# StreamSphere — DBMS Project

A college-level  database project for a Netflix-style
entertainment platform. Everything is done in SQL:
schema, sample data, queries, views, procedures, triggers, transactions
and security.



## Scope (DBMS only)

- Relational design: 9 normalized tables (BCNF / 5NF — see
  `docs/05_normalization.md`), ER + EER design, DFDs, use cases
  (`docs/06_design.md`).
- SQL: DDL, DML, 30 queries (SELECT, JOINs, subqueries, aggregates,
  GROUP BY / HAVING, UNION, UPDATE, DELETE), views, stored procedures,
  a trigger, transactions (`sql/03_queries.sql`,
  `sql/04_views_procedures_triggers_transactions.sql`).
- Database security: SHA-256 password hashes, role-based MySQL users
  (`app_user` / `app_admin`), GRANT / REVOKE.
- Viva preparation: `docs/07_viva_qa.md` (15 questions) and
  `docs/08_viva_demo_script.md` (2-minute timed demo script).

## Prerequisites

| Item | Notes |
|---|---|
| MySQL Server | 8.x, running locally on port 3306 |
| MySQL Workbench | 8.x (or the `mysql` command-line client) |
| OS | Windows / macOS / Linux |



## How to run — in this order

From the `streamsphere-dbms/` folder, in a terminal:

```bash
# 1. Create the 9 tables + 9 indexes
mysql -u root -p < sql/01_schema.sql

# 2. Load the sample data (8 genres, 3 categories, 3 users,
#    12 films + 3 web series, watchlist, reviews, history, ratings)
mysql -u root -p < sql/02_sample_data.sql

# 3. Run the 30 queries
mysql -u root -p < sql/03_queries.sql

# 4. Create views, procedures, the trigger, and run the
#    transaction + security examples
mysql -u root -p < sql/04_views_procedures_triggers_transactions.sql
```

Or in **MySQL Workbench**: File → Open SQL Script → open each file in
order → click Execute (lightning icon). The `CREATE USER` / `GRANT`
section of step 4 needs a root (or admin) login.

## File list

```
streamsphere-dbms/
├── README.md
├── sql/
│   ├── 01_schema.sql      # CREATE DATABASE + 9 tables, PK/FK/UNIQUE/CHECK,
│   │                      #   ENUM role, 9 indexes
│   ├── 02_sample_data.sql # 8 genres, 3 categories, 3 users, 15 Movies rows
│   │                      #   (12 films + 3 series), WebSeries, Watchlist,
│   │                      #   Reviews, Watch_History, Ratings
│   ├── 03_queries.sql     # 30 numbered queries, grouped (a)-(f)
│   └── 04_views_procedures_triggers_transactions.sql
│                          # 3 views, 2 procedures, 1 trigger, transactions
│                          #   with SAVEPOINT, app_user/app_admin + GRANT/REVOKE
└── docs/
    ├── 05_normalization.md  # FDs, candidate keys, attribute closure,
    │                        #   1NF-5NF per table, lossless join, the
    │                        #   Movies.genre denormalisation trade-off
    ├── 06_design.md         # ER/EER (text), relational schema, ER-to-
    │                        #   relational mapping, DFD Level 0/1, 10 use
    │                        #   cases, query optimisation (EXPLAIN, cost)
    ├── 07_viva_qa.md        # 15 short DBMS viva Q&A
    └── 08_viva_demo_script.md  # 2-minute timed viva demo script
```

## Logins (application users — rows in the Users table)

| Role | Email | Password |
|---|---|---|
| Admin | `admin@streamsphere.com` | `admin123` |
| User (demo) | `demo@streamsphere.com` | `demo123` |
| User (test) | `test@streamsphere.com` | `test123` |

Passwords are stored in MySQL as **SHA-256 hashes** (`SHA2(password, 256)`),
never as plain text — MySQL computes the hash in the INSERT itself:

```sql
SELECT email, password_hash FROM Users;
-- admin123 -> 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
-- demo123  -> d3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791
SELECT SHA2('admin123', 256);   -- verify the hash yourself
```

The MySQL server accounts in step 4 (`app_user` / `app_admin`) are
separate from these — see `sql/04_...sql` §5.

## How to verify

```sql
USE streamsphere;
SELECT COUNT(*) FROM Genres;        -- expect 8
SELECT COUNT(*) FROM Categories;    -- expect 3
SELECT COUNT(*) FROM Users;         -- expect 3
SELECT COUNT(*) FROM Movies;        -- expect 15 (12 films + 3 series)
SELECT COUNT(*) FROM Movies WHERE type = 'WebSeries';  -- expect 3
SELECT COUNT(*) FROM WebSeries;     -- expect 3
SELECT COUNT(*) FROM Watchlist;     -- expect 3
SELECT COUNT(*) FROM Reviews;       -- expect 4 (+2 after running file 04)
SELECT COUNT(*) FROM Watch_History; -- expect 3 (+3 each re-run of file 02)
SELECT COUNT(*) FROM Ratings;       -- expect 5 (+2 after running file 04)
SHOW TABLES;                        -- expect 9 tables
```

Note: file 04's transaction examples insert 2 extra Reviews/Ratings
rows on purpose, and file 02's `Watch_History` INSERT has no UNIQUE
key, so re-running file 02 adds 3 more history rows each time — that
is correct behaviour for a history log, not a bug.

## Viva tips

1. Start with the ER diagram (`docs/06_design.md` §1) — entities,
   then the M:N Users–Movies bridges.
2. Show one query from each group in `03_queries.sql`: a JOIN (Q13),
   a GROUP BY + HAVING (Q9), a correlated subquery (Q24).
3. Demo the trigger live: insert a review, then `SELECT rating FROM
   Movies` — the rating changes automatically.
4. Demo a transaction: run Example B in file 04 and show the review
   is kept but the rating row is rolled back to the SAVEPOINT.
5. If asked "how would you improve it?", answer with the two honest
   trade-offs in `docs/05_normalization.md` §5: `Movies.genre` as a
   FK to Genres, and `cast_members` as its own table.
6. Full answers: `docs/07_viva_qa.md`.
