"""
Datenzugriff für Lianes Bibliothek (Version 2).

Dieses Modul enthält KEINE Geschäftslogik. Es macht nur zwei Dinge:
  1. Views lesen         -> SELECT * FROM <view>
  2. Procedures aufrufen -> CALL <procedure>(...)

Alle Regeln stehen in MySQL (Trigger und Procedures in sql/04_procedures.sql),
alle Berechnungen in den Views (sql/03_views.sql).

Unterschied zu Version 1: read_views() holt alle Views über EINE Verbindung.
Version 1 hat für jede der 10 Views eine eigene Verbindung geöffnet, und das
bei jedem Klick.
"""
from __future__ import annotations

from decimal import Decimal

import pandas as pd
import pymysql

from config import MYSQL

# Nur diese Objekte darf die App benutzen (Schutz gegen Tippfehler und SQL-Injection)
VIEWS = (
    "v_kpi_overview",
    "v_book_overview",
    "v_current_loans",
    "v_reminders",
    "v_friend_statistics",
    "v_loan_history",
    "v_loans_per_month",
    "v_punctuality_by_relationship",
    "v_genre_statistics",
    "v_book_ranking",
)
PROCEDURES = {
    "sp_add_book",
    "sp_add_author_to_book",
    "sp_lend_book",
    "sp_return_book",
    "sp_extend_loan",
    "sp_find_book",
    "sp_add_friend",
}

# MySQL-Fehlercodes, bei denen die App einen Tipp zeigt
ERR_NO_SERVER = 2003        # Server läuft nicht oder ist nicht erreichbar
ERR_ACCESS_DENIED = 1045    # Benutzer gibt es nicht (oder falsches Passwort)
ERR_DB_ACCESS_DENIED = 1044  # Benutzer darf die Datenbank nicht benutzen
ERR_UNKNOWN_DATABASE = 1049  # Datenbank gibt es nicht
ERR_NO_SUCH_TABLE = 1146    # View gibt es nicht
ERR_TABLE_DENIED = 1142     # kein Recht auf die View
ERR_PROC_DENIED = 1370      # kein Recht auf die Procedure
ERR_SIGNAL = 1644           # eigene Meldung aus Trigger oder Procedure (SIGNAL)


class DbError(Exception):
    """Eine Meldung aus MySQL. code ist der MySQL-Fehlercode (oder None)."""

    def __init__(self, message: str, code: int | None = None):
        super().__init__(message)
        self.code = code

    @property
    def is_rule(self) -> bool:
        """True, wenn eine Regel der Datenbank die Aktion abgelehnt hat (SIGNAL)."""
        return self.code == ERR_SIGNAL


def _to_db_error(error: Exception) -> DbError:
    """Macht aus einem PyMySQL-Fehler (args = (Code, Text)) einen DbError."""
    args = getattr(error, "args", ())
    if len(args) > 1:
        return DbError(str(args[1]), args[0] if isinstance(args[0], int) else None)
    return DbError(str(error))


def _connect():
    """Neue Verbindung zu MySQL. autocommit=True: jede Procedure speichert sofort."""
    return pymysql.connect(
        **MYSQL,
        charset="utf8mb4",
        autocommit=True,
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )


def _decimals_to_float(df: pd.DataFrame) -> pd.DataFrame:
    """MySQL liefert SUM/AVG/ROUND als DECIMAL. Für Diagramme in float umwandeln."""
    for column in df.columns:
        if df[column].map(lambda value: isinstance(value, Decimal)).any():
            df[column] = df[column].astype(float)
    return df


def read_views(names=VIEWS) -> dict[str, pd.DataFrame]:
    """Liest mehrere Views über eine einzige Verbindung. Ergebnis: {Name: DataFrame}."""
    unknown = [name for name in names if name not in VIEWS]
    if unknown:
        raise ValueError(f"Unbekannte View: {unknown[0]}")
    result = {}
    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                for name in names:
                    cur.execute(f"SELECT * FROM {name}")
                    rows = cur.fetchall()
                    columns = [d[0] for d in cur.description]
                    result[name] = _decimals_to_float(pd.DataFrame(rows, columns=columns))
    except pymysql.MySQLError as error:
        raise _to_db_error(error) from error
    return result


def call(procedure: str, *args) -> pd.DataFrame:
    """Ruft eine Stored Procedure auf und gibt ihr Ergebnis als DataFrame zurück.

    Die Werte gehen als Parameter (%s) an MySQL, nie als Teil des SQL-Textes.
    Das schützt vor SQL-Injection.
    """
    if procedure not in PROCEDURES:
        raise ValueError(f"Unbekannte Procedure: {procedure}")
    placeholders = ", ".join(["%s"] * len(args))
    try:
        with _connect() as conn:
            with conn.cursor() as cur:
                cur.execute(f"CALL {procedure}({placeholders})", args)
                rows = cur.fetchall()
                columns = [d[0] for d in cur.description] if cur.description else []
                while cur.nextset():  # restliche Ergebnisse der Procedure abholen
                    pass
    except pymysql.MySQLError as error:
        raise _to_db_error(error) from error
    return _decimals_to_float(pd.DataFrame(rows, columns=columns))


# ---------------------------------------------------------------------------
# Kurze Namen für die App (jeweils genau eine Procedure)
# ---------------------------------------------------------------------------
def lend_book(book_id: int, friend_id: int, days: int) -> pd.DataFrame:
    return call("sp_lend_book", int(book_id), int(friend_id), int(days))


def return_book(book_id: int) -> pd.DataFrame:
    return call("sp_return_book", int(book_id))


def extend_loan(book_id: int, extra_days: int) -> pd.DataFrame:
    return call("sp_extend_loan", int(book_id), int(extra_days))


def find_book(text: str) -> pd.DataFrame:
    return call("sp_find_book", text)


def add_book(title, author_first, author_last, genre, publisher, first_published, isbn) -> pd.DataFrame:
    year = int(first_published) if first_published else None
    return call("sp_add_book", title, author_first, author_last, genre, publisher, year, isbn)


def add_author_to_book(book_id: int, author_first: str, author_last: str) -> pd.DataFrame:
    return call("sp_add_author_to_book", int(book_id), author_first, author_last)


def add_friend(first_name, last_name, email, phone, street, postal_code, city, relationship, max_loans) -> pd.DataFrame:
    return call("sp_add_friend", first_name, last_name, email, phone, street, postal_code, city,
                relationship, int(max_loans))
