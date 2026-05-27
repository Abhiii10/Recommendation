class EventTypes:
    RECOMMENDATION_SHOWN = "recommendation_shown"
    CLICK = "click"
    DETAIL_VIEW = "detail_view"
    SAVE = "save"
    RATING = "rating"
    MORE_LIKE_THIS = "more_like_this"
    UNSAVE = "unsave"
    SKIP = "skip"
    DISLIKE = "dislike"
    NOT_INTERESTED = "not_interested"
    SEARCH = "search"
    CHAT_USED = "chat_used"

    @classmethod
    def values(cls) -> set[str]:
        return {
            cls.RECOMMENDATION_SHOWN,
            cls.CLICK,
            cls.DETAIL_VIEW,
            cls.SAVE,
            cls.RATING,
            cls.MORE_LIKE_THIS,
            cls.UNSAVE,
            cls.SKIP,
            cls.DISLIKE,
            cls.NOT_INTERESTED,
            cls.SEARCH,
            cls.CHAT_USED,
        }


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
