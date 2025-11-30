# 문서 작성 가이드라인

## 문서 목적

본 문서는 ABS 프로젝트의 설계 문서 작성 시 일관성 있고 읽기 쉬운 문서를 만들기 위한 가이드라인을 제공합니다.

---

## 1. 문서 작성 원칙

### 1.1 간결성 (Conciseness)

- **핵심만 작성**: 구현 코드는 제외하고 개념, 규칙, 정책 중심으로 작성
- **불필요한 설명 제거**: 자명한 내용은 생략
- **리스트 활용**: 긴 문장보다는 bullet point나 번호 매긴 리스트 활용

### 1.2 명확성 (Clarity)

- **명확한 제목**: 섹션과 하위 섹션에 명확한 제목 사용
- **일관된 용어**: 동일한 개념은 항상 동일한 용어 사용
- **다이어그램 활용**: 복잡한 관계는 텍스트보다 다이어그램으로 표현

### 1.3 실용성 (Practicality)

- **실제 개발에 도움**: 개발자가 구현 시 참고할 수 있는 구체적 내용 포함
- **의사 결정 가이드**: 왜 이 방식을 선택했는지, 어떤 조건에서 사용하는지 명시
- **예시 최소화**: 간단한 예시는 포함하되, 복잡한 샘플 코드는 제외

---

## 2. 포함해야 할 내용

### 2.1 개념 정의

✅ **포함**:
- Entity, Value Object, Service의 역할 및 책임
- 필드 정의 (타입, 설명, 필수 여부, 기본값)
- 도메인 규칙 및 불변식

✅ **형식**:
- 테이블 형식 사용
- 명확한 타입 명시

**예시**:
```markdown
| 필드명 | 타입 | 설명 | 필수 | 기본값 |
|--------|------|------|------|--------|
| `ID` | `string` | 라우트 고유 식별자 (UUID) | ✓ | - |
| `Path` | `string` | API 경로 | ✓ | - |
```

### 2.2 비즈니스 규칙

✅ **포함**:
- 불변식 (Invariants)
- 검증 조건
- 상태 전이 규칙
- 계산 공식

✅ **형식**:
- 번호 매긴 리스트
- 조건은 간결하게

**예시**:
```markdown
#### 불변식 (Invariants)

1. **Path 검증**: Path는 반드시 '/'로 시작해야 함
2. **SampleSize 범위**: 10 이상 1,000 이하
3. **CanaryPercentage 범위**: 0 이상 100 이하
```

### 2.3 인터페이스 시그니처

✅ **포함**:
- 메서드 이름, 파라미터, 반환값
- 메서드의 역할 및 책임 (1-2줄)
- 전제 조건, 사후 조건

✅ **형식**:
- 시그니처와 간단한 설명
- 구현 코드는 제외

**예시**:
```markdown
**`Start() error`**
- 실험 시작
- 전제 조건: Status = pending
- 상태 전이: pending → running
- CurrentPercentage를 InitialPercentage로 설정
```

### 2.4 다이어그램

✅ **포함**:
- Entity 관계도 (ERD)
- 상태 머신
- 플로우차트
- 아키텍처 다이어그램

✅ **형식**:
- ASCII 아트 또는 Mermaid
- 간결하고 핵심만 표현

**예시**:
```markdown
```
┌──────────────┐
│    Route     │◄───┐
└──────────────┘    │
       ▲            │ RouteID
       │            │
┌──────────────┐    │
│  Experiment  │────┘
└──────────────┘
```
```

### 2.5 정책 및 전략

✅ **포함**:
- 알고리즘 설명 (의사코드 수준)
- 의사 결정 규칙
- 임계값, 기본값

✅ **형식**:
- 테이블 또는 리스트
- 수식은 간단히

**예시**:
```markdown
### 일치율 계산 공식

```
MatchRate = (MatchedRequests / TotalRequests) × 100
```

- 소수점 2자리까지 반올림
- TotalRequests = 0일 때는 0.0 반환
```

---

## 3. 제거해야 할 내용

### 3.1 구현 코드

❌ **제거**:
- func 내부 로직
- 복잡한 if-else 구조
- for loop 등 제어 구조

**Before** (제거):
```go
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
```

**After** (유지):
```markdown
**`Start() error`**
- 실험 시작
- 전제 조건: Status = pending
- 상태 전이: pending → running
- CurrentPercentage를 InitialPercentage로 설정
```

### 3.2 복잡한 예시 코드

❌ **제거**:
- 100줄 이상의 샘플 코드
- 실제 구현 수준의 예시

**Before** (제거):
```go
func (u *ApproveExperimentUseCase) Execute(ctx context.Context, req ApproveRequest) error {
    txCtx, err := u.uow.Begin(ctx)
    if err != nil {
        return err
    }
    // ... 50줄의 구현 코드
}
```

**After** (유지):
```markdown
### 사용 시나리오

- 실험 승인 시 Experiment, ExperimentStage, Route를 동시에 수정하는 경우
- 원자성이 보장되어야 하는 복잡한 비즈니스 로직
```

### 3.3 상세 구현 방법

❌ **제거**:
- 라이브러리 사용법 상세 설명
- 코드 최적화 기법
- 성능 튜닝 세부 사항

