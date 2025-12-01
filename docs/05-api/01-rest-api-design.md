# REST API 설계 원칙

## 문서 목적

본 문서는 ABS의 REST API 설계 원칙과 가이드라인을 정의합니다.

**포함 내용**:
- REST API 설계 원칙
- URL 설계 규칙
- HTTP 메서드 사용 가이드
- 버전 관리 전략
- CORS 정책
- 요청/응답 포맷

---

## 1. REST API 설계 원칙

### 1.1 기본 원칙

ABS는 **RESTful API** 설계 원칙을 따릅니다:

| 원칙 | 설명 | 예시 |
|------|------|------|
| **리소스 중심** | URL은 리소스를 표현 | `/routes`, `/experiments` |
| **HTTP 메서드 활용** | 동작은 HTTP 메서드로 표현 | GET, POST, PUT, DELETE |
| **무상태성 (Stateless)** | 각 요청은 독립적 | 서버는 세션 상태를 저장하지 않음 |
| **계층적 구조** | 리소스 간 관계 표현 | `/routes/{id}/experiments` |
| **일관성** | 명명 규칙 통일 | snake_case, kebab-case 통일 |

### 1.2 Richardson 성숙도 모델

ABS API는 **Level 2** 수준을 목표로 합니다:

```
Level 0: HTTP를 전송 수단으로만 사용
Level 1: 리소스 개념 도입
Level 2: HTTP 메서드 활용 ✓ (ABS 목표)
Level 3: HATEOAS (Hypermedia) - 선택사항
```

---

## 2. URL 설계 규칙

### 2.1 URL 구조

```
{scheme}://{host}:{port}/{context-path}/{version}/{resource}/{id}/{sub-resource}
```

**예시**:
```
https://abs.example.com/abs/api/v1/routes/123e4567/experiments
```

**구성 요소**:
- `scheme`: `https` (프로덕션), `http` (개발)
- `host`: `abs.example.com`
- `port`: 명시하지 않음 (기본 80/443)
- `context-path`: `/abs` (ABS 관리 API)
- `version`: `/api/v1`
- `resource`: `/routes`, `/experiments`, `/comparisons`
- `id`: 리소스 식별자 (UUID)
- `sub-resource`: 하위 리소스

### 2.2 Context-Path 규칙

| Context-Path | 용도 | 예시 |
|--------------|------|------|
| `/abs/api/v1/*` | ABS 관리 API | `/abs/api/v1/routes` |
| `/abs/health/*` | Health Check | `/abs/health/live` |
| `/abs/metrics` | Prometheus 메트릭 | `/abs/metrics` |
| 그 외 모든 경로 | 프록시 대상 API | `/api/v1/users`, `/service/data` |

**중요**: `/abs/*` 경로는 **예약어**이며, Legacy/Modern 서비스로 프록시되지 않습니다.

### 2.3 리소스 명명 규칙

#### 2.3.1 기본 규칙

| 항목 | 규칙 | 예시 |
|------|------|------|
| 리소스명 | 복수형 명사 | `/routes`, `/experiments` (O)<br>`/route`, `/experiment` (X) |
| 대소문자 | 소문자 kebab-case | `/experiment-stages` (O)<br>`/experimentStages` (X) |
| 단어 구분 | 하이픈 (`-`) 사용 | `/match-rates` (O)<br>`/match_rates` (X) |
| 계층 구조 | 슬래시 (`/`) 사용 | `/routes/{id}/experiments` |
| 마지막 슬래시 | 사용하지 않음 | `/routes` (O)<br>`/routes/` (X) |

#### 2.3.2 리소스 계층 구조

```
/routes                          # 라우트 목록
/routes/{route_id}               # 특정 라우트
/routes/{route_id}/experiments   # 라우트의 실험 목록
/routes/{route_id}/experiments/{experiment_id}  # 특정 실험
/routes/{route_id}/experiments/{experiment_id}/stages  # 실험 단계 목록
```

**규칙**:
- 최대 3단계 깊이까지 허용
- 4단계 이상은 쿼리 파라미터로 해결

