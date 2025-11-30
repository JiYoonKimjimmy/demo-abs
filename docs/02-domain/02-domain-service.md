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

**`Compare(ctx context.Context, req CompareRequest) (*CompareResult, error)`**
- Legacy와 Modern 응답 비교
- 타임아웃: 10초

**파라미터**:
- `CompareRequest`: LegacyResponse, ModernResponse, ExcludeFields

**반환값**:
- `CompareResult`: IsMatch, TotalFields, MatchedFields, FieldMatchRate, MismatchDetails, Duration

### 1.3 비교 규칙

#### 1.3.1 필드명 비교

- **대소문자 구분**: `userName` ≠ `username`
- **공백 무시**: 필드명의 선행/후행 공백 제거

#### 1.3.2 값 비교

| 케이스 | Legacy | Modern | 결과 |
|--------|--------|--------|------|
| 정수 일치 | `123` | `123` | ✓ 일치 |
| 문자열 일치 | `"hello"` | `"hello"` | ✓ 일치 |
| 타입 불일치 | `123` | `"123"` | ✗ 불일치 |
| null vs 빈 문자열 | `null` | `""` | ✗ 불일치 |
| 부동소수점 | `3.141592` | `3.141593` | ✓ 일치 (허용 오차 1e-6) |
| 배열 순서 | `[1,2,3]` | `[3,2,1]` | ✗ 불일치 |
| 객체 필드 순서 | `{a:1, b:2}` | `{b:2, a:1}` | ✓ 일치 |

#### 1.3.3 부동소수점 비교

- **허용 오차**: `1e-6` (소수점 6자리)
- **비교 방법**: `abs(a - b) < 1e-6`

#### 1.3.4 배열 비교

- **순서 일치**: 배열 요소 순서가 동일해야 함
- **길이 일치**: 배열 길이가 다르면 불일치
- **요소별 비교**: 각 인덱스의 요소를 재귀적으로 비교

#### 1.3.5 객체 비교

- **필드 순서 무시**: 필드 순서와 무관하게 비교
- **필드 누락**: 한쪽에만 있는 필드는 불일치
- **재귀 비교**: 중첩된 객체는 재귀적으로 비교

### 1.4 비교 제외 필드

**기본 제외 필드**:
- `timestamp`
- `requestId`
- `traceId`
- `responseTime`
- `serverTime`

**API별 설정**: Route 엔티티의 `ExcludeFields`에 정의

### 1.5 타임아웃

- **비교 시간 제한**: 10초
- 10초 초과 시 비교 중단 및 타임아웃 기록

---

## 2. MatchRateCalculator

일치율을 계산하는 도메인 서비스입니다.

### 2.1 책임

- 일치율 계산
- 표본 수 관리
- 전환/롤백 조건 검증

### 2.2 인터페이스

**`Calculate(totalRequests, matchedRequests int64) float64`**
- 일치율 계산
- 공식: `(matchedRequests / totalRequests) * 100`
- 소수점 2자리 반올림

**`ShouldUpdateMatchRate(route *Route) bool`**
- 일치율 갱신 필요 여부 판단
- 조건: TotalRequests ≤ SampleSize AND TotalRequests ≥ 10

**`CanSwitch(route *Route) bool`**
- Modern API 전환 가능 여부 판단
- 조건: MatchRate = 100% AND TotalRequests ≥ SampleSize AND ErrorRate < 0.1%

**`ShouldRollback(route *Route) bool`**
- 롤백 필요 여부 판단
- 조건: MatchRate < 99.9% OR ErrorRate > 1%

### 2.3 일치율 계산 공식

```
MatchRate = (MatchedRequests / TotalRequests) × 100
```

- 소수점 2자리까지 반올림
- TotalRequests = 0일 때는 0.0 반환

### 2.4 표본 수 관리

| 항목 | 값 |
|------|-----|
| 기본 표본 수 | 100개 |
| 최소 표본 수 | 10개 |
| 최대 표본 수 | 1,000개 |

---

## 3. RoutingService

요청을 Legacy 또는 Modern API로 라우팅하고 응답을 선택하는 도메인 서비스입니다.

### 3.1 책임

- 운영 모드별 라우팅 결정
- 트래픽 분배 (Canary 모드)
- 응답 선택 (Legacy vs Modern)

### 3.2 인터페이스

**`DecideRouting(ctx context.Context, route *Route) RoutingDecision`**
- 운영 모드에 따라 라우팅 결정
- 반환: CallLegacy, CallModern, ReturnLegacy, ReturnModern, ShouldCompare

**`SelectResponse(decision RoutingDecision, legacyResp, modernResp APIResponse) APIResponse`**
- 라우팅 결정에 따라 응답 선택

### 3.3 운영 모드별 라우팅

#### 3.3.1 Validation 모드 (검증)

| 항목 | 동작 |
|------|------|
| **목적** | Modern API 검증 |
| **Legacy API** | 동기 호출 → 응답 즉시 반환 |
| **Modern API** | 비동기 호출 → 응답 비교만 수행 |
| **응답** | 항상 Legacy 응답 반환 |
| **비교** | 수행 |

#### 3.3.2 Canary 모드

| 항목 | 동작 |
|------|------|
| **목적** | 점진적 전환 |
| **Legacy API** | 동기 호출 |
| **Modern API** | 비동기 호출 |
| **응답** | CanaryPercentage에 따라 Legacy 또는 Modern 응답 반환 |
| **비교** | 수행 |

