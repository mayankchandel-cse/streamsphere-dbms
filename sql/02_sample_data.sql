-- ============================================================================
-- StreamSphere (DBMS-ONLY) — 02_sample_data.sql
-- Same titles / data as the original StreamSphere project, so the queries in
-- 03_queries.sql and the demos in 04_...sql return the same answers.
-- Run AFTER 01_schema.sql:   mysql -u root -p < sql/02_sample_data.sql
--
-- Passwords are stored as SHA-256 hashes, NEVER as plain text.
-- MySQL computes the hash itself with SHA2(password, 256):
--   admin@streamsphere.com / admin123
--     -> SHA2('admin123', 256) = 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
--   demo@streamsphere.com / demo123
--     -> SHA2('demo123', 256)  = d3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791
-- Change both passwords before any real deployment.
-- ============================================================================
USE streamsphere;

-- Genres (8)
INSERT INTO Genres (id, name, description) VALUES
(1, 'Sci-Fi',   'Science fiction and futuristic stories'),
(2, 'Drama',    'Character-driven emotional stories'),
(3, 'Thriller', 'Suspense, mystery and crime'),
(4, 'Comedy',   'Humour and light-hearted stories'),
(5, 'Action',   'High-energy action and adventure'),
(6, 'Romance',  'Love stories'),
(7, 'Horror',   'Horror and supernatural stories'),
(8, 'Crime',    'Crime and gangster stories')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Categories (3)
INSERT INTO Categories (id, name, description) VALUES
(1, 'Movies',        'Feature films'),
(2, 'Web Series',    'Multi-season series'),
(3, 'Documentaries', 'Documentary titles')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Users (3): admin + demo user + test user (SHA-256 hashed passwords)
INSERT INTO Users (id, name, email, password_hash, role) VALUES
(1, 'StreamSphere Admin', 'admin@streamsphere.com',
    SHA2('admin123', 256), 'ADMIN'),
(2, 'Demo User', 'demo@streamsphere.com',
    SHA2('demo123', 256), 'USER'),
(3, 'Test User', 'test@streamsphere.com',
    SHA2('test123', 256), 'USER')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Movies (12 films, ids 1-12)
INSERT INTO Movies (id, title, genre, language, release_year, rating,
                    duration_min, popularity, description, cast_members,
                    director, category_id, poster_path, type) VALUES
(1,  'The Silent Horizon',        'Sci-Fi',  'English', 2024, 9.1, 142, 98, 'A deep-space crew discovers a signal that should not exist.', 'R. Sharma, L. D''Souza', 'A. Kapoor',       1, NULL, 'Movie'),
(2,  'Monsoon Wedding Nights',    'Drama',   'Hindi',   2023, 8.7, 158, 91, 'Three generations collide over one rainy wedding weekend in Delhi.', 'A. Khan, M. Iyer', 'P. Nair',         1, NULL, 'Movie'),
(3,  'Code Red: Cyber Heist',     'Thriller','English', 2024, 8.4, 131, 95, 'An ethical hacker is framed for the biggest bank heist in history.', 'J. Carter, N. Rao', 'S. Menon',        1, NULL, 'Movie'),
(4,  'Laugh Riot',                'Comedy',  'Hindi',   2022, 7.9, 118, 84, 'A struggling stand-up comic becomes the voice of a whole city.', 'K. Verma, S. Bhatt', 'V. Joshi',        1, NULL, 'Movie'),
(5,  'The Last Samurai''s Son',   'Action',  'English', 2023, 8.9, 149, 93, 'A retired swordsman must protect the village that once exiled him.', 'K. Watanabe, E. Stone', 'H. Tanaka', 1, NULL, 'Movie'),
(6,  'Chai & Chocolates',         'Romance', 'Hindi',   2024, 8.1, 126, 88, 'Two rival cafe owners in Darjeeling discover some recipes only work together.', 'P. Singh, T. Roy', 'R. Das', 1, NULL, 'Movie'),
(7,  'Galaxy Quest: Reborn',      'Sci-Fi',  'English', 2025, 9.3, 155, 99, 'The crew of a cancelled TV show must save a real alien civilisation.', 'C. Evans, Z. Malik', 'D. O''Brien', 1, NULL, 'Movie'),
(8,  'The Haunted Library',       'Horror',  'English', 2023, 7.6, 104, 79, 'Every book in the old library rewrites itself at midnight.', 'A. Bose, R. Gill', 'M. Fernandes',    1, NULL, 'Movie'),
(9,  'Street Kings of Mumbai',    'Crime',   'Hindi',   2024, 8.8, 162, 94, 'Two brothers on opposite sides of the law fight for the same streets.', 'N. Siddiqui, D. Yadav', 'F. Qureshi', 1, NULL, 'Movie'),
(10, 'The Grand Budapest Heist',  'Comedy',  'English', 2022, 8.2, 121, 86, 'A concierge, a countess and a stolen painting.', 'O. Grant, L. Meyer', 'W. Adler',        1, NULL, 'Movie'),
(11, 'Baahubali: The Beginning',  'Action',  'Telugu',  2015, 8.0, 159, 90, 'A young man raised in a village discovers his royal destiny.', 'Prabhas, R. Rana', 'S. S. Rajamouli', 1, NULL, 'Movie'),
(12, 'Interstellar Echoes',       'Sci-Fi',  'English', 2025, 9.0, 169, 97, 'A message from the future gives humanity one last chance.', 'M. Chen, S. Patel', 'A. Kapoor',       1, NULL, 'Movie')
ON DUPLICATE KEY UPDATE title = VALUES(title);

