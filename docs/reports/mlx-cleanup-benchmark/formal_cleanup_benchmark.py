from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Callable


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import generate_report


APPROVED_MLX_MODEL = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"


ReportGenerator = Callable[..., Path]


def validate_raw_inputs(ollama_raw: Path, mlx_raw: Path) -> dict[str, Any]:
    if not ollama_raw.exists():
        raise FileNotFoundError(f"Missing Ollama raw cleanup report: {ollama_raw}")
    if not mlx_raw.exists():
        raise FileNotFoundError(f"Missing MLX raw cleanup report: {mlx_raw}")

    ollama = generate_report.parse_ollama_report(ollama_raw)
    mlx = generate_report.parse_mlx_report(mlx_raw)
    if mlx["model"] != APPROVED_MLX_MODEL:
        raise ValueError(f"Unexpected MLX model {mlx['model']!r}; expected {APPROVED_MLX_MODEL!r}")

    ollama_ids = set(ollama["rows"])
    mlx_ids = set(mlx["rows"])
    shared_ids = sorted(ollama_ids.intersection(mlx_ids), key=int)
    if not shared_ids:
        raise ValueError("Ollama and MLX raw reports do not share any sample ids")

    return {
        "ollama": {
            "model": ollama["model"],
            "median": ollama["median"],
            "p90": ollama["p90"],
            "sample_count": len(ollama_ids),
        },
        "mlx": {
            "model": mlx["model"],
            "median": mlx["median"],
            "p90": mlx["p90"],
            "sample_count": len(mlx_ids),
        },
        "shared_sample_count": len(shared_ids),
    }


def run_formal_cleanup_benchmark(
    run_label: str,
    run_date: str,
    ollama_raw: Path,
    mlx_raw: Path,
    force: bool,
    report_generator: ReportGenerator = generate_report.generate_report,
) -> Path:
    validate_raw_inputs(ollama_raw, mlx_raw)
    return report_generator(
        run_label=run_label,
        run_date=run_date,
        ollama_raw=ollama_raw,
        mlx_raw=mlx_raw,
        force=force,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Create a formal Local Flow cleanup benchmark run by collecting raw "
            "Ollama and MLX cleanup outputs and invoking the report generator."
        )
    )
    parser.add_argument("--run-label", required=True, help="Human-readable run label.")
    parser.add_argument("--run-date", required=True, help="Run date in YYYY-MM-DD form.")
    parser.add_argument("--ollama-raw", type=Path, required=True, help="Path to raw Ollama cleanup Markdown.")
    parser.add_argument("--mlx-raw", type=Path, required=True, help="Path to raw MLX cleanup Markdown.")
    parser.add_argument("--force", action="store_true", help="Overwrite an existing run folder with the same date and label.")
    args = parser.parse_args()

    try:
        summary = validate_raw_inputs(args.ollama_raw, args.mlx_raw)
        print(
            "Validated raw inputs: "
            f"Ollama {summary['ollama']['sample_count']} rows, "
            f"MLX {summary['mlx']['sample_count']} rows, "
            f"{summary['shared_sample_count']} shared sample ids."
        )
        run_dir = run_formal_cleanup_benchmark(
            run_label=args.run_label,
            run_date=args.run_date,
            ollama_raw=args.ollama_raw,
            mlx_raw=args.mlx_raw,
            force=args.force,
        )
        print(f"Formal cleanup benchmark run: {run_dir}")
    except (FileNotFoundError, FileExistsError, ValueError, generate_report.MissingReportDependency) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
