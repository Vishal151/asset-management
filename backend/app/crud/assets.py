from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from geoalchemy2 import Geography
from shapely.geometry import Point
from app.models.assets import Asset, AssetDimension, AssetTag, Tag, AssetMetadata
from app.schemas.assets import AssetCreate, AssetUpdate
from typing import List, Optional

async def create_asset(db: AsyncSession, asset: AssetCreate):
    db_asset = Asset(**asset.dict(exclude={"tags", "dimensions", "metadata"}))
    if asset.location:
        db_asset.location = Geography(Point(asset.location.longitude, asset.location.latitude))
    db.add(db_asset)
    await db.flush()  # This assigns an id to db_asset

    if asset.dimensions:
        db_dimension = AssetDimension(asset_id=db_asset.id, **asset.dimensions.dict())
        db.add(db_dimension)

    if asset.tags:
        for tag_name in asset.tags:
            tag = await db.execute(select(Tag).where(Tag.name == tag_name))
            tag = tag.scalar_one_or_none()
            if not tag:
                tag = Tag(name=tag_name)
                db.add(tag)
            db_asset_tag = AssetTag(asset_id=db_asset.id, tag_id=tag.id)
            db.add(db_asset_tag)

    if asset.metadata:
        db_metadata = AssetMetadata(asset_id=db_asset.id, metadata_content=asset.metadata)
        db.add(db_metadata)

    await db.commit()
    await db.refresh(db_asset)
    return db_asset

async def get_asset(db: AsyncSession, asset_id: int):
    result = await db.execute(select(Asset).where(Asset.id == asset_id))
    return result.scalar_one_or_none()

async def list_assets(db: AsyncSession, skip: int = 0, limit: int = 100):
    result = await db.execute(select(Asset).offset(skip).limit(limit))
    return result.scalars().all()

async def update_asset(db: AsyncSession, asset_id: int, asset: AssetUpdate):
    result = await db.execute(select(Asset).where(Asset.id == asset_id))
    db_asset = result.scalar_one_or_none()
    if db_asset is None:
        return None

    update_data = asset.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_asset, key, value)

    if asset.location:
        db_asset.location = Geography(Point(asset.location.longitude, asset.location.latitude))

    await db.commit()
    await db.refresh(db_asset)
    return db_asset

async def delete_asset(db: AsyncSession, asset_id: int):
    result = await db.execute(select(Asset).where(Asset.id == asset_id))
    db_asset = result.scalar_one_or_none()
    if db_asset is None:
        return None
    await db.delete(db_asset)
    await db.commit()
    return db_asset

async def search_assets(db: AsyncSession, query: str):
    search_query = f"%{query}%"
    result = await db.execute(
        select(Asset).where(
            Asset.file_name.ilike(search_query) |
            Asset.asset_type.ilike(search_query) |
            Asset.tags.any(Tag.name.ilike(search_query))
        )
    )
    return result.scalars().all()

async def get_nearby_assets(db: AsyncSession, latitude: float, longitude: float, radius: float):
    point = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)
    result = await db.execute(
        select(Asset).where(
            func.ST_DWithin(Asset.location, point, radius)
        ).order_by(func.ST_Distance(Asset.location, point))
    )
    return result.scalars().all()

async def get_asset_counts(db: AsyncSession):
    result = await db.execute(
        select(Asset.asset_type, func.count(Asset.id)).group_by(Asset.asset_type)
    )
    counts = result.all()
    return {asset_type: count for asset_type, count in counts}

async def add_tag_to_asset(db: AsyncSession, asset_id: int, tag_name: str):
    result = await db.execute(select(Asset).where(Asset.id == asset_id))
    db_asset = result.scalar_one_or_none()
    if db_asset is None:
        return {"error": "Asset not found"}

    tag = await db.execute(select(Tag).where(Tag.name == tag_name))
    db_tag = tag.scalar_one_or_none()
    if not db_tag:
        db_tag = Tag(name=tag_name)
        db.add(db_tag)
        await db.commit()

    db_asset_tag = AssetTag(asset_id=asset_id, tag_id=db_tag.id)
    db.add(db_asset_tag)
    await db.commit()
    return {"message": f"Tag '{tag_name}' added to asset {asset_id}"}

async def refresh_asset_cache(db: AsyncSession):
    await db.execute("SELECT refresh_asset_counts()")
    await db.commit()
