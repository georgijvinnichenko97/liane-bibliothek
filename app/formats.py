"""
Anzeige-Hilfen: Zahlen, Datumswerte und Texte im deutschen Format.

Hier wird nichts gerechnet und nichts entschieden. Die Funktionen machen nur
aus einem Wert einen lesbaren Text. Sie brauchen weder Streamlit noch MySQL
und lassen sich deshalb einzeln testen (siehe tests/test_formats.py).
"""
from __future__ import annotations

from datetime import date, datetime

import pandas as pd

MONTHS = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]


def is_missing(value) -> bool:
    """True bei None, NaN und NaT (so kommen leere Werte aus MySQL und pandas)."""
    if value is None:
        return True
    try:
        return bool(pd.isna(value))
    except (TypeError, ValueError):
        return False


def de_date(value) -> str:
    """Datum als TT.MM.JJJJ, leerer Text bei fehlendem Wert."""
    if is_missing(value):
        return ""
    if isinstance(value, str):
        value = date.fromisoformat(value[:10])
    if isinstance(value, datetime):
        value = value.date()
    return value.strftime("%d.%m.%Y")


def de_number(value, decimals: int = 0) -> str:
    """Zahl im deutschen Format (Komma statt Punkt), Strich bei fehlendem Wert."""
    if is_missing(value):
        return "–"
    return f"{float(value):.{decimals}f}".replace(".", ",")


def with_unit(value, unit: str, decimals: int = 0) -> str:
    """Zahl mit Einheit, z. B. '75 %'. Nur ein Strich, solange es keinen Wert gibt."""
    return "–" if is_missing(value) else f"{de_number(value, decimals)} {unit}"


def count_text(value, singular: str, plural: str) -> str:
    """Anzahl mit dem passenden Wort: '1 Ausleihe', '3 Ausleihen', '0 Ausleihen'."""
    number = 0 if is_missing(value) else int(value)
    return f"{number} {singular if number == 1 else plural}"


def days_text(value) -> str:
    """'1 Tag', '5 Tage'."""
    return count_text(value, "Tag", "Tage")


def month_label(month: str) -> str:
    """'2026-05' -> 'Mai 26'."""
    year, number = month.split("-")
    return f"{MONTHS[int(number) - 1]} {year[2:]}"


def first_value(df: pd.DataFrame, column: str, default=""):
    """Wert aus der ersten Zeile eines Ergebnisses, oder default."""
    if df is None or df.empty or column not in df.columns:
        return default
    value = df.iloc[0][column]
    return default if is_missing(value) else value
