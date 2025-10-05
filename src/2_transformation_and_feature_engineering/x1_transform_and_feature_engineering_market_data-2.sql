-- =====================================================
-- SIGNAL EXTRACTION: MARKET DATA TRANSFORMATION & FEATURE ENGINEERING
-- PURPOSE: create + populate staging table with features for price prediction
-- SCHEMA: SIGNAL_EXTRACTION_DB.STAGING
-- Assumes raw table: SIGNAL_EXTRACTION_DB.RAW.MARKET_DATA
-- =====================================================

/*
 Raw table structure assumed:
 CREATE TABLE IF NOT EXISTS SIGNAL_EXTRACTION_DB.RAW.MARKET_DATA (
   date DATE,
   open NUMBER(10,4),
   high NUMBER(10,4),
   low NUMBER(10,4),
   close NUMBER(10,4),
   volume NUMBER(20,4),
   symbol STRING,
   function STRING,
   price_id STRING PRIMARY KEY,
   ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP
 );
*/

-- =====================================================
-- 1) Create or replace the staging features table
-- NOTE: Snowflake does not enforce PKs by default; PK included as documentation.
-- Consider adding CLUSTER BY for large datasets: CLUSTER BY (symbol, date)
-- =====================================================
CREATE OR REPLACE TABLE SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES (
    feature_id STRING PRIMARY KEY,
    date DATE NOT NULL,
    symbol STRING NOT NULL,
    entity_name STRING,
    open NUMBER(10,4),
    high NUMBER(10,4),
    low NUMBER(10,4),
    close NUMBER(10,4),
    volume NUMBER(20,4),
    daily_return NUMBER(10,6),
    log_return NUMBER(10,6),
    price_range NUMBER(10,4),
    price_range_pct NUMBER(10,6),
    ma_5 NUMBER(10,4),
    ma_10 NUMBER(10,4),
    ma_20 NUMBER(10,4),
    ma_50 NUMBER(10,4),
    ema_12 NUMBER(10,6),
    ema_26 NUMBER(10,6),
    rsi_14 NUMBER(10,4),
    macd NUMBER(10,6),
    macd_signal NUMBER(10,6),
    macd_histogram NUMBER(10,6),
    volatility_5d NUMBER(10,6),
    volatility_10d NUMBER(10,6),
    volatility_20d NUMBER(10,6),
    atr_14 NUMBER(10,4),
    volume_ma_5 NUMBER(20,4),
    volume_ma_20 NUMBER(20,4),
    volume_ratio NUMBER(10,6),
    close_lag_1 NUMBER(10,4),
    close_lag_2 NUMBER(10,4),
    close_lag_3 NUMBER(10,4),
    close_lag_5 NUMBER(10,4),
    volume_lag_1 NUMBER(20,4),
    rolling_max_20 NUMBER(10,4),
    rolling_min_20 NUMBER(10,4),
    distance_from_high_20 NUMBER(10,6),
    distance_from_low_20 NUMBER(10,6),
    next_day_close NUMBER(10,4),
    next_day_return NUMBER(10,6),
    price_direction NUMBER(1,0),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP,
    data_quality_flag STRING
)
COMMENT = 'Staging features for price prediction - automated generation'
;

