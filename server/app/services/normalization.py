"""
Funzioni di normalizzazione per nomi dei pasti e quantità degli ingredienti.
NUMBER_PATTERN è compilato una volta al caricamento del modulo per efficienza.
"""
import re

NUMBER_PATTERN = re.compile(r'(\d+(?:\.\d+)?)')

def normalize_meal_name(raw_name: str) -> str:
    """Normalizza i nomi dei pasti (già presente nel tuo codice)"""
    if not raw_name: return "Altro"
    raw = raw_name.lower().strip()
    if 'colazion' in raw and 'second' not in raw: return 'Colazione'
    if 'second' in raw and 'colazion' in raw: return 'Seconda Colazione'
    if 'spuntin' in raw and 'sera' in raw: return 'Spuntino Serale'
    if 'spuntin' in raw: return 'Spuntino'
    if 'pranzo' in raw: return 'Pranzo'
    if 'merenda' in raw: return 'Merenda'
    if 'cena' in raw: return 'Cena'
    return raw.title()

def normalize_quantity(raw_qty: str) -> str:
    """
    Trasforma "100 grammi", "100gr", "1 etto" -> "100 g"
    Trasforma "1 vasetto", "2 vasetti" -> "1 vasetto", "2 vasetto"
    """
    if not raw_qty: return ""

    raw = raw_qty.lower().strip().replace(',', '.')

    match = NUMBER_PATTERN.search(raw)
    if match:
        number = match.group(1)
        unit_part = (raw[:match.start()] + raw[match.end():]).strip()
    else:
        number = "1"
        unit_part = raw

    std_unit = "pz"

    if any(x in unit_part for x in ['gr', 'gramm', 'g.', ' g']):
        std_unit = 'g'
    elif unit_part == 'g':
        std_unit = 'g'

    elif 'ml' in unit_part:
        std_unit = 'ml'
    elif 'l' in unit_part and 'ml' not in unit_part and 'cucchiaio' not in unit_part:
        std_unit = 'l'

    elif 'vasett' in unit_part: std_unit = 'vasetto'
    elif 'cucchiain' in unit_part: std_unit = 'cucchiaino'
    elif 'cucchia' in unit_part: std_unit = 'cucchiaio'
    elif 'tazz' in unit_part: std_unit = 'tazza'
    elif 'bicchier' in unit_part: std_unit = 'bicchiere'
    elif 'fett' in unit_part: std_unit = 'fette'
    elif 'ciotol' in unit_part: std_unit = 'ciotola'
    elif 'pizzic' in unit_part: std_unit = 'pizzico'
    elif 'q.b' in unit_part or 'qb' in unit_part:
        return "q.b."  # Caso speciale senza numero

    if std_unit == 'pz' and not unit_part:
        return number

    return f"{number} {std_unit}"