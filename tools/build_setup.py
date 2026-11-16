"""Baut sql/00_setup_complete.sql aus den Einzeldateien 01 bis 05.

Warum? MySQL Workbench kann eine Datei nicht aus einer anderen heraus starten.
Damit trotzdem EIN Klick für die ganze Einrichtung reicht, gibt es
00_setup_complete.sql. Die Datei wird nicht von Hand gepflegt, sondern mit
diesem Skript erzeugt. So können die Einzeldateien und die Komplett-Datei
nicht auseinanderlaufen.

Aufruf (im Projektordner):   python tools/build_setup.py
"""
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"
PARTS = ["01_schema.sql", "02_master_data.sql", "03_views.sql", "04_procedures.sql", "05_app_user.sql"]

HEADER = """-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 00_setup_complete.sql
-- Inhalt    : 01_schema + 02_master_data + 03_views + 04_procedures
--             + 05_app_user in einer Datei. In MySQL Workbench komplett
--             ausführen (Blitz-Symbol oder Strg+Shift+Enter).
--             Ergebnis: Datenbank liane_library_v2 mit 35 Büchern und
--             12 Personen, 0 Ausleihen. Version 1 bleibt unberührt.
-- Optional  : 06_demo_loans.sql (50 Beispiel-Ausleihen) oder
--             07_demo_one_year.sql (Szenario "Ein Jahr später").
-- Danach    : 08_queries.sql (Abfragen) und 09_tests.sql (Tests).
--
-- Diese Datei wird erzeugt: python tools/build_setup.py
-- Änderungen bitte in den Einzeldateien 01 bis 05 machen.
-- =====================================================================
"""


def build() -> str:
    chunks = [HEADER]
    for part in PARTS:
        body = (SQL_DIR / part).read_text(encoding="utf-8").rstrip("\n")
        line = "-- " + "#" * 69
        chunks.append(f"\n\n{line}\n-- ##  {part}\n{line}\n\n{body}\n")
    return "".join(chunks)


if __name__ == "__main__":
    target = SQL_DIR / "00_setup_complete.sql"
    target.write_text(build(), encoding="utf-8", newline="\n")
    print(f"{target.name} geschrieben ({len(PARTS)} Teile)")