-- =====================================================
-- 2) Populate the staging table with features
--    - computes proper EMA using recursive per-symbol approach
--    - computes MA, volatility, RSI, MACD, lags, rolling stats, targets
-- =====================================================
INSERT INTO SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES (
    feature_id, date, symbol, entity_name,
    open, high, low, close, volume,
    daily_return, log_return, price_range, price_range_pct,
    ma_5, ma_10, ma_20, ma_50,
    ema_12, ema_26,
    rsi_14, macd, macd_signal, macd_histogram,
    volatility_5d, volatility_10d, volatility_20d, atr_14,
    volume_ma_5, volume_ma_20, volume_ratio,
    close_lag_1, close_lag_2, close_lag_3, close_lag_5, volume_lag_1,
    rolling_max_20, rolling_min_20,
    distance_from_high_20, distance_from_low_20,
    next_day_close, next_day_return, price_direction,
    created_at, data_quality_flag
)
WITH
base_data AS (
    SELECT
        date,
        symbol,
        -- simple entity mapping example; extend mapping as needed
        CASE
            WHEN UPPER(symbol) LIKE '%PLTR%' THEN 'Palantir'
            WHEN UPPER(symbol) LIKE '%ORCL%' THEN 'Oracle'
            ELSE INITCAP(symbol)
        END AS entity_name,
        open, high, low, close, volume,
        ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY date) AS row_num
    FROM SIGNAL_EXTRACTION_DB.RAW.MARKET_DATA
    WHERE close IS NOT NULL
),

