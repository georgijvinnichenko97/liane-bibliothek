-- =====================================================================
-- Projekt   : Bibliotheksverwaltung für Liane (Version 2)
-- Datei     : 09_tests.sql
-- Inhalt    : 100 Tests, die sich selbst auswerten
-- Voraussetzung: 00_setup_complete.sql wurde ausgeführt.
--               Demo-Daten (06 oder 07) sind erlaubt, aber nicht nötig.
-- =====================================================================
--
-- So benutzt du die Datei in MySQL Workbench:
--   Alles ausführen (Blitz-Symbol oder Strg+Shift+Enter). Der LETZTE
--   Ergebnis-Tab zeigt das Gesamtergebnis, zum Beispiel
--   "100 von 100 Tests bestanden". Der Tab davor listet jeden Test auf.
--   Die anderen Tabs sind Ausgaben der Procedures und können
--   ignoriert werden.
--
-- Was ist anders als in Version 1?
--   * Die Tests werten sich selbst aus. In Version 1 musste man den
--     Schalter "weiter nach Fehlern" einschalten und jede Meldung von
--     Hand mit dem Kommentar ERWARTET vergleichen. Hier fängt eine
--     Hilfs-Procedure jeden Fehler ab, vergleicht ihn mit der Erwartung
--     und schreibt OK oder FEHLER in eine Tabelle.
--   * Die Tests bringen ihre eigenen Testdaten mit (alles mit "ZZ-Test")
--     und löschen sie am Ende wieder. Sie brauchen keine Demo-Daten und
--     keine festen IDs, und danach ist die Datenbank wie vorher. Der
--     letzte Test prüft das selbst nach.
--     (Einzige Spur: Die nächste neue ID ist etwas höher, weil MySQL
--     einmal vergebene AUTO_INCREMENT-Nummern nicht wiederverwendet.)
--   * Neu geprüft werden: die Regeln bei direktem INSERT und UPDATE
--     (Teil 5), die Zahlen der Views (Teil 8) sowie Aufbau und Rechte
--     der Datenbank (Teil 9).
--
-- Die drei Hilfs-Procedures:
--   test_error(Nr, Name, SQL, Fehlercode, Muster)
--       Das SQL MUSS mit genau diesem Fehlercode scheitern. Das Muster
--       prüft den Text der Meldung (LIKE, % = beliebige Zeichen).
--   test_ok(Nr, Name, SQL)
--       Das SQL muss ohne Fehler laufen.
--   test_value(Nr, Name, SQL, Erwartung)
--       Das SQL liefert genau einen Wert, und der muss der Erwartung
--       entsprechen.
--
--   Das zu testende SQL steht als Text in '...'. Texte IM SQL stehen
--   deshalb in "..." (doppelte Anführungszeichen).
--
-- Fehlercodes in MySQL:
--   1048  Spalte darf nicht NULL sein          (NOT NULL)
--   1062  doppelter Wert                       (UNIQUE / PRIMARY KEY)
--   1451  Datensatz wird noch verwendet        (FOREIGN KEY beim Löschen)
--   1452  Verweis zeigt ins Leere              (FOREIGN KEY beim Einfügen)
--   1644  eigene Fehlermeldung                 (SIGNAL in Trigger oder Procedure)
--   3819  Prüfbedingung verletzt               (CHECK)
-- =====================================================================

USE liane_library_v2;

-- Workbench verbietet im "Safe Update Mode" ein DELETE ohne Schlüssel im
-- WHERE. Das Aufräumen der Testdaten braucht das. Die Einstellung gilt
-- nur für dieses Fenster und wird am Ende zurückgesetzt.
SET @old_safe_updates = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

-- Ergebnis-Tabelle (TEMPORARY: nur für dieses Fenster sichtbar)
DROP TEMPORARY TABLE IF EXISTS test_results;
CREATE TEMPORARY TABLE test_results (
    seq        INT AUTO_INCREMENT PRIMARY KEY,
    test_id    VARCHAR(8),
    test_name  VARCHAR(120),
    expected   VARCHAR(255),
    actual     VARCHAR(255),
    passed     TINYINT
);


-- =====================================================================
-- Hilfs-Procedures (werden am Ende wieder gelöscht)
-- =====================================================================
DELIMITER $$

-- test_run: führt einen SQL-Text aus und meldet Fehlercode und Meldung
-- zurück, statt abzubrechen.
--   PREPARE / EXECUTE: macht aus einem Text einen ausführbaren Befehl.
--   CONTINUE HANDLER:  fängt jeden Fehler ab, danach geht es weiter.
--   GET DIAGNOSTICS:   liest Fehlercode und Meldung des Fehlers aus.
DROP PROCEDURE IF EXISTS test_run $$
CREATE PROCEDURE test_run(
    IN  p_sql    TEXT,
    OUT p_errno  INT,
    OUT p_msg    VARCHAR(600)
)
BEGIN
    DECLARE v_errno      INT DEFAULT 0;
    DECLARE v_msg        VARCHAR(600) DEFAULT NULL;
    DECLARE v_this_errno INT;
    DECLARE v_this_msg   VARCHAR(600);

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_this_errno = MYSQL_ERRNO, v_this_msg = MESSAGE_TEXT;
        IF v_errno = 0 THEN                 -- nur den ersten Fehler merken
            SET v_errno = v_this_errno;
            SET v_msg   = v_this_msg;
        END IF;
    END;

    SET @test_sql = p_sql;
    PREPARE test_stmt FROM @test_sql;
    EXECUTE test_stmt;
    DEALLOCATE PREPARE test_stmt;

    SET p_errno = v_errno;
    SET p_msg   = v_msg;
