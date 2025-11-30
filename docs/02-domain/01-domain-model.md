# 도메인 모델 설계

## 문서 목적

본 문서는 ABS의 핵심 비즈니스 개념을 표현하는 도메인 모델을 정의합니다.

**포함 내용**:
- Entity 정의 (Route, Comparison, Experiment, ExperimentStage)
- Value Object 정의 (APIRequest, APIResponse, MatchRate 등)
- 도메인 규칙 및 불변식(Invariant)

---

## 1. Entity

### 1.1 Route Entity

API 라우트 정보를 관리하는 핵심 엔티티입니다.

#### 필드 정의

| 필드명 | 타입 | 설명 | 필수 | 기본값 |
|--------|------|------|------|--------|
| `ID` | `string` | 라우트 고유 식별자 (UUID) | ✓ | - |
| `Path` | `string` | API 경로 (예: `/api/v1/users`) | ✓ | - |
| `Method` | `string` | HTTP 메서드 (GET, POST, PUT, DELETE 등) | ✓ | - |
| `SampleSize` | `int` | 일치율 계산 표본 수 | ✓ | 100 |
| `ExcludeFields` | `[]string` | 비교 제외 필드 목록 | | `[]` |
| `LegacyHost` | `string` | Legacy API 호스트 | ✓ | - |
| `LegacyPort` | `int` | Legacy API 포트 | ✓ | 8080 |
| `ModernHost` | `string` | Modern API 호스트 | ✓ | - |
| `ModernPort` | `int` | Modern API 포트 | ✓ | 9080 |
| `OperationMode` | `OperationMode` | 운영 모드 (validation/canary/switched) | ✓ | validation |
| `CanaryPercentage` | `int` | Canary 모드 시 트래픽 비율 (0-100) | | 0 |
| `MatchRate` | `float64` | 현재 일치율 (0.0-100.0) | | 0.0 |
| `TotalRequests` | `int64` | 총 요청 수 | | 0 |
| `MatchedRequests` | `int64` | 일치한 요청 수 | | 0 |
| `ErrorRate` | `float64` | Modern API 에러율 (0.0-100.0) | | 0.0 |
| `IsActive` | `bool` | 라우트 활성화 여부 | ✓ | true |
| `CreatedAt` | `time.Time` | 생성 시간 | ✓ | now() |
| `UpdatedAt` | `time.Time` | 수정 시간 | ✓ | now() |

#### 불변식 (Invariants)

```go
// 1. Path는 반드시 '/'로 시작해야 함
func (r *Route) Validate() error {
    if !strings.HasPrefix(r.Path, "/") {
        return ErrInvalidPath
    }

    // 2. SampleSize는 10 이상 1000 이하
    if r.SampleSize < 10 || r.SampleSize > 1000 {
        return ErrInvalidSampleSize
    }

    // 3. CanaryPercentage는 0 이상 100 이하
    if r.CanaryPercentage < 0 || r.CanaryPercentage > 100 {
        return ErrInvalidCanaryPercentage
    }

    // 4. Canary 모드일 때만 CanaryPercentage > 0
    if r.OperationMode != OperationModeCanary && r.CanaryPercentage > 0 {
        return ErrInvalidOperationMode
    }

    return nil
}
```

#### 도메인 메서드

```go
// UpdateMatchRate: 일치율 갱신
func (r *Route) UpdateMatchRate(isMatch bool) {
    r.TotalRequests++
    if isMatch {
        r.MatchedRequests++
    }

    if r.TotalRequests > 0 {
        r.MatchRate = (float64(r.MatchedRequests) / float64(r.TotalRequests)) * 100.0
    }

    r.UpdatedAt = time.Now()
}

// CanSwitchToModern: Modern API로 전환 가능 여부
func (r *Route) CanSwitchToModern() bool {
    return r.MatchRate == 100.0 &&
           r.TotalRequests >= int64(r.SampleSize) &&
           r.ErrorRate < 0.1
}

// ShouldRollback: 롤백 필요 여부
func (r *Route) ShouldRollback() bool {
    return r.MatchRate < 99.9 || r.ErrorRate > 1.0
}
```

