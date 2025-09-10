# Cumulative Table Pattern: From Sports to Blockchain

## Understanding the Pattern

The cumulative table pattern you've built is a powerful analytical design that maintains **historical state** while efficiently processing **incremental updates**. Here's how it works:

### Core Components

1. **Complex Data Types**: Custom structs and enums to represent time-series data
2. **Array Accumulation**: Building arrays of historical records over time
3. **Idempotent Updates**: Safe to re-run without duplicating data
4. **Temporal State Management**: Tracking current vs historical information

### The Sports Example Breakdown

```sql
-- 1. Define complex data types
create type season_stats as (
    season INTEGER,
    gp INTEGER,
    pts real, 
    reb real, 
    ast real 
)

-- 2. Create cumulative table with array column
create table players (
    player_name TEXT,
    season_stats season_stats[],  -- Array of historical data
    scoring_class scoring_class,  -- Current classification
    current_season INTEGER,       -- Current time period
    primary key(player_name, current_season)
)

-- 3. Idempotent insert pattern
INSERT INTO players
with yesterday as ( -- Previous state
    select * from players where current_season = 2000
), today as ( -- New data
    select * from player_seasons where season = 2001
)
select 
    coalesce(t.player_name, y.player_name) as player_name,
    -- Array accumulation logic
    case when y.season_stats is null then 
        array[row(t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
    when t.season is not null then 
        y.season_stats || array[row(t.season, t.gp, t.pts, t.reb, t.ast)::season_stats]
    else y.season_stats
    end as season_stats,
    -- Current state calculation
    case when t.season is not null then 
        case when t.pts > 20 then 'star' 
             when t.pts > 15 then 'good'
             when t.pts > 10 then 'average'
             else 'bad'
        end::scoring_class 
    else y.scoring_class
    end as scoring_class,
    coalesce(t.season, y.current_season + 1) as current_season
from today t 
full outer join yesterday y on t.player_name = y.player_name
```

## Blockchain Application: DeFi Protocol Analytics

Let's apply this pattern to track DeFi protocol performance over time:

### 1. Define Complex Data Types for DeFi

```sql
-- Daily protocol metrics
create type daily_metrics as (
    date DATE,
    total_value_locked DECIMAL(20,2),
    daily_volume DECIMAL(20,2),
    active_users INTEGER,
    transaction_count INTEGER,
    fees_generated DECIMAL(20,2)
);

-- Protocol risk classification
create type risk_level as enum ('low', 'medium', 'high', 'critical');

-- Protocol category
create type protocol_category as enum ('dex', 'lending', 'yield', 'derivatives', 'insurance');
```

### 2. Create Cumulative Protocol Table

```sql
create table protocol_analytics (
    protocol_name TEXT,
    protocol_address TEXT,
    category protocol_category,
    chain TEXT,
    daily_metrics daily_metrics[],  -- Historical daily data
    risk_level risk_level,          -- Current risk assessment
    days_since_last_activity INTEGER,
    current_date DATE,
    primary key(protocol_name, current_date)
);
```

### 3. Idempotent Update Pattern for DeFi

```sql
INSERT INTO protocol_analytics
with yesterday as (
    select * from protocol_analytics 
    where current_date = '2024-01-14'  -- Previous day
), today as (
    select * from daily_protocol_data 
    where date = '2024-01-15'  -- New day's data
)
select 
    coalesce(t.protocol_name, y.protocol_name) as protocol_name,
    coalesce(t.protocol_address, y.protocol_address) as protocol_address,
    coalesce(t.category, y.category) as category,
    coalesce(t.chain, y.chain) as chain,
    
    -- Array accumulation: add today's metrics to historical array
    case when y.daily_metrics is null then 
        array[row(
            t.date,
            t.total_value_locked,
            t.daily_volume,
            t.active_users,
            t.transaction_count,
            t.fees_generated
        )::daily_metrics]
    when t.date is not null then 
        y.daily_metrics || array[row(
            t.date,
            t.total_value_locked,
            t.daily_volume,
            t.active_users,
            t.transaction_count,
            t.fees_generated
        )::daily_metrics]
    else y.daily_metrics
    end as daily_metrics,
    
    -- Current risk assessment based on latest data
    case when t.date is not null then 
        case when t.total_value_locked < 1000000 then 'critical'
             when t.total_value_locked < 10000000 then 'high'
             when t.total_value_locked < 100000000 then 'medium'
             else 'low'
        end::risk_level
    else y.risk_level
    end as risk_level,
    
    -- Days since last activity
    case when t.date is not null then 0 
         else y.days_since_last_activity + 1
    end as days_since_last_activity,
    
    coalesce(t.date, y.current_date + interval '1 day') as current_date
from today t 
full outer join yesterday y 
    on t.protocol_name = y.protocol_name
```

### 4. Analytics Queries for DeFi

```sql
-- Find protocols with biggest TVL growth
select
    protocol_name,
    (daily_metrics[1]::daily_metrics).total_value_locked as first_tvl,
    (daily_metrics[cardinality(daily_metrics)]::daily_metrics).total_value_locked as latest_tvl,
    (daily_metrics[cardinality(daily_metrics)]::daily_metrics).total_value_locked / 
    nullif((daily_metrics[1]::daily_metrics).total_value_locked, 0) as growth_multiplier
from protocol_analytics
where current_date = '2024-01-15'
and risk_level = 'low'
order by growth_multiplier desc;

-- Calculate 7-day moving average of volume
with unnested as (
    select
        protocol_name,
        unnest(daily_metrics) as daily_metrics
    from protocol_analytics 
    where current_date = '2024-01-15'
    and protocol_name = 'Uniswap'
)
select
    protocol_name,
    avg((daily_metrics::daily_metrics).daily_volume) as avg_7day_volume
from unnested
group by protocol_name;

-- Find protocols with declining activity
select
    protocol_name,
    (daily_metrics[cardinality(daily_metrics)]::daily_metrics).active_users as latest_users,
    (daily_metrics[cardinality(daily_metrics)-6]::daily_metrics).active_users as week_ago_users,
    days_since_last_activity
from protocol_analytics
where current_date = '2024-01-15'
and days_since_last_activity > 7
order by days_since_last_activity desc;
```

## Key Benefits of This Pattern

1. **Efficient Historical Analysis**: No need to join multiple tables or aggregate large datasets
2. **Idempotent Processing**: Safe to re-run without data corruption
3. **Parallelizable**: Can process different time periods in parallel
4. **Memory Efficient**: Only stores deltas, not full historical snapshots
5. **Query Performance**: Complex analytics without expensive GROUP BY operations

## When to Use This Pattern

- **Time-series data** that needs historical analysis
- **Incremental updates** from streaming sources
- **Complex aggregations** over time periods
- **Real-time analytics** on historical data
- **State management** in data pipelines

## Alternative Blockchain Use Cases

1. **Wallet Analytics**: Track user behavior over time
2. **Token Price Analysis**: Historical price movements and volatility
3. **Smart Contract Metrics**: Function call patterns and gas usage
4. **Cross-chain Bridge Activity**: Transaction flows between chains
5. **NFT Collection Performance**: Sales volume and floor price trends

This pattern is particularly powerful in blockchain contexts because it handles the high-volume, time-series nature of on-chain data while enabling complex analytical queries without performance penalties.
