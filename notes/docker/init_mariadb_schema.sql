-- ==============================================================================
-- ASSA Middleware — MariaDB Database Schema
-- Database: assa_middleware_db
-- Standar: Idempotency, Transaction Tracking, 3x Retry Log, Async Retry Queue
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS assa_middleware_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE assa_middleware_db;

-- ------------------------------------------------------------------------------
-- 1. Tabel Transaksi Utama (api_transaction)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(100) NULL,
    endpoint VARCHAR(255) NOT NULL,
    http_method VARCHAR(10) NOT NULL DEFAULT 'GET',
    request_payload LONGTEXT NULL,
    response_payload LONGTEXT NULL,
    status ENUM('PENDING', 'PROCESSING', 'SUCCESS', 'RETRY', 'FAILED') NOT NULL DEFAULT 'PENDING',
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    retry_interval_seconds INT NOT NULL DEFAULT 60,
    next_retry_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_transaction_id (transaction_id),
    INDEX idx_status_next_retry (status, next_retry_at),
    INDEX idx_idempotency (idempotency_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------------------------
-- 2. Tabel Log Attempt Percobaan Hit (api_transaction_log)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_transaction_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    attempt_number INT NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    request_payload LONGTEXT NULL,
    response_status INT NULL,
    response_body LONGTEXT NULL,
    error_message TEXT NULL,
    duration_ms INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trx_id (transaction_id),
    CONSTRAINT fk_trx_id
        FOREIGN KEY (transaction_id)
        REFERENCES api_transaction (transaction_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