END $$


DROP PROCEDURE IF EXISTS test_error $$
CREATE PROCEDURE test_error(
    IN p_id        VARCHAR(8),
    IN p_name      VARCHAR(120),
    IN p_sql       TEXT,
    IN p_errno     INT,
    IN p_msg_like  VARCHAR(200)
)
BEGIN
    DECLARE v_errno INT;
    DECLARE v_msg   VARCHAR(600);

    CALL test_run(p_sql, v_errno, v_msg);

    INSERT INTO test_results (test_id, test_name, expected, actual, passed)
    VALUES (p_id, p_name,
            LEFT(CONCAT('Fehler ', p_errno, IF(p_msg_like IS NULL, '', CONCAT(': ', p_msg_like))), 255),
            LEFT(IF(v_errno = 0, 'kein Fehler', CONCAT('Fehler ', v_errno, ': ', v_msg)), 255),
            IFNULL(v_errno = p_errno AND (p_msg_like IS NULL OR v_msg LIKE p_msg_like), 0));
END $$


DROP PROCEDURE IF EXISTS test_ok $$
CREATE PROCEDURE test_ok(
    IN p_id    VARCHAR(8),
    IN p_name  VARCHAR(120),
    IN p_sql   TEXT
)
BEGIN
    DECLARE v_errno INT;
    DECLARE v_msg   VARCHAR(600);

    CALL test_run(p_sql, v_errno, v_msg);

    INSERT INTO test_results (test_id, test_name, expected, actual, passed)
    VALUES (p_id, p_name,
            'kein Fehler',
            LEFT(IF(v_errno = 0, 'kein Fehler', CONCAT('Fehler ', v_errno, ': ', v_msg)), 255),
            v_errno = 0);
END $$


DROP PROCEDURE IF EXISTS test_value $$
CREATE PROCEDURE test_value(
    IN p_id        VARCHAR(8),
    IN p_name      VARCHAR(120),
    IN p_sql       TEXT,
    IN p_expected  VARCHAR(255)
)
BEGIN
    DECLARE v_errno   INT;
    DECLARE v_msg     VARCHAR(600);
    DECLARE v_actual  VARCHAR(600);

    SET @test_actual = NULL;
    CALL test_run(CONCAT('SET @test_actual = (', p_sql, ')'), v_errno, v_msg);
    SET v_actual = CAST(@test_actual AS CHAR);

    -- CAST(... AS BINARY): genauer Vergleich, auch Groß-/Kleinschreibung
    -- und Umlaute müssen stimmen.
    INSERT INTO test_results (test_id, test_name, expected, actual, passed)
    VALUES (p_id, p_name,
            IFNULL(p_expected, 'NULL'),
            LEFT(IF(v_errno = 0, IFNULL(v_actual, 'NULL'), CONCAT('Fehler ', v_errno, ': ', v_msg)), 255),
            IFNULL(v_errno = 0 AND CAST(v_actual AS BINARY) <=> CAST(p_expected AS BINARY), 0));
END $$


-- test_cleanup: löscht alle Testdaten (alles, was mit "ZZ-Test" beginnt).
-- Reihenfolge: erst die Ausleihen, dann Bücher (ihre Autoren-Zuordnungen
-- gehen per CASCADE mit), dann der Rest.
DROP PROCEDURE IF EXISTS test_cleanup $$
CREATE PROCEDURE test_cleanup()
BEGIN
    DELETE FROM loans
     WHERE book_id   IN (SELECT book_id   FROM books   WHERE title     LIKE 'ZZ-Test%')
        OR friend_id IN (SELECT friend_id FROM friends WHERE last_name LIKE 'ZZ-Test%');
    DELETE FROM books      WHERE title          LIKE 'ZZ-Test%';
    DELETE FROM authors    WHERE last_name      LIKE 'ZZ-Test%';
    DELETE FROM friends    WHERE last_name      LIKE 'ZZ-Test%';
    DELETE FROM genres     WHERE genre_name     LIKE 'ZZ-Test%';
    DELETE FROM publishers WHERE publisher_name LIKE 'ZZ-Test%';
END $$

DELIMITER ;


-- =====================================================================
-- Vorbereitung: Reste eines früheren Laufs entfernen, Stand merken,
-- Testdaten anlegen
-- =====================================================================
CALL test_cleanup();

-- Anzahl der Zeilen in allen 7 Tabellen VOR den Tests (für Test T100)
SET @counts_before = CONCAT_WS('|',
    (SELECT COUNT(*) FROM genres),  (SELECT COUNT(*) FROM publishers),
    (SELECT COUNT(*) FROM authors), (SELECT COUNT(*) FROM books),
    (SELECT COUNT(*) FROM book_authors),
    (SELECT COUNT(*) FROM friends), (SELECT COUNT(*) FROM loans));

