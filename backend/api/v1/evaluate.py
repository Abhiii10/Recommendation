"""
Evaluation and training endpoints.

POST /evaluate/generate-synthetic-data   → creates synthetic users + interactions
POST /evaluate/train-ranker              → trains ML ranking model from interactions
POST /evaluate/                          → runs offline evaluation metrics
POST /evaluate/clear-synthetic-data      → removes all synthetic users (cleanup)
"""

from fastapi import APIRouter

from backend.application.dto.requests import EvalRequest, EvalResponse
from backend.infrastructure.ml.synthetic_data import generate_synthetic_interactions
from backend.infrastructure.ml.ranker import RankingModel
from backend.infrastructure.ml.evaluator import evaluate_recommender
from backend.infrastructure.repositories.json_user_repository import JsonUserRepository

router = APIRouter()


@router.post("/generate-synthetic-data")
def generate_synthetic_data(
    n_users: int = 100,
    interactions_per_user: int = 15,
):
    """
    Creates synthetic user profiles and simulated interaction logs.

    Use this because the app has no real deployed users yet.
    Run this before /train-ranker and /evaluate.

    - n_users: number of synthetic user profiles to create (default 100)
    - interactions_per_user: destinations each user interacts with (default 15)
    """
    result = generate_synthetic_interactions(
        n_users=n_users,
        interactions_per_user=interactions_per_user,
    )
    return result


@router.post("/train-ranker")
def train_ranker():
    """
    Trains the ML ranking model (GradientBoostingClassifier) from all
    stored interaction data.

    Requires at least 20 interactions with both positive and negative labels.
    Run /generate-synthetic-data first if no interactions exist.
    """
    ranker = RankingModel()
    result = ranker.train_from_storage()
    return result


@router.post("/", response_model=EvalResponse)
def evaluate(request: EvalRequest):
    """
    Evaluates recommendation quality using synthetic users and pseudo-relevance.

    Metrics returned:
    - precision_at_k : fraction of top-K recommendations that are relevant
    - recall_at_k    : fraction of relevant destinations found in top-K
    - ndcg_at_k      : normalised discounted cumulative gain at K
    - coverage       : fraction of the total catalog recommended across all users
    - diversity      : average pairwise category/activity distance in top-K
    - novelty        : average (1 - popularity) of recommended destinations
    """
    result = evaluate_recommender(
        n_users=request.n_users,
        k=request.k,
    )
    return result


@router.post("/clear-synthetic-data")
def clear_synthetic_data():
    """
    Removes all synthetic users from users.json.
    Useful for resetting before re-generating with different parameters.
    Note: does NOT remove interactions — use with caution.
    """
    user_repo = JsonUserRepository()
    deleted   = user_repo.clear_synthetic()
    return {
        "deleted_users": deleted,
        "message": f"Removed {deleted} synthetic users from storage.",
    }