-- price_features: lags, returns, price range, simple rolling MAs for features that are fine with SMA
price_features AS (
    SELECT
        date, symbol, entity_name, open, high, low, close, volume, row_num,
        -- returns (guarded)
        CASE WHEN LAG(close) OVER (PARTITION BY symbol ORDER BY date) IS NULL THEN NULL
             WHEN LAG(close) OVER (PARTITION BY symbol ORDER BY date) = 0 THEN NULL
             ELSE (close - LAG(close) OVER (PARTITION BY symbol ORDER BY date)) / LAG(close) OVER (PARTITION BY symbol ORDER BY date)
        END AS daily_return,
        CASE WHEN LAG(close) OVER (PARTITION BY symbol ORDER BY date) IS NULL THEN NULL
             WHEN LAG(close) OVER (PARTITION BY symbol ORDER BY date) = 0 THEN NULL
             ELSE LN(close / LAG(close) OVER (PARTITION BY symbol ORDER BY date))
        END AS log_return,
        (high - low) AS price_range,
        CASE WHEN close = 0 THEN NULL ELSE (high - low) / close END AS price_range_pct,

        LAG(close,1) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_1,
        LAG(close,2) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_2,
        LAG(close,3) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_3,
        LAG(close,5) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_5,
        LAG(volume,1) OVER (PARTITION BY symbol ORDER BY date) AS volume_lag_1,

        LEAD(close,1) OVER (PARTITION BY symbol ORDER BY date) AS next_day_close,
        CASE WHEN close = 0 THEN NULL ELSE (LEAD(close,1) OVER (PARTITION BY symbol ORDER BY date) - close) / close END AS next_day_return,
        CASE WHEN LEAD(close,1) OVER (PARTITION BY symbol ORDER BY date) > close THEN 1 ELSE 0 END AS price_direction,

        -- Simple SMAs (for trend features)
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma_5,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS ma_10,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS ma_20,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma_50,
        AVG(volume) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS volume_ma_5,
        AVG(volume) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS volume_ma_20,

        -- rolling statistics for volatility & range
        STDDEV((close - LAG(close) OVER (PARTITION BY symbol ORDER BY date)) / NULLIF(LAG(close) OVER (PARTITION BY symbol ORDER BY date),0))
            OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS volatility_5d,
        STDDEV((close - LAG(close) OVER (PARTITION BY symbol ORDER BY date)) / NULLIF(LAG(close) OVER (PARTITION BY symbol ORDER BY date),0))
            OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS volatility_10d,
        STDDEV((close - LAG(close) OVER (PARTITION BY symbol ORDER BY date)) / NULLIF(LAG(close) OVER (PARTITION BY symbol ORDER BY date),0))
            OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS volatility_20d,

        AVG(high - low) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS atr_14,

        MAX(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS rolling_max_20,
        MIN(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS rolling_min_20
    FROM base_data
),

-- ema_calc: recursive calculation of EMA12 and EMA26 per symbol using standard formula
-- alpha = 2 / (N + 1)
ema_calc AS (
    WITH RECURSIVE r AS (
        -- Anchor: first row (row_num = 1) per symbol; initialize EMA = close
        SELECT
            p.date, p.symbol, p.entity_name, p.open, p.high, p.low, p.close, p.volume, p.row_num,
            p.daily_return, p.log_return, p.price_range, p.price_range_pct,
            p.close_lag_1, p.close_lag_2, p.close_lag_3, p.close_lag_5, p.volume_lag_1,
            p.next_day_close, p.next_day_return, p.price_direction,
            p.ma_5, p.ma_10, p.ma_20, p.ma_50, p.volume_ma_5, p.volume_ma_20,
            p.volatility_5d, p.volatility_10d, p.volatility_20d, p.atr_14,
            p.rolling_max_20, p.rolling_min_20,
            -- initialize both EMAs to the close of the first row
            p.close AS ema_12,
            p.close AS ema_26
        FROM price_features p
        WHERE p.row_num = 1

        UNION ALL

        -- Recursive step: compute EMA for row_num = prev.row_num + 1
        SELECT
            p.date, p.symbol, p.entity_name, p.open, p.high, p.low, p.close, p.volume, p.row_num,
            p.daily_return, p.log_return, p.price_range, p.price_range_pct,
            p.close_lag_1, p.close_lag_2, p.close_lag_3, p.close_lag_5, p.volume_lag_1,
            p.next_day_close, p.next_day_return, p.price_direction,
            p.ma_5, p.ma_10, p.ma_20, p.ma_50, p.volume_ma_5, p.volume_ma_20,
            p.volatility_5d, p.volatility_10d, p.volatility_20d, p.atr_14,
            p.rolling_max_20, p.rolling_min_20,
            -- EMA recursion
            -- alpha_12 = 2/(12+1), alpha_26 = 2/(26+1)
            ( (2.0/13.0) * p.close + (1 - 2.0/13.0) * r.ema_12 ) AS ema_12,
            ( (2.0/27.0) * p.close + (1 - 2.0/27.0) * r.ema_26 ) AS ema_26
        FROM r
        JOIN price_features p
          ON p.symbol = r.symbol
         AND p.row_num = r.row_num + 1
    )
    SELECT * FROM r
),

-- momentum_indicators: compute macd, macd_signal (SMA(9) on macd used here),
-- volume ratio and distances
momentum_indicators AS (
    SELECT
        *,
        (ema_12 - ema_26) AS macd,
        -- macd_signal as SMA(9) of macd (you can change to EMA(9) if preferred)
        AVG(ema_12 - ema_26) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 8 PRECEDING AND CURRENT ROW) AS macd_signal,
        (ema_12 - ema_26) - AVG(ema_12 - ema_26) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 8 PRECEDING AND CURRENT ROW) AS macd_histogram,
        CASE WHEN volume_ma_20 = 0 THEN NULL ELSE volume / volume_ma_20 END AS volume_ratio,
        CASE WHEN rolling_max_20 = 0 THEN NULL ELSE (rolling_max_20 - close) / rolling_max_20 END AS distance_from_high_20,
        CASE WHEN rolling_min_20 = 0 THEN NULL ELSE (close - rolling_min_20) / rolling_min_20 END AS distance_from_low_20
    FROM ema_calc
),

-- rsi_calculation (simplified RSI using avg gains/losses on daily_return window)
rsi_calculation AS (
    SELECT
        *,
        CASE
            WHEN AVG(CASE WHEN daily_return < 0 THEN ABS(daily_return) ELSE 0 END)
                 OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) = 0
            THEN 100
            ELSE 100 - (100 / (1 + 
                (AVG(CASE WHEN daily_return > 0 THEN daily_return ELSE 0 END)
                    OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW))
                /
                NULLIF(AVG(CASE WHEN daily_return < 0 THEN ABS(daily_return) ELSE 0 END)
                    OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW), 0)
            ))
        END AS rsi_14
    FROM momentum_indicators
),

