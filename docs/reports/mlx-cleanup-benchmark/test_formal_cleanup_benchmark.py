from __future__ import annotations

import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("formal_cleanup_benchmark.py")


def load_module():
    spec = importlib.util.spec_from_file_location("formal_cleanup_benchmark", MODULE_PATH)
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
"""


class FormalCleanupBenchmarkTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()
        self.temp_dir = Path(tempfile.mkdtemp(prefix="localflow-formal-bench-test-"))
        self.ollama_raw = self.temp_dir / "ollama.md"
        self.mlx_raw = self.temp_dir / "mlx.md"
        self.ollama_raw.write_text(OLLAMA_SAMPLE, encoding="utf-8")
        self.mlx_raw.write_text(MLX_SAMPLE, encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir)

    def test_validates_raw_inputs_before_formal_run(self) -> None:
        summary = self.module.validate_raw_inputs(self.ollama_raw, self.mlx_raw)

        self.assertEqual(summary["ollama"]["model"], "gemma3:4b")
        self.assertEqual(summary["mlx"]["model"], "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
        self.assertEqual(summary["ollama"]["sample_count"], 1)
        self.assertEqual(summary["mlx"]["sample_count"], 1)

    def test_missing_raw_input_fails_before_report_generation(self) -> None:
        calls = []

        def fake_generator(**kwargs):
            calls.append(kwargs)
            return self.temp_dir / "unexpected"

        with self.assertRaises(FileNotFoundError):
            self.module.run_formal_cleanup_benchmark(
                run_label="Task 2",
                run_date="2026-07-06",
                ollama_raw=self.temp_dir / "missing-ollama.md",
                mlx_raw=self.mlx_raw,
                force=False,
                report_generator=fake_generator,
            )

        self.assertEqual(calls, [])

    def test_formal_run_delegates_to_report_generator(self) -> None:
        calls = []
        expected_run = self.temp_dir / "runs" / "2026-07-06-task-2"

        def fake_generator(**kwargs):
            calls.append(kwargs)
            return expected_run

        result = self.module.run_formal_cleanup_benchmark(
            run_label="Task 2",
            run_date="2026-07-06",
            ollama_raw=self.ollama_raw,
            mlx_raw=self.mlx_raw,
            force=True,
            report_generator=fake_generator,
        )

        self.assertEqual(result, expected_run)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["run_label"], "Task 2")
        self.assertEqual(calls[0]["run_date"], "2026-07-06")
        self.assertEqual(calls[0]["ollama_raw"], self.ollama_raw)
        self.assertEqual(calls[0]["mlx_raw"], self.mlx_raw)
        self.assertTrue(calls[0]["force"])


if __name__ == "__main__":
    unittest.main()
