class EventTypes:
    CLICK       = "click"
    DETAIL_VIEW = "detail_view"
    SAVE        = "save"
    RATING      = "rating"


class BudgetOrder:
    ORDER = ["budget", "medium", "premium"]


class AccessibilityScores:
    MAP = {
        "easy":          1.00,
        "moderate":      0.65,
        "difficult":     0.30,
        "very difficult":0.10,
    }


class DefaultValues:
    DEFAULT_ACTIVITY_LEVEL = 3
    DEFAULT_CULTURE_LEVEL  = 3
    DEFAULT_NATURE_LEVEL   = 3
