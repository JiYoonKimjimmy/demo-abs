# 인덱스 및 성능 최적화 전략

## 문서 목적

본 문서는 ABS 데이터베이스의 인덱스 설계 및 성능 최적화 전략을 정의합니다.

**포함 내용**:
- 테이블별 인덱스 정의
- 복합 인덱스 전략
- 쿼리 최적화 가이드
- 파티셔닝 전략
- 성능 모니터링 방안

---

## 1. 인덱스 개요

### 1.1 인덱스 설계 원칙

| 원칙 | 설명 |
|------|------|
| **선택도(Selectivity)** | 카디널리티가 높은 컬럼에 인덱스 생성 |
| **조회 빈도** | 자주 조회되는 컬럼 우선 인덱스 생성 |
| **쓰기 성능** | 인덱스가 많을수록 INSERT/UPDATE 성능 저하 → 적정 수준 유지 |
| **복합 인덱스 순서** | 선택도가 높은 컬럼을 앞에 배치 |
| **커버링 인덱스** | SELECT에 필요한 모든 컬럼을 인덱스에 포함 (권장하지 않음) |

### 1.2 인덱스 타입

| 타입 | 사용 목적 | OracleDB 구문 |
|------|----------|---------------|
| **B-Tree Index** | 기본 인덱스, 대부분의 조회에 적합 | `CREATE INDEX` |
| **Unique Index** | 유니크 제약조건 보장 | `CREATE UNIQUE INDEX` |
| **Composite Index** | 여러 컬럼 조합 조회 | `CREATE INDEX ... (col1, col2)` |
| **Function-Based Index** | 함수 결과에 인덱스 | `CREATE INDEX ... (UPPER(col))` |
| **Bitmap Index** | 카디널리티가 낮은 컬럼 (비권장) | `CREATE BITMAP INDEX` |

---

## 2. 테이블별 인덱스 설계

### 2.1 routes 테이블

#### Primary Key Index

```sql
-- 자동 생성됨 (PK 제약조건)
CONSTRAINT pk_routes PRIMARY KEY (id)
```

#### Unique Index

```sql
-- 자동 생성됨 (UK 제약조건)
CONSTRAINT uk_routes_path_method UNIQUE (path, method)
```

#### 추가 인덱스

**idx_routes_is_active**
- **목적**: 활성화된 라우트만 조회 시 성능 향상
- **컬럼**: `is_active`
- **타입**: B-Tree

```sql
CREATE INDEX idx_routes_is_active ON routes(is_active);
```

**쿼리 예시**:
```sql
SELECT * FROM routes WHERE is_active = 1;
```

**idx_routes_operation_mode**
- **목적**: 운영 모드별 라우트 조회 (예: Canary 모드만 조회)
- **컬럼**: `operation_mode`
- **타입**: B-Tree

```sql
CREATE INDEX idx_routes_operation_mode ON routes(operation_mode);
```

**쿼리 예시**:
```sql
SELECT * FROM routes WHERE operation_mode = 'canary';
```

**idx_routes_is_active_operation_mode (복합 인덱스)**
- **목적**: 활성화 + 운영 모드 조합 조회
- **컬럼**: `is_active`, `operation_mode`
- **타입**: Composite B-Tree
- **컬럼 순서**: `is_active` 먼저 (선택도가 낮지만 필터링 효과 큼)

```sql
CREATE INDEX idx_routes_is_active_operation_mode
ON routes(is_active, operation_mode);
```

**쿼리 예시**:
```sql
SELECT * FROM routes
WHERE is_active = 1 AND operation_mode = 'validation';
```

#### routes 테이블 인덱스 요약

| 인덱스명 | 타입 | 컬럼 | 목적 |
|---------|------|------|------|
| `pk_routes` | PK | `id` | Primary Key |
| `uk_routes_path_method` | UK | `path`, `method` | 중복 방지 |
| `idx_routes_is_active` | B-Tree | `is_active` | 활성화 필터 |
| `idx_routes_operation_mode` | B-Tree | `operation_mode` | 운영 모드 필터 |
| `idx_routes_is_active_operation_mode` | Composite | `is_active`, `operation_mode` | 복합 필터 |

---

### 2.2 comparisons 테이블

#### Primary Key Index

```sql
-- 자동 생성됨 (PK 제약조건)
CONSTRAINT pk_comparisons PRIMARY KEY (id)
```

#### Foreign Key Index

**idx_comparisons_route_id**
- **목적**: 외래키 조인 성능 향상
- **컬럼**: `route_id`
- **타입**: B-Tree

```sql
CREATE INDEX idx_comparisons_route_id ON comparisons(route_id);
```

