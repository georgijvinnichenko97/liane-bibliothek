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
