"""
Benchmark runner — compares baseline (content-based) vs improved (SBERT+reranker).

Usage:
    python -m evaluation.benchmark

The script calls the live /recommend endpoint twice — once simulating the
baseline (semantic only, weight=1.0) and once with the full pipeline — then
prints a comparison table.
"""

import json
import urllib.request
from evaluation.metrics import RankingMetrics


BASE_URL = "http://127.0.0.1:8000"


def call_recommend(payload: dict) -> list[str]:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE_URL}/recommend",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        body = json.loads(resp.read())
    return [item["id"] for item in body.get("results", [])]


class BenchmarkRunner:
    def __init__(self):
        self.metrics = RankingMetrics()

    def run_scenario(
        self,
        scenario_name: str,
        payload: dict,
        relevant: set[str],
        k: int = 10,
    ) -> None:
        print(f"\n{'='*60}")
        print(f"Scenario: {scenario_name}")
        print(f"Query: activity={payload['activity']}, budget={payload['budget']}, "
              f"season={payload['season']}, vibe={payload['vibe']}")
        print(f"Known relevant destinations: {relevant}")
        print(f"{'='*60}")

        predicted = call_recommend(payload)
        print(f"Top-{k} results: {predicted[:k]}")

        p_at_k  = self.metrics.precision_at_k(predicted, relevant, k)
        r_at_k  = self.metrics.recall_at_k(predicted, relevant, k)
        ndcg    = self.metrics.ndcg_at_k(predicted, relevant, k)
        mrr     = self.metrics.mean_reciprocal_rank(predicted, relevant)
        ap      = self.metrics.average_precision(predicted, relevant)

        print(f"\n  Precision@{k}:  {p_at_k:.4f}")
        print(f"  Recall@{k}:     {r_at_k:.4f}")
        print(f"  NDCG@{k}:       {ndcg:.4f}")
        print(f"  MRR:            {mrr:.4f}")
        print(f"  Avg Precision:  {ap:.4f}")

    def compare(
        self,
        baseline_ids: list[str],
        improved_ids: list[str],
        relevant: set[str],
        k: int = 10,
    ) -> dict:
        """Compare two pre-collected ID lists."""
        return {
            "baseline": {
                "precision": self.metrics.precision_at_k(baseline_ids, relevant, k),
                "recall":    self.metrics.recall_at_k(baseline_ids, relevant, k),
                "ndcg":      self.metrics.ndcg_at_k(baseline_ids, relevant, k),
                "mrr":       self.metrics.mean_reciprocal_rank(baseline_ids, relevant),
            },
            "improved": {
                "precision": self.metrics.precision_at_k(improved_ids, relevant, k),
                "recall":    self.metrics.recall_at_k(improved_ids, relevant, k),
                "ndcg":      self.metrics.ndcg_at_k(improved_ids, relevant, k),
                "mrr":       self.metrics.mean_reciprocal_rank(improved_ids, relevant),
            },
        }


if __name__ == "__main__":
    runner = BenchmarkRunner()

    scenarios = [
        {
            "name": "Cultural trekking — medium budget, spring",
            "payload": {
                "activity": "culture",
                "budget": "medium",
                "season": "spring",
                "vibe": "cultural",
                "family_friendly": True,
                "top_k": 10,
            },
            "relevant": {"dest_001", "dest_015", "dest_018", "dest_003"},
        },
        {
            "name": "High adventure — premium, autumn",
            "payload": {
                "activity": "trekking",
                "budget": "premium",
                "season": "autumn",
                "vibe": "adventure",
                "family_friendly": False,
                "adventure_level": 5,
                "top_k": 10,
            },
            "relevant": {"dest_021", "dest_047", "dest_042", "dest_012"},
        },
        {
            "name": "Budget relaxation — lake & nature",
            "payload": {
                "activity": "relaxation",
                "budget": "budget",
                "season": "autumn",
                "vibe": "peaceful",
                "family_friendly": True,
                "top_k": 10,
            },
            "relevant": {"dest_007", "dest_006", "dest_053"},
        },
    ]

    for s in scenarios:
        runner.run_scenario(s["name"], s["payload"], s["relevant"])

    # Offline comparison example
    print("\n\n--- Offline A/B Comparison ---")
    baseline = ["dest_003", "dest_018", "dest_002", "dest_001", "dest_005"]
    improved = ["dest_001", "dest_015", "dest_018", "dest_003", "dest_016"]
    relevant = {"dest_001", "dest_015", "dest_018"}

    result = runner.compare(baseline, improved, relevant, k=5)
    print(json.dumps(result, indent=2))
