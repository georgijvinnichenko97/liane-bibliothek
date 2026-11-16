"""
Gemeinsame Bausteine der Oberfläche: Daten laden, Meldungen, Aktionen.
"""
from __future__ import annotations

from pathlib import Path

import streamlit as st

import db

PROJECT_DIR = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Daten laden
# ---------------------------------------------------------------------------
@st.cache_data(ttl=60, show_spinner=False)
def load_views() -> dict:
    """Alle Views aus MySQL, für höchstens 60 Sekunden zwischengespeichert.

    Streamlit führt bei jedem Klick das ganze Skript neu aus. Ohne den
    Zwischenspeicher würde jeder Filter und jeder Reiterwechsel alle Views
    neu abfragen. Nach jeder Aktion (verleihen, zurückgeben ...) und über den
    Knopf "Daten neu laden" wird der Speicher geleert: Dann sind die Zahlen
    sofort aktuell.
    """
    return db.read_views()


def refresh() -> None:
    """Zwischenspeicher leeren. Der nächste Aufruf von load_views() fragt MySQL neu."""
    load_views.clear()


def connection_help(error: db.DbError) -> str:
    """Tipp zu einem Verbindungsfehler, passend zum MySQL-Fehlercode."""
    if error.code == db.ERR_NO_SERVER:
        return "Der MySQL-Server läuft nicht. Unter Windows: Dienste öffnen und MySQL80 starten."
    if error.code in (db.ERR_ACCESS_DENIED, db.ERR_DB_ACCESS_DENIED, db.ERR_UNKNOWN_DATABASE):
        return ("Die Datenbank liane_library_v2 oder der App-Benutzer liane_app_v2 fehlt noch. "
                "In MySQL Workbench sql/00_setup_complete.sql aus dem Ordner von Version 2 ausführen.")
    if error.code in (db.ERR_NO_SUCH_TABLE, db.ERR_TABLE_DENIED, db.ERR_PROC_DENIED):
        return ("Die Datenbank ist nicht auf dem neuesten Stand. In MySQL Workbench "
                "sql/00_setup_complete.sql aus dem Ordner von Version 2 ausführen.")
    return "In MySQL Workbench prüfen, ob die Verbindung funktioniert und sql/00_setup_complete.sql gelaufen ist."


# ---------------------------------------------------------------------------
# Meldungen und Aktionen
# ---------------------------------------------------------------------------
def flash(message: str, kind: str = "success") -> None:
    """Meldung merken und nach dem Neuladen der Seite anzeigen."""
    st.session_state["flash"] = (kind, message)


def show_flash() -> None:
    if "flash" in st.session_state:
        kind, message = st.session_state.pop("flash")
        getattr(st, kind)(message)


def run_action(action, success_text) -> None:
    """Führt eine Procedure aus.

    Klappt es: Daten neu laden und eine Erfolgsmeldung zeigen.
    Lehnt MySQL ab: die Meldung aus MySQL unverändert anzeigen.
    success_text ist ein Text oder eine Funktion, die aus dem Ergebnis einen Text macht.
    """
    try:
        result = action()
    except db.DbError as error:
        st.error(str(error))
        if error.is_rule:
            st.caption("Diese Meldung kommt direkt aus MySQL (Trigger oder Stored Procedure).")
        return
    refresh()
    flash(success_text(result) if callable(success_text) else success_text)
    st.rerun()


# ---------------------------------------------------------------------------
# Quelle unter einem Diagramm
# ---------------------------------------------------------------------------
@st.cache_data
def view_sql(name: str) -> str:
    """Holt die Definition einer View aus sql/03_views.sql (nur zum Anzeigen)."""
    try:
        text = (PROJECT_DIR / "sql" / "03_views.sql").read_text(encoding="utf-8")
    except OSError:
        return ""
    start = text.find(f"CREATE OR REPLACE VIEW {name} AS")
    return text[start:text.find(";", start) + 1] if start >= 0 else ""


def source(view: str, explanation: str) -> None:
    """Quelle unter einem Diagramm: welche View, was sie macht, plus SQL zum Aufklappen."""
    st.caption(f"Quelle: View `{view}` · {explanation}")
    sql = view_sql(view)
    if sql:
        with st.expander(f"SQL von {view} anzeigen"):
            st.code(sql, language="sql")
