from fastapi import APIRouter

from backend.infrastructure.ml.ranker import rebuild_index
from backend.two_tower import train_two_tower


router = APIRouter()


@router.post("/retrain-ranker")
def retrain_ranker() -> dict:
    """
    Retrains the LightGBM LambdaRank model from current interaction data.
    """

    return rebuild_index()


@router.post("/train-two-tower")
def train_two_tower_collaborative_model() -> dict:
    """
    Trains the two-tower neural collaborative model from current interactions.
    """

    return train_two_tower(epochs=20)
