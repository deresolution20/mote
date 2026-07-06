from __future__ import annotations

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("generate_report.py")


def load_module():
    spec = importlib.util.spec_from_file_location("generate_report", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


OLLAMA_SAMPLE = """# Ollama cleanup-hop benchmark

## gemma3:4b

Median 0.914 s · p90 1.485 s · first call 12.070 s

| id | latency | cleaned output (verify meaning by eye) |
| --- | --- | --- |
| 01 | 12.070 s | I think we should ship it Friday. |
| 02 | 0.929 s | Yeah, basically the dashboard is broken again. |
"""


MLX_SAMPLE = """# MLX cleanup-hop benchmark

- Model: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
- Load: 0.489 s
- Warmup: 0.180 s
- Median: 0.240 s
- p90: 0.264 s

| id | latency | reference | cleaned output (verify meaning by eye) |
| --- | --- | --- | --- |
| 01 | 0.217 s | um, so I think we should ship it Friday | I think we should ship it Friday. |
| 02 | 0.238 s | yeah so basically the uh the dashboard is is broken again | Yeah, so basically the dashboard is broken again. |
"""


class ReportGeneratorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()
        self.temp_dir = Path(tempfile.mkdtemp(prefix="localflow-report-test-"))

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir)

    def test_parses_ollama_cleanup_markdown(self) -> None:
        raw = self.temp_dir / "ollama.md"
        raw.write_text(OLLAMA_SAMPLE, encoding="utf-8")

        result = self.module.parse_ollama_report(raw)

        self.assertEqual(result["model"], "gemma3:4b")
        self.assertEqual(result["median"], 0.914)
        self.assertEqual(result["p90"], 1.485)
        self.assertEqual(result["first_call"], 12.070)
        self.assertEqual(result["rows"]["01"]["latency"], 12.070)
        self.assertEqual(result["rows"]["02"]["output"], "Yeah, basically the dashboard is broken again.")

    def test_parses_mlx_cleanup_markdown(self) -> None:
        raw = self.temp_dir / "mlx.md"
        raw.write_text(MLX_SAMPLE, encoding="utf-8")

        result = self.module.parse_mlx_report(raw)

        self.assertEqual(result["model"], "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
        self.assertEqual(result["load"], 0.489)
        self.assertEqual(result["warmup"], 0.180)
        self.assertEqual(result["median"], 0.240)
        self.assertEqual(result["p90"], 0.264)
        self.assertEqual(result["rows"]["01"]["reference"], "um, so I think we should ship it Friday")
        self.assertEqual(result["rows"]["02"]["latency"], 0.238)

    def test_run_folder_name_is_sortable_and_slugged(self) -> None:
        name = self.module.build_run_folder_name("2026-07-06", "Initial MLX vs Ollama!")

        self.assertEqual(name, "2026-07-06-initial-mlx-vs-ollama")

    def test_create_run_folder_refuses_overwrite_without_force(self) -> None:
        first = self.module.create_run_folder(
            self.temp_dir,
            run_date="2026-07-06",
            run_label="Initial MLX vs Ollama",
            force=False,
        )

        with self.assertRaises(FileExistsError):
            self.module.create_run_folder(
                self.temp_dir,
                run_date="2026-07-06",
                run_label="Initial MLX vs Ollama",
                force=False,
            )

        forced = self.module.create_run_folder(
            self.temp_dir,
            run_date="2026-07-06",
            run_label="Initial MLX vs Ollama",
            force=True,
        )
        self.assertEqual(first, forced)

    def test_writes_metadata_and_cleanup_results_contract(self) -> None:
        run_dir = self.temp_dir / "2026-07-06-initial-mlx-vs-ollama"
        run_dir.mkdir()
        ollama = self.module.parse_ollama_text(OLLAMA_SAMPLE)
        mlx = self.module.parse_mlx_text(MLX_SAMPLE)

        self.module.write_structured_outputs(run_dir, "Initial MLX vs Ollama", ollama, mlx)

        metadata = json.loads((run_dir / "metadata.json").read_text(encoding="utf-8"))
        results = json.loads((run_dir / "cleanup-results.json").read_text(encoding="utf-8"))
        self.assertEqual(metadata["run_label"], "Initial MLX vs Ollama")
        self.assertEqual(results["acceptance"]["decision"], "fail")
        self.assertEqual({provider["provider_id"] for provider in results["providers"]}, {"ollama", "mlx"})
        self.assertEqual(results["providers"][1]["model"], "mlx-community/Qwen2.5-1.5B-Instruct-4bit")

    def test_writes_agent_readable_markdown_report(self) -> None:
        run_dir = self.temp_dir / "2026-07-06-initial-mlx-vs-ollama"
        run_dir.mkdir()
        ollama = self.module.parse_ollama_text(OLLAMA_SAMPLE)
        mlx = self.module.parse_mlx_text(MLX_SAMPLE)

        report_path = self.module.build_markdown_report(run_dir, "Initial MLX vs Ollama", ollama, mlx)

        report = report_path.read_text(encoding="utf-8")
        self.assertEqual(report_path.name, "report.md")
        self.assertIn("# Local Flow MLX Cleanup Benchmark", report)
        self.assertIn("Ollama `gemma3:4b`: median `0.914s`, p90 `1.485s`, first call `12.070s`.", report)
        self.assertIn("MLX `mlx-community/Qwen2.5-1.5B-Instruct-4bit`: load `0.489s`, warmup `0.180s`, median `0.240s`, p90 `0.264s`.", report)
        self.assertIn("Acceptance decision: `fail`", report)
        self.assertIn("sanitizer", report)

    def test_report_metadata_text_includes_run_label(self) -> None:
        metadata = self.module.report_metadata_text("task-2-formal-cleanup-benchmark")

        self.assertIn("Run label: task-2-formal-cleanup-benchmark", metadata)
        self.assertIn("July 6, 2026", metadata)


if __name__ == "__main__":
    unittest.main()
