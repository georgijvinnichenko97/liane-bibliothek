"""
Das Aussehen der App: Stil (CSS) und kleine HTML-Bausteine.

Hier wird nichts gerechnet und nichts entschieden. Die Funktionen bekommen
fertige Werte aus den Views und machen daraus HTML für st.markdown().
Alle Texte aus der Datenbank laufen durch esc(), damit ein Name wie
"<b>Max</b>" als Text erscheint und nicht als HTML.

Farben (alle mit genug Kontrast, geprüft mit WCAG-Kontrastwerten):
    Blau    #3056D3  Akzent: Knöpfe, aktiver Reiter, Balken
    Orange  #EB6834  "zu spät"
    Grau    #8A94A6  "noch nicht zurück"
    Rot / Gelb / Grün nur für Status (überfällig / bald fällig / pünktlich)
"""
from __future__ import annotations

import html
import re
from datetime import date, datetime

from formats import count_text, days_text, de_date, de_number, is_missing, with_unit

WEEKDAYS = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
MONTH_NAMES = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
               "September", "Oktober", "November", "Dezember"]


def esc(value) -> str:
    """Text sicher in HTML einsetzen."""
    return "" if is_missing(value) else html.escape(str(value))


def md_bold(text: str) -> str:
    """'**Familie** bringt ...' -> '<strong>Familie</strong> bringt ...' (Text vorher escapen)."""
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", esc(text))


# ---------------------------------------------------------------------------
# Symbole (einfache Strich-Symbole, 24 x 24)
# ---------------------------------------------------------------------------
_ICON_PATHS = {
    "book": '<path d="M3.5 6c2.8-1.2 5.6-1 8.5 1v12.5c-2.9-2-5.7-2.2-8.5-1z"/><path d="M20.5 6c-2.8-1.2-5.6-1-8.5 1v12.5c2.9-2 5.7-2.2 8.5-1z"/>',
    "shelf": '<rect x="4" y="4" width="4" height="16" rx="1"/><rect x="10" y="7" width="4" height="13" rx="1"/><path d="M16 6.5l3.6 13"/>',
    "out": '<path d="M7 17L17 7"/><path d="M8.5 7H17v8.5"/>',
    "alert": '<path d="M12 4.5l8.5 15h-17z"/><path d="M12 10v4"/><path d="M12 16.8h.01"/>',
    "check": '<circle cx="12" cy="12" r="8.5"/><path d="M8.2 12.4l2.6 2.6 5-5.4"/>',
    "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "calendar": '<rect x="4" y="5.5" width="16" height="14.5" rx="2"/><path d="M4 10h16"/><path d="M8.5 3.5v4"/><path d="M15.5 3.5v4"/>',
    "users": '<circle cx="9" cy="9" r="3.2"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0"/><circle cx="17" cy="10" r="2.5"/><path d="M15.5 14.2A4.5 4.5 0 0 1 21 18.5"/>',
    "spark": '<path d="M12 3.5l1.9 5.6L19.5 11l-5.6 1.9L12 18.5l-1.9-5.6L4.5 11l5.6-1.9z"/>',
    "database": '<ellipse cx="12" cy="6" rx="7" ry="2.8"/><path d="M5 6v12c0 1.6 3.1 2.8 7 2.8s7-1.2 7-2.8V6"/><path d="M5 12c0 1.6 3.1 2.8 7 2.8s7-1.2 7-2.8"/>',
    "layout": '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M3.5 9.5h17"/><path d="M9 9.5v10"/>',
    "plug": '<path d="M9 3.5v5"/><path d="M15 3.5v5"/><path d="M6.5 8.5h11v3a5.5 5.5 0 0 1-11 0z"/><path d="M12 17v3.5"/>',
    "shield": '<path d="M12 3.5l7 3v5.2c0 4.2-2.9 7.5-7 8.8-4.1-1.3-7-4.6-7-8.8V6.5z"/><path d="M9 12l2.2 2.2L15.5 10"/>',
    "send": '<path d="M20 4L9.5 14.5"/><path d="M20 4l-6.5 16-4-5.5L4 10.5z"/>',
}


def icon(name: str, size: int = 20) -> str:
    return (f'<svg class="lb-icon" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
            f'stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" '
            f'aria-hidden="true">{_ICON_PATHS[name]}</svg>')


