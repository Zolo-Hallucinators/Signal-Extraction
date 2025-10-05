-- =====================================================
-- MARKET DATA TRANSFORMATION & FEATURE ENGINEERING
-- Purpose: Transform raw market data and generate features for price prediction
-- Schema: SIGNAL_EXTRACTION_DB.STAGING
-- =====================================================


-- DROP Table Queries.
-- DROP TABLE SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
-- DROP VIEW SIGNAL_EXTRACTION_DB.STAGING.VW_LATEST_MARKET_FEATURES;
-- DROP PROCEDURE SIGNAL_EXTRACTION_DB.STAGING.TRANSFORM_MARKET_DATA();

-- =====================================================
--  Create the staging table with all features
-- =====================================================
CREATE OR REPLACE TABLE SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES (
    -- Primary Keys & Identifiers
    feature_id STRING PRIMARY KEY,
    date DATE NOT NULL,
    symbol STRING NOT NULL,
    entity_name STRING,
    
    -- Raw OHLCV Data
    open NUMBER(10,4),
    high NUMBER(10,4),
    low NUMBER(10,4),
    close NUMBER(10,4),
    volume NUMBER(20,4),
    
    -- Price-based Features
    daily_return NUMBER(10,6),
    log_return NUMBER(10,6),
    price_range NUMBER(10,4),
    price_range_pct NUMBER(10,6),
    
    -- Moving Averages (Trend Indicators)
    ma_5 NUMBER(10,4),
    ma_10 NUMBER(10,4),
    ma_20 NUMBER(10,4),
    ma_50 NUMBER(10,4),
    ema_12 NUMBER(10,4),
    ema_26 NUMBER(10,4),
    
    -- Momentum Indicators
    rsi_14 NUMBER(10,4),
    macd NUMBER(10,4),
    macd_signal NUMBER(10,4),
    macd_histogram NUMBER(10,4),
    
    -- Volatility Features
    volatility_5d NUMBER(10,6),
    volatility_10d NUMBER(10,6),
    volatility_20d NUMBER(10,6),
    atr_14 NUMBER(10,4),
    
    -- Volume Features
    volume_ma_5 NUMBER(20,4),
    volume_ma_20 NUMBER(20,4),
    volume_ratio NUMBER(10,6),
    
    -- Lag Features (Previous values)
    close_lag_1 NUMBER(10,4),
    close_lag_2 NUMBER(10,4),
    close_lag_3 NUMBER(10,4),
    close_lag_5 NUMBER(10,4),
    volume_lag_1 NUMBER(20,4),
    
    -- Rolling Statistics
    rolling_max_20 NUMBER(10,4),
    rolling_min_20 NUMBER(10,4),
    distance_from_high_20 NUMBER(10,6),
    distance_from_low_20 NUMBER(10,6),
    
    -- Target Variables (for prediction)
    next_day_close NUMBER(10,4),
    next_day_return NUMBER(10,6),
    price_direction NUMBER(1,0), -- 1 for up, 0 for down
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP,
    data_quality_flag STRING
);

-- =====================================================
-- Populate the staging table with transformed data and features
-- =====================================================
INSERT INTO SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
WITH base_data AS (
    -- Get base data with entity name extraction
    SELECT 
        date,
        symbol,
        -- CASE 
        --     WHEN UPPER(symbol) LIKE '%PLTR%' THEN 'Palantir'
        --     WHEN UPPER(symbol) LIKE '%ORCL%' THEN 'Oracle'
        --     ELSE INITCAP(symbol)
        -- END AS entity_name,
        entity_name,
        open,
        high,
        low,
        close,
        volume,
        -- Add row number for ordering
        ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY date) AS row_num
    FROM SIGNAL_EXTRACTION_DB.RAW.MARKET_DATA
    WHERE close IS NOT NULL
),

price_features AS (
    -- Calculate basic price features
    SELECT 
        *,
        -- Daily returns
        (close - LAG(close, 1) OVER (PARTITION BY symbol ORDER BY date)) / 
            NULLIF(LAG(close, 1) OVER (PARTITION BY symbol ORDER BY date), 0) AS daily_return,
        
        -- Log returns (more stable for modeling)
        LN(close / NULLIF(LAG(close, 1) OVER (PARTITION BY symbol ORDER BY date), 0)) AS log_return,
        
        -- Intraday range
        (high - low) AS price_range,
        (high - low) / NULLIF(close, 0) AS price_range_pct,
        
        -- Lag features
        LAG(close, 1) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_1,
        LAG(close, 2) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_2,
        LAG(close, 3) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_3,
        LAG(close, 5) OVER (PARTITION BY symbol ORDER BY date) AS close_lag_5,
        LAG(volume, 1) OVER (PARTITION BY symbol ORDER BY date) AS volume_lag_1,
        
        -- Target variables (future values)
        LEAD(close, 1) OVER (PARTITION BY symbol ORDER BY date) AS next_day_close,
        (LEAD(close, 1) OVER (PARTITION BY symbol ORDER BY date) - close) / 
            NULLIF(close, 0) AS next_day_return,
        CASE 
            WHEN LEAD(close, 1) OVER (PARTITION BY symbol ORDER BY date) > close THEN 1 
            ELSE 0 
        END AS price_direction
    FROM base_data
),

moving_averages AS (
    -- Calculate moving averages
    SELECT 
        *,
        -- Simple Moving Averages
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma_5,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS ma_10,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS ma_20,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma_50,
        
        -- Volume moving averages
        AVG(volume) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS volume_ma_5,
        AVG(volume) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS volume_ma_20
    FROM price_features
),

