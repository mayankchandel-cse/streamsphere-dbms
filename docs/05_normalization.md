# StreamSphere (DBMS-ONLY) — Database Normalization

Scope: the 9 tables in `sql/01_schema.sql`. All analysis is on this schema
only — there is no Java / application code in this project.

## 1. Functional dependencies (FDs) per table

An FD `X -> Y` means: if two rows agree on X, they must agree on Y.
Only the non-trivial FDs that matter for normalization are listed.

### Genres(id, name, description)
- `id -> name, description`
- `name -> id, description` (name is UNIQUE, so it is also a determinant)

### Categories(id, name, description)
- `id -> name, description`
- `name -> id, description` (name is UNIQUE)

### Users(id, name, email, password_hash, role, created_at)
- `id -> name, email, password_hash, role, created_at`
- `email -> id, name, password_hash, role, created_at` (email is UNIQUE)

### Movies(id, title, genre, language, release_year, rating, duration_min,
###        popularity, description, cast_members, director, category_id,
###        poster_path, type, seasons, episodes, status)
- `id -> title, genre, language, release_year, rating, duration_min, popularity, description, cast_members, director, category_id, poster_path, type, seasons, episodes, status`
- `category_id -> (nothing in this table)` — category_id is a FK; the
  category's *name* lives in Categories, so there is no transitive
  dependency inside Movies. (If `category_name` had been stored in Movies,
  we would have `category_id -> category_name`, a transitive dependency.)
- No FD `genre -> ...` inside Movies: genre is a plain value, not a key.

### WebSeries(id, seasons, total_episodes, status)
- `id -> seasons, total_episodes, status`
- `id` is both PK and FK to Movies(id) — a 1:1 extension.

### Watchlist(id, user_id, movie_id, added_date)
- `id -> user_id, movie_id, added_date`
- `(user_id, movie_id) -> id, added_date` (the pair is UNIQUE)

### Reviews(id, user_id, movie_id, rating, comment, created_at)
- `id -> user_id, movie_id, rating, comment, created_at`
- `(user_id, movie_id) -> id, rating, comment, created_at` (pair is UNIQUE)

### Watch_History(id, user_id, movie_id, watched_at, progress_percent)
- `id -> user_id, movie_id, watched_at, progress_percent`
- No FD from `(user_id, movie_id)`: a user can watch the same movie many
  times, so the pair does **not** determine a row.

### Ratings(id, user_id, movie_id, stars, rated_at)
- `id -> user_id, movie_id, stars, rated_at`
- `(user_id, movie_id) -> id, stars, rated_at` (pair is UNIQUE)

## 2. Candidate keys and attribute closure — worked example

**Candidate keys** (minimal attribute sets that determine the whole row):

| Table | Candidate key(s) | Primary key chosen | Alternate key(s) |
|---|---|---|---|
| Genres | {id}, {name} | id | name |
| Categories | {id}, {name} | id | name |
| Users | {id}, {email} | id | email |
| Movies | {id} | id | — (see note) |
| WebSeries | {id} | id | — |
| Watchlist | {id}, {user_id, movie_id} | id | (user_id, movie_id) |
| Reviews | {id}, {user_id, movie_id} | id | (user_id, movie_id) |
| Watch_History | {id} | id | — |
| Ratings | {id}, {user_id, movie_id} | id | (user_id, movie_id) |

Movies has no second candidate key: `(title, release_year, language)`
looks like one, but remakes exist (same title, year and language), so it
is not declared UNIQUE and is not a candidate key.

### Attribute closure — example: `{user_id, movie_id}` in Reviews

Closure `{user_id, movie_id}+` is computed by starting with the set and
repeatedly adding every attribute determined by an FD whose left side is
already in the set.

FDs of Reviews:
- F1: `id -> user_id, movie_id, rating, comment, created_at`
- F2: `(user_id, movie_id) -> id, rating, comment, created_at`

Computation:
1. Start: `{user_id, movie_id}`
2. F2 applies (its left side is in the set): add `id, rating, comment, created_at`
   → `{user_id, movie_id, id, rating, comment, created_at}`
3. F1 now applies (id is in the set): adds nothing new.
4. No FD adds anything more. Closure = **all attributes of Reviews**.

Therefore `{user_id, movie_id}` is a **superkey** of Reviews. It is a
**candidate key** because it is minimal: remove `user_id` and `{movie_id}`
does not determine a row (many users review one movie); remove `movie_id`
and `{user_id}` does not determine a row (one user reviews many movies).

The same argument works for Watchlist and Ratings (same pair, same FDs).
For Watch_History the closure of `{user_id, movie_id}` is just
`{user_id, movie_id}` — no FD has that pair on the left — so it is **not**
a key there, which is exactly why re-watches are allowed as separate rows.

## 3. Normal forms, per table

### 1NF — all tables: YES
Every attribute holds a single, atomic value: no repeating groups, no
multi-valued attributes, no arrays. (`cast_members` is a comma-separated
string — see the honest note in §5; it is atomic *as stored*, but it is
the one place a stricter design would split it out.)

### 2NF — all tables: YES
2NF = 1NF + no partial dependency on part of a composite PK.
- Tables with a single-attribute PK (Genres, Categories, Users, Movies,
  WebSeries, Watch_History) are in 2NF automatically — there is no
  "part of the key" for an attribute to depend on.
