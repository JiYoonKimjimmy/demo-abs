# Port 인터페이스 명세

## 문서 목적

본 문서는 ABS의 도메인 계층과 외부 세계를 연결하는 Port 인터페이스를 정의합니다.

**헥사고날 아키텍처의 Port**:
- **Outbound Port (Driven Port)**: 도메인 계층이 외부 인프라를 호출하기 위한 인터페이스
- 도메인 계층에 정의, 인프라 계층에서 구현

**포함 내용**:
- Repository Port (OracleDB)
- Cache Port (Redis)
- Message Publisher Port (RabbitMQ)
- API Client Port (Legacy/Modern API)
- Notification Port (Slack/Email)

---

## 1. Repository Port

### 1.1 RouteRepository

API 라우트 정보를 영속화하는 Repository입니다.

#### 인터페이스

**`Create(ctx context.Context, route *Route) error`**
- 라우트 생성

**`FindByID(ctx context.Context, id string) (*Route, error)`**
- ID로 라우트 조회

**`FindByPathAndMethod(ctx context.Context, path, method string) (*Route, error)`**
- 경로 및 메서드로 라우트 조회

**`FindAll(ctx context.Context, filter RouteFilter) ([]*Route, error)`**
- 모든 라우트 조회 (필터, 페이지네이션)

**`Update(ctx context.Context, route *Route) error`**
- 라우트 수정

**`Delete(ctx context.Context, id string) error`**
- 라우트 삭제

**`UpdateMatchRate(ctx context.Context, id string, matchRate float64, totalRequests, matchedRequests int64) error`**
- 일치율 갱신

**`UpdateOperationMode(ctx context.Context, id string, mode OperationMode, canaryPercentage int) error`**
- 운영 모드 변경

#### RouteFilter

| 필드 | 타입 | 설명 |
|------|------|------|
| `IsActive` | `*bool` | 활성화 여부 필터 |
| `OperationMode` | `*OperationMode` | 운영 모드 필터 |
| `Limit` | `int` | 페이지 크기 |
| `Offset` | `int` | 페이지 오프셋 |

---

### 1.2 ComparisonRepository

비교 결과를 영속화하는 Repository입니다.

#### 인터페이스

**`Create(ctx context.Context, comparison *Comparison) error`**
- 비교 결과 생성

**`FindByID(ctx context.Context, id string) (*Comparison, error)`**
- ID로 비교 결과 조회

**`FindByRouteID(ctx context.Context, routeID string, filter ComparisonFilter) ([]*Comparison, error)`**
- 라우트 ID로 비교 결과 목록 조회

**`FindMismatches(ctx context.Context, routeID string, limit int) ([]*Comparison, error)`**
- 불일치 결과만 조회

**`CountByRouteID(ctx context.Context, routeID string) (total, matched int64, err error)`**
- 라우트별 비교 결과 수 집계

**`DeleteOld(ctx context.Context, retentionDays int) (int64, error)`**
- 오래된 비교 결과 삭제 (기본: 30일)

#### ComparisonFilter

| 필드 | 타입 | 설명 |
|------|------|------|
| `IsMatch` | `*bool` | 일치 여부 필터 |
| `StartTime` | `*time.Time` | 시작 시간 |
| `EndTime` | `*time.Time` | 종료 시간 |
| `Limit` | `int` | 페이지 크기 |
| `Offset` | `int` | 페이지 오프셋 |

---

### 1.3 ExperimentRepository

실험 정보를 영속화하는 Repository입니다.

#### 인터페이스

**`Create(ctx context.Context, experiment *Experiment) error`**
- 실험 생성

**`FindByID(ctx context.Context, id string) (*Experiment, error)`**
- ID로 실험 조회

**`FindByRouteID(ctx context.Context, routeID string) ([]*Experiment, error)`**
- 라우트 ID로 실험 목록 조회

**`FindCurrentByRouteID(ctx context.Context, routeID string) (*Experiment, error)`**
- 라우트의 진행 중인 실험 조회 (Status = running or paused)

**`Update(ctx context.Context, experiment *Experiment) error`**
- 실험 수정

**`UpdateStatus(ctx context.Context, id string, status ExperimentStatus) error`**
- 실험 상태 변경

**`FindAll(ctx context.Context, filter ExperimentFilter) ([]*Experiment, error)`**
- 모든 실험 조회 (필터, 페이지네이션)

#### ExperimentFilter

| 필드 | 타입 | 설명 |
|------|------|------|
| `RouteID` | `*string` | 라우트 ID 필터 |
| `Status` | `*ExperimentStatus` | 상태 필터 |
| `StartTime` | `*time.Time` | 시작 시간 |
| `EndTime` | `*time.Time` | 종료 시간 |
| `Limit` | `int` | 페이지 크기 |
| `Offset` | `int` | 페이지 오프셋 |

