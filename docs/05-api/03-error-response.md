# 에러 응답 설계

## 문서 목적

본 문서는 ABS의 에러 응답 포맷과 에러 코드 체계를 정의합니다.

**포함 내용**:
- RFC 7807 Problem Details 포맷
- 에러 코드 체계
- HTTP 상태 코드 매핑
- 에러별 상세 예시

---

## 1. 에러 응답 포맷

### 1.1 RFC 7807 Problem Details

ABS는 **RFC 7807** 표준을 따릅니다:

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Sample size must be between 10 and 1000",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "errors": [
    {
      "field": "sample_size",
      "message": "must be between 10 and 1000",
      "rejected_value": 5000
    }
  ]
}
```

**필드 설명**:
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `type` | URI | ✓ | 에러 타입 식별자 (문서 URL) |
| `title` | string | ✓ | 사람이 읽을 수 있는 에러 제목 |
| `status` | int | ✓ | HTTP 상태 코드 |
| `detail` | string | ✓ | 상세 에러 메시지 |
| `instance` | URI | ✓ | 에러가 발생한 API 경로 |
| `timestamp` | datetime | | 에러 발생 시간 (ISO 8601) |
| `request_id` | string | | 요청 추적 ID |
| `errors` | []object | | 필드별 상세 에러 (유효성 검증 시) |

### 1.2 에러 응답 헤더

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json; charset=utf-8
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
X-Response-Time: 5
```

---

## 2. 에러 코드 체계

### 2.1 에러 코드 구조

```
ABS-{Category}-{Number}

예: ABS-VAL-001, ABS-BIZ-002
```

**Category**:
| 코드 | 카테고리 | 설명 |
|------|----------|------|
| `VAL` | Validation | 유효성 검증 오류 |
| `BIZ` | Business | 비즈니스 규칙 위반 |
| `RES` | Resource | 리소스 관련 오류 (Not Found, Conflict) |
| `AUTH` | Authorization | 인증/인가 오류 |
| `EXT` | External | 외부 서비스 오류 (Legacy/Modern API) |
| `SYS` | System | 시스템 내부 오류 |

### 2.2 에러 코드 목록

#### 2.2.1 유효성 검증 오류 (VAL)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-VAL-001` | 400 | 필수 필드 누락 |
| `ABS-VAL-002` | 400 | 필드 타입 불일치 |
| `ABS-VAL-003` | 400 | 필드 값 범위 초과 |
| `ABS-VAL-004` | 400 | 잘못된 포맷 (URL, Email 등) |
| `ABS-VAL-005` | 400 | JSON 파싱 실패 |

#### 2.2.2 비즈니스 규칙 오류 (BIZ)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-BIZ-001` | 422 | 전환 조건 미충족 |
| `ABS-BIZ-002` | 422 | 실험 진행 조건 미충족 |
| `ABS-BIZ-003` | 422 | 잘못된 상태 전이 |
| `ABS-BIZ-004` | 422 | Operation Mode 불일치 |
| `ABS-BIZ-005` | 422 | 안정화 기간 미경과 |

#### 2.2.3 리소스 오류 (RES)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-RES-001` | 404 | 라우트 없음 |
| `ABS-RES-002` | 404 | 실험 없음 |
| `ABS-RES-003` | 404 | 비교 결과 없음 |
| `ABS-RES-004` | 409 | 중복 라우트 (Path + Method) |
| `ABS-RES-005` | 409 | 진행 중인 실험 존재 |

#### 2.2.4 인증/인가 오류 (AUTH)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-AUTH-001` | 401 | 인증 필요 |
| `ABS-AUTH-002` | 401 | 토큰 만료 |
| `ABS-AUTH-003` | 403 | 권한 없음 |
| `ABS-AUTH-004` | 403 | 관리자 권한 필요 |

#### 2.2.5 외부 서비스 오류 (EXT)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-EXT-001` | 502 | Legacy API 오류 |
| `ABS-EXT-002` | 502 | Modern API 오류 |
| `ABS-EXT-003` | 504 | Legacy API 타임아웃 |
| `ABS-EXT-004` | 504 | Modern API 타임아웃 |
| `ABS-EXT-005` | 503 | Database 연결 실패 |
| `ABS-EXT-006` | 503 | Redis 연결 실패 |
| `ABS-EXT-007` | 503 | RabbitMQ 연결 실패 |

#### 2.2.6 시스템 오류 (SYS)

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `ABS-SYS-001` | 500 | 내부 서버 오류 |
| `ABS-SYS-002` | 500 | 예상치 못한 오류 |
| `ABS-SYS-003` | 503 | 서비스 점검 중 |
| `ABS-SYS-004` | 503 | 서버 과부하 |

