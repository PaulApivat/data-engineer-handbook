select * from player_seasons ps 

-- season_stats is a data type: struct we're creating
create type season_stats as (
	season INTEGER,
	gp INTEGER,
	pts real, 
	reb real, 
	ast real 
)


create type scoring_class as enum ('star', 'good', 'average', 'bad');


create table players (
	player_name TEXT,
	height TEXT,
	college TEXT,
	country TEXT, 
	draft_year TEXT, 
	draft_round TEXT,
	draft_number TEXT,
	season_stats season_stats[],
	scoring_class scoring_class, 
	years_since_last_season INTEGER, 
	current_season INTEGER, 
	primary key(player_name, current_season)
)


INSERT INTO players
with yesterday as ( -- this is NULL making it the "seed query"
	select * from players 
	where current_season = 2000
)

, today as (
	select * from player_seasons 
	where season = 2001
)

select 
	coalesce(t.player_name, y.player_name) as player_name
	, coalesce(t.height, y.height) as height 
	, coalesce(t.college, y.college) as college
	, coalesce(t.country, y.country) as country
	, coalesce(t.draft_year, y.draft_year) as draft_year
	, coalesce(t.draft_round, y.draft_round) as draft_round
	, coalesce(t.draft_number, y.draft_number) as draft_number
	, case when y.season_stats is null then array[row(
			t.season 
			, t.gp 
			, t.pts 
			, t.reb 
			, t.ast
			)::season_stats] -- turns array into struct type
	  when t.season is not null then y.season_stats || array[row(
			t.season 
			, t.gp 
			, t.pts 
			, t.reb 
			, t.ast
			)::season_stats]
	  else y.season_stats
	  end as season_stats
	, case 
		when t.season is not null then 
			case when t.pts > 20 then 'star' 
				 when t.pts > 15 then 'good'
				 when t.pts > 10 then 'average'
				 else 'bad'
			end::scoring_class 
		else y.scoring_class
	  end as scoring_class
	, case when t.season is not null then 0 
		else y.years_since_last_season + 1
	  end as years_since_last_season
	
	, coalesce(t.season, y.current_season + 1) as current_season
from today t 
full outer join yesterday y 
	on t.player_name = y.player_name

	
	
	
-- Do some analytics to show which player had the biggest improvement
-- from first season to their most recent season	
select
	player_name
	, (season_stats[1]::season_stats).pts as first_season
	, (season_stats[cardinality(season_stats)]::season_stats).pts as latest_season
from players
where current_season = 2001


-- do a ratio of first and latest season
select
	player_name
	, (season_stats[cardinality(season_stats)]::season_stats).pts /
	case when (season_stats[1]::season_stats).pts = 0 then 1 else (season_stats[1]::season_stats).pts end
from players 
where current_season = 2001
and scoring_class = 'star'



-- you can do historical analyses on cumulative tables without doing shuffles or group bys
-- if you don't have a group by and everything can happen in the "map" step and there's not "reduce"
-- this can be as parallelizable as you want it to be
	
	
select * from players where current_season = 2000
and player_name = 'Michael Jordan'


-- cumulative table design
-- do multiple joins whle keeping the temporal pieces (season_stats) together
-- without worrying about sorting because it stays sorted.
with unnested as ( -- going back and forth between unnest and regular query (player_seasons)
select
	player_name
	, UNNEST(season_stats) as season_stats 
from players 
where current_season = 2001
--and player_name = 'Michael Jordan'
)

select
	player_name
	, (season_stats::season_stats).*
from unnested


-- temporarily DROP players table; add two columns, then re-insert data
--drop table players;






