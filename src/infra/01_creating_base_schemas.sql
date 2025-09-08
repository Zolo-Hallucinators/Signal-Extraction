-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW;        -- Landing data as-is
CREATE SCHEMA IF NOT EXISTS STAGING;    -- Cleaned / standardized data
CREATE SCHEMA IF NOT EXISTS ANALYTICS;  -- Final features, dashboards, ML inputs
CREATE SCHEMA IF NOT EXISTS UTILS;      -- for git integration and other stuff