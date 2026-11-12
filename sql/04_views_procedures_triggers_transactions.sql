-- ============================================================================
-- StreamSphere (DBMS-ONLY) — 04_views_procedures_triggers_transactions.sql
-- Views, stored procedures, a trigger, transactions and role-based security.
-- Run AFTER 01 + 02:   mysql -u root -p < sql/04_views_procedures_triggers_transactions.sql
-- NOTE: the CREATE USER / GRANT section needs a MySQL root (or admin) login.
-- ============================================================================
USE streamsphere;

-- ============================================================================
-- 1. VIEWS — virtual tables: no data is stored, the query runs on each use
-- ============================================================================

-- VIEW 1: top-rated titles (rating 8.5 or above), with category name.
CREATE OR REPLACE VIEW vw_top_rated AS
SELECT m.id, m.title, m.genre, m.language, m.release_year, m.rating,
       c.name AS category
FROM Movies m
INNER JOIN Categories c ON m.category_id = c.id
WHERE m.rating >= 8.5
ORDER BY m.rating DESC;

-- VIEW 2: every user's watchlist, with user name and movie title.
CREATE OR REPLACE VIEW vw_user_watchlist AS
SELECT u.id AS user_id, u.name AS user_name, u.email,
       m.id AS movie_id, m.title, m.genre, m.rating, w.added_date
FROM Users u
INNER JOIN Watchlist w ON u.id = w.user_id
INNER JOIN Movies m ON w.movie_id = m.id;

-- VIEW 3: per-genre statistics (count, average rating, best rating).
CREATE OR REPLACE VIEW vw_genre_stats AS
SELECT genre,
       COUNT(*) AS title_count,
       ROUND(AVG(rating), 2) AS avg_rating,
       MAX(rating) AS best_rating
FROM Movies
GROUP BY genre;

-- Try them:
--   SELECT * FROM vw_top_rated;
--   SELECT * FROM vw_user_watchlist WHERE email = 'demo@streamsphere.com';
--   SELECT * FROM vw_genre_stats ORDER BY avg_rating DESC;

-- ============================================================================
-- 2. STORED PROCEDURES
-- ============================================================================
DELIMITER //

-- PROCEDURE 1: search movies by a title/genre/language pattern.
--   CALL sp_search_movies('Cyber');
--   CALL sp_search_movies('Sci%');
CREATE PROCEDURE sp_search_movies(IN p_pattern VARCHAR(200))
BEGIN
    SELECT id, title, genre, language, release_year, rating
    FROM Movies
    WHERE title    LIKE CONCAT('%', p_pattern, '%')
       OR genre    LIKE CONCAT('%', p_pattern, '%')
       OR language LIKE CONCAT('%', p_pattern, '%')
    ORDER BY rating DESC;
END //

-- PROCEDURE 2: add a review (and the matching Ratings row) for a user/movie.
--   The UNIQUE(user_id, movie_id) keys make a second call for the same
--   pair update the existing review instead of failing.
--   CALL sp_add_review(2, 5, 5, 'Superb action.');
CREATE PROCEDURE sp_add_review(
    IN p_user_id  INT,
    IN p_movie_id INT,
    IN p_rating   INT,
    IN p_comment  TEXT)
BEGIN
    INSERT INTO Reviews (user_id, movie_id, rating, comment)
    VALUES (p_user_id, p_movie_id, p_rating, p_comment)
    ON DUPLICATE KEY UPDATE
        rating = VALUES(rating), comment = VALUES(comment);
    INSERT INTO Ratings (user_id, movie_id, stars)
    VALUES (p_user_id, p_movie_id, p_rating)
    ON DUPLICATE KEY UPDATE
        stars = VALUES(stars);
    -- Movies.rating is recomputed by trg_after_review_insert (below).
END //

DELIMITER ;

-- ============================================================================
-- 3. TRIGGER — keep Movies.rating in sync with Reviews automatically
-- ============================================================================
DELIMITER //

-- After a review is inserted, recompute that movie's rating from the
-- average of its Reviews.
-- SCALE NOTE (honest): Reviews.rating is 1-5 stars, Movies.rating is
-- 0-10. The trigger multiplies the average by 2 (5 stars -> 10.0).
-- The alternative used in the original project's example query was
-- AVG(rating) with no multiplier, which would cap a movie at 5.0 — a
-- real scale bug. Multiplying by 2 keeps the 0-10 scale correct.
-- A movie with no reviews keeps its sample-data rating (COALESCE guard
-- is not needed here: AFTER INSERT, at least one review exists).
CREATE TRIGGER trg_after_review_insert
AFTER INSERT ON Reviews
FOR EACH ROW
BEGIN
    UPDATE Movies
    SET rating = (SELECT AVG(rating) * 2 FROM Reviews
                  WHERE movie_id = NEW.movie_id)
    WHERE id = NEW.movie_id;
END //

DELIMITER ;

