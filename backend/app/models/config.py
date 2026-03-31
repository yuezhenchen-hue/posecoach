from sqlalchemy import Column, String, Text, Boolean, DateTime
from sqlalchemy.sql import func
from app.core.database import Base


class AppConfig(Base):
    __tablename__ = "app_configs"

    key = Column(String(100), primary_key=True)
    value = Column(Text, nullable=False)
    description = Column(String(200), nullable=True)
    is_active = Column(Boolean, default=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
