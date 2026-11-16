# Bibliothek für Liane · Version 2

Liane verleiht gern Bücher und will wissen, wer welches Buch hat und was überfällig ist.
Das Projekt löst das mit einer **MySQL-Datenbank** und einer **Python-App** (Streamlit) als Oberfläche.

Version 2 ist ein Neubau von Datenbank-Logik und App. Das **Datenmodell ist gleich geblieben**:
7 Tabellen in der 3. Normalform, 7 Regeln. Version 2 hat eine eigene Datenbank und einen eigenen
Ordner. Version 1 bleibt unverändert, beide laufen nebeneinander.

|  | Version 1 | Version 2 |
| --- | --- | --- |
| Ordner | `Liane_Bibliothek` | `Liane_Bibliothek_v2` |
| Datenbank | `liane_library` | `liane_library_v2` |
| App-Benutzer | `liane_app` | `liane_app_v2` |
| Adresse der App | http://localhost:8501 | http://localhost:8502 |

Was sich geändert hat und warum, steht in `docs/Vergleich_Version_1_und_2.pdf`.

## Start in 5 Schritten

1. MySQL 8 (ab 8.0.16) und MySQL Workbench installieren.
2. In Workbench mit dem eigenen MySQL-Server verbinden (zum Beispiel als `root`).
3. `sql/00_setup_complete.sql` öffnen und komplett ausführen (Blitz-Symbol).
   Danach gibt es 35 Bücher, 12 Personen und 0 Ausleihen.
4. Python installieren (zum Beispiel Anaconda).
5. Im Ordner `app` doppelt auf `start_app.bat` klicken. Der Browser öffnet die App.
   Ein Passwort ist nicht nötig.

Ohne die Batch-Datei:

```
cd app
pip install -r requirements.txt
streamlit run app.py
```

## Demo-Daten (optional, immer nur eins davon)

| Skript | Inhalt |
| --- | --- |
| `sql/06_demo_loans.sql` | 50 Beispiel-Ausleihen (40 zurück, 10 offen, 4 überfällig) |
| `sql/07_demo_one_year.sql` | „Ein Jahr später“: 50 Bücher, 18 Personen, 160 Ausleihen |

Nach dem Skript in der App links auf **Daten neu laden** klicken.
Zurück auf 0 Ausleihen: `00_setup_complete.sql` noch einmal ausführen.

## Die 7 Regeln und wo sie stehen

| Nr. | Regel | Durchgesetzt durch |
| --- | --- | --- |
| 1 | Ein Buch ist höchstens an eine Person gleichzeitig verliehen | `UNIQUE` auf `open_book_id`, Trigger |
| 2 | Höchstens `max_loans` Bücher pro Person | Trigger `trg_loans_before_insert` |
| 3 | Wer etwas Überfälliges hat, bekommt nichts Neues | Trigger `trg_loans_before_insert` |
| 4 | Leihfrist 28 Tage, verlängerbar | `sp_lend_book`, `sp_extend_loan` |
| 5 | Nicht verleihbare Bücher bleiben im Regal | `is_lendable`, Trigger `trg_loans_before_insert` |
| 6 | Jede Person braucht E-Mail oder Telefon | `CHECK chk_friends_contact` |
| 7 | Was eine Ausleih-Historie hat, wird nicht gelöscht | `FOREIGN KEY ... RESTRICT` |

Ein **Trigger** ist ein Programm, das MySQL automatisch vor jedem INSERT ausführt.
Deshalb gelten die Regeln 1, 2, 3 und 5 für jeden Weg in die Tabelle `loans`:
über die App, über `sp_lend_book` und bei einem direkten `INSERT` in Workbench.

Der Trigger prüft eine neue Ausleihe gegen alles, was schon in der Tabelle steht,
und zwar für den Tag der Ausleihe. So kann man auch eine alte Ausleihe nachtragen.
Die Demo-Daten stehen deshalb in zeitlicher Reihenfolge und laufen durch dieselbe Prüfung.

## Tests

`sql/09_tests.sql` enthält 100 Tests, die sich selbst auswerten:

1. Datei in Workbench öffnen und komplett ausführen.
2. Der **letzte Ergebnis-Tab** zeigt das Gesamtergebnis, zum Beispiel
   „100 von 100 Tests bestanden“. Der Tab davor listet jeden Test mit `OK` oder `FEHLER`.

