"""
Verbindungsdaten für die MySQL-Datenbank liane_library_v2 (Version 2).

Die App meldet sich als eigener Benutzer liane_app_v2 an (angelegt in
sql/05_app_user.sql, ist in 00_setup_complete.sql enthalten). Er braucht kein
Passwort, darf aber nur die 11 Views lesen und die 7 Stored Procedures
aufrufen. So ist die App für jeden ohne Anmeldung offen, und trotzdem gelten
alle Regeln aus MySQL.

Version 1 benutzt die Datenbank liane_library und den Benutzer liane_app.
Beide Versionen stören sich nicht.
"""

MYSQL = {
    "host": "localhost",
    "port": 3306,
    "user": "liane_app_v2",
    "password": "",
    "database": "liane_library_v2",
}
