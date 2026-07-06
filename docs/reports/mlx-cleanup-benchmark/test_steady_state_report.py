from __future__ import annotations

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("steady_state_report.py")


def load_module():
    spec = importlib.util.spec_from_file_location("steady_state_report", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


STEADY_RESULT = {
    "task": "swift-native-mlx-steady-state-cleanup-benchmark",
    "created_at": "2026-07-06T18:30:00Z",
    "machine_context": {"architecture": "arm64", "physical_memory_bytes": "34359738368"},
    "swift_toolchain": "Apple Swift",
    "mlx_swift_package": "0.31.6",
    "mlx_swift_lm_package": "3.31.4",
    "model_id": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
    "model_source": "hugging_face",
    "model_load_path": "LLMRegistry.qwen2_5_1_5b via MLX Swift LM",
    "manifest_path": "bench/samples/manifest.json",
    "max_tokens": 80,
    "load_seconds": 0.963,
    "warmup_seconds": 0.140,
    "benchmark_seconds": 0.501,
    "summary": {
        "sample_count": 2,
        "min_seconds": 0.144,
        "max_seconds": 0.201,
        "mean_seconds": 0.173,
        "median_seconds": 0.173,
        "p50_seconds": 0.173,
        "p90_seconds": 0.201,
        "p95_seconds": 0.201,
    },
    "samples": [
        {
            "id": "01",
            "reference": "um, so I think we should ship it Friday",
            "prompt": "Clean this dictated text.\n\nInput: um, so I think we should ship it Friday",
            "latency_seconds": 0.144,
            "raw_output": "I think we should ship it Friday.",
            "cleaned_output_candidate": "I think we should ship it Friday.",
        },
        {
            "id": "02",
            "reference": "yeah so basically the uh the dashboard is is broken again",
            "prompt": "Clean this dictated text.\n\nInput: yeah so basically the uh the dashboard is is broken again",
            "latency_seconds": 0.201,
            "raw_output": "Yeah, the dashboard is broken again.",
            "cleaned_output_candidate": "Yeah, the dashboard is broken again.",
        },
    ],
    "status": "completed",
    "blockers": [],
    "notes": ["Summary latency excludes one-time model load and one warmup generation."],
}


class SteadyStateReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()
        self.temp_dir = Path(tempfile.mkdtemp(prefix="localflow-steady-report-test-"))
        self.result_path = self.temp_dir / "swift-steady-benchmark.json"
        self.result_path.write_text(json.dumps(STEADY_RESULT), encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir)

    def test_loads_completed_steady_state_result(self) -> None:
        result = self.module.load_steady_state_result(self.result_path)

        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["summary"]["sample_count"], 2)
        self.assertEqual(result["summary"]["p95_seconds"], 0.201)

    def test_rejects_non_completed_result_before_report_generation(self) -> None:
        blocked = dict(STEADY_RESULT)
        blocked["status"] = "package_or_toolchain_blocked"
        blocked["summary"] = None
        blocked_path = self.temp_dir / "blocked.json"
        blocked_path.write_text(json.dumps(blocked), encoding="utf-8")

        with self.assertRaises(ValueError):
            self.module.load_steady_state_result(blocked_path)

    def test_writes_agent_readable_markdown_report(self) -> None:
        result = self.module.load_steady_state_result(self.result_path)

        report_path = self.module.build_markdown_report(self.temp_dir, "Task 5 Swift Steady State", result)

        report = report_path.read_text(encoding="utf-8")
        self.assertEqual(report_path.name, "report.md")
        self.assertIn("# Local Flow Swift MLX Steady-State Benchmark", report)
        self.assertIn("Run label: `Task 5 Swift Steady State`", report)
        self.assertIn("p95 `0.201s`", report)
        self.assertIn("excludes one-time model load and warmup", report)
        self.assertIn("| 01 | 0.144s | I think we should ship it Friday. |", report)


if __name__ == "__main__":
    unittest.main()