**쿼리 예시**:
```sql
SELECT * FROM comparisons WHERE route_id = 'route-001';
```

#### 추가 인덱스

**idx_comparisons_created_at**
- **목적**: 시간대별 비교 결과 조회 (최신 순)
- **컬럼**: `created_at`
- **타입**: B-Tree

```sql
CREATE INDEX idx_comparisons_created_at ON comparisons(created_at DESC);
```

**쿼리 예시**:
```sql
SELECT * FROM comparisons
WHERE created_at >= SYSTIMESTAMP - INTERVAL '1' DAY
ORDER BY created_at DESC;
```

**idx_comparisons_route_id_is_match (복합 인덱스)**
- **목적**: 라우트별 일치/불일치 결과 조회
- **컬럼**: `route_id`, `is_match`
- **타입**: Composite B-Tree

```sql
CREATE INDEX idx_comparisons_route_id_is_match
ON comparisons(route_id, is_match);
```

**쿼리 예시**:
```sql
-- 라우트별 불일치 결과만 조회
SELECT * FROM comparisons
WHERE route_id = 'route-001' AND is_match = 0;
```

**idx_comparisons_route_id_created_at (복합 인덱스)**
- **목적**: 라우트별 최신 비교 결과 조회
- **컬럼**: `route_id`, `created_at`
- **타입**: Composite B-Tree

```sql
CREATE INDEX idx_comparisons_route_id_created_at
ON comparisons(route_id, created_at DESC);
```

**쿼리 예시**:
```sql
-- 라우트별 최근 100개 비교 결과 조회
SELECT * FROM comparisons
WHERE route_id = 'route-001'
ORDER BY created_at DESC
FETCH FIRST 100 ROWS ONLY;
```

#### comparisons 테이블 인덱스 요약

| 인덱스명 | 타입 | 컬럼 | 목적 |
|---------|------|------|------|
| `pk_comparisons` | PK | `id` | Primary Key |
| `idx_comparisons_route_id` | B-Tree | `route_id` | FK 조인 |
| `idx_comparisons_created_at` | B-Tree | `created_at DESC` | 시간대별 조회 |
| `idx_comparisons_route_id_is_match` | Composite | `route_id`, `is_match` | 라우트별 일치 여부 |
| `idx_comparisons_route_id_created_at` | Composite | `route_id`, `created_at DESC` | 라우트별 최신 조회 |

---

### 2.3 experiments 테이블

#### Primary Key Index

```sql
-- 자동 생성됨 (PK 제약조건)
CONSTRAINT pk_experiments PRIMARY KEY (id)
```

#### Foreign Key Index

**idx_experiments_route_id**
- **목적**: 외래키 조인 성능 향상
- **컬럼**: `route_id`
- **타입**: B-Tree

```sql
CREATE INDEX idx_experiments_route_id ON experiments(route_id);
```

**쿼리 예시**:
```sql
SELECT * FROM experiments WHERE route_id = 'route-001';
```

#### 추가 인덱스

**idx_experiments_status**
- **목적**: 상태별 실험 조회 (진행 중, 완료, 중단)
- **컬럼**: `status`
- **타입**: B-Tree

```sql
CREATE INDEX idx_experiments_status ON experiments(status);
```

**쿼리 예시**:
```sql
-- 진행 중인 실험 조회
SELECT * FROM experiments WHERE status = 'running';
```

**idx_experiments_route_id_status (복합 인덱스)**
- **목적**: 라우트별 진행 중인 실험 조회 (비즈니스 규칙: 최대 1개)
- **컬럼**: `route_id`, `status`
- **타입**: Composite B-Tree

```sql
CREATE INDEX idx_experiments_route_id_status
ON experiments(route_id, status);
```

**쿼리 예시**:
```sql
-- 라우트의 진행 중인 실험 조회
SELECT * FROM experiments
WHERE route_id = 'route-001' AND status IN ('running', 'paused');
```

**idx_experiments_created_at**
- **목적**: 실험 생성 시간 기준 조회
- **컬럼**: `created_at`
- **타입**: B-Tree

```sql
CREATE INDEX idx_experiments_created_at ON experiments(created_at DESC);
```

**쿼리 예시**:
```sql
-- 최근 1개월 내 실험 조회
SELECT * FROM experiments
WHERE created_at >= SYSTIMESTAMP - INTERVAL '1' MONTH
ORDER BY created_at DESC;
```

#### experiments 테이블 인덱스 요약

