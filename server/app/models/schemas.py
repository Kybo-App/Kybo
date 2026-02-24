"""
Schemi Pydantic per le risposte dell'API dieta.
Dish.instance_id è un UUID generato automaticamente per identificare univocamente ogni piatto nel client.
"""
from typing import List, Dict, Optional, Set
import uuid
from pydantic import BaseModel, Field

class Ingredient(BaseModel):
    name: str
    qty: str

class Dish(BaseModel):
    instance_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    qty: str
    cad_code: int = Field(default=0)
    is_composed: bool = Field(default=False)
    ingredients: List[Ingredient] = Field(default_factory=list)

class SubstitutionOption(BaseModel):
    name: str
    qty: str

class SubstitutionGroup(BaseModel):
    name: str
    options: List[SubstitutionOption]

class DietConfig(BaseModel):
    """Configurazione dinamica estratta dalla dieta."""
    days: List[str] = Field(default_factory=list)
    meals: List[str] = Field(default_factory=list)
    relaxable_foods: List[str] = Field(default_factory=list)
    week_count: int = 1

class DietResponse(BaseModel):
    plan: Dict[str, Dict[str, List[Dish]]]
    weeks: List[Dict[str, Dict[str, List[Dish]]]] = Field(default_factory=list)
    week_count: int = 1
    substitutions: Dict[str, SubstitutionGroup]
    config: Optional[DietConfig] = None
    allergens: List[str] = Field(default_factory=list)
