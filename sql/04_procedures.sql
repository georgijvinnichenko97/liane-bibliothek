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
