"""
Die sechs Reiter der App. Jede Funktion zeichnet einen Reiter.

d ist ein Objekt mit den Ergebnissen der Views (siehe app.py):
    d.kpi, d.books, d.current, d.reminders, d.friends, d.history,
    d.monthly, d.by_relationship, d.genres, d.ranking

Die Reiter zeigen nur an und nehmen Eingaben entgegen. Jede Änderung geht
über ui.run_action() an eine Stored Procedure. Das Aussehen (Karten,
Überschriften, Kennzahlen) kommt aus design.py.

Karten: Ein Container mit key="card_..." wird durch das CSS in design.py zur
weißen Karte mit Rahmen und Schatten.
"""
from __future__ import annotations

import inspect

import pandas as pd
import streamlit as st

import charts
import db
import design
import ui
from formats import count_text, de_date, de_number, first_value, is_missing, with_unit

DATE_COLUMN = st.column_config.DateColumn(format="DD.MM.YYYY")

# Lange Erinnerungstexte umbrechen statt abschneiden (gibt es ab Streamlit 1.38)
WRAP = {"wrap_lines": True} if "wrap_lines" in inspect.signature(st.code).parameters else {}


def html(text: str) -> None:
    """HTML aus design.py anzeigen."""
    st.markdown(text, unsafe_allow_html=True)


def show_table(df: pd.DataFrame, dates=(), config: dict | None = None) -> None:
    """Tabelle zeigen. Leere Felder (NULL aus MySQL) erscheinen als "–" statt als "None".

    dates:  Spalten mit Datum. Sie erscheinen als TT.MM.JJJJ.
    config: eigene Spalten-Einstellungen (Fortschrittsbalken, Zahlenformat). Diese Spalten
            bleiben unverändert.
    """
    df = df.copy()
    config = dict(config or {})
    for column in df.columns:
        has_gaps = bool(df[column].isna().any())
        if column in config:
            continue
        if column in dates:
            if has_gaps:   # Datum als Text, damit eine Lücke als "–" erscheinen kann
                df[column] = df[column].map(lambda v: "–" if is_missing(v) else de_date(v))
            else:
                config[column] = DATE_COLUMN
        elif has_gaps:
            if pd.api.types.is_numeric_dtype(df[column]):
                df[column] = df[column].map(lambda v: "–" if is_missing(v) else de_number(v))
            else:
                df[column] = df[column].fillna("–")
    st.dataframe(df, hide_index=True, width="stretch", column_config=config)


def _returned_text(result: pd.DataFrame) -> str:
    return f"„{first_value(result, 'title')}“ ist zurück: {first_value(result, 'result')}."


def _due_text(result: pd.DataFrame, title: str) -> str:
    return f"„{title}“: neue Frist {de_date(first_value(result, 'new_due_date', None))}."


