# StreamSphere (DBMS-ONLY) — Design: ER / EER, Relational Schema, DFD, Use Cases

Scope: the database design only. No Java / Swing / JDBC / ADSA in this project.

## 1. ER diagram

See `er-diagram.png` in this folder for the visual diagram (all 9 tables, PKs/FKs, 1:N and 1:1 relationships).

## 1a. ER diagram (text form)

Entities are in CAPS; PKs are underlined in the list below (shown as `*`).

```
USERS *id, name, email (unique), password_hash, role, created_at
GENRES *id, name (unique), description
CATEGORIES *id, name (unique), description
MOVIES *id, title, genre, language, release_year, rating, duration_min,
       popularity, description, cast_members, director, category_id (FK),
       poster_path, type, seasons, episodes, status
WEBSERIES *id (FK to MOVIES.id), seasons, total_episodes, status
WATCHLIST *id, user_id (FK), movie_id (FK), added_date
REVIEWS *id, user_id (FK), movie_id (FK), rating, comment, created_at
WATCH_HISTORY *id, user_id (FK), movie_id (FK), watched_at, progress_percent
RATINGS *id, user_id (FK), movie_id (FK), stars, rated_at
```

Relationships and cardinality (read left to right):

| Relationship | Type | Meaning |
|---|---|---|
| USERS — WATCHLIST | 1:N | One user saves many movies; each watchlist row belongs to one user. Total participation on the Watchlist side. |
| MOVIES — WATCHLIST | 1:N | One movie is saved by many users; each watchlist row is for one movie. |
| USERS — REVIEWS | 1:N | One user writes many reviews; each review is by one user. |
| MOVIES — REVIEWS | 1:N | One movie has many reviews; each review is about one movie. |
| USERS — WATCH_HISTORY | 1:N | One user has many watch events; each event belongs to one user. |
| MOVIES — WATCH_HISTORY | 1:N | One movie is watched many times; each event is for one movie. |
| USERS — RATINGS | 1:N | One user gives many star ratings; each rating is by one user. |
| MOVIES — RATINGS | 1:N | One movie receives many star ratings; each rating is for one movie. |
| CATEGORIES — MOVIES | 1:N | One category contains many movies; each movie is in one category. |
| MOVIES — WEBSERIES | 1:1 | One movie row of type 'WebSeries' has exactly one WebSeries row; a film has none. Total on the WebSeries side, partial on the Movies side. |
| GENRES — MOVIES | 1:N (logical) | One genre names many movies. Logical only: `Movies.genre` is a VARCHAR, not a FK — see the denormalisation note in `05_normalization.md` §5. |

M:N relationships, resolved: Users–Movies is M:N in the real world
(a user watches many movies, a movie is watched by many users). It is
resolved by **four** bridge entities, one per kind of interaction:
Watchlist, Reviews, Watch_History, Ratings. Each bridge carries its own
attributes (added_date / rating+comment / progress_percent / stars).

## 2. EER notes — specialization / generalization

- **Supertype:** MOVIES. Every title — film or series — is a Movies row
  (id, title, genre, language, release_year, rating, ...).
- **Subtype:** WEBSERIES. A series is a movie *plus* series-only
  attributes (seasons, total_episodes, status). Implemented as a
  1:1 extension table whose PK is also its FK to Movies(id).
- **Disjointness:** disjoint — a title is either a film or a web series,
  never both (`Movies.type` is 'Movie' or 'WebSeries', CHECK-enforced).
- **Completeness:** partial — films have no subtype row at all (they
  need no series attributes); series must have exactly one subtype row.
- There is no second subtype in this schema: films need no extra
  attributes beyond the supertype, so no `Films` table is created.
- **Union / aggregation:** none used. No category (union type) is needed.

## 3. Relational schema (final, as implemented in sql/01_schema.sql)

```
Genres(id, name, description)
Categories(id, name, description)
Users(id, name, email, password_hash, role, created_at)
Movies(id, title, genre, language, release_year, rating, duration_min,
       popularity, description, cast_members, director, category_id,
       poster_path, type, seasons, episodes, status)
WebSeries(id, seasons, total_episodes, status)
Watchlist(id, user_id, movie_id, added_date)
Reviews(id, user_id, movie_id, rating, comment, created_at)
Watch_History(id, user_id, movie_id, watched_at, progress_percent)
Ratings(id, user_id, movie_id, stars, rated_at)
```

Underlined = PK (id in every table; WebSeries.id is PK + FK).
FKs: Movies.category_id -> Categories.id; WebSeries.id -> Movies.id;
Watchlist/Reviews/Watch_History/Ratings.user_id -> Users.id;
Watchlist/Reviews/Watch_History/Ratings.movie_id -> Movies.id.

## 4. ER-to-relational mapping rules applied

1. **Strong entity -> table.** Every entity type became a table with
   its PK (Users, Movies, Genres, Categories).
2. **1:N relationship -> FK on the N side.** Categories–Movies: the FK
   `Movies.category_id` sits on the Movies side. Same for every
   Users–bridge and Movies–bridge pair.
3. **M:N relationship -> bridge table.** Users–Movies became Watchlist,
   Reviews, Watch_History, Ratings — each with FKs to both parents
   plus the relationship's own attributes.
