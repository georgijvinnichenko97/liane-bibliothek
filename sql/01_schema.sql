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