# ---------------------------------------------------------------------------
# Übersicht
# ---------------------------------------------------------------------------
def overview(d) -> None:
    left, right = st.columns([3, 2], gap="large")

    with left:
        overdue = len(d.reminders)
        html(design.section("Überfällig", overdue, "red" if overdue else "", "jetzt nachfragen" if overdue else ""))
        if d.reminders.empty:
            html(design.empty_state("check", "Nichts überfällig", "Alle Bücher sind im Zeitplan.", "green"))
        for r in d.reminders.sort_values("days_overdue", ascending=False).itertuples():
            with st.container(key=f"card_rem_{r.loan_id}"):
                html(design.reminder_head(r))
                st.code(r.reminder_text, language=None, **WRAP)
                if st.button("Ist zurück", key=f"back_{r.loan_id}", icon=":material/check_circle:"):
                    ui.run_action(lambda b=r.book_id: db.return_book(b), _returned_text)

        html(design.section("Gerade verliehen", len(d.current), "blue"))
        if d.current.empty:
            html(design.empty_state("book", "Gerade ist kein Buch unterwegs",
                                    "Rechts unter „Schnell verleihen“ kannst du loslegen."))
        else:
            with st.container(key="card_loans"):
                for r in d.current.sort_values(["due_date", "title"]).itertuples():
                    row = st.columns([6, 1.5, 1.6], vertical_alignment="center")
                    row[0].markdown(design.loan_row(r), unsafe_allow_html=True)
                    if row[1].button("Zurück", key=f"ret_{r.loan_id}", type="primary", width="stretch"):
                        ui.run_action(lambda b=r.book_id: db.return_book(b), _returned_text)
                    if row[2].button("+14 Tage", key=f"ext_{r.loan_id}", width="stretch"):
                        ui.run_action(lambda b=r.book_id: db.extend_loan(b, 14),
                                      lambda res, t=r.title: _due_text(res, t))
            st.caption("Zurück = Buch ist wieder da (MySQL trägt heute als Rückgabedatum ein und bewertet "
                       "pünktlich / zu spät). +14 Tage = Frist verlängern (sp_extend_loan). "
                       "Der Balken zeigt, wie viel der Leihfrist schon vorbei ist.")

    with right:
        html(design.section("Schnell verleihen"))
        available = d.books[d.books["status"] == "verfügbar"].sort_values("title")
        book_labels = {int(r.book_id): f"{r.title} – {r.authors}" for r in available.itertuples()}
        # Der Hinweis hinter dem Namen (lend_status) kommt fertig aus der View v_friend_statistics
        friend_labels = {
            int(r.friend_id): f"{r.friend} ({int(r.open_loans)}/{int(r.max_loans)}"
                              + ("" if r.lend_status == "frei" else f", {r.lend_status}") + ")"
            for r in d.friends.sort_values("friend").itertuples()
        }
        with st.form("quick_lend"):
            book_id = st.selectbox("Buch (nur verfügbare)", options=list(book_labels),
                                   format_func=book_labels.get, index=None, placeholder="Buch wählen")
            friend_id = st.selectbox("An wen?", options=list(friend_labels),
                                     format_func=friend_labels.get, index=None, placeholder="Person wählen")
            days = st.number_input("Leihfrist in Tagen", min_value=1, max_value=90, value=28, step=1)
            submitted = st.form_submit_button("Verleihen", type="primary", width="stretch",
                                              icon=":material/send:")
        if submitted:
            if book_id is None or friend_id is None:
                st.warning("Bitte ein Buch und eine Person auswählen.")
            else:
                ui.run_action(
                    lambda: db.lend_book(book_id, friend_id, days),
                    lambda res: f"„{first_value(res, 'title')}“ an {first_value(res, 'borrower')} verliehen, "
                                f"zurück bis {de_date(first_value(res, 'due_date', None))}.")
        st.caption("Die Regeln prüft MySQL beim Speichern (Trigger auf der Tabelle loans): Buch frei und "
                   "verleihbar, nichts Überfälliges bei der Person, Limit nicht erreicht.")

        soon = d.current[d.current["due_soon"] == 1].sort_values("days_left")
        html(design.section("Bald fällig", len(soon), "", "nächste 7 Tage"))
        if soon.empty:
            html(design.empty_state("calendar", "Nichts wird bald fällig",
                                    "In den nächsten 7 Tagen endet keine Leihfrist."))
        else:
            with st.container(key="card_soon"):
                html(design.soon_list(soon))


# ---------------------------------------------------------------------------
# Analyse (alle Zahlen aus den Views 7 bis 11)
# ---------------------------------------------------------------------------
def _insights(d, rated: pd.DataFrame, never: pd.DataFrame) -> list[str]:
    """Sätze zu den auffälligsten Ergebnissen. Die Zahlen stehen fertig in den Views."""
    insights = []
    if not rated.empty:
        best, worst = rated.iloc[0], rated.iloc[-1]
        insights.append(f"**{best.relationship}** bringt am zuverlässigsten zurück: "
                        f"{de_number(best.on_time_rate_pct)} % pünktlich "
                        f"(aus {count_text(best.returned, 'Rückgabe', 'Rückgaben')}).")
        if len(rated) > 1 and worst.on_time_rate_pct < best.on_time_rate_pct:
            late = ("" if is_missing(worst.avg_days_late)
                    else f", im Schnitt {de_number(worst.avg_days_late, 1)} Tage zu spät")
            insights.append(f"**{worst.relationship}** ist das Sorgenkind: nur "
                            f"{de_number(worst.on_time_rate_pct)} % pünktlich{late}.")
    top_genre = d.genres.sort_values("loan_rank").head(1)
    if not top_genre.empty and top_genre.iloc[0].loans > 0:
        g = top_genre.iloc[0]
        insights.append(f"Beliebtestes Genre ist **{g.genre}** mit {count_text(g.loans, 'Ausleihe', 'Ausleihen')} "
                        f"({de_number(g.share_of_loans_pct)} % aller Ausleihen).")
    top = d.ranking[(d.ranking["loan_rank"] == 1) & (d.ranking["loans"] > 0)].sort_values("title")
    if not top.empty:
        titles = ", ".join(top["title"].head(3))
        if len(top) > 3:
            titles += f" und {len(top) - 3} weitere"
        insights.append(f"Meistgelesen: **{titles}** ({'je ' if len(top) > 1 else ''}"
                        f"{count_text(top.iloc[0].loans, 'Ausleihe', 'Ausleihen')}).")
    insights.append(f"**{len(never)} von {len(d.ranking)} Büchern** wurden noch nie verliehen.")
    return insights


