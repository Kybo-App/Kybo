from typing import List, Dict, Optional
from pydantic import BaseModel, Field

class Ingredient(BaseModel):
    name: str
    qty: str

class Dish(BaseModel):
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
    # Structure: { "Lunedì": { "Pranzo": [Dish, Dish] } }
    plan: Dict[str, Dict[str, List[Dish]]]
    # Structure: { "1": SubstitutionGroup }
    substitutions: Dict[str, SubstitutionGroup]