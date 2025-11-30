-- ========================================
-- ABS Database Schema
-- Index Creation DDL
-- ========================================
-- Description: 테이블별 인덱스 생성 스크립트
-- ========================================

-- ========================================
-- 1. routes 테이블 인덱스
-- ========================================

-- 활성화된 라우트 조회
CREATE INDEX idx_routes_is_active
ON routes(is_active);

-- 운영 모드별 라우트 조회
CREATE INDEX idx_routes_operation_mode
ON routes(operation_mode);

-- 활성화 + 운영 모드 복합 조회
CREATE INDEX idx_routes_is_active_operation_mode
ON routes(is_active, operation_mode);

-- ========================================
-- 2. comparisons 테이블 인덱스
-- ========================================

-- 외래키 조인 성능 향상
CREATE INDEX idx_comparisons_route_id
ON comparisons(route_id);

-- 시간대별 비교 결과 조회
CREATE INDEX idx_comparisons_created_at
ON comparisons(created_at DESC);

-- 라우트별 일치/불일치 결과 조회
CREATE INDEX idx_comparisons_route_id_is_match
ON comparisons(route_id, is_match);

-- 라우트별 최신 비교 결과 조회
CREATE INDEX idx_comparisons_route_id_created_at
ON comparisons(route_id, created_at DESC);

-- ========================================
-- 3. experiments 테이블 인덱스
-- ========================================

-- 외래키 조인 성능 향상
CREATE INDEX idx_experiments_route_id
ON experiments(route_id);

-- 상태별 실험 조회
CREATE INDEX idx_experiments_status
ON experiments(status);

-- 라우트별 진행 중인 실험 조회
CREATE INDEX idx_experiments_route_id_status
ON experiments(route_id, status);

-- 실험 생성 시간 기준 조회
CREATE INDEX idx_experiments_created_at
ON experiments(created_at DESC);

-- ========================================
-- 4. experiment_stages 테이블 인덱스
-- ========================================

-- 외래키 조인 성능 향상
CREATE INDEX idx_experiment_stages_experiment_id
ON experiment_stages(experiment_id);

-- 실험의 특정 단계 조회
CREATE INDEX idx_experiment_stages_experiment_id_stage
ON experiment_stages(experiment_id, stage);

-- 진행 중인 단계 조회
CREATE INDEX idx_experiment_stages_completed_at
ON experiment_stages(completed_at);
