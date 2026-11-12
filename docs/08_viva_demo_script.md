# StreamSphere (DBMS-ONLY) — 2-minute viva demo script (MySQL Workbench)

Not a report — a timed script to read / rehearse before the viva.
No Java, no Swing, no JDBC, no ADSA. Everything below runs in
MySQL Workbench (or the `mysql` client) against the files in `sql/`.

## 30-second pre-flight (do before the viva)

1. MySQL 8 running on port 3306.
2. Run the files **in this order, once each**:
   `sql/01_schema.sql`, then `sql/02_sample_data.sql`,
   then `sql/03_queries.sql`, then
   `sql/04_views_procedures_triggers_transactions.sql`.
   In Workbench: File → Open SQL Script → open each file → Execute.
3. Verify the counts before you start:
   ```sql
   USE streamsphere;
   SELECT COUNT(*) FROM Movies;  -- expect 15 (12 films + 3 web series)
   SELECT COUNT(*) FROM Users;   -- expect 3
   SELECT COUNT(*) FROM Reviews; -- expect 6 (4 from sample data + 2 added
                                 -- by the transaction examples in file 04)
   SHOW TABLES;                  -- expect 9 tables
   ```
   If Reviews is still 4, file 04 has not been run yet — run it now.
4. Have these open, ready to run one at a time: the ER diagram
   (`docs/er-diagram.png`), `sql/03_queries.sql` and
   `sql/04_views_procedures_triggers_transactions.sql`.
5. Know the two numbers that change live, so they don't surprise you:
   after file 04, Reviews goes from 4 to 6, and movie 5
   ("The Last Samurai's Son") goes from 8.9 to 9.0 — the trigger
   recomputed it from the two new reviews (5 and 4 stars, ×2 for the
   0–10 scale). That is working as designed, not an error.

## The 2-minute script

**0:00–0:20 — What it is, and the design**
> "StreamSphere is a Netflix-style catalogue built as a MySQL-only
> project — 9 normalized tables, no application code. Users, Movies,
> WebSeries, Genres, Categories, Watchlist, Reviews, Watch_History
> and Ratings."
>
Show the ER diagram (`docs/er-diagram.png`), then:
```sql
SHOW TABLES;                 -- 9 tables
DESCRIBE Movies;             -- PK id, FK category_id, CHECKs, indexes
```
Say: "Movies is the supertype, WebSeries is the subtype — that is
the EER part. Users–Movies is many-to-many, bridged by Watchlist,
Reviews, Watch_History and Ratings."

**0:20–0:50 — One query from each group**
Run these three, naming the concept each time:
```sql
-- Q13, INNER JOIN: movies with their category name
-- (top rows: Galaxy Quest: Reborn, 9.3, Movies)
-- Q9, GROUP BY + HAVING: genres with more than one title
-- (Sci-Fi averages 9.13 over 3 titles — the highest genre average)
-- Q24, correlated subquery: movies above their own genre's average
```
Say: "Q9's HAVING filters groups, not rows. Q24's subquery runs once
per outer row, so on large data a JOIN would be faster — that is the
trade-off in `docs/07_viva_qa.md` Q10."

**0:50–1:20 — Views, procedure, and the trigger, live**
```sql
SELECT * FROM vw_top_rated;              -- top is Galaxy Quest: Reborn, 9.3
CALL sp_search_movies('Cyber%');         -- Cyber Squad: Zero Day + Code Red: Cyber Heist
SELECT title, rating FROM Movies WHERE id = 7;   -- 9.3 before
INSERT INTO Reviews (user_id, movie_id, rating, comment)
  VALUES (3, 7, 4, 'Great fun.');
SELECT title, rating FROM Movies WHERE id = 7;   -- now 9.0, no UPDATE written
```
Say: "I only inserted a review. The trigger `trg_after_review_insert`
recomputed the rating itself: (5 + 4) / 2 × 2 = 9.0 — the ×2 is because
reviews are 1–5 stars and Movies.rating is 0–10."
Then undo it, so the data stays clean:
```sql
DELETE FROM Reviews WHERE user_id = 3 AND movie_id = 7;
UPDATE Movies SET rating = 9.3 WHERE id = 7;
```

**1:20–1:45 — Transaction, live (nothing is saved)**
Run Example C from file 04 — it is commented out there, so run it
by hand:
```sql
START TRANSACTION;
INSERT INTO Reviews (user_id, movie_id, rating, comment)
  VALUES (2, 6, 1, 'This review will never be saved.');
ROLLBACK;
SELECT * FROM Reviews WHERE user_id = 2 AND movie_id = 6;  -- empty
```
Say: "That is atomicity — all or nothing. File 04 Example B shows
the middle case: a SAVEPOINT keeps the review but rolls back only
the rating row after it."
If asked, add one line: "Isolation is REPEATABLE READ, InnoDB's
default, with row-level locking — see `docs/07_viva_qa.md` Q6–Q7."

**1:45–2:00 — Security and close**
```sql
SELECT User, Host FROM mysql.user WHERE User LIKE 'app_%';
-- app_user and app_admin, both on localhost
SHOW GRANTS FOR 'app_user'@'localhost';   -- read everything, write only
                                           -- Watchlist / Reviews / Ratings
```
Close with one line:
> "Passwords are SHA-256 hashes, never plain text — `SELECT
> SHA2('admin123', 256)` reproduces the stored hash — and the design
> is BCNF, with the one honest trade-off in `docs/05_normalization.md`:
> `Movies.genre` is a VARCHAR, not a foreign key to Genres."

## If something goes wrong live

| Problem | Say / do |
|---|---|
| `Unknown database 'streamsphere'` | File 01 was not run — run `01_schema.sql` first |
| Counts are 0 / tables missing | Files were run out of order — re-run 01, then 02 |
| Reviews is 4, not 6 | File 04 has not been run yet — run it, then re-check |
| Movie 5 shows 9.0, not 8.9 | Expected after file 04 (see pre-flight §5) — say so |
| Re-running file 02 adds history rows | Expected: Watch_History has no UNIQUE key, it is a log — see README |
| `CREATE USER` / `GRANT` fails | That section of file 04 needs a root/admin login — run it as root |
| A query returns no rows | Check you are in `USE streamsphere;` and the file order above |

Short answers to likely questions are in `docs/07_viva_qa.md`
(15 Q&As). The six verified screenshots from a real run are in
`docs/screenshots/` (01_tables through 06_verify), with the
`DESCRIBE Movies` output as `01b_describe.txt`.
