from sqlalchemy import Column, String, Integer, Text, Boolean, DateTime, Float
from sqlalchemy.sql import func
from app.core.database import Base


class PoseTemplate(Base):
    __tablename__ = "pose_templates"

    id = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=False)
    scene = Column(String(50), nullable=False, index=True)
    person_count = Column(String(20), nullable=False, default="single")
    difficulty = Column(String(20), nullable=False, default="easy")
    image_url = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    is_premium = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class SceneTip(Base):
    __tablename__ = "scene_tips"

    id = Column(Integer, primary_key=True, autoincrement=True)
    scene = Column(String(50), nullable=False, index=True)
    tip_type = Column(String(30), nullable=False)  # creative, parameter, composition
    content = Column(Text, nullable=False)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
