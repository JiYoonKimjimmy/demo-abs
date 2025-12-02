# 01. 코딩 컨벤션

## 1. 문서 개요

본 문서는 ABS 프로젝트의 Go 코딩 스타일 가이드와 컨벤션을 정의합니다.

### 1.1 포함 내용

- Go 표준 코딩 스타일
- 네이밍 규칙
- 패키지 구조 규칙
- 에러 처리 규칙
- 주석 작성 규칙
- 코드 포맷팅
- Import 순서
- 인터페이스 설계

### 1.2 참고 자료

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)

## 2. 네이밍 규칙

### 2.1 패키지 네이밍

**규칙:**
- 소문자만 사용 (언더스코어, 대시 금지)
- 간결하고 명확한 이름
- 단수형 사용

```go
// Good
package user
package route
package config

// Bad
package users      // 복수형
package user_data  // 언더스코어
package user-data  // 대시
```

### 2.2 변수/함수 네이밍

**규칙:**
- CamelCase 사용
- 짧은 스코프는 짧은 이름
- 긴 스코프는 설명적인 이름

```go
// Good - 짧은 스코프
for i := 0; i < 10; i++ {
    // i는 짧은 스코프에서 명확
}

// Good - 긴 스코프
func ProcessComparison(comparisonRequest *ComparisonRequest) error {
    // 설명적인 이름
}

// Bad
func prcCmp(cr *CR) error {
    // 너무 축약됨
}
```

### 2.3 상수 네이밍

**규칙:**
- MixedCaps 사용 (ALL_CAPS 금지)
- 그룹화된 상수는 타입 지정

```go
// Good
const (
    StatusPending   = "pending"
    StatusCompleted = "completed"
    StatusFailed    = "failed"
)

// Good - 타입 지정
type Status string

const (
    StatusPending   Status = "pending"
    StatusCompleted Status = "completed"
    StatusFailed    Status = "failed"
)

// Bad
const (
    STATUS_PENDING   = "pending"  // ALL_CAPS
    STATUS_COMPLETED = "completed"
)
```

### 2.4 구조체 네이밍

**규칙:**
- PascalCase 사용
- 명사 사용
- Interface는 -er 접미사 (가능한 경우)

```go
// Good
type Route struct {
    ID   string
    Path string
}

type Comparator interface {
    Compare(a, b []byte) (*Result, error)
}

// Bad
type route struct {  // 소문자 (unexported)는 필요한 경우만
    ID string
}

type IComparator interface {  // I 접두사 금지
    Compare(a, b []byte) (*Result, error)
}
```

### 2.5 메서드 리시버 네이밍

**규칙:**
- 1-2 글자 약어 사용
- 일관된 이름 (같은 타입은 같은 리시버명)

```go
type RouteService struct {
    repository RouteRepository
}

// Good - 일관된 's'
func (s *RouteService) CreateRoute(route *Route) error {
    return s.repository.Save(route)
}

func (s *RouteService) GetRoute(id string) (*Route, error) {
    return s.repository.FindByID(id)
}

// Bad - 불일치
func (rs *RouteService) CreateRoute(route *Route) error {
    return rs.repository.Save(route)
}

func (service *RouteService) GetRoute(id string) (*Route, error) {
    return service.repository.FindByID(id)
}
```

## 3. 패키지 구조 규칙

### 3.1 Import 순서

**규칙:**
1. 표준 라이브러리
2. 외부 라이브러리
3. 내부 패키지

각 그룹은 빈 줄로 구분

```go
// Good
import (
    "context"
    "fmt"
    "time"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"

    "demo-abs/internal/domain/model"
    "demo-abs/internal/domain/service"
)

// Bad - 순서 섞임
import (
    "demo-abs/internal/domain/model"
    "fmt"
    "github.com/gin-gonic/gin"
    "context"
)
```

### 3.2 Import 별칭

**규칙:**
- 충돌 방지 목적으로만 사용
- 의미 있는 별칭 사용

```go
// Good
import (
    "database/sql"

    oracledb "demo-abs/internal/adapter/out/persistence/oracle"
)

// Bad - 불필요한 별칭
import (
    f "fmt"
    t "time"
)
```

## 4. 코드 구조

### 4.1 함수 크기

**규칙:**
- 한 함수는 한 가지 일만
- 50줄 이하 권장
- 복잡한 로직은 분리