INSERT INTO genres (genre_name) VALUES ('ZZ-Test Genre');
SET @g_test = (SELECT genre_id FROM genres WHERE genre_name = 'ZZ-Test Genre');

-- 6 verleihbare Bücher (A bis F) und 1 gesperrtes
INSERT INTO books (title, isbn, genre_id, is_lendable) VALUES
    ('ZZ-Test Buch A',        '9990000000011', @g_test, 1),
    ('ZZ-Test Buch B',        '9990000000028', @g_test, 1),
    ('ZZ-Test Buch C',        '9990000000035', @g_test, 1),
    ('ZZ-Test Buch D',        '9990000000042', @g_test, 1),
    ('ZZ-Test Buch E',        '9990000000059', @g_test, 1),
    ('ZZ-Test Buch F',        '9990000000066', @g_test, 1),
    ('ZZ-Test Buch gesperrt', '9990000000073', @g_test, 0);

-- 5 Personen: Tina darf nur 2 Bücher haben, Kai nur 1
INSERT INTO friends (first_name, last_name, email, phone, relationship, max_loans) VALUES
    ('Tina', 'ZZ-Test Limit', 'zz.test.limit@example.com', NULL,       'Freundeskreis', 2),
    ('Olaf', 'ZZ-Test Spät',  NULL,                        '0000 111', 'Bekanntschaft', 3),
    ('Nele', 'ZZ-Test Neu',   'zz.test.neu@example.com',   NULL,       'Kollegium',     3),
    ('Kai',  'ZZ-Test Eins',  'zz.test.eins@example.com',  NULL,       'Nachbarschaft', 1),
    ('Uwe',  'ZZ-Test Weg',   'zz.test.weg@example.com',   NULL,       'Freundeskreis', 3);

-- IDs der Testdaten in Variablen merken (@b_ = Buch, @f_ = Person)
SET @b_a = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch A');
SET @b_b = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch B');
SET @b_c = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch C');
SET @b_d = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch D');
SET @b_e = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch E');
SET @b_f = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch F');
SET @b_x = (SELECT book_id FROM books WHERE title = 'ZZ-Test Buch gesperrt');
SET @f_limit = (SELECT friend_id FROM friends WHERE last_name = 'ZZ-Test Limit');
SET @f_late  = (SELECT friend_id FROM friends WHERE last_name = 'ZZ-Test Spät');
SET @f_new   = (SELECT friend_id FROM friends WHERE last_name = 'ZZ-Test Neu');
SET @f_one   = (SELECT friend_id FROM friends WHERE last_name = 'ZZ-Test Eins');

-- Olaf hat Buch D seit 40 Tagen, die Frist ist seit 12 Tagen vorbei
INSERT INTO loans (book_id, friend_id, loan_date, due_date)
VALUES (@b_d, @f_late, CURDATE() - INTERVAL 40 DAY, CURDATE() - INTERVAL 12 DAY);


-- =====================================================================
-- Teil 1: Tabelle books (Constraints)
-- =====================================================================
CALL test_error('T01', 'Buch ohne Titel',
    'INSERT INTO books (title) VALUES (NULL)', 1048, '%title%');
CALL test_error('T02', 'ISBN mit Buchstaben',
    'INSERT INTO books (title, isbn) VALUES ("ZZ-Test", "ABC1234567")', 3819, '%chk_books_isbn%');
CALL test_error('T03', 'ISBN doppelt',
    'INSERT INTO books (title, isbn) VALUES ("ZZ-Test", "9990000000011")', 1062, '%uq_books_isbn%');
CALL test_error('T04', 'Sprachcode in Großbuchstaben',
    'INSERT INTO books (title, language_code) VALUES ("ZZ-Test", "DE")', 3819, '%chk_books_language%');
CALL test_error('T05', 'Erscheinungsjahr 3000',
    'INSERT INTO books (title, first_published) VALUES ("ZZ-Test", 3000)', 3819, '%chk_books_year%');
CALL test_ok('T06', 'Buch ohne ISBN ist erlaubt',
    'INSERT INTO books (title) VALUES ("ZZ-Test ohne ISBN")');
CALL test_value('T07', 'Standardwerte: Sprache de, verleihbar, heute erfasst',
    'SELECT CONCAT(language_code, "/", is_lendable, "/", added_on = CURDATE()) FROM books WHERE title = "ZZ-Test ohne ISBN"',
    'de/1/1');

SET @b_o = (SELECT book_id FROM books WHERE title = 'ZZ-Test ohne ISBN');


-- =====================================================================
-- Teil 2: Tabelle friends (Constraints, Regel 6)
-- =====================================================================
CALL test_error('T08', 'Regel 6: Person ohne E-Mail und ohne Telefon',
    'INSERT INTO friends (first_name, last_name) VALUES ("Max", "ZZ-Test")', 3819, '%chk_friends_contact%');
CALL test_error('T09', 'E-Mail ohne @',
    'INSERT INTO friends (first_name, last_name, email) VALUES ("Max", "ZZ-Test", "max.example.com")', 3819, '%chk_friends_email%');
