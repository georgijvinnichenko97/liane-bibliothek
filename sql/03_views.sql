-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 03_views.sql
-- Inhalt    : 11 Views (gespeicherte Abfragen) für Lianes tägliche Fragen
-- Voraussetzung: 01_schema.sql und 02_master_data.sql
-- =====================================================================
--
-- Eine View ist eine gespeicherte SELECT-Abfrage, die man wie eine
-- Tabelle benutzen kann:  SELECT * FROM v_current_loans;
-- Sie speichert keine eigenen Daten, sondern rechnet bei jedem Aufruf
-- neu. Deshalb ist der Status "ausgeliehen" immer aktuell.
--
-- Für den Alltag (Views 1 bis 6):
--   v_book_overview      alle Bücher mit Autoren und Status
--   v_current_loans      wer hat gerade welches Buch?
--   v_overdue_loans      welche Bücher sind überfällig?
--   v_friend_statistics  wer leiht wie viel, wer gibt pünktlich zurück?
--   v_loan_history       alle Ausleihen mit Ergebnis (pünktlich / zu spät)
--   v_reminders          fertige Erinnerungstexte für Überfälliges
--
-- Für die Analyse (Views 7 bis 11):
--   v_kpi_overview                 alle Kennzahlen in einer Zeile
--   v_loans_per_month              Ausleihen pro Monat, lückenlos
--   v_punctuality_by_relationship  Pünktlichkeit nach Beziehung
--   v_genre_statistics             Ausleihen pro Genre mit Anteil und Rang
--   v_book_ranking                 Rangliste der Bücher nach Ausleihen
--
-- Neu in Version 2 (die Namen der Views sind gleich geblieben):
--   * Kategorie und Zahl stehen in getrennten Spalten: v_loan_history hat
--     outcome ('pünktlich', 'zu spät', ...) und days_late (Zahl). Die App
--     muss keinen Text mehr zerlegen.
--   * v_loans_per_month zeigt auch Monate ohne Ausleihe (mit 0) und eine
--     laufende Summe.
--   * v_friend_statistics sagt direkt, ob jemand ausleihen darf
--     (lend_status). Die Regel steht damit nicht mehr zusätzlich in Python.
--   * v_kpi_overview liest jede Tabelle nur noch einmal.
-- =====================================================================

USE liane_library_v2;


-- ---------------------------------------------------------------------
-- View 1: Bücherübersicht mit Status
--   status = 'ausgeliehen' | 'verfügbar' | 'nicht verleihbar'
--   Mehrere Autoren werden mit GROUP_CONCAT zu einem Text verbunden.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_book_overview AS
SELECT
    b.book_id,
    b.title,
    (SELECT GROUP_CONCAT(CONCAT_WS(' ', a.first_name, a.last_name)
                         ORDER BY ba.author_order SEPARATOR ', ')
       FROM book_authors ba
       JOIN authors a ON a.author_id = ba.author_id
      WHERE ba.book_id = b.book_id)                  AS authors,
    g.genre_name                                     AS genre,
    p.publisher_name                                 AS publisher,
    b.first_published,
    b.language_code,
    b.isbn,
    CASE
        WHEN l.loan_id IS NOT NULL THEN 'ausgeliehen'
        WHEN b.is_lendable = 0     THEN 'nicht verleihbar'
        ELSE 'verfügbar'
    END                                              AS status,
    l.friend_id                                      AS borrower_id,
    CONCAT(f.first_name, ' ', f.last_name)           AS borrowed_by,
    l.due_date
FROM books b
LEFT JOIN genres     g ON g.genre_id     = b.genre_id
LEFT JOIN publishers p ON p.publisher_id = b.publisher_id
LEFT JOIN loans      l ON l.book_id      = b.book_id
                      AND l.return_date IS NULL      -- nur die offene Ausleihe
LEFT JOIN friends    f ON f.friend_id    = l.friend_id;


-- ---------------------------------------------------------------------
-- View 2: Aktuelle Ausleihen - wer hat gerade welches Buch?
--   days_borrowed = seit wie vielen Tagen das Buch weg ist
--   days_left     = Tage bis zur Frist (negativ = überfällig)
--   days_overdue  = wie viele Tage die Frist überschritten ist (sonst 0)
--   due_soon      = 1, wenn die Frist in den nächsten 7 Tagen endet
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_current_loans AS
SELECT
    l.loan_id,
    b.book_id,
    b.title,
    f.friend_id,
    f.first_name,
    CONCAT(f.first_name, ' ', f.last_name)          AS borrower,
    f.email,
    f.phone,
    COALESCE(f.email, f.phone)                      AS contact,
    l.loan_date,
    l.due_date,
    DATEDIFF(CURDATE(), l.loan_date)                AS days_borrowed,
    DATEDIFF(l.due_date, CURDATE())                 AS days_left,
    GREATEST(DATEDIFF(CURDATE(), l.due_date), 0)    AS days_overdue,
    CASE
        WHEN l.due_date < CURDATE() THEN 'überfällig'
        ELSE 'läuft'
    END                                             AS loan_status,
    CASE
        WHEN DATEDIFF(l.due_date, CURDATE()) BETWEEN 0 AND 7 THEN 1
        ELSE 0
    END                                             AS due_soon,
    l.notes