---

### 1.4 ExperimentStageRepository

실험 단계별 이력을 영속화하는 Repository입니다.

#### 인터페이스

**`Create(ctx context.Context, stage *ExperimentStage) error`**
- 실험 단계 생성

**`FindByID(ctx context.Context, id string) (*ExperimentStage, error)`**
- ID로 단계 조회

**`FindByExperimentID(ctx context.Context, experimentID string) ([]*ExperimentStage, error)`**
- 실험 ID로 모든 단계 조회

**`FindCurrentStage(ctx context.Context, experimentID string) (*ExperimentStage, error)`**
- 실험의 현재 진행 중인 단계 조회 (CompletedAt = nil)

**`Update(ctx context.Context, stage *ExperimentStage) error`**
- 단계 수정

**`UpdateMetrics(ctx context.Context, id string, metrics StageMetrics) error`**
- 단계의 메트릭 갱신

#### StageMetrics

| 필드 | 타입 | 설명 |
|------|------|------|
| `TotalRequests` | `int64` | 총 요청 수 |
| `MatchRate` | `float64` | 일치율 (%) |
| `ErrorRate` | `float64` | 에러율 (%) |
| `LegacyAvgResponseTime` | `int64` | Legacy 평균 응답 시간 (ms) |
| `ModernAvgResponseTime` | `int64` | Modern 평균 응답 시간 (ms) |

---

## 2. Cache Port

### 2.1 CachePort

Redis 캐시를 추상화한 인터페이스입니다.

#### 기본 연산

**`Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error`**
- 캐시 저장

**`Get(ctx context.Context, key string) (interface{}, error)`**
- 캐시 조회

**`GetString(ctx context.Context, key string) (string, error)`**
- 문자열 캐시 조회

**`Delete(ctx context.Context, key string) error`**
- 캐시 삭제

**`Exists(ctx context.Context, key string) (bool, error)`**
- 캐시 존재 여부

#### 카운터 연산

**`Increment(ctx context.Context, key string) (int64, error)`**
- 카운터 증가

**`Decrement(ctx context.Context, key string) (int64, error)`**
- 카운터 감소

#### 분산 락

**`SetNX(ctx context.Context, key string, value interface{}, ttl time.Duration) (bool, error)`**
- 존재하지 않을 때만 저장 (분산 락 구현)

#### Hash 연산

**`HSet(ctx context.Context, key, field string, value interface{}) error`**
- Hash 저장

**`HGet(ctx context.Context, key, field string) (string, error)`**
- Hash 조회

**`HGetAll(ctx context.Context, key string) (map[string]string, error)`**
- Hash 전체 조회

**`Expire(ctx context.Context, key string, ttl time.Duration) error`**
- TTL 설정

### 2.2 캐시 키 규칙

| 키 패턴 | 설명 | 예시 |
|---------|------|------|
| `abs:route:{routeID}` | Route 캐시 | `abs:route:uuid-1234` |
| `abs:matchrate:{routeID}` | 일치율 캐시 | `abs:matchrate:uuid-1234` |
| `abs:experiment:{experimentID}` | 실험 캐시 | `abs:experiment:uuid-5678` |
| `abs:warning:{stageID}:{warningType}` | 경고 캐시 | `abs:warning:uuid-abcd:match_rate` |
| `abs:lock:{resourceID}` | 분산 락 | `abs:lock:experiment:uuid-1234` |

### 2.3 TTL 정책

| 캐시 타입 | TTL | 설명 |
|----------|-----|------|
| Route | 1시간 | 라우트 정보 |
| MatchRate | 5분 | 일치율 (실시간 갱신) |
| Experiment | 10분 | 실험 상태 |
| Warning | 10분 | 경고 발생 시간 추적 |
| Lock | 30초 | 분산 락 |

---

## 3. Message Publisher Port

### 3.1 MessagePublisherPort

RabbitMQ 메시지 발행을 추상화한 인터페이스입니다.

#### 인터페이스

**`Publish(ctx context.Context, exchange, routingKey string, message interface{}) error`**
- 메시지 발행

**`PublishWithRetry(ctx context.Context, exchange, routingKey string, message interface{}, maxRetries int) error`**
- 재시도를 포함한 메시지 발행

### 3.2 Exchange 및 Routing Key