#### 2.3.3 동작 표현

| 동작 | 잘못된 예 | 올바른 예 |
|------|-----------|-----------|
| 승인 | `GET /experiments/{id}/approve` | `POST /experiments/{id}/approve` |
| 일시 정지 | `GET /experiments/{id}/pause` | `POST /experiments/{id}/pause` |
| 중단 | `DELETE /experiments/{id}` | `POST /experiments/{id}/abort` |
| 전환 | `PUT /routes/{id}?switch=true` | `POST /routes/{id}/switch` |

**원칙**: RPC 스타일 동작은 POST 메서드 + 동사형 경로 사용

### 2.4 쿼리 파라미터

#### 2.4.1 페이지네이션

```
GET /comparisons?page=1&limit=20
```

| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `page` | int | 1 | 페이지 번호 (1부터 시작) |
| `limit` | int | 20 | 페이지당 항목 수 (최대 100) |

**응답 예시**:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

#### 2.4.2 필터링

```
GET /comparisons?route_id=123&is_match=false&start_date=2025-11-01
```

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `route_id` | string | 라우트 ID |
| `is_match` | boolean | 일치 여부 |
| `start_date` | date | 시작 날짜 (ISO 8601) |
| `end_date` | date | 종료 날짜 (ISO 8601) |

#### 2.4.3 정렬

```
GET /comparisons?sort=created_at&order=desc
```

| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `sort` | string | `created_at` | 정렬 필드 |
| `order` | string | `desc` | 정렬 방향 (`asc`, `desc`) |

#### 2.4.4 필드 선택 (Sparse Fieldsets)

```
GET /routes?fields=id,path,method,match_rate
```

**응답**:
```json
{
  "data": [
    {
      "id": "123",
      "path": "/api/v1/users",
      "method": "GET",
      "match_rate": 99.5
    }
  ]
}
```

---

## 3. HTTP 메서드 사용 가이드

### 3.1 메서드별 용도

| 메서드 | 용도 | 멱등성 | 안전성 | Body |
|--------|------|--------|--------|------|
| **GET** | 리소스 조회 | ✓ | ✓ | 없음 |
| **POST** | 리소스 생성, 동작 실행 | ✗ | ✗ | 있음 |
| **PUT** | 리소스 전체 수정 | ✓ | ✗ | 있음 |
| **PATCH** | 리소스 부분 수정 | ✗ | ✗ | 있음 |
| **DELETE** | 리소스 삭제 | ✓ | ✗ | 없음 |

**멱등성 (Idempotent)**: 동일 요청을 여러 번 실행해도 결과가 같음
**안전성 (Safe)**: 리소스 상태를 변경하지 않음

### 3.2 메서드별 예시

#### 3.2.1 GET - 조회

```http
# 목록 조회
GET /abs/api/v1/routes

# 단일 조회
GET /abs/api/v1/routes/123e4567

# 하위 리소스 조회
GET /abs/api/v1/routes/123e4567/experiments
```

**특징**:
- Request Body 없음
- 캐싱 가능
- 북마크 가능

#### 3.2.2 POST - 생성 및 동작

```http
# 리소스 생성
POST /abs/api/v1/routes
Content-Type: application/json

{
  "path": "/api/v1/users",
  "method": "GET",
  "legacy_host": "api-host",
  "legacy_port": 8080,
  "modern_host": "api-host",
  "modern_port": 9080
}

# 동작 실행
POST /abs/api/v1/experiments/123e4567/approve
Content-Type: application/json

{
  "approved_by": "admin@example.com"
}
```

**응답**:
- 생성: `201 Created` + `Location` 헤더
- 동작: `200 OK` 또는 `202 Accepted`

#### 3.2.3 PUT - 전체 수정

```http
PUT /abs/api/v1/routes/123e4567
Content-Type: application/json

{
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 200,
  "operation_mode": "canary",
  "canary_percentage": 10,
  ...모든 필드
}
```

**특징**:
- 리소스 전체를 교체
- 누락된 필드는 기본값으로 설정
- 멱등성 보장

#### 3.2.4 PATCH - 부분 수정

