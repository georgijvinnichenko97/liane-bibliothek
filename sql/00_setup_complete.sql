-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 00_setup_complete.sql
-- Inhalt    : 01_schema + 02_master_data + 03_views + 04_procedures
--             + 05_app_user in einer Datei. In MySQL Workbench komplett
--             ausführen (Blitz-Symbol oder Strg+Shift+Enter).
--             Ergebnis: Datenbank liane_library_v2 mit 35 Büchern und
--             12 Personen, 0 Ausleihen. Version 1 bleibt unberührt.
-- Optional  : 06_demo_loans.sql (50 Beispiel-Ausleihen) oder
--             07_demo_one_year.sql (Szenario "Ein Jahr später").
-- Danach    : 08_queries.sql (Abfragen) und 09_tests.sql (Tests).
--
-- Diese Datei wird erzeugt: python tools/build_setup.py
-- Änderungen bitte in den Einzeldateien 01 bis 05 machen.
-- =====================================================================


-- #####################################################################
-- ##  01_schema.sql
-- #####################################################################

-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 01_schema.sql
-- Inhalt    : Datenbank und alle Tabellen anlegen (DDL)
-- Datenbank : MySQL 8.0.16 oder neuer (CHECK-Constraints, DEFAULT-Ausdrücke)
-- Reihenfolge der Skripte: 01 -> 02 -> 03 -> 04 -> 05 (App-Benutzer),
--                          optional 06 oder 07 (Demo-Ausleihen),
--                          dann 08 (Abfragen) und 09 (Tests)
-- =====================================================================
--
-- Das Datenmodell ist dasselbe wie in Version 1: 7 Tabellen in der
-- 3. Normalform, 11 CHECK-Constraints.
--
--   genres        Genres (Nachschlagetabelle)
--   publishers    Verlage
--   authors       Autorinnen und Autoren
--   books         Lianes Bücher
--   book_authors  Verbindung Buch <-> Autor (n:m)
--   friends       Ausleiher: Freundeskreis, Familie, Kollegium, ...
--   loans         Ausleihvorgänge (wer hat wann welches Buch)
--
-- Version 2 hat eine EIGENE Datenbank (liane_library_v2). Version 1
-- (liane_library) bleibt unberührt, beide laufen nebeneinander.
--
-- ACHTUNG: Das Skript löscht eine vorhandene Datenbank liane_library_v2
--          und legt sie neu an.
-- =====================================================================

DROP DATABASE IF EXISTS liane_library_v2;

CREATE DATABASE liane_library_v2
    CHARACTER SET utf8mb4               -- speichert alle Zeichen (ä, ö, ü, ß, ı, é ...)
    COLLATE utf8mb4_0900_ai_ci;         -- Standard-Sortierung von MySQL 8

USE liane_library_v2;


-- ---------------------------------------------------------------------
-- 1) genres: Genre eines Buches
--    Eigene Tabelle, damit jedes Genre nur einmal gespeichert wird
--    und keine Tippfehler entstehen ("Krimi" vs. "Krimis").
-- ---------------------------------------------------------------------
CREATE TABLE genres (
    genre_id    INT          AUTO_INCREMENT PRIMARY KEY,
    genre_name  VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_genres_name UNIQUE (genre_name)
);


-- ---------------------------------------------------------------------
-- 2) publishers: Verlage
--    Der Verlagsort hängt vom Verlag ab, nicht vom Buch (3NF).
-- ---------------------------------------------------------------------
CREATE TABLE publishers (
    publisher_id    INT           AUTO_INCREMENT PRIMARY KEY,
    publisher_name  VARCHAR(100)  NOT NULL,
    city            VARCHAR(100),                  -- optional
    CONSTRAINT uq_publishers_name UNIQUE (publisher_name)
);


-- ---------------------------------------------------------------------
-- 3) authors: Autorinnen und Autoren
--    Vorname ist optional (z. B. bei Autoren mit nur einem Namen).
-- ---------------------------------------------------------------------
CREATE TABLE authors (
    author_id   INT           AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(100),
    last_name   VARCHAR(100)  NOT NULL
);


