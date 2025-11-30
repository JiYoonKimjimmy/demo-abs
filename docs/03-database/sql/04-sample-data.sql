-- ========================================
-- ABS Database Schema
-- Sample Data Insert
-- ========================================
-- Description: 테스트 및 개발 환경용 샘플 데이터
-- ========================================

-- ========================================
-- 1. routes 테이블 샘플 데이터
-- ========================================

INSERT INTO routes (
    id, path, method, sample_size, exclude_fields,
    legacy_host, legacy_port, modern_host, modern_port,
    operation_mode, canary_percentage, is_active
) VALUES (
    'route-uuid-001',
    '/api/v1/users',
    'GET',
    100,
    '["timestamp", "requestId", "traceId"]',
    'api-host',
    8080,
    'api-host',
    9080,
    'validation',
    0,
    1
);

INSERT INTO routes (
    id, path, method, sample_size, exclude_fields,
    legacy_host, legacy_port, modern_host, modern_port,
    operation_mode, canary_percentage, is_active
) VALUES (
    'route-uuid-002',
    '/api/v1/orders',
    'POST',
    100,
    '["timestamp", "requestId", "serverTime"]',
    'api-host',
    8080,
    'api-host',
    9080,
    'validation',
    0,
    1
);

INSERT INTO routes (
    id, path, method, sample_size, exclude_fields,
    legacy_host, legacy_port, modern_host, modern_port,
    operation_mode, canary_percentage, is_active
) VALUES (
    'route-uuid-003',
    '/api/v1/products',
    'GET',
    100,
    '["timestamp"]',
    'api-host',
    8080,
    'api-host',
    9080,
    'canary',
    10,
    1
);

-- ========================================
-- 2. comparisons 테이블 샘플 데이터
-- ========================================

INSERT INTO comparisons (
    id, route_id, request_id,
    legacy_request_method, legacy_request_path, legacy_request_body,
    legacy_response_status, legacy_response_body, legacy_response_time,
    modern_request_method, modern_request_path, modern_request_body,
    modern_response_status, modern_response_body, modern_response_time,
    is_match, total_fields, matched_fields, field_match_rate,
    comparison_duration
) VALUES (
    'comparison-uuid-001',
    'route-uuid-001',
    'req-001',
    'GET',
    '/api/v1/users',
    NULL,
    200,
    '{"users": [{"id": 1, "name": "John"}]}',
    50,
    'GET',
    '/api/v1/users',
    NULL,
    200,
    '{"users": [{"id": 1, "name": "John"}]}',
    52,
    1,
    2,
    2,
    100.0,
    5
);

INSERT INTO comparisons (
    id, route_id, request_id,
    legacy_request_method, legacy_request_path, legacy_request_body,
    legacy_response_status, legacy_response_body, legacy_response_time,
    modern_request_method, modern_request_path, modern_request_body,
    modern_response_status, modern_response_body, modern_response_time,
    is_match, total_fields, matched_fields, field_match_rate,
    mismatch_details, comparison_duration
) VALUES (
    'comparison-uuid-002',
    'route-uuid-001',
    'req-002',
    'GET',
    '/api/v1/users',
    NULL,
    200,
    '{"users": [{"id": 2, "name": "Jane", "age": 30}]}',
    48,
    'GET',
    '/api/v1/users',
    NULL,
    200,
    '{"users": [{"id": 2, "name": "Jane", "age": "30"}]}',
    50,
    0,
    3,
    2,
    66.67,
    '[{"fieldPath": "users[0].age", "legacyValue": 30, "modernValue": "30", "expectedType": "number", "actualType": "string"}]',
    6
);

-- ========================================
-- 3. experiments 테이블 샘플 데이터
-- ========================================

INSERT INTO experiments (
    id, route_id, initial_percentage, current_percentage, target_percentage,
    stabilization_period, status, current_stage, total_stages,
    started_at
) VALUES (
    'experiment-uuid-001',
    'route-uuid-001',
    1,
    5,
    100,
    3600,
    'running',
    2,
    6,
    SYSTIMESTAMP - INTERVAL '2' HOUR
);

INSERT INTO experiments (
    id, route_id, initial_percentage, current_percentage, target_percentage,
    stabilization_period, status, current_stage, total_stages,
    completed_at
) VALUES (
    'experiment-uuid-002',
    'route-uuid-002',
    1,
    100,
    100,
    3600,
    'completed',
    6,
    6,
    SYSTIMESTAMP - INTERVAL '1' DAY
);

-- ========================================
-- 4. experiment_stages 테이블 샘플 데이터
-- ========================================

INSERT INTO experiment_stages (
    id, experiment_id, stage, traffic_percentage, min_requests,
    total_requests, match_rate, error_rate,
    legacy_avg_response_time, modern_avg_response_time,
    approved_by, approved_at, started_at, completed_at
) VALUES (
    'stage-uuid-001',
    'experiment-uuid-001',
    1,
    1,
    100,
    150,
    100.0,
    0.0,
    50,
    52,
    'admin@example.com',
    SYSTIMESTAMP - INTERVAL '90' MINUTE,
    SYSTIMESTAMP - INTERVAL '2' HOUR,
    SYSTIMESTAMP - INTERVAL '90' MINUTE
);

INSERT INTO experiment_stages (
    id, experiment_id, stage, traffic_percentage, min_requests,
    total_requests, match_rate, error_rate,
    legacy_avg_response_time, modern_avg_response_time,
    started_at
) VALUES (
    'stage-uuid-002',
    'experiment-uuid-001',
    2,
    5,
    500,
    320,
    99.9,
    0.05,
    50,
    53,
    SYSTIMESTAMP - INTERVAL '90' MINUTE
);

COMMIT;
