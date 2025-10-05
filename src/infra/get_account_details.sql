-- To get the actual info that you need in the form of a json go to. 
-- Tap Profile(bottom left) > Account > 'View Account Details' > 'Config File' > (Switch to passwork based approace, add schema if needed)

-- Some base code to get some info
SELECT CURRENT_ACCOUNT() AS account,
       CURRENT_USER() AS user,
       CURRENT_ROLE() AS role,
       CURRENT_WAREHOUSE() AS warehouse,
       CURRENT_DATABASE() AS database,
       CURRENT_SCHEMA() AS schema;