# Bücherregal für die Kopfzeile (Deko), wie auf der Titelfolie der Präsentation.
# Ist etwas verliehen, sind zwei Plätze leer (gestrichelt), sonst ist das Regal voll.
_SPINES = [(14, 34, 20, "#3056D3"), (38, 20, 16, "#C7D3F6"), (58, 48, 22, "#1D3FAE"), (84, 28, 18, "#5B7BE0"),
           (106, 40, 20, "#EB6834"), (130, 16, 16, "#F7C3AC"), (150, 54, 22, "#8FA8F0"), (176, 30, 18, "#1D3FAE"),
           (198, 38, 20, "#3056D3"), (222, 24, 16, "#DCE3F5")]
_GAPS = {3, 7}


def shelf_svg(books_out: bool) -> str:
    spines = []
    for i, (x, y, w, color) in enumerate(_SPINES):
        if books_out and i in _GAPS:
            spines.append(f'<rect x="{x}" y="{y}" width="{w}" height="{138 - y}" rx="4" fill="none" '
                          f'stroke="#9AA6BD" stroke-width="2" stroke-dasharray="5 5"/>')
        else:
            spines.append(f'<rect x="{x}" y="{y}" width="{w}" height="{138 - y}" rx="4" fill="{color}"/>')
    return ('<svg class="lb-shelf" viewBox="0 0 260 150" aria-hidden="true">' + "".join(spines)
            + '<rect x="6" y="138" width="248" height="6" rx="3" fill="#0F172A" opacity="0.85"/></svg>')