CALL test_error('T10', 'Unbekannte Beziehung',
    'INSERT INTO friends (first_name, last_name, phone, relationship) VALUES ("Max", "ZZ-Test", "0151 123", "Kumpel")', 3819, '%chk_friends_relation%');
CALL test_error('T11', 'max_loans = 0',
    'INSERT INTO friends (first_name, last_name, phone, max_loans) VALUES ("Max", "ZZ-Test", "0151 123", 0)', 3819, '%chk_friends_max_loans%');
CALL test_error('T12', 'E-Mail doppelt',
    'INSERT INTO friends (first_name, last_name, email) VALUES ("Max", "ZZ-Test", "zz.test.limit@example.com")', 1062, '%uq_friends_email%');


-- =====================================================================
-- Teil 3: Tabelle loans und Fremdschlüssel (Regel 7)
-- =====================================================================
CALL test_error('T13', 'Frist vor dem Ausleihdatum',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date) VALUES (@b_a, @f_new, CURDATE(), CURDATE() - INTERVAL 1 DAY)',
    3819, '%chk_loans_due%');
CALL test_error('T14', 'Ausleihe für ein Buch, das es nicht gibt',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (-1, @f_new, CURDATE() + INTERVAL 14 DAY)',
    1452, '%fk_loans_book%');
CALL test_error('T15', 'Regel 7: Buch mit Ausleih-Historie löschen',
    'DELETE FROM books WHERE book_id = @b_d', 1451, '%fk_loans_book%');
CALL test_error('T16', 'Regel 7: Person mit Ausleih-Historie löschen',
    'DELETE FROM friends WHERE friend_id = @f_late', 1451, '%fk_loans_friend%');
CALL test_ok('T17', 'Person ohne Ausleihen löschen',
    'DELETE FROM friends WHERE last_name = "ZZ-Test Weg"');
CALL test_ok('T18', 'Genre löschen, das noch benutzt wird (SET NULL)',
    'DELETE FROM genres WHERE genre_name = "ZZ-Test Genre"');
CALL test_value('T19', 'Die 7 Bücher des Genres bleiben, ihr Genre ist jetzt leer',
    'SELECT COUNT(*) FROM books WHERE title LIKE "ZZ-Test Buch%" AND genre_id IS NULL', '7');
CALL test_value('T20', 'Regel 1: UNIQUE auf open_book_id ist vorhanden',
    'SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = "loans" AND CONSTRAINT_NAME = "uq_loans_one_open_per_book" AND CONSTRAINT_TYPE = "UNIQUE"',
    '1');


-- =====================================================================
-- Teil 4: Verleihen mit sp_lend_book (Regeln 1 bis 5)
-- =====================================================================
CALL test_ok('T21', 'Buch A an Tina verleihen',
    'CALL sp_lend_book(@b_a, @f_limit, 28)');
CALL test_value('T22', 'Die Frist ist heute + 28 Tage',
    'SELECT DATEDIFF(due_date, CURDATE()) FROM loans WHERE book_id = @b_a AND return_date IS NULL', '28');
CALL test_error('T23', 'Regel 1: Buch A ist schon bei Tina',
    'CALL sp_lend_book(@b_a, @f_new, 28)', 1644, '"ZZ-Test Buch A" ist bereits an Tina ZZ-Test Limit verliehen.');
CALL test_error('T24', 'Regel 5: gesperrtes Buch',
    'CALL sp_lend_book(@b_x, @f_new, 28)', 1644, '"ZZ-Test Buch gesperrt" ist als nicht verleihbar markiert.');
CALL test_error('T25', 'Regel 3: Olaf hat etwas Überfälliges',
    'CALL sp_lend_book(@b_b, @f_late, 28)', 1644, 'Olaf ZZ-Test Spät hat noch 1 überfälliges Buch. Bitte erst zurückgeben.');
CALL test_ok('T26', 'Buch B an Tina, ohne Angabe der Leihfrist',
    'CALL sp_lend_book(@b_b, @f_limit, NULL)');
CALL test_value('T27', 'Regel 4: Standard-Leihfrist ist 28 Tage',
    'SELECT DATEDIFF(due_date, loan_date) FROM loans WHERE book_id = @b_b AND return_date IS NULL', '28');
CALL test_error('T28', 'Regel 2: Tina hat schon 2 von 2 Büchern',
    'CALL sp_lend_book(@b_c, @f_limit, 28)', 1644, 'Tina ZZ-Test Limit hat bereits 2 von maximal 2 Büchern.');
CALL test_error('T29', 'Buch, das es nicht gibt',
    'CALL sp_lend_book(-1, @f_new, 28)', 1644, 'Kein Buch mit der ID -1 gefunden.');
CALL test_error('T30', 'Person, die es nicht gibt',
    'CALL sp_lend_book(@b_c, -1, 28)', 1644, 'Kein Ausleiher mit der ID -1 gefunden.');
CALL test_error('T31', 'Leihfrist von 120 Tagen ist zu lang',
    'CALL sp_lend_book(@b_c, @f_new, 120)', 1644, 'Die Leihfrist muss zwischen 1 und 90 Tagen liegen.');


