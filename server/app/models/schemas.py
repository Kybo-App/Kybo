from typing import List, Dict, Optional
import uuid  # <--- AGGIUNGI QUESTO IMPORT
from pydantic import BaseModel, Field

class Ingredient(BaseModel):
    name: str
    qty: str

class Dish(BaseModel):
    instance_id: str = Field(default_factory=lambda: str(uuid.uuid4())) # <--- NUOVO CAMPO CRITICO
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

class DietResponse(BaseModel):
    plan: Dict[str, Dict[str, List[Dish]]]
    substitutions: Dict[str, SubstitutionGroup]