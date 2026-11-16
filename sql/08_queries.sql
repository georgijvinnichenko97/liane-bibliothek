-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 08_queries.sql
-- Inhalt    : 17 Abfragen zu Lianes Fragen + Beispiele für INSERT, UPDATE, DELETE
-- Voraussetzung: 00_setup_complete.sql und 06_demo_loans.sql wurden
--               ausgeführt (die Abfragen brauchen die Beispiel-Ausleihen)
-- =====================================================================
-- Tipp für MySQL Workbench: Cursor in eine Abfrage setzen und
-- Strg+Enter drücken, dann läuft nur diese eine Abfrage.
--
-- Neu in Version 2:
--   * Die Abfragen nutzen die Views, statt deren Logik zu wiederholen
--     (zum Beispiel kommen die Erinnerungstexte aus v_reminders).
--   * Teil B zeigt mehr Analyse-Technik: Rang mit Gleichstand, bester
--     Eintrag pro Gruppe, Vergleich zum Vormonat, laufende Summe, Median.
-- =====================================================================

USE liane_library_v2;


-- =====================================================================
-- TEIL A: Wer hat was? (der Alltag)
-- =====================================================================

-- A1: Welche Bücher sind gerade verliehen und bei wem?
SELECT title, borrower, loan_date, due_date, days_left, loan_status
FROM v_current_loans
ORDER BY due_date;

-- A2: Welche Bücher sind überfällig? (die längste Verspätung zuerst)
SELECT title, borrower, contact, due_date, days_overdue
FROM v_overdue_loans
ORDER BY days_overdue DESC;

-- A3: Erinnerungstexte für alle überfälligen Bücher
SELECT borrower, contact, reminder_text
FROM v_reminders
ORDER BY days_overdue DESC;

-- A4: Wer muss in den nächsten 7 Tagen zurückgeben?
SELECT title, borrower, due_date, days_left
FROM v_current_loans
WHERE due_soon = 1
ORDER BY due_date;

-- A5: Welche Bücher kann ich gerade verleihen?
SELECT title, authors, genre
FROM v_book_overview
WHERE status = 'verfügbar'
ORDER BY genre, title;

-- A6: Was hat Anna gerade, und was hatte sie schon? (komplette Historie)
SELECT title, loan_date, due_date, return_date, outcome, days_late
FROM v_loan_history
WHERE borrower = 'Anna Becker'
ORDER BY loan_date DESC;

-- A7: Buch suchen (Titel, Autor oder ISBN) - mit der Stored Procedure
CALL sp_find_book('Kling');


-- =====================================================================
-- TEIL B: Auswertungen (Data Analytics)
-- =====================================================================

-- B1: Die beliebtesten Bücher (Plätze 1 bis 3)
--     DENSE_RANK statt LIMIT: Haben mehrere Bücher gleich viele
--     Ausleihen, stehen alle auf demselben Platz. LIMIT 5 würde bei
--     Gleichstand zufällig eines abschneiden.
SELECT loan_rank AS platz, title, authors, loans AS ausleihen
FROM v_book_ranking
WHERE loan_rank <= 3 AND loans > 0
ORDER BY loan_rank, title;

-- B2: Welche Bücher wurden noch nie ausgeliehen?
--     NOT EXISTS: "Es gibt keine Ausleihe zu diesem Buch."
SELECT b.title, g.genre_name AS genre,
       CASE WHEN b.is_lendable = 0 THEN 'nicht verleihbar' ELSE '' END AS hinweis
FROM books b
LEFT JOIN genres g ON g.genre_id = b.genre_id
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.book_id = b.book_id)
ORDER BY b.title;

-- B3: Wer leiht am meisten aus, und wer gibt pünktlich zurück?
SELECT friend, relationship, total_loans, open_loans, overdue_now,
       returned_late, on_time_rate_pct, avg_days_kept, lend_status
FROM v_friend_statistics
ORDER BY total_loans DESC, friend;

-- B4: Zuverlässigkeit nach Beziehung (Familie, Kollegium, ...)
--     returned steht dabei, damit man sieht, wie viele Rückgaben hinter
--     der Prozentzahl stecken (100 % aus 3 Rückgaben sagt wenig).
SELECT relationship, people, returned, returned_on_time, on_time_rate_pct, avg_days_late
FROM v_punctuality_by_relationship
WHERE returned > 0
ORDER BY on_time_rate_pct DESC, returned DESC;

-- B5: Ausleihen und durchschnittliche Leihdauer pro Genre
SELECT
    g.genre_name                                        AS genre,
    COUNT(l.loan_id)                                    AS ausleihen,
    ROUND(AVG(DATEDIFF(l.return_date, l.loan_date)), 1) AS durchschnitt_tage
FROM genres g
JOIN books b      ON b.genre_id = g.genre_id
LEFT JOIN loans l ON l.book_id  = b.book_id
GROUP BY g.genre_id, g.genre_name
ORDER BY ausleihen DESC, genre;