✅ **유지**:
- 선택한 라이브러리 및 이유
- 주요 설정값
- 참고 링크

---

## 4. 문서 구조

### 4.1 공통 구조

모든 문서는 다음 구조를 따릅니다:

```markdown
# 문서 제목

## 문서 목적

본 문서는 ...

**포함 내용**:
- 항목 1
- 항목 2

---

## 1. 첫 번째 섹션

### 1.1 하위 섹션

#### 세부 항목

---

## 참고 사항

---

**최종 수정일**: YYYY-MM-DD
**작성자**: ABS 개발팀
```

### 4.2 섹션 구성 팁

- **목차 생성**: 긴 문서는 목차 포함
- **구분선 사용**: `---`로 섹션 구분
- **일관된 번호 체계**: 1.1, 1.2 형식 사용
- **최종 수정일 기록**: 문서 하단에 날짜 기록

---

## 5. 표 작성 가이드

### 5.1 필드 정의 표

| 필드명 | 타입 | 설명 | 필수 | 기본값 |
|--------|------|------|------|--------|
| 필드명을 `` 감싸기 | `` 감싸기 | 간결하게 | ✓ 또는 빈칸 | 값 또는 - |

### 5.2 비교 표

| 항목 | 값 A | 값 B | 결과 |
|------|------|------|------|
| 케이스명 | 예시 A | 예시 B | ✓ 또는 ✗ |

### 5.3 정책 표

| 항목 | 값 | 설명 |
|------|-----|------|
| 정책명 | 값 | 간단한 설명 |

---

## 6. 코드 블록 사용

### 6.1 구조체 정의 (간단한 경우만)

```go
type APIRequest struct {
    Method  string            // HTTP 메서드
    Path    string            // 요청 경로
    Headers map[string]string // 헤더
}
```

### 6.2 상수 정의

```go
const (
    OperationModeValidation OperationMode = "validation"
    OperationModeCanary     OperationMode = "canary"
    OperationModeSwitched   OperationMode = "switched"
)
```

### 6.3 공식 또는 명령어

```
MatchRate = (MatchedRequests / TotalRequests) × 100
```

```bash
mockgen -source=internal/domain/port/route_repository.go \
        -destination=internal/domain/port/mock/mock_route_repository.go
```

---

## 7. 마크다운 스타일 가이드

### 7.1 강조

- **굵게**: 중요한 용어, 섹션 제목
- *기울임*: 강조 (드물게 사용)
- `코드`: 변수명, 타입, 값

### 7.2 리스트

**순서 있는 리스트**: 단계, 조건 (순서가 중요)
```markdown
1. 첫 번째 단계
2. 두 번째 단계
```

**순서 없는 리스트**: 항목 나열
```markdown
- 항목 A
- 항목 B
```

### 7.3 링크

```markdown
- 내부 링크: [아키텍처 설계](./01-architecture.md)
- 외부 링크: [Go 공식 문서](https://golang.org/doc/)
```

---

## 8. 체크리스트

문서 작성 완료 전 다음을 확인하세요:

- [ ] **간결성**: 불필요한 코드 구현 제거
- [ ] **명확성**: 섹션 제목과 용어가 일관적
- [ ] **구조**: 공통 구조 (목적, 섹션, 참고사항, 작성자) 포함
- [ ] **표 형식**: 필드 정의는 테이블로 작성
- [ ] **다이어그램**: 관계도가 필요한 곳에 추가
- [ ] **시그니처**: 인터페이스 메서드는 시그니처와 설명만 포함
- [ ] **규칙**: 비즈니스 규칙은 번호 매긴 리스트로 작성
- [ ] **예시 최소화**: 복잡한 샘플 코드 제거
- [ ] **최종 수정일**: 문서 하단에 날짜 기록

---

## 9. 예시 비교

### Before (제거할 스타일)

```markdown
## Comparison Service

ComparisonService는 Legacy와 Modern API를 비교합니다. 이 서비스는 JSON 파싱, 필드 비교, 타입 검증 등의 기능을 수행합니다. 구현은 다음과 같습니다:

```go
func (s *ComparisonServiceImpl) Compare(ctx context.Context, req CompareRequest) (*CompareResult, error) {
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()

    start := time.Now()
    // ... 100줄의 구현 코드
}
```
```

### After (권장 스타일)

```markdown
## ComparisonService

Legacy API와 Modern API의 JSON 응답을 비교하는 도메인 서비스입니다.

### 책임

- JSON 응답 파싱
- 필드별 값 비교
- 타입 검증 (숫자 vs 문자열, null vs 빈 문자열)

### 인터페이스

**`Compare(ctx context.Context, req CompareRequest) (*CompareResult, error)`**
- Legacy와 Modern 응답 비교
- 타임아웃: 10초

### 비교 규칙

| 케이스 | Legacy | Modern | 결과 |
|--------|--------|--------|------|
| 정수 일치 | `123` | `123` | ✓ 일치 |
| 타입 불일치 | `123` | `"123"` | ✗ 불일치 |
```

---

## 10. 참고 자료

- [마크다운 가이드](https://www.markdownguide.org/)
- [Go 공식 문서 스타일](https://go.dev/doc/effective_go)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
