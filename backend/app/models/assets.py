from sqlalchemy import Column, Integer, String, ForeignKey, Enum, DateTime, BigInteger, func
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB
from geoalchemy2 import Geography
from app.database import Base
import enum

class AssetType(enum.Enum):
    image = "image"
    video = "video"

class Asset(Base):
    __tablename__ = "assets"

    id = Column(Integer, primary_key=True, index=True)
    asset_type = Column(Enum(AssetType), nullable=False)
    file_name = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    file_size = Column(BigInteger, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    location = Column(Geography(geometry_type='POINT', srid=4326), nullable=True)

    dimensions = relationship("AssetDimension", back_populates="asset", uselist=False)
    tags = relationship("Tag", secondary="asset_tags", back_populates="assets")
    asset_metadata = relationship("AssetMetadata", back_populates="asset", uselist=False)

class AssetDimension(Base):
    __tablename__ = "asset_dimensions"

    asset_id = Column(Integer, ForeignKey("assets.id"), primary_key=True)
    width = Column(Integer, nullable=False)
    height = Column(Integer, nullable=False)

    asset = relationship("Asset", back_populates="dimensions")

class Tag(Base):
    __tablename__ = "tags"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

    assets = relationship("Asset", secondary="asset_tags", back_populates="tags")

class AssetTag(Base):
    __tablename__ = "asset_tags"

    asset_id = Column(Integer, ForeignKey("assets.id"), primary_key=True)
    tag_id = Column(Integer, ForeignKey("tags.id"), primary_key=True)

class AssetMetadata(Base):
    __tablename__ = "asset_metadata"

    asset_id = Column(Integer, ForeignKey("assets.id"), primary_key=True)
    metadata_content = Column(JSONB, nullable=False)

    asset = relationship("Asset", back_populates="asset_metadata")