-- data_quality checks
data_quality AS (
    SELECT
        *,
        CASE
            WHEN close IS NULL OR volume IS NULL THEN 'MISSING_DATA'
            WHEN volume = 0 THEN 'ZERO_VOLUME'
            WHEN ABS(daily_return) > 0.5 THEN 'EXTREME_MOVEMENT'
            WHEN row_num <= 50 THEN 'INSUFFICIENT_HISTORY'
            ELSE 'VALID'
        END AS data_quality_flag
    FROM rsi_calculation
)

-- final select: explicit column ordering to match insert column list
SELECT
    -- feature_id: unique identifier (symbol + YYYYMMDD)
    CONCAT(symbol, '_', TO_VARCHAR(date,'YYYYMMDD')) AS feature_id,
    date, symbol, entity_name,
    open, high, low, close, volume,
    daily_return, log_return, price_range, price_range_pct,
    ma_5, ma_10, ma_20, ma_50,
    ema_12, ema_26,
    rsi_14, macd, macd_signal, macd_histogram,
    volatility_5d, volatility_10d, volatility_20d, atr_14,
    volume_ma_5, volume_ma_20, volume_ratio,
    close_lag_1, close_lag_2, close_lag_3, close_lag_5, volume_lag_1,
    rolling_max_20, rolling_min_20,
    distance_from_high_20, distance_from_low_20,
    next_day_close, next_day_return, price_direction,
    CURRENT_TIMESTAMP(), data_quality_flag
FROM data_quality
WHERE row_num > 1  -- exclude first row for each symbol (lags undefined)
ORDER BY symbol, date
;
-- End INSERT

-- =====================================================
-- 3) Create a model-ready view that only exposes 'VALID' rows and non-null targets
-- =====================================================
CREATE OR REPLACE VIEW SIGNAL_EXTRACTION_DB.STAGING.VW_MODEL_READY_FEATURES AS
SELECT
    feature_id, date, symbol, entity_name,
    open, high, low, close, volume,
    daily_return, log_return, price_range, price_range_pct,
    ma_5, ma_10, ma_20, ma_50, ema_12, ema_26,
    rsi_14, macd, macd_signal, macd_histogram,
    volatility_5d, volatility_10d, volatility_20d, atr_14,
    volume_ma_5, volume_ma_20, volume_ratio,
    close_lag_1, close_lag_2, close_lag_3, close_lag_5, volume_lag_1,
    rolling_max_20, rolling_min_20,
    distance_from_high_20, distance_from_low_20,
    next_day_close, next_day_return, price_direction
FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
WHERE data_quality_flag = 'VALID'
  AND next_day_close IS NOT NULL
ORDER BY symbol, date
;

-- =====================================================
-- 4) Useful validation queries (run separately)
-- =====================================================
-- Record counts per symbol
-- SELECT symbol, entity_name, COUNT(*) AS total_records,
--        MIN(date) AS earliest_date, MAX(date) AS latest_date,
--        COUNT(CASE WHEN data_quality_flag = 'VALID' THEN 1 END) AS valid_records
-- FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
-- GROUP BY symbol, entity_name ORDER BY symbol;

-- Missing critical features
-- SELECT 'ma_20' AS feature_name, COUNT(*) AS missing_count FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE ma_20 IS NULL
-- UNION ALL
-- SELECT 'rsi_14', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE rsi_14 IS NULL
-- UNION ALL
-- SELECT 'macd', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE macd IS NULL
-- UNION ALL
-- SELECT 'volatility_20d', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE volatility_20d IS NULL;

-- Sample model-ready rows for PLTR and ORCL
-- SELECT * FROM SIGNAL_EXTRACTION_DB.STAGING.VW_MODEL_READY_FEATURES WHERE symbol IN ('PLTR','ORCL') ORDER BY symbol, date DESC LIMIT 10;

