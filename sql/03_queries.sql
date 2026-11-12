-- ============================================================================
-- StreamSphere (DBMS-ONLY) — 03_queries.sql
-- 30 numbered queries, grouped (a)-(f). Run after 01 + 02.
--   mysql -u root -p < sql/03_queries.sql
--   or run them one at a time in MySQL Workbench.
-- Every query references only the 9 tables in 01_schema.sql.
-- ============================================================================
USE streamsphere;

-- ----------------------------------------------------------------------------
-- (a) SELECT / WHERE / ORDER BY / LIMIT
-- ----------------------------------------------------------------------------

-- Q1. All movies, highest rated first.
SELECT id, title, genre, language, release_year, rating
FROM Movies
ORDER BY rating DESC;

-- Q2. Sci-Fi movies only, newest first.
SELECT title, release_year, rating
FROM Movies
WHERE genre = 'Sci-Fi'
ORDER BY release_year DESC;

-- Q3. Top 5 most popular titles.
SELECT title, popularity, rating
FROM Movies
ORDER BY popularity DESC
LIMIT 5;

-- Q4. Hindi-language titles released in or after 2023.
SELECT title, language, release_year
FROM Movies
WHERE language = 'Hindi' AND release_year >= 2023
ORDER BY title;

-- Q5. Web series only (the Movies rows of type 'WebSeries').
SELECT title, genre, seasons, episodes, status
FROM Movies
WHERE type = 'WebSeries'
ORDER BY rating DESC;

-- Q6. Movies with a rating of 9.0 or above.
SELECT title, rating, release_year
FROM Movies
WHERE rating >= 9.0
ORDER BY rating DESC, title;

-- ----------------------------------------------------------------------------
-- (b) Aggregates + GROUP BY + HAVING
-- ----------------------------------------------------------------------------

-- Q7. Totals: how many titles, average rating, highest rating.
SELECT COUNT(*) AS total_titles,
       ROUND(AVG(rating), 2) AS avg_rating,
       MAX(rating) AS best_rating,
       MIN(rating) AS lowest_rating
FROM Movies;

-- Q8. Average rating and title count per genre.
SELECT genre,
       COUNT(*) AS movie_count,
       ROUND(AVG(rating), 2) AS avg_rating
FROM Movies
GROUP BY genre
ORDER BY avg_rating DESC;

-- Q9. Genres with more than one title (HAVING filters groups, not rows).
SELECT genre, COUNT(*) AS movie_count
FROM Movies
GROUP BY genre
HAVING COUNT(*) > 1
ORDER BY movie_count DESC;

-- Q10. Average rating and count per language, only for languages
--      whose average rating is above 8.5.
SELECT language,
       COUNT(*) AS movie_count,
       ROUND(AVG(rating), 2) AS avg_rating
FROM Movies
GROUP BY language
HAVING AVG(rating) > 8.5;

-- Q11. Average stars given per movie (from Ratings), with review count.
SELECT movie_id,
       COUNT(*) AS rating_count,
       ROUND(AVG(stars), 2) AS avg_stars
FROM Ratings
GROUP BY movie_id
ORDER BY avg_stars DESC;

-- Q12. How many movies each user has watched (Watch_History).
SELECT user_id, COUNT(*) AS watches,
       SUM(CASE WHEN progress_percent = 100 THEN 1 ELSE 0 END) AS finished
FROM Watch_History
GROUP BY user_id;

-- ----------------------------------------------------------------------------
-- (c) JOINs — INNER, LEFT, RIGHT, self-join
-- ----------------------------------------------------------------------------

-- Q13. INNER JOIN: movies with their category name.
SELECT m.title, m.genre, c.name AS category, m.rating
FROM Movies m
INNER JOIN Categories c ON m.category_id = c.id
ORDER BY m.rating DESC;

-- Q14. INNER JOIN (3 tables): demo user's watchlist with titles.
SELECT u.name AS user_name, m.title, m.genre, w.added_date
FROM Users u
INNER JOIN Watchlist w ON u.id = w.user_id
INNER JOIN Movies m ON w.movie_id = m.id
WHERE u.email = 'demo@streamsphere.com'
ORDER BY w.added_date;

-- Q15. LEFT JOIN: all users and their watchlist titles (users with an
--      empty watchlist still appear, with NULL title).
SELECT u.name, m.title
FROM Users u
LEFT JOIN Watchlist w ON u.id = w.user_id
LEFT JOIN Movies m ON w.movie_id = m.id
ORDER BY u.name, m.title;

-- Q16. LEFT JOIN: all movies and their reviews (unreviewed movies appear
--      with NULL rating/comment).
SELECT m.title, r.rating, r.comment
FROM Movies m
LEFT JOIN Reviews r ON r.movie_id = m.id
ORDER BY m.title;

