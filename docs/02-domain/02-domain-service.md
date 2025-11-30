# 도메인 서비스 설계

## 문서 목적

본 문서는 ABS의 핵심 비즈니스 로직을 수행하는 도메인 서비스를 정의합니다.

**포함 내용**:
- ComparisonService: JSON 응답 비교 로직
- MatchRateCalculator: 일치율 계산 로직
- RoutingService: 라우팅 및 응답 선택 로직
- ExperimentService: 반자동 전환 실험 관리 로직

---

## 1. ComparisonService

Legacy API와 Modern API의 JSON 응답을 비교하는 도메인 서비스입니다.

### 1.1 책임

- JSON 응답 파싱
- 필드별 값 비교
- 타입 검증 (숫자 vs 문자열, null vs 빈 문자열)
- 비교 제외 필드 처리
- 불일치 상세 정보 생성

### 1.2 인터페이스

```go
type ComparisonService interface {
    // Compare: 두 JSON 응답 비교
    Compare(ctx context.Context, req CompareRequest) (*CompareResult, error)

    // CompareFields: 필드별 비교 (재귀)
    CompareFields(legacy, modern map[string]interface{}, excludeFields []string, prefix string) ([]MismatchDetail, int, int)
}

type CompareRequest struct {
    LegacyResponse  APIResponse
    ModernResponse  APIResponse
    ExcludeFields   []string
}

type CompareResult struct {
    IsMatch         bool
    TotalFields     int
    MatchedFields   int
    FieldMatchRate  float64
    MismatchDetails []MismatchDetail
    Duration        time.Duration
}
```

### 1.3 비교 규칙

#### 1.3.1 필드명 비교

- **대소문자 구분**: `userName` ≠ `username`
- **공백 무시**: 필드명의 선행/후행 공백은 제거

#### 1.3.2 값 비교

| 케이스 | Legacy | Modern | 결과 |
|--------|--------|--------|------|
| 정수 일치 | `123` | `123` | ✓ 일치 |
| 문자열 일치 | `"hello"` | `"hello"` | ✓ 일치 |
| 타입 불일치 | `123` | `"123"` | ✗ 불일치 |
| null vs 빈 문자열 | `null` | `""` | ✗ 불일치 |
| 부동소수점 | `3.141592` | `3.141593` | ✓ 일치 (소수점 6자리) |
| 배열 순서 | `[1,2,3]` | `[3,2,1]` | ✗ 불일치 |
| 객체 필드 순서 | `{a:1, b:2}` | `{b:2, a:1}` | ✓ 일치 |

#### 1.3.3 부동소수점 비교

```go
const FloatTolerance = 1e-6 // 소수점 6자리

func compareFloat(a, b float64) bool {
    return math.Abs(a-b) < FloatTolerance
}
```

#### 1.3.4 배열 비교

- **순서 일치**: 배열 요소는 순서가 동일해야 함
- **길이 일치**: 배열 길이가 다르면 불일치
- **요소별 비교**: 각 인덱스의 요소를 재귀적으로 비교

```go
func compareArrays(legacy, modern []interface{}) bool {
    if len(legacy) != len(modern) {
        return false
    }

    for i := 0; i < len(legacy); i++ {
        if !compareValues(legacy[i], modern[i]) {
            return false
        }
    }

    return true
}
```

#### 1.3.5 객체 비교

- **필드 순서 무시**: 필드 순서와 무관하게 비교
- **필드 누락**: 한쪽에만 있는 필드는 불일치로 처리
- **재귀 비교**: 중첩된 객체는 재귀적으로 비교