-- [TODO] Must fix and use the exact exponential average formula instead of the sma formula.
exponential_mas AS (
    -- Calculate EMAs (simplified approach using weighted averages)
    SELECT 
        *,
        -- EMA 12 (approximate using weighted average)
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS ema_12,
        AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 25 PRECEDING AND CURRENT ROW) AS ema_26
    FROM moving_averages
),

volatility_features AS (
    -- Calculate volatility measures
    SELECT 
        *,
        -- Standard deviation of returns (volatility)
        STDDEV(daily_return) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS volatility_5d,
        STDDEV(daily_return) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS volatility_10d,
        STDDEV(daily_return) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS volatility_20d,
        
        -- Average True Range (ATR) - simplified
        AVG(high - low) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS atr_14,
        
        -- Rolling max/min
        MAX(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS rolling_max_20,
        MIN(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS rolling_min_20
    FROM exponential_mas
),

momentum_indicators AS (
    -- Calculate RSI and MACD
    SELECT 
        *,
        -- Distance from highs/lows
        (rolling_max_20 - close) / NULLIF(rolling_max_20, 0) AS distance_from_high_20,
        (close - rolling_min_20) / NULLIF(rolling_min_20, 0) AS distance_from_low_20,
        
        -- Volume ratio
        volume / NULLIF(volume_ma_20, 0) AS volume_ratio,
        
        -- MACD components
        (ema_12 - ema_26) AS macd,
        AVG(ema_12 - ema_26) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 8 PRECEDING AND CURRENT ROW) AS macd_signal
    FROM volatility_features
),

rsi_calculation AS (
    -- Calculate RSI (Relative Strength Index)
    SELECT 
        *,
        (macd - macd_signal) AS macd_histogram,
        
        -- RSI calculation (simplified using average gains/losses)
        CASE 
            WHEN AVG(CASE WHEN daily_return < 0 THEN ABS(daily_return) ELSE 0 END) 
                 OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) = 0 
            THEN 100
            ELSE 100 - (100 / (1 + 
                AVG(CASE WHEN daily_return > 0 THEN daily_return ELSE 0 END) 
                    OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) /
                NULLIF(AVG(CASE WHEN daily_return < 0 THEN ABS(daily_return) ELSE 0 END) 
                    OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW), 0)
            ))
        END AS rsi_14
    FROM momentum_indicators
),

data_quality AS (
    -- Add data quality checks
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

-- Final SELECT with all features
SELECT 
    CONCAT(symbol, '_', date) AS feature_id,
    date,
    symbol,
    entity_name,
    open,
    high,
    low,
    close,
    volume,
    daily_return,
    log_return,
    price_range,
    price_range_pct,
    ma_5,
    ma_10,
    ma_20,
    ma_50,
    ema_12,
    ema_26,
    rsi_14,
    macd,
    macd_signal,
    macd_histogram,
    volatility_5d,
    volatility_10d,
    volatility_20d,
    atr_14,
    volume_ma_5,
    volume_ma_20,
    volume_ratio,
    close_lag_1,
    close_lag_2,
    close_lag_3,
    close_lag_5,
    volume_lag_1,
    rolling_max_20,
    rolling_min_20,
    distance_from_high_20,
    distance_from_low_20,
    next_day_close,
    next_day_return,
    price_direction,
    CURRENT_TIMESTAMP AS created_at,
    data_quality_flag
FROM data_quality
WHERE row_num > 1  -- Exclude first row due to lag calculations
ORDER BY symbol, date;


-- =====================================================
-- Create a view for model-ready data (excludes poor quality data records)
-- =====================================================
CREATE OR REPLACE VIEW SIGNAL_EXTRACTION_DB.STAGING.VW_MODEL_READY_FEATURES AS
SELECT 
    feature_id,
    date,
    symbol,
    entity_name,
    -- OHLCV
    open, high, low, close, volume,
    -- Features
    daily_return, log_return, price_range, price_range_pct,
    ma_5, ma_10, ma_20, ma_50, ema_12, ema_26,
    rsi_14, macd, macd_signal, macd_histogram,
    volatility_5d, volatility_10d, volatility_20d, atr_14,
    volume_ma_5, volume_ma_20, volume_ratio,
    close_lag_1, close_lag_2, close_lag_3, close_lag_5, volume_lag_1,
    rolling_max_20, rolling_min_20,
    distance_from_high_20, distance_from_low_20,
    -- Targets
    next_day_close, next_day_return, price_direction
FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
WHERE data_quality_flag = 'VALID'
    AND next_day_close IS NOT NULL  -- Exclude last row (no target)
ORDER BY symbol, date;

-- =====================================================
-- Data validation queries
-- =====================================================

-- Check record counts per symbol
SELECT 
    symbol,
    entity_name,
    COUNT(*) AS total_records,
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date,
    COUNT(CASE WHEN data_quality_flag = 'VALID' THEN 1 END) AS valid_records
FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES
GROUP BY symbol, entity_name
ORDER BY symbol;

-- Check for missing values in key features
SELECT 
    'ma_20' AS feature_name, COUNT(*) AS missing_count 
FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE ma_20 IS NULL
UNION ALL
SELECT 'rsi_14', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE rsi_14 IS NULL
UNION ALL
SELECT 'macd', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE macd IS NULL
UNION ALL
SELECT 'volatility_20d', COUNT(*) FROM SIGNAL_EXTRACTION_DB.STAGING.MARKET_DATA_FEATURES WHERE volatility_20d IS NULL;

-- Sample the data
SELECT * 
FROM SIGNAL_EXTRACTION_DB.STAGING.VW_MODEL_READY_FEATURES 
WHERE symbol IN ('PLTR', 'ORCL')
ORDER BY symbol, date DESC
LIMIT 10;