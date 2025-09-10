----- setup for Lab 2

drop table players;



 CREATE TABLE players (
     player_name TEXT,
     height TEXT,
     college TEXT,
     country TEXT,
     draft_year TEXT,
     draft_round TEXT,
     draft_number TEXT,
     seasons season_stats[],
     scoring_class scoring_class,
     years_since_last_active INTEGER,
     is_active BOOLEAN,
     current_season INTEGER,
     PRIMARY KEY (player_name, current_season)
 );

INSERT INTO players
WITH years AS (
    SELECT *
    FROM GENERATE_SERIES(1996, 2022) AS season
), p AS (
    SELECT
        player_name,
        MIN(season) AS first_season
    FROM player_seasons
    GROUP BY player_name
), players_and_seasons AS (
    SELECT *
    FROM p
    JOIN years y
        ON p.first_season <= y.season
), windowed AS (
    SELECT
        pas.player_name,
        pas.season,
        ARRAY_REMOVE(
            ARRAY_AGG(
                CASE
                    WHEN ps.season IS NOT NULL
                        THEN ROW(
                            ps.season,
                            ps.gp,
                            ps.pts,
                            ps.reb,
                            ps.ast
                        )::season_stats
                END)
            OVER (PARTITION BY pas.player_name ORDER BY COALESCE(pas.season, ps.season)),
            NULL
        ) AS seasons
    FROM players_and_seasons pas
    LEFT JOIN player_seasons ps
        ON pas.player_name = ps.player_name
        AND pas.season = ps.season
    ORDER BY pas.player_name, pas.season
), static AS (
    SELECT
        player_name,
        MAX(height) AS height,
        MAX(college) AS college,
        MAX(country) AS country,
        MAX(draft_year) AS draft_year,
        MAX(draft_round) AS draft_round,
        MAX(draft_number) AS draft_number
    FROM player_seasons
    GROUP BY player_name
)
SELECT
    w.player_name,
    s.height,
    s.college,
    s.country,
    s.draft_year,
    s.draft_round,
    s.draft_number,
    seasons AS season_stats,
    CASE
        WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 20 THEN 'star'
        WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 15 THEN 'good'
        WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 10 THEN 'average'
        ELSE 'bad'
    END::scoring_class AS scoring_class,
    w.season - (seasons[CARDINALITY(seasons)]::season_stats).season as years_since_last_active,
    (seasons[CARDINALITY(seasons)]::season_stats).season = season AS is_active,
    w.season
FROM windowed w
JOIN static s
    ON w.player_name = s.player_name;


----- start Lab 2

drop table players_scd;


create table players_scd (
	player_name TEXT,
	scoring_class scoring_class, -- metric we're tracking
	is_active BOOLEAN,           -- metric we're tracking
	start_season INTEGER,
	end_season INTEGER,
	current_season INTEGER,      -- date column of the data table
	primary KEY(player_name, start_season)
);


insert into players_scd
with with_previous as (

select 
	player_name
	, current_season
	, scoring_class
	, is_active
	, LAG(scoring_class, 1) over (partition by player_name order by current_season) as previous_scoring_class
	, LAG(is_active, 1) over (partition by player_name order by current_season) as previous_is_active
from players 
where current_season <= 2021
)

, with_indicator as (
select 
	*
	, case
		when scoring_class <> previous_scoring_class then 1 
		when is_active <> previous_is_active then 1 
		else 0
	end as change_indicator
from with_previous
)

, with_streaks as (
select 
	*
	, SUM(change_indicator) OVER(partition by player_name order by current_season) as streak_identifier
from with_indicator
)

select 
	player_name
	, scoring_class 
	, is_active 
	, MIN(current_season) as start_season 
	, MAX(current_season) as end_season
	, 2021 as current_season
from with_streaks
group by player_name, streak_identifier, is_active, scoring_class
order by player_name, streak_identifier




select * from players_scd;


----- pick up

create type scd_type as ( 
	scoring_class scoring_class,
	is_active boolean,
	start_season integer, 
	end_season integer
)







with last_season_scd as ( 
	select * from players_scd 
	where current_season = 2021 
	and end_season = 2021
)

, historical_scd as (
	select
		player_name 
		, scoring_class
		, is_active 
		, start_season 
		, end_season
	from players_scd 
	where current_season = 2021 
	and end_season < 2021
)

, this_season_data as (
	select * from players 
	where current_season = 2022
)

, unchanged_records as (
select 
	ts.player_name 
	, ts.scoring_class
	, ts.is_active 
	, ls.start_season
	, ts.current_season as end_season
from this_season_data ts 
join last_season_scd ls 
	on ls.player_name = ts.player_name
where ts.scoring_class = ls.scoring_class 
	and ts.is_active = ls.is_active
)

, changed_records as (
	select 
		ts.player_name 
		, unnest(ARRAY[
			ROW( 
				ls.scoring_class, 
				ls.is_active,
				ls.start_season, 
				ls.end_season
			)::scd_type, 
			ROW ( 
				ts.scoring_class, 
				ts.is_active,
				ts.current_season, 
				ts.current_season
			)::scd_type
		]) as records
	from this_season_data ts 
	left join last_season_scd ls 
		on ls.player_name = ts.player_name
	where (ts.scoring_class <> ls.scoring_class 
		or ts.is_active <> ls.is_active)
)

, unnested_changed_records as ( 
	select 
		player_name 
		, (records::scd_type).scoring_class 
		, (records::scd_type).is_active 
		, (records::scd_type).start_season 
		, (records::scd_type).end_season 
	from changed_records
)

, new_records as (
	select 
		ts.player_name 
		, ts.scoring_class 
		, ts.is_active 
		, ts.current_season as start_season 
		, ts.current_season as end_season
	from this_season_data ts 
	left join last_season_scd ls 
		 on ts.player_name = ls.player_name 
	where ls.player_name is null 

)

select * from historical_scd 

union all 

select * from unchanged_records

union all

select * from unnested_changed_records

union all 

select * from new_records 