def analysis(d) -> None:
    k = d.kpi.iloc[0]
    rated = d.by_relationship[d.by_relationship["returned"] > 0].sort_values(
        ["on_time_rate_pct", "returned"], ascending=[False, False])
    never = d.ranking[d.ranking["loans"] == 0]

    html(design.section("Erkenntnisse aus den Daten", sub="automatisch aus den Views berechnet"))
    html(design.insights(_insights(d, rated, never)))

    with st.container(key="card_month"):
        html(design.card_title("Ausleihen pro Monat", "calendar", "Jede Säule ist ein Monat, geteilt nach Ergebnis."))
        if d.monthly.empty:
            st.write("Noch keine Ausleihen.")
        else:
            st.altair_chart(charts.loans_per_month(d.monthly), width="stretch")
            ui.source("v_loans_per_month", "Rekursive CTE erzeugt jeden Monat (auch ohne Ausleihe), "
                                           "CASE teilt in pünktlich, zu spät und offen.")

    col_a, col_b = st.columns(2, gap="medium")
    with col_a, st.container(key="card_punct"):
        html(design.card_title("Pünktlichkeit nach Beziehung", "users", "n = Anzahl der Rückgaben. "
                               "Bei kleinem n sagt die Prozentzahl wenig."))
        if rated.empty:
            st.write("Noch keine Rückgaben.")
        else:
            st.altair_chart(charts.punctuality(rated), width="stretch")
            ui.source("v_punctuality_by_relationship", "LEFT JOIN friends/loans, GROUP BY Beziehung, NULLIF gegen /0.")
    with col_b, st.container(key="card_genres"):
        html(design.card_title("Beliebte Genres", "book", "Ausleihen pro Genre mit Anteil an allen Ausleihen."))
        lent_genres = d.genres[d.genres["loans"] > 0]
        if lent_genres.empty:
            st.write("Noch keine Ausleihen.")
        else:
            st.altair_chart(charts.genres(lent_genres), width="stretch")
            ui.source("v_genre_statistics", "Fensterfunktionen: SUM() OVER () für den Anteil, RANK() für den Platz.")

    col_c, col_d = st.columns(2, gap="medium")
    with col_c, st.container(key="card_top"):
        html(design.card_title("Top 10 Bücher", "spark", "Gleich oft verliehen = gleicher Platz."))
        top = d.ranking[d.ranking["loans"] > 0].sort_values(["loans", "title"], ascending=[False, True]).head(10)
        if top.empty:
            st.write("Noch keine Ausleihen.")
        else:
            st.altair_chart(charts.top_books(top), width="stretch")
            ui.source("v_book_ranking", "LEFT JOIN auf loans, COUNT und DENSE_RANK() OVER (ORDER BY ...).")
    with col_d, st.container(key="card_duration"):
        html(design.card_title("Wie lange bleiben Bücher weg?", "clock",
                               f"Gestrichelt: Standard-Leihfrist 28 Tage · Ø {de_number(k.avg_days_kept, 1)} Tage"))
        kept = d.history.loc[d.history["return_date"].notna(), ["days_kept"]]
        if kept.empty:
            st.write("Noch keine Rückgaben.")
        else:
            st.altair_chart(charts.loan_durations(kept), width="stretch")
            st.caption(f"Verspätete Rückgaben sind im Schnitt {de_number(k.avg_days_late, 1)} Tage zu spät.")
            ui.source("v_loan_history", "DATEDIFF(return_date, loan_date) als days_kept.")

    with st.container(key="card_never"):
        html(design.card_title("Noch nie verliehen", "shelf", f"{count_text(len(never), 'Buch', 'Bücher')} "
                               "warten noch auf ihre erste Ausleihe."))
        if never.empty:
            st.write("Jedes Buch war schon mindestens einmal unterwegs.")
        else:
            show_table(never.sort_values("title")[["title", "authors", "genre", "status"]].rename(columns={
                "title": "Titel", "authors": "Autor(en)", "genre": "Genre", "status": "Status"}))


