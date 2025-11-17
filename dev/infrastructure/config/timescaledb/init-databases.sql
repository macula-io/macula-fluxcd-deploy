-- TimescaleDB Initialization Script
-- Creates databases for Macula applications with TimescaleDB extension

-- Note: Default database 'macula' is already created by POSTGRES_DB env var

-- Create database for Macula Console (Phoenix LiveView app)
CREATE DATABASE macula_console;
\c macula_console
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create database for CortexIQ Energy Exchange
CREATE DATABASE cortexiq_exchange;
\c cortexiq_exchange
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Switch back to default database and enable extension
\c macula
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create a monitoring user for Prometheus postgres_exporter (optional)
-- CREATE USER postgres_exporter WITH PASSWORD 'exporter-password';
-- GRANT pg_monitor TO postgres_exporter;

-- Log completion
SELECT 'TimescaleDB initialization complete' AS status;