-- Test the trigger (then undo it — see the transaction section below):
--   INSERT INTO Reviews (user_id, movie_id, rating, comment)
--     VALUES (3, 7, 4, 'Great fun.');
--   SELECT title, rating FROM Movies WHERE id = 7;
--     -- rating changes from 9.3 to (5+4)/2 * 2 = 9.0
--   DELETE FROM Reviews WHERE user_id = 3 AND movie_id = 7;
--   UPDATE Movies SET rating = 9.3 WHERE id = 7;

-- ============================================================================
-- 4. TRANSACTIONS — ACID: add a review + rating atomically
--    Either ALL of the writes happen, or NONE of them do.
-- ============================================================================

-- Example A: a transaction that COMMITS.
--   (Uses movie 5, user 2 — not in the sample Reviews/Ratings, so it
--    inserts cleanly. The trigger above also fires and recomputes the rating.)
START TRANSACTION;
    INSERT INTO Reviews (user_id, movie_id, rating, comment)
      VALUES (2, 5, 5, 'Superb action.');
    INSERT INTO Ratings (user_id, movie_id, stars)
      VALUES (2, 5, 5);
COMMIT;
-- Verify: SELECT * FROM Reviews WHERE user_id = 2 AND movie_id = 5;
--         SELECT title, rating FROM Movies WHERE id = 5;  -- now 10.0

-- Example B: a transaction with a SAVEPOINT, rolled back part-way.
--   The review is kept, the (deliberately wrong) rating insert is undone.
START TRANSACTION;
    INSERT INTO Reviews (user_id, movie_id, rating, comment)
      VALUES (3, 5, 4, 'Good, not great.');
    SAVEPOINT after_review;
    INSERT INTO Ratings (user_id, movie_id, stars)
      VALUES (3, 5, 4);
    -- Oops — wrong user/movie combination: undo only the last statement.
    ROLLBACK TO SAVEPOINT after_review;
    RELEASE SAVEPOINT after_review;
COMMIT;
-- Verify: the review (3, 5) exists, the Ratings row (3, 5) does not.
--   SELECT * FROM Reviews WHERE user_id = 3 AND movie_id = 5;
--   SELECT * FROM Ratings WHERE user_id = 3 AND movie_id = 5;  -- empty

-- Example C: a full ROLLBACK (nothing is saved). Run it, then check that
--   no row was added. (Commented out so re-running this file is safe.)
-- START TRANSACTION;
--     INSERT INTO Reviews (user_id, movie_id, rating, comment)
--       VALUES (2, 6, 1, 'This review will never be saved.');
-- ROLLBACK;
-- SELECT * FROM Reviews WHERE user_id = 2 AND movie_id = 6;  -- empty

-- Clean up the rows Example A/B added, so the sample data stays as in 02:
--   (uncomment to run)
-- DELETE FROM Reviews WHERE (user_id, movie_id) IN ((2, 5), (3, 5));
-- DELETE FROM Ratings WHERE (user_id, movie_id) IN ((2, 5), (3, 5));
-- UPDATE Movies SET rating = 8.9 WHERE id = 5;

-- ============================================================================
-- 5. DATABASE SECURITY — role-based access control
--    Two MySQL users, least privilege: the app user can read everything and
--    write only its own tables; the admin user can write the catalogue.
--    These are MySQL server accounts — different from the Users table rows.
--    App passwords in the Users table are SHA-256 hashes (SHA2(..., 256)),
--    NEVER plain text. MySQL account passwords below are only examples:
--    change them before any real deployment.
-- ============================================================================

CREATE USER IF NOT EXISTS 'app_user'@'localhost'  IDENTIFIED BY 'AppUser@123';
CREATE USER IF NOT EXISTS 'app_admin'@'localhost' IDENTIFIED BY 'AppAdmin@123';

-- app_user: read the catalogue, write only watchlist / reviews / ratings /
-- watch history (the things a normal user does).
GRANT SELECT ON streamsphere.Movies TO 'app_user'@'localhost';
GRANT SELECT ON streamsphere.Genres TO 'app_user'@'localhost';
GRANT SELECT ON streamsphere.Categories TO 'app_user'@'localhost';
GRANT SELECT ON streamsphere.WebSeries TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Watchlist TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Reviews TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Ratings TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON streamsphere.Watch_History TO 'app_user'@'localhost';
GRANT SELECT ON streamsphere.Users TO 'app_user'@'localhost';

-- app_admin: everything app_user has, plus managing movies, genres,
-- categories and users.
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Movies TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Genres TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Categories TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.WebSeries TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Users TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Watchlist TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Reviews TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Ratings TO 'app_admin'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON streamsphere.Watch_History TO 'app_admin'@'localhost';

-- REVOKE example: take DELETE away from the app user on Reviews
-- (a normal user may edit their review, but not delete other data).
REVOKE DELETE ON streamsphere.Reviews FROM 'app_user'@'localhost';

FLUSH PRIVILEGES;

-- Verify:
--   SHOW GRANTS FOR 'app_user'@'localhost';
--   SHOW GRANTS FOR 'app_admin'@'localhost';
--   -- log in as the app user and confirm a forbidden write fails:
--   --   mysql -u app_user -p streamsphere
--   --   DELETE FROM Movies WHERE id = 1;   -- ERROR 1142: DELETE denied
