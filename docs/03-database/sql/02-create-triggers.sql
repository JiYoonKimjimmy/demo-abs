-- ========================================
-- ABS Database Schema
-- Trigger Creation DDL
-- ========================================
-- Description: updated_at 컬럼 자동 갱신 트리거
-- ========================================

-- ========================================
-- 1. routes 테이블 트리거
-- ========================================
-- routes 테이블 수정 시 updated_at 자동 갱신

CREATE OR REPLACE TRIGGER trg_routes_updated_at
BEFORE UPDATE ON routes
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- ========================================
-- 2. experiments 테이블 트리거
-- ========================================
-- experiments 테이블 수정 시 updated_at 자동 갱신

CREATE OR REPLACE TRIGGER trg_experiments_updated_at
BEFORE UPDATE ON experiments
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/