-- ---------------------------------------------------------------------
-- 4) books: Lianes Bücher
--    - book_id ist ein künstlicher Schlüssel (ändert sich nie).
--    - isbn ist optional, aber eindeutig (alte Bücher haben keine ISBN).
--    - Ob ein Buch gerade verliehen ist, wird NICHT hier gespeichert,
--      sondern aus der Tabelle loans berechnet (siehe Views).
-- ---------------------------------------------------------------------
CREATE TABLE books (
    book_id          INT           AUTO_INCREMENT PRIMARY KEY,
    isbn             VARCHAR(13),                          -- ISBN-10 oder ISBN-13, ohne Bindestriche
    title            VARCHAR(255)  NOT NULL,
    genre_id         INT,
    publisher_id     INT,
    first_published  SMALLINT,                             -- Jahr der Erstveröffentlichung (YEAR reicht nur ab 1901)
    language_code    CHAR(2)       NOT NULL DEFAULT 'de',  -- Sprachcode nach ISO 639-1: de, en, fr ...
    is_lendable      TINYINT(1)    NOT NULL DEFAULT 1,     -- 1 = darf verliehen werden, 0 = bleibt bei Liane
    notes            TEXT,
    added_on         DATE          NOT NULL DEFAULT (CURRENT_DATE),

    CONSTRAINT uq_books_isbn UNIQUE (isbn),
    -- Hinweis: Ein CHECK schlägt nur fehl, wenn das Ergebnis FALSE ist.
    --          Bei NULL (z. B. keine ISBN) ist der Wert erlaubt.
    CONSTRAINT chk_books_isbn      CHECK (REGEXP_LIKE(isbn, '^([0-9]{9}[0-9X]|[0-9]{13})$', 'c')),
    CONSTRAINT chk_books_year      CHECK (first_published BETWEEN 1450 AND 2100),
    CONSTRAINT chk_books_language  CHECK (REGEXP_LIKE(language_code, '^[a-z]{2}$', 'c')),
    CONSTRAINT chk_books_lendable  CHECK (is_lendable IN (0, 1)),

    CONSTRAINT fk_books_genre FOREIGN KEY (genre_id)
        REFERENCES genres (genre_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_books_publisher FOREIGN KEY (publisher_id)
        REFERENCES publishers (publisher_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);


-- ---------------------------------------------------------------------
-- 5) book_authors: Verbindungstabelle für die n:m-Beziehung
--    Ein Buch kann mehrere Autoren haben, ein Autor mehrere Bücher.
--    Der Primärschlüssel ist zusammengesetzt (book_id, author_id).
-- ---------------------------------------------------------------------
CREATE TABLE book_authors (
    book_id       INT               NOT NULL,
    author_id     INT               NOT NULL,
    author_order  TINYINT UNSIGNED  NOT NULL DEFAULT 1,    -- 1 = Erstautor, 2 = zweiter Autor ...

    PRIMARY KEY (book_id, author_id),
    CONSTRAINT chk_ba_order CHECK (author_order BETWEEN 1 AND 20),

    CONSTRAINT fk_ba_book FOREIGN KEY (book_id)
        REFERENCES books (book_id)
        ON UPDATE CASCADE ON DELETE CASCADE,               -- Buch weg -> Zuordnungen weg
    CONSTRAINT fk_ba_author FOREIGN KEY (author_id)
        REFERENCES authors (author_id)
        ON UPDATE CASCADE ON DELETE RESTRICT               -- Autor mit Büchern nicht löschbar
);


-- ---------------------------------------------------------------------
-- 6) friends: alle Personen, die Bücher ausleihen
--    - Name, Kontakt und Adresse sind in atomare Spalten getrennt (1NF).
--    - Mindestens E-Mail ODER Telefon ist Pflicht (Regel 6).
--    - max_loans: so viele Bücher darf die Person gleichzeitig haben.
-- ---------------------------------------------------------------------
CREATE TABLE friends (
    friend_id     INT               AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(100)      NOT NULL,
    last_name     VARCHAR(100)      NOT NULL,
    email         VARCHAR(255),
    phone         VARCHAR(30),                             -- VARCHAR, damit auch +49 ... passt
    street        VARCHAR(150),
    postal_code   VARCHAR(10),                             -- VARCHAR, damit führende Nullen bleiben (01067)
    city          VARCHAR(100),
    relationship  VARCHAR(20)       NOT NULL DEFAULT 'Freundeskreis',
    max_loans     TINYINT UNSIGNED  NOT NULL DEFAULT 3,
    notes         TEXT,
    created_at    TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_friends_email       UNIQUE (email),
    CONSTRAINT chk_friends_contact    CHECK (email IS NOT NULL OR phone IS NOT NULL),
    CONSTRAINT chk_friends_email      CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT chk_friends_relation   CHECK (relationship IN
        ('Freundeskreis', 'Familie', 'Kollegium', 'Nachbarschaft', 'Bekanntschaft')),
    CONSTRAINT chk_friends_max_loans  CHECK (max_loans BETWEEN 1 AND 10)
);


