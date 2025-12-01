# API 엔드포인트 명세

## 문서 목적

본 문서는 ABS의 모든 REST API 엔드포인트의 상세 명세를 정의합니다.

**포함 내용**:
- 관리 API (라우트, 실험, 알림)
- 모니터링 API (메트릭, 비교 결과)
- Health Check API
- Request/Response DTO 정의

---

## 1. 라우트 관리 API

### 1.1 라우트 생성

```http
POST /abs/api/v1/routes
```

**Request**:
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

**Request DTO**:
| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `path` | string | ✓ | - | API 경로 (예: `/api/v1/users`) |
| `method` | string | ✓ | - | HTTP 메서드 (`GET`, `POST`, `PUT`, `DELETE`) |
| `sample_size` | int | | 100 | 표본 크기 (10-1,000) |
| `exclude_fields` | []string | | `[]` | 비교 제외 필드 목록 |
| `legacy_host` | string | ✓ | - | Legacy API 호스트 |
| `legacy_port` | int | ✓ | 8080 | Legacy API 포트 |
| `modern_host` | string | ✓ | - | Modern API 호스트 |
| `modern_port` | int | ✓ | 9080 | Modern API 포트 |
| `operation_mode` | string | | `validation` | 운영 모드 (`validation`, `canary`, `switched`) |
| `canary_percentage` | int | | 0 | Canary 트래픽 비율 (0-100) |

