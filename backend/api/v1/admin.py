from fastapi import APIRouter

from backend.infrastructure.ml.candidate_retriever import (
    rebuild_index as rebuild_candidate_index,
)
from backend.infrastructure.ml.ranker import rebuild_index as rebuild_ranker_index
from backend.two_tower import train_two_tower


router = APIRouter()


@router.post("/retrain-ranker")
def retrain_ranker() -> dict:
    """
    Retrains the LightGBM LambdaRank model from current interaction data.
    """

    return rebuild_ranker_index()


@router.post("/rebuild-index")
def rebuild_retrieval_index() -> dict:
    """
    Rebuilds the SBERT + FAISS candidate retrieval index from destination data.
    """

    return rebuild_candidate_index()


@router.post("/train-two-tower")
def train_two_tower_collaborative_model() -> dict:
    """
    Trains the two-tower neural collaborative model from current interactions.
    """

    return train_two_tower(epochs=20)