---

## 3. HTTP 상태 코드별 에러 응답

### 3.1 400 Bad Request - 유효성 검증 실패

**시나리오**: 필수 필드 누락

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-VAL-001",
  "title": "Validation Error",
  "status": 400,
  "detail": "Required fields are missing",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-VAL-001",
  "errors": [
    {
      "field": "path",
      "message": "path is required"
    },
    {
      "field": "method",
      "message": "method is required"
    }
  ]
}
```

**시나리오**: 필드 값 범위 초과

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-VAL-003",
  "title": "Validation Error",
  "status": 400,
  "detail": "Field value out of acceptable range",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-VAL-003",
  "errors": [
    {
      "field": "sample_size",
      "message": "must be between 10 and 1000",
      "rejected_value": 5000
    },
    {
      "field": "canary_percentage",
      "message": "must be between 0 and 100",
      "rejected_value": 150
    }
  ]
}
```

**시나리오**: JSON 파싱 실패

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-VAL-005",
  "title": "JSON Parsing Error",
  "status": 400,
  "detail": "Invalid JSON syntax: unexpected token at position 42",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-VAL-005"
}
```

---

### 3.2 401 Unauthorized - 인증 필요

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json
WWW-Authenticate: Bearer

{
  "type": "https://abs.example.com/errors/ABS-AUTH-001",
  "title": "Authentication Required",
  "status": 401,
  "detail": "This endpoint requires authentication. Please provide a valid Bearer token.",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-AUTH-001"
}
```

**시나리오**: 토큰 만료

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-AUTH-002",
  "title": "Token Expired",
  "status": 401,
  "detail": "The provided authentication token has expired",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-AUTH-002",
  "expired_at": "2025-11-30T14:00:00Z"
}
```

---

### 3.3 403 Forbidden - 권한 없음

```http
HTTP/1.1 403 Forbidden
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-AUTH-004",
  "title": "Insufficient Permissions",
  "status": 403,
  "detail": "This operation requires administrator privileges",
  "instance": "/abs/api/v1/routes/123e4567/switch",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-AUTH-004",
  "required_role": "admin",
  "current_role": "viewer"
}
```

---

### 3.4 404 Not Found - 리소스 없음

```http
HTTP/1.1 404 Not Found
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-RES-001",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "Route with ID '123e4567' not found",
  "instance": "/abs/api/v1/routes/123e4567",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-RES-001",
  "resource_type": "Route",
  "resource_id": "123e4567"
}
```

---

### 3.5 409 Conflict - 충돌

**시나리오**: 중복 라우트 생성

```http
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-RES-004",
  "title": "Resource Conflict",
  "status": 409,
  "detail": "A route with path '/api/v1/users' and method 'GET' already exists",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-RES-004",
  "conflicting_resource_id": "existing-route-123",
  "conflicting_fields": {
    "path": "/api/v1/users",
    "method": "GET"
  }
}
```

**시나리오**: 진행 중인 실험 존재

```http
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-RES-005",
  "title": "Resource Conflict",
  "status": 409,
  "detail": "An active experiment already exists for this route",
  "instance": "/abs/api/v1/routes/123e4567/experiments",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-RES-005",
  "active_experiment_id": "456e7890",
  "experiment_status": "running"
}
```

---

### 3.6 422 Unprocessable Entity - 비즈니스 규칙 위반

**시나리오**: 전환 조건 미충족

```http
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-BIZ-001",
  "title": "Business Rule Violation",
  "status": 422,
  "detail": "Cannot switch to Modern API: conditions not met",
  "instance": "/abs/api/v1/routes/123e4567/switch",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-BIZ-001",
  "violations": [
    {
      "rule": "match_rate_must_be_100",
      "current_value": 99.5,
      "required_value": 100.0
    },
    {
      "rule": "total_requests_must_exceed_sample_size",
      "current_value": 80,
      "required_value": 100
    }
  ]
}
```

**시나리오**: 실험 진행 조건 미충족

```http
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-BIZ-002",
  "title": "Business Rule Violation",
  "status": 422,
  "detail": "Cannot proceed to next stage: conditions not met",
  "instance": "/abs/api/v1/experiments/456e7890/approve",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-BIZ-002",
  "violations": [
    {
      "rule": "stabilization_period_must_elapse",
      "elapsed_seconds": 1800,
      "required_seconds": 3600
    },
    {
      "rule": "match_rate_must_be_99_9_percent",
      "current_value": 99.85,
      "required_value": 99.9
    }
  ]
}
```

**시나리오**: 잘못된 상태 전이

```http
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-BIZ-003",
  "title": "Invalid State Transition",
  "status": 422,
  "detail": "Cannot resume experiment: invalid status",
  "instance": "/abs/api/v1/experiments/456e7890/resume",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-BIZ-003",
  "current_status": "completed",
  "requested_transition": "resume",
  "allowed_statuses": ["paused"]
}
```

---

### 3.7 500 Internal Server Error - 서버 오류

```http
HTTP/1.1 500 Internal Server Error
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-SYS-001",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-SYS-001"
}
```

**특징**:
- 스택 트레이스 포함하지 않음 (보안)
- 상세 정보는 서버 로그에만 기록
- `request_id`로 로그 추적 가능

---

### 3.8 502 Bad Gateway - 외부 서비스 오류

**시나리오**: Legacy API 오류

```http
HTTP/1.1 502 Bad Gateway
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-EXT-001",
  "title": "External Service Error",
  "status": 502,
  "detail": "Legacy API returned error: Internal Server Error",
  "instance": "/api/v1/users",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-EXT-001",
  "upstream_service": "Legacy API",
  "upstream_status": 500,
  "upstream_host": "api-host:8080"
}
```

---

### 3.9 503 Service Unavailable - 서비스 불가

**시나리오**: Database 연결 실패

```http
HTTP/1.1 503 Service Unavailable
Content-Type: application/problem+json
Retry-After: 60

