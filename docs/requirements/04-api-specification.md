# ABS 요구사항 정의서 - API 명세

## 문서 정보

| 항목 | 내용 |
|------|------|
| **문서명** | ABS (API Bridge Service) 요구사항 정의서 - API 명세 |
| **버전** | v1.0 |
| **작성일** | 2025-11-30 |
| **대상 독자** | 개발팀, QA팀, Frontend 팀 |
| **문서 목적** | ABS의 모든 API 엔드포인트 명세 제공 |

---

## API 개요

### Context-Path 구분

ABS는 다음과 같이 Context-Path를 구분하여 사용합니다:

| Context-Path | 용도 | 인증 | 설명 |
|--------------|------|------|------|
| `/abs/*` | ABS 관리 API | Required | 라우트, 실험, 알림 관리 |
| 기타 경로 | 프록시 API | Delegated | Legacy/Modern API로 프록시 |

### Base URL

```
Development: http://localhost:8000
Staging:     http://abs-stg.internal:8000
Production:  http://abs-prod.internal:8000
```

### 공통 사항

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer {jwt_token}  # 관리 API만
X-Request-ID: {uuid}               # 선택사항
```

**Response Headers**:
```
Content-Type: application/json
X-Request-ID: {uuid}
X-Response-Time: {ms}
```

**에러 응답 형식**:
```json
{
  "error": {
    "code": "ROUTE_NOT_FOUND",
    "message": "Route not found",
    "details": "No route found for path: /api/v1/users",
    "timestamp": "2025-11-30T10:30:00Z",
    "request_id": "req-123"
  }
}
```

---

## 1. 라우트 관리 API

### 1.1 라우트 생성

**Endpoint**: `POST /abs/api/v1/routes`

**설명**: 새로운 라우트를 생성합니다.

**Request Body**:
```json
{
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 100,
  "exclude_fields": ["timestamp", "request_id"],
  "legacy_host": "api-host",
  "legacy_port": 8080,
  "modern_host": "api-host",
  "modern_port": 9080,
  "operation_mode": "validation",
  "canary_percentage": 0
}
```

**Request Schema**:
| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `path` | string | ✓ | - | API 경로 |
| `method` | string | ✓ | - | HTTP 메서드 (GET, POST, PUT, DELETE) |
| `sample_size` | int | | 100 | 표본 크기 (10-1,000) |
| `exclude_fields` | []string | | `[]` | 비교 제외 필드 |
| `legacy_host` | string | ✓ | - | Legacy API 호스트 |
| `legacy_port` | int | ✓ | - | Legacy API 포트 |
| `modern_host` | string | ✓ | - | Modern API 호스트 |
| `modern_port` | int | ✓ | - | Modern API 포트 |
| `operation_mode` | string | | `validation` | 운영 모드 |
| `canary_percentage` | int | | 0 | Canary 비율 (0-100) |

**Response**: `201 Created`
```json
{
  "id": "route-123",
  "path": "/api/v1/users",
  "method": "GET",
  "operation_mode": "validation",
  "created_at": "2025-11-30T10:30:00Z",
  "updated_at": "2025-11-30T10:30:00Z"
}
```

**Error Responses**:
- `400 Bad Request`: 잘못된 요청 (필수 필드 누락, 유효성 검증 실패)
- `409 Conflict`: 동일한 path+method 조합이 이미 존재
- `500 Internal Server Error`: 서버 내부 오류

---

### 1.2 라우트 목록 조회

**Endpoint**: `GET /abs/api/v1/routes`

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `page` | int | | 1 | 페이지 번호 |
| `page_size` | int | | 20 | 페이지 크기 (1-100) |
| `operation_mode` | string | | - | 운영 모드 필터 |
| `sort_by` | string | | `created_at` | 정렬 기준 |
| `sort_order` | string | | `desc` | 정렬 순서 (asc, desc) |

**Response**: `200 OK`
```json
{
  "items": [
    {
      "id": "route-123",
      "path": "/api/v1/users",
      "method": "GET",
      "operation_mode": "validation",
      "match_rate": 98.5,
      "created_at": "2025-11-30T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 150,
    "total_pages": 8
  }
}
```

---

### 1.3 라우트 상세 조회

**Endpoint**: `GET /abs/api/v1/routes/{route_id}`

**Path Parameters**:
- `route_id`: 라우트 ID

**Response**: `200 OK`
```json
{
  "id": "route-123",
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 100,
  "exclude_fields": ["timestamp"],
  "legacy_host": "api-host",
  "legacy_port": 8080,
  "modern_host": "api-host",
  "modern_port": 9080,
  "operation_mode": "validation",
  "canary_percentage": 0,
  "match_rate": 98.5,
  "total_comparisons": 1000,
  "matched_count": 985,
  "mismatched_count": 15,
  "last_compared_at": "2025-11-30T10:30:00Z",
  "created_at": "2025-11-30T10:00:00Z",
  "updated_at": "2025-11-30T10:30:00Z"
}
```

**Error Responses**:
- `404 Not Found`: 라우트를 찾을 수 없음

---

### 1.4 라우트 수정

**Endpoint**: `PUT /abs/api/v1/routes/{route_id}`

**Request Body**: (라우트 생성과 동일, 모든 필드 선택사항)
```json
{
  "sample_size": 200,
  "operation_mode": "canary",
  "canary_percentage": 5
}
```

**Response**: `200 OK`
```json
{
  "id": "route-123",
  "operation_mode": "canary",
  "canary_percentage": 5,
  "updated_at": "2025-11-30T11:00:00Z"
}
```

---

### 1.5 라우트 삭제

**Endpoint**: `DELETE /abs/api/v1/routes/{route_id}`

**Response**: `204 No Content`

**Error Responses**:
- `404 Not Found`: 라우트를 찾을 수 없음
- `409 Conflict`: 진행 중인 실험이 있어 삭제 불가

---

## 2. 실험 관리 API

### 2.1 실험 생성

**Endpoint**: `POST /abs/api/v1/experiments`

**Request Body**:
```json
{
  "route_id": "route-123",
  "target_match_rate": 99.0,
  "canary_start_percentage": 1,
  "canary_max_percentage": 10,
  "min_sample_size": 100
}
```

**Response**: `201 Created`
```json
{
  "id": "exp-456",
  "route_id": "route-123",
  "status": "pending",
  "target_match_rate": 99.0,
  "current_stage": null,
  "created_at": "2025-11-30T10:30:00Z"
}
```

---

### 2.2 실험 목록 조회

**Endpoint**: `GET /abs/api/v1/experiments`

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `route_id` | string | | - | 라우트 ID 필터 |
| `status` | string | | - | 상태 필터 (pending, validation, canary, switched, completed, failed) |
| `page` | int | | 1 | 페이지 번호 |
| `page_size` | int | | 20 | 페이지 크기 |

**Response**: `200 OK`
```json
{
  "items": [
    {
      "id": "exp-456",
      "route_id": "route-123",
      "status": "validation",
      "current_match_rate": 98.5,
      "target_match_rate": 99.0,
      "started_at": "2025-11-30T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 45,
    "total_pages": 3
  }
}
```

---

### 2.3 실험 상세 조회

**Endpoint**: `GET /abs/api/v1/experiments/{experiment_id}`

**Response**: `200 OK`
```json
{
  "id": "exp-456",
  "route_id": "route-123",
  "status": "canary",
  "target_match_rate": 99.0,
  "canary_start_percentage": 1,
  "canary_max_percentage": 10,
  "min_sample_size": 100,
  "current_stage": {
    "stage": "canary_5",
    "canary_percentage": 5,
    "match_rate": 99.2,
    "sample_count": 150,
    "started_at": "2025-11-30T11:00:00Z"
  },
  "stages": [
    {
      "stage": "validation",
      "match_rate": 99.5,
      "sample_count": 200,
      "started_at": "2025-11-30T10:30:00Z",
      "completed_at": "2025-12-01T10:30:00Z"
    },
    {
      "stage": "canary_1",
      "canary_percentage": 1,
      "match_rate": 99.3,
      "sample_count": 120,
      "started_at": "2025-12-01T10:30:00Z",
      "completed_at": "2025-12-01T16:30:00Z"
    }
  ],
  "created_at": "2025-11-30T10:30:00Z",
  "started_at": "2025-11-30T10:30:00Z",
  "updated_at": "2025-12-01T16:30:00Z"
}
```

---

### 2.4 실험 시작

**Endpoint**: `POST /abs/api/v1/experiments/{experiment_id}/start`

**Response**: `200 OK`
```json
{
  "id": "exp-456",
  "status": "validation",
  "started_at": "2025-11-30T10:30:00Z"
}
```

---

### 2.5 실험 중지

**Endpoint**: `POST /abs/api/v1/experiments/{experiment_id}/stop`

**Response**: `200 OK`
```json
{
  "id": "exp-456",
  "status": "failed",
  "stopped_at": "2025-11-30T11:00:00Z"
}
```

---

### 2.6 실험 삭제

**Endpoint**: `DELETE /abs/api/v1/experiments/{experiment_id}`

**Response**: `204 No Content`

**Error Responses**:
- `409 Conflict`: 진행 중인 실험은 삭제 불가 (먼저 중지 필요)

---

## 3. 비교 결과 조회 API

### 3.1 비교 결과 목록 조회

**Endpoint**: `GET /abs/api/v1/comparisons`

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `route_id` | string | | - | 라우트 ID 필터 |
| `is_matched` | boolean | | - | 일치 여부 필터 |
| `start_date` | string | | - | 시작 날짜 (ISO 8601) |
| `end_date` | string | | - | 종료 날짜 (ISO 8601) |
| `page` | int | | 1 | 페이지 번호 |
| `page_size` | int | | 20 | 페이지 크기 |

**Response**: `200 OK`
```json
{
  "items": [
    {
      "id": "comp-789",
      "route_id": "route-123",
      "is_matched": false,
      "mismatch_count": 2,
      "request_hash": "abc123",
      "created_at": "2025-11-30T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 15234,
    "total_pages": 762
  }
}
```

---

### 3.2 비교 결과 상세 조회

**Endpoint**: `GET /abs/api/v1/comparisons/{comparison_id}`

**Response**: `200 OK`
```json
{
  "id": "comp-789",
  "route_id": "route-123",
  "is_matched": false,
  "mismatch_count": 2,
  "request_hash": "abc123",
  "mismatches": [
    {
      "field": "user.email",
      "type": "value_mismatch",
      "legacy_value": "user@example.com",
      "modern_value": "user@company.com"
    },
    {
      "field": "user.age",
      "type": "type_mismatch",
      "legacy_value": "25",
      "modern_value": 25
    }
  ],
  "legacy_response": {
    "status_code": 200,
    "body": "{\"user\":{...}}",
    "response_time_ms": 120
  },
  "modern_response": {
    "status_code": 200,
    "body": "{\"user\":{...}}",
    "response_time_ms": 115
  },
  "created_at": "2025-11-30T10:30:00Z"
}
```

---

## 4. 메트릭 조회 API

### 4.1 전체 일치율 조회

**Endpoint**: `GET /abs/api/v1/metrics/match-rate`

**Response**: `200 OK`
```json
{
  "routes": [
    {
      "route_id": "route-123",
      "path": "/api/v1/users",
      "method": "GET",
      "match_rate": 98.5,
      "total_comparisons": 1000,
      "matched_count": 985,
      "last_compared_at": "2025-11-30T10:30:00Z"
    }
  ],
  "overall": {
    "average_match_rate": 97.8,
    "total_routes": 15,
    "total_comparisons": 15000
  }
}
```

---

### 4.2 특정 라우트 일치율 조회

**Endpoint**: `GET /abs/api/v1/metrics/match-rate/{route_id}`

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `time_range` | string | | `24h` | 시간 범위 (1h, 6h, 24h, 7d) |

**Response**: `200 OK`
```json
{
  "route_id": "route-123",
  "path": "/api/v1/users",
  "method": "GET",
  "current_match_rate": 98.5,
  "time_series": [
    {
      "timestamp": "2025-11-30T10:00:00Z",
      "match_rate": 98.2,
      "comparisons": 50
    },
    {
      "timestamp": "2025-11-30T11:00:00Z",
      "match_rate": 98.7,
      "comparisons": 52
    }
  ]
}
```

---

## 5. 알림 설정 API

### 5.1 알림 규칙 생성

**Endpoint**: `POST /abs/api/v1/alerts`

**Request Body**:
```json
{
  "name": "일치율 급락 알림",
  "condition": "match_rate_drop",
  "threshold": 95.0,
  "route_id": "route-123",
  "channels": ["slack", "email"],
  "enabled": true
}
```

**Response**: `201 Created`
```json
{
  "id": "alert-321",
  "name": "일치율 급락 알림",
  "enabled": true,
  "created_at": "2025-11-30T10:30:00Z"
}
```

---

### 5.2 알림 규칙 목록 조회

**Endpoint**: `GET /abs/api/v1/alerts`

**Response**: `200 OK`
```json
{
  "items": [
    {
      "id": "alert-321",
      "name": "일치율 급락 알림",
      "condition": "match_rate_drop",
      "threshold": 95.0,
      "enabled": true
    }
  ]
}
```

---

### 5.3 알림 규칙 수정

**Endpoint**: `PUT /abs/api/v1/alerts/{alert_id}`

**Request Body**:
```json
{
  "threshold": 97.0,
  "enabled": false
}
```

**Response**: `200 OK`

---

### 5.4 알림 규칙 삭제

**Endpoint**: `DELETE /abs/api/v1/alerts/{alert_id}`

**Response**: `204 No Content`

---

## 6. Health Check API

### 6.1 Liveness Probe

**Endpoint**: `GET /abs/health/liveness`

**인증**: 불필요

**Response**: `200 OK`
```json
{
  "status": "alive",
  "timestamp": "2025-11-30T10:30:00Z"
}
```

---

### 6.2 Readiness Probe

**Endpoint**: `GET /abs/health/readiness`

**인증**: 불필요

**Response**: `200 OK`
```json
{
  "status": "ready",
  "timestamp": "2025-11-30T10:30:00Z",
  "checks": {
    "database": "ok",
    "redis": "ok",
    "rabbitmq": "ok"
  }
}
```

**Error Response**: `503 Service Unavailable`
```json
{
  "status": "not_ready",
  "timestamp": "2025-11-30T10:30:00Z",
  "checks": {
    "database": "ok",
    "redis": "failed",
    "rabbitmq": "ok"
  }
}
```

---

### 6.3 Startup Probe

**Endpoint**: `GET /abs/health/startup`

**인증**: 불필요

**Response**: `200 OK`
```json
{
  "status": "started",
  "timestamp": "2025-11-30T10:30:00Z"
}
```

---

## 7. 프록시 API

### 7.1 모든 비-/abs/* 경로

**Endpoint**: `* /*` (Context-Path가 `/abs/*`가 아닌 모든 경로)

**설명**: 설정된 라우트에 따라 Legacy/Modern API로 프록시

**처리 흐름**:
1. 요청 수신
2. 라우트 조회
3. 운영 모드에 따라 라우팅
4. Target API 호출
5. 응답 반환
6. 비동기 비교 수행 (해당하는 경우)

**응답**: Target API의 응답을 그대로 반환

**Error Responses**:
- `404 Not Found`: 라우트 설정이 없는 경로
- `502 Bad Gateway`: Target API 연결 실패
- `503 Service Unavailable`: Target API 타임아웃
- `504 Gateway Timeout`: ABS 타임아웃

---

## 에러 코드 체계

| 에러 코드 | HTTP 상태 | 설명 |
|----------|----------|------|
| `INVALID_REQUEST` | 400 | 잘못된 요청 |
| `UNAUTHORIZED` | 401 | 인증 실패 |
| `FORBIDDEN` | 403 | 권한 없음 |
| `ROUTE_NOT_FOUND` | 404 | 라우트를 찾을 수 없음 |
| `RESOURCE_NOT_FOUND` | 404 | 리소스를 찾을 수 없음 |
| `CONFLICT` | 409 | 리소스 충돌 |
| `VALIDATION_ERROR` | 422 | 유효성 검증 실패 |
| `INTERNAL_ERROR` | 500 | 내부 서버 오류 |
| `BAD_GATEWAY` | 502 | Target API 연결 실패 |
| `SERVICE_UNAVAILABLE` | 503 | 서비스 사용 불가 |
| `GATEWAY_TIMEOUT` | 504 | 게이트웨이 타임아웃 |

---

## API 버전 관리

### 버전 정책

- 현재 버전: `v1`
- URL에 버전 포함: `/abs/api/v1/*`
- 하위 호환성 보장: Minor 버전 업데이트 시
- Breaking Change: Major 버전 업데이트 (v2)

### Deprecation 정책

- Deprecated API는 최소 6개월 유지
- Response Header에 Deprecation 정보 포함:
  ```
  X-API-Deprecated: true
  X-API-Sunset-Date: 2026-06-01
  X-API-Alternative: /abs/api/v2/routes
  ```

---

## API 사용 예시

### cURL 예시

**라우트 생성**:
```bash
curl -X POST http://localhost:8000/abs/api/v1/routes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "path": "/api/v1/users",
    "method": "GET",
    "legacy_host": "api-server",
    "legacy_port": 8080,
    "modern_host": "api-server",
    "modern_port": 9080
  }'
```

**실험 시작**:
```bash
curl -X POST http://localhost:8000/abs/api/v1/experiments/exp-456/start \
  -H "Authorization: Bearer $TOKEN"
```

**일치율 조회**:
```bash
curl http://localhost:8000/abs/api/v1/metrics/match-rate/route-123?time_range=24h \
  -H "Authorization: Bearer $TOKEN"
```

---

## 참조 문서

- [API 설계](../05-api/02-endpoint-specification.md)
- [에러 응답 설계](../05-api/03-error-response.md)
- [기능 요구사항](./02-functional-requirements.md)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
**승인자**: Tech Lead, API Architect
