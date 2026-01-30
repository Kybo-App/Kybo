import re

# [OPTIMIZATION] Pre-compiled regex patterns (compiled once at module load)
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

    [OPTIMIZATION] Usa regex pre-compilata per migliori performance.
    """
    if not raw_qty: return ""

    raw = raw_qty.lower().strip().replace(',', '.')

    # [OPTIMIZATION] Usa regex pre-compilata con una sola operazione
    match = NUMBER_PATTERN.search(raw)
    if match:
        number = match.group(1)
        # Estrai unit_part rimuovendo il numero trovato (più efficiente di re.sub)
        unit_part = (raw[:match.start()] + raw[match.end():]).strip()
    else:
        number = "1"  # Default a 1 se non c'è numero (es. "a piacere")
        unit_part = raw

    # 2. Mappatura Unità Standard
    std_unit = "pz"  # Default

    # Grammi
    if any(x in unit_part for x in ['gr', 'gramm', 'g.', ' g']):
        std_unit = 'g'
    elif unit_part == 'g':
        std_unit = 'g'

    # Millilitri / Litri
    elif 'ml' in unit_part:
        std_unit = 'ml'
    elif 'l' in unit_part and 'ml' not in unit_part and 'cucchiaio' not in unit_part:
        std_unit = 'l'

    # Unità comuni dieta
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

    # Se non troviamo nulla e c'è un numero, assumiamo "pezzi" o lasciamo vuoto
    if std_unit == 'pz' and not unit_part:
        return number  # Es: "1" mela -> "1"

    return f"{number} {std_unit}"