{
  "type": "https://abs.example.com/errors/ABS-EXT-005",
  "title": "Service Unavailable",
  "status": 503,
  "detail": "Database connection failed. Please try again later.",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-EXT-005",
  "retry_after_seconds": 60
}
```

**시나리오**: 서비스 점검 중

```http
HTTP/1.1 503 Service Unavailable
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-SYS-003",
  "title": "Service Under Maintenance",
  "status": 503,
  "detail": "ABS is currently under maintenance. Please try again later.",
  "instance": "/abs/api/v1/routes",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-SYS-003",
  "maintenance_end": "2025-11-30T17:00:00Z"
}
```

---

### 3.10 504 Gateway Timeout - 타임아웃

```http
HTTP/1.1 504 Gateway Timeout
Content-Type: application/problem+json

{
  "type": "https://abs.example.com/errors/ABS-EXT-003",
  "title": "Gateway Timeout",
  "status": 504,
  "detail": "Legacy API did not respond within 30 seconds",
  "instance": "/api/v1/users",
  "timestamp": "2025-11-30T15:30:00Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABS-EXT-003",
  "upstream_service": "Legacy API",
  "timeout_seconds": 30
}
```

---

## 4. 필드별 유효성 검증 에러

### 4.1 에러 객체 구조

```json
{
  "field": "sample_size",
  "message": "must be between 10 and 1000",
  "rejected_value": 5000,
  "constraint": {
    "type": "range",
    "min": 10,
    "max": 1000
  }
}
```

**필드 설명**:
| 필드 | 타입 | 설명 |
|------|------|------|
| `field` | string | 에러가 발생한 필드명 |
| `message` | string | 에러 메시지 |
| `rejected_value` | any | 거부된 값 |
| `constraint` | object | 제약 조건 (선택사항) |

### 4.2 유효성 검증 규칙별 예시

#### 4.2.1 필수 필드 (Required)

```json
{
  "field": "path",
  "message": "path is required",
  "rejected_value": null,
  "constraint": {
    "type": "required"
  }
}
```

#### 4.2.2 타입 검증 (Type)

```json
{
  "field": "sample_size",
  "message": "must be an integer",
  "rejected_value": "100",
  "constraint": {
    "type": "type",
    "expected": "integer",
    "actual": "string"
  }
}
```

#### 4.2.3 범위 검증 (Range)

```json
{
  "field": "canary_percentage",
  "message": "must be between 0 and 100",
  "rejected_value": 150,
  "constraint": {
    "type": "range",
    "min": 0,
    "max": 100
  }
}
```

#### 4.2.4 패턴 검증 (Pattern)

```json
{
  "field": "path",
  "message": "must start with '/'",
  "rejected_value": "api/v1/users",
  "constraint": {
    "type": "pattern",
    "pattern": "^/.*"
  }
}
```

#### 4.2.5 Enum 검증

```json
{
  "field": "operation_mode",
  "message": "must be one of: validation, canary, switched",
  "rejected_value": "invalid_mode",
  "constraint": {
    "type": "enum",
    "allowed_values": ["validation", "canary", "switched"]
  }
}
```

---

## 5. 에러 처리 모범 사례

### 5.1 클라이언트 에러 처리 예시

```javascript
// JavaScript 클라이언트 예시
async function createRoute(routeData) {
  try {
    const response = await fetch('/abs/api/v1/routes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(routeData)
    });

    if (!response.ok) {
      const error = await response.json();

      // HTTP 상태 코드별 처리
      switch (error.status) {
        case 400:
          // 유효성 검증 실패
          displayValidationErrors(error.errors);
          break;
        case 409:
          // 충돌
          showConflictDialog(error.detail);
          break;
        case 500:
          // 서버 오류
          showErrorMessage('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
          logError(error.request_id);
          break;
        default:
          showErrorMessage(error.detail);
      }

      return null;
    }

    return await response.json();
  } catch (err) {
    console.error('Network error:', err);
    showErrorMessage('네트워크 오류가 발생했습니다.');
    return null;
  }
}
```

### 5.2 서버 에러 로깅

```go
// Go 서버 예시
func (h *RouteHandler) handleError(c *gin.Context, err error) {
    requestID := c.GetString("request_id")

    // 에러 타입에 따라 분류
    switch e := err.(type) {
    case *ValidationError:
        h.logger.Warn("Validation error",
            "request_id", requestID,
            "errors", e.Errors,
        )
        c.JSON(400, e.ToProblemDetails())

    case *BusinessError:
        h.logger.Warn("Business rule violation",
            "request_id", requestID,
            "code", e.Code,
            "detail", e.Detail,
        )
        c.JSON(422, e.ToProblemDetails())

    case *NotFoundError:
        h.logger.Info("Resource not found",
            "request_id", requestID,
            "resource", e.ResourceType,
            "id", e.ResourceID,
        )
        c.JSON(404, e.ToProblemDetails())

    default:
        // 예상치 못한 오류
        h.logger.Error("Unexpected error",
            "request_id", requestID,
            "error", err,
            "stack", string(debug.Stack()),
        )
        c.JSON(500, NewInternalServerError(requestID))
    }
}
```

---

## 6. 에러 응답 구현

### 6.1 에러 구조체 정의

```go
// internal/adapter/in/http/errors/problem_details.go