| Exchange | Routing Key | 설명 |
|----------|-------------|------|
| `abs.comparison` | `comparison.completed` | 비교 완료 |
| `abs.comparison` | `comparison.failed` | 비교 실패 |
| `abs.experiment` | `experiment.started` | 실험 시작 |
| `abs.experiment` | `experiment.approved` | 단계 승인 |
| `abs.experiment` | `experiment.completed` | 실험 완료 |
| `abs.experiment` | `experiment.aborted` | 실험 중단 |
| `abs.experiment` | `experiment.rollback` | 롤백 발생 |
| `abs.notification` | `notification.alert` | 알림 |

### 3.3 Queue

| Queue 이름 | 설명 |
|-----------|------|
| `abs.comparison.processor` | 비교 결과 처리 |
| `abs.experiment.worker` | 실험 작업 처리 |
| `abs.notification.sender` | 알림 발송 |

### 3.4 메시지 포맷

#### ComparisonMessage

| 필드 | 타입 | 설명 |
|------|------|------|
| `comparison_id` | `string` | 비교 ID |
| `route_id` | `string` | 라우트 ID |
| `is_match` | `bool` | 일치 여부 |
| `timestamp` | `time.Time` | 타임스탬프 |

#### ExperimentMessage

| 필드 | 타입 | 설명 |
|------|------|------|
| `experiment_id` | `string` | 실험 ID |
| `route_id` | `string` | 라우트 ID |
| `event_type` | `string` | 이벤트 타입 |
| `payload` | `map[string]interface{}` | 페이로드 |
| `timestamp` | `time.Time` | 타임스탬프 |

#### NotificationMessage

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | `string` | 타입 (slack/email) |
| `severity` | `string` | 심각도 (info/warning/critical) |
| `subject` | `string` | 제목 |
| `message` | `string` | 메시지 본문 |
| `timestamp` | `time.Time` | 타임스탬프 |

---

## 4. API Client Port

### 4.1 APIClientPort

Legacy/Modern API 호출을 추상화한 인터페이스입니다.

#### 인터페이스

**`Call(ctx context.Context, req APICallRequest) (*APICallResponse, error)`**
- API 호출

**`CallWithRetry(ctx context.Context, req APICallRequest, maxRetries int) (*APICallResponse, error)`**
- 재시도를 포함한 API 호출

#### APICallRequest

| 필드 | 타입 | 설명 |
|------|------|------|
| `Host` | `string` | 호스트 |
| `Port` | `int` | 포트 |
| `Method` | `string` | HTTP 메서드 |
| `Path` | `string` | 경로 |
| `QueryParams` | `map[string]string` | 쿼리 파라미터 |
| `Headers` | `map[string]string` | 헤더 |
| `Body` | `[]byte` | 요청 본문 |
| `Timeout` | `time.Duration` | 타임아웃 |

#### APICallResponse

| 필드 | 타입 | 설명 |
|------|------|------|
| `StatusCode` | `int` | HTTP 상태 코드 |
| `Headers` | `map[string]string` | 응답 헤더 |
| `Body` | `[]byte` | 응답 본문 |
| `ResponseTime` | `int64` | 응답 시간 (ms) |
| `Error` | `string` | 에러 메시지 |

### 4.2 Timeout 정책

| API 타입 | Timeout |
|----------|---------|
| Legacy API | 30초 |
| Modern API | 30초 |

### 4.3 Retry 정책

| 항목 | 값 |
|------|-----|
| **최대 재시도 횟수** | 3회 |
| **Backoff 전략** | Exponential Backoff |
| **1차 재시도** | 1초 후 |
| **2차 재시도** | 2초 후 |
| **3차 재시도** | 4초 후 |

**재시도 대상**:
- 네트워크 오류
- 5xx 서버 에러
- 타임아웃

**재시도 제외**:
- 4xx 클라이언트 에러

---

## 5. Notification Port

### 5.1 NotificationPort

Slack/Email 알림을 추상화한 인터페이스입니다.

#### 인터페이스

**`SendSlack(ctx context.Context, notification SlackNotification) error`**
- Slack 알림 발송

**`SendEmail(ctx context.Context, notification EmailNotification) error`**
- Email 알림 발송

#### SlackNotification

| 필드 | 타입 | 설명 |
|------|------|------|
| `WebhookURL` | `string` | Webhook URL |
| `Channel` | `string` | 채널 |
| `Username` | `string` | 사용자명 |
| `IconEmoji` | `string` | 아이콘 이모지 |
| `Text` | `string` | 텍스트 |
| `Blocks` | `[]SlackBlock` | 블록 (포맷팅) |

#### EmailNotification

