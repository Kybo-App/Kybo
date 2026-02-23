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
    days: List[str] = Field(default_factory=list)  # Giorni della settimana (unici, senza duplicati per settimana)
    meals: List[str] = Field(default_factory=list)  # Tipi di pasto nell'ordine del PDF
    relaxable_foods: List[str] = Field(default_factory=list)  # Frutta/verdura identificati
    week_count: int = 1  # Numero totale di settimane nel piano

class DietResponse(BaseModel):
    plan: Dict[str, Dict[str, List[Dish]]]  # Settimana 1 (backward compat con client esistenti)
    weeks: List[Dict[str, Dict[str, List[Dish]]]] = Field(default_factory=list)  # Tutte le settimane
    week_count: int = 1  # Numero settimane trovate
    substitutions: Dict[str, SubstitutionGroup]
    config: Optional[DietConfig] = None  # Configurazione dinamica opzionale
    allergens: List[str] = Field(default_factory=list)  # Allergeni estratti