-- B6: Lieblingsgenre jeder Person ("bester Eintrag pro Gruppe")
--     Schritt 1 zählt Ausleihen pro Person und Genre.
--     Schritt 2 nummeriert die Genres jeder Person nach Anzahl
--     (ROW_NUMBER mit PARTITION BY). Platz 1 ist das Lieblingsgenre.
WITH per_genre AS (
    SELECT
        f.friend_id,
        CONCAT(f.first_name, ' ', f.last_name)  AS person,
        COALESCE(g.genre_name, 'ohne Genre')    AS genre,
        COUNT(*)                                AS ausleihen
    FROM loans l
    JOIN friends f     ON f.friend_id = l.friend_id
    JOIN books b       ON b.book_id   = l.book_id
    LEFT JOIN genres g ON g.genre_id  = b.genre_id
    GROUP BY f.friend_id, f.first_name, f.last_name, COALESCE(g.genre_name, 'ohne Genre')
),
ranked AS (
    SELECT
        person, genre, ausleihen,
        ROW_NUMBER() OVER (PARTITION BY friend_id ORDER BY ausleihen DESC, genre) AS platz
    FROM per_genre
)
SELECT person, genre AS lieblingsgenre, ausleihen
FROM ranked
WHERE platz = 1
ORDER BY ausleihen DESC, person;

-- B7: Ausleihen pro Monat mit Veränderung zum Vormonat und laufender Summe
--     LAG() holt den Wert der vorherigen Zeile (hier: des Vormonats).
--     Die View liefert jeden Monat, auch einen ohne Ausleihe.
SELECT
    month                                   AS monat,
    loans                                   AS ausleihen,
    loans - LAG(loans) OVER (ORDER BY month) AS veraenderung_zum_vormonat,
    loans_cumulative                        AS ausleihen_bisher
FROM v_loans_per_month
ORDER BY month;

-- B8: Bücher mit mehreren Autoren (HAVING filtert nach dem Gruppieren)
SELECT b.title, COUNT(*) AS anzahl_autoren
FROM books b
JOIN book_authors ba ON ba.book_id = b.book_id
GROUP BY b.book_id, b.title
HAVING COUNT(*) > 1
ORDER BY anzahl_autoren DESC, b.title;

-- B9: Durchschnitt und Median der Leihdauer
--     Der Durchschnitt wird von wenigen sehr langen Ausleihen nach oben
--     gezogen. Der Median ist der Wert in der Mitte: Die Hälfte der
--     Bücher kam früher zurück, die Hälfte später. MySQL hat keine
--     MEDIAN-Funktion, deshalb: sortieren, durchnummerieren, Mitte nehmen
--     (bei gerader Anzahl den Durchschnitt der beiden mittleren Werte).
WITH durations AS (
    SELECT
        DATEDIFF(return_date, loan_date)                                AS tage,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(return_date, loan_date))   AS zeile,
        COUNT(*) OVER ()                                                AS anzahl
    FROM loans
    WHERE return_date IS NOT NULL
)
SELECT
    MAX(anzahl)                                                         AS rueckgaben,
    ROUND(AVG(tage), 1)                                                 AS durchschnitt_tage,
    AVG(CASE WHEN zeile IN (FLOOR((anzahl + 1) / 2), CEIL((anzahl + 1) / 2))
             THEN tage END)                                             AS median_tage,
    MAX(tage)                                                           AS laengste_ausleihe
FROM durations;

-- B10: Ranking der Leser mit Anteil an allen Ausleihen
--      RANK() vergibt Plätze, SUM() OVER () ist die Gesamtsumme über
--      alle Zeilen. So steht der Anteil neben jeder Person.
SELECT
    RANK() OVER (ORDER BY total_loans DESC)                         AS platz,
    friend,
    total_loans,
    ROUND(100 * total_loans / SUM(total_loans) OVER (), 1)          AS anteil_pct
FROM v_friend_statistics
WHERE total_loans > 0
ORDER BY platz, friend;


-- =====================================================================
-- TEIL C: Daten ändern (CRUD) - INSERT, UPDATE, DELETE
-- Alles läuft in einer Transaktion und wird am Ende mit ROLLBACK
-- zurückgenommen. So bleiben die Beispieldaten unverändert.
-- Für echte Änderungen ROLLBACK durch COMMIT ersetzen.
-- =====================================================================

START TRANSACTION;

-- C1: INSERT (Create) - neue Person anlegen
INSERT INTO friends (first_name, last_name, email, relationship, max_loans)
VALUES ('Nina', 'Schmidt', 'nina.schmidt@example.com', 'Kollegium', 2);

-- C2: UPDATE - Telefonnummer nachtragen
UPDATE friends
   SET phone = '+49 151 1000 0013'
 WHERE email = 'nina.schmidt@example.com';

-- C3: Buch verleihen und zurücknehmen über die Procedures
--     (Momo an Nina, 14 Tage; danach sofort zurück)
CALL sp_lend_book(
    (SELECT book_id   FROM books   WHERE title = 'Momo'),
    (SELECT friend_id FROM friends WHERE email = 'nina.schmidt@example.com'),
    14);
CALL sp_return_book((SELECT book_id FROM books WHERE title = 'Momo'));

-- C4: DELETE - eine Person ohne Ausleih-Historie löschen klappt ...
DELETE FROM friends WHERE email = 'lukas.braun@example.com';

-- ... eine Person MIT Historie nicht (Fremdschlüssel, Regel 7).
-- Diese Zeile erzeugt absichtlich einen Fehler:
-- DELETE FROM friends WHERE email = 'nina.schmidt@example.com';

-- Read: Kontrolle nach den Änderungen
SELECT friend_id, first_name, last_name, email, phone FROM friends ORDER BY friend_id;

ROLLBACK;   -- alles zurücknehmen