```http
PATCH /abs/api/v1/routes/123e4567
Content-Type: application/json

{
  "sample_size": 200,
  "canary_percentage": 10
}
```

**특징**:
- 지정된 필드만 수정
- 누락된 필드는 변경하지 않음
- ABS에서는 **PATCH를 주로 사용**

#### 3.2.5 DELETE - 삭제

```http
DELETE /abs/api/v1/routes/123e4567
```

**응답**:
- 삭제 성공: `204 No Content`
- 이미 삭제됨: `404 Not Found`

### 3.3 HTTP 상태 코드

#### 3.3.1 성공 응답 (2xx)

| 코드 | 의미 | 사용 시점 |
|------|------|-----------|
| `200 OK` | 성공 | GET, PUT, PATCH, POST (조회/수정/동작) |
| `201 Created` | 생성 성공 | POST (리소스 생성) |
| `202 Accepted` | 요청 수락 | POST (비동기 작업 시작) |
| `204 No Content` | 성공, 응답 없음 | DELETE |

#### 3.3.2 클라이언트 오류 (4xx)

| 코드 | 의미 | 사용 시점 |
|------|------|-----------|
| `400 Bad Request` | 잘못된 요청 | 유효성 검증 실패 |
| `401 Unauthorized` | 인증 필요 | API Gateway에서 처리 |
| `403 Forbidden` | 권한 없음 | 관리자 권한 필요 |
| `404 Not Found` | 리소스 없음 | ID로 조회 실패 |
| `409 Conflict` | 충돌 | 중복 리소스 생성 시도 |
| `422 Unprocessable Entity` | 의미적 오류 | 비즈니스 규칙 위반 |

#### 3.3.3 서버 오류 (5xx)

| 코드 | 의미 | 사용 시점 |
|------|------|-----------|
| `500 Internal Server Error` | 서버 오류 | 예상치 못한 오류 |
| `502 Bad Gateway` | 게이트웨이 오류 | Legacy/Modern API 오류 |
| `503 Service Unavailable` | 서비스 불가 | 유지보수 중 |
| `504 Gateway Timeout` | 게이트웨이 타임아웃 | Legacy/Modern API 타임아웃 |

---

## 4. 버전 관리 전략

### 4.1 버전 표기 방식

ABS는 **URL 경로 버전 관리**를 사용합니다:

```
/abs/api/v1/routes
       ^^^
       버전
```

**선택 이유**:
- 명확하고 직관적
- 북마크 및 공유 가능
- 프록시/캐시 친화적

**대안 (미사용)**:
- 헤더 버전: `Accept: application/vnd.abs.v1+json` (복잡)
- 쿼리 버전: `/routes?version=1` (비표준)

### 4.2 버전 변경 정책

#### 4.2.1 메이저 버전 (v1 → v2)

**변경 시점**:
- 호환성 없는 변경 (Breaking Change)
- API 구조 대폭 변경
- 필수 필드 추가/삭제

**예시**:
```
v1: GET /routes → { "id": "123", "path": "/api/users" }
v2: GET /routes → { "route_id": "123", "endpoint": "/api/users" }
                   ^^^^^^^^       ^^^^^^^^
                   필드명 변경
```

**마이그레이션**:
- v1과 v2 동시 운영 (최소 6개월)
- 클라이언트에 마이그레이션 공지
- v1 Deprecation 경고 (응답 헤더)

#### 4.2.2 마이너 버전 (선택사항)

ABS는 **마이너 버전을 사용하지 않습니다**.

**이유**:
- 하위 호환 가능한 변경은 v1 내에서 처리
- 선택적 필드 추가는 버전 변경 불필요
- 단순성 유지

### 4.3 하위 호환성 유지

#### 4.3.1 안전한 변경

| 변경 유형 | 예시 | 버전 변경 |
|-----------|------|-----------|
| 선택적 필드 추가 | `description` 필드 추가 | 불필요 |
| 새 엔드포인트 추가 | `POST /routes/{id}/reset` | 불필요 |
| 에러 코드 추가 | `ERR_QUOTA_EXCEEDED` | 불필요 |
| Enum 값 추가 | `OperationMode: "hybrid"` | 불필요 |

