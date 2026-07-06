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


EXPECTED_TASK = "swift-native-mlx-steady-state-cleanup-benchmark"


def load_steady_state_result(path: Path) -> dict[str, Any]:
    result = json.loads(path.read_text(encoding="utf-8"))
    if result.get("task") != EXPECTED_TASK:
        raise ValueError(f"Unexpected task {result.get('task')!r}; expected {EXPECTED_TASK!r}")
    if result.get("status") != "completed":
        blockers = "; ".join(result.get("blockers") or [])
        raise ValueError(f"Cannot generate steady-state report for status {result.get('status')!r}: {blockers}")
    if not isinstance(result.get("summary"), dict):
        raise ValueError("Completed steady-state result is missing summary data")
    if not isinstance(result.get("samples"), list) or not result["samples"]:
        raise ValueError("Completed steady-state result is missing sample data")
    return result


def build_markdown_report(run_dir: Path, run_label: str, result: dict[str, Any]) -> Path:
    summary = result["summary"]
    lines = [
        "# Local Flow Swift MLX Steady-State Benchmark",
        "",
        f"Run label: `{run_label}`",
        "",
        "## Executive Summary",
        "",
        (
            "This benchmark measures the native Swift MLX cleanup path after one "
            "model load and one warmup generation. The summary latency excludes "
            "one-time model load and warmup, so it reflects repeated cleanup calls "
            "inside one long-lived process."
        ),
        "",
        "## Performance Metrics",
        "",
        f"- Model: `{result['model_id']}`.",
        f"- Sample count: `{summary['sample_count']}`.",
        f"- Load: `{result['load_seconds']:.3f}s`.",
        f"- Warmup: `{result['warmup_seconds']:.3f}s`.",
        f"- Repeated-call median: `{summary['median_seconds']:.3f}s`; p90 `{summary['p90_seconds']:.3f}s`; p95 `{summary['p95_seconds']:.3f}s`; max `{summary['max_seconds']:.3f}s`.",
        f"- Mean repeated-call latency: `{summary['mean_seconds']:.3f}s`.",
        f"- Total benchmark loop time: `{result['benchmark_seconds']:.3f}s`.",
        "",
        "## Runtime Contract",
        "",
        "- Native Swift MLX / MLX Swift LM.",
        "- No oMLX app.",
        "- No local MLX HTTP server.",
        "- No Python runtime helper in the measured cleanup path.",
        "- `mlx.metallib` is prepared by `swift run mlx-metallib-prepare`.",
        "",
        "## Sample Results",
        "",
        "| id | latency | cleaned output |",
        "| --- | ---: | --- |",
    ]
    for sample in result["samples"]:
        cleaned = str(sample["cleaned_output_candidate"]).replace("|", "\\|")
        lines.append(f"| {sample['id']} | {sample['latency_seconds']:.3f}s | {cleaned} |")
    lines.extend(
        [
            "",
            "## Generated Artifacts",
            "",
            "- `swift-steady-benchmark.json`: structured Swift benchmark result.",
            "- `report.md`: agent-readable summary.",
            "- `report.pdf`: visual report.",
            "- `report.docx`: editable Word-compatible report.",
            "- `charts/steady-state-latency.png`: per-sample latency chart.",
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
    out = charts_dir / "steady-state-latency.png"
    PILImage = deps["PILImage"]
    ImageDraw = deps["ImageDraw"]
    samples = result["samples"]
    latencies = [sample["latency_seconds"] for sample in samples]
    max_value = math.ceil(max(max(latencies), 0.35) * 10) / 10

    img = PILImage.new("RGB", (1400, 740), "white")
    draw = ImageDraw.Draw(img)
    draw.text((70, 42), "Swift MLX repeated cleanup latency", font=generate_report.font(deps, 34, True), fill=generate_report.rgb(generate_report.INK))
    draw.text((70, 88), "One model load, one warmup, then repeated cleanup calls in the same process.", font=generate_report.font(deps, 20), fill=generate_report.rgb(generate_report.MUTED))
    left, top, right, bottom = 120, 160, 1320, 610
    generate_report.draw_axis(deps, draw, left, top, right, bottom, max_value)

    bar_gap = 8
    bar_width = max(12, int((right - left - bar_gap * (len(samples) - 1)) / max(len(samples), 1)))
    for index, sample in enumerate(samples):
        value = sample["latency_seconds"]
        x0 = left + index * (bar_width + bar_gap)
        x1 = min(x0 + bar_width, right)
        y0 = bottom - (value / max_value) * (bottom - top)
        draw.rounded_rectangle((x0, y0, x1, bottom), radius=6, fill=generate_report.rgb(generate_report.TEAL))
        if index % 2 == 0:
            generate_report.draw_centered(
                draw,
                ((x0 + x1) / 2, bottom + 30),
                str(sample["id"]),
                generate_report.font(deps, 15),
                generate_report.rgb(generate_report.MUTED),
            )
    summary = result["summary"]
    draw.text((920, 42), f"median {summary['median_seconds']:.3f}s", font=generate_report.font(deps, 21, True), fill=generate_report.rgb(generate_report.INK))
    draw.text((920, 72), f"p95 {summary['p95_seconds']:.3f}s", font=generate_report.font(deps, 21, True), fill=generate_report.rgb(generate_report.INK))
    img.save(out)
    return out


def build_docx(run_dir: Path, run_label: str, result: dict[str, Any], chart: Path, deps: dict[str, Any]) -> Path:
    Document = deps["Document"]
    Inches = deps["Inches"]
    WD_ALIGN_PARAGRAPH = deps["WD_ALIGN_PARAGRAPH"]
    doc = Document()
    generate_report.style_docx(doc, deps)
    doc.sections[0].header.paragraphs[0].text = "Local Flow Swift MLX Steady-State Benchmark"

    generate_report.add_docx_para(doc, deps, "LOCAL FLOW", size=10, bold=True, color=generate_report.TEAL, after=4, align=WD_ALIGN_PARAGRAPH.CENTER)
    generate_report.add_docx_para(doc, deps, "Swift MLX Steady-State Benchmark", size=24, bold=True, color=generate_report.INK, after=2, align=WD_ALIGN_PARAGRAPH.CENTER)
    generate_report.add_docx_para(doc, deps, f"Run label: {run_label}", size=10, color=generate_report.MUTED, after=14, align=WD_ALIGN_PARAGRAPH.CENTER)

    summary = result["summary"]
    generate_report.add_metric_table_docx(doc, deps, [
        ("median repeated cleanup", f"{summary['median_seconds']:.3f}s", "load/warmup excluded", "E1F4F2"),
        ("p95 repeated cleanup", f"{summary['p95_seconds']:.3f}s", f"{summary['sample_count']} samples", "EAF2FB"),
        ("max repeated cleanup", f"{summary['max_seconds']:.3f}s", "tail observation", "FFF4DD"),
    ])
    doc.add_heading("Executive Summary", level=1)
    generate_report.add_docx_para(
        doc,
        deps,
        "This run measures native Swift MLX cleanup after one model load and one warmup generation. The reported median, p90, p95, and max values describe repeated cleanup calls inside one process.",
    )
    doc.add_picture(str(chart), width=Inches(6.2))
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER

    doc.add_heading("Sample Results", level=1)
    table = doc.add_table(rows=1, cols=3)
    for cell, header in zip(table.rows[0].cells, ["ID", "Latency", "Cleaned output"]):
        generate_report.set_cell_shading(cell, "E8EEF5", deps)
        generate_report.set_cell_text(cell, header, deps, bold=True, size=8.8)
    for sample in result["samples"]:
        cells = table.add_row().cells
        generate_report.set_cell_text(cells[0], str(sample["id"]), deps, size=8.2)
        generate_report.set_cell_text(cells[1], f"{sample['latency_seconds']:.3f}s", deps, size=8.2)
        generate_report.set_cell_text(cells[2], str(sample["cleaned_output_candidate"]), deps, size=8.2)
    generate_report.set_table_borders(table, deps)

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
        Paragraph("Swift MLX Steady-State Benchmark", styles["CoverTitle"]),
        Paragraph(f"Run label: {run_label}", styles["CoverSub"]),
        generate_report.pdf_metric_table(deps, [
            ("median repeated cleanup", f"{summary['median_seconds']:.3f}s", "load/warmup excluded", "E1F4F2"),
            ("p95 repeated cleanup", f"{summary['p95_seconds']:.3f}s", f"{summary['sample_count']} samples", "EAF2FB"),
            ("max repeated cleanup", f"{summary['max_seconds']:.3f}s", "tail observation", "FFF4DD"),
        ]),
        Spacer(1, 0.18 * inch),
        Image(str(chart), width=6.45 * inch, height=3.4 * inch),
        Paragraph("Executive Summary", styles["H1Custom"]),
        Paragraph("This run measures native Swift MLX cleanup after one model load and one warmup generation. The repeated-call latency summary excludes setup cost and is the right comparison for an already-resident cleanup provider.", styles["BodyCustom"]),
        Paragraph("Sample Results", styles["H1Custom"]),
        Paragraph("The PDF shows the first eight samples to keep the visual brief compact. The complete 24-sample table is in report.md and swift-steady-benchmark.json.", styles["SmallCustom"]),
    ]
    sample_rows = [["ID", "Latency", "Cleaned output"]]
    for sample in result["samples"][:8]:
        sample_rows.append([
            str(sample["id"]),
            f"{sample['latency_seconds']:.3f}s",
            str(sample["cleaned_output_candidate"])[:86],
        ])
    table = Table(sample_rows, colWidths=[0.55 * inch, 0.8 * inch, 5.0 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7.5),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor(generate_report.GRID)),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    story.append(table)

    def header_footer(canvas: Any, doc_obj: Any) -> None:
        canvas.saveState()
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(colors.HexColor(generate_report.MUTED))
        canvas.drawString(0.65 * inch, 0.35 * inch, "Local Flow Swift MLX Steady-State Benchmark")
        canvas.drawRightString(7.85 * inch, 0.35 * inch, f"Page {doc_obj.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    return out


def generate_steady_state_report(input_json: Path, run_dir: Path | None, run_label: str) -> Path:
    result = load_steady_state_result(input_json)
    target_dir = run_dir or input_json.parent
    target_dir.mkdir(parents=True, exist_ok=True)
    target_json = target_dir / "swift-steady-benchmark.json"
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a Local Flow Swift MLX steady-state benchmark report.")
    parser.add_argument("--input", type=Path, required=True, help="Path to swift-steady-benchmark.json.")
    parser.add_argument("--run-dir", type=Path, default=None, help="Run folder. Defaults to the input JSON parent.")
    parser.add_argument("--run-label", default="Task 5 Swift Steady State", help="Human-readable run label.")
    args = parser.parse_args()
    generate_steady_state_report(args.input, args.run_dir, args.run_label)


if __name__ == "__main__":
    main()
