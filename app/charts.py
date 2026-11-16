"""
Diagramme für den Analyse-Bereich (Altair).

Jede Funktion bekommt fertige Daten aus einer View und gibt ein Diagramm
zurück. Gerechnet wird hier nicht, das hat MySQL schon erledigt.
"""
from __future__ import annotations

import altair as alt
import pandas as pd

from formats import de_number, month_label

# Farben passend zum Design (design.py, .streamlit/config.toml)
#   BLUE   alle Balken mit nur einer Reihe, "pünktlich zurück"
#   ORANGE "zu spät zurück" und die Linie bei der Leihfrist
#   GREY   "noch nicht zurück" (bewusst neutral: noch kein Ergebnis)
#   INK    Beschriftungen an den Balken (Schriftfarbe, nie die Balkenfarbe)
# Blau und Orange sind auch für Menschen mit Rot-Grün-Schwäche gut zu
# unterscheiden, und alle drei Farben haben mindestens 3:1 Kontrast zu Weiß.
BLUE, ORANGE, GREY, INK = "#3056D3", "#EB6834", "#7A8496", "#0F172A"
RELATIONSHIPS = ["Freundeskreis", "Familie", "Kollegium", "Nachbarschaft", "Bekanntschaft"]

# Reihenfolge und Namen der drei Ergebnisse im Monats-Diagramm
MONTH_PARTS = {
    "returned_on_time": "pünktlich zurück",
    "returned_late": "zu spät zurück",
    "still_open": "noch nicht zurück",
}


def horizontal_bars(data: pd.DataFrame, value: str, label: str, value_title: str, text: str,
                    tooltip: list, color: str = BLUE, domain=None):
    """Liegende Balken, sortiert nach Wert, mit Beschriftung am Balkenende."""
    x = alt.X(f"{value}:Q", title=value_title)
    if domain:  # Platz rechts für die Beschriftung, Achse aber nur bis 100
        x = alt.X(f"{value}:Q", title=value_title, scale=alt.Scale(domain=domain),
                  axis=alt.Axis(values=[0, 25, 50, 75, 100]))
    base = alt.Chart(data).encode(
        x=x,
        y=alt.Y(f"{label}:N", title=None, sort="-x", axis=alt.Axis(labelLimit=260)),
        tooltip=tooltip,
    )
    bars = base.mark_bar(color=color, cornerRadiusEnd=4)
    labels = base.mark_text(align="left", dx=5, color=INK).encode(text=f"{text}:N")
    return (bars + labels).properties(height=max(36 * len(data), 140))


def loans_per_month(monthly: pd.DataFrame):
    """Gestapelte Säulen: Ausleihen pro Monat, geteilt nach Ergebnis (View v_loans_per_month)."""
    months = monthly.sort_values("month")
    long = months.melt(id_vars=["month", "loans_cumulative"], value_vars=list(MONTH_PARTS),
                       var_name="kind", value_name="count")
    long["result"] = long["kind"].map(MONTH_PARTS)
    long["order"] = long["kind"].map({kind: position for position, kind in enumerate(MONTH_PARTS)})
    long["label"] = long["month"].map(month_label)
    data = long[["label", "result", "order", "count", "loans_cumulative"]]
    # Weiße Linie zwischen den gestapelten Teilen, damit sie klar getrennt sind
    return alt.Chart(data).mark_bar(stroke="#FFFFFF", strokeWidth=1.5).encode(
        x=alt.X("label:O", title=None, sort=[month_label(m) for m in months["month"]],
                axis=alt.Axis(labelAngle=0)),
        y=alt.Y("count:Q", title="Ausleihen"),
        color=alt.Color("result:N", title=None,
                        scale=alt.Scale(domain=list(MONTH_PARTS.values()), range=[BLUE, ORANGE, GREY]),
                        legend=alt.Legend(orient="top")),
        order=alt.Order("order:Q"),
        tooltip=[alt.Tooltip("label:O", title="Monat"), alt.Tooltip("result:N", title="Ergebnis"),
                 alt.Tooltip("count:Q", title="Anzahl"),
                 alt.Tooltip("loans_cumulative:Q", title="Ausleihen bisher insgesamt")],
    ).properties(height=300)