**Response** (`201 Created`):
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 100,
  "exclude_fields": ["timestamp", "request_id"],
  "legacy_host": "api-host",
  "legacy_port": 8080,
  "modern_host": "api-host",
  "modern_port": 9080,
  "operation_mode": "validation",
  "canary_percentage": 0,
  "match_rate": 0.0,
  "total_requests": 0,
  "matched_requests": 0,
  "error_rate": 0.0,
  "is_active": true,
  "created_at": "2025-11-30T10:00:00Z",
  "updated_at": "2025-11-30T10:00:00Z"
}
```

**Response Headers**:
```http
HTTP/1.1 201 Created
Location: /abs/api/v1/routes/123e4567-e89b-12d3-a456-426614174000
Content-Type: application/json
```

**Errors**:
- `400 Bad Request`: 유효성 검증 실패
- `409 Conflict`: 동일 Path + Method 조합 이미 존재

---

### 1.2 라우트 목록 조회

```http
GET /abs/api/v1/routes?page=1&limit=20&operation_mode=validation
```

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `page` | int | 1 | 페이지 번호 |
| `limit` | int | 20 | 페이지당 항목 수 (최대 100) |
| `operation_mode` | string | - | 운영 모드 필터 |
| `is_active` | boolean | - | 활성 상태 필터 |
| `sort` | string | `created_at` | 정렬 필드 |
| `order` | string | `desc` | 정렬 방향 (`asc`, `desc`) |

**Response** (`200 OK`):
```json
{
  "data": [
    {
      "id": "123e4567",
      "path": "/api/v1/users",
      "method": "GET",
      "operation_mode": "validation",
      "match_rate": 99.95,
      "total_requests": 1500,
      "is_active": true,
      "created_at": "2025-11-30T10:00:00Z"
    },
    {
      "id": "234e5678",
      "path": "/api/v1/orders",
      "method": "POST",
      "operation_mode": "canary",
      "canary_percentage": 10,
      "match_rate": 99.85,
      "total_requests": 3200,
      "is_active": true,
      "created_at": "2025-11-29T15:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 50,
    "total_pages": 3
  }
}
```

---

### 1.3 라우트 단일 조회

```http
GET /abs/api/v1/routes/{route_id}
```

**Path Parameters**:
| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `route_id` | string | 라우트 ID (UUID) |

**Response** (`200 OK`):
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 100,
  "exclude_fields": ["timestamp", "request_id"],
  "legacy_host": "api-host",
  "legacy_port": 8080,
  "modern_host": "api-host",
  "modern_port": 9080,
  "operation_mode": "validation",
  "canary_percentage": 0,
  "match_rate": 99.95,
  "total_requests": 1500,
  "matched_requests": 1499,
  "error_rate": 0.05,
  "is_active": true,
  "created_at": "2025-11-30T10:00:00Z",
  "updated_at": "2025-11-30T15:30:00Z"
}
```

**Errors**:
- `404 Not Found`: 라우트 없음

---

### 1.4 라우트 수정

```http
PATCH /abs/api/v1/routes/{route_id}
```

**Request**:
```json
{
  "sample_size": 200,
  "exclude_fields": ["timestamp", "request_id", "trace_id"],
  "operation_mode": "canary",
  "canary_percentage": 10
}
```

**Response** (`200 OK`):
```json
{
  "id": "123e4567",
  "path": "/api/v1/users",
  "sample_size": 200,
  "exclude_fields": ["timestamp", "request_id", "trace_id"],
  "operation_mode": "canary",
  "canary_percentage": 10,
  ...
  "updated_at": "2025-11-30T16:00:00Z"
}
```

**Errors**:
- `400 Bad Request`: 유효성 검증 실패
- `404 Not Found`: 라우트 없음
- `422 Unprocessable Entity`: 비즈니스 규칙 위반 (예: Canary 모드인데 percentage=0)

---

### 1.5 라우트 삭제

```http
DELETE /abs/api/v1/routes/{route_id}
```

**Response** (`204 No Content`):
```
(응답 본문 없음)
```

**Errors**:
- `404 Not Found`: 라우트 없음
- `409 Conflict`: 진행 중인 실험 있음 (삭제 불가)

---

### 1.6 라우트 통계 조회

```http
GET /abs/api/v1/routes/{route_id}/stats?start_date=2025-11-01&end_date=2025-11-30
```

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `start_date` | date | | 시작 날짜 (ISO 8601) |
| `end_date` | date | | 종료 날짜 (ISO 8601) |

**Response** (`200 OK`):
```json
{
  "route_id": "123e4567",
  "path": "/api/v1/users",
  "method": "GET",
  "period": {
    "start": "2025-11-01T00:00:00Z",
    "end": "2025-11-30T23:59:59Z"
  },
  "stats": {
    "total_requests": 150000,
    "matched_requests": 149900,
    "match_rate": 99.93,
    "error_rate": 0.05,
    "avg_legacy_response_time": 120,
    "avg_modern_response_time": 115,
    "p50_legacy_response_time": 110,
    "p50_modern_response_time": 105,
    "p95_legacy_response_time": 180,
    "p95_modern_response_time": 170,
    "p99_legacy_response_time": 250,
    "p99_modern_response_time": 240
  },
  "daily_stats": [
    {
      "date": "2025-11-01",
      "total_requests": 5000,
      "match_rate": 99.95,
      "error_rate": 0.04
    },
    {
      "date": "2025-11-02",
      "total_requests": 5200,
      "match_rate": 99.90,
      "error_rate": 0.06
    }
  ]
}
```

---

### 1.7 라우트 모드 전환 (수동)

```http
POST /abs/api/v1/routes/{route_id}/switch
```

**Request**:
```json
{
  "operation_mode": "switched",
  "reason": "Manual switch after validation"
}
```

**Request DTO**:
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `operation_mode` | string | ✓ | 전환할 모드 (`validation`, `canary`, `switched`) |
| `canary_percentage` | int | | Canary 모드 시 트래픽 비율 |
| `reason` | string | | 전환 이유 (감사 로그용) |

**Response** (`200 OK`):
```json
{
  "success": true,
  "message": "Operation mode switched successfully",
  "data": {
    "route_id": "123e4567",
    "previous_mode": "validation",
    "current_mode": "switched",
    "switched_at": "2025-11-30T16:30:00Z",
    "switched_by": "admin@example.com"
  }
}
```

**Errors**:
- `422 Unprocessable Entity`: 전환 조건 미충족 (예: validation → switched인데 MatchRate < 100%)

---

## 2. 실험 관리 API

### 2.1 실험 시작

```http
POST /abs/api/v1/routes/{route_id}/experiments
```

**Request**:
```json
{
  "initial_percentage": 1,
  "target_percentage": 100,
  "stabilization_period": 3600
}
```

**Request DTO**:
| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `initial_percentage` | int | | 1 | 시작 트래픽 비율 (1-100) |
| `target_percentage` | int | | 100 | 목표 트래픽 비율 |
| `stabilization_period` | int | | 3600 | 안정화 기간 (초, 최소 3600) |

**Response** (`201 Created`):
```json
{
  "id": "456e7890-e89b-12d3-a456-426614174000",
  "route_id": "123e4567",
  "initial_percentage": 1,
  "current_percentage": 1,
  "target_percentage": 100,
  "stabilization_period": 3600,
  "status": "pending",
  "current_stage": 1,
  "total_stages": 6,
  "created_at": "2025-11-30T16:00:00Z",
  "updated_at": "2025-11-30T16:00:00Z"
}
```

**Errors**:
- `409 Conflict`: 이미 진행 중인 실험 존재
- `422 Unprocessable Entity`: 라우트가 validation 모드가 아님

---

### 2.2 현재 실험 상태 조회

```http
GET /abs/api/v1/routes/{route_id}/experiments/current
```

**Response** (`200 OK`):
```json
{
  "experiment": {
    "id": "456e7890",
    "status": "running",
    "current_stage": 2,
    "total_stages": 6,
    "current_percentage": 5,
    "next_percentage": 10,
    "started_at": "2025-11-30T16:00:00Z"
  },
  "current_stage": {
    "stage": 2,
    "traffic_percentage": 5,
    "min_requests": 500,
    "total_requests": 520,
    "match_rate": 99.92,
    "error_rate": 0.05,
    "legacy_avg_response_time": 120,
    "modern_avg_response_time": 115,
    "started_at": "2025-11-30T17:30:00Z",
    "elapsed_seconds": 1800
  },
  "can_proceed_to_next_stage": true,
  "proceed_conditions": {
    "stabilization_period_elapsed": true,
    "min_requests_met": true,
    "match_rate_acceptable": true,
    "error_rate_acceptable": true,
    "response_time_acceptable": true
  }
}
```

**Errors**:
- `404 Not Found`: 진행 중인 실험 없음

---

### 2.3 다음 단계 승인

```http
POST /abs/api/v1/experiments/{experiment_id}/approve
```

**Request**:
```json
{
  "approved_by": "admin@example.com",
  "comment": "메트릭 확인 완료, 다음 단계 진행"
}
```

**Response** (`200 OK`):
```json
{
  "success": true,
  "message": "Experiment stage approved",
  "data": {
    "experiment_id": "456e7890",
    "previous_percentage": 5,
    "current_percentage": 10,
    "current_stage": 3,
    "approved_by": "admin@example.com",
    "approved_at": "2025-11-30T19:00:00Z",
    "estimated_completion": "2025-12-01T02:00:00Z"
  }
}
```

**Errors**:
- `400 Bad Request`: 진행 조건 미충족
- `404 Not Found`: 실험 없음
- `422 Unprocessable Entity`: 실험이 running 상태가 아님

---

### 2.4 실험 일시 정지

```http
POST /abs/api/v1/experiments/{experiment_id}/pause
```

**Response** (`200 OK`):
```json
{
  "success": true,
  "message": "Experiment paused",
  "data": {
    "experiment_id": "456e7890",
    "status": "paused",
    "current_percentage": 10,
    "paused_at": "2025-11-30T20:00:00Z"
  }
}
```

---

### 2.5 실험 재개

```http
POST /abs/api/v1/experiments/{experiment_id}/resume
```

**Response** (`200 OK`):
```json
{
  "success": true,
  "message": "Experiment resumed",
  "data": {
    "experiment_id": "456e7890",
    "status": "running",
    "current_percentage": 10,
    "resumed_at": "2025-11-30T20:30:00Z"
  }
}
```

---

### 2.6 실험 중단

```http
POST /abs/api/v1/experiments/{experiment_id}/abort
```

**Request**:
```json
{
  "reason": "Modern API 이상 감지",
  "rollback_to": "validation"
}
```

**Request DTO**:
| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `reason` | string | ✓ | - | 중단 이유 |
| `rollback_to` | string | | `validation` | 롤백 모드 (`validation`, `canary:N`, `previous`) |

**Response** (`200 OK`):
```json
{
  "success": true,
  "message": "Experiment aborted and rolled back",
  "data": {
    "experiment_id": "456e7890",
    "status": "aborted",
    "rollback_mode": "validation",
    "rollback_percentage": 0,
    "aborted_at": "2025-11-30T21:00:00Z",
    "aborted_reason": "Modern API 이상 감지"
  }
}
```

---

### 2.7 실험 이력 조회

```http
GET /abs/api/v1/routes/{route_id}/experiments?page=1&limit=10&status=completed
```

**Query Parameters**:
| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `page` | int | 페이지 번호 |
| `limit` | int | 페이지당 항목 수 |
| `status` | string | 상태 필터 (`pending`, `running`, `completed`, `aborted`) |

**Response** (`200 OK`):
```json
{
  "data": [
    {
      "id": "456e7890",
      "route_id": "123e4567",
      "status": "completed",
      "initial_percentage": 1,
      "current_percentage": 100,
      "started_at": "2025-11-30T16:00:00Z",
      "completed_at": "2025-12-01T08:00:00Z",
      "duration_hours": 16
    },
    {
      "id": "567e8901",
      "route_id": "123e4567",
      "status": "aborted",
      "initial_percentage": 1,
      "current_percentage": 5,
      "started_at": "2025-11-20T10:00:00Z",
      "aborted_at": "2025-11-20T15:00:00Z",
      "aborted_reason": "Error rate exceeded threshold"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 15,
    "total_pages": 2
  }
}
```

---

### 2.8 실험 상세 조회

```http
GET /abs/api/v1/experiments/{experiment_id}
```

**Response** (`200 OK`):
```json
{
  "id": "456e7890",
  "route_id": "123e4567",
  "route": {
    "path": "/api/v1/users",
    "method": "GET"
  },
  "status": "completed",
  "initial_percentage": 1,
  "current_percentage": 100,
  "target_percentage": 100,
  "stabilization_period": 3600,
  "current_stage": 6,
  "total_stages": 6,
  "started_at": "2025-11-30T16:00:00Z",
  "completed_at": "2025-12-01T08:00:00Z",
  "stages": [
    {
      "stage": 1,
      "traffic_percentage": 1,
      "total_requests": 125,
      "match_rate": 100.0,
      "error_rate": 0.04,
      "approved_by": "admin@example.com",
      "approved_at": "2025-11-30T17:30:00Z",
      "started_at": "2025-11-30T16:00:00Z",
      "completed_at": "2025-11-30T17:30:00Z"
    },
    {
      "stage": 2,
      "traffic_percentage": 5,
      "total_requests": 520,
      "match_rate": 99.92,
      "error_rate": 0.05,
      "approved_by": "admin@example.com",
      "approved_at": "2025-11-30T19:00:00Z",
      "started_at": "2025-11-30T17:30:00Z",
      "completed_at": "2025-11-30T19:00:00Z"
    }
  ]
}
```

---

### 2.9 실험 타임라인 조회

```http
GET /abs/api/v1/experiments/{experiment_id}/timeline
```

**Response** (`200 OK`):
```json
{
  "experiment_id": "456e7890",
  "timeline": [
    {
      "timestamp": "2025-11-30T16:00:00Z",
      "event_type": "experiment_started",
      "message": "Experiment started at 1%",
      "metadata": {
        "initial_percentage": 1
      }
    },
    {
      "timestamp": "2025-11-30T17:30:00Z",
      "event_type": "stage_approved",
      "message": "Stage 1 approved, traffic increased to 5%",
      "metadata": {
        "stage": 1,
        "from_percentage": 1,
        "to_percentage": 5,
        "approved_by": "admin@example.com"
      }
    },
    {
      "timestamp": "2025-12-01T08:00:00Z",
      "event_type": "experiment_completed",
      "message": "Experiment completed, 100% traffic to Modern API",
      "metadata": {
        "final_percentage": 100
      }
    }
  ],
  "metrics_history": [
    {
      "timestamp": "2025-11-30T16:30:00Z",
      "traffic_percentage": 1,
      "match_rate": 100.0,
      "error_rate": 0.04
    },
    {
      "timestamp": "2025-11-30T17:00:00Z",
      "traffic_percentage": 1,
      "match_rate": 100.0,
      "error_rate": 0.05
    }
  ]
}
```

---

### 2.10 알림 설정 변경

```http
PUT /abs/api/v1/routes/{route_id}/notification-settings
```

**Request**:
```json
{
  "channels": ["slack", "email"],
  "slack_webhook": "https://hooks.slack.com/services/XXX/YYY/ZZZ",
  "email_recipients": ["team@example.com", "admin@example.com"],
  "notify_on_stage_ready": true,
  "notify_on_rollback": true,
  "notify_on_completion": true
}
```

**Response** (`200 OK`):
```json
{
  "route_id": "123e4567",
  "notification_settings": {
    "channels": ["slack", "email"],
    "slack_webhook": "https://hooks.slack.com/services/XXX/YYY/ZZZ",
    "email_recipients": ["team@example.com", "admin@example.com"],
    "notify_on_stage_ready": true,
    "notify_on_rollback": true,
    "notify_on_completion": true,
    "updated_at": "2025-11-30T22:00:00Z"
  }
}
```

---

## 3. 모니터링 API

### 3.1 전체 메트릭 조회

```http
GET /abs/api/v1/metrics
```

**Response** (`200 OK`):
```json
{
  "summary": {
    "total_routes": 50,
    "active_routes": 48,
    "validation_mode": 35,
    "canary_mode": 10,
    "switched_mode": 3,
    "total_requests_today": 250000,
    "avg_match_rate": 99.85,
    "avg_error_rate": 0.06
  },
  "top_routes": [
    {
      "route_id": "123e4567",
      "path": "/api/v1/users",
      "method": "GET",
      "requests_today": 50000,
      "match_rate": 99.95,
      "operation_mode": "validation"
    }
  ]
}
```

---

### 3.2 API별 메트릭 조회

```http
GET /abs/api/v1/metrics/{route_id}?interval=1h&duration=24h
```

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `interval` | string | `1h` | 집계 간격 (`1m`, `5m`, `1h`, `1d`) |
| `duration` | string | `24h` | 조회 기간 (`1h`, `24h`, `7d`, `30d`) |

**Response** (`200 OK`):
```json
{
  "route_id": "123e4567",
  "path": "/api/v1/users",
  "method": "GET",
  "current_metrics": {
    "match_rate": 99.95,
    "error_rate": 0.05,
    "total_requests": 50000,
    "avg_legacy_response_time": 120,
    "avg_modern_response_time": 115
  },
  "time_series": [
    {
      "timestamp": "2025-11-30T00:00:00Z",
      "match_rate": 99.90,
      "error_rate": 0.06,
      "requests": 2000,
      "legacy_avg_response_time": 122,
      "modern_avg_response_time": 117
    },
    {
      "timestamp": "2025-11-30T01:00:00Z",
      "match_rate": 99.95,
      "error_rate": 0.04,
      "requests": 2100,
      "legacy_avg_response_time": 118,
      "modern_avg_response_time": 113
    }
  ]
}
```

---

### 3.3 비교 결과 조회

```http
GET /abs/api/v1/comparisons?route_id=123e4567&is_match=false&page=1&limit=20
```

**Query Parameters**:
| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `route_id` | string | 라우트 ID 필터 |
| `is_match` | boolean | 일치 여부 필터 |
| `start_date` | date | 시작 날짜 |
| `end_date` | date | 종료 날짜 |
| `page` | int | 페이지 번호 |
| `limit` | int | 페이지당 항목 수 |

**Response** (`200 OK`):
```json
{
  "data": [
    {
      "id": "789e0123",
      "route_id": "123e4567",
      "request_id": "req-12345",
      "is_match": false,
      "total_fields": 20,
      "matched_fields": 19,
      "field_match_rate": 95.0,
      "comparison_duration": 15,
      "created_at": "2025-11-30T15:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

---

### 3.4 비교 결과 상세 조회

```http
GET /abs/api/v1/comparisons/{comparison_id}
```

**Response** (`200 OK`):
```json
{
  "id": "789e0123",
  "route_id": "123e4567",
  "request_id": "req-12345",
  "legacy_request": {
    "method": "GET",
    "path": "/api/v1/users/123",
    "query_params": {},
    "headers": {
      "Content-Type": "application/json"
    },
    "timestamp": "2025-11-30T15:30:00Z"
  },
  "legacy_response": {
    "status_code": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "{\"id\":123,\"name\":\"John\",\"age\":30}",
    "response_time": 120,
    "timestamp": "2025-11-30T15:30:00.120Z"
  },
  "modern_request": {
    "method": "GET",
    "path": "/api/v1/users/123",
    "query_params": {},
    "headers": {
      "Content-Type": "application/json"
    },
    "timestamp": "2025-11-30T15:30:00Z"
  },
  "modern_response": {
    "status_code": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "body": "{\"id\":123,\"name\":\"John\",\"age\":31}",
    "response_time": 115,
    "timestamp": "2025-11-30T15:30:00.115Z"
  },
  "is_match": false,
  "total_fields": 3,
  "matched_fields": 2,
  "field_match_rate": 66.67,
  "mismatch_details": [
    {
      "field_path": "age",
      "legacy_value": 30,
      "modern_value": 31,
      "expected_type": "number",
      "actual_type": "number"
    }
  ],
  "comparison_duration": 15,
  "created_at": "2025-11-30T15:30:00.150Z"
}
```

---

## 4. Health Check API

### 4.1 Liveness Probe

```http
GET /abs/health/live
```

**Response** (`200 OK`):
```json
{
  "status": "UP"
}
```

**설명**:
- ABS 프로세스가 실행 중인지 확인
- Kubernetes Liveness Probe용
- 외부 의존성 확인하지 않음

---

### 4.2 Readiness Probe

```http
GET /abs/health/ready
```

**Response** (`200 OK`):
```json
{
  "status": "UP",
  "checks": {
    "database": "UP",
    "redis": "UP",
    "rabbitmq": "UP"
  }
}
```

**Response** (`503 Service Unavailable`):
```json
{
  "status": "DOWN",
  "checks": {
    "database": "UP",
    "redis": "DOWN",
    "rabbitmq": "UP"
  }
}
```

**설명**:
- ABS가 요청 처리 가능한지 확인
- Kubernetes Readiness Probe용
- 외부 의존성 연결 확인 (DB, Redis, RabbitMQ)

---

### 4.3 Health Check 상세

```http
GET /abs/health
```

**Response** (`200 OK`):
```json
{
  "status": "UP",
  "version": "1.0.0",
  "uptime_seconds": 86400,
  "checks": {
    "database": {
      "status": "UP",
      "response_time_ms": 5,
      "details": "OracleDB 19c connected"
    },
    "redis": {
      "status": "UP",
      "response_time_ms": 2,
      "details": "Redis 7.0 connected"
    },
    "rabbitmq": {
      "status": "UP",
      "response_time_ms": 3,
      "details": "RabbitMQ 3.12 connected"
    }
  },
  "timestamp": "2025-11-30T16:00:00Z"
}
```

---

## 5. 공통 응답 구조

### 5.1 성공 응답 (단일 리소스)

```json
{
  "id": "...",
  "field1": "value1",
  "field2": "value2",
  ...
}
```

### 5.2 성공 응답 (리스트)

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

### 5.3 동작 실행 응답

```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    ...
  }
}
```

---

## 6. 참고 사항

### 6.1 관련 문서

- `01-rest-api-design.md`: REST API 설계 원칙
- `03-error-response.md`: 에러 응답 포맷
- `docs/requirement.md`: 요구사항 정의서 (섹션 11. API 명세)

### 6.2 DTO 구현 위치

```
internal/application/dto/
├── route_dto.go
├── experiment_dto.go
├── comparison_dto.go
├── metrics_dto.go
└── health_dto.go
```

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