```go
func compareObjects(legacy, modern map[string]interface{}, excludeFields []string) []MismatchDetail {
    var mismatches []MismatchDetail

    // Legacy 필드 검사
    for key, legacyValue := range legacy {
        if isExcluded(key, excludeFields) {
            continue
        }

        modernValue, exists := modern[key]
        if !exists {
            mismatches = append(mismatches, MismatchDetail{
                FieldPath:    key,
                LegacyValue:  legacyValue,
                ModernValue:  nil,
                ExpectedType: fmt.Sprintf("%T", legacyValue),
                ActualType:   "missing",
            })
            continue
        }

        if !compareValues(legacyValue, modernValue) {
            mismatches = append(mismatches, MismatchDetail{
                FieldPath:    key,
                LegacyValue:  legacyValue,
                ModernValue:  modernValue,
                ExpectedType: fmt.Sprintf("%T", legacyValue),
                ActualType:   fmt.Sprintf("%T", modernValue),
            })
        }
    }

    // Modern 필드 중 Legacy에 없는 것 검사
    for key, modernValue := range modern {
        if isExcluded(key, excludeFields) {
            continue
        }

        if _, exists := legacy[key]; !exists {
            mismatches = append(mismatches, MismatchDetail{
                FieldPath:    key,
                LegacyValue:  nil,
                ModernValue:  modernValue,
                ExpectedType: "missing",
                ActualType:   fmt.Sprintf("%T", modernValue),
            })
        }
    }

    return mismatches
}
```

### 1.4 비교 제외 필드

다음 필드는 비교 시 제외됩니다:

- **기본 제외 필드**:
  - `timestamp`
  - `requestId`
  - `traceId`
  - `responseTime`
  - `serverTime`

- **API별 설정 제외 필드**: Route 엔티티의 `ExcludeFields`에 정의

```go
func isExcluded(fieldPath string, excludeFields []string) bool {
    defaultExcluded := []string{"timestamp", "requestId", "traceId", "responseTime", "serverTime"}

    for _, excluded := range append(defaultExcluded, excludeFields...) {
        if strings.HasSuffix(fieldPath, excluded) {
            return true
        }
    }

    return false
}
```

### 1.5 타임아웃

- **비교 시간 제한**: 10초
- 10초 초과 시 비교 중단 및 타임아웃 기록

```go
func (s *ComparisonServiceImpl) Compare(ctx context.Context, req CompareRequest) (*CompareResult, error) {
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()

    start := time.Now()
    defer func() {
        result.Duration = time.Since(start)
    }()

    // 비교 로직...

    select {
    case <-ctx.Done():
        return nil, ErrComparisonTimeout
    default:
        return result, nil
    }
}
```

---

## 2. MatchRateCalculator

일치율을 계산하는 도메인 서비스입니다.

### 2.1 책임

- 일치율 계산
- 표본 수 관리
- 일치율 갱신

### 2.2 인터페이스

```go
type MatchRateCalculator interface {
    // Calculate: 일치율 계산
    Calculate(totalRequests, matchedRequests int64) float64

    // ShouldUpdateMatchRate: 일치율 갱신 필요 여부
    ShouldUpdateMatchRate(route *Route) bool

    // CanSwitch: 전환 가능 여부 판단
    CanSwitch(route *Route) bool

    // ShouldRollback: 롤백 필요 여부 판단
    ShouldRollback(route *Route) bool
}
```

### 2.3 일치율 계산 공식

```go
func (c *MatchRateCalculatorImpl) Calculate(totalRequests, matchedRequests int64) float64 {
    if totalRequests == 0 {
        return 0.0
    }

    matchRate := (float64(matchedRequests) / float64(totalRequests)) * 100.0

    // 소수점 2자리까지 반올림
    return math.Round(matchRate*100) / 100
}
```

### 2.4 표본 수 관리

- **기본 표본 수**: 100개
- **최소 표본 수**: 10개
- **최대 표본 수**: 1,000개

```go
func (c *MatchRateCalculatorImpl) ShouldUpdateMatchRate(route *Route) bool {
    // 1. 표본 수 범위 내에서만 갱신
    if route.TotalRequests > int64(route.SampleSize) {
        return false
    }

    // 2. 최소 표본 수 이상일 때만 유효
    return route.TotalRequests >= 10
}
```

### 2.5 전환 조건 검증

```go
func (c *MatchRateCalculatorImpl) CanSwitch(route *Route) bool {
    // 1. 일치율 100%
    if route.MatchRate != 100.0 {
        return false
    }

    // 2. 최소 표본 수 이상
    if route.TotalRequests < int64(route.SampleSize) {
        return false
    }

    // 3. Modern API 에러율 < 0.1%
    if route.ErrorRate >= 0.1 {
        return false
    }

    return true
}
```

### 2.6 롤백 조건 검증

```go
func (c *MatchRateCalculatorImpl) ShouldRollback(route *Route) bool {
    // 1. 일치율 < 99.9%
    if route.MatchRate < 99.9 {
        return true
    }

    // 2. 에러율 > 1%
    if route.ErrorRate > 1.0 {
        return true
    }

    return false
}
```