-- =====================================================================
-- Teil 5: Dieselben Regeln OHNE die Procedure (neu in Version 2)
--   Ein direktes INSERT oder UPDATE auf loans muss genauso scheitern.
--   In Version 1 wären T32, T33, T34 und T40 durchgegangen.
-- =====================================================================
CALL test_error('T32', 'Regel 5 bei direktem INSERT',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (@b_x, @f_new, CURDATE() + INTERVAL 14 DAY)',
    1644, '%nicht verleihbar%');
CALL test_error('T33', 'Regel 3 bei direktem INSERT',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (@b_c, @f_late, CURDATE() + INTERVAL 14 DAY)',
    1644, '%hat noch 1 überfälliges Buch%');
CALL test_error('T34', 'Regel 2 bei direktem INSERT',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (@b_c, @f_limit, CURDATE() + INTERVAL 14 DAY)',
    1644, '%hat bereits 2 von maximal 2%');
CALL test_error('T35', 'Regel 1 bei direktem INSERT',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (@b_a, @f_new, CURDATE() + INTERVAL 14 DAY)',
    1644, '%ist bereits an Tina ZZ-Test Limit verliehen%');
CALL test_error('T36', 'Regel 2 auch bei zwei Zeilen in EINEM INSERT (Kai darf nur 1 Buch)',
    'INSERT INTO loans (book_id, friend_id, due_date) VALUES (@b_e, @f_one, CURDATE() + INTERVAL 14 DAY), (@b_f, @f_one, CURDATE() + INTERVAL 14 DAY)',
    1644, '%hat bereits 1 von maximal 1%');
CALL test_value('T37', 'Alles oder nichts: Auch die erste Zeile aus T36 ist nicht gespeichert',
    'SELECT COUNT(*) FROM loans WHERE friend_id = @f_one', '0');
CALL test_ok('T38', 'Eine alte, schon beendete Ausleihe nachtragen (Buch E an Nele)',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date, return_date) VALUES (@b_e, @f_new, CURDATE() - INTERVAL 200 DAY, CURDATE() - INTERVAL 172 DAY, CURDATE() - INTERVAL 180 DAY)');
CALL test_error('T39', 'Regel 1 gilt auch in der Vergangenheit: Zeitraum überschneidet sich',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date, return_date) VALUES (@b_e, @f_one, CURDATE() - INTERVAL 190 DAY, CURDATE() - INTERVAL 170 DAY, CURDATE() - INTERVAL 185 DAY)',
    1644, '"ZZ-Test Buch E" war in diesem Zeitraum an Nele ZZ-Test Neu verliehen.');
CALL test_error('T40', 'Ausleihe per UPDATE auf eine andere Person umhängen',
    'UPDATE loans SET friend_id = @f_new WHERE book_id = @b_a AND return_date IS NULL',
    1644, '%sind fest%');
CALL test_error('T41', 'Rückgabe per UPDATE zurücknehmen',
    'UPDATE loans SET return_date = NULL WHERE book_id = @b_e AND friend_id = @f_new',
    1644, '%kann nicht zurückgenommen werden%');


-- =====================================================================
-- Teil 6: Rückgabe und Verlängerung
-- =====================================================================
CALL test_error('T42', 'Rückgabe für ein Buch, das nicht verliehen ist',
    'CALL sp_return_book(@b_c)', 1644, 'Dieses Buch ist gerade nicht verliehen.');
CALL test_ok('T43', 'Tina bringt Buch A zurück',
    'CALL sp_return_book(@b_a)');
CALL test_value('T44', 'Die Rückgabe ist als pünktlich bewertet',
    'SELECT outcome FROM v_loan_history WHERE book_id = @b_a AND friend_id = @f_limit', 'pünktlich');
CALL test_ok('T45', 'Buch A geht am selben Tag an Nele',
    'CALL sp_lend_book(@b_a, @f_new, 14)');
CALL test_ok('T46', 'Nele verlängert Buch A um 7 Tage',
    'CALL sp_extend_loan(@b_a, 7)');
CALL test_value('T47', 'Neue Frist: heute + 14 + 7 Tage',
    'SELECT DATEDIFF(due_date, CURDATE()) FROM loans WHERE book_id = @b_a AND return_date IS NULL', '21');
CALL test_value('T48', 'Die Verlängerung steht in der Notiz',
    'SELECT notes FROM loans WHERE book_id = @b_a AND return_date IS NULL', 'Verlängert um 7 Tage');
CALL test_error('T49', 'Verlängerung um 0 Tage',
    'CALL sp_extend_loan(@b_a, 0)', 1644, 'Verlängerung muss zwischen 1 und 60 Tagen liegen.');
CALL test_error('T50', 'Verlängerung für ein Buch, das nicht verliehen ist',
    'CALL sp_extend_loan(@b_c, 14)', 1644, 'Dieses Buch ist gerade nicht verliehen.');
CALL test_ok('T51', 'Olaf verlängert das überfällige Buch D um 14 Tage',
    'CALL sp_extend_loan(@b_d, 14)');
CALL test_value('T52', 'Bei Überfälligem zählt die Verlängerung ab heute',
    'SELECT DATEDIFF(due_date, CURDATE()) FROM loans WHERE book_id = @b_d AND return_date IS NULL', '14');
CALL test_ok('T53', 'Olaf hat nichts Überfälliges mehr und bekommt Buch C',
    'CALL sp_lend_book(@b_c, @f_late, 28)');
