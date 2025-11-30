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

```go
package port

import (
    "context"
    "demo-abs/internal/domain/model"
)

type RouteRepository interface {
    // Create: 라우트 생성
    Create(ctx context.Context, route *model.Route) error

    // FindByID: ID로 라우트 조회
    FindByID(ctx context.Context, id string) (*model.Route, error)

    // FindByPathAndMethod: 경로 및 메서드로 라우트 조회
    FindByPathAndMethod(ctx context.Context, path, method string) (*model.Route, error)

    // FindAll: 모든 라우트 조회
    FindAll(ctx context.Context, filter RouteFilter) ([]*model.Route, error)

    // Update: 라우트 수정
    Update(ctx context.Context, route *model.Route) error

    // Delete: 라우트 삭제
    Delete(ctx context.Context, id string) error

    // UpdateMatchRate: 일치율 갱신
    UpdateMatchRate(ctx context.Context, id string, matchRate float64, totalRequests, matchedRequests int64) error

    // UpdateOperationMode: 운영 모드 변경
    UpdateOperationMode(ctx context.Context, id string, mode model.OperationMode, canaryPercentage int) error
}

type RouteFilter struct {
    IsActive       *bool
    OperationMode  *model.OperationMode
    Limit          int
    Offset         int
}
```

---

### 1.2 ComparisonRepository

비교 결과를 영속화하는 Repository입니다.

```go
type ComparisonRepository interface {
    // Create: 비교 결과 생성
    Create(ctx context.Context, comparison *model.Comparison) error

    // FindByID: ID로 비교 결과 조회
    FindByID(ctx context.Context, id string) (*model.Comparison, error)

    // FindByRouteID: 라우트 ID로 비교 결과 목록 조회
    FindByRouteID(ctx context.Context, routeID string, filter ComparisonFilter) ([]*model.Comparison, error)

    // FindMismatches: 불일치 결과만 조회
    FindMismatches(ctx context.Context, routeID string, limit int) ([]*model.Comparison, error)

    // CountByRouteID: 라우트별 비교 결과 수 집계
    CountByRouteID(ctx context.Context, routeID string) (total, matched int64, err error)

    // DeleteOld: 오래된 비교 결과 삭제 (30일 이상)
    DeleteOld(ctx context.Context, retentionDays int) (int64, error)
}

type ComparisonFilter struct {
    IsMatch    *bool
    StartTime  *time.Time
    EndTime    *time.Time
    Limit      int
    Offset     int
}
```

---

### 1.3 ExperimentRepository

실험 정보를 영속화하는 Repository입니다.

```go
type ExperimentRepository interface {
    // Create: 실험 생성
    Create(ctx context.Context, experiment *model.Experiment) error

    // FindByID: ID로 실험 조회
    FindByID(ctx context.Context, id string) (*model.Experiment, error)

    // FindByRouteID: 라우트 ID로 실험 조회
    FindByRouteID(ctx context.Context, routeID string) ([]*model.Experiment, error)

    // FindCurrentByRouteID: 라우트의 진행 중인 실험 조회
    FindCurrentByRouteID(ctx context.Context, routeID string) (*model.Experiment, error)

    // Update: 실험 수정
    Update(ctx context.Context, experiment *model.Experiment) error

    // UpdateStatus: 실험 상태 변경
    UpdateStatus(ctx context.Context, id string, status model.ExperimentStatus) error

    // FindAll: 모든 실험 조회
    FindAll(ctx context.Context, filter ExperimentFilter) ([]*model.Experiment, error)
}

type ExperimentFilter struct {
    RouteID    *string
    Status     *model.ExperimentStatus
    StartTime  *time.Time
    EndTime    *time.Time
    Limit      int
    Offset     int
}
```

---

### 1.4 ExperimentStageRepository

실험 단계별 이력을 영속화하는 Repository입니다.

```go
type ExperimentStageRepository interface {
    // Create: 실험 단계 생성
    Create(ctx context.Context, stage *model.ExperimentStage) error

    // FindByID: ID로 단계 조회
    FindByID(ctx context.Context, id string) (*model.ExperimentStage, error)

    // FindByExperimentID: 실험 ID로 모든 단계 조회
    FindByExperimentID(ctx context.Context, experimentID string) ([]*model.ExperimentStage, error)

    // FindCurrentStage: 실험의 현재 진행 중인 단계 조회
    FindCurrentStage(ctx context.Context, experimentID string) (*model.ExperimentStage, error)

    // Update: 단계 수정
    Update(ctx context.Context, stage *model.ExperimentStage) error

    // UpdateMetrics: 단계의 메트릭 갱신
    UpdateMetrics(ctx context.Context, id string, metrics StageMetrics) error
}

type StageMetrics struct {
    TotalRequests          int64
    MatchRate              float64
    ErrorRate              float64
    LegacyAvgResponseTime  int64
    ModernAvgResponseTime  int64
}
```