FROM loans l
JOIN books   b ON b.book_id   = l.book_id
JOIN friends f ON f.friend_id = l.friend_id
WHERE l.return_date IS NULL;


-- ---------------------------------------------------------------------
-- View 3: Überfällige Ausleihen (baut auf View 2 auf)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_overdue_loans AS
SELECT
    loan_id,
    book_id,
    title,
    friend_id,
    first_name,
    borrower,
    email,
    phone,
    contact,
    loan_date,
    due_date,
    days_overdue
FROM v_current_loans
WHERE days_overdue > 0;


-- ---------------------------------------------------------------------
-- View 4: Statistik pro Ausleiher
--   Schritt 1 (per_friend): pro Person zählen. LEFT JOIN, damit auch
--   Personen ohne Ausleihe erscheinen (mit 0).
--   Schritt 2: lend_status sagt, ob die Person gerade etwas bekommt:
--     'hat Überfälliges' (Regel 3), 'Limit erreicht' (Regel 2), 'frei'
--   on_time_rate_pct = Anteil der pünktlich zurückgegebenen Bücher in %
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_friend_statistics AS
WITH per_friend AS (
    SELECT
        f.friend_id,
        CONCAT(f.first_name, ' ', f.last_name)                              AS friend,
        f.relationship,
        f.max_loans,
        COUNT(l.loan_id)                                                    AS total_loans,
        COUNT(CASE WHEN l.loan_id IS NOT NULL AND l.return_date IS NULL
                   THEN 1 END)                                              AS open_loans,
        COUNT(CASE WHEN l.return_date IS NULL AND l.due_date < CURDATE()
                   THEN 1 END)                                              AS overdue_now,
        COUNT(l.return_date)                                                AS returned,
        COUNT(CASE WHEN l.return_date > l.due_date THEN 1 END)              AS returned_late,
        ROUND(AVG(DATEDIFF(l.return_date, l.loan_date)), 1)                 AS avg_days_kept
    FROM friends f
    LEFT JOIN loans l ON l.friend_id = f.friend_id
    GROUP BY f.friend_id, f.first_name, f.last_name, f.relationship, f.max_loans
)
SELECT
    friend_id,
    friend,
    relationship,
    max_loans,
    total_loans,
    open_loans,
    overdue_now,
    returned,
    returned_late,
    ROUND(100 * (returned - returned_late) / NULLIF(returned, 0), 0)        AS on_time_rate_pct,
    avg_days_kept,
    CASE
        WHEN overdue_now > 0         THEN 'hat Überfälliges'
        WHEN open_loans >= max_loans THEN 'Limit erreicht'
        ELSE 'frei'
    END                                                                     AS lend_status
FROM per_friend;


-- ---------------------------------------------------------------------
-- View 5: Verlauf aller Ausleihen mit Ergebnis
--   outcome   = Kategorie: 'pünktlich' | 'zu spät' | 'unterwegs' | 'überfällig'
--   days_late = Tage über der Frist (0, wenn pünktlich oder noch in der Frist)
--   result    = fertiger Text für die Anzeige, z. B. '3 Tage zu spät'
--   days_kept = Leihdauer in Tagen (bei offenen Ausleihen bis heute)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_loan_history AS
WITH rated AS (
    SELECT
        l.loan_id,
        l.book_id,
        l.friend_id,
        l.loan_date,
        l.due_date,
        l.return_date,
        l.notes,
        GREATEST(DATEDIFF(COALESCE(l.return_date, CURDATE()), l.due_date), 0)   AS days_late
    FROM loans l
)
SELECT
    r.loan_id,
    b.book_id,
    b.title,
    f.friend_id,
    CONCAT(f.first_name, ' ', f.last_name)  AS borrower,
    r.loan_date,
    r.due_date,
    r.return_date,
    CASE
        WHEN r.return_date IS NULL AND r.days_late > 0 THEN 'überfällig'
        WHEN r.return_date IS NULL                     THEN 'unterwegs'
        WHEN r.days_late > 0                           THEN 'zu spät'
        ELSE 'pünktlich'
    END                                     AS outcome,
    r.days_late,
    CASE
        WHEN r.return_date IS NULL AND r.days_late > 0 THEN 'überfällig'
        WHEN r.return_date IS NULL                     THEN 'unterwegs'
        WHEN r.days_late = 1                           THEN '1 Tag zu spät'
        WHEN r.days_late > 1                           THEN CONCAT(r.days_late, ' Tage zu spät')
        ELSE 'pünktlich'
    END                                     AS result,
    DATEDIFF(COALESCE(r.return_date, CURDATE()), r.loan_date)
                                            AS days_kept,
    r.notes
