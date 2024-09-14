--Total titles
SELECT COUNT(title) FROM netflix_stg;

--Total Genre
SELECT COUNT(DISTINCT genre) FROM netflix_genre;

--Total Directors
SELECT COUNT(director) FROM netflix_directors;

--Total Countries
SELECT COUNT(country) FROM netflix_countries;

--Latest Release Year
SELECT MAX(release_year) FROM netflix_stg;

--Lasted Release Year
SELECT MIN(release_year) FROM netflix_stg;

--Count of show ids in different counrties
SELECT country,COUNT(show_id) FROM netflix_countries
GROUP BY country ORDER BY COUNT(show_id) DESC;

--Movies vs shows
SELECT COUNT(CASE WHEN type='Movie' THEN show_id END) AS num_movies,
COUNT(CASE WHEN type='TV Show' THEN show_id END) AS num_shows
FROM netflix_stg;


--Shows by rating
SELECT rating,
COUNT(CASE WHEN type='Movie' THEN show_id END) AS Movies,
COUNT(CASE WHEN type='TV Show' THEN show_id END) AS 'TV Shows'
FROM netflix_stg
GROUP BY rating ORDER BY COUNT(show_id) DESC;