---

## 3. RoutingService

요청을 Legacy 또는 Modern API로 라우팅하고 응답을 선택하는 도메인 서비스입니다.

### 3.1 책임

- 운영 모드별 라우팅 결정
- 트래픽 분배 (Canary 모드)
- 응답 선택 (Legacy vs Modern)

### 3.2 인터페이스

```go
type RoutingService interface {
    // DecideRouting: 라우팅 결정
    DecideRouting(ctx context.Context, route *Route) RoutingDecision

    // SelectResponse: 응답 선택
    SelectResponse(decision RoutingDecision, legacyResp, modernResp APIResponse) APIResponse
}

type RoutingDecision struct {
    CallLegacy          bool    // Legacy API 호출 여부
    CallModern          bool    // Modern API 호출 여부
    ReturnLegacy        bool    // Legacy 응답 반환 여부
    ReturnModern        bool    // Modern 응답 반환 여부
    ShouldCompare       bool    // 비교 수행 여부
    CanaryPercentage    int     // Canary 비율
}
```

### 3.3 운영 모드별 라우팅

#### 3.3.1 Validation 모드 (검증)

- **목적**: Modern API 검증
- **라우팅**:
  - Legacy API: 동기 호출 → 응답 즉시 반환
  - Modern API: 비동기 호출 → 응답 비교만 수행
- **응답**: 항상 Legacy 응답 반환

```go
func (s *RoutingServiceImpl) validationMode(route *Route) RoutingDecision {
    return RoutingDecision{
        CallLegacy:    true,
        CallModern:    true,
        ReturnLegacy:  true,
        ReturnModern:  false,
        ShouldCompare: true,
    }
}
```

#### 3.3.2 Canary 모드

- **목적**: 점진적 전환
- **라우팅**:
  - Legacy API: 동기 호출
  - Modern API: 비동기 호출
  - N% 트래픽만 Modern 응답 반환
- **응답**: CanaryPercentage에 따라 Legacy 또는 Modern 응답 반환

```go
func (s *RoutingServiceImpl) canaryMode(route *Route) RoutingDecision {
    // 랜덤 값 생성 (0-99)
    random := rand.Intn(100)

    returnModern := random < route.CanaryPercentage

    return RoutingDecision{
        CallLegacy:       true,
        CallModern:       true,
        ReturnLegacy:     !returnModern,
        ReturnModern:     returnModern,
        ShouldCompare:    true,
        CanaryPercentage: route.CanaryPercentage,
    }
}
```

#### 3.3.3 Switched 모드 (전환 완료)

- **목적**: 완전 전환
- **라우팅**:
  - Legacy API: 호출하지 않음 (비교 종료)
  - Modern API: 동기 호출
- **응답**: 항상 Modern 응답 반환

```go
func (s *RoutingServiceImpl) switchedMode(route *Route) RoutingDecision {
    return RoutingDecision{
        CallLegacy:    false,
        CallModern:    true,
        ReturnLegacy:  false,
        ReturnModern:  true,
        ShouldCompare: false,
    }
}
```

### 3.4 응답 선택 로직

```go
func (s *RoutingServiceImpl) SelectResponse(
    decision RoutingDecision,
    legacyResp, modernResp APIResponse,
) APIResponse {
    if decision.ReturnModern {
        return modernResp
    }
    return legacyResp
}
```

### 3.5 Canary 트래픽 분배 알고리즘

- **방식**: 랜덤 분배 (균등 분포)
- **구현**: `rand.Intn(100) < CanaryPercentage`

```go
// 예: CanaryPercentage = 10
// 0-9 (10%) → Modern 반환
// 10-99 (90%) → Legacy 반환

func shouldReturnModern(canaryPercentage int) bool {
    return rand.Intn(100) < canaryPercentage
}
```

---

## 4. ExperimentService

반자동 전환 실험을 관리하는 도메인 서비스입니다.

### 4.1 책임

- 실험 생명주기 관리 (Start, Pause, Resume, Abort)
- 단계별 진행 조건 검증
- 롤백 결정
- 알림 트리거

### 4.2 인터페이스

