from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import generate_report


EXPECTED_TASK = "post-safety-production-cleanup-acceptance-benchmark"


def load_acceptance_result(path: Path) -> dict[str, Any]:
    result = json.loads(path.read_text(encoding="utf-8"))
    if result.get("task") != EXPECTED_TASK:
        raise ValueError(f"Unexpected task {result.get('task')!r}; expected {EXPECTED_TASK!r}")
    if result.get("status") != "completed":
        raise ValueError(f"Cannot generate production acceptance report for status {result.get('status')!r}")
    if not isinstance(result.get("summary"), dict):
        raise ValueError("Completed acceptance result is missing summary data")
    if not isinstance(result.get("samples"), list) or not result["samples"]:
        raise ValueError("Completed acceptance result is missing sample data")
    return result


def build_markdown_report(run_dir: Path, run_label: str, result: dict[str, Any]) -> Path:
    summary = result["summary"]
    lines = [
        "# Local Flow Post-Safety Production Acceptance Benchmark",
        "",
        f"Run label: `{run_label}`",
        "",
        "## Executive Summary",
        "",
        (
            "This run measures the actual production cleanup chain after one warmup "
            f"inside a single process: {chain_description(result)}. "
            "The benchmark records latency, chosen path, "
            "attempted providers, and final text for every reference sample."
        ),
        "",
        "## Acceptance Snapshot",
        "",
        f"- Selected provider: `{result['selectedProvider']}`.",
        f"- Provider chain: `{provider_chain_text(result)}`.",
        f"- Sample count: `{result['sampleCount']}`.",
        f"- Warmup: `{result['warmupSeconds']:.3f}s` via `{result['warmupPath']}`.",
        f"- Median production-chain latency: `{summary['medianSeconds']:.3f}s`.",
        f"- p90: `{summary['p90Seconds']:.3f}s`; p95: `{summary['p95Seconds']:.3f}s`; max: `{summary['maxSeconds']:.3f}s`.",
        f"- Path counts: {path_counts_text(summary)}.",
        f"- Automated decision: `{summary['automatedDecision']}`.",
        "- Manual review: `required` for accepted-output quality and raw fallback review.",
        "",
        "## Runtime Contract",
        "",
        "- Native Swift MLX / MLX Swift LM.",
        "- No oMLX app.",
        "- No Python runtime helper in the measured cleanup path.",
        "- MLX is the only cleanup provider in the measured app path.",
        "- Raw transcript fallback remains the terminal safety behavior.",
        "",
        "## Sample Results",
        "",
        "| id | latency | path | attempted providers | final text |",
        "| --- | ---: | --- | --- | --- |",
    ]
    for sample in result["samples"]:
        lines.append(
            "| {id} | {latency:.3f}s | {path} | {attempted} | {text} |".format(
                id=sample["id"],
                latency=sample["latencySeconds"],
                path=sample["path"],
                attempted=", ".join(sample["attemptedProviders"]),
                text=escape_markdown_table(sample["textToPaste"]),
            )
        )
    rejected_rows = diagnostic_rows(result)
    if rejected_rows:
        lines.extend(
            [
                "",
                "## Rejected Attempt Diagnostics",
                "",
                "| id | provider | latency | outcome | reason | detail | raw candidate | sanitized candidate |",
                "| --- | --- | ---: | --- | --- | --- | --- | --- |",
            ]
        )
        for row in rejected_rows:
            lines.append(
                "| {id} | {provider} | {latency:.3f}s | {outcome} | {reason} | {detail} | {raw} | {sanitized} |".format(
                    id=row["id"],
                    provider=row["provider"],
                    latency=row["latencySeconds"],
                    outcome=row["outcome"],
                    reason=row["rejectReason"] or "",
                    detail=escape_markdown_table(row["rejectDetail"] or ""),
                    raw=escape_markdown_table(row.get("rawCandidate") or ""),
                    sanitized=escape_markdown_table(row.get("sanitizedCandidate") or ""),
                )
            )
    lines.extend(
        [
            "",
            "## Generated Artifacts",
            "",
            "- `production-acceptance.json`: structured live benchmark result.",
            "- `report.md`: agent-readable benchmark summary.",
            "- `report.pdf`: visual report.",
            "- `report.docx`: editable Word-compatible report.",
            "- `charts/production-chain-latency.png`: per-sample latency/path chart.",
            "- `qa-render/`: rendered PDF QA images.",
            "",
        ]
    )
    out = run_dir / "report.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def save_latency_chart(run_dir: Path, result: dict[str, Any], deps: dict[str, Any]) -> Path:
    charts_dir = run_dir / "charts"
    charts_dir.mkdir(exist_ok=True)
    out = charts_dir / "production-chain-latency.png"
    PILImage = deps["PILImage"]
    ImageDraw = deps["ImageDraw"]
    samples = result["samples"]
    latencies = [sample["latencySeconds"] for sample in samples]
    max_value = math.ceil(max(max(latencies), 0.35) * 10) / 10

    img = PILImage.new("RGB", (1400, 760), "white")
    draw = ImageDraw.Draw(img)
    draw.text((70, 42), "Production cleanup chain latency", font=generate_report.font(deps, 34, True), fill=generate_report.rgb(generate_report.INK))
    draw.text((70, 88), f"{chain_description(result)}. Warmup is excluded.", font=generate_report.font(deps, 20), fill=generate_report.rgb(generate_report.MUTED))
    left, top, right, bottom = 120, 170, 1320, 625
    generate_report.draw_axis(deps, draw, left, top, right, bottom, max_value)

    bar_gap = 8
    bar_width = max(12, int((right - left - bar_gap * (len(samples) - 1)) / max(len(samples), 1)))
    for index, sample in enumerate(samples):
        value = sample["latencySeconds"]
        x0 = left + index * (bar_width + bar_gap)
        x1 = min(x0 + bar_width, right)
        y0 = bottom - (value / max_value) * (bottom - top)
        draw.rounded_rectangle((x0, y0, x1, bottom), radius=6, fill=path_color(sample["path"]))
        if index % 2 == 0:
            generate_report.draw_centered(
                draw,
                ((x0 + x1) / 2, bottom + 30),
                str(sample["id"]),
                generate_report.font(deps, 15),
                generate_report.rgb(generate_report.MUTED),
            )

    summary = result["summary"]
    draw.text((930, 42), f"median {summary['medianSeconds']:.3f}s", font=generate_report.font(deps, 21, True), fill=generate_report.rgb(generate_report.INK))
    draw.text((930, 72), f"p95 {summary['p95Seconds']:.3f}s", font=generate_report.font(deps, 21, True), fill=generate_report.rgb(generate_report.INK))
    draw.rectangle((930, 108, 954, 132), fill=path_color("mlx"))
    draw.text((964, 104), "MLX accepted", font=generate_report.font(deps, 17), fill=generate_report.rgb(generate_report.INK))
    legend_y = 140
    if includes_ollama(result):
        draw.rectangle((930, legend_y, 954, legend_y + 24), fill=path_color("ollama"))
        draw.text((964, legend_y - 4), "Ollama fallback", font=generate_report.font(deps, 17), fill=generate_report.rgb(generate_report.INK))
        legend_y += 32
    draw.rectangle((930, legend_y, 954, legend_y + 24), fill=path_color("raw_fallback"))
    draw.text((964, legend_y - 4), "Raw fallback", font=generate_report.font(deps, 17), fill=generate_report.rgb(generate_report.INK))
    img.save(out)
    return out