**트래픽 분배 알고리즘**:
- 방식: 랜덤 분배 (균등 분포)
- 구현: `rand.Intn(100) < CanaryPercentage`
- 예: CanaryPercentage = 10일 때, 0-9 (10%) → Modern 반환, 10-99 (90%) → Legacy 반환

#### 3.3.3 Switched 모드 (전환 완료)

| 항목 | 동작 |
|------|------|
| **목적** | 완전 전환 |
| **Legacy API** | 호출하지 않음 |
| **Modern API** | 동기 호출 |
| **응답** | 항상 Modern 응답 반환 |
| **비교** | 수행 안 함 |

---

## 4. ExperimentService

반자동 전환 실험을 관리하는 도메인 서비스입니다.

### 4.1 책임

- 실험 생명주기 관리 (Start, Pause, Resume, Abort, Approve)
- 단계별 진행 조건 검증
- 롤백 결정
- 알림 트리거

### 4.2 인터페이스

**`Start(ctx context.Context, experiment *Experiment) error`**
- 실험 시작
- 전제 조건: Status = pending
- 상태 전이: pending → running
- 첫 번째 단계 (ExperimentStage) 생성

**`Pause(ctx context.Context, experimentID string) error`**
- 실험 일시 정지
- 상태 전이: running → paused

**`Resume(ctx context.Context, experimentID string) error`**
- 실험 재개
- 상태 전이: paused → running

**`Approve(ctx context.Context, req ApproveRequest) error`**
- 다음 단계 승인
- 진행 조건 검증
- 트래픽 비율 증가
- 새로운 ExperimentStage 생성

**`Abort(ctx context.Context, experimentID string, reason string) error`**
- 실험 중단
- 상태 전이: * → aborted
- Route를 Validation 모드로 복원

**`CheckProgressConditions(ctx context.Context, stage *ExperimentStage) (*ProgressConditionResult, error)`**
- 다음 단계 진행 가능 여부 검증
- 5개 조건 확인 (안정화 기간, 최소 요청 수, 일치율, 에러율, 응답 시간)

**`CheckRollbackConditions(ctx context.Context, stage *ExperimentStage) (*RollbackDecision, error)`**
- 롤백 필요 여부 검증
- 즉시 롤백 / 경고 후 롤백 조건 확인

### 4.3 단계별 최소 요청 수

| 단계 | 트래픽 비율 | 최소 요청 수 |
|------|-------------|--------------|
| 1 | 1% → 5% | 100 |
| 2 | 5% → 10% | 500 |
| 3 | 10% → 25% | 1,000 |
| 4 | 25% → 50% | 5,000 |
| 5 | 50% → 100% | 10,000 |

### 4.4 진행 조건 (모두 충족)

1. **안정화 기간 경과**: StartedAt 또는 LastApprovedAt 기준
2. **최소 요청 수 충족**: TotalRequests ≥ MinRequests
3. **일치율 조건**: MatchRate ≥ 99.9%
4. **에러율 조건**: ErrorRate < 0.1%
5. **응답 시간 조건**: ModernAvgResponseTime ≤ LegacyAvgResponseTime × 1.2

### 4.5 롤백 조건

#### 즉시 롤백 (Critical)

조건 (하나라도 충족):
1. ErrorRate > 1%
2. ModernAvgResponseTime > LegacyAvgResponseTime × 2.0

동작:
- 즉시 이전 안정 단계로 롤백
- 관리자에게 긴급 알림 발송

#### 경고 후 롤백 (Warning)

조건 (하나라도 5분 이상 지속):
1. MatchRate < 99.5%
2. ErrorRate > 0.5%
3. ModernAvgResponseTime > LegacyAvgResponseTime × 1.5

동작:
- 경고 시작 시간을 Redis에 기록
- 5분 경과 시 롤백
- 관리자에게 경고 알림 발송

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
- `ExperimentCompletedEvent`: 실험 완료 (100% 도달)
- `ExperimentAbortedEvent`: 실험 중단
- `RollbackTriggeredEvent`: 롤백 발생 (즉시 또는 경고 후)
- `ProgressConditionMetEvent`: 진행 조건 충족 (관리자 알림 필요)

---

## 6. 에러 정의

### 6.1 ComparisonService 에러

- `ErrComparisonTimeout`: 비교 타임아웃 (10초 초과)
- `ErrInvalidJSONFormat`: 유효하지 않은 JSON 형식
- `ErrResponseBodyEmpty`: 응답 본문이 비어있음

### 6.2 ExperimentService 에러

- `ErrInvalidExperimentStatus`: 유효하지 않은 실험 상태
- `ErrCannotPauseExperiment`: 실험을 일시 정지할 수 없음
- `ErrCannotResumeExperiment`: 실험을 재개할 수 없음
- `ErrCannotApproveExperiment`: 실험을 승인할 수 없음
- `ErrCannotAbortExperiment`: 실험을 중단할 수 없음
- `ErrInvalidNextPercentage`: 유효하지 않은 다음 단계 비율
- `ErrProgressConditionsNotMet`: 진행 조건 미충족

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

- ComparisonService: stateless → 동시 호출 가능
- MatchRateCalculator: stateless → 동시 호출 가능
- RoutingService: stateless → 동시 호출 가능
- ExperimentService: 낙관적 잠금(Optimistic Lock) 사용 권장

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