---

### 1.2 Comparison Entity

Legacy API와 Modern API의 응답 비교 결과를 저장하는 엔티티입니다.

#### 필드 정의

| 필드명 | 타입 | 설명 | 필수 |
|--------|------|------|------|
| `ID` | `string` | 비교 결과 고유 식별자 (UUID) | ✓ |
| `RouteID` | `string` | 라우트 ID (FK) | ✓ |
| `RequestID` | `string` | 요청 추적 ID | ✓ |
| `LegacyRequest` | `APIRequest` | Legacy API 요청 | ✓ |
| `LegacyResponse` | `APIResponse` | Legacy API 응답 | ✓ |
| `ModernRequest` | `APIRequest` | Modern API 요청 | ✓ |
| `ModernResponse` | `APIResponse` | Modern API 응답 | |
| `IsMatch` | `bool` | 응답 일치 여부 | ✓ |
| `TotalFields` | `int` | 총 필드 수 | | 0 |
| `MatchedFields` | `int` | 일치한 필드 수 | | 0 |
| `FieldMatchRate` | `float64` | 필드 일치율 (0.0-100.0) | | 0.0 |
| `MismatchDetails` | `[]MismatchDetail` | 불일치 상세 정보 | | `[]` |
| `ComparisonDuration` | `time.Duration` | 비교 소요 시간 (ms) | | 0 |
| `CreatedAt` | `time.Time` | 생성 시간 | ✓ |

#### MismatchDetail 구조체

```go
type MismatchDetail struct {
    FieldPath     string      // 필드 경로 (예: "user.address.city")
    LegacyValue   interface{} // Legacy 값
    ModernValue   interface{} // Modern 값
    ExpectedType  string      // 기대 타입
    ActualType    string      // 실제 타입
}
```

#### 도메인 메서드

```go
// CalculateFieldMatchRate: 필드 일치율 계산
func (c *Comparison) CalculateFieldMatchRate() {
    if c.TotalFields > 0 {
        c.FieldMatchRate = (float64(c.MatchedFields) / float64(c.TotalFields)) * 100.0
    }
}

// IsTimeout: 비교 타임아웃 여부
func (c *Comparison) IsTimeout() bool {
    return c.ComparisonDuration > 10*time.Second
}
```

---

### 1.3 Experiment Entity

반자동 전환 실험을 관리하는 엔티티입니다.

#### 필드 정의

| 필드명 | 타입 | 설명 | 필수 | 기본값 |
|--------|------|------|------|--------|
| `ID` | `string` | 실험 고유 식별자 (UUID) | ✓ | - |
| `RouteID` | `string` | 라우트 ID (FK) | ✓ | - |
| `InitialPercentage` | `int` | 시작 트래픽 비율 (%) | ✓ | 1 |
| `CurrentPercentage` | `int` | 현재 트래픽 비율 (%) | ✓ | 1 |
| `TargetPercentage` | `int` | 목표 트래픽 비율 (%) | ✓ | 100 |
| `StabilizationPeriod` | `int` | 안정화 기간 (초) | ✓ | 3600 |
| `Status` | `ExperimentStatus` | 실험 상태 | ✓ | pending |
| `CurrentStage` | `int` | 현재 단계 (1-6) | | 1 |
| `TotalStages` | `int` | 전체 단계 수 | | 6 |
| `LastApprovedBy` | `string` | 마지막 승인자 | | - |
| `LastApprovedAt` | `*time.Time` | 마지막 승인 시간 | | nil |
| `StartedAt` | `*time.Time` | 실험 시작 시간 | | nil |
| `CompletedAt` | `*time.Time` | 실험 완료 시간 | | nil |
| `AbortedReason` | `string` | 중단 사유 | | - |
| `CreatedAt` | `time.Time` | 생성 시간 | ✓ | now() |
| `UpdatedAt` | `time.Time` | 수정 시간 | ✓ | now() |

