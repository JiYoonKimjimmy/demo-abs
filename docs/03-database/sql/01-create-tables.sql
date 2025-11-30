-- ========================================
-- ABS Database Schema
-- Table Creation DDL
-- ========================================
-- Description: API Bridge Service 테이블 생성 스크립트
-- DBMS: OracleDB 19c 이상
-- Character Set: UTF-8 (AL32UTF8)
-- Timezone: UTC
-- ========================================

-- ========================================
-- 1. routes 테이블
-- ========================================
-- API 라우트 정보를 관리하는 테이블

CREATE TABLE routes (
    id                    VARCHAR2(36)  NOT NULL,
    path                  VARCHAR2(500) NOT NULL,
    method                VARCHAR2(10)  NOT NULL,
    sample_size           NUMBER(10)    DEFAULT 100 NOT NULL,
    exclude_fields        CLOB,
    legacy_host           VARCHAR2(255) NOT NULL,
    legacy_port           NUMBER(5)     DEFAULT 8080 NOT NULL,
    modern_host           VARCHAR2(255) NOT NULL,
    modern_port           NUMBER(5)     DEFAULT 9080 NOT NULL,
    operation_mode        VARCHAR2(20)  DEFAULT 'validation' NOT NULL,
    canary_percentage     NUMBER(3)     DEFAULT 0 NOT NULL,
    match_rate            NUMBER(5,2)   DEFAULT 0.0 NOT NULL,
    total_requests        NUMBER(19)    DEFAULT 0 NOT NULL,
    matched_requests      NUMBER(19)    DEFAULT 0 NOT NULL,
    error_rate            NUMBER(5,2)   DEFAULT 0.0 NOT NULL,
    is_active             NUMBER(1)     DEFAULT 1 NOT NULL,
    created_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_routes PRIMARY KEY (id),
    CONSTRAINT uk_routes_path_method UNIQUE (path, method),
    CONSTRAINT ck_routes_sample_size CHECK (sample_size BETWEEN 10 AND 1000),
    CONSTRAINT ck_routes_canary_percentage CHECK (canary_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_routes_match_rate CHECK (match_rate BETWEEN 0.0 AND 100.0),
    CONSTRAINT ck_routes_error_rate CHECK (error_rate BETWEEN 0.0 AND 100.0),
    CONSTRAINT ck_routes_operation_mode CHECK (operation_mode IN ('validation', 'canary', 'switched')),
    CONSTRAINT ck_routes_is_active CHECK (is_active IN (0, 1))
);

COMMENT ON TABLE routes IS 'API 라우트 정보';
COMMENT ON COLUMN routes.id IS '라우트 고유 식별자 (UUID)';
COMMENT ON COLUMN routes.path IS 'API 경로 (예: /api/v1/users)';
COMMENT ON COLUMN routes.method IS 'HTTP 메서드 (GET, POST, PUT, DELETE 등)';
COMMENT ON COLUMN routes.sample_size IS '일치율 계산 표본 수 (10-1000)';
COMMENT ON COLUMN routes.exclude_fields IS '비교 제외 필드 목록 (JSON 배열)';
COMMENT ON COLUMN routes.legacy_host IS 'Legacy API 호스트';
COMMENT ON COLUMN routes.legacy_port IS 'Legacy API 포트';
COMMENT ON COLUMN routes.modern_host IS 'Modern API 호스트';
COMMENT ON COLUMN routes.modern_port IS 'Modern API 포트';
COMMENT ON COLUMN routes.operation_mode IS '운영 모드 (validation/canary/switched)';
COMMENT ON COLUMN routes.canary_percentage IS 'Canary 모드 시 트래픽 비율 (0-100)';
COMMENT ON COLUMN routes.match_rate IS '현재 일치율 (0.0-100.0)';
COMMENT ON COLUMN routes.total_requests IS '총 요청 수';
COMMENT ON COLUMN routes.matched_requests IS '일치한 요청 수';
COMMENT ON COLUMN routes.error_rate IS 'Modern API 에러율 (0.0-100.0)';
COMMENT ON COLUMN routes.is_active IS '라우트 활성화 여부 (0: 비활성, 1: 활성)';

-- ========================================
-- 2. comparisons 테이블
-- ========================================
-- Legacy API와 Modern API의 응답 비교 결과를 저장하는 테이블

CREATE TABLE comparisons (
    id                     VARCHAR2(36)  NOT NULL,
    route_id               VARCHAR2(36)  NOT NULL,
    request_id             VARCHAR2(100) NOT NULL,
    legacy_request_method  VARCHAR2(10)  NOT NULL,
    legacy_request_path    VARCHAR2(500) NOT NULL,
    legacy_request_body    CLOB,
    legacy_response_status NUMBER(3)     NOT NULL,
    legacy_response_body   CLOB,
    legacy_response_time   NUMBER(10)    NOT NULL,
    modern_request_method  VARCHAR2(10)  NOT NULL,
    modern_request_path    VARCHAR2(500) NOT NULL,
    modern_request_body    CLOB,
    modern_response_status NUMBER(3),
    modern_response_body   CLOB,
    modern_response_time   NUMBER(10),
    modern_error           VARCHAR2(1000),
    is_match               NUMBER(1)     NOT NULL,
    total_fields           NUMBER(10)    DEFAULT 0 NOT NULL,
    matched_fields         NUMBER(10)    DEFAULT 0 NOT NULL,
    field_match_rate       NUMBER(5,2)   DEFAULT 0.0 NOT NULL,
    mismatch_details       CLOB,
    comparison_duration    NUMBER(10)    DEFAULT 0 NOT NULL,
    created_at             TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_comparisons PRIMARY KEY (id),
    CONSTRAINT fk_comparisons_routes FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
    CONSTRAINT ck_comparisons_is_match CHECK (is_match IN (0, 1)),
    CONSTRAINT ck_comparisons_field_match_rate CHECK (field_match_rate BETWEEN 0.0 AND 100.0)
);

COMMENT ON TABLE comparisons IS 'API 응답 비교 결과';
COMMENT ON COLUMN comparisons.id IS '비교 결과 고유 식별자 (UUID)';
COMMENT ON COLUMN comparisons.route_id IS '라우트 ID (FK)';
COMMENT ON COLUMN comparisons.request_id IS '요청 추적 ID';
COMMENT ON COLUMN comparisons.legacy_request_method IS 'Legacy API 요청 메서드';
COMMENT ON COLUMN comparisons.legacy_request_path IS 'Legacy API 요청 경로';
COMMENT ON COLUMN comparisons.legacy_request_body IS 'Legacy API 요청 본문 (JSON)';
COMMENT ON COLUMN comparisons.legacy_response_status IS 'Legacy API 응답 상태 코드';
COMMENT ON COLUMN comparisons.legacy_response_body IS 'Legacy API 응답 본문 (JSON)';
COMMENT ON COLUMN comparisons.legacy_response_time IS 'Legacy API 응답 시간 (ms)';
COMMENT ON COLUMN comparisons.modern_request_method IS 'Modern API 요청 메서드';
COMMENT ON COLUMN comparisons.modern_request_path IS 'Modern API 요청 경로';
COMMENT ON COLUMN comparisons.modern_request_body IS 'Modern API 요청 본문 (JSON)';
COMMENT ON COLUMN comparisons.modern_response_status IS 'Modern API 응답 상태 코드';
COMMENT ON COLUMN comparisons.modern_response_body IS 'Modern API 응답 본문 (JSON)';
COMMENT ON COLUMN comparisons.modern_response_time IS 'Modern API 응답 시간 (ms)';
COMMENT ON COLUMN comparisons.modern_error IS 'Modern API 에러 메시지';
COMMENT ON COLUMN comparisons.is_match IS '응답 일치 여부 (0: 불일치, 1: 일치)';
COMMENT ON COLUMN comparisons.total_fields IS '총 필드 수';
COMMENT ON COLUMN comparisons.matched_fields IS '일치한 필드 수';
COMMENT ON COLUMN comparisons.field_match_rate IS '필드 일치율 (0.0-100.0)';
COMMENT ON COLUMN comparisons.mismatch_details IS '불일치 상세 정보 (JSON 배열)';
COMMENT ON COLUMN comparisons.comparison_duration IS '비교 소요 시간 (ms)';

-- ========================================
-- 3. experiments 테이블
-- ========================================
-- 반자동 전환 실험을 관리하는 테이블

CREATE TABLE experiments (
    id                    VARCHAR2(36)  NOT NULL,
    route_id              VARCHAR2(36)  NOT NULL,
    initial_percentage    NUMBER(3)     NOT NULL,
    current_percentage    NUMBER(3)     NOT NULL,
    target_percentage     NUMBER(3)     DEFAULT 100 NOT NULL,
    stabilization_period  NUMBER(10)    DEFAULT 3600 NOT NULL,
    status                VARCHAR2(20)  DEFAULT 'pending' NOT NULL,
    current_stage         NUMBER(3)     DEFAULT 1 NOT NULL,
    total_stages          NUMBER(3)     DEFAULT 6 NOT NULL,
    last_approved_by      VARCHAR2(255),
    last_approved_at      TIMESTAMP(6) WITH TIME ZONE,
    started_at            TIMESTAMP(6) WITH TIME ZONE,
    completed_at          TIMESTAMP(6) WITH TIME ZONE,
    aborted_reason        VARCHAR2(1000),
    created_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_experiments PRIMARY KEY (id),
    CONSTRAINT fk_experiments_routes FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
    CONSTRAINT ck_experiments_initial_percentage CHECK (initial_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_experiments_current_percentage CHECK (current_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_experiments_target_percentage CHECK (target_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_experiments_stabilization_period CHECK (stabilization_period >= 3600),
    CONSTRAINT ck_experiments_status CHECK (status IN ('pending', 'running', 'paused', 'completed', 'aborted')),
    CONSTRAINT ck_experiments_current_stage CHECK (current_stage BETWEEN 1 AND 6),
    CONSTRAINT ck_experiments_total_stages CHECK (total_stages BETWEEN 1 AND 6)
);

COMMENT ON TABLE experiments IS '반자동 전환 실험';
COMMENT ON COLUMN experiments.id IS '실험 고유 식별자 (UUID)';
COMMENT ON COLUMN experiments.route_id IS '라우트 ID (FK)';
COMMENT ON COLUMN experiments.initial_percentage IS '시작 트래픽 비율 (%)';
COMMENT ON COLUMN experiments.current_percentage IS '현재 트래픽 비율 (%)';
COMMENT ON COLUMN experiments.target_percentage IS '목표 트래픽 비율 (%)';
COMMENT ON COLUMN experiments.stabilization_period IS '안정화 기간 (초)';
COMMENT ON COLUMN experiments.status IS '실험 상태 (pending/running/paused/completed/aborted)';
COMMENT ON COLUMN experiments.current_stage IS '현재 단계 (1-6)';
COMMENT ON COLUMN experiments.total_stages IS '전체 단계 수';
COMMENT ON COLUMN experiments.last_approved_by IS '마지막 승인자';
COMMENT ON COLUMN experiments.last_approved_at IS '마지막 승인 시간';
COMMENT ON COLUMN experiments.started_at IS '실험 시작 시간';
COMMENT ON COLUMN experiments.completed_at IS '실험 완료 시간';
COMMENT ON COLUMN experiments.aborted_reason IS '중단 사유';

-- ========================================
-- 4. experiment_stages 테이블
-- ========================================
-- 실험 단계별 이력 및 메트릭을 기록하는 테이블

CREATE TABLE experiment_stages (
    id                        VARCHAR2(36)  NOT NULL,
    experiment_id             VARCHAR2(36)  NOT NULL,
    stage                     NUMBER(3)     NOT NULL,
    traffic_percentage        NUMBER(3)     NOT NULL,
    min_requests              NUMBER(10)    NOT NULL,
    total_requests            NUMBER(19)    DEFAULT 0 NOT NULL,
    match_rate                NUMBER(5,2)   DEFAULT 0.0 NOT NULL,
    error_rate                NUMBER(5,2)   DEFAULT 0.0 NOT NULL,
    legacy_avg_response_time  NUMBER(10)    DEFAULT 0 NOT NULL,
    modern_avg_response_time  NUMBER(10)    DEFAULT 0 NOT NULL,
    approved_by               VARCHAR2(255),
    approved_at               TIMESTAMP(6) WITH TIME ZONE,
    started_at                TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    completed_at              TIMESTAMP(6) WITH TIME ZONE,
    rollback_reason           VARCHAR2(1000),
    is_rollback               NUMBER(1)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_experiment_stages PRIMARY KEY (id),
    CONSTRAINT fk_experiment_stages_experiments FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
    CONSTRAINT ck_experiment_stages_stage CHECK (stage BETWEEN 1 AND 6),
    CONSTRAINT ck_experiment_stages_traffic_percentage CHECK (traffic_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_experiment_stages_match_rate CHECK (match_rate BETWEEN 0.0 AND 100.0),
    CONSTRAINT ck_experiment_stages_error_rate CHECK (error_rate BETWEEN 0.0 AND 100.0),
    CONSTRAINT ck_experiment_stages_is_rollback CHECK (is_rollback IN (0, 1))
);

COMMENT ON TABLE experiment_stages IS '실험 단계별 이력';
COMMENT ON COLUMN experiment_stages.id IS '단계 고유 식별자 (UUID)';
COMMENT ON COLUMN experiment_stages.experiment_id IS '실험 ID (FK)';
COMMENT ON COLUMN experiment_stages.stage IS '단계 번호 (1-6)';
COMMENT ON COLUMN experiment_stages.traffic_percentage IS '트래픽 비율 (%)';
COMMENT ON COLUMN experiment_stages.min_requests IS '최소 요청 수';
COMMENT ON COLUMN experiment_stages.total_requests IS '처리된 총 요청 수';
COMMENT ON COLUMN experiment_stages.match_rate IS '일치율 (%)';
COMMENT ON COLUMN experiment_stages.error_rate IS '에러율 (%)';
COMMENT ON COLUMN experiment_stages.legacy_avg_response_time IS 'Legacy 평균 응답 시간 (ms)';
COMMENT ON COLUMN experiment_stages.modern_avg_response_time IS 'Modern 평균 응답 시간 (ms)';
COMMENT ON COLUMN experiment_stages.approved_by IS '승인자';
COMMENT ON COLUMN experiment_stages.approved_at IS '승인 시간';
COMMENT ON COLUMN experiment_stages.started_at IS '단계 시작 시간';
COMMENT ON COLUMN experiment_stages.completed_at IS '단계 완료 시간';
COMMENT ON COLUMN experiment_stages.rollback_reason IS '롤백 사유';
COMMENT ON COLUMN experiment_stages.is_rollback IS '롤백 여부 (0: 정상, 1: 롤백)';
