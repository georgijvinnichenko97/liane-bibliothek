-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 07_demo_one_year.sql
-- Inhalt    : Szenario "Ein Jahr später": so sieht die Bibliothek aus,
--             nachdem Liane die App ein Jahr lang benutzt hat
-- Voraussetzung: 00_setup_complete.sql wurde ausgeführt
-- =====================================================================
--
-- Was passiert hier?
--   * 8 neue Verlage, 14 neue Autorinnen und Autoren und 15 neue Bücher,
--     die Liane im Laufe des Jahres gekauft hat (added_on = Kaufdatum)
--   * 6 neue Personen, die im Laufe des Jahres dazugekommen sind
--   * 160 Ausleihen über 365 Tage: 144 zurück (davon 27 zu spät),
--     16 noch unterwegs, davon 4 überfällig
--
-- Die Ausleihen sind SIMULIERT (fester Zufalls-Seed, alle Personen
-- erfunden). Sie stehen in der Reihenfolge, in der sie passiert sind,
-- und jede Zeile läuft durch den Trigger trg_loans_before_insert:
-- ein Buch nur einmal gleichzeitig, höchstens max_loans pro Person,
-- keine neue Ausleihe bei Überfälligem, "Der kleine Prinz" nie.
-- Würde eine Zeile eine Regel verletzen, bricht das Skript ab.
-- Familie und Nachbarschaft bringen fast immer pünktlich zurück,
-- Bekanntschaften oft zu spät. Im Winter und in den Sommerferien
-- wird mehr gelesen.
--
-- Achtung: TRUNCATE leert zuerst die Tabelle loans. Ausleihen aus der
-- App oder aus 06_demo_loans.sql sind danach weg.
-- Alle Datumswerte sind relativ zu HEUTE (CURDATE()).
--
-- Zurück zum Start mit 0 Ausleihen: 00_setup_complete.sql ausführen.
-- =====================================================================

USE liane_library_v2;

TRUNCATE TABLE loans;   -- leert loans und setzt loan_id wieder auf 1

-- ---------------------------------------------------------------------
-- 1) Neue Verlage (nur anlegen, wenn es sie noch nicht gibt)
-- ---------------------------------------------------------------------
INSERT INTO publishers (publisher_name, city)
SELECT n.publisher_name, n.city
FROM (SELECT 'Knaus' AS publisher_name, 'München' AS city
      UNION ALL SELECT 'Luchterhand', 'München'
      UNION ALL SELECT 'Droemer', 'München'
      UNION ALL SELECT 'Heyne', 'München'
      UNION ALL SELECT 'Oetinger', 'Hamburg'
      UNION ALL SELECT 'Wiley', 'Hoboken'
      UNION ALL SELECT 'Deuticke', 'Wien'
      UNION ALL SELECT 'dtv', 'München') AS n
WHERE NOT EXISTS (SELECT 1 FROM publishers p WHERE p.publisher_name = n.publisher_name);

-- ---------------------------------------------------------------------
-- 2) Neue Autorinnen und Autoren (Marc-Uwe Kling gibt es schon)
-- ---------------------------------------------------------------------
INSERT INTO authors (first_name, last_name)
SELECT n.first_name, n.last_name
FROM (SELECT 'Dörte' AS first_name, 'Hansen' AS last_name
      UNION ALL SELECT 'Juli', 'Zeh'
      UNION ALL SELECT 'Matt', 'Haig'
      UNION ALL SELECT 'Andy', 'Weir'
      UNION ALL SELECT 'Frank', 'Herbert'
      UNION ALL SELECT 'Suzanne', 'Collins'
      UNION ALL SELECT 'Noah', 'Gordon'
      UNION ALL SELECT 'Marc-Uwe', 'Kling'
      UNION ALL SELECT 'Ralf', 'Adams'
      UNION ALL SELECT 'Cole Nussbaumer', 'Knaflic'
      UNION ALL SELECT 'Sebastian', 'Fitzek'
      UNION ALL SELECT 'Marlen', 'Haushofer'
      UNION ALL SELECT 'Daniel', 'Glattauer'
      UNION ALL SELECT 'Daniel', 'Kehlmann'
      UNION ALL SELECT 'John', 'Strelecky') AS n
WHERE NOT EXISTS (SELECT 1 FROM authors a
                   WHERE a.first_name = n.first_name AND a.last_name = n.last_name);

