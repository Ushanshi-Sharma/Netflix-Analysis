-- ---------------------------------- SQL+ PYTHON + POWER BI PROJECT ON NETFLIX -----------------------------------
USE netflix;

SELECT * FROM netflix_titles;

SELECT count(*) FROM netflix_titles; -- LOADED DATA FROM PYTHON

-- ------------ DATA CLEANING ---------------------------------------
-- --------- Checking and removing duplicates -----------------------
SET SQL_SAFE_UPDATES = 0;

SELECT * 
FROM NETFLIX_TITLES
WHERE (UPPER(TITLE), TYPE, COUNTRY) IN (
    SELECT TITLE, TYPE, COUNTRY
    FROM NETFLIX_TITLES
    GROUP BY TITLE, TYPE, COUNTRY
    HAVING COUNT(*) > 1)
ORDER BY UPPER(TITLE);

WITH cte AS (
    SELECT *, 
           ROW_NUMBER() OVER(PARTITION BY TITLE, TYPE, COUNTRY ORDER BY SHOW_ID) AS rn
    FROM NETFLIX_TITLES)
DELETE FROM NETFLIX_TITLES
WHERE SHOW_ID IN (
    SELECT SHOW_ID 
    FROM cte 
    WHERE rn > 1);

-- ------------- --	creating new table for comma seperated directors -----------------------------------------------------
-- --------------- created files in python and imported in sql [source_id,director] [source_id,country] [source_id,cast] ------

--  ---------------- Datatype conversion for Date column ------------------------
ALTER TABLE netflix_titles ADD COLUMN date_added_new DATE;

UPDATE netflix_titles 
SET date_added_new = 
    CASE
        WHEN date_added IS NULL OR date_added = '' THEN NULL
        ELSE STR_TO_DATE(date_added, '%M %d, %Y')
    END;


ALTER TABLE netflix_titles 
DROP COLUMN date_added;

ALTER TABLE netflix_titles 
CHANGE COLUMN date_added_new date_added DATE;

-- ---------------- Making a new table with necessary columns only ---------------------

CREATE TABLE netflix;
ALTER TABLE netflix
DROP COLUMN director,
DROP COLUMN cast,
DROP COLUMN country,
DROP COLUMN listed_in;
SELECT * FROM netflix;

-- ------------------------ HANDLING NULL VALUES ----------------------------------------
-- ------ COUNTRY NULL VALUES -----------------
DELETE FROM netflix_country
WHERE country = "";

INSERT INTO netflix_country(
SELECT show_id, m.country 
FROM netflix_titles nt
JOIN (SELECT director,country
FROM netflix_country nc
JOIN netflix_directors nd 
ON nd.show_id = nc.show_id
GROUP BY director,country) m 
ON nt.director = m.director
WHERE nt.country = "");

-- -----------------	HANDLING DURATION NULL VALUES ---------------------------------
SELECT * FROM netflix
WHERE duration = ""; -- -- Here we found out that wherever duration is null the value is in "rating column" 

UPDATE netflix
SET duration = CASE 
					WHEN duration = "" THEN rating
                    Else duration
                    END;
				
SELECT * FROM netflix;

-- ----------------------------		 NETFLIX DATA ANALYSIS 	-------------------------
SELECT * FROM netflix;


-- 1) for each director count the no of movies and tv shows created by them in separate columns for directors who have created tv shows and movies both 
SELECT d.DIRECTOR,
       COUNT(CASE WHEN n.TYPE = "Movie" THEN n.SHOW_ID END) AS NO_OF_MOVIES,
       COUNT(CASE WHEN n.TYPE = "TV Show" THEN n.SHOW_ID END) AS NO_OF_SHOWS
FROM NETFLIX_DIRECTORS d
JOIN NETFLIX n
ON d.SHOW_ID = n.SHOW_ID
GROUP BY d.DIRECTOR
HAVING COUNT(DISTINCT n.TYPE) > 1;



-- 2) which country has highest number of comedy Movies
SELECT * 
FROM NETFLIX
WHERE DATE_ADDED LIKE "2020-%";

SELECT DISTINCT c.COUNTRY, COUNT(*) as Count
FROM NETFLIX_COUNTRY AS c
JOIN NETFLIX_GENRE AS g
ON g.SHOW_ID = c.SHOW_ID
JOIN NETFLIX AS n
ON n.SHOW_ID = c.SHOW_ID
WHERE g.LISTED_IN = "comedies" AND n.TYPE = "Movie"
GROUP BY c.COUNTRY
ORDER BY COUNT(*) DESC
LIMIT 1;


-- 3) for each year (as per release year), which country has maximum number of movies released
WITH cte AS (
    SELECT release_year AS year, 
           c.country, 
           COUNT(c.country) AS cnt, 
           ROW_NUMBER() OVER(PARTITION BY release_year ORDER BY COUNT(c.country) DESC) AS rn
    FROM netflix n
    LEFT JOIN netflix_country c
    ON n.show_id = c.show_id
    WHERE c.country IS NOT NULL 
    GROUP BY release_year, c.country)
    
SELECT year, country, cnt
FROM cte
WHERE rn = 1;


-- 4) what is average duration of movies in each genre

WITH cte AS (SELECT *, REPLACE(duration , " min", "") AS duration_int
FROM netflix
WHERE TYPE = "Movie")

SELECT ng.listed_in  AS genre, ROUND(AVG(c.duration_int),2) AS avg_duartion
FROM netflix_genre ng
JOIN cte c
ON ng.show_id = c.show_id
WHERE c.TYPE = "Movie"
GROUP BY ng.listed_in
ORDER BY avg_duartion DESC;


-- 5)  find the list of directors who have created International Movies and comedy movies both.
-- display director names along with number of comedy and horror movies directed by them 

SELECT nd.director
FROM netflix_directors nd
JOIN netflix_genre ng ON nd.show_id = ng.show_id
JOIN netflix n ON nd.show_id = n.show_id
WHERE n.TYPE = "Movie"
AND ng.listed_in IN ("International Movies" , "comedies")
GROUP BY nd.director
HAVING COUNT(DISTINCT ng.listed_in) > 1