#### 4.3.2 위험한 변경 (Breaking Change)

| 변경 유형 | 예시 | 버전 변경 |
|-----------|------|-----------|
| 필드명 변경 | `match_rate` → `matching_rate` | **필요 (v2)** |
| 필드 타입 변경 | `sample_size: int` → `string` | **필요 (v2)** |
| 필수 필드 추가 | `region` 필드 필수화 | **필요 (v2)** |
| 엔드포인트 삭제 | `DELETE /routes/{id}` 제거 | **필요 (v2)** |

### 4.4 Deprecation 정책

**Deprecated 응답 헤더**:
```http
HTTP/1.1 200 OK
Deprecation: true
Sunset: Sat, 01 Jun 2026 00:00:00 GMT
Link: </abs/api/v2/routes>; rel="successor-version"
```

**Deprecated 경고 로그**:
```json
{
  "data": {...},
  "warning": "This API version (v1) is deprecated and will be removed on 2026-06-01. Please migrate to v2."
}
```

---

## 5. CORS 정책

### 5.1 기본 정책

ABS는 **제한적 CORS**를 지원합니다:

```go
// CORS 설정
corsConfig := cors.Config{
    AllowOrigins:     []string{"https://abs-dashboard.example.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE"},
    AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
    ExposeHeaders:    []string{"Content-Length", "X-Request-ID"},
    AllowCredentials: true,
    MaxAge:           12 * time.Hour,
}
```

### 5.2 환경별 설정

| 환경 | AllowOrigins |
|------|--------------|
| **개발** | `*` (모든 출처 허용) |
| **스테이징** | `https://*.stg.example.com` |
| **프로덕션** | `https://abs-dashboard.example.com` (화이트리스트) |

### 5.3 Preflight 요청 처리

```http
# Preflight 요청
OPTIONS /abs/api/v1/routes HTTP/1.1
Origin: https://abs-dashboard.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type

# Preflight 응답
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://abs-dashboard.example.com
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 43200
```

---

## 6. 요청/응답 포맷

### 6.1 Content-Type

**요청**:
```http
POST /abs/api/v1/routes
Content-Type: application/json; charset=utf-8
```

**응답**:
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
```

**지원 포맷**:
- `application/json` (기본, 필수)
- `application/problem+json` (에러 응답, RFC 7807)

### 6.2 날짜/시간 포맷

**ISO 8601** 표준 사용:

```json
{
  "created_at": "2025-11-30T10:30:00Z",
  "updated_at": "2025-11-30T15:45:00+09:00"
}
```

**형식**:
- `YYYY-MM-DDTHH:mm:ssZ` (UTC)
- `YYYY-MM-DDTHH:mm:ss±hh:mm` (타임존 포함)

### 6.3 숫자 포맷

```json
{
  "match_rate": 99.95,          // float64, 소수점 2자리
  "total_requests": 1500,       // int64
  "canary_percentage": 25       // int
}
```

**규칙**:
- 정수: 따옴표 없이 표기
- 부동소수점: 소수점 2자리까지 (비즈니스 로직에서 반올림)
- 매우 큰 수: 문자열 사용 (예: `"9223372036854775807"`)

### 6.4 Boolean 포맷

```json
{
  "is_active": true,
  "is_match": false
}
```

**규칙**:
- `true` / `false` (소문자, 따옴표 없음)
- `"true"` / `"false"` (문자열) 사용 금지

### 6.5 Null 처리

```json
{
  "started_at": null,          // 시작 안 함
  "aborted_reason": null       // 중단 안 함
}
```

**규칙**:
- 값이 없는 경우 `null` 사용
- 필드 자체를 생략하지 않음 (명시적)
- 빈 문자열 `""` 사용 금지

---

## 7. 공통 헤더

### 7.1 요청 헤더

| 헤더 | 필수 | 설명 | 예시 |
|------|------|------|------|
| `Content-Type` | ✓ (POST/PUT/PATCH) | 요청 본문 타입 | `application/json` |
| `Authorization` | (API Gateway) | 인증 토큰 | `Bearer eyJ...` |
| `X-Request-ID` | | 요청 추적 ID | `550e8400-e29b-41d4-a716` |
| `X-User-ID` | | 사용자 ID (Canary 분배용) | `user-12345` |

### 7.2 응답 헤더

| 헤더 | 설명 | 예시 |
|------|------|------|
| `Content-Type` | 응답 본문 타입 | `application/json; charset=utf-8` |
| `X-Request-ID` | 요청 추적 ID (요청 헤더 반환) | `550e8400-e29b-41d4-a716` |
| `X-Response-Time` | 응답 시간 (ms) | `45` |
| `Location` | 생성된 리소스 위치 (201) | `/abs/api/v1/routes/123` |
| `Deprecation` | API Deprecated 여부 | `true` |
| `Sunset` | API 종료 예정일 | `Sat, 01 Jun 2026 00:00:00 GMT` |

---

## 8. 성공 응답 포맷

### 8.1 단일 리소스 조회

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "path": "/api/v1/users",
  "method": "GET",
  "sample_size": 100,
  "operation_mode": "validation",
  "match_rate": 99.95,
  "created_at": "2025-11-30T10:00:00Z",
  "updated_at": "2025-11-30T15:30:00Z"
}
```