-- Web series (3): stored in Movies with type = 'WebSeries' (ids 101-103),
-- plus the one-to-one WebSeries extension rows
INSERT INTO Movies (id, title, genre, language, release_year, rating,
                    duration_min, popularity, description, cast_members,
                    director, category_id, poster_path, type, seasons, episodes, status) VALUES
(101, 'The Crown of Shadows',   'Drama',    'English', 2024, 9.2, 45, 96, 'A secret society pulls the strings of a royal family.', 'H. Mirza, J. Cole', 'E. Clarke', 2, NULL, 'WebSeries', 3, 24, 'Ongoing'),
(102, 'Campus Diaries',         'Comedy',   'Hindi',   2023, 8.5, 35, 89, 'Four first-year students, one chaotic hostel.', 'A. Gupta, R. Jain', 'V. Joshi',  2, NULL, 'WebSeries', 2, 16, 'Completed'),
(103, 'Cyber Squad: Zero Day',  'Thriller', 'English', 2025, 8.9, 50, 92, 'A teenage hacking team races a rogue AI.', 'N. Rao, K. Lee', 'S. Menon', 2, NULL, 'WebSeries', 1, 8, 'Ongoing')
ON DUPLICATE KEY UPDATE title = VALUES(title);

INSERT INTO WebSeries (id, seasons, total_episodes, status) VALUES
(101, 3, 24, 'Ongoing'),
(102, 2, 16, 'Completed'),
(103, 1,  8, 'Ongoing')
ON DUPLICATE KEY UPDATE seasons = VALUES(seasons);

-- Watchlist (demo user, id 2)
INSERT INTO Watchlist (user_id, movie_id) VALUES
(2, 1), (2, 7), (2, 9)
ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);

-- Reviews (rating 1-5 stars)
INSERT INTO Reviews (user_id, movie_id, rating, comment) VALUES
(2, 1, 5, 'Brilliant sci-fi — the ending stayed with me for days.'),
(2, 7, 5, 'The best space adventure on StreamSphere.'),
(3, 9, 4, 'Gripping crime drama, superb performances.'),
(3, 2, 4, 'Warm, funny and beautifully shot.')
ON DUPLICATE KEY UPDATE comment = VALUES(comment);

-- Watch_History — no UNIQUE key: re-running this script adds these rows
-- again, which is correct behaviour for a history log (every watch is an event)
INSERT INTO Watch_History (user_id, movie_id, progress_percent) VALUES
(2, 7, 100), (2, 1, 100), (2, 3, 45);

-- Ratings (stars 1-5)
INSERT INTO Ratings (user_id, movie_id, stars) VALUES
(2, 1, 5), (2, 7, 5), (2, 3, 4), (3, 9, 4), (3, 2, 4)
ON DUPLICATE KEY UPDATE stars = VALUES(stars);

-- Verify:
--   SELECT COUNT(*) FROM Genres;       -- expect 8
--   SELECT COUNT(*) FROM Categories;   -- expect 3
--   SELECT COUNT(*) FROM Users;        -- expect 3
--   SELECT COUNT(*) FROM Movies;       -- expect 15 (12 films + 3 series)
--   SELECT COUNT(*) FROM Movies WHERE type = 'WebSeries';  -- expect 3
--   SELECT COUNT(*) FROM WebSeries;    -- expect 3
--   SELECT COUNT(*) FROM Watchlist;    -- expect 3
--   SELECT COUNT(*) FROM Reviews;      -- expect 4
--   SELECT COUNT(*) FROM Watch_History;-- expect 3 (+3 each re-run)
--   SELECT COUNT(*) FROM Ratings;      -- expect 5