# ---------------------------------------------------------------------------
# Bücher
# ---------------------------------------------------------------------------
BOOK_COLUMNS = {"title": "Titel", "authors": "Autor(en)", "genre": "Genre", "publisher": "Verlag",
                "first_published": "Jahr", "status": "Status", "borrowed_by": "Bei", "due_date": "Frist"}


def books(d) -> None:
    html(design.section("Alle Bücher", len(d.books), "blue"))
    with st.container(key="card_books"):
        col_search, col_filter = st.columns([3, 1])
        search = col_search.text_input("Titel, Autor oder ISBN suchen", placeholder="z. B. Hesse")
        status_filter = col_filter.selectbox("Status", ["Alle", "verfügbar", "ausgeliehen", "nicht verleihbar"])

        if search.strip():
            try:
                shown = db.find_book(search.strip())  # Suche über die Procedure sp_find_book
            except db.DbError as error:
                st.error(str(error))
                shown = d.books.iloc[0:0]
        else:
            shown = d.books.sort_values("title")
        if status_filter != "Alle" and not shown.empty:
            shown = shown[shown["status"] == status_filter]

        show_table(shown[[c for c in BOOK_COLUMNS if c in shown.columns]].rename(columns=BOOK_COLUMNS),
                   dates=["Frist"], config={"Jahr": st.column_config.NumberColumn(format="%d")})
        st.caption(f"{len(shown)} von {len(d.books)} Büchern")

    html(design.section("Rückgabe oder Verlängerung"))
    lent_labels = {
        int(r.book_id): f"{r.title} – bei {r.borrower}, bis {de_date(r.due_date)}"
        for r in d.current.sort_values("title").itertuples()
    }
    if not lent_labels:
        html(design.empty_state("book", "Gerade ist kein Buch verliehen", "Hier erscheint jedes Buch, das unterwegs ist."))
    else:
        with st.container(key="card_return"):
            lent_id = st.selectbox("Verliehenes Buch", options=list(lent_labels), format_func=lent_labels.get)
            b1, b2, b3 = st.columns([1, 1, 2], vertical_alignment="bottom")
            if b1.button("Ist zurück", type="primary", width="stretch"):
                ui.run_action(lambda: db.return_book(lent_id), _returned_text)
            extra = b3.number_input("Tage verlängern", min_value=1, max_value=60, value=14, step=1)
            if b2.button("Verlängern", width="stretch"):
                ui.run_action(lambda: db.extend_loan(lent_id, extra),
                              lambda res: f"Neue Frist: {de_date(first_value(res, 'new_due_date', None))}.")

    all_books = {int(r.book_id): f"{r.title} – {r.authors}" for r in d.books.sort_values("title").itertuples()}

    html(design.section("Mehr"))
    with st.expander("Wer hatte dieses Buch? (Verlauf eines Buches)", icon=":material/history:"):
        picked = st.selectbox("Buch", options=list(all_books), format_func=all_books.get,
                              index=None, placeholder="Buch wählen", key="book_history")
        if picked in all_books:
            own = d.history[d.history["book_id"] == picked].sort_values("loan_date", ascending=False)
            if own.empty:
                st.write("Dieses Buch wurde noch nie verliehen.")
            else:
                show_table(own[["borrower", "loan_date", "due_date", "return_date", "result"]].rename(columns={
                    "borrower": "Person", "loan_date": "Ausgeliehen", "due_date": "Frist",
                    "return_date": "Zurück", "result": "Ergebnis"}), dates=["Ausgeliehen", "Frist", "Zurück"])
                st.caption(f"{count_text(len(own), 'Ausleihe', 'Ausleihen')} · Quelle: View `v_loan_history`")

    with st.expander("Neues Buch erfassen", icon=":material/add_circle:"):
        with st.form("add_book", clear_on_submit=True):
            title = st.text_input("Titel *")
            a1, a2 = st.columns(2)
            author_first = a1.text_input("Vorname des Autors")
            author_last = a2.text_input("Nachname des Autors *")
            g1, g2 = st.columns(2)
            genre = g1.text_input("Genre", placeholder="z. B. Roman")
            publisher = g2.text_input("Verlag")
            y1, y2 = st.columns(2)
            year = y1.number_input("Erstveröffentlichung (Jahr)", min_value=1450, max_value=2100,
                                   value=None, step=1, placeholder="optional")
            isbn = y2.text_input("ISBN (10 oder 13 Ziffern, Bindestriche erlaubt)")
            add_book_clicked = st.form_submit_button("Buch speichern", type="primary")
        if add_book_clicked:
            ui.run_action(lambda: db.add_book(title, author_first, author_last, genre, publisher, year, isbn),
                          lambda res: f"„{first_value(res, 'title')}“ ist jetzt in der Bibliothek.")

    with st.expander("Weiteren Autor zu einem Buch hinzufügen", icon=":material/person_add:"):
        with st.form("add_author", clear_on_submit=True):
            author_book = st.selectbox("Buch", options=list(all_books), format_func=all_books.get,
                                       index=None, placeholder="Buch wählen", key="author_book")
            n1, n2 = st.columns(2)
            extra_first = n1.text_input("Vorname des weiteren Autors")
            extra_last = n2.text_input("Nachname des weiteren Autors *")
            add_author_clicked = st.form_submit_button("Autor hinzufügen", type="primary")
        if add_author_clicked:
            if author_book is None:
                st.warning("Bitte ein Buch auswählen.")
            else:
                ui.run_action(lambda: db.add_author_to_book(author_book, extra_first, extra_last),
                              "Der Autor wurde hinzugefügt.")