```go
// Good
func (s *ComparisonService) ProcessComparison(ctx context.Context, req *ComparisonRequest) error {
    legacyResp, err := s.callLegacyAPI(ctx, req)
    if err != nil {
        return err
    }

    modernResp, err := s.callModernAPI(ctx, req)
    if err != nil {
        return err
    }

    result, err := s.compareResponses(legacyResp, modernResp)
    if err != nil {
        return err
    }

    return s.publishResult(ctx, result)
}

// Bad - 너무 긴 함수
func (s *ComparisonService) ProcessComparison(ctx context.Context, req *ComparisonRequest) error {
    // 200줄의 코드...
}
```

### 4.2 Early Return

**규칙:**
- Guard Clause 사용
- Happy Path는 들여쓰기 최소화

```go
// Good
func (s *RouteService) GetRoute(ctx context.Context, id string) (*Route, error) {
    if id == "" {
        return nil, errors.New("route id is required")
    }

    route, err := s.repository.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }

    return route, nil
}

// Bad
func (s *RouteService) GetRoute(ctx context.Context, id string) (*Route, error) {
    if id != "" {
        route, err := s.repository.FindByID(ctx, id)
        if err == nil {
            return route, nil
        } else {
            return nil, err
        }
    } else {
        return nil, errors.New("route id is required")
    }
}
```

## 5. 에러 처리

### 5.1 에러 반환

**규칙:**
- 에러는 마지막 반환값
- 에러 타입은 error 인터페이스
- Custom 에러는 명확한 이름

```go
// Good
func (s *RouteService) CreateRoute(ctx context.Context, route *Route) error {
    if err := s.validate(route); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    if err := s.repository.Save(ctx, route); err != nil {
        return fmt.Errorf("failed to save route: %w", err)
    }

    return nil
}

// Custom 에러
var (
    ErrRouteNotFound    = errors.New("route not found")
    ErrInvalidMatchRate = errors.New("invalid match rate")
)

func (s *RouteService) GetRoute(ctx context.Context, id string) (*Route, error) {
    route, err := s.repository.FindByID(ctx, id)
    if err == sql.ErrNoRows {
        return nil, ErrRouteNotFound
    }
    return route, err
}
```

### 5.2 에러 래핑

**규칙:**
- `fmt.Errorf`와 `%w` 사용
- 에러 체인 유지
- 컨텍스트 정보 추가

```go
// Good
func (s *ComparisonService) Compare(a, b []byte) (*Result, error) {
    result, err := s.comparator.Compare(a, b)
    if err != nil {
        return nil, fmt.Errorf("comparison failed: %w", err)
    }
    return result, nil
}

// 에러 체크
if errors.Is(err, ErrRouteNotFound) {
    // 특정 에러 처리
}

// Bad
func (s *ComparisonService) Compare(a, b []byte) (*Result, error) {
    result, err := s.comparator.Compare(a, b)
    if err != nil {
        return nil, errors.New("comparison failed")  // 원본 에러 손실
    }
    return result, nil
}
```

### 5.3 Panic 사용

**규칙:**
- 복구 불가능한 상황에만 사용
- 초기화 실패 시
- 라이브러리 코드에서는 금지

```go
// Good - 초기화 실패
func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatal("Failed to load config: ", err)  // Fatal은 panic + exit
    }

    // ...
}

// Bad - 비즈니스 로직에서 panic
func (s *RouteService) GetRoute(id string) *Route {
    route, err := s.repository.FindByID(id)
    if err != nil {
        panic(err)  // 절대 금지
    }
    return route
}
```

## 6. 주석 작성

### 6.1 패키지 주석

**규칙:**
- 패키지 설명은 package 위에
- 주요 기능 설명
- 사용 예시 (필요시)

```go
// Package service provides business logic implementation.
//
// This package contains core business services including:
//   - RouteService: Route management
//   - ComparisonService: Response comparison
//   - ExperimentService: Experiment management
//
// Example usage:
//
//	routeService := service.NewRouteService(repository)
//	route, err := routeService.GetRoute(ctx, "route-123")
package service
```

### 6.2 함수/메서드 주석

**규칙:**
- Exported 항목은 반드시 주석
- 함수명으로 시작
- 동작 설명

