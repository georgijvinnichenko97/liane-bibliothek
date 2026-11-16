"""
Lianes Bibliothek (Version 2) - Streamlit-App

Start:  streamlit run app.py   (oder Doppelklick auf start_app.bat)

Die App zeigt nur an und nimmt Eingaben entgegen. Alle Daten liegen in MySQL,
alle Regeln stehen in Triggern und Stored Procedures (sql/04_procedures.sql)
und alle Berechnungen in den Views (sql/03_views.sql).

Aufbau der App:
    app.py      diese Datei: Seite, Seitenleiste, Kopfzeile, Kennzahlen, Reiter
    tabs.py     die sechs Reiter
    design.py   das Aussehen: Stil (CSS) und HTML-Bausteine (Karten, Kennzahlen ...)
    charts.py   die Diagramme
    ui.py       Daten laden, Meldungen, Aktionen
    formats.py  Zahlen und Datumswerte im deutschen Format
    db.py       Verbindung zu MySQL (Views lesen, Procedures aufrufen)
    config.py   Verbindungsdaten
"""
from types import SimpleNamespace

import streamlit as st
import streamlit.components.v1 as components

import db
import design
import tabs
import ui

st.set_page_config(page_title="Lianes Bibliothek · Version 2", page_icon="📚", layout="wide")

# Chrome übersetzt Streamlit-Seiten sonst automatisch (die Seite meldet sich als Englisch).
# Das Skript stellt die Seite auf Deutsch und "nicht übersetzen". Es steht ganz oben,
# damit es so früh wie möglich läuft.
NO_TRANSLATE = """<script>
const d = window.parent.document;
d.documentElement.lang = "de";
d.documentElement.setAttribute("translate", "no");
d.documentElement.classList.add("notranslate");
if (!d.querySelector('meta[name="google"]')) {
  const m = d.createElement("meta"); m.name = "google"; m.content = "notranslate"; d.head.appendChild(m);
}
</script>"""
components.html(NO_TRANSLATE, height=0)
st.markdown(design.CSS, unsafe_allow_html=True)

# Spalten, die es erst in Version 2 der Views gibt. Fehlen sie, ist die Datenbank veraltet.
REQUIRED_COLUMNS = {
    "v_current_loans": {"due_soon", "contact"},
    "v_friend_statistics": {"lend_status"},
    "v_loan_history": {"outcome", "days_late"},
    "v_loans_per_month": {"loans_cumulative"},
}


# ---------------------------------------------------------------------------
# Seitenleiste
# ---------------------------------------------------------------------------
with st.sidebar:
    st.markdown(design.brand(), unsafe_allow_html=True)
    st.markdown(design.steps([
        "Alle Daten und Regeln liegen in **MySQL**.",
        "Die App liest nur **Views** und ruft **7 Stored Procedures** auf.",
        "Ein **Trigger** prüft jede neue Ausleihe.",
        "Fehlermeldungen kommen direkt aus MySQL.",
        "Keine Anmeldung nötig: Benutzer **liane_app_v2** mit minimalen Rechten.",
    ]), unsafe_allow_html=True)
    if st.button("Daten neu laden", width="stretch"):
        ui.refresh()
        st.rerun()
    st.caption("Nach einem Skript in MySQL Workbench hier klicken, dann sind die Zahlen aktuell.")
    st.divider()
    st.caption("Projekt aus dem Data-Analytics-Bootcamp\n\nMySQL 8 · Python · Streamlit · pandas · Altair")


# ---------------------------------------------------------------------------
# Daten laden (nur Views)
# ---------------------------------------------------------------------------
try:
    views = ui.load_views()
except db.DbError as error:
    st.markdown(design.section("Lianes Bibliothek"), unsafe_allow_html=True)
    st.error(f"Die App kann die Daten nicht laden: {error}")
    st.info(f"{ui.connection_help(error)} Danach links auf „Daten neu laden“ klicken.")
    st.stop()

outdated = [name for name, columns in REQUIRED_COLUMNS.items() if not columns <= set(views[name].columns)]
if outdated:
    st.error(f"Diese Views sind veraltet: {', '.join(outdated)}.")
    st.info("In MySQL Workbench sql/03_views.sql (oder sql/00_setup_complete.sql) aus dem Ordner von "
            "Version 2 ausführen, danach links auf „Daten neu laden“ klicken.")
    st.stop()

d = SimpleNamespace(
    kpi=views["v_kpi_overview"],
    books=views["v_book_overview"],
    current=views["v_current_loans"],
    reminders=views["v_reminders"],
    friends=views["v_friend_statistics"],
    history=views["v_loan_history"],
    monthly=views["v_loans_per_month"],
    by_relationship=views["v_punctuality_by_relationship"],
    genres=views["v_genre_statistics"],
    ranking=views["v_book_ranking"],
)
k = d.kpi.iloc[0]


# ---------------------------------------------------------------------------
# Kopfzeile und Kennzahlen (View v_kpi_overview)
# ---------------------------------------------------------------------------
st.markdown(design.hero(k), unsafe_allow_html=True)

# Fester Platz für die Meldung nach einer Aktion. Der Platz ist immer da, auch
# ohne Meldung. So verschiebt sich darunter nichts, wenn die Meldung kommt oder
# geht, und der gerade gewählte Reiter bleibt offen. Ohne den festen Platz
# springt Streamlit nach einer Aktion auf den ersten Reiter zurück.
with st.container():
    ui.show_flash()

st.markdown(design.kpi_cards(k), unsafe_allow_html=True)


# ---------------------------------------------------------------------------
# Reiter
# ---------------------------------------------------------------------------
tab_start, tab_analysis, tab_books, tab_people, tab_history, tab_project = st.tabs(
    ["Übersicht", "Analyse", "Bücher", "Ausleiher", "Verlauf", "Projekt"])

with tab_start:
    tabs.overview(d)
with tab_analysis:
    tabs.analysis(d)
with tab_books:
    tabs.books(d)
with tab_people:
    tabs.people(d)
with tab_history:
    tabs.history(d)
with tab_project:
    tabs.project(d)
