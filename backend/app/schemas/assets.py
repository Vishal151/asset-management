from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from enum import Enum

class AssetType(str, Enum):
    image = "image"
    video = "video"

class LocationSchema(BaseModel):
    latitude: float
    longitude: float

class DimensionsSchema(BaseModel):
    width: int
    height: int

class AssetBase(BaseModel):
    asset_type: AssetType
    file_name: str
    file_path: str
    file_size: int

class AssetCreate(AssetBase):
    location: Optional[LocationSchema] = None
    dimensions: Optional[DimensionsSchema] = None
    tags: Optional[List[str]] = None
    metadata: Optional[dict] = None

class AssetUpdate(BaseModel):
    asset_type: Optional[AssetType] = None
    file_name: Optional[str] = None
    file_path: Optional[str] = None
    file_size: Optional[int] = None
    location: Optional[LocationSchema] = None
    dimensions: Optional[DimensionsSchema] = None
    tags: Optional[List[str]] = None
    metadata: Optional[dict] = None

class AssetMetadataSchema(BaseModel):
    metadata_content: dict

class AssetInDBBase(AssetBase):
    id: int
    created_at: datetime
    updated_at: datetime
    location: Optional[LocationSchema] = None
    dimensions: Optional[DimensionsSchema] = None
    tags: List[str] = []
    asset_metadata: Optional[AssetMetadataSchema] = None

    class Config:
        orm_mode = True

class AssetResponse(AssetInDBBase):
    pass

class AssetSearch(BaseModel):
    query: str = Field(..., description="Search query string")

class AssetCount(BaseModel):
    image: int
    video: int