#### 불변식 (Invariants)

```go
func (e *Experiment) Validate() error {
    // 1. 트래픽 비율은 0-100 범위
    if e.InitialPercentage < 0 || e.InitialPercentage > 100 {
        return ErrInvalidPercentage
    }

    // 2. CurrentPercentage는 InitialPercentage 이상
    if e.CurrentPercentage < e.InitialPercentage {
        return ErrInvalidCurrentPercentage
    }

    // 3. 안정화 기간은 최소 1시간
    if e.StabilizationPeriod < 3600 {
        return ErrInvalidStabilizationPeriod
    }

    // 4. 완료 상태일 때 CurrentPercentage는 100
    if e.Status == ExperimentStatusCompleted && e.CurrentPercentage != 100 {
        return ErrIncompleteExperiment
    }

    return nil
}
```

#### 도메인 메서드

```go
// Start: 실험 시작
func (e *Experiment) Start() error {
    if e.Status != ExperimentStatusPending {
        return ErrInvalidExperimentStatus
    }

    e.Status = ExperimentStatusRunning
    e.CurrentPercentage = e.InitialPercentage
    now := time.Now()
    e.StartedAt = &now
    e.UpdatedAt = now

    return nil
}

// Pause: 실험 일시 정지
func (e *Experiment) Pause() error {
    if e.Status != ExperimentStatusRunning {
        return ErrCannotPauseExperiment
    }

    e.Status = ExperimentStatusPaused
    e.UpdatedAt = time.Now()

    return nil
}

// Resume: 실험 재개
func (e *Experiment) Resume() error {
    if e.Status != ExperimentStatusPaused {
        return ErrCannotResumeExperiment
    }

    e.Status = ExperimentStatusRunning
    e.UpdatedAt = time.Now()

    return nil
}

// Approve: 다음 단계 승인
func (e *Experiment) Approve(approvedBy string, nextPercentage int) error {
    if e.Status != ExperimentStatusRunning {
        return ErrCannotApproveExperiment
    }

    if nextPercentage <= e.CurrentPercentage || nextPercentage > 100 {
        return ErrInvalidNextPercentage
    }

    e.CurrentPercentage = nextPercentage
    e.CurrentStage++
    e.LastApprovedBy = approvedBy
    now := time.Now()
    e.LastApprovedAt = &now
    e.UpdatedAt = now

    // 100% 도달 시 완료
    if e.CurrentPercentage == 100 {
        e.Status = ExperimentStatusCompleted
        e.CompletedAt = &now
    }

    return nil
}

// Abort: 실험 중단
func (e *Experiment) Abort(reason string) error {
    if e.Status == ExperimentStatusCompleted || e.Status == ExperimentStatusAborted {
        return ErrCannotAbortExperiment
    }

    e.Status = ExperimentStatusAborted
    e.AbortedReason = reason
    now := time.Now()
    e.CompletedAt = &now
    e.UpdatedAt = now

    return nil
}

// IsStabilizationPeriodElapsed: 안정화 기간 경과 여부
func (e *Experiment) IsStabilizationPeriodElapsed() bool {
    if e.LastApprovedAt == nil {
        return time.Since(*e.StartedAt) >= time.Duration(e.StabilizationPeriod)*time.Second
    }
    return time.Since(*e.LastApprovedAt) >= time.Duration(e.StabilizationPeriod)*time.Second
}
```

---

### 1.4 ExperimentStage Entity

실험 단계별 이력 및 메트릭을 기록하는 엔티티입니다.

#### 필드 정의