---

## 2. Cache Port

### 2.1 CachePort

Redis 캐시를 추상화한 인터페이스입니다.

```go
type CachePort interface {
    // Set: 캐시 저장
    Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error

    // Get: 캐시 조회
    Get(ctx context.Context, key string) (interface{}, error)

    // GetString: 문자열 캐시 조회
    GetString(ctx context.Context, key string) (string, error)

    // Delete: 캐시 삭제
    Delete(ctx context.Context, key string) error

    // Exists: 캐시 존재 여부
    Exists(ctx context.Context, key string) (bool, error)

    // Increment: 카운터 증가
    Increment(ctx context.Context, key string) (int64, error)

    // Decrement: 카운터 감소
    Decrement(ctx context.Context, key string) (int64, error)

    // SetNX: 존재하지 않을 때만 저장 (분산 락)
    SetNX(ctx context.Context, key string, value interface{}, ttl time.Duration) (bool, error)

    // HSet: Hash 저장
    HSet(ctx context.Context, key, field string, value interface{}) error

    // HGet: Hash 조회
    HGet(ctx context.Context, key, field string) (string, error)

    // HGetAll: Hash 전체 조회
    HGetAll(ctx context.Context, key string) (map[string]string, error)

    // Expire: TTL 설정
    Expire(ctx context.Context, key string, ttl time.Duration) error
}
```

### 2.2 캐시 키 규칙

```go
const (
    // Route 캐시
    CacheKeyRoute = "abs:route:%s" // abs:route:{routeID}

    // 일치율 캐시
    CacheKeyMatchRate = "abs:matchrate:%s" // abs:matchrate:{routeID}

    // 실험 캐시
    CacheKeyExperiment = "abs:experiment:%s" // abs:experiment:{experimentID}

    // 경고 캐시 (롤백 경고)
    CacheKeyWarning = "abs:warning:%s:%s" // abs:warning:{stageID}:{warningType}

    // 분산 락
    CacheLockKey = "abs:lock:%s" // abs:lock:{resourceID}
)
```

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

```go
type MessagePublisherPort interface {
    // Publish: 메시지 발행
    Publish(ctx context.Context, exchange, routingKey string, message interface{}) error

    // PublishWithRetry: 재시도를 포함한 메시지 발행
    PublishWithRetry(ctx context.Context, exchange, routingKey string, message interface{}, maxRetries int) error
}
```

### 3.2 Exchange 및 Queue 정의

```go
const (
    // Exchange
    ExchangeComparison   = "abs.comparison"   // 비교 결과
    ExchangeExperiment   = "abs.experiment"   // 실험 이벤트
    ExchangeNotification = "abs.notification" // 알림

    // Routing Key
    RoutingKeyComparisonCompleted = "comparison.completed"
    RoutingKeyComparisonFailed    = "comparison.failed"
    RoutingKeyExperimentStarted   = "experiment.started"
    RoutingKeyExperimentApproved  = "experiment.approved"
    RoutingKeyExperimentCompleted = "experiment.completed"
    RoutingKeyExperimentAborted   = "experiment.aborted"
    RoutingKeyRollbackTriggered   = "experiment.rollback"
    RoutingKeyNotificationAlert   = "notification.alert"

    // Queue
    QueueComparisonProcessor = "abs.comparison.processor"
    QueueExperimentWorker    = "abs.experiment.worker"
    QueueNotificationSender  = "abs.notification.sender"
)
```

### 3.3 메시지 포맷

```go
type ComparisonMessage struct {
    ComparisonID string                `json:"comparison_id"`
    RouteID      string                `json:"route_id"`
    IsMatch      bool                  `json:"is_match"`
    Timestamp    time.Time             `json:"timestamp"`
}

type ExperimentMessage struct {
    ExperimentID string                `json:"experiment_id"`
    RouteID      string                `json:"route_id"`
    EventType    string                `json:"event_type"`
    Payload      map[string]interface{} `json:"payload"`
    Timestamp    time.Time             `json:"timestamp"`
}

type NotificationMessage struct {
    Type      string                `json:"type"` // "slack" | "email"
    Severity  string                `json:"severity"` // "info" | "warning" | "critical"
    Subject   string                `json:"subject"`
    Message   string                `json:"message"`
    Timestamp time.Time             `json:"timestamp"`
}
```