# ---------------------------------------------------------------------------
# Ausleiher
# ---------------------------------------------------------------------------
def people(d) -> None:
    html(design.section("Alle Personen", len(d.friends), "blue"))
    with st.container(key="card_people"):
        friend_columns = {"friend": "Name", "relationship": "Beziehung", "open_loans": "Hat gerade",
                          "max_loans": "Max.", "overdue_now": "Überfällig", "lend_status": "Darf ausleihen?",
                          "total_loans": "Ausleihen gesamt", "on_time_rate_pct": "Pünktlich",
                          "avg_days_kept": "Ø Tage"}
        show_table(d.friends.sort_values("friend")[list(friend_columns)].rename(columns=friend_columns),
                   config={
                       "Pünktlich": st.column_config.ProgressColumn(
                           "Pünktlich", min_value=0, max_value=100, format="%d %%",
                           help="Anteil pünktlicher Rückgaben (aus v_friend_statistics)"),
                       "Ø Tage": st.column_config.NumberColumn(format="%.1f"),
                   })
        st.caption("„Darf ausleihen?“ kommt aus der View v_friend_statistics (Regeln 2 und 3).")

    html(design.section("Person ansehen"))
    names = {int(r.friend_id): r.friend for r in d.friends.sort_values("friend").itertuples()}
    with st.container(key="card_person"):
        person = st.selectbox("Person auswählen", options=list(names), format_func=names.get,
                              index=None, placeholder="Person wählen", key="person_detail")
        if person in names:
            row = d.friends[d.friends["friend_id"] == person].iloc[0]
            overdue = int(row.overdue_now)
            html(design.mini_kpis([
                ("out", "Hat gerade", f"{int(row.open_loans)} von {int(row.max_loans)}", row.lend_status, ""),
                ("alert" if overdue else "check", "Überfällig", de_number(overdue),
                 "Frist überschritten" if overdue else "nichts überfällig", "red" if overdue else "green"),
                ("book", "Ausleihen gesamt", de_number(row.total_loans), row.relationship, "gray"),
                ("clock", "Pünktlich", with_unit(row.on_time_rate_pct, "%"),
                 f"aus {count_text(row.returned, 'Rückgabe', 'Rückgaben')}", "green"),
            ]))
            own = d.history[d.history["friend_id"] == person].sort_values("loan_date", ascending=False)
            if own.empty:
                st.write(f"{row.friend} hat noch nichts ausgeliehen.")
            else:
                show_table(own[["title", "loan_date", "due_date", "return_date", "result"]].rename(columns={
                    "title": "Buch", "loan_date": "Ausgeliehen", "due_date": "Frist",
                    "return_date": "Zurück", "result": "Ergebnis"}), dates=["Ausgeliehen", "Frist", "Zurück"])

    active = d.friends[d.friends["total_loans"] > 0]
    with st.container(key="card_readers"):
        html(design.card_title("Wer leiht am meisten?", "users", "Ausleihen gesamt pro Person, mit Beziehung."))
        if active.empty:
            st.write("Noch keine Ausleihen.")
        else:
            st.altair_chart(charts.readers(active), width="stretch")
            ui.source("v_friend_statistics", "LEFT JOIN friends/loans, GROUP BY Person, COUNT(CASE WHEN ...) zählt mit Bedingung.")

    with st.expander("Neue Person anlegen", icon=":material/person_add:"):
        with st.form("add_friend", clear_on_submit=True):
            n1, n2 = st.columns(2)
            first_name = n1.text_input("Vorname *")
            last_name = n2.text_input("Nachname *")
            c1, c2 = st.columns(2)
            email = c1.text_input("E-Mail")
            phone = c2.text_input("Telefon")
            st.caption("Mindestens E-Mail oder Telefon (Regel 6).")
            street = st.text_input("Straße")
            p1, p2 = st.columns([1, 2])
            postal_code = p1.text_input("PLZ")
            city = p2.text_input("Ort")
            r1, r2 = st.columns(2)
            relationship = r1.selectbox("Beziehung", charts.RELATIONSHIPS)
            max_loans = r2.number_input("Max. Bücher gleichzeitig", min_value=1, max_value=10, value=3, step=1)
            add_friend_clicked = st.form_submit_button("Person speichern", type="primary")
        if add_friend_clicked:
            ui.run_action(lambda: db.add_friend(first_name, last_name, email, phone, street, postal_code, city,
                                                relationship, max_loans),
                          lambda res: f"{first_value(res, 'friend')} ist jetzt dabei.")