FROM rated r
JOIN books   b ON b.book_id   = r.book_id
JOIN friends f ON f.friend_id = r.friend_id;


-- ---------------------------------------------------------------------
-- View 6: Erinnerungstexte für alle überfälligen Bücher
--   Die App zeigt den Text nur an, Liane kopiert ihn in ihre Nachricht.
--   Der Vorname kommt direkt aus der Tabelle friends (auch bei
--   Doppelnamen wie "Anna Lena" richtig).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_reminders AS
SELECT
    loan_id,
    book_id,
    title,
    friend_id,
    borrower,
    contact,
    due_date,
    days_overdue,
    CONCAT('Hallo ', first_name,
           ', hast du noch an "', title, '" gedacht? ',
           'Die Rückgabe war am ', DATE_FORMAT(due_date, '%d.%m.%Y'),
           ' fällig. Liebe Grüße, Liane')   AS reminder_text
FROM v_overdue_loans;


-- =====================================================================
-- Auswertungen (Views 7 bis 11)
-- Für den Analyse-Bereich der App. Alle Kennzahlen werden hier in MySQL
-- berechnet, die App zeichnet nur die Diagramme.
-- =====================================================================

-- ---------------------------------------------------------------------
-- View 7: Kennzahlen (KPIs) in einer einzigen Zeile
--   Drei kleine Zusammenfassungen (Bücher, Personen, Ausleihen) werden
--   mit CROSS JOIN zu einer Zeile verbunden. COUNT(CASE WHEN ...) zählt
--   nur die Zeilen, auf die die Bedingung passt.
--   books_on_shelf:   alle Bücher, die gerade nicht verliehen sind
--                     (auch die nicht verleihbaren stehen im Regal)
--   on_time_rate_pct: Anteil pünktlicher Rückgaben an allen Rückgaben
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_kpi_overview AS
SELECT
    bk.books_total,
    bk.books_available,
    bk.books_lent,
    bk.books_total - bk.books_lent                                      AS books_on_shelf,
    bk.books_not_lendable,
    fr.friends_total,
    ln.loans_total,
    ln.loans_overdue,
    ln.loans_returned,
    ROUND(100 * ln.returned_on_time / NULLIF(ln.loans_returned, 0), 0)  AS on_time_rate_pct,
    ln.avg_days_kept,
    ln.avg_days_late
FROM (
    SELECT
        COUNT(*)                                                 AS books_total,
        COUNT(CASE WHEN status = 'verfügbar'        THEN 1 END)  AS books_available,
        COUNT(CASE WHEN status = 'ausgeliehen'      THEN 1 END)  AS books_lent,
        COUNT(CASE WHEN status = 'nicht verleihbar' THEN 1 END)  AS books_not_lendable
    FROM v_book_overview
) bk
CROSS JOIN (
    SELECT COUNT(*) AS friends_total
    FROM friends
) fr
CROSS JOIN (
    SELECT
        COUNT(*)                                                             AS loans_total,
        COUNT(CASE WHEN return_date IS NULL AND due_date < CURDATE()
                   THEN 1 END)                                               AS loans_overdue,
        COUNT(return_date)                                                   AS loans_returned,
        COUNT(CASE WHEN return_date <= due_date THEN 1 END)                  AS returned_on_time,
        ROUND(AVG(DATEDIFF(return_date, loan_date)), 1)                      AS avg_days_kept,
        ROUND(AVG(CASE WHEN return_date > due_date
                       THEN DATEDIFF(return_date, due_date) END), 1)         AS avg_days_late
    FROM loans
) ln;


