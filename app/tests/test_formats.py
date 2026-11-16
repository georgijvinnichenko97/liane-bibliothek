"""
Tests für formats.py (Anzeige-Hilfen).

Start im Ordner app:   python -m pytest tests
Ohne pytest geht auch: python tests/test_formats.py
"""
import sys
from datetime import date, datetime
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from formats import count_text, days_text, de_date, de_number, first_value, is_missing, month_label, with_unit


def test_is_missing():
    assert is_missing(None)
    assert is_missing(float("nan"))
    assert is_missing(pd.NaT)
    assert not is_missing(0)
    assert not is_missing("")
    assert not is_missing(date(2026, 11, 6))


def test_de_date():
    assert de_date(date(2026, 11, 6)) == "06.11.2026"
    assert de_date(datetime(2026, 11, 6, 14, 30)) == "06.11.2026"
    assert de_date("2026-11-06") == "06.11.2026"
    assert de_date(None) == ""
    assert de_date(pd.NaT) == ""


def test_de_number():
    assert de_number(75) == "75"
    assert de_number(20.44, 1) == "20,4"
    assert de_number(None) == "–"
    assert de_number(float("nan")) == "–"


def test_with_unit():
    assert with_unit(75, "%") == "75 %"
    assert with_unit(20.4, "Tage", 1) == "20,4 Tage"
    assert with_unit(None, "%") == "–"          # kein "– %"


def test_count_text():
    assert count_text(1, "Ausleihe", "Ausleihen") == "1 Ausleihe"
    assert count_text(3, "Ausleihe", "Ausleihen") == "3 Ausleihen"
    assert count_text(0, "Ausleihe", "Ausleihen") == "0 Ausleihen"
    assert count_text(2.0, "Rückgabe", "Rückgaben") == "2 Rückgaben"


def test_days_text():
    assert days_text(1) == "1 Tag"
    assert days_text(92) == "92 Tage"


def test_month_label():
    assert month_label("2026-05") == "Mai 26"
    assert month_label("2025-12") == "Dez 25"


def test_first_value():
    df = pd.DataFrame([{"title": "Momo", "due_date": None}])
    assert first_value(df, "title") == "Momo"
    assert first_value(df, "due_date", "kein Datum") == "kein Datum"
    assert first_value(df, "gibt_es_nicht", "?") == "?"
    assert first_value(pd.DataFrame(), "title", "leer") == "leer"


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
        print("ok  ", test.__name__)
    print(f"{len(tests)} Tests bestanden")