# ---------------------------------------------------------------------------
# Stil (CSS). Grundfarben und Schrift stehen in .streamlit/config.toml.
# ---------------------------------------------------------------------------
CSS = """<style>
@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@600;700;800&display=swap');
:root {
  --lb-ink: #0F172A; --lb-muted: #5B6475; --lb-faint: #8A94A6; --lb-line: #E4E7EC;
  --lb-card: #FFFFFF; --lb-page: #F4F6FA;
  --lb-blue: #3056D3; --lb-blue-dark: #1D3FAE; --lb-blue-soft: #E8EEFC;
  --lb-red: #B42318; --lb-red-soft: #FEE4E2; --lb-amber: #B54708; --lb-amber-soft: #FEF0C7;
  --lb-green: #067647; --lb-green-soft: #DCFAE6;
  --lb-shadow: 0 1px 2px rgba(16, 24, 40, 0.04), 0 2px 8px rgba(16, 24, 40, 0.05);
  --lb-head: 'Plus Jakarta Sans', 'Inter', 'Segoe UI', sans-serif;
}
.stApp, [data-testid="stAppViewContainer"], [data-testid="stMain"] { background: var(--lb-page); }
[data-testid="stMainBlockContainer"] { max-width: 1340px; padding-top: 2.2rem; padding-bottom: 4rem; }
[data-testid="stHeader"] { background: transparent; }
h1, h2, h3, .lb-head { font-family: var(--lb-head) !important; letter-spacing: -0.015em; color: var(--lb-ink); }

/* Karten: alle Container mit key "card..." und alle Formulare */
[class*="st-key-card"], [data-testid="stForm"] {
  background: var(--lb-card); border: 1px solid var(--lb-line) !important; border-radius: 16px !important;
  box-shadow: var(--lb-shadow); padding: 18px 20px !important;
}
[class*="st-key-card_rem"] { border-left: 4px solid #D92D20 !important; }

/* Reiter als Leiste mit Pillen */
[data-baseweb="tab-list"] {
  gap: 4px; background: var(--lb-card); border: 1px solid var(--lb-line); border-radius: 14px;
  padding: 5px; width: fit-content; box-shadow: var(--lb-shadow); margin-bottom: 10px;
}
[data-baseweb="tab-highlight"], [data-baseweb="tab-border"] { display: none; }
button[role="tab"] { border-radius: 10px !important; padding: 8px 18px !important; height: auto !important; }
button[role="tab"] p { font-weight: 600; font-size: 0.95rem; color: var(--lb-muted); }
button[role="tab"]:hover { background: #F2F4F8; }
button[role="tab"][aria-selected="true"] { background: var(--lb-blue-soft); }
button[role="tab"][aria-selected="true"] p { color: var(--lb-blue-dark); }

/* Knöpfe, Aufklapper, Code-Kästen */
[data-testid^="stBaseButton"] { border-radius: 10px !important; font-weight: 600 !important; }
[data-testid="stExpander"] details { background: var(--lb-card); border-radius: 14px; border-color: var(--lb-line); }
[class*="st-key-card_rem"] [data-testid="stCode"] pre { background: #F8FAFC; border: 1px solid var(--lb-line); border-radius: 12px; }
[class*="st-key-card_rem"] [data-testid="stCode"] code { font-family: 'Inter', 'Segoe UI', sans-serif; font-size: 0.92rem; white-space: pre-wrap; }

/* Zeilen in der Liste "Gerade verliehen" */
.st-key-card_loans [data-testid="stHorizontalBlock"] { padding: 12px 0; border-bottom: 1px solid var(--lb-line); }
.st-key-card_loans [data-testid="stHorizontalBlock"]:last-of-type { border-bottom: none; }

/* Seitenleiste */
[data-testid="stSidebar"], [data-testid="stSidebarContent"] { background: var(--lb-card); }
[data-testid="stSidebar"] { border-right: 1px solid var(--lb-line); }

/* ---- eigene Bausteine ---- */
.lb-icon { flex: none; }
.lb-hero {
  display: flex; justify-content: space-between; align-items: center; gap: 24px;
  background: linear-gradient(120deg, #FFFFFF 0%, #FFFFFF 55%, #EEF2FD 100%);
  border: 1px solid var(--lb-line); border-radius: 22px; box-shadow: var(--lb-shadow);
  padding: 28px 34px; margin-bottom: 18px;
}
.lb-eyebrow { font-size: 0.78rem; font-weight: 700; letter-spacing: 0.09em; text-transform: uppercase; color: var(--lb-blue); margin: 0 0 6px; }
.lb-hero h1 { font-size: 2.3rem; font-weight: 800; margin: 0 0 8px; padding: 0; line-height: 1.15; }
.lb-hero .lb-lead { font-size: 1.08rem; color: var(--lb-muted); margin: 0 0 14px; max-width: 640px; }
.lb-chips { display: flex; flex-wrap: wrap; gap: 8px; }
.lb-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 0.8rem; font-weight: 600; color: var(--lb-muted);
  background: #F2F4F8; border-radius: 999px; padding: 4px 11px; }
.lb-chip.is-blue { background: var(--lb-blue-soft); color: var(--lb-blue-dark); }
.lb-shelf { width: 250px; height: auto; flex: none; }

.lb-kpis { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 14px; margin: 0 0 22px; }
.lb-kpi { background: var(--lb-card); border: 1px solid var(--lb-line); border-radius: 16px; box-shadow: var(--lb-shadow);
  padding: 16px 18px; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
.lb-kpi-top { display: flex; align-items: center; gap: 10px; }
.lb-kpi-icon { width: 34px; height: 34px; border-radius: 10px; display: grid; place-items: center;
  background: var(--lb-blue-soft); color: var(--lb-blue); flex: none; }
.lb-kpi-label { font-size: 0.84rem; font-weight: 600; color: var(--lb-muted); }
.lb-kpi-value { font-family: var(--lb-head); font-size: 2rem; font-weight: 800; color: var(--lb-ink); line-height: 1.1; }
.lb-kpi-value small { font-size: 0.95rem; font-weight: 700; color: var(--lb-muted); margin-left: 3px; }
.lb-kpi-sub { font-size: 0.8rem; color: var(--lb-muted); }
.lb-kpi.is-red { border-color: #FDA29B; background: linear-gradient(180deg, #FFFFFF 0%, #FFF6F5 100%); }
.lb-kpi.is-red .lb-kpi-icon { background: var(--lb-red-soft); color: var(--lb-red); }
.lb-kpi.is-red .lb-kpi-value { color: var(--lb-red); }
.lb-kpi.is-green .lb-kpi-icon { background: var(--lb-green-soft); color: var(--lb-green); }
.lb-kpi.is-amber .lb-kpi-icon { background: var(--lb-amber-soft); color: var(--lb-amber); }
.lb-kpi.is-gray .lb-kpi-icon { background: #F2F4F8; color: var(--lb-muted); }
.lb-meter { height: 6px; border-radius: 999px; background: #EEF0F4; overflow: hidden; margin-top: 2px; }
.lb-meter span { display: block; height: 100%; border-radius: 999px; background: var(--lb-blue); }

.lb-section { display: flex; align-items: center; gap: 10px; margin: 6px 0 12px; }
.lb-section h3 { font-size: 1.2rem; font-weight: 800; margin: 0; padding: 0; }
.lb-section .lb-sub { font-size: 0.9rem; color: var(--lb-muted); }
.lb-count { font-size: 0.78rem; font-weight: 700; border-radius: 999px; padding: 2px 9px; background: #F2F4F8; color: var(--lb-muted); }
.lb-count.is-red { background: var(--lb-red-soft); color: var(--lb-red); }
.lb-count.is-blue { background: var(--lb-blue-soft); color: var(--lb-blue-dark); }

.lb-pill { display: inline-flex; align-items: center; gap: 5px; font-size: 0.78rem; font-weight: 700;
  border-radius: 999px; padding: 3px 10px; white-space: nowrap; }
.lb-pill.is-red { background: var(--lb-red-soft); color: var(--lb-red); }
.lb-pill.is-amber { background: var(--lb-amber-soft); color: var(--lb-amber); }
.lb-pill.is-green { background: var(--lb-green-soft); color: var(--lb-green); }
.lb-pill.is-blue { background: var(--lb-blue-soft); color: var(--lb-blue-dark); }
.lb-pill.is-gray { background: #F2F4F8; color: var(--lb-muted); }

.lb-person { display: flex; align-items: center; gap: 12px; min-width: 0; }
.lb-avatar { width: 38px; height: 38px; border-radius: 50%; display: grid; place-items: center; flex: none;
  font-weight: 700; font-size: 0.85rem; background: var(--lb-blue-soft); color: var(--lb-blue-dark); }
.lb-avatar.is-red { background: var(--lb-red-soft); color: var(--lb-red); }
.lb-title { font-weight: 700; color: var(--lb-ink); font-size: 0.98rem; line-height: 1.3; }
.lb-meta { font-size: 0.84rem; color: var(--lb-muted); line-height: 1.4; }
.lb-row-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; margin-bottom: 4px; }

.lb-loan { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
.lb-loan-top { display: flex; justify-content: space-between; align-items: center; gap: 10px; }
.lb-bar { height: 6px; border-radius: 999px; background: #EEF0F4; overflow: hidden; }
.lb-bar span { display: block; height: 100%; border-radius: 999px; background: var(--lb-blue); }
.lb-bar.is-red span { background: #D92D20; }
.lb-bar.is-amber span { background: #F79009; }
.lb-dates { display: flex; justify-content: space-between; font-size: 0.78rem; color: var(--lb-faint); }

.lb-empty { text-align: center; padding: 26px 20px; border: 1.5px dashed #D0D5DD; border-radius: 16px; background: #FBFCFE; margin-bottom: 18px; }
.lb-empty-icon { width: 46px; height: 46px; margin: 0 auto 10px; border-radius: 14px; display: grid; place-items: center; }
.lb-empty-icon.is-green { background: var(--lb-green-soft); color: var(--lb-green); }
.lb-empty-icon.is-blue { background: var(--lb-blue-soft); color: var(--lb-blue); }
.lb-empty .lb-title { font-size: 1.02rem; }
.lb-empty .lb-meta { margin-top: 3px; }

.lb-list { display: flex; flex-direction: column; }
.lb-list-item { display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 10px 0; border-bottom: 1px solid var(--lb-line); }
.lb-list-item:last-child { border-bottom: none; }

.lb-insights { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-bottom: 18px; }
.lb-insight { display: flex; gap: 12px; align-items: flex-start; background: var(--lb-card); border: 1px solid var(--lb-line);
  border-radius: 14px; box-shadow: var(--lb-shadow); padding: 14px 16px; font-size: 0.92rem; color: var(--lb-ink); line-height: 1.45; }
.lb-insight .lb-kpi-icon { width: 30px; height: 30px; border-radius: 9px; }

.lb-card-title { display: flex; align-items: center; gap: 8px; margin: 0 0 4px; }
.lb-card-title h4 { font-family: var(--lb-head); font-size: 1.02rem; font-weight: 800; margin: 0; padding: 0; color: var(--lb-ink); }
.lb-card-sub { font-size: 0.84rem; color: var(--lb-muted); margin: 0 0 6px; }

.lb-features { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; margin-bottom: 18px; }
.lb-feature { background: var(--lb-card); border: 1px solid var(--lb-line); border-radius: 16px; box-shadow: var(--lb-shadow); padding: 18px 20px; }
.lb-feature .lb-kpi-icon { margin-bottom: 10px; }
.lb-feature p { font-size: 0.9rem; color: var(--lb-muted); margin: 6px 0 0; line-height: 1.5; }
.lb-feature code { font-size: 0.82rem; }

.lb-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
.lb-table th { text-align: left; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--lb-muted);
  padding: 8px 10px; border-bottom: 1px solid var(--lb-line); }
.lb-table td { padding: 10px; border-bottom: 1px solid var(--lb-line); vertical-align: top; color: var(--lb-ink); }
.lb-table tr:last-child td { border-bottom: none; }
.lb-num { display: inline-grid; place-items: center; width: 24px; height: 24px; border-radius: 7px;
  background: var(--lb-blue-soft); color: var(--lb-blue-dark); font-weight: 700; font-size: 0.8rem; }

.lb-brand { display: flex; align-items: center; gap: 10px; margin: 0 0 14px; }
.lb-brand-mark { width: 38px; height: 38px; border-radius: 11px; display: grid; place-items: center; background: var(--lb-blue); color: #FFFFFF; }
.lb-brand-name { font-family: var(--lb-head); font-weight: 800; font-size: 1.05rem; color: var(--lb-ink); line-height: 1.2; }
.lb-brand-sub { font-size: 0.78rem; color: var(--lb-muted); }
.lb-steps { display: flex; flex-direction: column; gap: 10px; margin: 4px 0 16px; }
.lb-step { display: flex; gap: 10px; align-items: flex-start; font-size: 0.86rem; color: var(--lb-ink); line-height: 1.4; }
.lb-step .lb-icon { color: var(--lb-blue); margin-top: 1px; }

@media (max-width: 1200px) { .lb-kpis { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 900px) { .lb-features { grid-template-columns: 1fr; } .lb-shelf { display: none; } }
@media (max-width: 640px) { .lb-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } .lb-hero { padding: 22px; } .lb-hero h1 { font-size: 1.8rem; } }
</style>"""


