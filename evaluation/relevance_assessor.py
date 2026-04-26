from __future__ import annotations
 
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
 
 
# ── Scenario definitions ──────────────────────────────────────────────────────
 
@dataclass
class Scenario:
    key: str
    name: str
    activity: str
    budget: str
    season: str
    vibe: str
    family_friendly: Optional[bool]
    min_adventure_level: Optional[int]   # None = no constraint
    min_culture_level:   Optional[int]
    description: str
 
 
SCENARIOS: List[Scenario] = [
    Scenario(
        key="cultural_trekking",
        name="Cultural trekking — medium budget, spring",
        activity="culture",
        budget="medium",
        season="spring",
        vibe="cultural",
        family_friendly=True,
        min_adventure_level=None,
        min_culture_level=4,
        description="Family-friendly cultural experience with moderate trekking, spring season.",
    ),
    Scenario(
        key="high_adventure",
        name="High adventure — premium budget, autumn",
        activity="trekking",
        budget="premium",
        season="autumn",
        vibe="adventure",
        family_friendly=False,
        min_adventure_level=4,
        min_culture_level=None,
        description="Demanding trekking routes for experienced travellers, autumn season.",
    ),
    Scenario(
        key="budget_relaxation",
        name="Budget relaxation — lake & nature, autumn",
        activity="relaxation",
        budget="budget",
        season="autumn",
        vibe="peaceful",
        family_friendly=True,
        min_adventure_level=None,
        min_culture_level=None,
        description="Low-cost peaceful retreat in nature, suitable for families.",
    ),
    Scenario(
        key="family_friendly",
        name="Family-friendly cultural — medium budget, spring",
        activity="culture",
        budget="medium",
        season="spring",
        vibe="cultural",
        family_friendly=True,
        min_adventure_level=None,
        min_culture_level=3,
        description="Safe, accessible cultural destinations for families with children.",
    ),
    Scenario(
        key="pilgrimage_route",
        name="Pilgrimage route — budget, any season",
        activity="pilgrimage",
        budget="budget",
        season=None,          # season-agnostic for pilgrimage
        vibe="spiritual",
        family_friendly=None,
        min_adventure_level=None,
        min_culture_level=3,
        description="Spiritual and heritage sites accessible on a limited budget.",
    ),
]
 
 
# ── Alias expansion ───────────────────────────────────────────────────────────
 
_ACTIVITY_ALIASES: Dict[str, set] = {
    "trekking":    {"trekking", "hiking", "trail", "trek", "high altitude pass crossing",
                    "acclimatization", "mountaineering"},
    "culture":     {"culture", "cultural", "heritage", "traditional", "exploring walled city",
                    "palace tours", "local crafts"},
    "relaxation":  {"relaxation", "quiet", "peaceful", "retreat", "boating", "swimming",
                    "fishing", "picnic"},
    "pilgrimage":  {"pilgrimage", "spiritual", "temple", "monastery visit", "religious",
                    "cave exploration", "cultural study"},
    "photography": {"photography", "viewpoint", "scenic", "panorama"},
    "wildlife":    {"wildlife", "bird watching", "nature walk"},
    "boating":     {"boating", "lake", "waterside", "kayaking"},
}
 