def build_docx(run_dir: Path, run_label: str, result: dict[str, Any], chart: Path, deps: dict[str, Any]) -> Path:
    Document = deps["Document"]
    Inches = deps["Inches"]
    WD_ALIGN_PARAGRAPH = deps["WD_ALIGN_PARAGRAPH"]
    doc = Document()
    generate_report.style_docx(doc, deps)
    doc.sections[0].header.paragraphs[0].text = "Local Flow Production Cleanup Acceptance"

    summary = result["summary"]
    generate_report.add_docx_para(doc, deps, "LOCAL FLOW", size=10, bold=True, color=generate_report.TEAL, after=4, align=WD_ALIGN_PARAGRAPH.CENTER)
    generate_report.add_docx_para(doc, deps, "Post-Safety Production Acceptance Benchmark", size=22, bold=True, color=generate_report.INK, after=2, align=WD_ALIGN_PARAGRAPH.CENTER)
    generate_report.add_docx_para(doc, deps, f"Run label: {run_label}", size=10, color=generate_report.MUTED, after=14, align=WD_ALIGN_PARAGRAPH.CENTER)
    generate_report.add_metric_table_docx(doc, deps, [
        ("median production latency", f"{summary['medianSeconds']:.3f}s", "warmup excluded", "E1F4F2"),
        ("p95 production latency", f"{summary['p95Seconds']:.3f}s", f"{summary['sampleCount']} samples", "EAF2FB"),
        ("path split", path_split_value(summary), path_split_label(summary), "FFF4DD"),
    ])

    doc.add_heading("Executive Summary", level=1)
    generate_report.add_docx_para(
        doc,
        deps,
        f"This run measures the actual production cleanup chain after one warmup inside a single process: {chain_description(result)}. Manual output review remains required for accepted-output quality and raw fallback review.",
    )
    doc.add_picture(str(chart), width=Inches(6.2))
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER

    doc.add_heading("Runtime Contract", level=1)
    table = doc.add_table(rows=1, cols=2)
    for cell, header in zip(table.rows[0].cells, ["Item", "Value"]):
        generate_report.set_cell_shading(cell, "E8EEF5", deps)
        generate_report.set_cell_text(cell, header, deps, bold=True, size=8.8)
    for label, value in [
        ("Selected provider", result["selectedProvider"]),
        ("Provider chain", provider_chain_text(result)),
        ("Warmup", f"{result['warmupSeconds']:.3f}s via {result['warmupPath']}"),
        ("Automated decision", summary["automatedDecision"]),
        ("Manual review", "required for output quality"),
    ]:
        cells = table.add_row().cells
        generate_report.set_cell_text(cells[0], label, deps, bold=True, size=8.4)
        generate_report.set_cell_text(cells[1], value, deps, size=8.4)
    generate_report.set_table_borders(table, deps)

    doc.add_heading("Sample Results", level=1)
    sample_table = doc.add_table(rows=1, cols=5)
    for cell, header in zip(sample_table.rows[0].cells, ["ID", "Latency", "Path", "Attempted", "Final text"]):
        generate_report.set_cell_shading(cell, "E8EEF5", deps)
        generate_report.set_cell_text(cell, header, deps, bold=True, size=8.2)
    for sample in result["samples"]:
        cells = sample_table.add_row().cells
        generate_report.set_cell_text(cells[0], str(sample["id"]), deps, size=7.8)
        generate_report.set_cell_text(cells[1], f"{sample['latencySeconds']:.3f}s", deps, size=7.8)
        generate_report.set_cell_text(cells[2], sample["path"], deps, size=7.8)
        generate_report.set_cell_text(cells[3], ", ".join(sample["attemptedProviders"]), deps, size=7.2)
        generate_report.set_cell_text(cells[4], sample["textToPaste"], deps, size=7.2)
    generate_report.set_table_borders(sample_table, deps)

    rejected_rows = diagnostic_rows(result)
    if rejected_rows:
        doc.add_heading("Rejected Attempt Diagnostics", level=1)
        diag_table = doc.add_table(rows=1, cols=7)
        for cell, header in zip(diag_table.rows[0].cells, ["ID", "Provider", "Latency", "Outcome", "Reason", "Detail", "Raw candidate"]):
            generate_report.set_cell_shading(cell, "E8EEF5", deps)
            generate_report.set_cell_text(cell, header, deps, bold=True, size=7.6)
        for row in rejected_rows:
            cells = diag_table.add_row().cells
            generate_report.set_cell_text(cells[0], str(row["id"]), deps, size=6.8)
            generate_report.set_cell_text(cells[1], str(row["provider"]), deps, size=6.8)
            generate_report.set_cell_text(cells[2], f"{row['latencySeconds']:.3f}s", deps, size=6.8)
            generate_report.set_cell_text(cells[3], str(row["outcome"]), deps, size=6.8)
            generate_report.set_cell_text(cells[4], str(row.get("rejectReason") or ""), deps, size=6.5)
            generate_report.set_cell_text(cells[5], str(row.get("rejectDetail") or ""), deps, size=6.5)
            generate_report.set_cell_text(cells[6], str(row.get("rawCandidate") or ""), deps, size=6.2)
        generate_report.set_table_borders(diag_table, deps)

    out = run_dir / "report.docx"
    doc.save(out)
    return out