| 필드명 | 타입 | 설명 | 필수 |
|--------|------|------|------|
| `ID` | `string` | 단계 고유 식별자 (UUID) | ✓ |
| `ExperimentID` | `string` | 실험 ID (FK) | ✓ |
| `Stage` | `int` | 단계 번호 (1-6) | ✓ |
| `TrafficPercentage` | `int` | 트래픽 비율 (%) | ✓ |
| `MinRequests` | `int` | 최소 요청 수 | ✓ |
| `TotalRequests` | `int64` | 처리된 총 요청 수 | 0 |
| `MatchRate` | `float64` | 일치율 (%) | 0.0 |
| `ErrorRate` | `float64` | 에러율 (%) | 0.0 |
| `LegacyAvgResponseTime` | `int64` | Legacy 평균 응답 시간 (ms) | 0 |
| `ModernAvgResponseTime` | `int64` | Modern 평균 응답 시간 (ms) | 0 |
| `ApprovedBy` | `string` | 승인자 | - |
| `ApprovedAt` | `*time.Time` | 승인 시간 | nil |
| `StartedAt` | `time.Time` | 단계 시작 시간 | ✓ |
| `CompletedAt` | `*time.Time` | 단계 완료 시간 | nil |
| `RollbackReason` | `string` | 롤백 사유 | - |
| `IsRollback` | `bool` | 롤백 여부 | false |

#### 도메인 메서드

```go
// CanProceedToNextStage: 다음 단계 진행 가능 여부
func (s *ExperimentStage) CanProceedToNextStage(stabilizationPeriod int) bool {
    // 1. 안정화 기간 경과
    elapsed := time.Since(s.StartedAt) >= time.Duration(stabilizationPeriod)*time.Second

    // 2. 최소 요청 수 충족
    minRequestsMet := s.TotalRequests >= int64(s.MinRequests)

    // 3. 일치율 99.9% 이상
    matchRateOK := s.MatchRate >= 99.9

    // 4. 에러율 0.1% 미만
    errorRateOK := s.ErrorRate < 0.1

    // 5. 응답 시간 Legacy × 1.2 이하
    responseTimeOK := s.ModernAvgResponseTime <= s.LegacyAvgResponseTime*12/10

    return elapsed && minRequestsMet && matchRateOK && errorRateOK && responseTimeOK
}

// ShouldRollback: 롤백 필요 여부 (즉시 롤백)
func (s *ExperimentStage) ShouldRollback() (bool, string) {
    // 에러율 > 1%
    if s.ErrorRate > 1.0 {
        return true, "Modern API 에러율 1% 초과"
    }

    // 응답 시간 > Legacy × 2.0
    if s.ModernAvgResponseTime > s.LegacyAvgResponseTime*2 {
        return true, "Modern API 응답 시간이 Legacy의 2배 초과"
    }

    return false, ""
}

// ShouldWarnRollback: 경고 후 롤백 (조건 지속 시)
func (s *ExperimentStage) ShouldWarnRollback() (bool, string) {
    // 일치율 < 99.5%
    if s.MatchRate < 99.5 {
        return true, "일치율 99.5% 미만"
    }

    // 에러율 > 0.5%
    if s.ErrorRate > 0.5 {
        return true, "에러율 0.5% 초과"
    }

    // 응답 시간 > Legacy × 1.5
    if s.ModernAvgResponseTime > s.LegacyAvgResponseTime*15/10 {
        return true, "응답 시간이 Legacy의 1.5배 초과"
    }

    return false, ""
}

// Complete: 단계 완료
func (s *ExperimentStage) Complete(approvedBy string) {
    s.ApprovedBy = approvedBy
    now := time.Now()
    s.ApprovedAt = &now
    s.CompletedAt = &now
}

// Rollback: 롤백 기록
func (s *ExperimentStage) Rollback(reason string) {
    s.IsRollback = true
    s.RollbackReason = reason
    now := time.Now()
    s.CompletedAt = &now
}
```

---

## 2. Value Object

### 2.1 APIRequest

API 요청 정보를 나타내는 Value Object입니다.