_VIBE_ALIASES: Dict[str, set] = {
    "adventure":   {"adventure", "trekking", "extreme", "high-altitude", "challenging",
                    "remote", "expedition"},
    "cultural":    {"cultural", "culture", "heritage", "traditional", "historic",
                    "newar", "gurung", "thakali"},
    "peaceful":    {"peaceful", "quiet", "retreat", "relaxation", "tranquil", "serene"},
    "spiritual":   {"spiritual", "pilgrimage", "monastery", "temple", "sacred", "religious"},
    "scenic":      {"scenic", "viewpoint", "panorama", "landscape", "nature"},
}
 
 
class RelevanceAssessor:
    """
    Scores every destination in the dataset against every scenario
    using a transparent, reproducible rubric.
    """
 
    def __init__(self, destinations_path: str | Path) -> None:
        with open(destinations_path, encoding="utf-8") as fh:
            self._destinations = json.load(fh)
 
    # ── Public API ────────────────────────────────────────────────────────────
 
    def grade_scenario(self, scenario_key: str) -> Dict[str, int]:
        """
        Returns {dest_id: grade} for every destination, where grade ∈ {0,1,2,3}.
        Only destinations with grade >= 1 are 'relevant' in any sense.
        """
        scenario = self._get_scenario(scenario_key)
        return {
            dest["id"]: self._grade(dest, scenario)
            for dest in self._destinations
        }
 
    def grade_all(self) -> Dict[str, Dict[str, int]]:
        """Returns grades for all scenarios keyed by scenario key."""
        return {s.key: self.grade_scenario(s.key) for s in SCENARIOS}
 
    def relevant_set(
        self,
        scenario_key: str,
        threshold: int = 2,
    ) -> set[str]:
        """Binary relevant set — destinations with grade >= threshold."""
        return {
            d for d, g in self.grade_scenario(scenario_key).items()
            if g >= threshold
        }
 
    def print_grade_table(self, scenario_key: str) -> None:
        """Prints a human-readable grade table for audit / dissertation appendix."""
        scenario = self._get_scenario(scenario_key)
        grades = self.grade_scenario(scenario_key)
        dest_map = {d["id"]: d for d in self._destinations}
 
        print(f"\n{'='*70}")
        print(f"Scenario : {scenario.name}")
        print(f"Criteria : activity={scenario.activity}, budget={scenario.budget}, "
              f"season={scenario.season}, vibe={scenario.vibe}")
        print(f"{'='*70}")
        print(f"{'Grade':<7} {'ID':<12} {'Name':<22} {'Activity':<10} "
              f"{'Season':<8} {'Budget':<9} {'Vibe'}")
        print("-"*70)
 
        for grade in [3, 2, 1, 0]:
            for dest_id, g in sorted(grades.items()):
                if g != grade:
                    continue
                d = dest_map[dest_id]
                a = "✅" if self._activity_match(d, scenario) else "❌"
                s = "✅" if self._season_match(d, scenario) else "❌"
                b = "✅" if self._budget_match(d, scenario) else "❌"
                v = "✅" if self._vibe_match(d, scenario) else "❌"
                print(f"  [{g}]   {dest_id:<12} {d['name']:<22} {a:<10} {s:<8} {b:<9} {v}")
 
    # ── Grading rubric ────────────────────────────────────────────────────────
 
    def _grade(self, dest: dict, scenario: Scenario) -> int:
        """
        Rubric:
          Core criteria  (activity, season, budget, vibe)  → 1 point each
          Bonus criteria (adventure_level, culture_level,
                          family_friendly)                  → can upgrade grade
          Hard block     (activity mismatch + no partial)   → grade = 0
        """
        activity_ok = self._activity_match(dest, scenario)
        season_ok   = self._season_match(dest, scenario)
        budget_ok   = self._budget_match(dest, scenario)
        vibe_ok     = self._vibe_match(dest, scenario)
 
        # Hard block: if activity completely misses, grade = 0
        if not activity_ok:
            return 0
 
        core_score = sum([activity_ok, season_ok, budget_ok, vibe_ok])
 
        # Bonus modifiers
        bonus = 0
        if scenario.min_adventure_level is not None:
            if dest.get("adventure_level", 0) >= scenario.min_adventure_level:
                bonus += 1
        if scenario.min_culture_level is not None:
            if dest.get("culture_level", 0) >= scenario.min_culture_level:
                bonus += 1
        if scenario.family_friendly is True:
            if dest.get("family_friendly") is True:
                bonus += 1
        if scenario.family_friendly is False:
            # Adventure seekers want non-family destinations
            if dest.get("family_friendly") is False:
                bonus += 1
 
        total = core_score + bonus
 
        # Map to 0-3 grade
        if total >= 5:
            return 3
        if total >= 3:
            return 2
        if total >= 1:
            return 1
        return 0
 
    def _activity_match(self, dest: dict, scenario: Scenario) -> bool:
        if not scenario.activity:
            return True
        dest_terms = self._dest_terms(dest)
        query_terms = _ACTIVITY_ALIASES.get(scenario.activity, {scenario.activity})
        return bool(query_terms & dest_terms)
 
    def _season_match(self, dest: dict, scenario: Scenario) -> bool:
        if not scenario.season:
            return True   # season-agnostic scenario
        seasons = {s.lower() for s in dest.get("best_season", [])}
        return scenario.season.lower() in seasons or "year-round" in seasons
 
    def _budget_match(self, dest: dict, scenario: Scenario) -> bool:
        if not scenario.budget:
            return True
        order = ["budget", "medium", "premium"]
        actual    = dest.get("budget_level", "").lower()
        preferred = scenario.budget.lower()
        if actual == preferred:
            return True
        if actual in order and preferred in order:
            return abs(order.index(actual) - order.index(preferred)) == 1
        return False
 
    def _vibe_match(self, dest: dict, scenario: Scenario) -> bool:
        if not scenario.vibe:
            return True
        dest_terms = self._dest_terms(dest)
        query_terms = _VIBE_ALIASES.get(scenario.vibe, {scenario.vibe})
        return bool(query_terms & dest_terms)
 
    @staticmethod
    def _dest_terms(dest: dict) -> set[str]:
        terms: set[str] = set()
        for field in ("activities", "category", "tags"):
            for t in dest.get(field, []):
                terms.add(t.lower().strip())
        return terms
 
    @staticmethod
    def _get_scenario(key: str) -> Scenario:
        for s in SCENARIOS:
            if s.key == key:
                return s
        raise ValueError(f"Unknown scenario key: '{key}'. "
                         f"Available: {[s.key for s in SCENARIOS]}")