| 필드 | 타입 | 설명 |
|------|------|------|
| `From` | `string` | 발신자 |
| `To` | `[]string` | 수신자 목록 |
| `Cc` | `[]string` | 참조 목록 |
| `Subject` | `string` | 제목 |
| `Body` | `string` | 본문 |
| `IsHTML` | `bool` | HTML 여부 |

### 5.2 알림 템플릿

#### 진행 조건 충족 알림 (ProgressReadyNotification)

| 필드 | 설명 |
|------|------|
| `RouteID` | 라우트 ID |
| `RoutePath` | API 경로 (예: GET /api/v1/users) |
| `ExperimentID` | 실험 ID |
| `CurrentStage` | 현재 단계 |
| `CurrentPercentage` | 현재 트래픽 비율 |
| `NextPercentage` | 다음 트래픽 비율 |
| `MatchRate` | 일치율 |
| `ErrorRate` | 에러율 |
| `ApprovalLink` | 승인 링크 |

**메시지 구성**:
- 제목: "🚀 실험 진행 준비 완료"
- 내용: API 경로, 실험 ID, 현재/다음 단계, 메트릭 (일치율, 에러율, 요청 수)
- 액션: 승인 링크

#### 롤백 발생 알림 (RollbackNotification)

| 필드 | 설명 |
|------|------|
| `RouteID` | 라우트 ID |
| `RoutePath` | API 경로 |
| `ExperimentID` | 실험 ID |
| `Stage` | 단계 번호 |
| `Percentage` | 트래픽 비율 |
| `Severity` | 심각도 (critical/warning) |
| `Reason` | 롤백 사유 |
| `Metrics` | 메트릭 맵 |

**메시지 구성**:
- 제목: "🚨 긴급: 자동 롤백 발생" (Critical) 또는 "⚠️ 경고: 자동 롤백 발생" (Warning)
- 내용: API 경로, 실험 ID, 단계, 심각도, 롤백 사유, 메트릭
- 액션: 상세 보기 링크

---

## 6. UnitOfWork 패턴 (선택사항)

복잡한 트랜잭션 처리가 필요한 경우 UnitOfWork 패턴을 사용할 수 있습니다.

### 6.1 인터페이스

**`Begin(ctx context.Context) (context.Context, error)`**
- 트랜잭션 시작

**`Commit(ctx context.Context) error`**
- 트랜잭션 커밋

**`Rollback(ctx context.Context) error`**
- 트랜잭션 롤백

**Repository 접근자**:
- `RouteRepository() RouteRepository`
- `ComparisonRepository() ComparisonRepository`
- `ExperimentRepository() ExperimentRepository`
- `ExperimentStageRepository() ExperimentStageRepository`

### 6.2 사용 시나리오

- 실험 승인 시 Experiment, ExperimentStage, Route를 동시에 수정하는 경우
- 원자성이 보장되어야 하는 복잡한 비즈니스 로직

---

## 7. 에러 정의

### 7.1 Repository 에러

- `ErrRouteNotFound`: 라우트를 찾을 수 없음
- `ErrComparisonNotFound`: 비교 결과를 찾을 수 없음
- `ErrExperimentNotFound`: 실험을 찾을 수 없음
- `ErrExperimentStageNotFound`: 실험 단계를 찾을 수 없음
- `ErrDuplicateRoute`: 중복된 라우트
- `ErrDatabaseConnection`: 데이터베이스 연결 오류

### 7.2 Cache 에러

- `ErrCacheNotFound`: 캐시를 찾을 수 없음
- `ErrCacheConnection`: 캐시 연결 오류
- `ErrCacheSerialization`: 캐시 직렬화 오류

### 7.3 API Client 에러

- `ErrAPICallTimeout`: API 호출 타임아웃
- `ErrAPICallFailed`: API 호출 실패
- `ErrInvalidResponse`: 유효하지 않은 API 응답
- `ErrCircuitBreakerOpen`: Circuit Breaker가 Open 상태

---

## 8. 구현 가이드

### 8.1 Port 정의 위치

```
internal/domain/port/
```

### 8.2 Adapter 구현 위치

```
internal/adapter/out/
├── persistence/    # Repository 구현
├── cache/          # Cache 구현
├── messaging/      # Message Publisher 구현
├── httpclient/     # API Client 구현
└── notification/   # Notification 구현
```

### 8.3 의존성 방향

```
Domain Layer (Port 정의)
       ↑
       │ 의존
       │
Infrastructure Layer (Adapter 구현)
```

### 8.4 Mock 생성

테스트를 위해 gomock을 사용하여 Mock 생성:

```bash
mockgen -source=internal/domain/port/route_repository.go \
        -destination=internal/domain/port/mock/mock_route_repository.go \
        -package=mock
```

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