**특징**:
- 루트가 객체
- 메타데이터 포함 안 함 (단순성)

### 8.2 리스트 조회

```json
{
  "data": [
    {
      "id": "123e4567",
      "path": "/api/v1/users",
      "method": "GET"
    },
    {
      "id": "234e5678",
      "path": "/api/v1/orders",
      "method": "POST"
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

**특징**:
- `data` 배열에 리소스 목록
- `pagination` 메타데이터

### 8.3 생성 응답 (201 Created)

```http
HTTP/1.1 201 Created
Location: /abs/api/v1/routes/123e4567
Content-Type: application/json

{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "path": "/api/v1/users",
  "method": "GET",
  ...
}
```

**특징**:
- `201 Created` 상태 코드
- `Location` 헤더에 생성된 리소스 URL
- 응답 본문에 생성된 리소스 전체

### 8.4 동작 실행 응답

```json
{
  "success": true,
  "message": "Experiment approved successfully",
  "data": {
    "experiment_id": "123e4567",
    "new_percentage": 10,
    "approved_by": "admin@example.com",
    "approved_at": "2025-11-30T15:30:00Z"
  }
}
```

---

## 9. 보안 고려사항

### 9.1 인증/인가

**API Gateway 레벨 처리**:
- ABS는 인증된 요청만 수신
- `Authorization` 헤더는 API Gateway에서 검증
- ABS 내부에서는 추가 인증 불필요

**관리 API 권한**:
```go
// 관리자 권한 필요
POST /abs/api/v1/routes/{id}/switch
DELETE /abs/api/v1/routes/{id}

// 일반 사용자 가능
GET /abs/api/v1/routes
GET /abs/api/v1/metrics
```

### 9.2 Rate Limiting

**API Gateway 레벨 제한**:
- 초당 100 요청 (per IP)
- 분당 1,000 요청 (per API Key)

**응답 헤더**:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1638316800
```

### 9.3 HTTPS 강제

**프로덕션**:
- 모든 요청은 HTTPS
- HTTP 요청 시 `301 Moved Permanently` → HTTPS

**개발**:
- HTTP 허용 (로컬 환경)

---

## 10. 참고 사항

### 10.1 관련 문서

- `02-endpoint-specification.md`: 엔드포인트 상세 명세
- `03-error-response.md`: 에러 응답 포맷
- `docs/02-domain/01-domain-model.md`: 도메인 모델 정의

### 10.2 참고 자료

- [RESTful API 설계 가이드](https://restfulapi.net/)
- [HTTP 상태 코드](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [RFC 7807 - Problem Details](https://www.rfc-editor.org/rfc/rfc7807)
- [ISO 8601 - 날짜/시간 포맷](https://en.wikipedia.org/wiki/ISO_8601)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
