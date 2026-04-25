import math
from typing import Sequence, Set


class RankingMetrics:
    """Standard IR metrics for evaluating recommendation quality."""

    def precision_at_k(self, predicted: Sequence[str], relevant: Set[str], k: int) -> float:
        top = list(predicted)[:k]
        if not top:
            return 0.0
        return sum(1 for item in top if item in relevant) / len(top)

    def recall_at_k(self, predicted: Sequence[str], relevant: Set[str], k: int) -> float:
        if not relevant:
            return 0.0
        top = list(predicted)[:k]
        return sum(1 for item in top if item in relevant) / len(relevant)

    def dcg_at_k(self, predicted: Sequence[str], relevant: Set[str], k: int) -> float:
        return sum(
            (1 if item in relevant else 0) / math.log2(i + 2)
            for i, item in enumerate(list(predicted)[:k])
        )

    def ndcg_at_k(self, predicted: Sequence[str], relevant: Set[str], k: int) -> float:
        actual  = self.dcg_at_k(predicted, relevant, k)
        ideal   = sum(1 / math.log2(i + 2) for i in range(min(len(relevant), k)))
        return (actual / ideal) if ideal > 0 else 0.0

    def mean_reciprocal_rank(self, predicted: Sequence[str], relevant: Set[str]) -> float:
        for i, item in enumerate(predicted, start=1):
            if item in relevant:
                return 1.0 / i
        return 0.0

    def average_precision(self, predicted: Sequence[str], relevant: Set[str]) -> float:
        hits = 0
        total_precision = 0.0
        for i, item in enumerate(predicted, start=1):
            if item in relevant:
                hits += 1
                total_precision += hits / i
        return total_precision / len(relevant) if relevant else 0.0
