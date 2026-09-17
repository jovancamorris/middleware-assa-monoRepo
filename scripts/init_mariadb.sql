-- ==============================================================================
-- ASSA Middleware Database Initialization Script
-- Target Database: MariaDB (Port 3307)
-- Database Name  : assa_middleware_db
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS assa_middleware_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE assa_middleware_db;

-- ------------------------------------------------------------------------------
-- 1. Main Transaction Table (api_transaction)
-- Mencatat seluruh transaksi utama yang diproses oleh ASSA Middleware.
-- Mendukung Idempotency, Retry State Tracking, dan Asynchronous Queue.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL UNIQUE,
    idempotency_key VARCHAR(100) NULL,
    endpoint VARCHAR(255) NOT NULL,
    http_method VARCHAR(10) DEFAULT 'GET',
    request_payload MEDIUMTEXT NULL,
    response_payload MEDIUMTEXT NULL,
    status ENUM('PENDING', 'PROCESSING', 'SUCCESS', 'RETRY', 'FAILED') NOT NULL DEFAULT 'PENDING',
    attempt_count INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    retry_interval_seconds INT DEFAULT 60,
    next_retry_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_trx_id (transaction_id),
    INDEX idx_idempotency (idempotency_key),
    INDEX idx_status_retry (status, next_retry_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------------------------
-- 2. Transaction Audit & Attempt Log Table (api_transaction_log)
-- Mencatat riwayat setiap percobaan (attempt 1, 2, 3...) pemanggilan external API.
-- Menyimpan status HTTP, response body, pesan error, serta latency (duration_ms).
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_transaction_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    attempt_number INT NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    request_payload MEDIUMTEXT NULL,
    response_status INT NULL,
    response_body MEDIUMTEXT NULL,
    error_message TEXT NULL,
    duration_ms INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log_trx_id (transaction_id),
    INDEX idx_log_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
