-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 06_demo_loans.sql
-- Inhalt    : 50 Beispiel-Ausleihen (40 zurück, 10 offen, davon 4 überfällig)
-- Voraussetzung: 00_setup_complete.sql (oder 01 bis 05) wurde ausgeführt
-- =====================================================================
--
-- Wofür?  Die Datenbank startet mit 0 Ausleihen. Für die Präsentation,
--         den Analyse-Reiter der App und 08_queries.sql braucht man aber
--         eine Ausleih-Geschichte. Dieses Skript lädt sie.
--
-- Neu in Version 2:
--   * Die Ausleihen stehen in der Reihenfolge, in der sie passiert sind
--     (älteste zuerst). Jede Zeile läuft durch den Trigger
--     trg_loans_before_insert. Würde eine Ausleihe eine Regel verletzen,
--     bricht das Skript mit einer Meldung ab. Dass es durchläuft, ist
--     also der Beweis, dass die Demo-Daten zu den Regeln passen.
--   * Eine Zeile aus Version 1 ist korrigiert: Dort bekam Tobias Klein
--     "Tschick", obwohl "Der Schwarm" bei ihm schon überfällig war
--     (Verstoß gegen Regel 3). Hier leiht er "Tschick" 94 Tage vor heute
--     aus: einen Tag, nachdem er die "Schachnovelle" zurückgebracht hat,
--     und zwei Tage, bevor "Der Schwarm" fällig war.
--
-- Achtung: TRUNCATE leert zuerst die Tabelle loans. Ausleihen, die in der
--          App eingetragen wurden, sind danach weg. Bücher und Personen
--          bleiben unverändert.
--
-- Alle Datumswerte sind relativ zu HEUTE (CURDATE()) angegeben. So gibt
-- es immer passende offene und überfällige Ausleihen, egal an welchem Tag
-- das Skript ausgeführt wird.
--
-- Zurück zu 0 Ausleihen: 00_setup_complete.sql erneut ausführen.
-- =====================================================================

USE liane_library_v2;

TRUNCATE TABLE loans;   -- leert loans und setzt loan_id wieder auf 1

