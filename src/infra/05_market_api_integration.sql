USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

-- Network Rule Creation
CREATE OR REPLACE NETWORK RULE market_api_network_rule
    MODE = EGRESS   -- means outbound traffice FROM snowflake to external is allowed.
    TYPE = HOST_PORT
    VALUE_LIST = ('www.alphavantage.co:443')
    ;

-- API Key Creation
CREATE OR REPLACE SECRET market_api_key_1
    TYPE = PASSWORD
    USERNAME = 'market_api_key_1'
    PASSWORD = 'ESDNSG7Y1KQ6CZ9K'
    ;

-- API Key Creation
CREATE OR REPLACE SECRET market_api_key_2
    TYPE = PASSWORD
    USERNAME = 'market_api_key_2'
    PASSWORD = 'JTKM3LAKTM7KPT6C'
    ;

-- External Access Integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION market_api_integration
    ALLOWED_NETWORK_RULES = (market_api_network_rule)
    ALLOWED_AUTHENTICATION_SECRETS = (market_api_key_1, market_api_key_2)
    ENABLED = TRUE
    COMMENT = 'Market API External Access Integration'
    ;