```go
type ExperimentService interface {
    // Start: 실험 시작
    Start(ctx context.Context, experiment *Experiment) error

    // Pause: 실험 일시 정지
    Pause(ctx context.Context, experimentID string) error

    // Resume: 실험 재개
    Resume(ctx context.Context, experimentID string) error

    // Approve: 다음 단계 승인
    Approve(ctx context.Context, req ApproveRequest) error

    // Abort: 실험 중단
    Abort(ctx context.Context, experimentID string, reason string) error

    // CheckProgressConditions: 진행 조건 검증
    CheckProgressConditions(ctx context.Context, stage *ExperimentStage) (*ProgressConditionResult, error)

    // CheckRollbackConditions: 롤백 조건 검증
    CheckRollbackConditions(ctx context.Context, stage *ExperimentStage) (*RollbackDecision, error)
}

type ApproveRequest struct {
    ExperimentID   string
    ApprovedBy     string
    Comment        string
}

type ProgressConditionResult struct {
    CanProceed              bool
    StabilizationElapsed    bool
    MinRequestsMet          bool
    MatchRateOK             bool
    ErrorRateOK             bool
    ResponseTimeOK          bool
    Reason                  string
}

type RollbackDecision struct {
    ShouldRollback  bool
    Severity        string // "critical" | "warning"
    Reason          string
}
```

### 4.3 실험 시작 로직

```go
func (s *ExperimentServiceImpl) Start(ctx context.Context, experiment *Experiment) error {
    // 1. 상태 검증
    if experiment.Status != ExperimentStatusPending {
        return ErrInvalidExperimentStatus
    }

    // 2. 실험 시작
    if err := experiment.Start(); err != nil {
        return err
    }

    // 3. 첫 번째 단계 생성
    stage := &ExperimentStage{
        ID:                 uuid.New().String(),
        ExperimentID:       experiment.ID,
        Stage:              1,
        TrafficPercentage:  experiment.InitialPercentage,
        MinRequests:        getMinRequests(1),
        StartedAt:          time.Now(),
    }

    // 4. Route의 OperationMode를 Canary로 변경
    // 5. Route의 CanaryPercentage 설정
    // (UseCase 레이어에서 처리)

    return nil
}

func getMinRequests(stage int) int {
    minRequests := map[int]int{
        1: 100,    // 1% → 5%
        2: 500,    // 5% → 10%
        3: 1000,   // 10% → 25%
        4: 5000,   // 25% → 50%
        5: 10000,  // 50% → 100%
    }
    return minRequests[stage]
}
```

### 4.4 진행 조건 검증

```go
func (s *ExperimentServiceImpl) CheckProgressConditions(
    ctx context.Context,
    stage *ExperimentStage,
) (*ProgressConditionResult, error) {
    result := &ProgressConditionResult{}

    experiment, err := s.experimentRepo.FindByID(ctx, stage.ExperimentID)
    if err != nil {
        return nil, err
    }

    // 1. 안정화 기간 경과
    elapsed := time.Since(stage.StartedAt)
    result.StabilizationElapsed = elapsed >= time.Duration(experiment.StabilizationPeriod)*time.Second

    // 2. 최소 요청 수 충족
    result.MinRequestsMet = stage.TotalRequests >= int64(stage.MinRequests)

    // 3. 일치율 ≥ 99.9%
    result.MatchRateOK = stage.MatchRate >= 99.9

    // 4. 에러율 < 0.1%
    result.ErrorRateOK = stage.ErrorRate < 0.1

    // 5. 응답 시간 ≤ Legacy × 1.2
    result.ResponseTimeOK = stage.ModernAvgResponseTime <= stage.LegacyAvgResponseTime*12/10

    // 종합 판단
    result.CanProceed = result.StabilizationElapsed &&
                        result.MinRequestsMet &&
                        result.MatchRateOK &&
                        result.ErrorRateOK &&
                        result.ResponseTimeOK

    if !result.CanProceed {
        result.Reason = s.buildProgressBlockReason(result)
    }

    return result, nil
}

func (s *ExperimentServiceImpl) buildProgressBlockReason(result *ProgressConditionResult) string {
    var reasons []string

    if !result.StabilizationElapsed {
        reasons = append(reasons, "안정화 기간 미경과")
    }
    if !result.MinRequestsMet {
        reasons = append(reasons, "최소 요청 수 미달")
    }
    if !result.MatchRateOK {
        reasons = append(reasons, "일치율 99.9% 미만")
    }
    if !result.ErrorRateOK {
        reasons = append(reasons, "에러율 0.1% 초과")
    }
    if !result.ResponseTimeOK {
        reasons = append(reasons, "응답 시간이 Legacy의 1.2배 초과")
    }

    return strings.Join(reasons, ", ")
}
```