def build_pdf(run_dir: Path, run_label: str, result: dict[str, Any], chart: Path, deps: dict[str, Any]) -> Path:
    colors = deps["colors"]
    letter = deps["letter"]
    inch = deps["inch"]
    Image = deps["Image"]
    Paragraph = deps["Paragraph"]
    SimpleDocTemplate = deps["SimpleDocTemplate"]
    Spacer = deps["Spacer"]
    Table = deps["Table"]
    TableStyle = deps["TableStyle"]
    styles = generate_report.make_pdf_styles(deps)
    out = run_dir / "report.pdf"
    doc = SimpleDocTemplate(str(out), pagesize=letter, rightMargin=0.65 * inch, leftMargin=0.65 * inch, topMargin=0.65 * inch, bottomMargin=0.62 * inch)
    summary = result["summary"]
    story: list[Any] = [
        Paragraph("LOCAL FLOW", styles["CoverKicker"]),
        Paragraph("Post-Safety Production Acceptance Benchmark", styles["CoverTitle"]),
        Paragraph(f"Run label: {run_label}", styles["CoverSub"]),
        generate_report.pdf_metric_table(deps, [
            ("median production latency", f"{summary['medianSeconds']:.3f}s", "warmup excluded", "E1F4F2"),
            ("p95 production latency", f"{summary['p95Seconds']:.3f}s", f"{summary['sampleCount']} samples", "EAF2FB"),
            ("path split", path_split_value(summary), path_split_label(summary), "FFF4DD"),
        ]),
        Spacer(1, 0.16 * inch),
        Image(str(chart), width=6.45 * inch, height=3.5 * inch),
        Paragraph("Executive Summary", styles["H1Custom"]),
        Paragraph(f"This run measures the production cleanup chain after one warmup inside a single process: {chain_description(result)}. Manual review remains required for accepted-output quality and raw fallback review.", styles["BodyCustom"]),
        Paragraph("Sample Results", styles["H1Custom"]),
        Paragraph("The PDF shows the first six samples. The complete table is in report.md and production-acceptance.json.", styles["SmallCustom"]),
    ]
    sample_rows = [["ID", "Latency", "Path", "Final text"]]
    for sample in result["samples"][:6]:
        sample_rows.append([
            str(sample["id"]),
            f"{sample['latencySeconds']:.3f}s",
            sample["path"],
            str(sample["textToPaste"])[:76],
        ])
    table = Table(sample_rows, colWidths=[0.45 * inch, 0.7 * inch, 0.75 * inch, 4.95 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7.2),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor(generate_report.GRID)),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    story.append(table)
    rejected_rows = diagnostic_rows(result)
    if rejected_rows:
        story.extend([
            Paragraph("Rejected Attempt Diagnostics", styles["H1Custom"]),
            Paragraph("The complete raw and sanitized candidates are preserved in report.md and production-acceptance.json.", styles["SmallCustom"]),
        ])
        diag_rows = [["ID", "Provider", "Latency", "Outcome", "Reason", "Candidate"]]
        for row in rejected_rows[:6]:
            diag_rows.append([
                str(row["id"]),
                str(row["provider"]),
                f"{row['latencySeconds']:.3f}s",
                str(row["outcome"]),
                str(row.get("rejectReason") or ""),
                str(row.get("rawCandidate") or "")[:58],
            ])
        diag_table = Table(diag_rows, colWidths=[0.38 * inch, 0.62 * inch, 0.58 * inch, 0.65 * inch, 1.05 * inch, 3.55 * inch])
        diag_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 6.6),
            ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor(generate_report.GRID)),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]))
        story.append(diag_table)

    def header_footer(canvas: Any, doc_obj: Any) -> None:
        canvas.saveState()
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(colors.HexColor(generate_report.MUTED))
        canvas.drawString(0.65 * inch, 0.35 * inch, "Local Flow Production Cleanup Acceptance")
        canvas.drawRightString(7.85 * inch, 0.35 * inch, f"Page {doc_obj.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    return out


def generate_acceptance_report(input_json: Path, run_dir: Path | None, run_label: str) -> Path:
    result = load_acceptance_result(input_json)
    target_dir = run_dir or input_json.parent
    target_dir.mkdir(parents=True, exist_ok=True)
    target_json = target_dir / "production-acceptance.json"
    if input_json.resolve() != target_json.resolve():
        shutil.copyfile(input_json, target_json)

    markdown_path = build_markdown_report(target_dir, run_label, result)
    deps = generate_report.require_report_dependencies()
    chart = save_latency_chart(target_dir, result, deps)
    docx_path = build_docx(target_dir, run_label, result, chart, deps)
    pdf_path = build_pdf(target_dir, run_label, result, chart, deps)
    pages, contact = generate_report.render_pdf_pages(target_dir, pdf_path, deps)

    print(f"Run folder: {target_dir}")
    print(f"Markdown: {markdown_path}")
    print(f"DOCX: {docx_path}")
    print(f"PDF: {pdf_path}")
    print(f"PDF pages rendered: {len(pages)}")
    print(f"PDF contact sheet: {contact}")
    return target_dir


def provider_chain_text(result: dict[str, Any]) -> str:
    return " -> ".join(f"{provider['id']} ({provider['modelName']})" for provider in result["providerChain"])


def includes_ollama(result: dict[str, Any]) -> bool:
    summary = result.get("summary", {})
    if "ollamaCount" in summary:
        return True
    if any(provider.get("id") == "ollama" for provider in result.get("providerChain", [])):
        return True
    return any(sample.get("path") == "ollama" for sample in result.get("samples", []))


def chain_description(result: dict[str, Any]) -> str:
    if includes_ollama(result):
        return "MLX first, Ollama fallback second, and raw transcript fallback last"
    return "MLX cleanup, then raw transcript fallback"


def path_counts_text(summary: dict[str, Any]) -> str:
    parts = [f"`MLX {summary['mlxCount']}`"]
    if "ollamaCount" in summary:
        parts.append(f"`Ollama fallback {summary['ollamaCount']}`")
    parts.append(f"`raw fallback {summary['rawFallbackCount']}`")
    return ", ".join(parts)


def path_split_value(summary: dict[str, Any]) -> str:
    if "ollamaCount" in summary:
        return f"{summary['mlxCount']}/{summary['ollamaCount']}/{summary['rawFallbackCount']}"
    return f"{summary['mlxCount']}/{summary['rawFallbackCount']}"


def path_split_label(summary: dict[str, Any]) -> str:
    if "ollamaCount" in summary:
        return "MLX/Ollama/raw"
    return "MLX/raw"


def diagnostic_rows(result: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for sample in result["samples"]:
        for attempt in sample.get("attempts", []):
            if attempt.get("outcome") == "accepted":
                continue
            row = dict(attempt)
            row["id"] = sample["id"]
            rows.append(row)
    return rows


def escape_markdown_table(text: str) -> str:
    return str(text).replace("|", "\\|")


def path_color(path: str) -> tuple[int, int, int]:
    colors = {
        "mlx": generate_report.TEAL,
        "ollama": generate_report.BLUE,
        "raw_fallback": generate_report.GOLD,
    }
    return generate_report.rgb(colors.get(path, generate_report.MUTED))


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a Local Flow production cleanup acceptance benchmark report.")
    parser.add_argument("--input", type=Path, required=True, help="Path to production-acceptance.json.")
    parser.add_argument("--run-dir", type=Path, default=None, help="Run folder. Defaults to the input JSON parent.")
    parser.add_argument("--run-label", default="Task 10 Production Acceptance", help="Human-readable run label.")
    args = parser.parse_args()
    generate_acceptance_report(args.input, args.run_dir, args.run_label)


if __name__ == "__main__":
    main()
