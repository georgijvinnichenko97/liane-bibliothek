-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 02_master_data.sql
-- Inhalt    : Stammdaten (DML: INSERT): Genres, Verlage, Autoren,
--             Bücher und Ausleiher - aber noch KEINE Ausleihen
-- Voraussetzung: 01_schema.sql wurde ausgeführt
-- =====================================================================
--
-- Hinweise zu den Beispieldaten:
--   * Titel, Autoren und Verlage sind echte Bücher.
--   * Die ISBN-Nummern sind FIKTIV (gültiges Format, aber ausgedacht).
--   * Die Ausleiher sind erfundene Personen, E-Mail-Adressen enden auf
--     example.com, Telefonnummern sind Platzhalter.
--   * Nach diesem Skript gibt es 0 Ausleihen: Liane startet mit leerer
--     Ausleihliste (Verliehen 0, Überfällig 0).
--   * 50 Beispiel-Ausleihen für Präsentation, Analyse und Tests liegen
--     in 06_demo_loans.sql und werden nur bei Bedarf geladen.
-- =====================================================================

USE liane_library_v2;

-- ---------------------------------------------------------------------
-- 1) Genres (11)
-- ---------------------------------------------------------------------
INSERT INTO genres (genre_name) VALUES
    ('Roman'),
    ('Klassiker'),
    ('Science-Fiction'),
    ('Fantasy'),
    ('Kinder- und Jugendbuch'),
    ('Sachbuch'),
    ('Fachbuch IT & Daten'),
    ('Humor'),
    ('Drama'),
    ('Krimi & Thriller'),
    ('Historischer Roman');

-- ---------------------------------------------------------------------
-- 2) Verlage (21)
-- ---------------------------------------------------------------------
INSERT INTO publishers (publisher_name, city) VALUES
    ('Diogenes', 'Zürich'),
    ('Rowohlt', 'Hamburg'),
    ('Kiepenheuer & Witsch', 'Köln'),
    ('Thienemann', 'Stuttgart'),
    ('Suhrkamp', 'Berlin'),
    ('Reclam', 'Ditzingen'),
    ('Ullstein', 'Berlin'),
    ('Karl Rauch', 'Düsseldorf'),
    ('DVA', 'München'),
    ('William Morrow', 'New York'),
    ('dpunkt.verlag', 'Heidelberg'),
    ('O''Reilly', NULL),
    ('Carlsen', 'Hamburg'),
    ('Klett-Cotta', 'Stuttgart'),
    ('S. Fischer', 'Frankfurt am Main'),
    ('Goldmann', 'München'),
    ('Siedler', 'München'),
    ('Hanser', 'München'),
    ('Bastei Lübbe', 'Köln'),
    ('carl''s books', 'München'),
    ('Prentice Hall', NULL);

-- ---------------------------------------------------------------------
-- 3) Autorinnen und Autoren (35)
-- ---------------------------------------------------------------------
INSERT INTO authors (first_name, last_name) VALUES
    ('Bernhard', 'Schlink'),
    ('Patrick', 'Süskind'),
    ('Wolfgang', 'Herrndorf'),
    ('Frank', 'Schätzing'),
    ('Michael', 'Ende'),
    ('Max', 'Frisch'),
    ('Hermann', 'Hesse'),
    ('Franz', 'Kafka'),
    ('George', 'Orwell'),
    ('Antoine de', 'Saint-Exupéry'),
    ('Yuval Noah', 'Harari'),
    ('Hans', 'Rosling'),
    ('Ola', 'Rosling'),
    ('Anna', 'Rosling Rönnlund'),
    ('Marc-Uwe', 'Kling'),
    ('Terry', 'Pratchett'),
    ('Neil', 'Gaiman'),
    ('Steven D.', 'Levitt'),
    ('Stephen J.', 'Dubner'),
    ('Eric', 'Matthes'),
    ('Wes', 'McKinney'),
    ('J. K.', 'Rowling'),
    ('J. R. R.', 'Tolkien'),
    ('Friedrich', 'Dürrenmatt'),
    ('Theodor', 'Fontane'),
    ('Johann Wolfgang von', 'Goethe'),
    ('Erich Maria', 'Remarque'),
    ('Paulo', 'Coelho'),
    ('Stefan', 'Zweig'),
    ('James', 'Clear'),
    ('Daniel', 'Kahneman'),
    ('Umberto', 'Eco'),
    ('Ken', 'Follett'),
    ('Jonas', 'Jonasson'),
    ('Robert C.', 'Martin');