### 4.5 롤백 조건 검증

```go
func (s *ExperimentServiceImpl) CheckRollbackConditions(
    ctx context.Context,
    stage *ExperimentStage,
) (*RollbackDecision, error) {
    decision := &RollbackDecision{}

    // 즉시 롤백 (Critical)
    if stage.ErrorRate > 1.0 {
        decision.ShouldRollback = true
        decision.Severity = "critical"
        decision.Reason = fmt.Sprintf("Modern API 에러율 %.2f%% (임계값: 1.0%%)", stage.ErrorRate)
        return decision, nil
    }

    if stage.ModernAvgResponseTime > stage.LegacyAvgResponseTime*2 {
        decision.ShouldRollback = true
        decision.Severity = "critical"
        decision.Reason = fmt.Sprintf(
            "Modern API 응답 시간 %dms가 Legacy %dms의 2배 초과",
            stage.ModernAvgResponseTime,
            stage.LegacyAvgResponseTime,
        )
        return decision, nil
    }

    // 경고 후 롤백 (Warning) - 5분 지속 시
    if stage.MatchRate < 99.5 {
        decision.ShouldRollback = s.shouldRollbackAfterWarning(ctx, stage, "match_rate")
        decision.Severity = "warning"
        decision.Reason = fmt.Sprintf("일치율 %.2f%% (임계값: 99.5%%)", stage.MatchRate)
        return decision, nil
    }

    if stage.ErrorRate > 0.5 {
        decision.ShouldRollback = s.shouldRollbackAfterWarning(ctx, stage, "error_rate")
        decision.Severity = "warning"
        decision.Reason = fmt.Sprintf("에러율 %.2f%% (임계값: 0.5%%)", stage.ErrorRate)
        return decision, nil
    }

    if stage.ModernAvgResponseTime > stage.LegacyAvgResponseTime*15/10 {
        decision.ShouldRollback = s.shouldRollbackAfterWarning(ctx, stage, "response_time")
        decision.Severity = "warning"
        decision.Reason = fmt.Sprintf(
            "응답 시간 %dms가 Legacy %dms의 1.5배 초과",
            stage.ModernAvgResponseTime,
            stage.LegacyAvgResponseTime,
        )
        return decision, nil
    }

    return decision, nil
}

// shouldRollbackAfterWarning: 경고 조건이 5분 이상 지속되었는지 확인
func (s *ExperimentServiceImpl) shouldRollbackAfterWarning(
    ctx context.Context,
    stage *ExperimentStage,
    warningType string,
) bool {
    // Redis 또는 메모리에서 경고 시작 시간 조회
    warningKey := fmt.Sprintf("warning:%s:%s", stage.ID, warningType)
    warningStartTime, exists := s.warningCache.Get(warningKey)

    if !exists {
        // 최초 경고 발생 - 시작 시간 기록
        s.warningCache.Set(warningKey, time.Now(), 10*time.Minute)
        return false
    }

    // 경고가 5분 이상 지속되었는지 확인
    elapsed := time.Since(warningStartTime.(time.Time))
    return elapsed >= 5*time.Minute
}
```

### 4.6 승인 로직