```go
type APIRequest struct {
    Method      string            // HTTP 메서드
    Path        string            // 요청 경로
    QueryParams map[string]string // 쿼리 파라미터
    Headers     map[string]string // 헤더
    Body        []byte            // 요청 본문 (JSON)
    Timestamp   time.Time         // 요청 시간
}

// Equals: 동등성 비교
func (r APIRequest) Equals(other APIRequest) bool {
    return r.Method == other.Method &&
           r.Path == other.Path &&
           mapsEqual(r.QueryParams, other.QueryParams) &&
           bytes.Equal(r.Body, other.Body)
}
```

---

### 2.2 APIResponse

API 응답 정보를 나타내는 Value Object입니다.

```go
type APIResponse struct {
    StatusCode   int               // HTTP 상태 코드
    Headers      map[string]string // 응답 헤더
    Body         []byte            // 응답 본문 (JSON)
    ResponseTime int64             // 응답 시간 (ms)
    Error        string            // 에러 메시지 (실패 시)
    Timestamp    time.Time         // 응답 시간
}

// IsSuccess: 성공 응답 여부
func (r APIResponse) IsSuccess() bool {
    return r.StatusCode >= 200 && r.StatusCode < 300 && r.Error == ""
}

// IsTimeout: 타임아웃 여부
func (r APIResponse) IsTimeout() bool {
    return r.ResponseTime >= 30000 // 30초
}
```

---

### 2.3 MatchRate

일치율을 나타내는 Value Object입니다.

```go
type MatchRate struct {
    Value      float64 // 일치율 (0.0-100.0)
    SampleSize int     // 표본 크기
    UpdatedAt  time.Time
}

// IsPerfect: 완벽한 일치율 (100%)
func (m MatchRate) IsPerfect() bool {
    return m.Value == 100.0
}

// IsAcceptable: 허용 가능한 일치율 (≥ 99.9%)
func (m MatchRate) IsAcceptable() bool {
    return m.Value >= 99.9
}

// HasEnoughSamples: 충분한 표본 수 확보 여부
func (m MatchRate) HasEnoughSamples() bool {
    return m.SampleSize >= 10
}
```

---

### 2.4 TrafficPercentage

트래픽 비율을 나타내는 Value Object입니다.

```go
type TrafficPercentage struct {
    Value int // 0-100
}

// NewTrafficPercentage: TrafficPercentage 생성
func NewTrafficPercentage(value int) (TrafficPercentage, error) {
    if value < 0 || value > 100 {
        return TrafficPercentage{}, ErrInvalidPercentage
    }
    return TrafficPercentage{Value: value}, nil
}

// IsZero: 0%
func (t TrafficPercentage) IsZero() bool {
    return t.Value == 0
}

// IsFull: 100%
func (t TrafficPercentage) IsFull() bool {
    return t.Value == 100
}

// NextStage: 다음 단계 비율 반환
func (t TrafficPercentage) NextStage() (TrafficPercentage, error) {
    stages := []int{1, 5, 10, 25, 50, 100}

    for _, stage := range stages {
        if t.Value < stage {
            return NewTrafficPercentage(stage)
        }
    }

    return TrafficPercentage{}, ErrAlreadyFullTraffic
}
```

---

### 2.5 OperationMode (Enum)

운영 모드를 나타내는 열거형입니다.

```go
type OperationMode string

const (
    OperationModeValidation OperationMode = "validation" // 검증 모드 (Legacy 응답 반환)
    OperationModeCanary     OperationMode = "canary"     // Canary 모드 (N% Modern 반환)
    OperationModeSwitched   OperationMode = "switched"   // 전환 모드 (100% Modern 반환)
)

// String: 문자열 변환
func (m OperationMode) String() string {
    return string(m)
}

// IsValid: 유효한 모드 여부
func (m OperationMode) IsValid() bool {
    switch m {
    case OperationModeValidation, OperationModeCanary, OperationModeSwitched:
        return true
    }
    return false
}
```

---

### 2.6 ExperimentStatus (Enum)

실험 상태를 나타내는 열거형입니다.