CALL test_ok('T54', 'Vorbereitung: Kai hat Buch F seit 30 Tagen, Frist seit 2 Tagen vorbei',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date) VALUES (@b_f, @f_one, CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 2 DAY)');
CALL test_ok('T55', 'Kai bringt Buch F zurück',
    'CALL sp_return_book(@b_f)');
CALL test_value('T56', 'Ergebnis der Rückgabe: 2 Tage zu spät',
    'SELECT CONCAT(outcome, " / ", days_late, " / ", result) FROM v_loan_history WHERE book_id = @b_f AND friend_id = @f_one',
    'zu spät / 2 / 2 Tage zu spät');
CALL test_ok('T57', 'Vorbereitung: Nele hat Buch E seit 20 Tagen, Frist seit gestern vorbei',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date) VALUES (@b_e, @f_new, CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 1 DAY)');
CALL test_ok('T58', 'Nele bringt Buch E zurück',
    'CALL sp_return_book(@b_e)');
CALL test_value('T59', 'Einzahl stimmt: "1 Tag zu spät" (Version 1 schrieb "1 Tage")',
    'SELECT result FROM v_loan_history WHERE book_id = @b_e AND return_date = CURDATE()', '1 Tag zu spät');


-- =====================================================================
-- Teil 7: Bücher und Personen anlegen, Suche
-- =====================================================================
CALL test_ok('T60', 'Neues Buch mit neuem Genre, Verlag und Autorin',
    'CALL sp_add_book("  ZZ-Test Neues Buch  ", "Zoe", "ZZ-Test Autorin", "ZZ-Test Genre Neu", "ZZ-Test Verlag", 2020, "999-0-000-00020-3")');
CALL test_value('T61', 'Titel ohne Leerzeichen am Rand, ISBN ohne Bindestriche gespeichert',
    'SELECT CONCAT(title, "|", isbn) FROM books WHERE isbn = "9990000000203"', 'ZZ-Test Neues Buch|9990000000203');
CALL test_value('T62', 'Genre, Verlag und Autorin wurden mit angelegt',
    'SELECT CONCAT(genre, "|", publisher, "|", authors) FROM v_book_overview WHERE isbn = "9990000000203"',
    'ZZ-Test Genre Neu|ZZ-Test Verlag|Zoe ZZ-Test Autorin');
CALL test_error('T63', 'Neues Buch ohne Titel (nur Leerzeichen)',
    'CALL sp_add_book("   ", "Zoe", "ZZ-Test Autorin", NULL, NULL, NULL, NULL)', 1644, 'Bitte einen Titel angeben.');
CALL test_error('T64', 'Neues Buch mit zu kurzer ISBN',
    'CALL sp_add_book("ZZ-Test Fehlversuch", NULL, "ZZ-Test Autorin", "ZZ-Test Genre Fehl", NULL, NULL, "123")', 1644, 'Die ISBN muss 10 oder 13 Ziffern haben%');
CALL test_error('T65', 'ISBN gibt es schon (mit Bindestrichen eingegeben)',
    'CALL sp_add_book("ZZ-Test Fehlversuch", NULL, "ZZ-Test Autorin", NULL, NULL, NULL, "999-0-000-00020-3")', 1644, 'Diese ISBN gibt es schon in der Bibliothek.');
CALL test_error('T66', 'Erscheinungsjahr 99999',
    'CALL sp_add_book("ZZ-Test Fehlversuch", NULL, "ZZ-Test Autorin", NULL, NULL, 99999, NULL)', 1644, 'Das Erscheinungsjahr muss zwischen 1450 und 2100 liegen.');
CALL test_value('T67', 'Von den Fehlversuchen ist nichts gespeichert (auch kein Genre)',
    'SELECT (SELECT COUNT(*) FROM books WHERE title = "ZZ-Test Fehlversuch") + (SELECT COUNT(*) FROM genres WHERE genre_name = "ZZ-Test Genre Fehl")',
    '0');

SET @b_new = (SELECT book_id FROM books WHERE isbn = '9990000000203');

CALL test_ok('T68', 'Zweiten Autor hinzufügen',
    'CALL sp_add_author_to_book(@b_new, "Yan", "ZZ-Test Zweitautor")');
CALL test_value('T69', 'Beide Autoren stehen in der richtigen Reihenfolge',
    'SELECT authors FROM v_book_overview WHERE book_id = @b_new', 'Zoe ZZ-Test Autorin, Yan ZZ-Test Zweitautor');
CALL test_error('T70', 'Denselben Autor noch einmal hinzufügen',
    'CALL sp_add_author_to_book(@b_new, "Yan", "ZZ-Test Zweitautor")', 1644, 'Dieser Autor ist dem Buch bereits zugeordnet.');
CALL test_ok('T71', 'Suche in Kleinbuchstaben läuft',
    'CALL sp_find_book("zz-test neues")');
CALL test_ok('T72', 'Suche mit dem Sonderzeichen % läuft',
    'CALL sp_find_book("100%")');
CALL test_ok('T73', 'Neue Person, Telefon leer, max. Bücher nicht angegeben',
    'CALL sp_add_friend("  Mia ", "ZZ-Test Person", "zz.test.mia@example.com", "", NULL, NULL, NULL, "Familie", NULL)');
