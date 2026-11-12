# StreamSphere (DBMS-ONLY) — Viva Q&A (15 questions)

Short answers — one or two sentences each, then stop. Every answer can
be demonstrated in `sql/01_schema.sql` – `sql/04_...sql`.

## 1. What is a primary key? How is it different from a foreign key?
A primary key uniquely identifies each row of a table and cannot be NULL
(`Users.id`). A foreign key is a column in one table that refers to the
primary key of another table (`Watchlist.user_id -> Users.id`) and
enforces referential integrity — you cannot insert a watchlist row for
a user who does not exist.

## 2. Candidate key vs alternate key vs primary key?
A candidate key is any minimal set of attributes that uniquely
identifies a row. The primary key is the candidate key chosen as the
main identifier. The other candidate keys are alternate keys — e.g. in
Users, `id` is the PK and `email` (UNIQUE) is the alternate key.

## 3. What is 1NF, 2NF, 3NF, BCNF?
1NF: every attribute is atomic, no repeating groups. 2NF: 1NF + no
partial dependency on part of a composite key. 3NF: 2NF + no transitive
dependency (non-key attribute depending on another non-key attribute).
BCNF: every determinant is a candidate key — stricter than 3NF; in this
project all 9 tables are in BCNF (see `docs/05_normalization.md`).

## 4. What are ACID properties?
Atomicity (a transaction is all-or-nothing), Consistency (a transaction
moves the database from one valid state to another), Isolation
(concurrent transactions do not interfere), Durability (a committed
transaction survives a crash). Demonstrated in `04_...sql`: the review
+ rating insert is one transaction — COMMIT saves both, ROLLBACK
undoes both.

## 5. COMMIT vs ROLLBACK vs SAVEPOINT?
COMMIT makes a transaction's changes permanent. ROLLBACK undoes all
changes since the transaction began. A SAVEPOINT marks a point inside
a transaction so `ROLLBACK TO SAVEPOINT` undoes only the work after
that point — shown in Example B of `04_...sql`.

## 6. What are transaction isolation levels?
READ UNCOMMITTED (dirty reads allowed), READ COMMITTED (no dirty reads),
REPEATABLE READ (MySQL/InnoDB default — no non-repeatable reads),
SERIALIZABLE (strictest, transactions run as if one at a time).
Higher isolation = fewer anomalies, more locking and less concurrency.

## 7. What are deadlocks and locking?
A deadlock is two transactions each waiting for a lock the other holds;
InnoDB detects it and rolls back one transaction (the victim) so the
other can finish. InnoDB uses row-level locking (only the affected
rows are locked, not the whole table), plus shared locks for reads and
exclusive locks for writes.

## 8. What is an index, and why a B-tree?
An index is a separate data structure that lets the database find rows
without scanning the whole table — like a book's index. InnoDB uses
B-trees: balanced, so lookup, insert and range scans are O(log n), and
ordered, so `ORDER BY` on an indexed column needs no extra sort.
This project has 9 indexes, e.g. `idx_movies_genre` on `Movies(genre)`.

## 9. INNER JOIN vs LEFT JOIN vs RIGHT JOIN?
INNER JOIN returns only rows that match in both tables. LEFT JOIN
returns all rows from the left table, with NULLs where the right table
has no match (Q15: all users, even with an empty watchlist). RIGHT
JOIN is the mirror image — all rows from the right table (Q17).

## 10. Subquery vs JOIN — when to use which?
A subquery is a query inside another query; a JOIN combines tables in
one query. Use a JOIN when you need columns from both tables, and a
subquery when you need a single value or a filtered set (Q20: movies
above the average rating). A correlated subquery (Q23/Q24) runs once
per outer row, so it is slower than an equivalent JOIN on large data.

## 11. Normalization vs denormalisation — which is better?
Normalization removes redundancy and update anomalies, but every
fact split across tables costs a JOIN to read back. Denormalisation
deliberately re-introduces redundancy for speed or simplicity. This
project is fully normalized to BCNF/5NF except for one honest trade-off:
`Movies.genre` is a VARCHAR instead of a FK to Genres (see
`05_normalization.md` §5).

## 12. Trigger vs stored procedure?
A stored procedure is code you call explicitly (`CALL sp_add_review(...)`).
A trigger is code the database runs automatically when an event happens
(`trg_after_review_insert` fires AFTER INSERT on Reviews and
recomputes `Movies.rating`). Procedures are for reusable logic you
invoke; triggers are for rules that must always hold, even if someone
inserts a row by hand.

## 13. GRANT vs REVOKE?
GRANT gives a MySQL user a privilege (`GRANT SELECT ON
streamsphere.Movies TO 'app_user'@'localhost'`); REVOKE takes it away
(`REVOKE DELETE ON streamsphere.Reviews FROM 'app_user'@'localhost'`).
Together they implement role-based access: the app user can read the
catalogue and write only watchlists/reviews, the admin can write
everything (see `04_...sql` §5).

## 14. ER diagram vs EER diagram?
An ER diagram shows entities, attributes and relationships. An EER
diagram adds the extra concepts: specialization/generalization,
subtypes, disjointness and completeness. Here the EER part is Movies
(supertype) and WebSeries (subtype, disjoint, partial completeness).

## 15. What is a lossless join / lossless decomposition?
A decomposition is lossless if joining the smaller tables back together
reproduces exactly the original table — no rows lost, no spurious rows
created. It holds when the common attributes of the split are a key of
one side: e.g. Movies and WebSeries join on `id`, which is the PK of
both, so the join returns exactly the 3 series rows.
