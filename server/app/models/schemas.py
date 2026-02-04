from typing import List, Dict, Optional, Set
import uuid
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

class DietConfig(BaseModel):
    """Configurazione dinamica estratta dalla dieta."""
    days: List[str] = Field(default_factory=list)  # Giorni della settimana nell'ordine del PDF
    meals: List[str] = Field(default_factory=list)  # Tipi di pasto nell'ordine del PDF
    relaxable_foods: List[str] = Field(default_factory=list)  # Frutta/verdura identificati

class DietResponse(BaseModel):
    plan: Dict[str, Dict[str, List[Dish]]]
    substitutions: Dict[str, SubstitutionGroup]
    config: Optional[DietConfig] = None  # Configurazione dinamica opzionale
    allergens: List[str] = Field(default_factory=list)  # Allergeni estratti