```go
type ExperimentStatus string

const (
    ExperimentStatusPending   ExperimentStatus = "pending"   // 대기 중
    ExperimentStatusRunning   ExperimentStatus = "running"   // 진행 중
    ExperimentStatusPaused    ExperimentStatus = "paused"    // 일시 정지
    ExperimentStatusCompleted ExperimentStatus = "completed" // 완료
    ExperimentStatusAborted   ExperimentStatus = "aborted"   // 중단
)

// CanTransitionTo: 상태 전이 가능 여부
func (s ExperimentStatus) CanTransitionTo(next ExperimentStatus) bool {
    transitions := map[ExperimentStatus][]ExperimentStatus{
        ExperimentStatusPending:   {ExperimentStatusRunning},
        ExperimentStatusRunning:   {ExperimentStatusPaused, ExperimentStatusCompleted, ExperimentStatusAborted},
        ExperimentStatusPaused:    {ExperimentStatusRunning, ExperimentStatusAborted},
        ExperimentStatusCompleted: {},
        ExperimentStatusAborted:   {},
    }

    allowed := transitions[s]
    for _, a := range allowed {
        if a == next {
            return true
        }
    }
    return false
}
```

---

## 3. 도메인 규칙 요약

### Route 도메인 규칙

1. **일치율 계산**: 요청 처리 시마다 실시간 갱신
2. **전환 조건**: 일치율 100% + 표본 수 충족 + 에러율 < 0.1%
3. **롤백 조건**: 일치율 < 99.9% 또는 에러율 > 1%

### Experiment 도메인 규칙

1. **상태 전이**:
   - pending → running → completed
   - running → paused → running
   - running/paused → aborted
2. **단계별 진행**: 1% → 5% → 10% → 25% → 50% → 100%
3. **승인 필수**: 각 단계 진행 시 관리자 승인 필요

### ExperimentStage 도메인 규칙

1. **진행 조건**:
   - 안정화 기간 경과
   - 최소 요청 수 충족
   - 일치율 ≥ 99.9%
   - 에러율 < 0.1%
   - 응답 시간 ≤ Legacy × 1.2
2. **즉시 롤백**:
   - 에러율 > 1%
   - 응답 시간 > Legacy × 2.0
3. **경고 후 롤백** (5분 지속 시):
   - 일치율 < 99.5%
   - 에러율 > 0.5%
   - 응답 시간 > Legacy × 1.5

---

## 4. Entity 관계 다이어그램

```
┌──────────────┐
│    Route     │
│              │
│ - ID         │
│ - Path       │◄───────┐
│ - Method     │        │
│ - MatchRate  │        │
└──────────────┘        │
       ▲                │
       │                │
       │                │
       │ RouteID        │ RouteID
       │                │
       │                │
┌──────────────┐   ┌────────────────┐
│  Comparison  │   │  Experiment    │
│              │   │                │
│ - RouteID    │   │ - RouteID      │
│ - IsMatch    │   │ - Status       │◄───────┐
│ - Legacy...  │   │ - Current%     │        │
│ - Modern...  │   │                │        │
└──────────────┘   └────────────────┘        │
                          ▲                  │
                          │                  │
                          │ ExperimentID     │ ExperimentID
                          │                  │
                   ┌──────────────────┐      │
                   │ ExperimentStage  │      │
                   │                  │──────┘
                   │ - Stage          │
                   │ - Traffic%       │
                   │ - MatchRate      │
                   │ - ErrorRate      │
                   └──────────────────┘
```

---

## 5. 참고 사항

### 5.1 UUID 생성

모든 Entity의 ID는 UUID v4를 사용합니다.

```go
import "github.com/google/uuid"

id := uuid.New().String()
```

### 5.2 타임스탬프

- `CreatedAt`, `UpdatedAt`: UTC 시간 사용
- DB 저장 시 `time.Time` → `timestamp with time zone`

### 5.3 JSON 직렬화

- APIRequest.Body, APIResponse.Body는 `[]byte`로 저장
- DB 저장 시 CLOB 또는 TEXT 타입 사용

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
