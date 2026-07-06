from __future__ import annotations

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("production_acceptance_report.py")


def load_module():
    spec = importlib.util.spec_from_file_location("production_acceptance_report", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


ACCEPTANCE_RESULT = {
    "task": "post-safety-production-cleanup-acceptance-benchmark",
    "createdAt": "2026-07-06T20:15:00Z",
    "status": "completed",
    "selectedProvider": "mlx",
    "providerChain": [
        {
            "id": "mlx",
            "displayName": "MLX",
            "modelName": "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        },
        {"id": "ollama", "displayName": "Ollama", "modelName": "gemma3:4b"},
    ],
    "manifestPath": "bench/samples/manifest.json",
    "sampleCount": 2,
    "warmupSeconds": 0.950,
    "warmupPath": "mlx",
    "benchmarkSeconds": 0.310,
    "summary": {
        "sampleCount": 2,
        "minSeconds": 0.140,
        "maxSeconds": 0.170,
        "meanSeconds": 0.155,
        "medianSeconds": 0.155,
        "p90Seconds": 0.167,
        "p95Seconds": 0.168,
        "mlxCount": 1,
        "ollamaCount": 1,
        "rawFallbackCount": 0,
        "requiresManualReview": True,
        "automatedDecision": "latency_and_output_review_required",
    },
    "samples": [
        {
            "id": "01",
            "file": "01.wav",
            "reference": "um so i think we should ship it friday",
            "latencySeconds": 0.140,
            "path": "mlx",
            "attemptedProviders": ["mlx"],
            "textToPaste": "I think we should ship it Friday.",
            "cleanedText": "I think we should ship it Friday.",
        },
        {
            "id": "02",
            "file": "02.wav",
            "reference": "yeah so basically the dashboard is broken again",
            "latencySeconds": 0.170,
            "path": "ollama",
            "attemptedProviders": ["mlx", "ollama"],
            "attempts": [
                {
                    "provider": "mlx",
                    "outcome": "rejected",
                    "latencySeconds": 0.041,
                    "rejectReason": "protectedMarkerLoss",
                    "rejectDetail": "basically",
                    "rawCandidate": "Yeah, the dashboard is broken again.",
                    "sanitizedCandidate": "Yeah, the dashboard is broken again.",
                    "cleanedText": None,
                    "errorDescription": None,
                },
                {
                    "provider": "ollama",
                    "outcome": "accepted",
                    "latencySeconds": 0.129,
                    "rejectReason": None,
                    "rejectDetail": None,
                    "rawCandidate": "Yeah, the dashboard is broken again.",
                    "sanitizedCandidate": "Yeah, the dashboard is broken again.",
                    "cleanedText": "Yeah, the dashboard is broken again.",
                    "errorDescription": None,
                },
            ],
            "textToPaste": "Yeah, the dashboard is broken again.",
            "cleanedText": "Yeah, the dashboard is broken again.",
        },
    ],
    "notes": ["Synthetic fixture for tests."],
}


class ProductionAcceptanceReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()
        self.temp_dir = Path(tempfile.mkdtemp(prefix="localflow-acceptance-report-test-"))
        self.result_path = self.temp_dir / "production-acceptance.json"
        self.result_path.write_text(json.dumps(ACCEPTANCE_RESULT), encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir)

    def test_loads_completed_acceptance_result(self) -> None:
        result = self.module.load_acceptance_result(self.result_path)

        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["summary"]["mlxCount"], 1)
        self.assertEqual(result["summary"]["ollamaCount"], 1)

    def test_rejects_failed_acceptance_result(self) -> None:
        failed = dict(ACCEPTANCE_RESULT)
        failed["status"] = "failed"
        failed_path = self.temp_dir / "failed.json"
        failed_path.write_text(json.dumps(failed), encoding="utf-8")

        with self.assertRaises(ValueError):
            self.module.load_acceptance_result(failed_path)

    def test_writes_agent_readable_markdown_report(self) -> None:
        result = self.module.load_acceptance_result(self.result_path)

        report_path = self.module.build_markdown_report(self.temp_dir, "Task 10 Production Acceptance", result)

        report = report_path.read_text(encoding="utf-8")
        self.assertEqual(report_path.name, "report.md")
        self.assertIn("# Local Flow Post-Safety Production Acceptance Benchmark", report)
        self.assertIn("Run label: `Task 10 Production Acceptance`", report)
        self.assertIn("Median production-chain latency: `0.155s`", report)
        self.assertIn("Path counts: `MLX 1`, `Ollama fallback 1`, `raw fallback 0`", report)
        self.assertIn("| 02 | 0.170s | ollama | mlx, ollama | Yeah, the dashboard is broken again. |", report)
        self.assertIn("## Rejected Attempt Diagnostics", report)
        self.assertIn("| 02 | mlx | 0.041s | rejected | protectedMarkerLoss | basically | Yeah, the dashboard is broken again. | Yeah, the dashboard is broken again. |", report)

    def test_markdown_handles_timeout_attempt_without_candidates(self) -> None:
        result = json.loads(json.dumps(ACCEPTANCE_RESULT))
        result["samples"][0]["attempts"] = [
            {
                "provider": "ollama",
                "outcome": "timeout",
                "latencySeconds": 6.004,
                "rejectReason": "requestTimedOut",
                "rejectDetail": "6.0s",
            }
        ]

        report_path = self.module.build_markdown_report(self.temp_dir, "Task 11 Diagnostics", result)

        report = report_path.read_text(encoding="utf-8")
        self.assertIn("| 01 | ollama | 6.004s | timeout | requestTimedOut | 6.0s |  |  |", report)


if __name__ == "__main__":
    unittest.main()
