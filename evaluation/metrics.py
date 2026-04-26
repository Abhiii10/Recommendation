"""
evaluation/metrics.py
---------------------
Standard IR metrics supporting both binary and graded relevance.

Binary relevance  : pass relevant as Set[str]  (original interface preserved)
Graded relevance  : pass grades as Dict[str, int] with values 0-3
                    0 = not relevant
                    1 = marginally relevant
                    2 = relevant
                    3 = highly relevant

Graded nDCG is the professional standard used in TREC evaluations.
"""
from __future__ import annotations

import math
from typing import Dict, Sequence, Set, Union


class RankingMetrics:
    # ── Binary metrics (original interface — unchanged) ────────────────────────

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
        actual = self.dcg_at_k(predicted, relevant, k)
        ideal  = sum(1 / math.log2(i + 2) for i in range(min(len(relevant), k)))
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

    # ── Graded metrics (professional standard) ─────────────────────────────────

    def graded_dcg_at_k(
        self,
        predicted: Sequence[str],
        grades: Dict[str, int],
        k: int,
    ) -> float:
        """
        DCG with graded relevance using the standard formula:
            DCG = sum( (2^rel - 1) / log2(rank + 1) )
        This rewards placing highly-relevant items near the top more than
        binary DCG does.
        """
        return sum(
            (2 ** grades.get(item, 0) - 1) / math.log2(i + 2)
            for i, item in enumerate(list(predicted)[:k])
        )

    def graded_ndcg_at_k(
        self,
        predicted: Sequence[str],
        grades: Dict[str, int],
        k: int,
    ) -> float:
        """
        Normalised graded DCG. Ideal DCG is computed by sorting all graded
        items by descending relevance grade.
        """
        actual = self.graded_dcg_at_k(predicted, grades, k)
        ideal_grades = sorted(grades.values(), reverse=True)[:k]
        ideal = sum(
            (2 ** g - 1) / math.log2(i + 2)
            for i, g in enumerate(ideal_grades)
        )
        return (actual / ideal) if ideal > 0 else 0.0

    def graded_precision_at_k(
        self,
        predicted: Sequence[str],
        grades: Dict[str, int],
        k: int,
        threshold: int = 1,
    ) -> float:
        """Precision@K treating items with grade >= threshold as relevant."""
        relevant = {d for d, g in grades.items() if g >= threshold}
        return self.precision_at_k(predicted, relevant, k)

    def graded_recall_at_k(
        self,
        predicted: Sequence[str],
        grades: Dict[str, int],
        k: int,
        threshold: int = 1,
    ) -> float:
        """Recall@K treating items with grade >= threshold as relevant."""
        relevant = {d for d, g in grades.items() if g >= threshold}
        return self.recall_at_k(predicted, relevant, k)

    def graded_mrr(
        self,
        predicted: Sequence[str],
        grades: Dict[str, int],
        threshold: int = 2,
    ) -> float:
        """MRR using grade >= threshold as the relevance cutoff."""
        relevant = {d for d, g in grades.items() if g >= threshold}
        return self.mean_reciprocal_rank(predicted, relevant)

    # ── Inter-annotator agreement ───────────────────────────────────────────────

    def cohens_kappa(
        self,
        annotator_a: Dict[str, int],
        annotator_b: Dict[str, int],
    ) -> float:
        """
        Cohen's Kappa for two annotators over the same destination set.
        Measures how much the agreement exceeds chance.
        Kappa > 0.6  = substantial agreement (acceptable for IR research)
        Kappa > 0.8  = almost perfect agreement
        """
        items = set(annotator_a) & set(annotator_b)
        if not items:
            return 0.0

        n = len(items)
        observed_agree = sum(
            1 for d in items if annotator_a[d] == annotator_b[d]
        ) / n

        grades = sorted({*annotator_a.values(), *annotator_b.values()})
        chance = sum(
            (sum(1 for d in items if annotator_a[d] == g) / n)
            * (sum(1 for d in items if annotator_b[d] == g) / n)
            for g in grades
        )

        return (observed_agree - chance) / (1 - chance) if (1 - chance) > 0 else 1.0