-- ---------------------------------------------------------------------
-- View 8: Ausleihen pro Monat (Zeitreihe ohne Lücken)
--   Die rekursive CTE "months" erzeugt jeden Monat von der ersten
--   Ausleihe bis heute. Der LEFT JOIN hängt die Ausleihen an. Ein Monat
--   ohne Ausleihe erscheint so mit 0 statt zu fehlen.
--   loans_cumulative = laufende Summe (Fensterfunktion SUM() OVER).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_loans_per_month AS
WITH RECURSIVE months (month_start) AS (
    SELECT CAST(DATE_FORMAT(MIN(loan_date), '%Y-%m-01') AS DATE)
    FROM loans
    HAVING MIN(loan_date) IS NOT NULL            -- keine Ausleihen: keine Zeile
    UNION ALL
    SELECT month_start + INTERVAL 1 MONTH
    FROM months
    WHERE month_start + INTERVAL 1 MONTH <= CURDATE()
)
SELECT
    DATE_FORMAT(m.month_start, '%Y-%m')                                 AS month,
    COUNT(l.loan_id)                                                    AS loans,
    COUNT(CASE WHEN l.return_date <= l.due_date THEN 1 END)             AS returned_on_time,
    COUNT(CASE WHEN l.return_date >  l.due_date THEN 1 END)             AS returned_late,
    COUNT(CASE WHEN l.loan_id IS NOT NULL AND l.return_date IS NULL
               THEN 1 END)                                              AS still_open,
    SUM(COUNT(l.loan_id)) OVER (ORDER BY m.month_start)                 AS loans_cumulative
FROM months m
LEFT JOIN loans l ON l.loan_date >= m.month_start
                 AND l.loan_date <  m.month_start + INTERVAL 1 MONTH
GROUP BY m.month_start;


-- ---------------------------------------------------------------------
-- View 9: Pünktlichkeit nach Beziehung
--   Wer bringt Bücher pünktlich zurück: Familie, Kollegium, ...?
--   NULLIF verhindert eine Division durch 0 (Gruppe ohne Rückgaben).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_punctuality_by_relationship AS
SELECT
    f.relationship,
    COUNT(DISTINCT f.friend_id)                                         AS people,
    COUNT(l.loan_id)                                                    AS loans,
    COUNT(l.return_date)                                                AS returned,
    COUNT(CASE WHEN l.return_date <= l.due_date THEN 1 END)             AS returned_on_time,
    ROUND(100 * COUNT(CASE WHEN l.return_date <= l.due_date THEN 1 END)
              / NULLIF(COUNT(l.return_date), 0), 0)                     AS on_time_rate_pct,
    ROUND(AVG(CASE WHEN l.return_date > l.due_date
                   THEN DATEDIFF(l.return_date, l.due_date) END), 1)    AS avg_days_late
FROM friends f
LEFT JOIN loans l ON l.friend_id = f.friend_id
GROUP BY f.relationship;


-- ---------------------------------------------------------------------
-- View 10: Ausleihen pro Genre mit Anteil und Rang
--   Fensterfunktionen (Window Functions) über dem GROUP BY:
--   SUM(...) OVER () = Summe über alle Genres, RANK() = Platzierung
--   NULLIF: Gibt es noch keine Ausleihe, ist der Anteil NULL statt /0.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_genre_statistics AS
SELECT
    COALESCE(g.genre_name, 'ohne Genre')                                AS genre,
    COUNT(DISTINCT b.book_id)                                           AS books,
    COUNT(l.loan_id)                                                    AS loans,
    ROUND(100 * COUNT(l.loan_id)
              / NULLIF(SUM(COUNT(l.loan_id)) OVER (), 0), 1)            AS share_of_loans_pct,
    RANK() OVER (ORDER BY COUNT(l.loan_id) DESC)                        AS loan_rank
FROM books b
LEFT JOIN genres g ON g.genre_id = b.genre_id
LEFT JOIN loans  l ON l.book_id  = b.book_id
GROUP BY COALESCE(g.genre_name, 'ohne Genre');


-- ---------------------------------------------------------------------
-- View 11: Rangliste der Bücher nach Anzahl Ausleihen
--   DENSE_RANK: gleiche Anzahl = gleicher Platz, ohne Lücken.
--   Bücher mit 0 Ausleihen bleiben dabei (LEFT JOIN): "nie verliehen".
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_book_ranking AS
SELECT
    o.book_id,
    o.title,
    o.authors,
    o.genre,
    o.status,
    COUNT(l.loan_id)                                                    AS loans,
    DENSE_RANK() OVER (ORDER BY COUNT(l.loan_id) DESC)                  AS loan_rank,
    MAX(l.loan_date)                                                    AS last_loan_date
FROM v_book_overview o
LEFT JOIN loans l ON l.book_id = o.book_id
GROUP BY o.book_id, o.title, o.authors, o.genre, o.status;


-- Kontrolle
SELECT * FROM v_kpi_overview;