-- Q17. RIGHT JOIN: all movies and any reviews they have (same rows as Q16
--      from the other side — every movie appears, reviewed or not).
SELECT m.title, r.rating, r.comment
FROM Reviews r
RIGHT JOIN Movies m ON r.movie_id = m.id
ORDER BY m.title;

-- Q18. Self-join: pairs of movies in the SAME genre (each pair once,
--      a movie is never paired with itself).
SELECT a.title AS movie_1, b.title AS movie_2, a.genre
FROM Movies a
INNER JOIN Movies b
        ON a.genre = b.genre
       AND a.id < b.id
ORDER BY a.genre, a.title, b.title;

-- Q19. INNER JOIN with WebSeries: series titles with their series data.
SELECT m.title, m.genre, w.seasons, w.total_episodes, w.status
FROM Movies m
INNER JOIN WebSeries w ON m.id = w.id
ORDER BY m.rating DESC;

-- ----------------------------------------------------------------------------
-- (d) Subqueries — scalar, IN, EXISTS, correlated
-- ----------------------------------------------------------------------------

-- Q20. Scalar subquery: movies rated above the overall average rating.
SELECT title, rating
FROM Movies
WHERE rating > (SELECT AVG(rating) FROM Movies)
ORDER BY rating DESC;

-- Q21. IN subquery: movies the demo user has in their watchlist.
SELECT title, genre, rating
FROM Movies
WHERE id IN (SELECT movie_id FROM Watchlist
             WHERE user_id = (SELECT id FROM Users
                              WHERE email = 'demo@streamsphere.com'))
ORDER BY rating DESC;

-- Q22. EXISTS subquery: movies that have at least one review.
SELECT title, rating
FROM Movies m
WHERE EXISTS (SELECT 1 FROM Reviews r WHERE r.movie_id = m.id)
ORDER BY rating DESC;

-- Q23. Correlated subquery: for each movie, its review count.
--      (The subquery runs once per row of the outer query.)
SELECT m.title,
       (SELECT COUNT(*) FROM Reviews r WHERE r.movie_id = m.id) AS review_count
FROM Movies m
ORDER BY review_count DESC, m.rating DESC;

-- Q24. Correlated subquery: movies whose rating is above their own
--      genre's average rating.
SELECT m.title, m.genre, m.rating
FROM Movies m
WHERE m.rating > (SELECT AVG(m2.rating) FROM Movies m2
                  WHERE m2.genre = m.genre)
ORDER BY m.genre, m.rating DESC;

-- Q25. IN subquery with an aggregate: the highest-rated movie(s) overall.
SELECT title, rating
FROM Movies
WHERE rating IN (SELECT MAX(rating) FROM Movies);

-- ----------------------------------------------------------------------------
-- (e) UPDATE / DELETE with WHERE  (run these LAST — they change the data;
--      re-run 02_sample_data.sql to restore the sample rows)
-- ----------------------------------------------------------------------------

-- Q26. UPDATE: raise the popularity of 'Galaxy Quest: Reborn' to 100.
UPDATE Movies
SET popularity = 100
WHERE title = 'Galaxy Quest: Reborn';

-- Q27. UPDATE with a subquery: set every movie's rating to the average of
--      its Reviews (x2: reviews are 1-5 stars, Movies.rating is 0-10).
--      Movies with no reviews keep their current rating.
UPDATE Movies m
SET rating = (SELECT AVG(r.rating) * 2 FROM Reviews r
              WHERE r.movie_id = m.id)
WHERE EXISTS (SELECT 1 FROM Reviews r WHERE r.movie_id = m.id);

-- Q28. DELETE: remove one watchlist row (demo user, movie id 9).
DELETE FROM Watchlist
WHERE user_id = 2 AND movie_id = 9;

-- Q29. DELETE with a subquery: remove history rows for movies that no
--      longer exist is impossible (FK prevents it) — instead delete the
--      unfinished watches (progress < 100) of the demo user.
DELETE FROM Watch_History
WHERE user_id = 2 AND progress_percent < 100;

-- ----------------------------------------------------------------------------
-- (f) UNION, DISTINCT, LIKE, BETWEEN, IN
-- ----------------------------------------------------------------------------

-- Q30. UNION + DISTINCT + LIKE + BETWEEN + IN, in one query:
--      distinct genres of English/Hindi titles whose title contains
--      'The' or 'Cyber', released between 2023 and 2025.
--      (UNION removes duplicates across the two SELECTs; DISTINCT is
--      shown explicitly in the second branch.)
SELECT DISTINCT genre
FROM Movies
WHERE (title LIKE '%The%' OR title LIKE '%Cyber%')
  AND release_year BETWEEN 2023 AND 2025
  AND language IN ('English', 'Hindi')
UNION
SELECT DISTINCT genre
FROM Movies
WHERE genre IN ('Sci-Fi', 'Thriller')
  AND release_year BETWEEN 2023 AND 2025;

-- Extra check (not counted in the 30): DISTINCT languages in the catalogue.
-- SELECT DISTINCT language FROM Movies ORDER BY language;