# ---------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------
def greeting(now: datetime | None = None) -> str:
    hour = (now or datetime.now()).hour
    return "Guten Morgen" if hour < 11 else ("Guten Tag" if hour < 18 else "Guten Abend")


def long_date(day: date | None = None) -> str:
    day = day or date.today()
    return f"{WEEKDAYS[day.weekday()]}, {day.day}. {MONTH_NAMES[day.month - 1]} {day.year}"


def summary_sentence(k) -> str:
    """Ein Satz zur Lage, nur aus den Kennzahlen der View v_kpi_overview."""
    lent, overdue = int(k.books_lent), int(k.loans_overdue)
    if lent == 0:
        return "Alle Bücher stehen im Regal. Bereit für die nächste Ausleihe."
    first = f"{lent} Buch ist gerade unterwegs" if lent == 1 else f"{lent} Bücher sind gerade unterwegs"
    if overdue == 0:
        return f"{first}, alle im Zeitplan."
    return f"{first}, davon {overdue} überfällig."


def hero(k) -> str:
    return (
        '<div class="lb-hero"><div>'
        f'<p class="lb-eyebrow">{esc(long_date())}</p>'
        f'<h1>{greeting()}, Liane</h1>'
        f'<p class="lb-lead">{esc(summary_sentence(k))}</p>'
        '<div class="lb-chips">'
        f'<span class="lb-chip is-blue">{icon("spark", 14)}Version 2</span>'
        f'<span class="lb-chip">{icon("database", 14)}Alle Zahlen live aus MySQL</span>'
        '</div></div>'
        f'{shelf_svg(int(k.books_lent) > 0)}</div>'
    )