-- ---------------------------------------------------------------------
-- 7) loans: Ausleihvorgänge
--    - Ein Buch wird mit der Zeit oft verliehen (books 1:n loans).
--    - return_date ist NULL, solange das Buch noch nicht zurück ist.
--    - open_book_id ist eine berechnete Hilfsspalte: Sie enthält die
--      book_id nur bei offenen Ausleihen. Der UNIQUE-Constraint darauf
--      sorgt dafür, dass ein Buch nie zweimal gleichzeitig verliehen ist
--      (Regel 1). NULL-Werte zählen bei UNIQUE nicht als Duplikat,
--      deshalb sind beliebig viele abgeschlossene Ausleihen erlaubt.
--    - Die Regeln 2, 3 und 5 prüft ein Trigger auf dieser Tabelle
--      (siehe 04_procedures.sql).
-- ---------------------------------------------------------------------
CREATE TABLE loans (
    loan_id       INT           AUTO_INCREMENT PRIMARY KEY,
    book_id       INT           NOT NULL,
    friend_id     INT           NOT NULL,
    loan_date     DATE          NOT NULL DEFAULT (CURRENT_DATE),
    due_date      DATE          NOT NULL,
    return_date   DATE,
    notes         VARCHAR(255),
    open_book_id  INT GENERATED ALWAYS AS (IF(return_date IS NULL, book_id, NULL)) STORED,

    CONSTRAINT uq_loans_one_open_per_book UNIQUE (open_book_id),
    CONSTRAINT chk_loans_due     CHECK (due_date >= loan_date),
    CONSTRAINT chk_loans_return  CHECK (return_date >= loan_date),

    -- RESTRICT: Bücher und Ausleiher mit Ausleih-Historie können nicht
    -- gelöscht werden (Regel 7). CASCADE ist hier ohnehin nicht erlaubt,
    -- weil book_id die Grundlage der berechneten Spalte open_book_id ist.
    CONSTRAINT fk_loans_book FOREIGN KEY (book_id)
        REFERENCES books (book_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_loans_friend FOREIGN KEY (friend_id)
        REFERENCES friends (friend_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Index für die häufigste Abfrage "Was ist überfällig?"
CREATE INDEX idx_loans_open_due ON loans (return_date, due_date);

-- Kontrolle: Welche Tabellen gibt es jetzt?
SHOW TABLES;


-- #####################################################################
-- ##  02_master_data.sql
-- #####################################################################

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


-- #####################################################################
-- ##  03_views.sql
-- #####################################################################

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


-- #####################################################################
-- ##  04_procedures.sql
-- #####################################################################

-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 04_procedures.sql
-- Inhalt    : 2 Trigger und 7 Stored Procedures (die Logik der Datenbank)
-- Voraussetzung: 01_schema.sql und 03_views.sql
-- =====================================================================
--
-- TEIL 1: TRIGGER auf der Tabelle loans
--   Ein Trigger ist ein Programm, das MySQL AUTOMATISCH ausführt, zum
--   Beispiel vor jedem INSERT. Niemand muss ihn aufrufen, und niemand
--   kann ihn vergessen.
--
--   trg_loans_before_insert  prüft bei JEDER neuen Ausleihe:
--                              Regel 5  Buch ist verleihbar
--                              Regel 1  Buch ist nicht schon verliehen
--                              Regel 3  Person hat nichts Überfälliges
--                              Regel 2  Person hat ihr Limit nicht erreicht
--   trg_loans_before_update  schützt bestehende Ausleihen: Buch, Person
--                            und Ausleihdatum bleiben fest, eine Rückgabe
--                            kann nicht zurückgenommen werden.
--
--   Unterschied zu Version 1: Dort standen die Regeln 2, 3 und 5 nur in
--   der Procedure sp_lend_book. Ein direktes INSERT INTO loans (zum
--   Beispiel in MySQL Workbench) konnte sie umgehen. Jetzt gelten sie für
--   jeden Weg in die Tabelle, und jede Regel steht nur an einer Stelle.
--
-- TEIL 2: STORED PROCEDURES (gleiche Namen und Parameter wie in Version 1)
--   sp_add_book            neues Buch erfassen (legt Autor/Genre/Verlag
--                          bei Bedarf automatisch an)
--   sp_add_author_to_book  weiteren Autor zu einem Buch hinzufügen
--   sp_lend_book           Buch verleihen (die Regeln prüft der Trigger)
--   sp_return_book         Rückgabe erfassen
--   sp_extend_loan         Leihfrist verlängern
--   sp_find_book           Buch suchen (Titel, Autor oder ISBN)
--   sp_add_friend          neue Person (Ausleiher) anlegen
--
-- Fehler werden mit SIGNAL SQLSTATE '45000' ausgelöst. '45000' bedeutet
-- "benutzerdefinierter Fehler" (MySQL-Fehlercode 1644). MESSAGE_TEXT ist
-- auf 128 Zeichen begrenzt, deshalb kürzt LEFT(..., 128) lange Meldungen.
--
-- DELIMITER: Innerhalb eines Triggers oder einer Procedure stehen mehrere
-- Befehle mit ";". Damit MySQL Workbench nicht beim ersten ";" abschneidet,
-- wird das Trennzeichen vorübergehend auf $$ gesetzt.
-- =====================================================================

USE liane_library_v2;

DELIMITER $$


-- =====================================================================
-- TEIL 1: TRIGGER
-- =====================================================================

-- ---------------------------------------------------------------------
-- trg_loans_before_insert: Regeln 1, 2, 3 und 5 für jede neue Ausleihe
--
--   NEW ist die Zeile, die gerade eingefügt werden soll.
--   Geprüft wird für den TAG DER AUSLEIHE (v_day). Bei einer normalen
--   Ausleihe ist das heute. So kann Liane auch eine alte Ausleihe
--   nachtragen, und die Demo-Daten laufen durch dieselbe Prüfung.
--
--   "Am Tag v_day noch nicht zurück" heißt:
--       return_date IS NULL  ODER  return_date > v_day
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_loans_before_insert $$
CREATE TRIGGER trg_loans_before_insert
BEFORE INSERT ON loans
FOR EACH ROW
BEGIN
    DECLARE v_day          DATE;
    DECLARE v_title        VARCHAR(255);
    DECLARE v_lendable     TINYINT;
    DECLARE v_friend_name  VARCHAR(201);
    DECLARE v_max_loans    INT;
    DECLARE v_conflict_id  INT;
    DECLARE v_holder       VARCHAR(201);
    DECLARE v_holder_open  TINYINT;
    DECLARE v_open_loans   INT;
    DECLARE v_overdue      INT;
    DECLARE v_msg          VARCHAR(500);

    SET v_day = COALESCE(NEW.loan_date, CURDATE());

    -- Daten zum Buch und zur Person holen
    SET v_title       = (SELECT title       FROM books   WHERE book_id   = NEW.book_id);
    SET v_lendable    = (SELECT is_lendable FROM books   WHERE book_id   = NEW.book_id);
    SET v_friend_name = (SELECT CONCAT(first_name, ' ', last_name)
                           FROM friends WHERE friend_id = NEW.friend_id);
    SET v_max_loans   = (SELECT max_loans   FROM friends WHERE friend_id = NEW.friend_id);

    -- Gibt es das Buch oder die Person nicht, meldet das gleich danach
    -- der Fremdschlüssel (Fehler 1452). Hier ist dann nichts zu prüfen.
    IF v_title IS NOT NULL AND v_friend_name IS NOT NULL THEN

        -- Regel 5: nicht verleihbare Bücher bleiben im Regal
        IF v_lendable = 0 THEN
            SET v_msg = LEFT(CONCAT('"', v_title, '" ist als nicht verleihbar markiert.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        -- Regel 1: Das Buch ist im selben Zeitraum schon bei jemandem.
        -- Zwei Zeiträume überschneiden sich, wenn jeder beginnt, bevor
        -- der andere endet. Eine offene Ausleihe hat noch kein Ende.
        -- MIN() liefert immer genau eine Zeile: die loan_id der störenden
        -- Ausleihe oder NULL, wenn es keine gibt.
        SELECT MIN(l.loan_id)
          INTO v_conflict_id
          FROM loans l
         WHERE l.book_id = NEW.book_id
           AND (NEW.return_date IS NULL OR l.loan_date < NEW.return_date)
           AND (l.return_date  IS NULL OR l.return_date  > v_day);

        IF v_conflict_id IS NOT NULL THEN
            SELECT CONCAT(f.first_name, ' ', f.last_name), l.return_date IS NULL
              INTO v_holder, v_holder_open
              FROM loans l
              JOIN friends f ON f.friend_id = l.friend_id
             WHERE l.loan_id = v_conflict_id;

            SET v_msg = LEFT(CONCAT('"', v_title, '" ',
                                    IF(v_holder_open = 1, 'ist bereits an ', 'war in diesem Zeitraum an '),
                                    v_holder, ' verliehen.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        -- Regel 3: Wer am Tag der Ausleihe etwas Überfälliges hat,
        -- bekommt nichts Neues.
        SELECT COUNT(*)
          INTO v_overdue
          FROM loans l
         WHERE l.friend_id = NEW.friend_id
           AND l.due_date  < v_day
           AND (l.return_date IS NULL OR l.return_date > v_day);

        IF v_overdue > 0 THEN
            SET v_msg = LEFT(CONCAT(v_friend_name, ' hat noch ', v_overdue,
                                    IF(v_overdue = 1, ' überfälliges Buch', ' überfällige Bücher'),
                                    '. Bitte erst zurückgeben.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        -- Regel 2: höchstens max_loans Bücher gleichzeitig
        SELECT COUNT(*)
          INTO v_open_loans
          FROM loans l
         WHERE l.friend_id = NEW.friend_id
           AND l.loan_date <= v_day
           AND (l.return_date IS NULL OR l.return_date > v_day);

        IF v_open_loans >= v_max_loans THEN
            SET v_msg = LEFT(CONCAT(v_friend_name, ' hat bereits ', v_open_loans,
                                    ' von maximal ', v_max_loans, ' Büchern.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

    END IF;
END $$


-- ---------------------------------------------------------------------
-- trg_loans_before_update: bestehende Ausleihen schützen
--
--   OLD ist die Zeile vor der Änderung, NEW die Zeile danach.
--   Erlaubt bleibt, was die Procedures tun: Rückgabe eintragen
--   (return_date), Frist verlängern (due_date) und eine Notiz ändern.
--   Ohne diesen Trigger könnte man die Regeln mit einem UPDATE umgehen,
--   zum Beispiel eine Ausleihe auf eine Person mit vollem Limit umhängen.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_loans_before_update $$
CREATE TRIGGER trg_loans_before_update
BEFORE UPDATE ON loans
FOR EACH ROW
BEGIN
    IF NEW.book_id <> OLD.book_id
       OR NEW.friend_id <> OLD.friend_id
       OR NEW.loan_date <> OLD.loan_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Buch, Person und Ausleihdatum einer Ausleihe sind fest. Bitte zurückgeben und neu verleihen.';
    END IF;

    IF OLD.return_date IS NOT NULL AND NEW.return_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Eine Rückgabe kann nicht zurückgenommen werden. Bitte das Buch neu verleihen.';
    END IF;
END $$


-- =====================================================================
-- TEIL 2: STORED PROCEDURES
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_add_book: neues Buch erfassen
-- Beispiel:
--   CALL sp_add_book('Der Gesang der Flusskrebse', 'Delia', 'Owens',
--                    'Roman', 'hanserblau', 2018, NULL);
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_add_book $$
CREATE PROCEDURE sp_add_book(
    IN p_title            VARCHAR(255),
    IN p_author_first     VARCHAR(100),
    IN p_author_last      VARCHAR(100),
    IN p_genre            VARCHAR(50),
    IN p_publisher        VARCHAR(100),
    IN p_first_published  INT,             -- INT, damit auch 99999 eine deutsche Meldung bekommt
    IN p_isbn             VARCHAR(20)      -- Bindestriche und Leerzeichen erlaubt
)
BEGIN
    DECLARE v_title        VARCHAR(255);
    DECLARE v_author_first VARCHAR(100);
    DECLARE v_author_last  VARCHAR(100);
    DECLARE v_genre        VARCHAR(50);
    DECLARE v_publisher    VARCHAR(100);
    DECLARE v_isbn         VARCHAR(20);
    DECLARE v_genre_id     INT DEFAULT NULL;
    DECLARE v_publisher_id INT DEFAULT NULL;
    DECLARE v_author_id    INT DEFAULT NULL;
    DECLARE v_book_id      INT DEFAULT NULL;

    -- Tritt irgendein Fehler auf, wird alles rückgängig gemacht
    -- und der Fehler an den Aufrufer weitergegeben.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Eingaben einmal aufräumen: Leerzeichen am Rand weg, '' wird zu NULL.
    -- ISBN: zusätzlich Bindestriche und Leerzeichen entfernen.
    SET v_title        = NULLIF(TRIM(p_title), '');
    SET v_author_first = NULLIF(TRIM(p_author_first), '');
    SET v_author_last  = NULLIF(TRIM(p_author_last), '');
    SET v_genre        = NULLIF(TRIM(p_genre), '');
    SET v_publisher    = NULLIF(TRIM(p_publisher), '');
    SET v_isbn         = NULLIF(REPLACE(REPLACE(TRIM(p_isbn), '-', ''), ' ', ''), '');

    -- Eingaben prüfen.
    -- (Die CHECK-Constraints greifen auch, melden sich aber nur auf Englisch.)
    IF v_title IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bitte einen Titel angeben.';
    END IF;
    IF v_author_last IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bitte mindestens den Nachnamen des Autors angeben.';
    END IF;
    IF v_isbn IS NOT NULL AND NOT REGEXP_LIKE(v_isbn, '^([0-9]{9}[0-9X]|[0-9]{13})$', 'c') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die ISBN muss 10 oder 13 Ziffern haben (bei ISBN-10 darf am Ende ein X stehen).';
    END IF;
    IF v_isbn IS NOT NULL AND EXISTS (SELECT 1 FROM books WHERE isbn = v_isbn) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Diese ISBN gibt es schon in der Bibliothek.';
    END IF;
    IF p_first_published IS NOT NULL AND (p_first_published < 1450 OR p_first_published > 2100) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Das Erscheinungsjahr muss zwischen 1450 und 2100 liegen.';
    END IF;

    -- Ab hier wird gespeichert: alles oder nichts.
    START TRANSACTION;

    -- Genre suchen, sonst neu anlegen
    IF v_genre IS NOT NULL THEN
        SET v_genre_id = (SELECT genre_id FROM genres WHERE genre_name = v_genre);
        IF v_genre_id IS NULL THEN
            INSERT INTO genres (genre_name) VALUES (v_genre);
            SET v_genre_id = LAST_INSERT_ID();
        END IF;
    END IF;

    -- Verlag suchen, sonst neu anlegen
    IF v_publisher IS NOT NULL THEN
        SET v_publisher_id = (SELECT publisher_id FROM publishers WHERE publisher_name = v_publisher);
        IF v_publisher_id IS NULL THEN
            INSERT INTO publishers (publisher_name) VALUES (v_publisher);
            SET v_publisher_id = LAST_INSERT_ID();
        END IF;
    END IF;

    -- Autor suchen, sonst neu anlegen
    -- <=> ist ein NULL-sicherer Vergleich (NULL <=> NULL ergibt TRUE)
    SET v_author_id = (SELECT MIN(author_id) FROM authors
                        WHERE last_name = v_author_last
                          AND first_name <=> v_author_first);
    IF v_author_id IS NULL THEN
        INSERT INTO authors (first_name, last_name) VALUES (v_author_first, v_author_last);
        SET v_author_id = LAST_INSERT_ID();
    END IF;

    -- Buch und Zuordnung speichern
    INSERT INTO books (isbn, title, genre_id, publisher_id, first_published)
    VALUES (v_isbn, v_title, v_genre_id, v_publisher_id, p_first_published);
    SET v_book_id = LAST_INSERT_ID();

    INSERT INTO book_authors (book_id, author_id, author_order)
    VALUES (v_book_id, v_author_id, 1);

    COMMIT;

    SELECT v_book_id AS book_id, v_title AS title, 'Buch wurde gespeichert.' AS message;
END $$


-- ---------------------------------------------------------------------
-- sp_add_author_to_book: weiteren Autor ergänzen
-- Beispiel:  CALL sp_add_author_to_book(36, 'Max', 'Mustermann');
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_add_author_to_book $$
CREATE PROCEDURE sp_add_author_to_book(
    IN p_book_id       INT,
    IN p_author_first  VARCHAR(100),
    IN p_author_last   VARCHAR(100)
)
BEGIN
    DECLARE v_author_first VARCHAR(100);
    DECLARE v_author_last  VARCHAR(100);
    DECLARE v_author_id    INT DEFAULT NULL;
    DECLARE v_next         INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_author_first = NULLIF(TRIM(p_author_first), '');
    SET v_author_last  = NULLIF(TRIM(p_author_last), '');

    IF NOT EXISTS (SELECT 1 FROM books WHERE book_id = p_book_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Buch nicht gefunden.';
    END IF;
    IF v_author_last IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bitte mindestens den Nachnamen des Autors angeben.';
    END IF;

    START TRANSACTION;

    SET v_author_id = (SELECT MIN(author_id) FROM authors
                        WHERE last_name = v_author_last
                          AND first_name <=> v_author_first);
    IF v_author_id IS NULL THEN
        INSERT INTO authors (first_name, last_name) VALUES (v_author_first, v_author_last);
        SET v_author_id = LAST_INSERT_ID();
    END IF;

    IF EXISTS (SELECT 1 FROM book_authors WHERE book_id = p_book_id AND author_id = v_author_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dieser Autor ist dem Buch bereits zugeordnet.';
    END IF;

    SET v_next = (SELECT COALESCE(MAX(author_order), 0) + 1 FROM book_authors WHERE book_id = p_book_id);

    INSERT INTO book_authors (book_id, author_id, author_order)
    VALUES (p_book_id, v_author_id, v_next);

    COMMIT;

    SELECT p_book_id AS book_id, v_author_id AS author_id, v_next AS author_order,
           'Autor wurde hinzugefügt.' AS message;
END $$


-- ---------------------------------------------------------------------
-- sp_lend_book: Buch verleihen
--   p_days = Leihfrist in Tagen (NULL = Standard 28 Tage, Regel 4)
--   Die Procedure prüft nur die Eingaben. Die Regeln 1, 2, 3 und 5 prüft
--   der Trigger trg_loans_before_insert beim INSERT. Seine Meldung kommt
--   unverändert beim Aufrufer an.
-- Beispiel:  CALL sp_lend_book(7, 3, 28);   -- Homo faber an Mira, 4 Wochen
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_lend_book $$
CREATE PROCEDURE sp_lend_book(
    IN p_book_id    INT,
    IN p_friend_id  INT,
    IN p_days       INT
)
BEGIN
    DECLARE v_title        VARCHAR(255);
    DECLARE v_friend_name  VARCHAR(201);
    DECLARE v_days         INT;
    DECLARE v_due          DATE;
    DECLARE v_msg          VARCHAR(500);

    SET v_days        = IFNULL(p_days, 28);
    SET v_title       = (SELECT title FROM books WHERE book_id = p_book_id);
    SET v_friend_name = (SELECT CONCAT(first_name, ' ', last_name) FROM friends WHERE friend_id = p_friend_id);

    IF v_title IS NULL THEN
        SET v_msg = CONCAT('Kein Buch mit der ID ', IFNULL(p_book_id, 'NULL'), ' gefunden.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_friend_name IS NULL THEN
        SET v_msg = CONCAT('Kein Ausleiher mit der ID ', IFNULL(p_friend_id, 'NULL'), ' gefunden.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_days < 1 OR v_days > 90 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die Leihfrist muss zwischen 1 und 90 Tagen liegen.';
    END IF;

    SET v_due = ADDDATE(CURDATE(), v_days);          -- heute + v_days Tage

    -- Hier greift der Trigger. Verletzt die Ausleihe eine Regel,
    -- bricht das INSERT mit seiner Meldung ab.
    INSERT INTO loans (book_id, friend_id, loan_date, due_date)
    VALUES (p_book_id, p_friend_id, CURDATE(), v_due);

    SELECT LAST_INSERT_ID()              AS loan_id,
           v_title                       AS title,
           v_friend_name                 AS borrower,
           CURDATE()                     AS loan_date,
           v_due                         AS due_date,
           'Ausleihe wurde gespeichert.' AS message;
END $$


-- ---------------------------------------------------------------------
-- sp_return_book: Rückgabe erfassen (über die book_id)
-- Beispiel:  CALL sp_return_book(3);   -- Tschick ist zurück
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_return_book $$
CREATE PROCEDURE sp_return_book(
    IN p_book_id INT
)
BEGIN
    DECLARE v_loan_id INT DEFAULT NULL;

    IF NOT EXISTS (SELECT 1 FROM books WHERE book_id = p_book_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Buch nicht gefunden.';
    END IF;

    SET v_loan_id = (SELECT loan_id FROM loans
                      WHERE book_id = p_book_id
                        AND return_date IS NULL);

    IF v_loan_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dieses Buch ist gerade nicht verliehen.';
    END IF;

    UPDATE loans
       SET return_date = CURDATE()
     WHERE loan_id = v_loan_id;

    -- Das Ergebnis (pünktlich / zu spät) rechnet die View v_loan_history.
    -- So gibt es die Berechnung nur an einer Stelle.
    SELECT loan_id, title, borrower, loan_date, due_date, return_date,
           outcome, days_late, result
      FROM v_loan_history
     WHERE loan_id = v_loan_id;
END $$


-- ---------------------------------------------------------------------
-- sp_extend_loan: Leihfrist verlängern (über die book_id)
--   Neue Frist = alte Frist + Tage. Ist das Buch schon überfällig,
--   wird ab heute gerechnet (sonst wäre es nach dem Verlängern
--   immer noch überfällig).
-- Beispiel:  CALL sp_extend_loan(33, 14);   -- Säulen der Erde, +14 Tage
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_extend_loan $$
CREATE PROCEDURE sp_extend_loan(
    IN p_book_id     INT,
    IN p_extra_days  INT
)
BEGIN
    DECLARE v_loan_id INT DEFAULT NULL;

    IF p_extra_days IS NULL OR p_extra_days < 1 OR p_extra_days > 60 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Verlängerung muss zwischen 1 und 60 Tagen liegen.';
    END IF;

    SET v_loan_id = (SELECT loan_id FROM loans
                      WHERE book_id = p_book_id
                        AND return_date IS NULL);

    IF v_loan_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dieses Buch ist gerade nicht verliehen.';
    END IF;

    UPDATE loans
       SET due_date = ADDDATE(GREATEST(due_date, CURDATE()), p_extra_days),
           notes    = LEFT(CONCAT_WS('; ', notes, CONCAT('Verlängert um ', p_extra_days, ' Tage')), 255)
     WHERE loan_id = v_loan_id;

    SELECT loan_id, title, borrower, due_date AS new_due_date, loan_status
      FROM v_current_loans
     WHERE loan_id = v_loan_id;
END $$


-- ---------------------------------------------------------------------
-- sp_find_book: Buch nach Titel, Autor oder ISBN suchen
--   - Groß-/Kleinschreibung und Umlaute spielen keine Rolle
--     (Sortierung utf8mb4_0900_ai_ci der Datenbank).
--   - Leerer Suchtext zeigt alle Bücher.
--   - % und _ haben in LIKE eine Sonderbedeutung ("beliebige Zeichen").
--     Sie werden mit dem Zeichen ! entschärft (ESCAPE), damit eine Suche
--     nach "100%" nicht einfach alles findet.
-- Beispiel:  CALL sp_find_book('hesse');
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_find_book $$
CREATE PROCEDURE sp_find_book(
    IN p_search VARCHAR(100)
)
BEGIN
    DECLARE v_search  VARCHAR(100);
    DECLARE v_pattern VARCHAR(310);

    SET v_search  = TRIM(IFNULL(p_search, ''));
    SET v_pattern = CONCAT('%',
                           REPLACE(REPLACE(REPLACE(v_search, '!', '!!'), '%', '!%'), '_', '!_'),
                           '%');

    SELECT o.book_id, o.title, o.authors, o.genre, o.publisher, o.first_published,
           o.status, o.borrowed_by, o.due_date
      FROM v_book_overview o
     WHERE o.title LIKE v_pattern ESCAPE '!'
        OR o.isbn = REPLACE(REPLACE(v_search, '-', ''), ' ', '')
        OR EXISTS (SELECT 1
                     FROM book_authors ba
                     JOIN authors a ON a.author_id = ba.author_id
                    WHERE ba.book_id = o.book_id
                      AND CONCAT_WS(' ', a.first_name, a.last_name) LIKE v_pattern ESCAPE '!')
     ORDER BY o.title;
END $$


-- ---------------------------------------------------------------------
-- sp_add_friend: neue Person anlegen
--   Leere Texte werden als NULL gespeichert.
--   Die CHECK-Constraints der Tabelle friends gelten zusätzlich.
-- Beispiel:
--   CALL sp_add_friend('Nina', 'Schmidt', 'nina.schmidt@example.com', NULL,
--                      NULL, NULL, NULL, 'Kollegium', 2);
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_add_friend $$
CREATE PROCEDURE sp_add_friend(
    IN p_first_name    VARCHAR(100),
    IN p_last_name     VARCHAR(100),
    IN p_email         VARCHAR(255),
    IN p_phone         VARCHAR(30),
    IN p_street        VARCHAR(150),
    IN p_postal_code   VARCHAR(10),
    IN p_city          VARCHAR(100),
    IN p_relationship  VARCHAR(20),
    IN p_max_loans     INT
)
BEGIN
    DECLARE v_first_name   VARCHAR(100);
    DECLARE v_last_name    VARCHAR(100);
    DECLARE v_email        VARCHAR(255);
    DECLARE v_phone        VARCHAR(30);
    DECLARE v_relationship VARCHAR(20);

    SET v_first_name   = NULLIF(TRIM(p_first_name), '');
    SET v_last_name    = NULLIF(TRIM(p_last_name), '');
    SET v_email        = NULLIF(TRIM(p_email), '');
    SET v_phone        = NULLIF(TRIM(p_phone), '');
    SET v_relationship = COALESCE(NULLIF(TRIM(p_relationship), ''), 'Freundeskreis');

    IF v_first_name IS NULL OR v_last_name IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bitte Vor- und Nachnamen angeben.';
    END IF;

    -- Regel 6: mindestens E-Mail oder Telefon
    IF v_email IS NULL AND v_phone IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bitte mindestens E-Mail oder Telefon angeben.';
    END IF;

    IF v_email IS NOT NULL AND v_email NOT LIKE '_%@_%._%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die E-Mail-Adresse sieht unvollständig aus.';
    END IF;

    IF v_email IS NOT NULL AND EXISTS (SELECT 1 FROM friends WHERE email = v_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Diese E-Mail-Adresse gehört schon einer anderen Person.';
    END IF;

    IF v_relationship NOT IN ('Freundeskreis', 'Familie', 'Kollegium', 'Nachbarschaft', 'Bekanntschaft') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Beziehung muss Freundeskreis, Familie, Kollegium, Nachbarschaft oder Bekanntschaft sein.';
    END IF;

    IF p_max_loans IS NOT NULL AND (p_max_loans < 1 OR p_max_loans > 10) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Max. Bücher muss zwischen 1 und 10 liegen.';
    END IF;

    INSERT INTO friends (first_name, last_name, email, phone, street, postal_code, city, relationship, max_loans)
    VALUES (v_first_name, v_last_name, v_email, v_phone,
            NULLIF(TRIM(p_street), ''), NULLIF(TRIM(p_postal_code), ''), NULLIF(TRIM(p_city), ''),
            v_relationship, COALESCE(p_max_loans, 3));

    SELECT LAST_INSERT_ID()                      AS friend_id,
           CONCAT(v_first_name, ' ', v_last_name) AS friend,
           'Person wurde gespeichert.'           AS message;
END $$


DELIMITER ;

-- Kontrolle: Welche Trigger und Procedures gibt es?
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'liane_library_v2';


-- #####################################################################
-- ##  05_app_user.sql
-- #####################################################################

-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 05_app_user.sql
-- Inhalt    : Eigener MySQL-Benutzer für die Python-App (ohne Passwort)
-- Hinweis   : Ist in 00_setup_complete.sql schon enthalten.
--             Einzeln ausführen nur, wenn die Datenbank schon steht.
-- =====================================================================
--
-- Warum ein eigener Benutzer ohne Passwort?
--   Die App soll für jeden ohne Anmeldung offen sein. Deshalb meldet sie
--   sich nicht als root an, sondern als liane_app_v2. Dieser Benutzer hat
--   kein Geheimnis, darf dafür aber fast nichts:
--     * nur von diesem Rechner aus ('localhost'), nicht über das Netzwerk
--     * nur die 11 Views lesen
--     * nur die 7 Stored Procedures aufrufen
--     * keine Tabelle direkt lesen oder ändern, nichts löschen
--   Alle Regeln in Triggern und Procedures gelten also auch für die App.
--
-- Unterschied zu Version 1: Dort stand GRANT EXECUTE ON liane_library.*
-- (alle Procedures der Datenbank, auch künftige). Hier bekommt der
-- Benutzer jede Procedure einzeln. Das ist das Prinzip der kleinsten
-- Rechte: Eine neue Procedure ist für die App erst sichtbar, wenn man sie
-- bewusst freigibt.
--
-- Die Views und Procedures laufen mit den Rechten ihres Erstellers
-- (SQL SECURITY DEFINER, Standard in MySQL). Darum braucht liane_app_v2
-- keine Rechte auf den Tabellen selbst.
-- =====================================================================

USE liane_library_v2;

CREATE USER IF NOT EXISTS 'liane_app_v2'@'localhost' IDENTIFIED BY '';

-- Lesen: nur die Views
GRANT SELECT ON liane_library_v2.v_book_overview     TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_current_loans     TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_overdue_loans     TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_friend_statistics TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_loan_history      TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_reminders         TO 'liane_app_v2'@'localhost';
-- Auswertungen für den Analyse-Bereich
GRANT SELECT ON liane_library_v2.v_kpi_overview                TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_loans_per_month             TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_punctuality_by_relationship TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_genre_statistics            TO 'liane_app_v2'@'localhost';
GRANT SELECT ON liane_library_v2.v_book_ranking                TO 'liane_app_v2'@'localhost';

-- Ändern: nur über diese 7 Stored Procedures
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_add_book           TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_add_author_to_book TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_add_friend         TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_lend_book          TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_return_book        TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_extend_loan        TO 'liane_app_v2'@'localhost';
GRANT EXECUTE ON PROCEDURE liane_library_v2.sp_find_book          TO 'liane_app_v2'@'localhost';

-- Kontrolle: Welche Rechte hat liane_app_v2?
SHOW GRANTS FOR 'liane_app_v2'@'localhost';