```go
// CreateRoute creates a new route and returns it.
// Returns ErrInvalidRoute if validation fails.
func (s *RouteService) CreateRoute(ctx context.Context, route *Route) (*Route, error) {
    // ...
}

// Private 함수는 필요시만
func (s *RouteService) validate(route *Route) error {
    // ...
}
```

### 6.3 구조체 주석

**규칙:**
- Exported 구조체는 반드시 주석
- 필드 설명 (필요시)

```go
// Route represents an API routing configuration.
type Route struct {
    // ID is the unique identifier of the route.
    ID string `json:"id"`

    // Path is the API endpoint path.
    Path string `json:"path"`

    // Method is the HTTP method (GET, POST, etc.).
    Method string `json:"method"`

    // OperationMode defines how the route operates.
    // Possible values: validation, canary, switched
    OperationMode OperationMode `json:"operation_mode"`

    matchRate float64  // unexported는 주석 선택
}
```

### 6.4 TODO 주석

**규칙:**
- TODO 주석 사용
- 책임자/날짜 명시 (선택)

```go
// TODO(username): Implement caching
// TODO: Add retry logic (by 2025-12-31)

func (s *RouteService) GetRoute(ctx context.Context, id string) (*Route, error) {
    // TODO: Add distributed lock
    return s.repository.FindByID(ctx, id)
}
```

## 7. 인터페이스 설계

### 7.1 인터페이스 크기

**규칙:**
- 작은 인터페이스 (1-3개 메서드)
- 필요한 메서드만 정의
- 사용하는 곳에서 정의

```go
// Good - 작은 인터페이스
type RouteRepository interface {
    FindByID(ctx context.Context, id string) (*Route, error)
    Save(ctx context.Context, route *Route) error
}

type RouteCache interface {
    Get(ctx context.Context, key string) (*Route, error)
    Set(ctx context.Context, key string, route *Route) error
}

// Bad - 너무 큰 인터페이스
type RouteManager interface {
    FindByID(ctx context.Context, id string) (*Route, error)
    Save(ctx context.Context, route *Route) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context) ([]*Route, error)
    Cache(ctx context.Context, route *Route) error
    Invalidate(ctx context.Context, id string) error
    // ... 10개 이상의 메서드
}
```

### 7.2 인터페이스 위치

**규칙:**
- 사용하는 패키지에 정의
- 제공하는 패키지가 아님

```go
// Good - domain/service에서 정의
package service

type RouteRepository interface {
    FindByID(ctx context.Context, id string) (*Route, error)
}

type RouteService struct {
    repository RouteRepository  // 인터페이스 사용
}

// adapter/persistence에서 구현
package persistence

type OracleRouteRepository struct {
    db *sql.DB
}

func (r *OracleRouteRepository) FindByID(ctx context.Context, id string) (*Route, error) {
    // 구현
}
```

## 8. Context 사용

### 8.1 Context 전달

**규칙:**
- 첫 번째 파라미터로 전달
- context.Background() 사용 금지 (main 제외)
- context.TODO() 임시로만 사용

```go
// Good
func (s *RouteService) CreateRoute(ctx context.Context, route *Route) error {
    return s.repository.Save(ctx, route)
}

// Bad
func (s *RouteService) CreateRoute(route *Route) error {
    ctx := context.Background()  // 금지
    return s.repository.Save(ctx, route)
}
```

### 8.2 Context 값 전달

**규칙:**
- Request-scoped 데이터만
- Type-safe key 사용

```go
// Good
type contextKey string

const (
    requestIDKey contextKey = "request_id"
    userIDKey    contextKey = "user_id"
)

func WithRequestID(ctx context.Context, requestID string) context.Context {
    return context.WithValue(ctx, requestIDKey, requestID)
}

func GetRequestID(ctx context.Context) string {
    if requestID, ok := ctx.Value(requestIDKey).(string); ok {
        return requestID
    }
    return ""
}

// Bad
func WithRequestID(ctx context.Context, requestID string) context.Context {
    return context.WithValue(ctx, "request_id", requestID)  // String key
}
```

## 9. 동시성

### 9.1 고루틴 시작

**규칙:**
- 명확한 종료 조건
- Context 사용
- WaitGroup 사용 (필요시)