# ---------------------------------------------------------------------------
# Verlauf
# ---------------------------------------------------------------------------
def history(d) -> None:
    html(design.section("Alle Ausleihen", len(d.history), "blue"))
    with st.container(key="card_history"):
        f1, f2 = st.columns(2)
        person = f1.selectbox("Person", ["Alle"] + sorted(d.history["borrower"].unique()))
        outcome = f2.selectbox("Ergebnis", ["Alle", "pünktlich", "zu spät", "unterwegs", "überfällig"])
        shown = d.history.sort_values("loan_date", ascending=False)
        if person != "Alle":
            shown = shown[shown["borrower"] == person]
        if outcome != "Alle":
            shown = shown[shown["outcome"] == outcome]      # Kategorie kommt fertig aus der View

        columns = {"title": "Buch", "borrower": "Person", "loan_date": "Ausgeliehen", "due_date": "Frist",
                   "return_date": "Zurück", "days_kept": "Tage", "outcome": "Ergebnis",
                   "days_late": "Tage zu spät", "notes": "Notiz"}
        table = shown[list(columns)].rename(columns=columns)
        show_table(table, dates=["Ausgeliehen", "Frist", "Zurück"])
        left, right = st.columns([3, 1], vertical_alignment="center")
        left.caption(f"{len(shown)} von {len(d.history)} Ausleihen")
        right.download_button("Als CSV herunterladen", data=table.to_csv(index=False, sep=";").encode("utf-8-sig"),
                              file_name="lianes_ausleihen.csv", mime="text/csv", width="stretch",
                              icon=":material/download:")


