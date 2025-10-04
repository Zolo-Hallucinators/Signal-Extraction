-- First: Create the database that can be used to create the below schemas.
-- TODO: Go to catalog and create database - 'SIGNAL_EXTRACTION_DB'

USE DATABASE SIGNAL_EXTRACTION_DB;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW;        -- Landing data as-is
CREATE SCHEMA IF NOT EXISTS STAGING;    -- Cleaned / standardized data
CREATE SCHEMA IF NOT EXISTS ANALYTICS;  -- Final features, dashboards, ML inputs
CREATE SCHEMA IF NOT EXISTS UTILS;      -- for git integration and other stuff