-- ---------------------------------------------------------------------
-- 4) Bücher (35)
--    genre_id und publisher_id werden per Unterabfrage über den Namen
--    gesucht. So ist das Skript lesbar und unabhängig von den IDs.
-- ---------------------------------------------------------------------
INSERT INTO books (isbn, title, genre_id, publisher_id, first_published, language_code, is_lendable, notes, added_on) VALUES
    ('9783999000015', 'Der Vorleser', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Diogenes'), 1995, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000022', 'Das Parfum', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Diogenes'), 1985, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000039', 'Tschick', (SELECT genre_id FROM genres WHERE genre_name = 'Kinder- und Jugendbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Rowohlt'), 2010, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000046', 'Der Schwarm', (SELECT genre_id FROM genres WHERE genre_name = 'Krimi & Thriller'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Kiepenheuer & Witsch'), 2004, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000053', 'Momo', (SELECT genre_id FROM genres WHERE genre_name = 'Kinder- und Jugendbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Thienemann'), 1973, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000060', 'Die unendliche Geschichte', (SELECT genre_id FROM genres WHERE genre_name = 'Fantasy'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Thienemann'), 1979, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000077', 'Homo faber', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Suhrkamp'), 1957, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000084', 'Der Steppenwolf', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Suhrkamp'), 1927, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000091', 'Siddhartha', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Suhrkamp'), 1922, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000107', 'Die Verwandlung', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Reclam'), 1915, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000114', '1984', (SELECT genre_id FROM genres WHERE genre_name = 'Science-Fiction'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 1949, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000121', 'Der kleine Prinz', (SELECT genre_id FROM genres WHERE genre_name = 'Kinder- und Jugendbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Karl Rauch'), 1943, 'de', 0, 'Erbstück von Oma, wird nicht verliehen', CURDATE() - INTERVAL 420 DAY),
    ('9783999000138', 'Eine kurze Geschichte der Menschheit', (SELECT genre_id FROM genres WHERE genre_name = 'Sachbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'DVA'), 2011, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000145', 'Factfulness', (SELECT genre_id FROM genres WHERE genre_name = 'Sachbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 2018, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000152', 'Die Känguru-Chroniken', (SELECT genre_id FROM genres WHERE genre_name = 'Humor'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 2009, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000169', 'QualityLand', (SELECT genre_id FROM genres WHERE genre_name = 'Science-Fiction'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Ullstein'), 2017, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    (NULL, 'Good Omens', (SELECT genre_id FROM genres WHERE genre_name = 'Fantasy'), NULL, 1990, 'en', 1, 'Englische Ausgabe', CURDATE() - INTERVAL 420 DAY),
    ('9783999000183', 'Freakonomics', (SELECT genre_id FROM genres WHERE genre_name = 'Sachbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'William Morrow'), 2005, 'en', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000190', 'Python Crashkurs', (SELECT genre_id FROM genres WHERE genre_name = 'Fachbuch IT & Daten'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'dpunkt.verlag'), 2015, 'de', 1, NULL, CURDATE() - INTERVAL 300 DAY),
    ('9783999000206', 'Datenanalyse mit Python', (SELECT genre_id FROM genres WHERE genre_name = 'Fachbuch IT & Daten'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'O''Reilly'), 2012, 'de', 1, NULL, CURDATE() - INTERVAL 300 DAY),
    ('9783999000213', 'Harry Potter und der Stein der Weisen', (SELECT genre_id FROM genres WHERE genre_name = 'Fantasy'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Carlsen'), 1997, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000220', 'Der Herr der Ringe', (SELECT genre_id FROM genres WHERE genre_name = 'Fantasy'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Klett-Cotta'), 1954, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000237', 'Der Hobbit', (SELECT genre_id FROM genres WHERE genre_name = 'Fantasy'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Klett-Cotta'), 1937, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000244', 'Die Physiker', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Diogenes'), 1962, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    (NULL, 'Effi Briest', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Reclam'), 1896, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    (NULL, 'Faust. Der Tragödie erster Teil', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Reclam'), 1808, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000275', 'Im Westen nichts Neues', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Kiepenheuer & Witsch'), 1929, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000282', 'Der Alchimist', (SELECT genre_id FROM genres WHERE genre_name = 'Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Diogenes'), 1988, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000299', 'Schachnovelle', (SELECT genre_id FROM genres WHERE genre_name = 'Klassiker'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'S. Fischer'), 1942, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000305', 'Die 1%-Methode', (SELECT genre_id FROM genres WHERE genre_name = 'Sachbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Goldmann'), 2018, 'de', 1, NULL, CURDATE() - INTERVAL 200 DAY),
    ('9783999000312', 'Schnelles Denken, langsames Denken', (SELECT genre_id FROM genres WHERE genre_name = 'Sachbuch'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Siedler'), 2011, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000329', 'Der Name der Rose', (SELECT genre_id FROM genres WHERE genre_name = 'Krimi & Thriller'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Hanser'), 1980, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000336', 'Die Säulen der Erde', (SELECT genre_id FROM genres WHERE genre_name = 'Historischer Roman'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Bastei Lübbe'), 1989, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000343', 'Der Hundertjährige, der aus dem Fenster stieg und verschwand', (SELECT genre_id FROM genres WHERE genre_name = 'Humor'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'carl''s books'), 2009, 'de', 1, NULL, CURDATE() - INTERVAL 420 DAY),
    ('9783999000350', 'Clean Code', (SELECT genre_id FROM genres WHERE genre_name = 'Fachbuch IT & Daten'), (SELECT publisher_id FROM publishers WHERE publisher_name = 'Prentice Hall'), 2008, 'en', 1, 'Neu gekauft', CURDATE() - INTERVAL 25 DAY);

-- ---------------------------------------------------------------------
-- 5) Zuordnung Buch <-> Autor (n:m)
--    Factfulness, Good Omens und Freakonomics haben mehrere Autoren.
-- ---------------------------------------------------------------------
INSERT INTO book_authors (book_id, author_id, author_order) VALUES
    (1, 1, 1),   -- Der Vorleser / Bernhard Schlink
    (2, 2, 1),   -- Das Parfum / Patrick Süskind
    (3, 3, 1),   -- Tschick / Wolfgang Herrndorf
    (4, 4, 1),   -- Der Schwarm / Frank Schätzing
    (5, 5, 1),   -- Momo / Michael Ende
    (6, 5, 1),   -- Die unendliche Geschichte / Michael Ende
    (7, 6, 1),   -- Homo faber / Max Frisch
    (8, 7, 1),   -- Der Steppenwolf / Hermann Hesse
    (9, 7, 1),   -- Siddhartha / Hermann Hesse
    (10, 8, 1),   -- Die Verwandlung / Franz Kafka
    (11, 9, 1),   -- 1984 / George Orwell
    (12, 10, 1),   -- Der kleine Prinz / Antoine de Saint-Exupéry
    (13, 11, 1),   -- Eine kurze Geschichte der Menschheit / Yuval Noah Harari
    (14, 12, 1),   -- Factfulness / Hans Rosling
    (14, 13, 2),   -- Factfulness / Ola Rosling
    (14, 14, 3),   -- Factfulness / Anna Rosling Rönnlund
    (15, 15, 1),   -- Die Känguru-Chroniken / Marc-Uwe Kling
    (16, 15, 1),   -- QualityLand / Marc-Uwe Kling
    (17, 16, 1),   -- Good Omens / Terry Pratchett
    (17, 17, 2),   -- Good Omens / Neil Gaiman
    (18, 18, 1),   -- Freakonomics / Steven D. Levitt
    (18, 19, 2),   -- Freakonomics / Stephen J. Dubner
    (19, 20, 1),   -- Python Crashkurs / Eric Matthes
    (20, 21, 1),   -- Datenanalyse mit Python / Wes McKinney
    (21, 22, 1),   -- Harry Potter und der Stein der Weisen / J. K. Rowling
    (22, 23, 1),   -- Der Herr der Ringe / J. R. R. Tolkien
    (23, 23, 1),   -- Der Hobbit / J. R. R. Tolkien
    (24, 24, 1),   -- Die Physiker / Friedrich Dürrenmatt
    (25, 25, 1),   -- Effi Briest / Theodor Fontane
    (26, 26, 1),   -- Faust. Der Tragödie erster Teil / Johann Wolfgang von Goethe
    (27, 27, 1),   -- Im Westen nichts Neues / Erich Maria Remarque
    (28, 28, 1),   -- Der Alchimist / Paulo Coelho
    (29, 29, 1),   -- Schachnovelle / Stefan Zweig
    (30, 30, 1),   -- Die 1%-Methode / James Clear
    (31, 31, 1),   -- Schnelles Denken, langsames Denken / Daniel Kahneman
    (32, 32, 1),   -- Der Name der Rose / Umberto Eco
    (33, 33, 1),   -- Die Säulen der Erde / Ken Follett
    (34, 34, 1),   -- Der Hundertjährige, der aus dem Fenster stieg und verschwand / Jonas Jonasson
    (35, 35, 1);   -- Clean Code / Robert C. Martin

-- ---------------------------------------------------------------------
-- 6) Ausleiher (12)
-- ---------------------------------------------------------------------
INSERT INTO friends (first_name, last_name, email, phone, street, postal_code, city, relationship, max_loans, notes) VALUES
    ('Anna', 'Becker', 'anna.becker@example.com', '+49 151 1000 0001', 'Lindenstraße 12', '10969', 'Berlin', 'Freundeskreis', 4, 'Liest am liebsten Sachbücher'),
    ('Jonas', 'Weber', 'jonas.weber@example.com', NULL, NULL, NULL, NULL, 'Kollegium', 3, NULL),
    ('Mira', 'Schulz', 'mira.schulz@example.com', '+49 151 1000 0003', 'Kastanienallee 5', '10435', 'Berlin', 'Freundeskreis', 3, NULL),
    ('Tobias', 'Klein', NULL, '+49 151 1000 0004', NULL, NULL, NULL, 'Bekanntschaft', 2, 'Gibt Bücher oft zu spät zurück'),
    ('Lea', 'Hoffmann', 'lea.hoffmann@example.com', '+49 151 1000 0005', 'Gartenweg 3', '14467', 'Potsdam', 'Familie', 5, 'Schwester'),
    ('Can', 'Yılmaz', 'can.yilmaz@example.com', NULL, NULL, NULL, NULL, 'Kollegium', 3, NULL),
    ('Sofia', 'Rossi', 'sofia.rossi@example.com', '+49 151 1000 0007', 'Lindenstraße 14', '10969', 'Berlin', 'Nachbarschaft', 2, NULL),
    ('Felix', 'Wagner', 'felix.wagner@example.com', NULL, NULL, NULL, NULL, 'Bekanntschaft', 2, NULL),
    ('Hannah', 'Krüger', 'hannah.krueger@example.com', '+49 151 1000 0009', NULL, NULL, NULL, 'Kollegium', 3, NULL),
    ('David', 'Nowak', 'david.nowak@example.com', '+49 151 1000 0010', 'Bergmannstraße 20', '10961', 'Berlin', 'Freundeskreis', 3, NULL),
    ('Emma', 'Fischer', NULL, '+49 151 1000 0011', 'Lindenstraße 10', '10969', 'Berlin', 'Nachbarschaft', 2, NULL),
    ('Lukas', 'Braun', 'lukas.braun@example.com', NULL, NULL, NULL, NULL, 'Kollegium', 3, 'Neuer Kollege, noch nichts ausgeliehen');


-- ---------------------------------------------------------------------
-- Kontrolle: Anzahl Datensätze pro Tabelle (loans = 0)
-- ---------------------------------------------------------------------
SELECT 'genres' AS tabelle, COUNT(*) AS anzahl FROM genres
UNION ALL SELECT 'publishers',   COUNT(*) FROM publishers
UNION ALL SELECT 'authors',      COUNT(*) FROM authors
UNION ALL SELECT 'books',        COUNT(*) FROM books
UNION ALL SELECT 'book_authors', COUNT(*) FROM book_authors
UNION ALL SELECT 'friends',      COUNT(*) FROM friends
UNION ALL SELECT 'loans',        COUNT(*) FROM loans;