def punctuality(rated: pd.DataFrame):
    """Pünktlichkeit nach Beziehung (View v_punctuality_by_relationship)."""
    data = rated[["relationship", "on_time_rate_pct", "returned", "people"]].copy()
    data["text"] = [f"{de_number(r.on_time_rate_pct)} %  (n = {int(r.returned)})" for r in data.itertuples()]
    return horizontal_bars(
        data, "on_time_rate_pct", "relationship", "pünktlich zurückgegeben in %", "text",
        tooltip=[alt.Tooltip("relationship:N", title="Beziehung"),
                 alt.Tooltip("on_time_rate_pct:Q", title="pünktlich %"),
                 alt.Tooltip("returned:Q", title="Rückgaben"),
                 alt.Tooltip("people:Q", title="Personen")],
        domain=[0, 125])


def genres(genre_stats: pd.DataFrame):
    """Ausleihen pro Genre (View v_genre_statistics)."""
    data = genre_stats[["genre", "loans", "share_of_loans_pct", "books"]].copy()
    data["text"] = [f"{int(r.loans)}  ({de_number(r.share_of_loans_pct)} %)" for r in data.itertuples()]
    return horizontal_bars(
        data, "loans", "genre", "Ausleihen", "text",
        tooltip=[alt.Tooltip("genre:N", title="Genre"), alt.Tooltip("loans:Q", title="Ausleihen"),
                 alt.Tooltip("share_of_loans_pct:Q", title="Anteil %"),
                 alt.Tooltip("books:Q", title="Bücher im Genre")])


def top_books(ranking: pd.DataFrame):
    """Die meistverliehenen Bücher (View v_book_ranking)."""
    data = ranking[["title", "authors", "loans", "loan_rank"]].copy()
    data["text"] = [f"{int(r.loans)}×  (Platz {int(r.loan_rank)})" for r in data.itertuples()]
    return horizontal_bars(
        data, "loans", "title", "Ausleihen", "text",
        tooltip=[alt.Tooltip("title:N", title="Titel"), alt.Tooltip("authors:N", title="Autor(en)"),
                 alt.Tooltip("loans:Q", title="Ausleihen")])


def loan_durations(kept: pd.DataFrame, standard_days: int = 28):
    """Histogramm der Leihdauer in 7-Tage-Schritten, mit Linie bei der Standard-Leihfrist."""
    histogram = alt.Chart(kept[["days_kept"]]).mark_bar(color=BLUE, cornerRadiusEnd=3).encode(
        x=alt.X("days_kept:Q", bin=alt.Bin(step=7), title="Tage bis zur Rückgabe (in 7-Tage-Schritten)"),
        y=alt.Y("count():Q", title="Ausleihen"),
        tooltip=[alt.Tooltip("count():Q", title="Ausleihen")],
    )
    deadline = alt.Chart(pd.DataFrame({"frist": [standard_days]})).mark_rule(
        color=ORANGE, strokeDash=[6, 4], size=2).encode(x="frist:Q")
    return (histogram + deadline).properties(height=300)


def readers(friends: pd.DataFrame):
    """Wer leiht am meisten? (View v_friend_statistics)

    Die Beziehung steht als Text neben dem Namen, nicht als Farbe. Fünf Farben
    nebeneinander wären schwer auseinanderzuhalten, Text liest jeder.
    """
    data = friends[["friend", "relationship", "total_loans", "open_loans"]].copy()
    data["label"] = data["friend"] + " · " + data["relationship"]
    data["text"] = [str(int(n)) for n in data["total_loans"]]
    return horizontal_bars(
        data, "total_loans", "label", "Ausleihen gesamt", "text",
        tooltip=[alt.Tooltip("friend:N", title="Name"), alt.Tooltip("relationship:N", title="Beziehung"),
                 alt.Tooltip("total_loans:Q", title="Ausleihen gesamt"),
                 alt.Tooltip("open_loans:Q", title="hat gerade")])