```go
func (s *ExperimentServiceImpl) Approve(ctx context.Context, req ApproveRequest) error {
    experiment, err := s.experimentRepo.FindByID(ctx, req.ExperimentID)
    if err != nil {
        return err
    }

    // 현재 단계의 진행 조건 검증
    currentStage, err := s.stageRepo.FindCurrentStage(ctx, req.ExperimentID)
    if err != nil {
        return err
    }

    conditionResult, err := s.CheckProgressConditions(ctx, currentStage)
    if err != nil {
        return err
    }

    if !conditionResult.CanProceed {
        return fmt.Errorf("진행 조건 미충족: %s", conditionResult.Reason)
    }

    // 다음 단계 비율 결정
    nextPercentage := getNextStagePercentage(experiment.CurrentPercentage)

    // 실험 승인 및 단계 진행
    if err := experiment.Approve(req.ApprovedBy, nextPercentage); err != nil {
        return err
    }

    // 현재 단계 완료 처리
    currentStage.Complete(req.ApprovedBy)

    // 새로운 단계 생성 (100% 미만일 때만)
    if nextPercentage < 100 {
        newStage := &ExperimentStage{
            ID:                uuid.New().String(),
            ExperimentID:      experiment.ID,
            Stage:             currentStage.Stage + 1,
            TrafficPercentage: nextPercentage,
            MinRequests:       getMinRequests(currentStage.Stage + 1),
            StartedAt:         time.Now(),
        }
        // Repository에 저장 (UseCase 레이어에서 처리)
    }

    return nil
}

func getNextStagePercentage(current int) int {
    stages := []int{1, 5, 10, 25, 50, 100}

    for _, stage := range stages {
        if current < stage {
            return stage
        }
    }

    return 100
}
```

### 4.7 중단 및 롤백 로직

```go
func (s *ExperimentServiceImpl) Abort(
    ctx context.Context,
    experimentID string,
    reason string,
) error {
    experiment, err := s.experimentRepo.FindByID(ctx, experimentID)
    if err != nil {
        return err
    }

    // 실험 중단
    if err := experiment.Abort(reason); err != nil {
        return err
    }

    // 현재 단계 롤백 기록
    currentStage, err := s.stageRepo.FindCurrentStage(ctx, experimentID)
    if err == nil {
        currentStage.Rollback(reason)
        // Repository에 저장 (UseCase 레이어에서 처리)
    }

    // Route를 Validation 모드로 복원
    // CanaryPercentage를 0으로 설정
    // (UseCase 레이어에서 처리)

    // 알림 발송 (긴급)
    // (UseCase 레이어에서 처리)

    return nil
}
```

---

## 5. 도메인 이벤트

도메인 서비스가 발생시키는 이벤트 목록입니다.

### 5.1 ComparisonService 이벤트

- `ComparisonCompletedEvent`: 비교 완료
- `ComparisonFailedEvent`: 비교 실패
- `ComparisonTimeoutEvent`: 비교 타임아웃

### 5.2 ExperimentService 이벤트

- `ExperimentStartedEvent`: 실험 시작
- `ExperimentPausedEvent`: 실험 일시 정지
- `ExperimentResumedEvent`: 실험 재개
- `ExperimentApprovedEvent`: 단계 승인
- `ExperimentCompletedEvent`: 실험 완료
- `ExperimentAbortedEvent`: 실험 중단
- `RollbackTriggeredEvent`: 롤백 발생
- `ProgressConditionMetEvent`: 진행 조건 충족 (알림 필요)

---

## 6. 에러 정의

### 6.1 ComparisonService 에러

```go
var (
    ErrComparisonTimeout    = errors.New("comparison timeout")
    ErrInvalidJSONFormat    = errors.New("invalid JSON format")
    ErrResponseBodyEmpty    = errors.New("response body is empty")
)
```

### 6.2 ExperimentService 에러

```go
var (
    ErrInvalidExperimentStatus   = errors.New("invalid experiment status")
    ErrCannotPauseExperiment     = errors.New("cannot pause experiment")
    ErrCannotResumeExperiment    = errors.New("cannot resume experiment")
    ErrCannotApproveExperiment   = errors.New("cannot approve experiment")
    ErrCannotAbortExperiment     = errors.New("cannot abort experiment")
    ErrInvalidNextPercentage     = errors.New("invalid next percentage")
    ErrProgressConditionsNotMet  = errors.New("progress conditions not met")
)
```

---

## 7. 참고 사항

### 7.1 의존성

- 도메인 서비스는 **도메인 엔티티**와 **Port 인터페이스**만 의존
- 외부 인프라(DB, Redis 등)는 Port를 통해 접근
- Application 계층의 UseCase에서 도메인 서비스를 오케스트레이션

### 7.2 트랜잭션

- 도메인 서비스는 트랜잭션을 직접 관리하지 않음
- UseCase 레이어에서 트랜잭션 경계 설정

### 7.3 동시성

- ComparisonService는 stateless하므로 동시 호출 가능
- ExperimentService는 낙관적 잠금(Optimistic Lock) 사용 권장

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
