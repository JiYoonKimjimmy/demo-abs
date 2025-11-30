# 데이터베이스 스키마 설계

## 문서 목적

본 문서는 ABS의 OracleDB 테이블 스키마를 정의합니다.

**포함 내용**:
- 테이블 스키마 정의
- 데이터 타입 및 제약조건
- 외래키 관계
- 데이터 보관 정책

**SQL 파일 위치**: `docs/03-database/sql/`

---

## 1. 데이터베이스 개요

### 1.1 DBMS
- **제품**: OracleDB 19c 이상
- **문자셋**: UTF-8 (AL32UTF8)
- **타임존**: UTC

### 1.2 네이밍 규칙

| 항목 | 규칙 | 예시 |
|------|------|------|
| **테이블** | 복수형 소문자, 언더스코어 구분 | `routes`, `experiment_stages` |
| **컬럼** | 소문자, 언더스코어 구분 | `route_id`, `created_at` |
| **Primary Key** | `pk_{테이블명}` | `pk_routes` |
| **Foreign Key** | `fk_{테이블명}_{참조테이블}` | `fk_comparisons_routes` |
| **Index** | `idx_{테이블명}_{컬럼명}` | `idx_routes_path_method` |
| **Sequence** | `seq_{테이블명}_id` | `seq_routes_id` |

### 1.3 공통 컬럼

모든 엔티티 테이블에 포함되는 컬럼:

| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| `created_at` | `TIMESTAMP WITH TIME ZONE` | 생성 시간 (UTC) |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | 수정 시간 (UTC) |

---

## 2. 테이블 스키마

### 2.1 routes 테이블

API 라우트 정보를 관리하는 테이블입니다.

#### 컬럼 정의

| 컬럼명 | 타입 | Null | 기본값 | 설명 |
|--------|------|------|--------|------|
| `id` | VARCHAR2(36) | NOT NULL | - | UUID v4 |
| `path` | VARCHAR2(500) | NOT NULL | - | API 경로 |
| `method` | VARCHAR2(10) | NOT NULL | - | HTTP 메서드 |
| `sample_size` | NUMBER(10) | NOT NULL | 100 | 표본 크기 (10-1000) |
| `exclude_fields` | CLOB | NULL | NULL | JSON 배열 형식 |
| `legacy_host` | VARCHAR2(255) | NOT NULL | - | Legacy 호스트 |
| `legacy_port` | NUMBER(5) | NOT NULL | 8080 | Legacy 포트 |
| `modern_host` | VARCHAR2(255) | NOT NULL | - | Modern 호스트 |
| `modern_port` | NUMBER(5) | NOT NULL | 9080 | Modern 포트 |
| `operation_mode` | VARCHAR2(20) | NOT NULL | 'validation' | 운영 모드 |
| `canary_percentage` | NUMBER(3) | NOT NULL | 0 | Canary 비율 (0-100) |
| `match_rate` | NUMBER(5,2) | NOT NULL | 0.0 | 일치율 (0.0-100.0) |
| `total_requests` | NUMBER(19) | NOT NULL | 0 | 총 요청 수 |
| `matched_requests` | NUMBER(19) | NOT NULL | 0 | 일치 요청 수 |
| `error_rate` | NUMBER(5,2) | NOT NULL | 0.0 | 에러율 (0.0-100.0) |
| `is_active` | NUMBER(1) | NOT NULL | 1 | 활성화 여부 |
| `created_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 생성 시간 |
| `updated_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 수정 시간 |

#### 제약조건

- **PK**: `pk_routes` (id)
- **UK**: `uk_routes_path_method` (path, method)
- **CHECK**:
  - `sample_size`: 10 ~ 1,000
  - `canary_percentage`: 0 ~ 100
  - `match_rate`: 0.0 ~ 100.0
  - `error_rate`: 0.0 ~ 100.0
  - `operation_mode`: validation / canary / switched
  - `is_active`: 0 / 1

---

### 2.2 comparisons 테이블

Legacy API와 Modern API의 응답 비교 결과를 저장하는 테이블입니다.

#### 컬럼 정의

