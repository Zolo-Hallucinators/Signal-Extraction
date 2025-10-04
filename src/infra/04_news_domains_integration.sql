USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

-- Network Rule Creation
CREATE OR REPLACE NETWORK RULE news_domains_nr -- hard coded in ensure_network_rule_for_domain()
    MODE = EGRESS   -- means outbound traffice FROM snowflake to external is allowed.
    TYPE = HOST_PORT
    VALUE_LIST = ('finance.yahoo.com', 'www.activistpost.com')
    ;

-- External Access Integration (Mandatory one-time creation needed)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION news_domains_integration -- hard coded in ensure_network_rule_for_domain()
    ALLOWED_NETWORK_RULES = (news_domains_nr)
    ENABLED = TRUE
    COMMENT = 'Dynamic Integration to add network rules through code'
    ;

-- To view the latest changes made to the integration
DESCRIBE EXTERNAL ACCESS INTEGRATION news_domains_integration;
DESCRIBE NETWORK RULE news_domains_nr; --value_list only able to be retrieved from here.
SHOW NETWORK RULES LIKE 'news_domains_nr';
SELECT VALUE_LIST 
FROM INFORMATION_SCHEMA.NETWORK_RULES 
WHERE NETWORK_RULE_NAME = 'news_domains_nr';