# ---------------------------------------------------------------------------
# Projekt: Aufbau, Datenmodell, Regeln
# ---------------------------------------------------------------------------
RULES = [
    ("1", "Ein Buch ist höchstens an eine Person verliehen", "`UNIQUE` auf `open_book_id`, Trigger"),
    ("2", "Höchstens `max_loans` Bücher pro Person", "Trigger `trg_loans_before_insert`"),
    ("3", "Wer etwas Überfälliges hat, bekommt nichts Neues", "Trigger `trg_loans_before_insert`"),
    ("4", "Leihfrist 28 Tage, verlängerbar", "`sp_lend_book`, `sp_extend_loan`"),
    ("5", "Nicht verleihbare Bücher bleiben im Regal", "`is_lendable`, Trigger `trg_loans_before_insert`"),
    ("6", "Jede Person braucht E-Mail oder Telefon", "`CHECK chk_friends_contact`"),
    ("7", "Was eine Ausleih-Historie hat, wird nicht gelöscht", "`FOREIGN KEY ... RESTRICT`"),
]


def project(d) -> None:
    html(design.section("So ist die App aufgebaut"))
    html(design.features([
        ("layout", "1. Oberfläche",
         "`app.py`, `tabs.py`, `design.py`, `charts.py`: Streamlit zeigt Karten, Tabellen und Diagramme und "
         "nimmt Eingaben entgegen. Keine Regeln, keine Berechnungen."),
        ("plug", "2. Zugriff",
         "`db.py` liest nur Views und ruft nur Stored Procedures auf. Werte gehen immer als Parameter (`%s`) "
         "an MySQL: Schutz vor SQL-Injection."),
        ("database", "3. Daten und Regeln",
         "MySQL: 7 Tabellen in 3. Normalform, 11 CHECK-Constraints, 2 Trigger, 11 Views, 7 Stored Procedures, "
         "App-Benutzer `liane_app_v2` mit minimalen Rechten."),
    ]))

    with st.container(key="card_erd"):
        html(design.card_title("Datenmodell (ER-Diagramm)", "database", "7 Tabellen in 3. Normalform, Krähenfuß-Notation"))
        erd = ui.PROJECT_DIR / "docs" / "erd.png"
        if erd.exists():
            st.image(str(erd))
        else:
            st.info("Das ER-Diagramm liegt in docs/erd.png.")

    with st.container(key="card_rules"):
        html(design.card_title("Regeln, die MySQL selbst prüft", "shield",
                               "Neu in Version 2: Die Regeln 2, 3 und 5 stehen in einem Trigger. Sie gelten "
                               "damit auch bei einem direkten INSERT in MySQL Workbench."))
        html(design.rules_table(RULES))

    v_col, p_col = st.columns(2, gap="medium")
    with v_col, st.container(key="card_views"):
        html(design.card_title("11 Views", "layout", "lesen und rechnen"))
        st.dataframe(pd.DataFrame({
            "View": ["v_book_overview", "v_current_loans", "v_overdue_loans", "v_friend_statistics",
                     "v_loan_history", "v_reminders", "v_kpi_overview", "v_loans_per_month",
                     "v_punctuality_by_relationship", "v_genre_statistics", "v_book_ranking"],
            "Zeigt": ["alle Bücher mit Status", "wer hat gerade was", "überfällige Ausleihen",
                      "Statistik pro Person, darf ausleihen?", "alle Ausleihen mit Ergebnis",
                      "fertige Erinnerungstexte", "Kennzahlen in einer Zeile", "Ausleihen pro Monat, lückenlos",
                      "Pünktlichkeit nach Beziehung", "Ausleihen pro Genre mit Rang", "Rangliste der Bücher"],
        }), hide_index=True, width="stretch")
    with p_col, st.container(key="card_procs"):
        html(design.card_title("7 Procedures und 2 Trigger", "plug", "prüfen und ändern"))
        st.dataframe(pd.DataFrame({
            "Procedure / Trigger": ["sp_add_book", "sp_add_author_to_book", "sp_add_friend", "sp_lend_book",
                                    "sp_return_book", "sp_extend_loan", "sp_find_book",
                                    "trg_loans_before_insert", "trg_loans_before_update"],
            "Macht": ["Buch erfassen (legt Autor, Verlag, Genre bei Bedarf an)", "weiteren Autor zuordnen",
                      "Person anlegen (prüft Kontakt und E-Mail)", "verleihen (Regeln prüft der Trigger)",
                      "Rückgabe mit Ergebnis", "Frist verlängern", "Suche in Titel, Autor und ISBN",
                      "prüft Regeln 1, 2, 3 und 5 bei jeder neuen Ausleihe",
                      "schützt bestehende Ausleihen vor Umhängen"],
        }), hide_index=True, width="stretch")