CALL test_value('T74', 'Gespeichert: Name ohne Leerzeichen, Standard 3 Bücher, Telefon leer (NULL)',
    'SELECT CONCAT(first_name, "|", relationship, "|", max_loans, "|", phone IS NULL) FROM friends WHERE email = "zz.test.mia@example.com"',
    'Mia|Familie|3|1');
CALL test_error('T75', 'Regel 6: neue Person ohne E-Mail und ohne Telefon',
    'CALL sp_add_friend("Max", "ZZ-Test Person", "", NULL, NULL, NULL, NULL, "Kollegium", 2)', 1644, 'Bitte mindestens E-Mail oder Telefon angeben.');
CALL test_error('T76', 'Neue Person mit unbekannter Beziehung',
    'CALL sp_add_friend("Max", "ZZ-Test Person", NULL, "0151 123", NULL, NULL, NULL, "Kumpel", 2)', 1644, 'Beziehung muss Freundeskreis%');
CALL test_error('T77', 'Neue Person mit unvollständiger E-Mail',
    'CALL sp_add_friend("Max", "ZZ-Test Person", "max.example.com", NULL, NULL, NULL, NULL, "Kollegium", 2)', 1644, 'Die E-Mail-Adresse sieht unvollständig aus.');
CALL test_error('T78', 'Neue Person mit einer E-Mail, die es schon gibt',
    'CALL sp_add_friend("Max", "ZZ-Test Person", "zz.test.mia@example.com", NULL, NULL, NULL, NULL, "Kollegium", 2)', 1644, 'Diese E-Mail-Adresse gehört schon einer anderen Person.');
CALL test_error('T79', 'Neue Person mit max. 0 Büchern',
    'CALL sp_add_friend("Max", "ZZ-Test Person", NULL, "0151 123", NULL, NULL, NULL, "Kollegium", 0)', 1644, 'Max. Bücher muss zwischen 1 und 10 liegen.');


-- =====================================================================
-- Teil 8: Rechnen die Views richtig? (neu in Version 2)
--   Erst gezielt mit den Testdaten, dann als Abgleich: Die Zahlen der
--   Views müssen zu den Tabellen passen, egal welche Daten geladen sind.
-- =====================================================================
CALL test_ok('T80', 'Vorbereitung: Kai leiht Buch F noch einmal (1 von 1)',
    'CALL sp_lend_book(@b_f, @f_one, 28)');
CALL test_ok('T81', 'Vorbereitung: Tina hat ein Buch seit 15 Tagen, Frist seit gestern vorbei',
    'INSERT INTO loans (book_id, friend_id, loan_date, due_date) VALUES (@b_o, @f_limit, CURDATE() - INTERVAL 15 DAY, CURDATE() - INTERVAL 1 DAY)');
CALL test_value('T82', 'v_friend_statistics: Kai hat sein Limit erreicht',
    'SELECT lend_status FROM v_friend_statistics WHERE friend_id = @f_one', 'Limit erreicht');
CALL test_value('T83', 'v_friend_statistics: Tina hat Überfälliges',
    'SELECT lend_status FROM v_friend_statistics WHERE friend_id = @f_limit', 'hat Überfälliges');
CALL test_value('T84', 'v_friend_statistics: Olaf ist frei (2 von 3, nichts überfällig)',
    'SELECT CONCAT(lend_status, "|", open_loans, "|", overdue_now) FROM v_friend_statistics WHERE friend_id = @f_late', 'frei|2|0');
CALL test_value('T85', 'v_friend_statistics: Nele hat 1 von 2 Rückgaben pünktlich = 50 %',
    'SELECT CONCAT(returned, "|", returned_late, "|", on_time_rate_pct) FROM v_friend_statistics WHERE friend_id = @f_new', '2|1|50');
CALL test_value('T86', 'v_book_overview: gesperrtes Buch',
    'SELECT status FROM v_book_overview WHERE book_id = @b_x', 'nicht verleihbar');
CALL test_value('T87', 'v_book_overview: Buch A ist bei Nele',
    'SELECT CONCAT(status, "|", borrowed_by) FROM v_book_overview WHERE book_id = @b_a', 'ausgeliehen|Nele ZZ-Test Neu');
CALL test_value('T88', 'v_current_loans: 1 Tag überfällig',
    'SELECT CONCAT(loan_status, "|", days_overdue, "|", due_soon) FROM v_current_loans WHERE book_id = @b_o', 'überfällig|1|0');
CALL test_value('T89', 'v_reminders: Text nennt Vornamen und Titel',
    'SELECT reminder_text LIKE "Hallo Tina, hast du noch an %ZZ-Test ohne ISBN% gedacht? Die Rückgabe war am % fällig. Liebe Grüße, Liane" FROM v_reminders WHERE book_id = @b_o',
    '1');
CALL test_value('T90', 'v_kpi_overview: gesamt = im Regal + verliehen, im Regal = verfügbar + gesperrt',
    'SELECT books_total = books_on_shelf + books_lent AND books_on_shelf = books_available + books_not_lendable FROM v_kpi_overview', '1');
