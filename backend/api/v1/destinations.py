from fastapi import APIRouter, HTTPException
from backend.application.services.destination_detail_service import DestinationDetailService
from backend.application.services.destination_image_service import DestinationImageService

router = APIRouter()
_service = DestinationDetailService()
_image_service = DestinationImageService()


@router.get("")
def list_destinations():
    """Return all destinations."""
    return {"results": [d.model_dump() for d in _service.get_all_destinations()]}


@router.get("/{name}/image")
async def get_destination_image(name: str):
    """Return a reliable image URL for a destination name."""
    return await _image_service.get_image(name)


@router.get("/{destination_id}")
def get_destination(destination_id: str):
    """Return a single destination by ID."""
    dest = _service.get_destination(destination_id)
    if not dest:
        raise HTTPException(status_code=404, detail="Destination not found")
    return dest.model_dump()


@router.get("/{destination_id}/accommodations")
def get_accommodations(destination_id: str):
    """Return accommodations for a destination."""
    accs = _service.get_accommodations(destination_id)
    return {"results": [a.model_dump() for a in accs]}
