--Create Database
CREATE DATABASE netflix;
--Use the created database
USE netflix;
SELECT * FROM netflix_titles order by title;
SELECT * FROM netflix_titles WHERE show_id='s8766';
SELECT COUNT(*) FROM netflix_titles;

--1. Handle Foreign Characters
--Create table inside the created database
CREATE TABLE [dbo].[netflix_titles](
	[show_id] [varchar](10) primary key,
	[type] [varchar](10) NULL,
	[title] [NVARCHAR](1000) NULL,
	[director] [varchar](300) NULL,
	[cast] [varchar](1000) NULL,
	[country] [varchar](150) NULL,
	[date_added] [varchar](20) NULL,
	[release_year] [int] NULL,
	[rating] [varchar](10) NULL,
	[duration] [varchar](10) NULL,
	[listed_in] [varchar](100) NULL,
	[description] [varchar](500) NULL
);
--to check the datatype of columns
sp_help 'netflix_titles';

--2. Remove Duplicates
SELECT show_id,COUNT(*) from netflix_titles
GROUP BY show_id HAVING COUNT(*)>1;
--AS there are no duplicates so we set show_id as PK

--Now there are duplicate title,type
SELECT * FROM netflix_titles WHERE CONCAT(title,type) IN (
SELECT CONCAT(title,type) FROM netflix_titles
GROUP BY CONCAT(title,type) HAVING COUNT(*)>1) ORDER BY title;

--Now Handle Duplicates
WITH cte AS (SELECT *,ROW_NUMBER() OVER (PARTITION BY type,title ORDER BY show_id) AS rn FROM netflix_titles)
SELECT *FROM cte WHERE rn=1;



--3. New Table for listed-in,director,country,cast
SELECT show_id,trim(value) AS director
INTO netflix_directors
FROM netflix_titles
CROSS APPLY string_split(director,',');

SELECT *FROM netflix_directors;

SELECT show_id,trim(value) AS cast
INTO netflix_casts
FROM netflix_titles
CROSS APPLY string_split(cast,',');

SELECT *FROM netflix_casts;


SELECT show_id,trim(value) AS Country
INTO netflix_countries 
FROM netflix_titles 
CROSS APPLY STRING_SPLIT(country,',');

SELECT *from netflix_countries;

SELECT show_id,trim(value) AS genre
INTO netflix_genre
FROM netflix_titles
CROSS APPLY STRING_SPLIT(listed_in,',');

SELECT *FROM netflix_genre;

--4. Data type conversions for date added
WITH cte AS (SELECT *,ROW_NUMBER() OVER (PARTITION BY type,title ORDER BY show_id) AS rn FROM netflix_titles)
SELECT show_id,type,title,cast(date_added AS DATE),release_year,rating,duration,description FROM cte WHERE rn=1;

--5.Populate missing values in country
INSERT INTO netflix_countries
SELECT show_id,m.country FROM netflix_titles nt INNER JOIN
(SELECT director,country FROM netflix_countries nc
INNER JOIN netflix_directors nd ON nc.show_id=nd.show_id
GROUP BY director,country) m
ON nt.director=m.director
WHERE nt.country is null;

--Populate missing values in duration
SELECT *FROM netflix_titles WHERE duration IS NULL;

WITH cte AS (SELECT *,ROW_NUMBER() OVER (PARTITION BY type,title ORDER BY show_id) AS rn FROM netflix_titles)
SELECT show_id,type,title,
cast(date_added AS DATE),release_year,rating,
CASE WHEN duration IS NULL THEN rating ELSE duration END AS duration,description FROM cte WHERE rn=1;


--Now create a final table
WITH cte AS (SELECT *,ROW_NUMBER() OVER (PARTITION BY type,title ORDER BY show_id) AS rn FROM netflix_titles)
SELECT show_id,type,title,
CAST(date_added AS DATE) AS date_added,release_year,rating,
CASE WHEN duration IS NULL THEN rating ELSE duration END AS duration,description
INTO netflix_stg
FROM cte WHERE rn=1;

SELECT *FROM netflix_stg;
SELECT *FROM netflix_genre;
SELECT *FROM netflix_directors;
SELECT *FROM netflix_countries;
SELECT *FROM netflix_casts;
SELECT *FROM netflix_titles;

--NETFLIX DATA ANALYSIS
/*1. For each director count the no of movies and tv shows created by them in separate columns 
for directors who have created tv shows and movies both*/

SELECT nd.director,
COUNT(DISTINCT CASE WHEN ns.type='Movie' THEN ns.show_id END) AS no_of_movies,
COUNT(DISTINCT CASE WHEN ns.type='TV Show' THEN ns.show_id END) AS no_of_shows
FROM netflix_stg ns INNER JOIN netflix_directors nd ON nd.show_id=ns.show_id 
GROUP BY nd.director
HAVING COUNT(DISTINCT ns.type)>1;

--2. Which country has highest number of comedy movies

SELECT TOP 1 nc.country,COUNT(DISTINCT ng.show_id) AS no_of_movies FROM netflix_genre ng 
INNER JOIN netflix_countries nc ON ng.show_id=nc.show_id 
INNER JOIN netflix_stg ns ON ns.show_id=nc.show_id
WHERE ng.genre='Comedies' AND ns.type='Movie'
GROUP BY nc.country
ORDER BY no_of_movies DESC;

--3. For each year(as per date added to netflix), which director has maximum number of movies released
WITH cte AS
(SELECT nd.director,YEAR(date_added) AS date_year, COUNT(ns.show_id) AS no_of_movies,
ROW_NUMBER() OVER (PARTITION BY YEAR(date_added) ORDER BY COUNT(ns.show_id) DESC,nd.director) AS rn
FROM netflix_stg ns
INNER JOIN netflix_directors nd ON ns.show_id=nd.show_id
WHERE ns.type='Movie'
GROUP BY YEAR(date_added),nd.director)
SELECT director,date_year,no_of_movies FROM cte WHERE rn=1;


--4. What is the average duration of movies in each genre

SELECT ng.genre,AVG(CAST(REPLACE(duration,' min','') AS INT)) AS avg_duration FROM netflix_genre ng INNER JOIN
netflix_stg ns ON ng.show_id=ns.show_id
WHERE ns.type='Movie'
GROUP BY ng.genre;


--5. Find the list of directors who have created horror and comedy movies both.
--Display director name along with number of comedy and horror movies directed by them.

SELECT nd.director,
COUNT(CASE WHEN ng.genre='Comedies' THEN ns.show_id END) AS no_of_comedy_movies,
COUNT(CASE WHEN ng.genre='Horror Movies' THEN ns.show_id END) AS no_of_horror_movies
FROM netflix_stg ns INNER JOIN
netflix_genre ng ON ns.show_id=ng.show_id
INNER JOIN netflix_directors nd ON nd.show_id=ng.show_id
WHERE ns.type='Movie' AND ng.genre IN ('Comedies','Horror Movies')
GROUP BY nd.director
HAVING COUNT(DISTINCT ng.genre)=2;