- Watchlist / Reviews / Ratings have a surrogate PK `id`; every
  non-key attribute depends on the whole key `id` (and also on the
  alternate key `(user_id, movie_id)`), never on `user_id` or `movie_id`
  alone. So no partial dependency exists.

### 3NF — all tables: YES
3NF = 2NF + no transitive dependency (a non-key attribute depending on
another non-key attribute).
- Movies: `category_id` is a FK, but the category *name* is not stored
  in Movies, so nothing depends transitively on it.
- Users: `role` depends on the user (`id`), not on `email` or any other
  non-key attribute.
- All other tables: every non-key attribute depends directly on the key.

### BCNF — all tables: YES
BCNF = every determinant is a candidate key.
- In Users, `email -> ...` is fine because `email` is a candidate key.
- In Genres/Categories, `name -> ...` is fine because `name` is a
  candidate key.
- In Watchlist/Reviews/Ratings, `(user_id, movie_id) -> ...` is fine
  because the pair is a candidate key.
- In Movies, the only determinant is `id`, the PK.
- No table has a determinant that is not a superkey.

### 4NF — all tables: YES (with one honest exception, §5)
4NF = BCNF + no non-trivial multi-valued dependency (MVD).
No table stores two independent multi-valued facts about the same key:
Watchlist stores one fact (user saved movie), Reviews stores one fact
(user reviewed movie). The exception is `Movies.cast_members`: a movie
has many cast members, and if the same column also had to carry many
genres, that would be an MVD. As stored it is a single string, so the
table is formally in 4NF, but a strict design would split cast into its
own table (see §5).

### 5NF — all tables: YES
5NF = every join dependency is implied by a candidate key; the schema
cannot be losslessly decomposed any further into smaller tables without
losing information. The M:N relationships (Users–Movies) are already
decomposed into their own bridge tables (Watchlist, Reviews, Ratings,
Watch_History), each of which is exactly the join of its two parents
plus its own attributes. No table can be split further without losing
a fact (e.g. splitting Reviews into (user_id, rating) and
(movie_id, rating) would lose *which user gave which movie which rating*).

Summary:

| Table | 1NF | 2NF | 3NF | BCNF | 4NF | 5NF |
|---|---|---|---|---|---|---|
| Genres, Categories, Users, Movies, WebSeries, Watchlist, Reviews, Watch_History, Ratings | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## 4. Lossless decomposition and dependency preservation

**Lossless decomposition.** The original un-normalized idea — one big
table `AllData(user, email, movie, genre, category, rating, ...)` — was
decomposed into the 9 tables by splitting on the FDs in §1. The
decomposition is **lossless (lossless join)** because every split was
made on a key:

- `Movies` was split from `WebSeries` on `Movies.id`, a key of Movies,
  and `WebSeries.id` is both PK and FK to it — joining them back on
  `id` reproduces exactly the original rows, no spurious tuples.
- Users–Movies M:N was split into bridge tables whose PKs contain the
  FKs to both parents — joining Watchlist to Users and Movies on
  `user_id` / `movie_id` reproduces the original pairing exactly.
- In general, a decomposition of R into R1, R2 is lossless if
  `R1 ∩ R2 -> R1` or `R1 ∩ R2 -> R2` (the common attributes are a key
  of one side). Here every join is on a PK/FK pair, so this holds at
  every step. Test it: `SELECT COUNT(*) FROM Movies m JOIN WebSeries w
  ON m.id = w.id;` returns exactly 3 — the 3 series, no duplicates,
  nothing lost.

**Dependency preservation.** Every FD in §1 is still enforceable in
the decomposed schema without a join:
- `id -> ...` in each table is enforced by that table's PK.
- `(user_id, movie_id) -> ...` in Watchlist/Reviews/Ratings is enforced
  by the UNIQUE pair constraint in the same table.
- `email -> ...` and `name -> ...` are enforced by the UNIQUE
  constraints on Users.email, Genres.name, Categories.name.
- The FK dependencies (`Movies.category_id -> Categories.id`, etc.)
  are enforced by the FOREIGN KEY constraints themselves.
No FD was lost in the decomposition.

## 5. Honest note: the `Movies.genre` denormalisation trade-off

`Movies.genre` is a `VARCHAR(50)` holding the genre *name*, while a
`Genres` lookup table also exists with the same names. That is a
deliberate, small **denormalisation**:

- **Why it was done:** the original project's code reads
  `Movies.genre` directly for searching/sorting by genre; a VARCHAR
  keeps every query in `sql/03_queries.sql` a single-table filter
  (`WHERE genre = 'Sci-Fi'`) instead of a join, and it keeps the table
  readable in a viva demo.
- **Cost:** the same fact (a genre name) lives in two places, so a
  rename in Genres does not automatically rename it in Movies, and a
  typo in `Movies.genre` (e.g. `'SciFi'`) is not rejected by the FK —
  there is no FK from `Movies.genre` to `Genres.name`.
- **Fully normalised alternative:** replace `Movies.genre` with
  `genre_id INT`, FK to `Genres(id)`, and join whenever the name is
  needed. That is the design to propose if the examiner asks "how
  would you improve this?" — and it is a one-line change per query
  (`JOIN Genres g ON m.genre_id = g.id`).
- **Same trade-off, `cast_members`:** a comma-separated string is
  convenient but not atomic in spirit. Fully normalised, it would be
  `Cast(movie_id, actor_name)` with one row per actor, which would also
  fix the 4NF note above and allow "all movies starring X" as a join
  instead of `LIKE '%X%'`.
