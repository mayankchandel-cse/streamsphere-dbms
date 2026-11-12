-- ============================================================================
-- StreamSphere (DBMS-ONLY) — 01_schema.sql
-- MySQL 8 / InnoDB. No Java, no Swing, no JDBC, no ADSA code in this project.
--
-- Run order:  01_schema.sql -> 02_sample_data.sql -> 03_queries.sql
--              -> 04_views_procedures_triggers_transactions.sql
--
-- Run with:  mysql -u root -p < sql/01_schema.sql
--   or in MySQL Workbench:  File -> Open SQL Script -> Execute.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS streamsphere
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE streamsphere;

-- Drop in reverse dependency order so the script is re-runnable.
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS Watch_History;
DROP TABLE IF EXISTS Reviews;
DROP TABLE IF EXISTS Watchlist;
DROP TABLE IF EXISTS WebSeries;
DROP TABLE IF EXISTS Movies;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Genres;

-- ----------------------------------------------------------------------------
-- 1. Genres — lookup table for genre names
--    PK: id.  Candidate key / alternate key: name (UNIQUE).
--    No FK.  No non-key attribute depends on another non-key attribute.
-- ----------------------------------------------------------------------------
CREATE TABLE Genres (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,   -- candidate key, alternate key
    description VARCHAR(255)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 2. Categories — e.g. Movies, Web Series, Documentaries
--    PK: id.  Candidate key / alternate key: name (UNIQUE).  No FK.
-- ----------------------------------------------------------------------------
CREATE TABLE Categories (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,   -- candidate key, alternate key
    description VARCHAR(255)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 3. Users — role-based access: 'ADMIN' or 'USER'
--    PK: id.  Candidate keys: id, email.  Alternate key: email (UNIQUE).
--    No FK.  password_hash is CHAR(64) = SHA-256 hex, never plain text.
-- ----------------------------------------------------------------------------
CREATE TABLE Users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,       -- alternate key
    password_hash CHAR(64) NOT NULL,                  -- SHA2(password, 256)
    role          ENUM('ADMIN', 'USER') NOT NULL DEFAULT 'USER',
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (email LIKE '%@%.%')
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 4. Movies — films AND web series (series have type = 'WebSeries')
--    PK: id.  Candidate keys: id; (title, release_year, language) is a
--    practical alternate key but is NOT declared UNIQUE (remakes exist).
--    FK: category_id -> Categories(id) ON UPDATE CASCADE, ON DELETE RESTRICT
--        (a category in use by a movie cannot be deleted).
--    genre is a VARCHAR (see docs/05_normalization.md for the trade-off);
--    Genres is the lookup table for its allowed values.
-- ----------------------------------------------------------------------------
CREATE TABLE Movies (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    title          VARCHAR(200) NOT NULL,
    genre          VARCHAR(50) NOT NULL,
    language       VARCHAR(50) NOT NULL DEFAULT 'English',
    release_year   INT NOT NULL,
    rating         DECIMAL(3,1) NOT NULL DEFAULT 0.0,  -- 0-10 scale
    duration_min   INT NOT NULL,
    popularity     INT NOT NULL DEFAULT 0,              -- 0-100
    description    TEXT,
    cast_members   VARCHAR(500),
    director       VARCHAR(100),
    category_id    INT NOT NULL DEFAULT 1,
    poster_path    VARCHAR(255),
    type           VARCHAR(20) NOT NULL DEFAULT 'Movie',
    seasons        INT,
    episodes       INT,
    status         VARCHAR(20),
    FOREIGN KEY (category_id) REFERENCES Categories(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (release_year BETWEEN 1900 AND 2030),
    CHECK (rating BETWEEN 0 AND 10),
    CHECK (popularity BETWEEN 0 AND 100),
    CHECK (duration_min > 0),
    CHECK (type IN ('Movie', 'WebSeries'))
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 5. WebSeries — series-specific data, one-to-one extension of Movies
--    PK: id, which is ALSO the FK: id -> Movies(id)
--        ON UPDATE CASCADE, ON DELETE CASCADE (deleting the movie deletes
--        its series row).  Candidate key: id only (1:1 relationship).
-- ----------------------------------------------------------------------------
CREATE TABLE WebSeries (
    id             INT PRIMARY KEY,   -- PK = FK to Movies.id
    seasons        INT NOT NULL DEFAULT 1,
    total_episodes INT NOT NULL DEFAULT 1,
    status         VARCHAR(20) NOT NULL DEFAULT 'Ongoing',
    FOREIGN KEY (id) REFERENCES Movies(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (seasons > 0),
    CHECK (total_episodes > 0)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 6. Watchlist — many-to-many bridge: Users <-> Movies
--    PK: id (surrogate).  Candidate keys: id, (user_id, movie_id) (UNIQUE).
--    FK: user_id  -> Users(id)  ON UPDATE CASCADE, ON DELETE CASCADE
--    FK: movie_id -> Movies(id) ON UPDATE CASCADE, ON DELETE CASCADE
-- ----------------------------------------------------------------------------
CREATE TABLE Watchlist (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    movie_id   INT NOT NULL,
    added_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES Users(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE (user_id, movie_id)   -- a user can save a movie only once
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 7. Reviews — one review per user per movie; rating 1-5 stars
--    PK: id (surrogate).  Candidate keys: id, (user_id, movie_id) (UNIQUE).
--    FK: user_id  -> Users(id)  ON UPDATE CASCADE, ON DELETE CASCADE
--    FK: movie_id -> Movies(id) ON UPDATE CASCADE, ON DELETE CASCADE
-- ----------------------------------------------------------------------------
CREATE TABLE Reviews (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    movie_id   INT NOT NULL,
    rating     INT NOT NULL,   -- 1-5 stars (see note in 04: x2 = 0-10 scale)
    comment    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES Users(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE (user_id, movie_id),
    CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 8. Watch_History — every watch is an event (no UNIQUE key: a user may
--    re-watch a movie, and each watch is a separate row)
--    PK: id.  Candidate key: id only.
--    FK: user_id  -> Users(id)  ON UPDATE CASCADE, ON DELETE CASCADE
--    FK: movie_id -> Movies(id) ON UPDATE CASCADE, ON DELETE CASCADE
-- ----------------------------------------------------------------------------
CREATE TABLE Watch_History (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    movie_id         INT NOT NULL,
    watched_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    progress_percent INT NOT NULL DEFAULT 0,
    FOREIGN KEY (user_id)  REFERENCES Users(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (progress_percent BETWEEN 0 AND 100)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 9. Ratings — every star-rating event (including rating-only submissions)
--    PK: id (surrogate).  Candidate keys: id, (user_id, movie_id) (UNIQUE).
--    FK: user_id  -> Users(id)  ON UPDATE CASCADE, ON DELETE CASCADE
--    FK: movie_id -> Movies(id) ON UPDATE CASCADE, ON DELETE CASCADE
-- ----------------------------------------------------------------------------
CREATE TABLE Ratings (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id  INT NOT NULL,
    movie_id INT NOT NULL,
    stars    INT NOT NULL,   -- 1-5 stars
    rated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES Users(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE (user_id, movie_id),
    CHECK (stars BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ============================================================================
-- Indexes — query processing & optimisation (9 indexes)
-- B-tree indexes (InnoDB default). Used by the WHERE / JOIN / ORDER BY
-- columns in sql/03_queries.sql; check with EXPLAIN (see docs/06_design.md).
-- ============================================================================
CREATE INDEX idx_movies_title    ON Movies(title);
CREATE INDEX idx_movies_genre    ON Movies(genre);
CREATE INDEX idx_movies_rating   ON Movies(rating);
CREATE INDEX idx_movies_year     ON Movies(release_year);
CREATE INDEX idx_movies_language ON Movies(language);
CREATE INDEX idx_watchlist_user  ON Watchlist(user_id);
CREATE INDEX idx_history_user    ON Watch_History(user_id);
CREATE INDEX idx_reviews_movie   ON Reviews(movie_id);
CREATE INDEX idx_ratings_movie   ON Ratings(movie_id);

-- Verify:
--   SHOW TABLES;            -- expect 9 tables
--   SHOW CREATE TABLE Movies\G
--   SELECT COUNT(*) FROM information_schema.TABLES
--     WHERE TABLE_SCHEMA = 'streamsphere';   -- expect 9