def _kpi(icon_name: str, label: str, value: str, sub: str, tone: str = "", extra: str = "") -> str:
    tone_class = f" is-{tone}" if tone else ""
    return (f'<div class="lb-kpi{tone_class}"><div class="lb-kpi-top"><div class="lb-kpi-icon">{icon(icon_name, 18)}</div>'
            f'<div class="lb-kpi-label">{esc(label)}</div></div>'
            f'<div class="lb-kpi-value">{value}</div>{extra}<div class="lb-kpi-sub">{esc(sub)}</div></div>')


def kpi_cards(k) -> str:
    """Die sechs Kennzahlen aus v_kpi_overview als Karten."""
    returned = int(k.loans_returned)
    overdue = int(k.loans_overdue)
    rate = None if is_missing(k.on_time_rate_pct) else float(k.on_time_rate_pct)
    meter = f'<div class="lb-meter"><span style="width:{rate:.0f}%"></span></div>' if rate is not None else ""
    avg = "–" if is_missing(k.avg_days_kept) else f'{de_number(k.avg_days_kept, 1)}<small>Tage</small>'
    cards = [
        _kpi("book", "Bücher gesamt", de_number(k.books_total), "im Katalog"),
        _kpi("shelf", "Im Regal", de_number(k.books_on_shelf),
             f"{de_number(k.books_available)} verleihbar, {de_number(k.books_not_lendable)} nicht verleihbar", "gray"),
        _kpi("out", "Verliehen", de_number(k.books_lent), "gerade unterwegs"),
        _kpi("alert" if overdue else "check", "Überfällig", de_number(overdue),
             "Frist überschritten" if overdue else "alles im Zeitplan", "red" if overdue else "green"),
        _kpi("clock", "Pünktlichkeit", esc(with_unit(rate, "%")),
             f"aus {count_text(returned, 'Rückgabe', 'Rückgaben')}" if returned else "noch keine Rückgabe",
             "green", meter),
        _kpi("calendar", "Ø Leihdauer", avg, "bis zur Rückgabe" if returned else "noch keine Rückgabe", "amber"),
    ]
    return f'<div class="lb-kpis">{"".join(cards)}</div>'