4. **1:1 relationship -> PK-as-FK.** Movies–WebSeries: WebSeries.id is
   both PK and FK to Movies.id (option 2 in the textbook: put the PK of
   one side as PK+FK of the other).
5. **Multivalued attribute -> separate table (not applied, noted).**
   `cast_members` should strictly be its own table; it is kept as a
   VARCHAR as a documented trade-off (see `05_normalization.md` §5).
6. **Specialization -> supertype + subtype tables.** Movies is the
   supertype table; WebSeries is the subtype table (EER option: one
   table per subtype, PK = supertype PK).

## 5. DFD — Data Flow Diagrams

### Level 0 (context diagram) — one process, two external entities

```
                +------------------+
                |   1.0 StreamSphere  |
  User  ------> |   Database System   | ------> MySQL Server
        <------ |  (MySQL database)   | <------
                +------------------+
  Admin ------> |                   | ------> MySQL Server
        <------ |                   | <------
```

- External entities: **User** (browses, searches, watchlists, rates)
  and **Admin** (manages movies/users/categories).
- The single process is the StreamSphere database system; the data
  store is the **MySQL Server (streamsphere database)**.
- Flows in: login credentials, search text, watchlist/review/rating
  data, admin add/delete/update commands.
- Flows out: movie lists, details, search results, watchlist, history,
  confirmations, admin tables.

### Level 1 — the single process decomposed

```
User --(credentials)--> [1.1 Register / Login] --(user row)--> Users
User --(title/genre/language)--> [1.2 Browse / Search] --(read)--> Movies, Genres, Categories
User --(movie choice)--> [1.3 Watchlist] --(write/read)--> Watchlist
User --(stars + comment)--> [1.4 Rate / Review] --(write)--> Reviews, Ratings
                          [1.4] --(recompute)--> Movies.rating  (trigger trg_after_review_insert)
User --(watch event)--> [1.5 Watch History] --(write)--> Watch_History
Admin --(add/delete/update)--> [1.6 Admin Manage] --(write)--> Movies, WebSeries, Genres, Categories, Users
[1.2] --(results)--> User
[1.3]/[1.4]/[1.5] --(confirmations + lists)--> User
[1.6] --(tables + totals)--> Admin
```

Processes: 1.1 Register/Login, 1.2 Browse/Search, 1.3 Watchlist,
1.4 Rate/Review, 1.5 Watch History, 1.6 Admin Manage. Data stores:
the 9 tables (Users, Movies, WebSeries, Genres, Categories,
Watchlist, Reviews, Watch_History, Ratings).

## 6. Use cases (actor: User / Admin)

| # | Use case | Actor | Main flow |
|---|---|---|---|
| UC1 | Register | User | Give name/email/password -> Users row created, password stored as SHA-256 hash. |
| UC2 | Login | User, Admin | Email + password -> hash compared with Users.password_hash; role decides the menu. |
| UC3 | Browse catalogue | User | List Movies, sorted by rating/year/popularity. |
| UC4 | Search movies | User | Search by title/genre/language (sp_search_movies). |
| UC5 | View movie details | User | One Movies row + its WebSeries row (if a series) + its Reviews. |
| UC6 | Add to watchlist | User | Insert Watchlist row; UNIQUE(user_id, movie_id) blocks duplicates. |
| UC7 | Rate and review | User | Insert Reviews + Ratings rows; trigger recomputes Movies.rating. |
| UC8 | View watch history | User | List Watch_History rows for the user, newest first. |
| UC9 | Manage movies | Admin | INSERT/UPDATE/DELETE Movies (+ WebSeries rows for series). |
| UC10 | Manage users & categories | Admin | INSERT/UPDATE/DELETE Users, Genres, Categories; view totals. |

## 7. Query optimisation notes

**Indexes.** The 9 B-tree indexes in `01_schema.sql` cover the columns
the queries actually filter, join and sort on: `Movies(title, genre,
rating, release_year, language)` and the FK columns
`Watchlist(user_id)`, `Watch_History(user_id)`, `Reviews(movie_id)`,
`Ratings(movie_id)`. A query such as `WHERE genre = 'Sci-Fi' ORDER BY
rating DESC` can use `idx_movies_genre` to find the rows and
`idx_movies_rating` for the ordering, instead of scanning all 15 rows
(and, at real scale, instead of scanning millions of rows).

**EXPLAIN.** Run `EXPLAIN SELECT ...` before and after adding an index
to see the change: `type: ALL` (full table scan) becomes
`type: ref` (index lookup), `rows` drops, and `Extra` stops saying
`Using filesort` when the index supplies the ORDER BY. Example:
`EXPLAIN SELECT title FROM Movies WHERE genre = 'Sci-Fi';`

**Query tree / cost-based optimisation (one paragraph).** MySQL parses
a query into a query tree (SELECT -> WHERE -> JOIN -> tables), then the
optimizer rewrites it (predicate push-down, join reordering) and picks
the cheapest execution plan using table statistics — row counts, index
cardinality and selectivity — not the order the tables were written in.
That is cost-based optimisation: for a join of Movies to Reviews, the
optimizer estimates the cost of "scan Movies, look up Reviews by
`idx_reviews_movie`" versus "scan Reviews, look up Movies by PK" and
chooses the cheaper one. This is why the right indexes matter more
than writing the query in a particular order, and why `ANALYZE TABLE`
(refreshing the statistics) can change a plan.
