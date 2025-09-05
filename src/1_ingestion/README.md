# Ingestion Notes
- Need to ingest from 2 types of sources
    1. Real Time Price  
        - Need to figure out APIs that can give more features/indicators along with lower latency.
    2. News Data
        - Need to find more APIs that can give quality articles and location specific ones(India).
- Complete Ingestion process needs to be worked out using a Snowflake framework, planning to create to separate pipelines:
    1. Batch Processing Pipeline (less pricing)
    2. Real-Time Processing Pipeline (more pricy, but can be batches of lower time intervals, making it nearly real-time)
- Need to perform transformation and feature generation as well.