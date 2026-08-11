from datetime import datetime
from typing import List, Literal
from pydantic import BaseModel, Field

class IOC(BaseModel):
    """Indicator of Compromise"""
    type: Literal["ip", "domain", "url", "hash"]
    value: str
    source: str
    confidence: int = Field(ge=0, le=100)
    first_seen: datetime
    last_seen: datetime
    tags: List[str] = []