CALL test_value('T91', 'v_kpi_overview passt zu den Tabellen (Bücher, Personen, Ausleihen, Überfällige)',
    'SELECT books_total = (SELECT COUNT(*) FROM books) AND friends_total = (SELECT COUNT(*) FROM friends) AND loans_total = (SELECT COUNT(*) FROM loans) AND loans_overdue = (SELECT COUNT(*) FROM v_overdue_loans) FROM v_kpi_overview',
    '1');
CALL test_value('T92', 'v_loans_per_month: Summe der Monate = alle Ausleihen',
    'SELECT (SELECT SUM(loans) FROM v_loans_per_month) = (SELECT COUNT(*) FROM loans)', '1');
CALL test_value('T93', 'v_loans_per_month: kein Monat fehlt zwischen dem ersten und dem letzten',
    'SELECT COUNT(*) = 1 + TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(MIN(month), "-01"), "%Y-%m-%d"), STR_TO_DATE(CONCAT(MAX(month), "-01"), "%Y-%m-%d")) FROM v_loans_per_month',
    '1');
CALL test_value('T94', 'v_loans_per_month: laufende Summe endet bei der Gesamtzahl',
    'SELECT MAX(loans_cumulative) = (SELECT COUNT(*) FROM loans) FROM v_loans_per_month', '1');
CALL test_value('T95', 'v_loan_history: offene Ausleihen = v_current_loans',
    'SELECT (SELECT COUNT(*) FROM v_loan_history WHERE outcome IN ("unterwegs", "überfällig")) = (SELECT COUNT(*) FROM v_current_loans)', '1');
CALL test_value('T96', 'v_genre_statistics: Anteile ergeben zusammen 100 %',
    'SELECT ABS(SUM(share_of_loans_pct) - 100) <= 1 FROM v_genre_statistics', '1');
CALL test_value('T97', 'v_book_ranking: jedes Buch kommt genau einmal vor',
    'SELECT COUNT(*) = (SELECT COUNT(*) FROM books) AND COUNT(*) = COUNT(DISTINCT book_id) FROM v_book_ranking', '1');


-- =====================================================================
-- Teil 9: Aufbau und Rechte (neu in Version 2)
-- =====================================================================
CALL test_value('T98', 'Aufbau: 7 Tabellen, 11 Views, 7 Procedures, 2 Trigger, 11 CHECKs',
    'SELECT CONCAT_WS("/", (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = "BASE TABLE"), (SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE()), (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = "PROCEDURE" AND LEFT(ROUTINE_NAME, 3) = "sp_"), (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()), (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = "CHECK"))',
    '7/11/7/2/11');
CALL test_value('T99', 'App-Benutzer: nur SELECT auf 11 Views, 7 Procedures, sonst nichts',
    'SELECT CONCAT_WS("/", (SELECT COUNT(*) FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE LIKE "%liane_app_v2%" AND TABLE_SCHEMA = DATABASE() AND PRIVILEGE_TYPE = "SELECT" AND LEFT(TABLE_NAME, 2) = "v_"), (SELECT COUNT(*) FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE LIKE "%liane_app_v2%" AND TABLE_SCHEMA = DATABASE()), (SELECT COUNT(*) FROM mysql.procs_priv WHERE User = "liane_app_v2" AND Db = DATABASE()), (SELECT COUNT(*) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE LIKE "%liane_app_v2%" AND TABLE_SCHEMA = DATABASE()))',
    '11/11/7/0');


-- =====================================================================
-- Aufräumen und Ergebnis
-- =====================================================================
CALL test_cleanup();

CALL test_value('T100', 'Nach dem Aufräumen hat jede Tabelle wieder so viele Zeilen wie vorher',
    'SELECT CONCAT_WS("|", (SELECT COUNT(*) FROM genres), (SELECT COUNT(*) FROM publishers), (SELECT COUNT(*) FROM authors), (SELECT COUNT(*) FROM books), (SELECT COUNT(*) FROM book_authors), (SELECT COUNT(*) FROM friends), (SELECT COUNT(*) FROM loans)) = @counts_before',
    '1');

DROP PROCEDURE IF EXISTS test_error;
DROP PROCEDURE IF EXISTS test_ok;
DROP PROCEDURE IF EXISTS test_value;
DROP PROCEDURE IF EXISTS test_run;
DROP PROCEDURE IF EXISTS test_cleanup;
SET SQL_SAFE_UPDATES = @old_safe_updates;

-- Vorletzter Ergebnis-Tab: jeder Test einzeln
SELECT test_id                          AS test,
       test_name                        AS was_wird_geprueft,
       expected                         AS erwartet,
       actual                           AS ergebnis,
       IF(passed = 1, 'OK', 'FEHLER')   AS status
FROM test_results
ORDER BY seq;

-- Letzter Ergebnis-Tab: das Gesamtergebnis
SELECT CONCAT(COUNT(CASE WHEN passed = 1 THEN 1 END), ' von ', COUNT(*), ' Tests bestanden')  AS gesamt,
       IF(COUNT(CASE WHEN passed = 1 THEN 1 END) = COUNT(*),
          'ALLES OK',
          'BITTE PRÜFEN: im Tab davor nach FEHLER suchen')                                    AS bewertung
FROM test_results;