def mini_kpis(items: list[tuple[str, str, str, str, str]]) -> str:
    """Kleine Kennzahl-Karten nebeneinander: (Symbol, Beschriftung, Wert, Untertext, Farbe)."""
    cards = "".join(_kpi(icon_name, label, esc(value), sub, tone) for icon_name, label, value, sub, tone in items)
    return f'<div class="lb-kpis" style="grid-template-columns:repeat({len(items)}, minmax(0, 1fr))">{cards}</div>'


def section(title: str, count=None, tone: str = "", sub: str = "") -> str:
    badge = "" if count is None else f'<span class="lb-count{" is-" + tone if tone else ""}">{esc(count)}</span>'
    subline = f'<span class="lb-sub">{esc(sub)}</span>' if sub else ""
    return f'<div class="lb-section"><h3>{esc(title)}</h3>{badge}{subline}</div>'


def card_title(title: str, icon_name: str | None = None, sub: str = "") -> str:
    ico = f'<span class="lb-kpi-icon" style="width:28px;height:28px;border-radius:8px">{icon(icon_name, 16)}</span>' if icon_name else ""
    subline = f'<p class="lb-card-sub">{esc(sub)}</p>' if sub else ""
    return f'<div class="lb-card-title">{ico}<h4>{esc(title)}</h4></div>{subline}'


def empty_state(icon_name: str, title: str, text: str, tone: str = "blue") -> str:
    return (f'<div class="lb-empty"><div class="lb-empty-icon is-{tone}">{icon(icon_name, 22)}</div>'
            f'<div class="lb-title">{esc(title)}</div><div class="lb-meta">{esc(text)}</div></div>')


def pill(text: str, tone: str = "gray") -> str:
    return f'<span class="lb-pill is-{tone}">{esc(text)}</span>'


def initials(name: str) -> str:
    parts = [p for p in str(name).split() if p]
    return "".join(p[0] for p in parts[:2]).upper() if parts else "?"


def reminder_head(r) -> str:
    """Kopf einer Erinnerungskarte (Zeile aus v_reminders)."""
    return (
        '<div class="lb-row-head"><div class="lb-person">'
        f'<div class="lb-avatar is-red">{esc(initials(r.borrower))}</div>'
        f'<div><div class="lb-title">{esc(r.title)}</div>'
        f'<div class="lb-meta">bei {esc(r.borrower)} · {esc(r.contact)} · Frist {esc(de_date(r.due_date))}</div></div></div>'
        f'{pill(days_text(r.days_overdue) + " überfällig", "red")}</div>'
    )


def loan_status(r) -> tuple[str, str]:
    """(Text, Farbe) für eine offene Ausleihe aus v_current_loans."""
    days = int(r.days_left)
    if days < 0:
        return f"{days_text(-days)} überfällig", "red"
    if days == 0:
        return "heute fällig", "amber"
    if int(r.due_soon) == 1:
        return f"noch {days_text(days)}", "amber"
    return f"noch {days_text(days)}", "blue"