-- ---------------------------------------------------------------------
-- 3) 15 neue Bücher (ISBN fiktiv), added_on = Tag des Kaufs
--    INSERT IGNORE: schon vorhandene ISBN werden übersprungen
-- ---------------------------------------------------------------------
INSERT IGNORE INTO books (isbn, title, genre_id, publisher_id, first_published, language_code, is_lendable, notes, added_on) VALUES
    ('9783999000367', 'Altes Land', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Knaus'), 2015, 'de', 1, NULL, CURDATE() - INTERVAL 345 DAY),
    ('9783999000374', 'Unterleuten', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Luchterhand'), 2016, 'de', 1, NULL, CURDATE() - INTERVAL 320 DAY),
    ('9783999000381', 'Die Mitternachtsbibliothek', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Droemer'), 2020, 'de', 1, NULL, CURDATE() - INTERVAL 295 DAY),
    ('9783999000398', 'Der Marsianer', (SELECT genre_id FROM genres WHERE genre_name = 'Science-Fiction'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Heyne'), 2011, 'de', 1, NULL, CURDATE() - INTERVAL 275 DAY),
    ('9783999000404', 'Dune', (SELECT genre_id FROM genres WHERE genre_name = 'Science-Fiction'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Heyne'), 1965, 'de', 1, NULL, CURDATE() - INTERVAL 255 DAY),
    ('9783999000411', 'Die Tribute von Panem', (SELECT genre_id FROM genres WHERE genre_name = 'Kinder- und Jugendbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Oetinger'), 2008, 'de', 1, NULL, CURDATE() - INTERVAL 235 DAY),
    ('9783999000428', 'Der Medicus', (SELECT genre_id FROM genres WHERE genre_name = 'Historischer Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Droemer'), 1986, 'de', 1, NULL, CURDATE() - INTERVAL 215 DAY),
    ('9783999000435', 'Die Känguru-Offenbarung', (SELECT genre_id FROM genres WHERE genre_name = 'Humor'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 2014, 'de', 1, NULL, CURDATE() - INTERVAL 200 DAY),
    ('9783999000442', 'SQL. Der Grundkurs für Ausbildung und Praxis', (SELECT genre_id FROM genres WHERE genre_name = 'Fachbuch IT & Daten'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Hanser'), 2012, 'de', 1, NULL, CURDATE() - INTERVAL 180 DAY),
    ('9783999000459', 'Storytelling with Data', (SELECT genre_id FROM genres WHERE genre_name = 'Fachbuch IT & Daten'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Wiley'), 2015, 'en', 1, NULL, CURDATE() - INTERVAL 160 DAY),
    ('9783999000466', 'Der Insasse', (SELECT genre_id FROM genres WHERE genre_name = 'Krimi & Thriller'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Droemer'), 2018, 'de', 1, NULL, CURDATE() - INTERVAL 140 DAY),
    ('9783999000473', 'Die Wand', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 1963, 'de', 1, NULL, CURDATE() - INTERVAL 120 DAY),
    ('9783999000480', 'Gut gegen Nordwind', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Deuticke'), 2006, 'de', 1, NULL, CURDATE() - INTERVAL 95 DAY),
    ('9783999000497', 'Die Vermessung der Welt', (SELECT genre_id FROM genres WHERE genre_name = 'Historischer Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Rowohlt'), 2005, 'de', 1, NULL, CURDATE() - INTERVAL 65 DAY),
    ('9783999000503', 'Das Café am Rande der Welt', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'dtv'), 2003, 'de', 1, NULL, CURDATE() - INTERVAL 35 DAY);

-- Zuordnung Buch <-> Autor über ISBN und Namen (JOIN statt fester IDs)
INSERT IGNORE INTO book_authors (book_id, author_id, author_order)
SELECT b.book_id, a.author_id, 1
FROM (SELECT '9783999000367' AS isbn, 'Dörte' AS first_name, 'Hansen' AS last_name
      UNION ALL SELECT '9783999000374', 'Juli', 'Zeh'
      UNION ALL SELECT '9783999000381', 'Matt', 'Haig'
      UNION ALL SELECT '9783999000398', 'Andy', 'Weir'
      UNION ALL SELECT '9783999000404', 'Frank', 'Herbert'
      UNION ALL SELECT '9783999000411', 'Suzanne', 'Collins'
      UNION ALL SELECT '9783999000428', 'Noah', 'Gordon'
      UNION ALL SELECT '9783999000435', 'Marc-Uwe', 'Kling'
      UNION ALL SELECT '9783999000442', 'Ralf', 'Adams'
      UNION ALL SELECT '9783999000459', 'Cole Nussbaumer', 'Knaflic'
      UNION ALL SELECT '9783999000466', 'Sebastian', 'Fitzek'
      UNION ALL SELECT '9783999000473', 'Marlen', 'Haushofer'
      UNION ALL SELECT '9783999000480', 'Daniel', 'Glattauer'
      UNION ALL SELECT '9783999000497', 'Daniel', 'Kehlmann'
      UNION ALL SELECT '9783999000503', 'John', 'Strelecky') AS n
JOIN books   b ON b.isbn = n.isbn
JOIN authors a ON a.first_name = n.first_name AND a.last_name = n.last_name;

-- ---------------------------------------------------------------------
-- 4) 6 neue Personen (erfunden), created_at = Tag, an dem sie dazukamen
-- ---------------------------------------------------------------------
INSERT IGNORE INTO friends (first_name, last_name, email, phone, relationship, max_loans, created_at) VALUES
    ('Jana', 'Wolf', 'jana.wolf@example.com', '+49 151 1000 0013', 'Kollegium', 3, NOW() - INTERVAL 305 DAY),
    ('Paul', 'Hoffmann', 'paul.hoffmann@example.com', '+49 151 1000 0014', 'Familie', 4, NOW() - INTERVAL 270 DAY),
    ('Nora', 'Schmitt', 'nora.schmitt@example.com', '+49 151 1000 0015', 'Nachbarschaft', 2, NOW() - INTERVAL 225 DAY),
    ('Ben', 'Schröder', 'ben.schroeder@example.com', NULL, 'Freundeskreis', 3, NOW() - INTERVAL 190 DAY),
    ('Kevin', 'Lange', 'kevin.lange@example.com', '+49 151 1000 0017', 'Bekanntschaft', 2, NOW() - INTERVAL 150 DAY),
    ('Aylin', 'Demir', 'aylin.demir@example.com', NULL, 'Kollegium', 3, NOW() - INTERVAL 105 DAY);

-- ---------------------------------------------------------------------
-- 5) 160 Ausleihen über ein Jahr (sortiert nach Ausleihdatum)
--    Neue Bücher und Personen werden über ISBN bzw. E-Mail gefunden.
-- ---------------------------------------------------------------------
INSERT INTO loans (book_id, friend_id, loan_date, due_date, return_date, notes) VALUES
    (31, 9, CURDATE() - INTERVAL 364 DAY, CURDATE() - INTERVAL 336 DAY, CURDATE() - INTERVAL 337 DAY, NULL),
    (35, 5, CURDATE() - INTERVAL 364 DAY, CURDATE() - INTERVAL 322 DAY, CURDATE() - INTERVAL 345 DAY, NULL),
    (9, 9, CURDATE() - INTERVAL 362 DAY, CURDATE() - INTERVAL 348 DAY, CURDATE() - INTERVAL 322 DAY, NULL),
    (15, 5, CURDATE() - INTERVAL 361 DAY, CURDATE() - INTERVAL 333 DAY, CURDATE() - INTERVAL 352 DAY, 'Verlängert um 14 Tage'),
    (33, 4, CURDATE() - INTERVAL 356 DAY, CURDATE() - INTERVAL 328 DAY, CURDATE() - INTERVAL 328 DAY, NULL),
    (20, 3, CURDATE() - INTERVAL 353 DAY, CURDATE() - INTERVAL 311 DAY, CURDATE() - INTERVAL 335 DAY, 'Verlängert um 14 Tage'),
    (19, 4, CURDATE() - INTERVAL 350 DAY, CURDATE() - INTERVAL 322 DAY, CURDATE() - INTERVAL 258 DAY, NULL),
    (34, 1, CURDATE() - INTERVAL 347 DAY, CURDATE() - INTERVAL 319 DAY, CURDATE() - INTERVAL 332 DAY, 'Verlängert um 14 Tage'),
    (8, 2, CURDATE() - INTERVAL 343 DAY, CURDATE() - INTERVAL 322 DAY, CURDATE() - INTERVAL 289 DAY, NULL),
    (28, 7, CURDATE() - INTERVAL 339 DAY, CURDATE() - INTERVAL 311 DAY, CURDATE() - INTERVAL 320 DAY, NULL),
    (14, 2, CURDATE() - INTERVAL 335 DAY, CURDATE() - INTERVAL 293 DAY, CURDATE() - INTERVAL 258 DAY, 'Verlängert um 14 Tage'),
    (6, 8, CURDATE() - INTERVAL 333 DAY, CURDATE() - INTERVAL 305 DAY, CURDATE() - INTERVAL 313 DAY, NULL),
    (22, 10, CURDATE() - INTERVAL 332 DAY, CURDATE() - INTERVAL 318 DAY, CURDATE() - INTERVAL 318 DAY, NULL),
    (31, 2, CURDATE() - INTERVAL 327 DAY, CURDATE() - INTERVAL 299 DAY, CURDATE() - INTERVAL 312 DAY, NULL),
    (23, 10, CURDATE() - INTERVAL 326 DAY, CURDATE() - INTERVAL 312 DAY, CURDATE() - INTERVAL 317 DAY, NULL),
    (34, 5, CURDATE() - INTERVAL 325 DAY, CURDATE() - INTERVAL 304 DAY, CURDATE() - INTERVAL 308 DAY, NULL),
    (11, 12, CURDATE() - INTERVAL 321 DAY, CURDATE() - INTERVAL 293 DAY, CURDATE() - INTERVAL 299 DAY, NULL),
    (13, 10, CURDATE() - INTERVAL 318 DAY, CURDATE() - INTERVAL 290 DAY, CURDATE() - INTERVAL 297 DAY, NULL),
    (20, 10, CURDATE() - INTERVAL 316 DAY, CURDATE() - INTERVAL 288 DAY, CURDATE() - INTERVAL 303 DAY, NULL),
    (2, 10, CURDATE() - INTERVAL 313 DAY, CURDATE() - INTERVAL 285 DAY, CURDATE() - INTERVAL 301 DAY, NULL),
    (16, 3, CURDATE() - INTERVAL 308 DAY, CURDATE() - INTERVAL 294 DAY, CURDATE() - INTERVAL 297 DAY, NULL),
    (23, 3, CURDATE() - INTERVAL 304 DAY, CURDATE() - INTERVAL 276 DAY, CURDATE() - INTERVAL 255 DAY, NULL),
    (30, 3, CURDATE() - INTERVAL 303 DAY, CURDATE() - INTERVAL 275 DAY, CURDATE() - INTERVAL 287 DAY, NULL),
    (20, 11, CURDATE() - INTERVAL 302 DAY, CURDATE() - INTERVAL 274 DAY, CURDATE() - INTERVAL 293 DAY, NULL),
    (3, 6, CURDATE() - INTERVAL 299 DAY, CURDATE() - INTERVAL 271 DAY, CURDATE() - INTERVAL 275 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000367'), 3, CURDATE() - INTERVAL 297 DAY, CURDATE() - INTERVAL 276 DAY, CURDATE() - INTERVAL 282 DAY, NULL),
    (9, 11, CURDATE() - INTERVAL 294 DAY, CURDATE() - INTERVAL 266 DAY, CURDATE() - INTERVAL 271 DAY, NULL),
    (16, 11, CURDATE() - INTERVAL 292 DAY, CURDATE() - INTERVAL 271 DAY, CURDATE() - INTERVAL 278 DAY, NULL),
    (21, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 289 DAY, CURDATE() - INTERVAL 254 DAY, CURDATE() - INTERVAL 275 DAY, 'Verlängert um 14 Tage'),
    (30, 6, CURDATE() - INTERVAL 284 DAY, CURDATE() - INTERVAL 249 DAY, CURDATE() - INTERVAL 260 DAY, 'Verlängert um 14 Tage'),
    (7, 3, CURDATE() - INTERVAL 281 DAY, CURDATE() - INTERVAL 239 DAY, CURDATE() - INTERVAL 258 DAY, NULL),
    (22, 1, CURDATE() - INTERVAL 280 DAY, CURDATE() - INTERVAL 252 DAY, CURDATE() - INTERVAL 267 DAY, NULL),
    (32, 1, CURDATE() - INTERVAL 276 DAY, CURDATE() - INTERVAL 248 DAY, CURDATE() - INTERVAL 255 DAY, NULL),
    (6, 1, CURDATE() - INTERVAL 274 DAY, CURDATE() - INTERVAL 246 DAY, CURDATE() - INTERVAL 261 DAY, NULL),
    (15, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 267 DAY, CURDATE() - INTERVAL 253 DAY, CURDATE() - INTERVAL 218 DAY, NULL),
    (20, 6, CURDATE() - INTERVAL 267 DAY, CURDATE() - INTERVAL 246 DAY, CURDATE() - INTERVAL 214 DAY, NULL),
    (28, 6, CURDATE() - INTERVAL 265 DAY, CURDATE() - INTERVAL 244 DAY, CURDATE() - INTERVAL 232 DAY, NULL),
    (3, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 265 DAY, CURDATE() - INTERVAL 237 DAY, CURDATE() - INTERVAL 249 DAY, NULL),
    (21, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 262 DAY, CURDATE() - INTERVAL 220 DAY, CURDATE() - INTERVAL 233 DAY, 'Verlängert um 14 Tage'),
    (16, 10, CURDATE() - INTERVAL 260 DAY, CURDATE() - INTERVAL 218 DAY, CURDATE() - INTERVAL 224 DAY, 'Verlängert um 14 Tage'),
    (35, 12, CURDATE() - INTERVAL 254 DAY, CURDATE() - INTERVAL 233 DAY, CURDATE() - INTERVAL 234 DAY, NULL),
    (19, 1, CURDATE() - INTERVAL 251 DAY, CURDATE() - INTERVAL 209 DAY, CURDATE() - INTERVAL 236 DAY, 'Verlängert um 14 Tage'),
    (33, 5, CURDATE() - INTERVAL 250 DAY, CURDATE() - INTERVAL 208 DAY, CURDATE() - INTERVAL 219 DAY, 'Verlängert um 14 Tage'),
    (23, 11, CURDATE() - INTERVAL 249 DAY, CURDATE() - INTERVAL 221 DAY, CURDATE() - INTERVAL 223 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000381'), 6, CURDATE() - INTERVAL 248 DAY, CURDATE() - INTERVAL 220 DAY, CURDATE() - INTERVAL 233 DAY, NULL),
    (27, 9, CURDATE() - INTERVAL 244 DAY, CURDATE() - INTERVAL 202 DAY, CURDATE() - INTERVAL 208 DAY, NULL),
    (34, 11, CURDATE() - INTERVAL 240 DAY, CURDATE() - INTERVAL 198 DAY, CURDATE() - INTERVAL 222 DAY, 'Verlängert um 14 Tage'),
    (6, 4, CURDATE() - INTERVAL 237 DAY, CURDATE() - INTERVAL 181 DAY, CURDATE() - INTERVAL 149 DAY, 'Verlängert um 14 Tage'),
    (22, 12, CURDATE() - INTERVAL 234 DAY, CURDATE() - INTERVAL 206 DAY, CURDATE() - INTERVAL 219 DAY, NULL),
    (5, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 234 DAY, CURDATE() - INTERVAL 206 DAY, CURDATE() - INTERVAL 215 DAY, NULL),
    (31, 3, CURDATE() - INTERVAL 230 DAY, CURDATE() - INTERVAL 202 DAY, CURDATE() - INTERVAL 211 DAY, NULL),
    (14, 1, CURDATE() - INTERVAL 224 DAY, CURDATE() - INTERVAL 196 DAY, CURDATE() - INTERVAL 196 DAY, NULL),
    (3, 1, CURDATE() - INTERVAL 223 DAY, CURDATE() - INTERVAL 195 DAY, CURDATE() - INTERVAL 170 DAY, NULL),
    (33, 3, CURDATE() - INTERVAL 219 DAY, CURDATE() - INTERVAL 191 DAY, CURDATE() - INTERVAL 200 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000381'), 9, CURDATE() - INTERVAL 219 DAY, CURDATE() - INTERVAL 191 DAY, CURDATE() - INTERVAL 207 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000398'), 5, CURDATE() - INTERVAL 217 DAY, CURDATE() - INTERVAL 175 DAY, CURDATE() - INTERVAL 192 DAY, NULL),
    (11, 1, CURDATE() - INTERVAL 209 DAY, CURDATE() - INTERVAL 181 DAY, CURDATE() - INTERVAL 185 DAY, NULL),
    (32, 11, CURDATE() - INTERVAL 209 DAY, CURDATE() - INTERVAL 181 DAY, CURDATE() - INTERVAL 179 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000381'), 8, CURDATE() - INTERVAL 206 DAY, CURDATE() - INTERVAL 178 DAY, CURDATE() - INTERVAL 90 DAY, NULL),
    (21, 1, CURDATE() - INTERVAL 196 DAY, CURDATE() - INTERVAL 168 DAY, CURDATE() - INTERVAL 168 DAY, NULL),
    (16, 5, CURDATE() - INTERVAL 193 DAY, CURDATE() - INTERVAL 165 DAY, CURDATE() - INTERVAL 178 DAY, NULL),
    (27, 3, CURDATE() - INTERVAL 191 DAY, CURDATE() - INTERVAL 149 DAY, CURDATE() - INTERVAL 144 DAY, 'Verlängert um 14 Tage'),
    ((SELECT book_id FROM books WHERE isbn = '9783999000428'), 10, CURDATE() - INTERVAL 189 DAY, CURDATE() - INTERVAL 147 DAY, CURDATE() - INTERVAL 170 DAY, NULL),
    (14, 2, CURDATE() - INTERVAL 187 DAY, CURDATE() - INTERVAL 166 DAY, CURDATE() - INTERVAL 173 DAY, NULL),
    (20, 3, CURDATE() - INTERVAL 187 DAY, CURDATE() - INTERVAL 159 DAY, CURDATE() - INTERVAL 159 DAY, NULL),
    (25, 3, CURDATE() - INTERVAL 185 DAY, CURDATE() - INTERVAL 157 DAY, CURDATE() - INTERVAL 164 DAY, NULL),
    (15, 7, CURDATE() - INTERVAL 180 DAY, CURDATE() - INTERVAL 152 DAY, CURDATE() - INTERVAL 160 DAY, NULL),
    (31, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 179 DAY, CURDATE() - INTERVAL 151 DAY, CURDATE() - INTERVAL 169 DAY, NULL),
    (4, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 173 DAY, CURDATE() - INTERVAL 145 DAY, CURDATE() - INTERVAL 157 DAY, NULL),
    (22, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 169 DAY, CURDATE() - INTERVAL 148 DAY, CURDATE() - INTERVAL 159 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000374'), (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 167 DAY, CURDATE() - INTERVAL 139 DAY, CURDATE() - INTERVAL 143 DAY, NULL),
    (19, 10, CURDATE() - INTERVAL 165 DAY, CURDATE() - INTERVAL 123 DAY, CURDATE() - INTERVAL 124 DAY, 'Verlängert um 14 Tage'),
    (11, 1, CURDATE() - INTERVAL 164 DAY, CURDATE() - INTERVAL 122 DAY, CURDATE() - INTERVAL 129 DAY, 'Verlängert um 14 Tage'),
    (16, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 160 DAY, CURDATE() - INTERVAL 132 DAY, CURDATE() - INTERVAL 148 DAY, NULL),
    (18, 2, CURDATE() - INTERVAL 158 DAY, CURDATE() - INTERVAL 130 DAY, CURDATE() - INTERVAL 140 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000367'), 9, CURDATE() - INTERVAL 155 DAY, CURDATE() - INTERVAL 141 DAY, CURDATE() - INTERVAL 147 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000428'), 6, CURDATE() - INTERVAL 147 DAY, CURDATE() - INTERVAL 119 DAY, CURDATE() - INTERVAL 134 DAY, NULL),
    (13, 7, CURDATE() - INTERVAL 137 DAY, CURDATE() - INTERVAL 109 DAY, CURDATE() - INTERVAL 126 DAY, NULL),
    (21, 10, CURDATE() - INTERVAL 130 DAY, CURDATE() - INTERVAL 102 DAY, CURDATE() - INTERVAL 103 DAY, NULL),
    (22, 5, CURDATE() - INTERVAL 130 DAY, CURDATE() - INTERVAL 102 DAY, CURDATE() - INTERVAL 114 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000428'), 7, CURDATE() - INTERVAL 125 DAY, CURDATE() - INTERVAL 97 DAY, CURDATE() - INTERVAL 99 DAY, 'Verlängert um 14 Tage'),
    (4, 6, CURDATE() - INTERVAL 124 DAY, CURDATE() - INTERVAL 96 DAY, CURDATE() - INTERVAL 94 DAY, NULL),
    (15, 2, CURDATE() - INTERVAL 121 DAY, CURDATE() - INTERVAL 107 DAY, CURDATE() - INTERVAL 116 DAY, NULL),
    (35, 1, CURDATE() - INTERVAL 120 DAY, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 103 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000398'), 3, CURDATE() - INTERVAL 120 DAY, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 92 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000435'), 4, CURDATE() - INTERVAL 120 DAY, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 88 DAY, NULL),
    (30, (SELECT friend_id FROM friends WHERE email = 'ben.schroeder@example.com'), CURDATE() - INTERVAL 119 DAY, CURDATE() - INTERVAL 105 DAY, CURDATE() - INTERVAL 80 DAY, NULL),
    (11, 4, CURDATE() - INTERVAL 118 DAY, CURDATE() - INTERVAL 97 DAY, CURDATE() - INTERVAL 61 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000367'), (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 117 DAY, CURDATE() - INTERVAL 103 DAY, CURDATE() - INTERVAL 110 DAY, NULL),
    (3, 5, CURDATE() - INTERVAL 116 DAY, CURDATE() - INTERVAL 88 DAY, CURDATE() - INTERVAL 106 DAY, NULL),
    (33, (SELECT friend_id FROM friends WHERE email = 'ben.schroeder@example.com'), CURDATE() - INTERVAL 115 DAY, CURDATE() - INTERVAL 87 DAY, CURDATE() - INTERVAL 104 DAY, NULL),
    (20, 1, CURDATE() - INTERVAL 111 DAY, CURDATE() - INTERVAL 69 DAY, CURDATE() - INTERVAL 42 DAY, 'Verlängert um 14 Tage'),
    (28, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 111 DAY, CURDATE() - INTERVAL 83 DAY, CURDATE() - INTERVAL 102 DAY, NULL),
    (29, 5, CURDATE() - INTERVAL 111 DAY, CURDATE() - INTERVAL 83 DAY, CURDATE() - INTERVAL 91 DAY, NULL),
    (6, 6, CURDATE() - INTERVAL 107 DAY, CURDATE() - INTERVAL 79 DAY, CURDATE() - INTERVAL 81 DAY, NULL),
    (19, 12, CURDATE() - INTERVAL 106 DAY, CURDATE() - INTERVAL 64 DAY, CURDATE() - INTERVAL 79 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000404'), 5, CURDATE() - INTERVAL 106 DAY, CURDATE() - INTERVAL 78 DAY, CURDATE() - INTERVAL 82 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000466'), 10, CURDATE() - INTERVAL 105 DAY, CURDATE() - INTERVAL 84 DAY, CURDATE() - INTERVAL 98 DAY, NULL),
    (23, 9, CURDATE() - INTERVAL 104 DAY, CURDATE() - INTERVAL 76 DAY, CURDATE() - INTERVAL 88 DAY, 'Verlängert um 14 Tage'),
    ((SELECT book_id FROM books WHERE isbn = '9783999000411'), 1, CURDATE() - INTERVAL 104 DAY, CURDATE() - INTERVAL 76 DAY, CURDATE() - INTERVAL 78 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000442'), 10, CURDATE() - INTERVAL 103 DAY, CURDATE() - INTERVAL 89 DAY, CURDATE() - INTERVAL 93 DAY, NULL),
    (14, 11, CURDATE() - INTERVAL 100 DAY, CURDATE() - INTERVAL 72 DAY, CURDATE() - INTERVAL 72 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000367'), (SELECT friend_id FROM friends WHERE email = 'kevin.lange@example.com'), CURDATE() - INTERVAL 100 DAY, CURDATE() - INTERVAL 72 DAY, CURDATE() - INTERVAL 48 DAY, NULL),
    (27, 1, CURDATE() - INTERVAL 95 DAY, CURDATE() - INTERVAL 67 DAY, CURDATE() - INTERVAL 80 DAY, NULL),
    (32, 11, CURDATE() - INTERVAL 93 DAY, CURDATE() - INTERVAL 72 DAY, CURDATE() - INTERVAL 83 DAY, NULL),
    (17, 6, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 64 DAY, CURDATE() - INTERVAL 67 DAY, NULL),
    (8, 10, CURDATE() - INTERVAL 92 DAY, CURDATE() - INTERVAL 71 DAY, CURDATE() - INTERVAL 76 DAY, NULL),
    (33, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 89 DAY, CURDATE() - INTERVAL 68 DAY, CURDATE() - INTERVAL 40 DAY, NULL),
    (31, 6, CURDATE() - INTERVAL 86 DAY, CURDATE() - INTERVAL 58 DAY, CURDATE() - INTERVAL 14 DAY, NULL),
    (2, 2, CURDATE() - INTERVAL 83 DAY, CURDATE() - INTERVAL 62 DAY, CURDATE() - INTERVAL 74 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000374'), 1, CURDATE() - INTERVAL 82 DAY, CURDATE() - INTERVAL 54 DAY, CURDATE() - INTERVAL 60 DAY, NULL),
    (19, 7, CURDATE() - INTERVAL 78 DAY, CURDATE() - INTERVAL 50 DAY, CURDATE() - INTERVAL 53 DAY, NULL),
    (28, 5, CURDATE() - INTERVAL 78 DAY, CURDATE() - INTERVAL 36 DAY, CURDATE() - INTERVAL 56 DAY, 'Verlängert um 14 Tage'),
    (34, (SELECT friend_id FROM friends WHERE email = 'nora.schmitt@example.com'), CURDATE() - INTERVAL 77 DAY, CURDATE() - INTERVAL 49 DAY, CURDATE() - INTERVAL 62 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000459'), 5, CURDATE() - INTERVAL 77 DAY, CURDATE() - INTERVAL 35 DAY, CURDATE() - INTERVAL 40 DAY, NULL),
    (7, 8, CURDATE() - INTERVAL 75 DAY, CURDATE() - INTERVAL 47 DAY, CURDATE() - INTERVAL 48 DAY, NULL),
    (16, 7, CURDATE() - INTERVAL 74 DAY, CURDATE() - INTERVAL 46 DAY, CURDATE() - INTERVAL 63 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000442'), 10, CURDATE() - INTERVAL 74 DAY, CURDATE() - INTERVAL 46 DAY, CURDATE() - INTERVAL 24 DAY, NULL),
    (30, (SELECT friend_id FROM friends WHERE email = 'jana.wolf@example.com'), CURDATE() - INTERVAL 69 DAY, CURDATE() - INTERVAL 41 DAY, CURDATE() - INTERVAL 9 DAY, NULL),
    (23, 5, CURDATE() - INTERVAL 66 DAY, CURDATE() - INTERVAL 45 DAY, CURDATE() - INTERVAL 48 DAY, NULL),
    (32, 12, CURDATE() - INTERVAL 64 DAY, CURDATE() - INTERVAL 43 DAY, CURDATE() - INTERVAL 54 DAY, NULL),
    (3, 2, CURDATE() - INTERVAL 63 DAY, CURDATE() - INTERVAL 35 DAY, CURDATE(), NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000381'), (SELECT friend_id FROM friends WHERE email = 'ben.schroeder@example.com'), CURDATE() - INTERVAL 58 DAY, CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 6 DAY, NULL),
    (16, 3, CURDATE() - INTERVAL 57 DAY, CURDATE() - INTERVAL 43 DAY, CURDATE() - INTERVAL 52 DAY, NULL),
    (21, 3, CURDATE() - INTERVAL 55 DAY, CURDATE() - INTERVAL 27 DAY, CURDATE() - INTERVAL 32 DAY, NULL),
    (35, 10, CURDATE() - INTERVAL 55 DAY, CURDATE() - INTERVAL 27 DAY, CURDATE() - INTERVAL 30 DAY, NULL),
    (22, 3, CURDATE() - INTERVAL 53 DAY, CURDATE() - INTERVAL 11 DAY, CURDATE() - INTERVAL 20 DAY, 'Verlängert um 14 Tage'),
    (15, (SELECT friend_id FROM friends WHERE email = 'ben.schroeder@example.com'), CURDATE() - INTERVAL 52 DAY, CURDATE() - INTERVAL 24 DAY, CURDATE() - INTERVAL 2 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000497'), (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 51 DAY, CURDATE() - INTERVAL 23 DAY, CURDATE() - INTERVAL 40 DAY, NULL),
    (23, 10, CURDATE() - INTERVAL 48 DAY, CURDATE() - INTERVAL 13 DAY, CURDATE() - INTERVAL 36 DAY, 'Verlängert um 14 Tage'),
    (28, (SELECT friend_id FROM friends WHERE email = 'ben.schroeder@example.com'), CURDATE() - INTERVAL 48 DAY, CURDATE() - INTERVAL 6 DAY, CURDATE() - INTERVAL 17 DAY, 'Verlängert um 14 Tage'),
    (10, 12, CURDATE() - INTERVAL 46 DAY, CURDATE() - INTERVAL 18 DAY, CURDATE() - INTERVAL 28 DAY, NULL),
    (16, 4, CURDATE() - INTERVAL 44 DAY, CURDATE() - INTERVAL 16 DAY, CURDATE() - INTERVAL 28 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000374'), 7, CURDATE() - INTERVAL 44 DAY, CURDATE() - INTERVAL 16 DAY, CURDATE() - INTERVAL 29 DAY, NULL),
    (11, (SELECT friend_id FROM friends WHERE email = 'kevin.lange@example.com'), CURDATE() - INTERVAL 42 DAY, CURDATE() - INTERVAL 14 DAY, NULL, NULL),
    (33, 4, CURDATE() - INTERVAL 39 DAY, CURDATE() - INTERVAL 11 DAY, CURDATE() - INTERVAL 25 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000466'), (SELECT friend_id FROM friends WHERE email = 'aylin.demir@example.com'), CURDATE() - INTERVAL 38 DAY, CURDATE() - INTERVAL 17 DAY, CURDATE() - INTERVAL 24 DAY, NULL),
    (4, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 36 DAY, CURDATE() - INTERVAL 15 DAY, CURDATE() - INTERVAL 10 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000459'), (SELECT friend_id FROM friends WHERE email = 'kevin.lange@example.com'), CURDATE() - INTERVAL 35 DAY, CURDATE() - INTERVAL 7 DAY, NULL, NULL),
    (1, (SELECT friend_id FROM friends WHERE email = 'nora.schmitt@example.com'), CURDATE() - INTERVAL 32 DAY, CURDATE() - INTERVAL 4 DAY, CURDATE() - INTERVAL 15 DAY, NULL),
    (2, 11, CURDATE() - INTERVAL 31 DAY, CURDATE() - INTERVAL 3 DAY, CURDATE() - INTERVAL 11 DAY, NULL),
    (34, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 31 DAY, CURDATE() + INTERVAL 11 DAY, CURDATE() - INTERVAL 7 DAY, 'Verlängert um 14 Tage'),
    (5, 7, CURDATE() - INTERVAL 31 DAY, CURDATE() - INTERVAL 3 DAY, CURDATE() - INTERVAL 17 DAY, NULL),
    (35, 1, CURDATE() - INTERVAL 29 DAY, CURDATE() - INTERVAL 1 DAY, NULL, NULL),
    (6, 5, CURDATE() - INTERVAL 29 DAY, CURDATE() - INTERVAL 1 DAY, CURDATE() - INTERVAL 11 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000398'), (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 29 DAY, CURDATE() - INTERVAL 1 DAY, CURDATE() - INTERVAL 19 DAY, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000497'), 8, CURDATE() - INTERVAL 29 DAY, CURDATE() - INTERVAL 1 DAY, NULL, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000404'), (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE() - INTERVAL 17 DAY, CURDATE() + INTERVAL 11 DAY, NULL, NULL),
    (14, (SELECT friend_id FROM friends WHERE email = 'nora.schmitt@example.com'), CURDATE() - INTERVAL 15 DAY, CURDATE() + INTERVAL 13 DAY, NULL, NULL),
    (16, 12, CURDATE() - INTERVAL 15 DAY, CURDATE() + INTERVAL 13 DAY, CURDATE() - INTERVAL 6 DAY, NULL),
    (28, 7, CURDATE() - INTERVAL 15 DAY, CURDATE() + INTERVAL 27 DAY, NULL, 'Verlängert um 14 Tage'),
    ((SELECT book_id FROM books WHERE isbn = '9783999000411'), 4, CURDATE() - INTERVAL 14 DAY, CURDATE() + INTERVAL 14 DAY, NULL, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000374'), (SELECT friend_id FROM friends WHERE email = 'aylin.demir@example.com'), CURDATE() - INTERVAL 12 DAY, CURDATE() + INTERVAL 9 DAY, NULL, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000398'), 1, CURDATE() - INTERVAL 12 DAY, CURDATE() + INTERVAL 9 DAY, NULL, NULL),
    ((SELECT book_id FROM books WHERE isbn = '9783999000367'), 10, CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 32 DAY, NULL, NULL),
    (7, 4, CURDATE() - INTERVAL 9 DAY, CURDATE() + INTERVAL 19 DAY, NULL, NULL),
    (22, 5, CURDATE() - INTERVAL 3 DAY, CURDATE() + INTERVAL 25 DAY, NULL, NULL),
    (30, 8, CURDATE() - INTERVAL 3 DAY, CURDATE() + INTERVAL 25 DAY, NULL, NULL),
    (32, 12, CURDATE() - INTERVAL 3 DAY, CURDATE() + INTERVAL 25 DAY, NULL, NULL),
    (31, (SELECT friend_id FROM friends WHERE email = 'paul.hoffmann@example.com'), CURDATE(), CURDATE() + INTERVAL 28 DAY, NULL, NULL);


-- Kontrolle
SELECT (SELECT COUNT(*) FROM books)                          AS buecher,
       (SELECT COUNT(*) FROM friends)                        AS personen,
       (SELECT COUNT(*) FROM loans)                          AS ausleihen,
       (SELECT COUNT(*) FROM loans WHERE return_date IS NULL) AS offen,
       (SELECT COUNT(*) FROM v_overdue_loans)                AS ueberfaellig;