type ProblemDetails struct {
    Type      string                 `json:"type"`
    Title     string                 `json:"title"`
    Status    int                    `json:"status"`
    Detail    string                 `json:"detail"`
    Instance  string                 `json:"instance"`
    Timestamp string                 `json:"timestamp"`
    RequestID string                 `json:"request_id"`
    Code      string                 `json:"code,omitempty"`
    Errors    []FieldError           `json:"errors,omitempty"`
    Extra     map[string]interface{} `json:"extra,omitempty"`
}

type FieldError struct {
    Field         string      `json:"field"`
    Message       string      `json:"message"`
    RejectedValue interface{} `json:"rejected_value,omitempty"`
    Constraint    *Constraint `json:"constraint,omitempty"`
}

type Constraint struct {
    Type          string        `json:"type"`
    Min           *int          `json:"min,omitempty"`
    Max           *int          `json:"max,omitempty"`
    Pattern       string        `json:"pattern,omitempty"`
    AllowedValues []string      `json:"allowed_values,omitempty"`
    Expected      string        `json:"expected,omitempty"`
    Actual        string        `json:"actual,omitempty"`
}
```

### 6.2 에러 생성 헬퍼

```go
func NewValidationError(instance string, errors []FieldError) *ProblemDetails {
    return &ProblemDetails{
        Type:      "https://abs.example.com/errors/ABS-VAL-001",
        Title:     "Validation Error",
        Status:    400,
        Detail:    "Request validation failed",
        Instance:  instance,
        Timestamp: time.Now().UTC().Format(time.RFC3339),
        Code:      "ABS-VAL-001",
        Errors:    errors,
    }
}

func NewNotFoundError(resourceType, resourceID, instance string) *ProblemDetails {
    return &ProblemDetails{
        Type:      "https://abs.example.com/errors/ABS-RES-001",
        Title:     "Resource Not Found",
        Status:    404,
        Detail:    fmt.Sprintf("%s with ID '%s' not found", resourceType, resourceID),
        Instance:  instance,
        Timestamp: time.Now().UTC().Format(time.RFC3339),
        Code:      "ABS-RES-001",
        Extra: map[string]interface{}{
            "resource_type": resourceType,
            "resource_id":   resourceID,
        },
    }
}
```

---

## 7. 참고 사항

### 7.1 관련 문서

- `01-rest-api-design.md`: REST API 설계 원칙
- `02-endpoint-specification.md`: 엔드포인트 명세
- `docs/07-security/02-log-security.md`: 로그 보안 (에러 로깅)

### 7.2 참고 자료

- [RFC 7807 - Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807)
- [HTTP 상태 코드](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