| 인덱스명 | 타입 | 컬럼 | 목적 |
|---------|------|------|------|
| `pk_experiments` | PK | `id` | Primary Key |
| `idx_experiments_route_id` | B-Tree | `route_id` | FK 조인 |
| `idx_experiments_status` | B-Tree | `status` | 상태 필터 |
| `idx_experiments_route_id_status` | Composite | `route_id`, `status` | 라우트별 상태 |
| `idx_experiments_created_at` | B-Tree | `created_at DESC` | 시간대별 조회 |

---

### 2.4 experiment_stages 테이블

#### Primary Key Index

```sql
-- 자동 생성됨 (PK 제약조건)
CONSTRAINT pk_experiment_stages PRIMARY KEY (id)
```

#### Foreign Key Index

**idx_experiment_stages_experiment_id**
- **목적**: 외래키 조인 성능 향상
- **컬럼**: `experiment_id`
- **타입**: B-Tree

```sql
CREATE INDEX idx_experiment_stages_experiment_id
ON experiment_stages(experiment_id);
```

**쿼리 예시**:
```sql
SELECT * FROM experiment_stages
WHERE experiment_id = 'experiment-001'
ORDER BY stage;
```

#### 추가 인덱스

**idx_experiment_stages_experiment_id_stage (복합 인덱스)**
- **목적**: 실험의 특정 단계 조회
- **컬럼**: `experiment_id`, `stage`
- **타입**: Composite B-Tree

```sql
CREATE INDEX idx_experiment_stages_experiment_id_stage
ON experiment_stages(experiment_id, stage);
```

**쿼리 예시**:
```sql
-- 실험의 현재 단계(Stage 3) 조회
SELECT * FROM experiment_stages
WHERE experiment_id = 'experiment-001' AND stage = 3;
```

**idx_experiment_stages_completed_at**
- **목적**: 진행 중인 단계 조회 (`completed_at IS NULL`)
- **컬럼**: `completed_at`
- **타입**: B-Tree

```sql
CREATE INDEX idx_experiment_stages_completed_at
ON experiment_stages(completed_at);
```

**쿼리 예시**:
```sql
-- 진행 중인 단계 조회 (완료되지 않은 단계)
SELECT * FROM experiment_stages
WHERE experiment_id = 'experiment-001' AND completed_at IS NULL;
```

#### experiment_stages 테이블 인덱스 요약

| 인덱스명 | 타입 | 컬럼 | 목적 |
|---------|------|------|------|
| `pk_experiment_stages` | PK | `id` | Primary Key |
| `idx_experiment_stages_experiment_id` | B-Tree | `experiment_id` | FK 조인 |
| `idx_experiment_stages_experiment_id_stage` | Composite | `experiment_id`, `stage` | 실험별 단계 조회 |
| `idx_experiment_stages_completed_at` | B-Tree | `completed_at` | 진행 중 단계 조회 |

---

## 3. 인덱스 생성

전체 인덱스 생성 DDL은 별도 SQL 파일에서 관리합니다.

**참조**: `sql/03-create-indexes.sql`

---

## 4. 쿼리 최적화 가이드

### 4.1 인덱스 힌트 사용

Oracle에서 옵티마이저가 적절한 인덱스를 선택하지 못할 경우 힌트 사용:

**INDEX 힌트**:
```sql
SELECT /*+ INDEX(r idx_routes_is_active_operation_mode) */
    r.id, r.path, r.method
FROM routes r
WHERE r.is_active = 1 AND r.operation_mode = 'canary';
```

**INDEX_DESC 힌트** (역순 스캔):
```sql
SELECT /*+ INDEX_DESC(c idx_comparisons_created_at) */
    c.id, c.route_id, c.created_at
FROM comparisons c
WHERE c.created_at >= SYSTIMESTAMP - INTERVAL '1' DAY;
```

### 4.2 쿼리 패턴별 최적화

#### 라우트별 최신 비교 결과 조회

**비효율적인 쿼리**:
```sql
SELECT * FROM comparisons c
WHERE c.route_id = 'route-001'
ORDER BY c.created_at DESC
FETCH FIRST 1 ROW ONLY;
```

**최적화된 쿼리** (인덱스 활용):
```sql
SELECT /*+ INDEX_DESC(c idx_comparisons_route_id_created_at) */
    * FROM comparisons c
WHERE c.route_id = 'route-001'
FETCH FIRST 1 ROW ONLY;
```

#### 라우트별 일치율 계산

**비효율적인 쿼리** (전체 스캔):
```sql
SELECT
    route_id,
    COUNT(*) AS total,
    SUM(CASE WHEN is_match = 1 THEN 1 ELSE 0 END) AS matched
FROM comparisons
GROUP BY route_id;
```