-- ---------------------------------------------------------------------
-- 50 Ausleihen, älteste zuerst
--   return_date = NULL: das Buch ist noch unterwegs
-- ---------------------------------------------------------------------
INSERT INTO loans (book_id, friend_id, loan_date, due_date, return_date, notes) VALUES
    (29, 3, CURDATE() - INTERVAL 360 DAY, CURDATE() - INTERVAL 339 DAY, CURDATE() - INTERVAL 341 DAY, NULL),   -- Schachnovelle -> Mira Schulz
    (15, 8, CURDATE() - INTERVAL 359 DAY, CURDATE() - INTERVAL 331 DAY, CURDATE() - INTERVAL 306 DAY, NULL),   -- Die Känguru-Chroniken -> Felix Wagner (zu spät)
    (8, 3, CURDATE() - INTERVAL 357 DAY, CURDATE() - INTERVAL 329 DAY, CURDATE() - INTERVAL 336 DAY, NULL),   -- Der Steppenwolf -> Mira Schulz
    (11, 4, CURDATE() - INTERVAL 355 DAY, CURDATE() - INTERVAL 327 DAY, CURDATE() - INTERVAL 301 DAY, NULL),   -- 1984 -> Tobias Klein (zu spät)
    (3, 3, CURDATE() - INTERVAL 346 DAY, CURDATE() - INTERVAL 332 DAY, CURDATE() - INTERVAL 336 DAY, NULL),   -- Tschick -> Mira Schulz
    (32, 1, CURDATE() - INTERVAL 343 DAY, CURDATE() - INTERVAL 329 DAY, CURDATE() - INTERVAL 337 DAY, NULL),   -- Der Name der Rose -> Anna Becker
    (3, 2, CURDATE() - INTERVAL 329 DAY, CURDATE() - INTERVAL 301 DAY, CURDATE() - INTERVAL 317 DAY, NULL),   -- Tschick -> Jonas Weber
    (9, 1, CURDATE() - INTERVAL 317 DAY, CURDATE() - INTERVAL 303 DAY, CURDATE() - INTERVAL 305 DAY, NULL),   -- Siddhartha -> Anna Becker
    (14, 10, CURDATE() - INTERVAL 316 DAY, CURDATE() - INTERVAL 288 DAY, CURDATE() - INTERVAL 310 DAY, NULL),   -- Factfulness -> David Nowak
    (6, 1, CURDATE() - INTERVAL 312 DAY, CURDATE() - INTERVAL 298 DAY, CURDATE() - INTERVAL 298 DAY, NULL),   -- Die unendliche Geschichte -> Anna Becker
    (4, 8, CURDATE() - INTERVAL 304 DAY, CURDATE() - INTERVAL 276 DAY, CURDATE() - INTERVAL 273 DAY, NULL),   -- Der Schwarm -> Felix Wagner (zu spät)
    (33, 5, CURDATE() - INTERVAL 302 DAY, CURDATE() - INTERVAL 274 DAY, CURDATE() - INTERVAL 296 DAY, NULL),   -- Die Säulen der Erde -> Lea Hoffmann
    (14, 2, CURDATE() - INTERVAL 296 DAY, CURDATE() - INTERVAL 268 DAY, CURDATE() - INTERVAL 276 DAY, NULL),   -- Factfulness -> Jonas Weber
    (2, 2, CURDATE() - INTERVAL 283 DAY, CURDATE() - INTERVAL 269 DAY, CURDATE() - INTERVAL 261 DAY, NULL),   -- Das Parfum -> Jonas Weber (zu spät)
    (34, 5, CURDATE() - INTERVAL 274 DAY, CURDATE() - INTERVAL 246 DAY, CURDATE() - INTERVAL 263 DAY, NULL),   -- Der Hundertjährige, der aus dem Fenster stieg und verschwand -> Lea Hoffmann
    (21, 1, CURDATE() - INTERVAL 268 DAY, CURDATE() - INTERVAL 254 DAY, CURDATE() - INTERVAL 255 DAY, NULL),   -- Harry Potter und der Stein der Weisen -> Anna Becker
    (16, 2, CURDATE() - INTERVAL 261 DAY, CURDATE() - INTERVAL 240 DAY, CURDATE() - INTERVAL 218 DAY, NULL),   -- QualityLand -> Jonas Weber (zu spät)
    (6, 2, CURDATE() - INTERVAL 261 DAY, CURDATE() - INTERVAL 233 DAY, CURDATE() - INTERVAL 254 DAY, NULL),   -- Die unendliche Geschichte -> Jonas Weber
    (11, 9, CURDATE() - INTERVAL 257 DAY, CURDATE() - INTERVAL 229 DAY, CURDATE() - INTERVAL 229 DAY, NULL),   -- 1984 -> Hannah Krüger
    (21, 7, CURDATE() - INTERVAL 239 DAY, CURDATE() - INTERVAL 211 DAY, CURDATE() - INTERVAL 226 DAY, NULL),   -- Harry Potter und der Stein der Weisen -> Sofia Rossi
    (28, 9, CURDATE() - INTERVAL 219 DAY, CURDATE() - INTERVAL 191 DAY, CURDATE() - INTERVAL 203 DAY, NULL),   -- Der Alchimist -> Hannah Krüger
    (14, 5, CURDATE() - INTERVAL 210 DAY, CURDATE() - INTERVAL 182 DAY, CURDATE() - INTERVAL 201 DAY, NULL),   -- Factfulness -> Lea Hoffmann
    (21, 8, CURDATE() - INTERVAL 199 DAY, CURDATE() - INTERVAL 171 DAY, CURDATE() - INTERVAL 164 DAY, NULL),   -- Harry Potter und der Stein der Weisen -> Felix Wagner (zu spät)
    (20, 2, CURDATE() - INTERVAL 191 DAY, CURDATE() - INTERVAL 163 DAY, CURDATE() - INTERVAL 160 DAY, NULL),   -- Datenanalyse mit Python -> Jonas Weber (zu spät)
    (1, 10, CURDATE() - INTERVAL 182 DAY, CURDATE() - INTERVAL 154 DAY, CURDATE() - INTERVAL 124 DAY, NULL),   -- Der Vorleser -> David Nowak (zu spät)
    (31, 9, CURDATE() - INTERVAL 177 DAY, CURDATE() - INTERVAL 163 DAY, CURDATE() - INTERVAL 170 DAY, NULL),   -- Schnelles Denken, langsames Denken -> Hannah Krüger
    (19, 1, CURDATE() - INTERVAL 165 DAY, CURDATE() - INTERVAL 137 DAY, CURDATE() - INTERVAL 137 DAY, NULL),   -- Python Crashkurs -> Anna Becker
    (7, 3, CURDATE() - INTERVAL 161 DAY, CURDATE() - INTERVAL 133 DAY, CURDATE() - INTERVAL 151 DAY, NULL),   -- Homo faber -> Mira Schulz
    (15, 10, CURDATE() - INTERVAL 159 DAY, CURDATE() - INTERVAL 145 DAY, CURDATE() - INTERVAL 146 DAY, NULL),   -- Die Känguru-Chroniken -> David Nowak
    (16, 3, CURDATE() - INTERVAL 158 DAY, CURDATE() - INTERVAL 130 DAY, CURDATE() - INTERVAL 143 DAY, NULL),   -- QualityLand -> Mira Schulz
    (13, 9, CURDATE() - INTERVAL 152 DAY, CURDATE() - INTERVAL 124 DAY, CURDATE() - INTERVAL 133 DAY, NULL),   -- Eine kurze Geschichte der Menschheit -> Hannah Krüger
    (27, 11, CURDATE() - INTERVAL 146 DAY, CURDATE() - INTERVAL 118 DAY, CURDATE() - INTERVAL 126 DAY, NULL),   -- Im Westen nichts Neues -> Emma Fischer
    (29, 4, CURDATE() - INTERVAL 133 DAY, CURDATE() - INTERVAL 119 DAY, CURDATE() - INTERVAL 95 DAY, NULL),   -- Schachnovelle -> Tobias Klein (zu spät)
    (4, 4, CURDATE() - INTERVAL 120 DAY, CURDATE() - INTERVAL 92 DAY, NULL, NULL),   -- Der Schwarm -> Tobias Klein (ÜBERFÄLLIG)
    (23, 1, CURDATE() - INTERVAL 106 DAY, CURDATE() - INTERVAL 85 DAY, CURDATE() - INTERVAL 97 DAY, NULL),   -- Der Hobbit -> Anna Becker
    (3, 4, CURDATE() - INTERVAL 94 DAY, CURDATE() - INTERVAL 66 DAY, NULL, NULL),   -- Tschick -> Tobias Klein (ÜBERFÄLLIG)
    (16, 5, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 64 DAY, CURDATE() - INTERVAL 80 DAY, NULL),   -- QualityLand -> Lea Hoffmann
    (9, 8, CURDATE() - INTERVAL 77 DAY, CURDATE() - INTERVAL 49 DAY, CURDATE() - INTERVAL 36 DAY, NULL),   -- Siddhartha -> Felix Wagner (zu spät)
    (23, 2, CURDATE() - INTERVAL 74 DAY, CURDATE() - INTERVAL 53 DAY, CURDATE() - INTERVAL 56 DAY, NULL),   -- Der Hobbit -> Jonas Weber
    (11, 8, CURDATE() - INTERVAL 60 DAY, CURDATE() - INTERVAL 32 DAY, NULL, NULL),   -- 1984 -> Felix Wagner (ÜBERFÄLLIG)
    (15, 1, CURDATE() - INTERVAL 49 DAY, CURDATE() - INTERVAL 21 DAY, CURDATE() - INTERVAL 39 DAY, NULL),   -- Die Känguru-Chroniken -> Anna Becker
    (17, 7, CURDATE() - INTERVAL 48 DAY, CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 41 DAY, NULL),   -- Good Omens -> Sofia Rossi
    (28, 6, CURDATE() - INTERVAL 47 DAY, CURDATE() - INTERVAL 26 DAY, CURDATE() - INTERVAL 30 DAY, NULL),   -- Der Alchimist -> Can Yılmaz
    (19, 2, CURDATE() - INTERVAL 40 DAY, CURDATE() - INTERVAL 12 DAY, NULL, NULL),   -- Python Crashkurs -> Jonas Weber (ÜBERFÄLLIG)
    (33, 5, CURDATE() - INTERVAL 30 DAY, CURDATE() + INTERVAL 5 DAY, NULL, 'Verlängert um 7 Tage'),   -- Die Säulen der Erde -> Lea Hoffmann (läuft)
    (20, 6, CURDATE() - INTERVAL 20 DAY, CURDATE() + INTERVAL 8 DAY, NULL, NULL),   -- Datenanalyse mit Python -> Can Yılmaz (läuft)
    (16, 10, CURDATE() - INTERVAL 14 DAY, CURDATE() + INTERVAL 14 DAY, NULL, NULL),   -- QualityLand -> David Nowak (läuft)
    (14, 1, CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 18 DAY, NULL, NULL),   -- Factfulness -> Anna Becker (läuft)
    (1, 1, CURDATE() - INTERVAL 5 DAY, CURDATE() + INTERVAL 23 DAY, NULL, NULL),   -- Der Vorleser -> Anna Becker (läuft)
    (21, 3, CURDATE() - INTERVAL 3 DAY, CURDATE() + INTERVAL 25 DAY, NULL, NULL);   -- Harry Potter und der Stein der Weisen -> Mira Schulz (läuft)


-- Kontrolle: 50 Ausleihen, davon 10 offen und 4 überfällig
SELECT COUNT(*)                                                    AS ausleihen,
       COUNT(CASE WHEN return_date IS NULL THEN 1 END)             AS offen,
       COUNT(CASE WHEN return_date IS NULL AND due_date < CURDATE()
                  THEN 1 END)                                      AS ueberfaellig
FROM loans;
