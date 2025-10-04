USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

-- Network Rule Creation
CREATE OR REPLACE NETWORK RULE news_api_network_rule
    MODE = EGRESS   -- means outbound traffice FROM snowflake to external is allowed.
    TYPE = HOST_PORT
    VALUE_LIST = ('newsapi.org:443')
    ;

-- API Key Creation
CREATE OR REPLACE SECRET news_api_key
    TYPE = PASSWORD
    USERNAME = 'News-API-Key'
    PASSWORD = 'c494f280427646c78473013990b3cd45'
    ;

-- External Access Integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION news_api_integration
    ALLOWED_NETWORK_RULES = (news_api_network_rule)
    ALLOWED_AUTHENTICATION_SECRETS = (news_api_key)
    ENABLED = TRUE
    COMMENT = 'News API External Access Integration'
    ;

-- Can create a UDF for each endpoint to make it easy.
-- CREATE OR REPLACE FUNCTION GET_NEWS_API_ENDPOINT_EVERYTHING()