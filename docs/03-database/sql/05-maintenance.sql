-- ========================================
-- ABS Database Schema
-- Maintenance Queries
-- ========================================
-- Description: 데이터 삭제, 통계 갱신, 인덱스 재생성 등 유지보수 쿼리
-- ========================================

-- ========================================
-- 1. 데이터 보관 정책에 따른 삭제
-- ========================================

-- comparisons 테이블: 30일 이전 데이터 삭제
DELETE FROM comparisons
WHERE created_at < SYSTIMESTAMP - INTERVAL '30' DAY;

-- experiments 테이블: 1년 이전 완료/중단 실험 삭제
DELETE FROM experiments
WHERE created_at < SYSTIMESTAMP - INTERVAL '1' YEAR
  AND status IN ('completed', 'aborted');

-- ========================================
-- 2. 통계 정보 갱신
-- ========================================

-- routes 테이블 통계 갱신
EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname => USER,
    tabname => 'ROUTES',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO'
);

-- comparisons 테이블 통계 갱신
EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname => USER,
    tabname => 'COMPARISONS',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO'
);

-- experiments 테이블 통계 갱신
EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname => USER,
    tabname => 'EXPERIMENTS',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO'
);

-- experiment_stages 테이블 통계 갱신
EXEC DBMS_STATS.GATHER_TABLE_STATS(
    ownname => USER,
    tabname => 'EXPERIMENT_STAGES',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO'
);

-- ========================================
-- 3. 인덱스 재생성 (단편화 해소)
-- ========================================

-- routes 테이블 인덱스
ALTER INDEX idx_routes_is_active REBUILD ONLINE;
ALTER INDEX idx_routes_operation_mode REBUILD ONLINE;
ALTER INDEX idx_routes_is_active_operation_mode REBUILD ONLINE;

-- comparisons 테이블 인덱스
ALTER INDEX idx_comparisons_route_id REBUILD ONLINE;
ALTER INDEX idx_comparisons_created_at REBUILD ONLINE;
ALTER INDEX idx_comparisons_route_id_is_match REBUILD ONLINE;
ALTER INDEX idx_comparisons_route_id_created_at REBUILD ONLINE;

-- experiments 테이블 인덱스
ALTER INDEX idx_experiments_route_id REBUILD ONLINE;
ALTER INDEX idx_experiments_status REBUILD ONLINE;
ALTER INDEX idx_experiments_route_id_status REBUILD ONLINE;
ALTER INDEX idx_experiments_created_at REBUILD ONLINE;

-- experiment_stages 테이블 인덱스
ALTER INDEX idx_experiment_stages_experiment_id REBUILD ONLINE;
ALTER INDEX idx_experiment_stages_experiment_id_stage REBUILD ONLINE;
ALTER INDEX idx_experiment_stages_completed_at REBUILD ONLINE;

-- ========================================
-- 4. 인덱스 통계 갱신
-- ========================================

-- routes 테이블 인덱스 통계
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_ROUTES_IS_ACTIVE');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_ROUTES_OPERATION_MODE');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_ROUTES_IS_ACTIVE_OPERATION_MODE');

-- comparisons 테이블 인덱스 통계
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_COMPARISONS_ROUTE_ID');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_COMPARISONS_CREATED_AT');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_COMPARISONS_ROUTE_ID_IS_MATCH');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_COMPARISONS_ROUTE_ID_CREATED_AT');

-- experiments 테이블 인덱스 통계
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENTS_ROUTE_ID');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENTS_STATUS');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENTS_ROUTE_ID_STATUS');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENTS_CREATED_AT');

-- experiment_stages 테이블 인덱스 통계
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENT_STAGES_EXPERIMENT_ID');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENT_STAGES_EXPERIMENT_ID_STAGE');
EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => USER, indname => 'IDX_EXPERIMENT_STAGES_COMPLETED_AT');

-- ========================================
-- 5. 파티션 관리 (comparisons 테이블 파티셔닝 사용 시)
-- ========================================

-- 월별 파티션 추가 (매월 초 실행)
-- 예: 2025년 4월 파티션 추가
-- ALTER TABLE comparisons
-- ADD PARTITION comparisons_2025_04 VALUES LESS THAN (TIMESTAMP '2025-05-01 00:00:00');

-- 오래된 파티션 삭제 (30일 이전 데이터)
-- 예: 2024년 11월 파티션 삭제
-- ALTER TABLE comparisons
-- DROP PARTITION comparisons_2024_11;

-- ========================================
-- 6. 안전한 데이터 삭제 (논리 삭제)
-- ========================================

-- 라우트 비활성화 (물리 삭제 대신)
-- UPDATE routes
-- SET is_active = 0, updated_at = SYSTIMESTAMP
-- WHERE id = :route_id;

-- 실험 중단 (물리 삭제 대신)
-- UPDATE experiments
-- SET status = 'aborted',
--     aborted_reason = '관리자 수동 중단',
--     updated_at = SYSTIMESTAMP
-- WHERE id = :experiment_id;

-- ========================================
-- 7. 인덱스 사용률 모니터링
-- ========================================

-- 인덱스 모니터링 활성화
-- ALTER INDEX idx_routes_is_active MONITORING USAGE;

-- 인덱스 사용 여부 확인
-- SELECT
--     index_name,
--     table_name,
--     monitoring,
--     used
-- FROM v$object_usage
-- WHERE index_name = 'IDX_ROUTES_IS_ACTIVE';

-- 인덱스 모니터링 비활성화
-- ALTER INDEX idx_routes_is_active NOMONITORING USAGE;

-- ========================================
-- 8. 테이블 및 인덱스 정보 조회
-- ========================================

-- 테이블 크기 조회
SELECT
    segment_name AS table_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM user_segments
WHERE segment_type = 'TABLE'
  AND segment_name IN ('ROUTES', 'COMPARISONS', 'EXPERIMENTS', 'EXPERIMENT_STAGES')
ORDER BY bytes DESC;

-- 인덱스 크기 조회
SELECT
    segment_name AS index_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM user_segments
WHERE segment_type = 'INDEX'
  AND segment_name LIKE 'IDX_%'
ORDER BY bytes DESC;

-- 인덱스 정보 조회
SELECT
    index_name,
    table_name,
    num_rows,
    distinct_keys,
    clustering_factor,
    last_analyzed
FROM user_indexes
WHERE table_name IN ('ROUTES', 'COMPARISONS', 'EXPERIMENTS', 'EXPERIMENT_STAGES')
ORDER BY table_name, index_name;
