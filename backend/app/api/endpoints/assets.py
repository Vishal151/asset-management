from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from geoalchemy2 import Geography
from shapely.geometry import Point
from app.database import get_db
from app.schemas.assets import AssetCreate, AssetUpdate, AssetResponse, AssetSearch
from app.crud import assets as assets_crud
from app.schemas.user import User
from app.api.deps import get_current_active_user
from typing import List, Optional

router = APIRouter()

@router.post("/assets/", response_model=AssetResponse)
async def create_asset(
    asset: AssetCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.create_asset(db, asset)

@router.get("/assets/{asset_id}", response_model=AssetResponse)
async def read_asset(
    asset_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    db_asset = await assets_crud.get_asset(db, asset_id)
    if db_asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return db_asset

@router.get("/assets/", response_model=List[AssetResponse])
async def list_assets(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.list_assets(db, skip=skip, limit=limit)

@router.put("/assets/{asset_id}", response_model=AssetResponse)
async def update_asset(
    asset_id: int,
    asset: AssetUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    db_asset = await assets_crud.update_asset(db, asset_id, asset)
    if db_asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return db_asset

@router.delete("/assets/{asset_id}", response_model=AssetResponse)
async def delete_asset(
    asset_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    db_asset = await assets_crud.delete_asset(db, asset_id)
    if db_asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return db_asset

@router.get("/assets/search/", response_model=List[AssetResponse])
async def search_assets(
    query: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.search_assets(db, query)

@router.get("/assets/nearby/", response_model=List[AssetResponse])
async def get_nearby_assets(
    latitude: float = Query(..., description="Latitude of the center point"),
    longitude: float = Query(..., description="Longitude of the center point"),
    radius: float = Query(1000, description="Search radius in meters"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.get_nearby_assets(db, latitude, longitude, radius)

@router.get("/assets/count/", response_model=dict)
async def get_asset_counts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.get_asset_counts(db)

@router.post("/assets/{asset_id}/tags/{tag_name}")
async def add_tag_to_asset(
    asset_id: int,
    tag_name: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    return await assets_crud.add_tag_to_asset(db, asset_id, tag_name)

@router.get("/assets/cache/refresh")
async def refresh_asset_cache(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    await assets_crud.refresh_asset_cache(db)
    return {"message": "Asset cache refreshed"}