**최적화된 쿼리** (인덱스 활용):
```sql
SELECT /*+ INDEX(c idx_comparisons_route_id_is_match) */
    route_id,
    COUNT(*) AS total,
    SUM(CASE WHEN is_match = 1 THEN 1 ELSE 0 END) AS matched
FROM comparisons c
WHERE c.route_id = :route_id
GROUP BY route_id;
```

---

## 5. 파티셔닝 전략

### 5.1 comparisons 테이블 파티셔닝

**목적**: 대량 데이터 발생 예상, 조회/삭제 성능 향상

**파티셔닝 타입**: Range Partitioning (월별)
**파티션 키**: `created_at`

**주의사항**:
- PK에 파티션 키(`created_at`) 포함 필요
- 매월 초 새로운 파티션 자동 생성 스크립트 필요
- 파티션 추가/삭제 쿼리는 유지보수 파일 참조

**참조**: `sql/05-maintenance.sql` (파티션 관리 섹션)

### 5.2 파티셔닝 장점

| 장점 | 설명 |
|------|------|
| **조회 성능** | 특정 기간만 스캔 (Partition Pruning) |
| **삭제 성능** | 파티션 단위 DROP (DELETE보다 빠름) |
| **백업/복구** | 파티션 단위 백업 가능 |
| **유지보수** | 오래된 데이터 아카이빙 용이 |

---

## 6. 성능 모니터링

### 6.1 인덱스 사용률 확인

인덱스 정보 및 사용률 확인 쿼리는 유지보수 파일을 참조하세요.

**참조**: `sql/05-maintenance.sql` (테이블 및 인덱스 정보 조회 섹션)

### 6.2 실행 계획 확인

EXPLAIN PLAN을 사용하여 쿼리 실행 계획을 확인합니다.

**확인 사항**:
- `TABLE ACCESS FULL` → 인덱스 미사용 (개선 필요)
- `INDEX RANGE SCAN` → 인덱스 사용 (정상)

### 6.3 인덱스 재생성

인덱스 단편화 발생 시 재생성이 필요합니다.

**참조**: `sql/05-maintenance.sql` (인덱스 재생성 섹션)

---

## 7. 인덱스 유지보수

### 7.1 통계 정보 갱신

정기적으로 통계 정보를 갱신합니다 (주 1회 권장).

**참조**: `sql/05-maintenance.sql` (통계 정보 갱신 섹션)

### 7.2 인덱스 모니터링

사용되지 않는 인덱스를 확인하고 삭제하여 쓰기 성능을 향상시킵니다.

**참조**: `sql/05-maintenance.sql` (인덱스 사용률 모니터링 섹션)

---

## 8. 인덱스 삭제 가이드

사용되지 않는 인덱스는 삭제하여 쓰기 성능을 향상시킬 수 있습니다.

**삭제 전 확인사항**:
- 인덱스 사용률 확인 (v$object_usage)
- 쿼리 성능 영향 분석
- 백업 계획 수립

---

## 9. 성능 목표

### 9.1 응답 시간 목표

| 쿼리 타입 | 목표 시간 | 인덱스 |
|----------|----------|--------|
| PK 조회 (id) | < 1ms | PK 인덱스 |
| 라우트 조회 (path, method) | < 5ms | UK 인덱스 |
| 비교 결과 조회 (route_id) | < 10ms | FK 인덱스 |
| 실험 조회 (route_id, status) | < 10ms | 복합 인덱스 |
| 통계 집계 (라우트별 일치율) | < 100ms | 복합 인덱스 |

### 9.2 처리량 목표

| 작업 | 목표 TPS |
|------|----------|
| 비교 결과 INSERT | 10,000 TPS |
| 라우트 조회 (활성화 필터) | 50,000 TPS |
| 실험 상태 UPDATE | 1,000 TPS |

---

## 10. 참고 사항

### 10.1 인덱스 설계 체크리스트

- [ ] PK/UK 인덱스 자동 생성 확인
- [ ] FK 컬럼에 인덱스 생성
- [ ] 자주 조회되는 컬럼에 인덱스 생성
- [ ] 복합 인덱스 컬럼 순서 최적화
- [ ] 파티셔닝 필요성 검토 (comparisons 테이블)
- [ ] 통계 정보 갱신 스케줄 설정
- [ ] 인덱스 모니터링 활성화
- [ ] 실행 계획 확인 및 튜닝

### 10.2 안티 패턴

**피해야 할 인덱스 설계**:
- CLOB 컬럼에 인덱스 생성 (불가)
- 선택도가 낮은 컬럼에만 단일 인덱스 (예: `is_active`)
- 과도한 복합 인덱스 (3개 이상 컬럼)
- 중복 인덱스 (예: (A, B)와 (A) 동시 존재 시 후자 불필요)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