def loan_row(r) -> str:
    """Eine Zeile in "Gerade verliehen": Buch, Person, Fortschritt der Leihfrist, Status."""
    text, tone = loan_status(r)
    borrowed, left = int(r.days_borrowed), int(r.days_left)
    total = borrowed + max(left, 0)
    share = 100 if left < 0 or total == 0 else min(100, round(100 * borrowed / total))
    bar_tone = "" if tone == "blue" else f" is-{tone}"
    return (
        '<div class="lb-loan"><div class="lb-loan-top"><div class="lb-person">'
        f'<div class="lb-avatar">{esc(initials(r.borrower))}</div>'
        f'<div style="min-width:0"><div class="lb-title">{esc(r.title)}</div>'
        f'<div class="lb-meta">{esc(r.borrower)}</div></div></div>{pill(text, tone)}</div>'
        f'<div class="lb-bar{bar_tone}"><span style="width:{share}%"></span></div>'
        f'<div class="lb-dates"><span>seit {esc(de_date(r.loan_date))}</span><span>Frist {esc(de_date(r.due_date))}</span></div></div>'
    )


def soon_list(rows) -> str:
    """Liste "Bald fällig" (Zeilen aus v_current_loans mit due_soon = 1)."""
    items = []
    for r in rows.itertuples():
        text, tone = loan_status(r)
        items.append(f'<div class="lb-list-item"><div><div class="lb-title">{esc(r.title)}</div>'
                     f'<div class="lb-meta">{esc(r.borrower)} · Frist {esc(de_date(r.due_date))}</div></div>'
                     f'{pill(text, tone)}</div>')
    return f'<div class="lb-list">{"".join(items)}</div>'


def insights(texts: list[str]) -> str:
    """Erkenntnisse als Kacheln. Die Texte enthalten **fett** im Markdown-Stil."""
    icons = ["users", "alert", "book", "spark", "shelf"]
    tones = ["green", "red", "", "", "gray"]
    tiles = []
    for i, text in enumerate(texts):
        tone = tones[i % len(tones)]
        tone_class = f" is-{tone}" if tone else ""
        tiles.append(f'<div class="lb-insight lb-kpi{tone_class}" style="flex-direction:row;padding:14px 16px">'
                     f'<div class="lb-kpi-icon">{icon(icons[i % len(icons)], 16)}</div><div>{md_bold(text)}</div></div>')
    return f'<div class="lb-insights">{"".join(tiles)}</div>'


def _code(text: str) -> str:
    """Text escapen und `so` markierte Stellen als Code zeigen."""
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", esc(text))


def features(items: list[tuple[str, str, str]]) -> str:
    """Drei Karten nebeneinander: (Symbol, Titel, Text mit `code`)."""
    cards = []
    for icon_name, title, text in items:
        cards.append(f'<div class="lb-feature"><div class="lb-kpi-icon">{icon(icon_name, 18)}</div>'
                     f'<div class="lb-title">{esc(title)}</div><p>{_code(text)}</p></div>')
    return f'<div class="lb-features">{"".join(cards)}</div>'


def rules_table(rows: list[tuple[str, str, str]]) -> str:
    """Tabelle der 7 Regeln: (Nr., Regel, durchgesetzt durch mit `code`)."""
    body = "".join(
        f'<tr><td><span class="lb-num">{esc(nr)}</span></td><td>{_code(rule)}</td><td>{_code(where)}</td></tr>'
        for nr, rule, where in rows)
    return ('<table class="lb-table"><thead><tr><th>Nr.</th><th>Regel</th><th>Durchgesetzt durch</th></tr></thead>'
            f'<tbody>{body}</tbody></table>')


def brand() -> str:
    return (f'<div class="lb-brand"><div class="lb-brand-mark">{icon("book", 20)}</div>'
            f'<div><div class="lb-brand-name">Lianes Bibliothek</div>'
            f'<div class="lb-brand-sub">Version 2 · {esc(de_date(date.today()))}</div></div></div>')


def steps(items: list[str]) -> str:
    rows = "".join(f'<div class="lb-step">{icon("check", 16)}<span>{md_bold(t)}</span></div>' for t in items)
    return f'<div class="lb-steps">{rows}</div>'
