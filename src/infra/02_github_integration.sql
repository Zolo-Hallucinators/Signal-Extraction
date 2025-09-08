// Following documentation from: https://docs.snowflake.com/en/developer-guide/git/git-setting-up#label-git-setup-token

USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

CREATE OR REPLACE SECRET my_git_token_secret
    TYPE = PASSWORD
    USERNAME = 'Snowflake-Signal-Extraction'
    PASSWORD = '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'
    ;

CREATE OR REPLACE API INTEGRATION github_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/Zolo-Hallucinators/Signal-Extraction.git')
  ALLOWED_AUTHENTICATION_SECRETS = (my_git_token_secret)
  ENABLED = TRUE
  COMMENT = 'Integration to connect git'
  ;