Die Tests legen eigene Testdaten an (alles mit „ZZ-Test“) und löschen sie am Ende wieder.
Sie brauchen keine Demo-Daten, und die Datenbank ist danach wie vorher.

Die Anzeige-Hilfen der App haben eigene Tests: im Ordner `app` den Befehl
`python -m pytest tests` ausführen (oder `python tests/test_formats.py`).

## Abfragen

`sql/08_queries.sql` enthält 17 Abfragen zu Lianes Fragen (braucht `06_demo_loans.sql`):

- **Teil A** (Alltag): wer hat was, was ist überfällig, Erinnerungstexte, Suche.
- **Teil B** (Analyse): Rang mit Gleichstand (`DENSE_RANK`), Lieblingsgenre pro Person
  (`ROW_NUMBER` mit `PARTITION BY`), Vergleich zum Vormonat (`LAG`), laufende Summe, Median.
- **Teil C** (CRUD): `INSERT`, `UPDATE`, `DELETE` in einer Transaktion mit `ROLLBACK`.

## Projektstruktur

```
Liane_Bibliothek_v2/
├── README.md
├── .gitignore
├── sql/                           in dieser Reihenfolge ausführen
│   ├── 00_setup_complete.sql      01 bis 05 in einer Datei: hiermit starten (0 Ausleihen)
│   ├── 01_schema.sql              Datenbank und 7 Tabellen (DDL)
│   ├── 02_master_data.sql         Stammdaten: Genres, Verlage, Autoren, Bücher, Personen
│   ├── 03_views.sql               11 Views (6 für den Alltag, 5 für die Analyse)
│   ├── 04_procedures.sql          2 Trigger und 7 Stored Procedures
│   ├── 05_app_user.sql            App-Benutzer liane_app_v2 (minimale Rechte)
│   ├── 06_demo_loans.sql          optional: 50 Demo-Ausleihen
│   ├── 07_demo_one_year.sql       optional: Szenario „Ein Jahr später“
│   ├── 08_queries.sql             17 Abfragen + INSERT/UPDATE/DELETE-Beispiele
│   └── 09_tests.sql               100 Tests, die sich selbst auswerten
├── app/
│   ├── start_app.bat              Start per Doppelklick (Windows)
│   ├── app.py                     Seite, Seitenleiste, Kennzahlen, Reiter
│   ├── tabs.py                    die sechs Reiter
│   ├── design.py                  das Aussehen: CSS und HTML-Bausteine (Karten, Kennzahlen)
│   ├── charts.py                  die Diagramme (Altair)
│   ├── ui.py                      Daten laden, Meldungen, Aktionen
│   ├── formats.py                 Zahlen und Datumswerte im deutschen Format
│   ├── db.py                      Verbindung zu MySQL: Views lesen, Procedures aufrufen
│   ├── config.py                  Verbindungsdaten
│   ├── requirements.txt           Python-Pakete
│   ├── .streamlit/config.toml     Grundfarben, Port 8502
│   └── tests/test_formats.py      Tests für formats.py
├── docs/
│   ├── Vergleich_Version_1_und_2.pdf
│   ├── erd.png                    ER-Diagramm als Bild
│   ├── erd.html                   ER-Diagramm zum Öffnen im Browser
│   └── erd.mmd                    ER-Diagramm als Mermaid-Code
└── tools/
    └── build_setup.py             erzeugt 00_setup_complete.sql aus 01 bis 05
```

`00_setup_complete.sql` wird nicht von Hand gepflegt. Nach einer Änderung an 01 bis 05:
`python tools/build_setup.py`.

## Wenn etwas nicht klappt

| Meldung in der App | Ursache | Lösung |
| --- | --- | --- |
| Can't connect to MySQL server | MySQL läuft nicht | Windows-Dienste öffnen, `MySQL80` starten |
| Access denied / Unknown database | Datenbank oder App-Benutzer fehlt | `sql/00_setup_complete.sql` ausführen |
| Diese Views sind veraltet | alte Version der Views | `sql/00_setup_complete.sql` ausführen |
| Zahlen sind nicht aktuell | Zwischenspeicher der App (60 Sekunden) | links auf **Daten neu laden** klicken |

## Hinweise zu den Daten

Titel, Autoren und Verlage sind echte Bücher. Die ISBN-Nummern sind fiktiv.
Alle Personen sind erfunden, die E-Mail-Adressen enden auf `example.com`.