| 컬럼명 | 타입 | Null | 기본값 | 설명 |
|--------|------|------|--------|------|
| `id` | VARCHAR2(36) | NOT NULL | - | UUID v4 |
| `route_id` | VARCHAR2(36) | NOT NULL | - | 외래키 (routes.id) |
| `request_id` | VARCHAR2(100) | NOT NULL | - | 요청 추적 ID |
| `legacy_request_method` | VARCHAR2(10) | NOT NULL | - | Legacy 요청 메서드 |
| `legacy_request_path` | VARCHAR2(500) | NOT NULL | - | Legacy 요청 경로 |
| `legacy_request_body` | CLOB | NULL | NULL | Legacy 요청 본문 |
| `legacy_response_status` | NUMBER(3) | NOT NULL | - | Legacy 응답 상태 |
| `legacy_response_body` | CLOB | NULL | NULL | Legacy 응답 본문 |
| `legacy_response_time` | NUMBER(10) | NOT NULL | - | Legacy 응답 시간 (ms) |
| `modern_request_method` | VARCHAR2(10) | NOT NULL | - | Modern 요청 메서드 |
| `modern_request_path` | VARCHAR2(500) | NOT NULL | - | Modern 요청 경로 |
| `modern_request_body` | CLOB | NULL | NULL | Modern 요청 본문 |
| `modern_response_status` | NUMBER(3) | NULL | NULL | Modern 응답 상태 |
| `modern_response_body` | CLOB | NULL | NULL | Modern 응답 본문 |
| `modern_response_time` | NUMBER(10) | NULL | NULL | Modern 응답 시간 (ms) |
| `modern_error` | VARCHAR2(1000) | NULL | NULL | Modern 에러 메시지 |
| `is_match` | NUMBER(1) | NOT NULL | - | 일치 여부 (0/1) |
| `total_fields` | NUMBER(10) | NOT NULL | 0 | 총 필드 수 |
| `matched_fields` | NUMBER(10) | NOT NULL | 0 | 일치 필드 수 |
| `field_match_rate` | NUMBER(5,2) | NOT NULL | 0.0 | 필드 일치율 |
| `mismatch_details` | CLOB | NULL | NULL | 불일치 상세 (JSON) |
| `comparison_duration` | NUMBER(10) | NOT NULL | 0 | 비교 시간 (ms) |
| `created_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 생성 시간 |

#### 제약조건

- **PK**: `pk_comparisons` (id)
- **FK**: `fk_comparisons_routes` (route_id → routes.id) ON DELETE CASCADE
- **CHECK**:
  - `is_match`: 0 / 1
  - `field_match_rate`: 0.0 ~ 100.0

---

### 2.3 experiments 테이블

반자동 전환 실험을 관리하는 테이블입니다.

#### 컬럼 정의

| 컬럼명 | 타입 | Null | 기본값 | 설명 |
|--------|------|------|--------|------|
| `id` | VARCHAR2(36) | NOT NULL | - | UUID v4 |
| `route_id` | VARCHAR2(36) | NOT NULL | - | 외래키 (routes.id) |
| `initial_percentage` | NUMBER(3) | NOT NULL | - | 시작 비율 (0-100) |
| `current_percentage` | NUMBER(3) | NOT NULL | - | 현재 비율 (0-100) |
| `target_percentage` | NUMBER(3) | NOT NULL | 100 | 목표 비율 |
| `stabilization_period` | NUMBER(10) | NOT NULL | 3600 | 안정화 기간 (초) |
| `status` | VARCHAR2(20) | NOT NULL | 'pending' | 상태 |
| `current_stage` | NUMBER(3) | NOT NULL | 1 | 현재 단계 |
| `total_stages` | NUMBER(3) | NOT NULL | 6 | 전체 단계 수 |
| `last_approved_by` | VARCHAR2(255) | NULL | NULL | 승인자 |
| `last_approved_at` | TIMESTAMP(6) WITH TIME ZONE | NULL | NULL | 승인 시간 |
| `started_at` | TIMESTAMP(6) WITH TIME ZONE | NULL | NULL | 시작 시간 |
| `completed_at` | TIMESTAMP(6) WITH TIME ZONE | NULL | NULL | 완료 시간 |
| `aborted_reason` | VARCHAR2(1000) | NULL | NULL | 중단 사유 |
| `created_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 생성 시간 |
| `updated_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 수정 시간 |

#### 제약조건

- **PK**: `pk_experiments` (id)
- **FK**: `fk_experiments_routes` (route_id → routes.id) ON DELETE CASCADE
- **CHECK**:
  - `initial_percentage`: 0 ~ 100
  - `current_percentage`: 0 ~ 100
  - `target_percentage`: 0 ~ 100
  - `stabilization_period`: >= 3600초
  - `status`: pending / running / paused / completed / aborted
  - `current_stage`: 1 ~ 6
  - `total_stages`: 1 ~ 6

---

### 2.4 experiment_stages 테이블

실험 단계별 이력 및 메트릭을 기록하는 테이블입니다.

#### 컬럼 정의

| 컬럼명 | 타입 | Null | 기본값 | 설명 |
|--------|------|------|--------|------|
| `id` | VARCHAR2(36) | NOT NULL | - | UUID v4 |
| `experiment_id` | VARCHAR2(36) | NOT NULL | - | 외래키 (experiments.id) |
| `stage` | NUMBER(3) | NOT NULL | - | 단계 번호 (1-6) |
| `traffic_percentage` | NUMBER(3) | NOT NULL | - | 트래픽 비율 |
| `min_requests` | NUMBER(10) | NOT NULL | - | 최소 요청 수 |
| `total_requests` | NUMBER(19) | NOT NULL | 0 | 총 요청 수 |
| `match_rate` | NUMBER(5,2) | NOT NULL | 0.0 | 일치율 |
| `error_rate` | NUMBER(5,2) | NOT NULL | 0.0 | 에러율 |
| `legacy_avg_response_time` | NUMBER(10) | NOT NULL | 0 | Legacy 평균 응답 시간 |
| `modern_avg_response_time` | NUMBER(10) | NOT NULL | 0 | Modern 평균 응답 시간 |
| `approved_by` | VARCHAR2(255) | NULL | NULL | 승인자 |
| `approved_at` | TIMESTAMP(6) WITH TIME ZONE | NULL | NULL | 승인 시간 |
| `started_at` | TIMESTAMP(6) WITH TIME ZONE | NOT NULL | SYSTIMESTAMP | 시작 시간 |
| `completed_at` | TIMESTAMP(6) WITH TIME ZONE | NULL | NULL | 완료 시간 |
| `rollback_reason` | VARCHAR2(1000) | NULL | NULL | 롤백 사유 |
| `is_rollback` | NUMBER(1) | NOT NULL | 0 | 롤백 여부 |

#### 제약조건

- **PK**: `pk_experiment_stages` (id)
- **FK**: `fk_experiment_stages_experiments` (experiment_id → experiments.id) ON DELETE CASCADE
- **CHECK**:
  - `stage`: 1 ~ 6
  - `traffic_percentage`: 0 ~ 100
  - `match_rate`: 0.0 ~ 100.0
  - `error_rate`: 0.0 ~ 100.0
  - `is_rollback`: 0 / 1

#### 단계별 최소 요청 수

| 단계 | 트래픽 비율 | 최소 요청 수 |
|------|-------------|--------------|
| 1 | 1% → 5% | 100 |
| 2 | 5% → 10% | 500 |
| 3 | 10% → 25% | 1,000 |
| 4 | 25% → 50% | 5,000 |
| 5 | 50% → 100% | 10,000 |

---

## 3. 데이터 타입 매핑

### 3.1 Go ↔ OracleDB 타입 매핑

| Go 타입 | OracleDB 타입 | 설명 |
|---------|---------------|------|
| `string` (UUID) | `VARCHAR2(36)` | UUID v4 |
| `string` (일반) | `VARCHAR2(N)` | 가변 길이 문자열 |
| `int` | `NUMBER(10)` | 정수 |
| `int64` | `NUMBER(19)` | 큰 정수 |
| `float64` (비율) | `NUMBER(5,2)` | 소수점 2자리 |
| `bool` | `NUMBER(1)` | 0: false, 1: true |
| `time.Time` | `TIMESTAMP(6) WITH TIME ZONE` | UTC 시간 |
| `[]byte` (JSON) | `CLOB` | JSON 문자열 |

### 3.2 JSON 필드 저장

다음 필드는 JSON 형식으로 직렬화하여 CLOB에 저장:

| 필드 | 테이블 | 타입 | 예시 |
|------|--------|------|------|
| `exclude_fields` | routes | `[]string` | `["timestamp", "requestId"]` |
| `legacy_request_body` | comparisons | `map[string]interface{}` | `{"userId": 123}` |
| `mismatch_details` | comparisons | `[]MismatchDetail` | `[{"fieldPath": "user.name", ...}]` |

---

## 4. 데이터 보관 정책

### 4.1 보관 기간

| 테이블 | 보관 기간 | 삭제 방법 |
|--------|-----------|----------|
| `routes` | 영구 | 수동 삭제만 |
| `comparisons` | 30일 | 배치 작업으로 자동 삭제 |
| `experiments` | 1년 | 배치 작업으로 자동 삭제 |
| `experiment_stages` | 1년 | `experiments` CASCADE 삭제 |

### 4.2 데이터 삭제

보관 기간이 지난 데이터는 정기 배치 작업으로 삭제합니다.

**참조**: `sql/05-maintenance.sql`

---

## 5. 테이블 생성 순서

외래키 관계를 고려한 테이블 생성 순서:

1. `routes` (참조 없음)
2. `comparisons` (routes 참조)
3. `experiments` (routes 참조)
4. `experiment_stages` (experiments 참조)

---

## 6. SQL 파일 참조

데이터베이스 구축 시 다음 SQL 파일을 순서대로 실행하세요:

### 6.1 DDL 파일

| 파일명 | 설명 |
|--------|------|
| `sql/01-create-tables.sql` | 테이블 생성 DDL |
| `sql/02-create-triggers.sql` | updated_at 자동 갱신 트리거 |
| `sql/03-create-indexes.sql` | 인덱스 생성 DDL |

### 6.2 데이터 및 유지보수 파일

| 파일명 | 설명 |
|--------|------|
| `sql/04-sample-data.sql` | 샘플 데이터 (개발/테스트용) |
| `sql/05-maintenance.sql` | 데이터 삭제, 통계 갱신, 인덱스 재생성 |

---

## 7. 참고 사항

### 7.1 OracleDB 특이사항

- **Boolean 타입 없음**: `NUMBER(1)` 사용 (0: false, 1: true)
- **AUTO_INCREMENT 없음**: 시퀀스 사용 (UUID 사용 시 불필요)
- **CLOB 타입**: 4GB까지 저장 가능, JSON 데이터 저장에 적합

### 7.2 성능 고려사항

- `comparisons` 테이블은 대량 데이터 발생 예상 → 파티셔닝 고려
- CLOB 필드 (`legacy_response_body`, `modern_response_body`)는 별도 테이블스페이스 고려
- 인덱스 전략은 별도 문서 참조 (`03-index-strategy.md`)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
