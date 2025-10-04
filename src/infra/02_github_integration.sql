-- Following documentation from: https://docs.snowflake.com/en/developer-guide/git/git-setting-up#label-git-setup-token

USE ROLE ACCOUNTADMIN;
USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

-- Base to create secrets
CREATE OR REPLACE SECRET my_git_token_secret
    TYPE = PASSWORD
    USERNAME = 'Snowflake-Signal-Extraction'
    PASSWORD = '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'
    ;
    
SHOW SECRETS;

-- Creating git integration
CREATE OR REPLACE API INTEGRATION github_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/Zolo-Hallucinators')
  ALLOWED_AUTHENTICATION_SECRETS = (my_git_token_secret)
  ENABLED = TRUE
  COMMENT = 'Integration to connect git'
  ;

SHOW API INTEGRATIONS;
SHOW INTEGRATIONS;

-- creating the git repo so that we can view and access in the utils schema.
CREATE OR REPLACE GIT REPOSITORY SIGNAL_EXTRACTION_REPO
    API_INTEGRATION = github_integration
    GIT_CREDENTIALS = my_git_token_secret
    ORIGIN = 'https://github.com/Zolo-Hallucinators/Signal-Extraction'

-- SHOW GIT REPOSITORIES; -- Didn't work.
-- Finally: When adding the 'Git Repository' to the workspace, for the 'Credentials secret', go to SIGNAL_EXTRACTION_DB > UTILS > my_git_token_secret