---

## 4. API Client Port

### 4.1 APIClientPort

Legacy/Modern API 호출을 추상화한 인터페이스입니다.

```go
type APIClientPort interface {
    // Call: API 호출
    Call(ctx context.Context, req APICallRequest) (*APICallResponse, error)

    // CallWithRetry: 재시도를 포함한 API 호출
    CallWithRetry(ctx context.Context, req APICallRequest, maxRetries int) (*APICallResponse, error)
}

type APICallRequest struct {
    Host        string
    Port        int
    Method      string
    Path        string
    QueryParams map[string]string
    Headers     map[string]string
    Body        []byte
    Timeout     time.Duration
}

type APICallResponse struct {
    StatusCode   int
    Headers      map[string]string
    Body         []byte
    ResponseTime int64 // ms
    Error        string
}
```

### 4.2 Timeout 정책

| API 타입 | Timeout | 설명 |
|----------|---------|------|
| Legacy API | 30초 | Legacy API 호출 |
| Modern API | 30초 | Modern API 호출 |

### 4.3 Retry 정책

- **최대 재시도 횟수**: 3회
- **Backoff 전략**: Exponential Backoff
  - 1차 재시도: 1초 후
  - 2차 재시도: 2초 후
  - 3차 재시도: 4초 후
- **재시도 대상**:
  - 네트워크 오류
  - 5xx 서버 에러
  - 타임아웃
- **재시도 제외**:
  - 4xx 클라이언트 에러

---

## 5. Notification Port

### 5.1 NotificationPort

Slack/Email 알림을 추상화한 인터페이스입니다.

```go
type NotificationPort interface {
    // SendSlack: Slack 알림 발송
    SendSlack(ctx context.Context, notification SlackNotification) error

    // SendEmail: Email 알림 발송
    SendEmail(ctx context.Context, notification EmailNotification) error
}

type SlackNotification struct {
    WebhookURL string
    Channel    string
    Username   string
    IconEmoji  string
    Text       string
    Blocks     []SlackBlock
}

type SlackBlock struct {
    Type string                 `json:"type"`
    Text map[string]string      `json:"text,omitempty"`
    Fields []map[string]string  `json:"fields,omitempty"`
}

type EmailNotification struct {
    From    string
    To      []string
    Cc      []string
    Subject string
    Body    string
    IsHTML  bool
}
```

### 5.2 알림 템플릿

#### 5.2.1 진행 조건 충족 알림

```go
type ProgressReadyNotification struct {
    RouteID          string
    RoutePath        string
    ExperimentID     string
    CurrentStage     int
    CurrentPercentage int
    NextPercentage   int
    MatchRate        float64
    ErrorRate        float64
    ApprovalLink     string
}
```

**Slack 메시지 예시**:
```
🚀 실험 진행 준비 완료

API: GET /api/v1/users
실험 ID: exp-12345
현재 단계: 1단계 (1%)
다음 단계: 5%

📊 메트릭
- 일치율: 100.0%
- 에러율: 0.0%
- 요청 수: 150

✅ 승인하기: https://abs-dashboard/experiments/exp-12345/approve
```

#### 5.2.2 롤백 발생 알림

```go
type RollbackNotification struct {
    RouteID      string
    RoutePath    string
    ExperimentID string
    Stage        int
    Percentage   int
    Severity     string // "critical" | "warning"
    Reason       string
    Metrics      map[string]interface{}
}
```

**Slack 메시지 예시**:
```
🚨 긴급: 자동 롤백 발생

API: GET /api/v1/users
실험 ID: exp-12345
단계: 2단계 (5%)
심각도: Critical

⚠️ 롤백 사유
Modern API 에러율 1.5% (임계값: 1.0%)

📊 메트릭
- 일치율: 99.8%
- 에러율: 1.5%
- 응답 시간: Legacy 120ms / Modern 250ms

🔍 상세 보기: https://abs-dashboard/experiments/exp-12345
```

---

## 6. Port 구현 가이드

### 6.1 Repository 구현 위치