```go
// Good
func (s *ComparisonService) ProcessAsync(ctx context.Context, comparisons []*Comparison) error {
    var wg sync.WaitGroup

    for _, cmp := range comparisons {
        wg.Add(1)
        go func(c *Comparison) {
            defer wg.Done()

            select {
            case <-ctx.Done():
                return
            default:
                s.process(ctx, c)
            }
        }(cmp)
    }

    wg.Wait()
    return nil
}

// Bad - 종료 조건 없음
func (s *ComparisonService) ProcessAsync(comparisons []*Comparison) {
    for _, cmp := range comparisons {
        go s.process(cmp)  // 언제 끝나는지 모름
    }
}
```

### 9.2 채널 사용

**규칙:**
- 버퍼 크기 명시
- Close는 생산자가
- Range로 수신

```go
// Good
func (s *ComparisonService) ProcessBatch(ctx context.Context, batch []*Comparison) error {
    results := make(chan *Result, len(batch))
    defer close(results)

    for _, cmp := range batch {
        go func(c *Comparison) {
            result := s.process(ctx, c)
            results <- result
        }(cmp)
    }

    for i := 0; i < len(batch); i++ {
        select {
        case result := <-results:
            s.handleResult(result)
        case <-ctx.Done():
            return ctx.Err()
        }
    }

    return nil
}
```

## 10. 테스트 코드

### 10.1 테스트 함수 네이밍

**규칙:**
- `Test` + 함수명
- 테이블 드리븐 테스트 사용

```go
// Good
func TestRouteService_CreateRoute(t *testing.T) {
    tests := []struct {
        name    string
        route   *Route
        wantErr bool
    }{
        {
            name:    "Valid route",
            route:   &Route{Path: "/api/test"},
            wantErr: false,
        },
        {
            name:    "Invalid route",
            route:   &Route{Path: ""},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            s := NewRouteService(mockRepo)
            err := s.CreateRoute(context.Background(), tt.route)
            if (err != nil) != tt.wantErr {
                t.Errorf("CreateRoute() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

## 11. 포맷팅

### 11.1 자동 포맷팅

**도구:**
- `gofmt`: 기본 포맷팅
- `goimports`: Import 자동 정리

```bash
# 전체 프로젝트 포맷팅
gofmt -s -w .

# Import 정리
goimports -w .
```

### 11.2 Linter

**도구:**
- `golangci-lint`: 통합 Linter

```yaml
# .golangci.yml
linters:
  enable:
    - gofmt
    - goimports
    - govet
    - errcheck
    - staticcheck
    - unused
    - gosimple
    - ineffassign
    - misspell

linters-settings:
  gofmt:
    simplify: true
  goimports:
    local-prefixes: demo-abs
```

```bash
# Lint 실행
golangci-lint run ./...
```

## 12. 베스트 프랙티스

### 12.1 제로값 활용

```go
// Good
var count int       // 0
var name string     // ""
var ready bool      // false
var items []string  // nil

// Bad
var count int = 0
var name string = ""
```

### 12.2 구조체 초기화

```go
// Good - 필드명 명시
route := &Route{
    ID:     "route-123",
    Path:   "/api/test",
    Method: "GET",
}

// Bad - 순서 의존
route := &Route{"route-123", "/api/test", "GET"}
```

### 12.3 슬라이스 초기화

```go
// Good - 용량 예상 가능
routes := make([]*Route, 0, 100)

// Good - 리터럴
statuses := []string{"pending", "completed", "failed"}

// Bad
var routes []*Route  // nil, append 시 재할당
```

## 13. 코드 리뷰 체크리스트

- [ ] 함수/메서드는 한 가지 일만 하는가?
- [ ] Early return 패턴 사용?
- [ ] 에러 처리가 적절한가?
- [ ] Context 전달이 올바른가?
- [ ] 고루틴 종료 조건이 명확한가?
- [ ] Exported 항목에 주석이 있는가?
- [ ] 테스트 코드가 작성되었는가?
- [ ] Import 순서가 올바른가?
- [ ] 네이밍이 일관성 있는가?
- [ ] gofmt, goimports 실행했는가?

## 14. 참고 자료

- Effective Go: https://go.dev/doc/effective_go
- Go Code Review Comments: https://github.com/golang/go/wiki/CodeReviewComments
- Uber Go Style Guide: https://github.com/uber-go/guide/blob/master/style.md
- Go Proverbs: https://go-proverbs.github.io/

---

최종 수정일: 2025-11-30, 작성자: ABS 개발팀
