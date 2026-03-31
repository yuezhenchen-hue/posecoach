from sqlalchemy import Column, String, Integer, DateTime, Text, Float
from sqlalchemy.sql import func
from app.core.database import Base


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(100), nullable=False, index=True)
    event_type = Column(String(50), nullable=False, index=True)
    event_data = Column(Text, nullable=True)  # JSON string
    app_version = Column(String(20), nullable=True)
    ios_version = Column(String(20), nullable=True)
    device_model = Column(String(50), nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)


class DailyStats(Base):
    """预聚合的每日统计"""
    __tablename__ = "daily_stats"

    id = Column(Integer, primary_key=True, autoincrement=True)
    date = Column(String(10), nullable=False, index=True)  # YYYY-MM-DD
    active_devices = Column(Integer, default=0)
    total_photos = Column(Integer, default=0)
    total_photo_match = Column(Integer, default=0)
    most_used_scene = Column(String(50), nullable=True)
    avg_session_seconds = Column(Float, nullable=True)