```
internal/adapter/out/persistence/
├── oracle_route_repository.go
├── oracle_comparison_repository.go
├── oracle_experiment_repository.go
└── oracle_experiment_stage_repository.go
```

### 6.2 Cache 구현 위치

```
internal/adapter/out/cache/
└── redis_cache_adapter.go
```

### 6.3 Message Publisher 구현 위치

```
internal/adapter/out/messaging/
└── rabbitmq_publisher_adapter.go
```

### 6.4 API Client 구현 위치

```
internal/adapter/out/httpclient/
├── api_client_adapter.go
└── circuit_breaker.go
```

### 6.5 Notification 구현 위치

```
internal/adapter/out/notification/
├── slack_notifier.go
└── email_notifier.go
```

---

## 7. 에러 처리

### 7.1 Repository 에러

```go
var (
    ErrRouteNotFound           = errors.New("route not found")
    ErrComparisonNotFound      = errors.New("comparison not found")
    ErrExperimentNotFound      = errors.New("experiment not found")
    ErrExperimentStageNotFound = errors.New("experiment stage not found")
    ErrDuplicateRoute          = errors.New("duplicate route")
    ErrDatabaseConnection      = errors.New("database connection error")
)
```

### 7.2 Cache 에러

```go
var (
    ErrCacheNotFound      = errors.New("cache not found")
    ErrCacheConnection    = errors.New("cache connection error")
    ErrCacheSerialization = errors.New("cache serialization error")
)
```

### 7.3 API Client 에러

```go
var (
    ErrAPICallTimeout     = errors.New("API call timeout")
    ErrAPICallFailed      = errors.New("API call failed")
    ErrInvalidResponse    = errors.New("invalid API response")
    ErrCircuitBreakerOpen = errors.New("circuit breaker is open")
)
```

---

## 8. 트랜잭션 처리

### 8.1 UnitOfWork 패턴 (선택사항)

복잡한 트랜잭션 처리가 필요한 경우 UnitOfWork 패턴을 사용할 수 있습니다.

```go
type UnitOfWork interface {
    // Begin: 트랜잭션 시작
    Begin(ctx context.Context) (context.Context, error)

    // Commit: 트랜잭션 커밋
    Commit(ctx context.Context) error

    // Rollback: 트랜잭션 롤백
    Rollback(ctx context.Context) error

    // RouteRepository: 트랜잭션 내 Repository 반환
    RouteRepository() RouteRepository
    ComparisonRepository() ComparisonRepository
    ExperimentRepository() ExperimentRepository
    ExperimentStageRepository() ExperimentStageRepository
}
```

### 8.2 사용 예시

```go
func (u *ApproveExperimentUseCase) Execute(ctx context.Context, req ApproveRequest) error {
    txCtx, err := u.uow.Begin(ctx)
    if err != nil {
        return err
    }

    defer func() {
        if err != nil {
            u.uow.Rollback(txCtx)
        }
    }()

    // 1. 실험 조회
    experiment, err := u.uow.ExperimentRepository().FindByID(txCtx, req.ExperimentID)
    if err != nil {
        return err
    }

    // 2. 실험 승인
    if err := experiment.Approve(req.ApprovedBy, nextPercentage); err != nil {
        return err
    }

    // 3. 실험 수정
    if err := u.uow.ExperimentRepository().Update(txCtx, experiment); err != nil {
        return err
    }

    // 4. 현재 단계 완료
    currentStage.Complete(req.ApprovedBy)
    if err := u.uow.ExperimentStageRepository().Update(txCtx, currentStage); err != nil {
        return err
    }

    // 5. 새로운 단계 생성
    if err := u.uow.ExperimentStageRepository().Create(txCtx, newStage); err != nil {
        return err
    }

    // 커밋
    return u.uow.Commit(txCtx)
}
```

---

## 9. 참고 사항

### 9.1 인터페이스 위치

- **정의**: `internal/domain/port/` (도메인 계층)
- **구현**: `internal/adapter/out/` (인프라 계층)

### 9.2 의존성 방향

```
Domain Layer (Port 정의)
       ↑
       │ 의존
       │
Infrastructure Layer (Port 구현)
```

### 9.3 Mock 생성

테스트를 위해 gomock을 사용하여 Mock 생성:

```bash
mockgen -source=internal/domain/port/route_repository.go \
        -destination=internal/domain/port/mock/mock_route_repository.go \
        -package=mock
```

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
