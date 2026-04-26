"""
evaluation/benchmark.py
------------------------
Professional benchmark runner.

What makes this systematic (not just a basic project):
  1. Ground truth derived from destination attributes — not hardcoded guesses
  2. Graded relevance (0-3) feeding into proper graded nDCG
  3. All five dissertation scenarios covered
  4. Baseline vs full hybrid A/B comparison
  5. Per-scenario grade tables for dissertation appendix
  6. Results exported to JSON for Chapter 5 tables

Usage:
    python -m evaluation.benchmark                  # full run
    python -m evaluation.benchmark --audit          # print grade tables only
    python -m evaluation.benchmark --export         # save results to evaluation/results.json
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Dict, List

from evaluation.metrics import RankingMetrics
from evaluation.relevance_assessor import RelevanceAssessor, SCENARIOS


BASE_URL        = "http://127.0.0.1:8000"
DESTINATIONS    = Path(__file__).parent.parent / "data" / "destinations.json"
K               = 10


# ── HTTP helpers ──────────────────────────────────────────────────────────────

def call_recommend(payload: dict) -> List[str]:
    """Call live /recommend endpoint, return ordered list of destination IDs."""
    data = json.dumps(payload).encode()
    req  = urllib.request.Request(
        f"{BASE_URL}/recommend",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = json.loads(resp.read())
    return [item["id"] for item in body.get("results", [])]


def call_recommend_semantic_only(payload: dict) -> List[str]:
    """
    Simulate semantic-only baseline by passing an unknown user_id so
    collaborative weight collapses to 0, leaving only SBERT + contextual.
    A cleaner approach would be a dedicated /recommend/baseline endpoint,
    but this works without server changes.
    """
    baseline_payload = {**payload, "user_id": "__baseline_no_collab__"}
    return call_recommend(baseline_payload)


# ── Result container ──────────────────────────────────────────────────────────

class ScenarioResult:
    def __init__(
        self,
        scenario_name: str,
        predicted: List[str],
        grades: Dict[str, int],
        k: int,
    ) -> None:
        self.scenario_name = scenario_name
        self.predicted     = predicted
        self.grades        = grades
        metrics            = RankingMetrics()
        relevant_set       = {d for d, g in grades.items() if g >= 2}

        self.p_at_k      = metrics.graded_precision_at_k(predicted, grades, k, threshold=2)
        self.r_at_k      = metrics.graded_recall_at_k(predicted, grades, k, threshold=2)
        self.ndcg        = metrics.graded_ndcg_at_k(predicted, grades, k)
        self.mrr         = metrics.graded_mrr(predicted, grades, threshold=2)
        self.binary_ndcg = metrics.ndcg_at_k(predicted, relevant_set, k)

        # Grade distribution in top-K
        top_k = predicted[:k]
        self.grade_dist = {g: sum(1 for d in top_k if grades.get(d, 0) == g)
                           for g in range(4)}

    def print(self) -> None:
        relevant_count = sum(1 for g in self.grades.values() if g >= 2)
        print(f"\n{'='*65}")
        print(f"Scenario : {self.scenario_name}")
        print(f"Relevant destinations (grade ≥ 2) : {relevant_count} / "
              f"{len(self.grades)}")
        print(f"{'='*65}")
        print(f"  Top-{K} predicted : {self.predicted[:K]}")
        print(f"\n  Grade distribution in top-{K}:")
        labels = {3: "Highly relevant", 2: "Relevant",
                  1: "Marginal", 0: "Not relevant"}
        for g in [3, 2, 1, 0]:
            bar = "█" * self.grade_dist[g]
            print(f"    [{g}] {labels[g]:<18} {bar} {self.grade_dist[g]}")
        print(f"\n  Precision@{K}  (graded, thresh=2) : {self.p_at_k:.4f}")
        print(f"  Recall@{K}     (graded, thresh=2) : {self.r_at_k:.4f}")
        print(f"  nDCG@{K}       (graded)           : {self.ndcg:.4f}")
        print(f"  nDCG@{K}       (binary, for table): {self.binary_ndcg:.4f}")
        print(f"  MRR            (thresh=2)         : {self.mrr:.4f}")

    def to_dict(self) -> dict:
        return {
            "scenario": self.scenario_name,
            "p_at_k":      round(self.p_at_k, 4),
            "r_at_k":      round(self.r_at_k, 4),
            "ndcg":        round(self.ndcg, 4),
            "binary_ndcg": round(self.binary_ndcg, 4),
            "mrr":         round(self.mrr, 4),
            "grade_distribution_top_k": self.grade_dist,
        }


# ── Benchmark runner ──────────────────────────────────────────────────────────

class BenchmarkRunner:

    def __init__(self) -> None:
        self.assessor = RelevanceAssessor(DESTINATIONS)
        self.metrics  = RankingMetrics()

    def run_all(self, export: bool = False) -> None:
        """Run all five scenarios with graded ground truth."""
        payloads = {
            "cultural_trekking": {
                "activity": "culture", "budget": "medium",
                "season": "spring",    "vibe": "cultural",
                "family_friendly": True, "top_k": K,
            },
            "high_adventure": {
                "activity": "trekking", "budget": "premium",
                "season": "autumn",     "vibe": "adventure",
                "family_friendly": False, "adventure_level": 5, "top_k": K,
            },
            "budget_relaxation": {
                "activity": "relaxation", "budget": "budget",
                "season": "autumn",       "vibe": "peaceful",
                "family_friendly": True,  "top_k": K,
            },
            "family_friendly": {
                "activity": "culture", "budget": "medium",
                "season": "spring",    "vibe": "cultural",
                "family_friendly": True, "top_k": K,
            },
            "pilgrimage_route": {
                "activity": "pilgrimage", "budget": "budget",
                "season": "autumn",       "vibe": "spiritual",
                "family_friendly": None,  "top_k": K,
            },
        }

        all_grades  = self.assessor.grade_all()
        results     = []

        for scenario in SCENARIOS:
            key     = scenario.key
            grades  = all_grades[key]
            payload = payloads[key]

            print(f"\n⏳  Running: {scenario.name}")
            predicted = call_recommend(payload)

            result = ScenarioResult(scenario.name, predicted, grades, K)
            result.print()
            results.append(result)

        # Summary table
        self._print_summary(results)

        # A/B comparison
        self._run_ab_comparison(payloads, all_grades)

        if export:
            self._export(results)

    def _run_ab_comparison(
        self,
        payloads: Dict[str, dict],
        all_grades: Dict[str, Dict[str, int]],
    ) -> None:
        """Compare full hybrid pipeline against semantic-only baseline."""
        print(f"\n\n{'='*65}")
        print("A/B COMPARISON — Baseline (semantic only) vs Full Hybrid")
        print(f"{'='*65}")
        print(f"{'Scenario':<28} {'Baseline nDCG':>14} {'Hybrid nDCG':>12} {'Δ':>7}")
        print("-"*65)

        for scenario in SCENARIOS:
            key     = scenario.key
            grades  = all_grades[key]
            payload = payloads[key]

            baseline_ids = call_recommend_semantic_only(payload)
            hybrid_ids   = call_recommend(payload)

            b_ndcg = self.metrics.graded_ndcg_at_k(baseline_ids, grades, K)
            h_ndcg = self.metrics.graded_ndcg_at_k(hybrid_ids,   grades, K)
            delta  = h_ndcg - b_ndcg
            arrow  = "↑" if delta > 0 else ("↓" if delta < 0 else "=")

            print(f"  {scenario.name[:26]:<26}   {b_ndcg:>10.4f}   {h_ndcg:>10.4f}   "
                  f"{arrow}{abs(delta):.4f}")

    def _print_summary(self, results: List[ScenarioResult]) -> None:
        """Print the dissertation Table 2 — ready to copy in."""
        print(f"\n\n{'='*65}")
        print("SUMMARY TABLE  (copy into dissertation Chapter 5)")
        print(f"{'='*65}")
        print(f"{'Scenario':<30} {'P@10':>6} {'R@10':>6} {'nDCG@10':>9} {'MRR':>7}")
        print("-"*65)
        for r in results:
            name = r.scenario_name[:28]
            print(f"  {name:<28}  {r.p_at_k:>6.4f} {r.r_at_k:>6.4f} "
                  f"{r.ndcg:>9.4f} {r.mrr:>7.4f}")

    def audit(self) -> None:
        """Print grade tables for all scenarios — use in dissertation appendix."""
        for scenario in SCENARIOS:
            self.assessor.print_grade_table(scenario.key)

    def _export(self, results: List[ScenarioResult]) -> None:
        out = {
            "generated_at": datetime.utcnow().isoformat(),
            "k": K,
            "relevance_method": "attribute-based graded (0-3)",
            "scenarios": [r.to_dict() for r in results],
        }
        path = Path(__file__).parent / "results.json"
        path.write_text(json.dumps(out, indent=2))
        print(f"\n✅  Results exported → {path}")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Recommendation benchmark")
    parser.add_argument("--audit",  action="store_true",
                        help="Print grade tables for dissertation appendix")
    parser.add_argument("--export", action="store_true",
                        help="Export results to evaluation/results.json")
    args = parser.parse_args()

    runner = BenchmarkRunner()

    if args.audit:
        runner.audit()
    else:
        runner.run_all(export=args.export)