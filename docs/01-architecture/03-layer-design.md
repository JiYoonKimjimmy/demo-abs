# 계층별 설계 및 책임

## 목차
1. [계층 구조 개요](#계층-구조-개요)
2. [Domain Layer](#domain-layer)
3. [Application Layer](#application-layer)
4. [Adapter Layer](#adapter-layer)
5. [Infrastructure Layer](#infrastructure-layer)
6. [계층 간 통신 규칙](#계층-간-통신-규칙)
7. [실전 예시](#실전-예시)

---

## 계층 구조 개요

### 의존성 방향

```
┌─────────────────────────────────────────┐
│      Infrastructure Layer               │
│  (Config, Logger, Monitoring)           │
└──────────────┬──────────────────────────┘
               │ uses
               ▼
┌─────────────────────────────────────────┐
│         Adapter Layer                   │
│  (HTTP, Repository, Cache, Client)      │
└──────────────┬──────────────────────────┘
               │ implements & calls
               ▼
┌─────────────────────────────────────────┐
│       Application Layer                 │
│         (Use Cases)                     │
└──────────────┬──────────────────────────┘
               │ uses
               ▼
┌─────────────────────────────────────────┐
│        Domain Layer                     │
│  (Entities, Services, Ports)            │
└─────────────────────────────────────────┘
         ↑
         │ 의존성 방향 (안쪽으로만)
```

### 계층별 안정성

- **Domain**: 가장 안정적 (변경 최소화)
- **Application**: 안정적 (Use Case 변경 시에만)
- **Adapter**: 불안정 (기술 스택 변경 가능)
- **Infrastructure**: 가장 불안정 (설정, 로깅 등 자주 변경)

---

## Domain Layer

### 위치
`internal/domain/`

### 책임

**핵심 비즈니스 로직 및 도메인 규칙 구현**

Domain Layer는 애플리케이션의 핵심으로, 비즈니스 문제를 해결하는 순수한 로직만 포함합니다.

### 구성 요소

#### 1. Model (`internal/domain/model/`)

**엔티티 (Entity)**:
- 고유 식별자를 가진 객체
- 생명주기 동안 속성이 변할 수 있음
- 예: `Route`, `Comparison`, `Experiment`

**Value Object**:
- 식별자가 없으며, 값 자체가 중요
- 불변(Immutable)
- 예: `APIRequest`, `APIResponse`, `MatchRate`

**예시**:
```go
// internal/domain/model/route.go
package model

import "time"

// Route 엔티티
type Route struct {
    ID              string
    Path            string
    Method          string
    LegacyURL       string
    ModernURL       string
    Mode            RouteMode    // 검증/Canary/전환
    MatchRate       float64
    SampleSize      int
    ExcludedFields  []string
    CreatedAt       time.Time
    UpdatedAt       time.Time
}

type RouteMode string

const (
    RouteModeValidation RouteMode = "validation"
    RouteModeCanary     RouteMode = "canary"
    RouteModeSwitched   RouteMode = "switched"
)

// 비즈니스 규칙: 모드 전환 가능 여부 검증
func (r *Route) CanSwitchToMode(newMode RouteMode) error {
    if r.Mode == RouteModeValidation && newMode == RouteModeSwitched {
        if r.MatchRate < 100.0 {
            return errors.New("match rate must be 100% to switch")
        }
    }
    return nil
}
```

**Value Object 예시**:
```go
// internal/domain/model/api_request.go
package model

type APIRequest struct {
    Method  string
    Path    string
    Headers map[string]string
    Body    []byte
}

// 불변성 보장: 새로운 객체 반환
func (req APIRequest) WithHeader(key, value string) APIRequest {
    newHeaders := make(map[string]string)
    for k, v := range req.Headers {
        newHeaders[k] = v
    }
    newHeaders[key] = value
    return APIRequest{
        Method:  req.Method,
        Path:    req.Path,
        Headers: newHeaders,
        Body:    req.Body,
    }
}
```

---

#### 2. Service (`internal/domain/service/`)

**도메인 서비스**:
- 단일 엔티티에 속하지 않는 비즈니스 로직
- 여러 엔티티를 조합하여 복잡한 규칙 구현

**예시**:
```go
// internal/domain/service/comparison_service.go
package service

type ComparisonService struct {}

func NewComparisonService() *ComparisonService {
    return &ComparisonService{}
}

// JSON 비교 로직 (순수 비즈니스 로직)
func (s *ComparisonService) Compare(legacy, modern []byte, excludeFields []string) (*ComparisonResult, error) {
    // 1. JSON 파싱
    // 2. 제외 필드 제거
    // 3. 재귀적 비교
    // 4. 일치율 계산
    return &ComparisonResult{
        IsMatch:       true,
        MatchRate:     100.0,
        Differences:   []Difference{},
    }, nil
}

type ComparisonResult struct {
    IsMatch     bool
    MatchRate   float64
    Differences []Difference
}

type Difference struct {
    Path     string
    Expected interface{}
    Actual   interface{}
}
```

**라우팅 서비스 예시**:
```go
// internal/domain/service/routing_service.go
package service

type RoutingService struct {}

func NewRoutingService() *RoutingService {
    return &RoutingService{}
}

// 라우팅 결정 로직
func (s *RoutingService) DetermineTarget(route *model.Route, requestID string) TargetAPI {
    switch route.Mode {
    case model.RouteModeValidation:
        return TargetLegacy
    case model.RouteModeCanary:
        // Canary 비율에 따라 결정 (해시 기반)
        if s.shouldUseModern(requestID, route.CanaryPercentage) {
            return TargetModern
        }
        return TargetLegacy
    case model.RouteModeSwitched:
        return TargetModern
    default:
        return TargetLegacy
    }
}

type TargetAPI int

const (
    TargetLegacy TargetAPI = iota
    TargetModern
)
```

---

#### 3. Port (`internal/domain/port/`)

**Port 인터페이스**:
- 외부 세계와의 경계를 정의
- Domain이 외부 시스템에 요구하는 계약

**Repository Port 예시**:
```go
// internal/domain/port/repository.go
package port

import (
    "context"
    "demo-abs/internal/domain/model"
)

type RouteRepository interface {
    Save(ctx context.Context, route *model.Route) error
    FindByID(ctx context.Context, id string) (*model.Route, error)
    FindByPath(ctx context.Context, path string) (*model.Route, error)
    FindAll(ctx context.Context) ([]*model.Route, error)
    Update(ctx context.Context, route *model.Route) error
    Delete(ctx context.Context, id string) error
}

type ComparisonRepository interface {
    Save(ctx context.Context, comparison *model.Comparison) error
    FindByRouteID(ctx context.Context, routeID string, limit int) ([]*model.Comparison, error)
    CountByRouteID(ctx context.Context, routeID string) (int, error)
}
```

**Cache Port 예시**:
```go
// internal/domain/port/cache.go
package port

import (
    "context"
    "time"
)

type CacheStore interface {
    Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error
    Get(ctx context.Context, key string) (interface{}, error)
    Delete(ctx context.Context, key string) error
    Exists(ctx context.Context, key string) (bool, error)
}
```

**API Client Port 예시**:
```go
// internal/domain/port/api_client.go
package port

import (
    "context"
    "demo-abs/internal/domain/model"
)

type APIClient interface {
    Call(ctx context.Context, req *model.APIRequest) (*model.APIResponse, error)
}

type LegacyAPIClient interface {
    APIClient
}

type ModernAPIClient interface {
    APIClient
}
```

### Domain Layer 원칙

1. **외부 의존성 금지**: 표준 라이브러리만 사용
2. **순수 함수 지향**: 부수 효과(Side Effect) 최소화
3. **비즈니스 언어 사용**: 도메인 전문가가 이해할 수 있는 용어
4. **테스트 용이성**: 외부 의존성 없이 단위 테스트 가능

---

## Application Layer

### 위치
`internal/application/`

### 책임

**유스케이스 오케스트레이션 및 트랜잭션 관리**

Application Layer는 Domain의 비즈니스 로직을 조합하여 특정 사용 사례를 구현합니다.

### 구성 요소

#### 1. UseCase (`internal/application/usecase/`)

**UseCase 특징**:
- 하나의 비즈니스 흐름을 구현
- Domain Service와 Port를 조합
- 트랜잭션 경계 정의

**예시**:
```go
// internal/application/usecase/route_usecase.go
package usecase

import (
    "context"
    "demo-abs/internal/domain/model"
    "demo-abs/internal/domain/port"
    "demo-abs/internal/domain/service"
)

type RouteUseCase struct {
    routeRepo       port.RouteRepository
    cache           port.CacheStore
    routingService  *service.RoutingService
}

func NewRouteUseCase(
    routeRepo port.RouteRepository,
    cache port.CacheStore,
    routingService *service.RoutingService,
) *RouteUseCase {
    return &RouteUseCase{
        routeRepo:      routeRepo,
        cache:          cache,
        routingService: routingService,
    }
}

// CreateRoute 유스케이스
func (uc *RouteUseCase) CreateRoute(ctx context.Context, req CreateRouteRequest) (*model.Route, error) {
    // 1. DTO → Domain Model 변환
    route := &model.Route{
        ID:             generateID(),
        Path:           req.Path,
        Method:         req.Method,
        LegacyURL:      req.LegacyURL,
        ModernURL:      req.ModernURL,
        Mode:           model.RouteModeValidation,
        ExcludedFields: req.ExcludedFields,
    }

    // 2. 비즈니스 규칙 검증 (Domain Service)
    if err := uc.validateRoute(route); err != nil {
        return nil, err
    }

    // 3. 영속화 (Repository)
    if err := uc.routeRepo.Save(ctx, route); err != nil {
        return nil, err
    }

    // 4. 캐시 무효화
    cacheKey := fmt.Sprintf("route:%s", route.Path)
    _ = uc.cache.Delete(ctx, cacheKey)

    return route, nil
}

// SwitchRouteMode 유스케이스
func (uc *RouteUseCase) SwitchRouteMode(ctx context.Context, routeID string, newMode model.RouteMode) error {
    // 1. 조회
    route, err := uc.routeRepo.FindByID(ctx, routeID)
    if err != nil {
        return err
    }

    // 2. 비즈니스 규칙 검증
    if err := route.CanSwitchToMode(newMode); err != nil {
        return err
    }

    // 3. 상태 변경
    route.Mode = newMode
    route.UpdatedAt = time.Now()

    // 4. 저장
    if err := uc.routeRepo.Update(ctx, route); err != nil {
        return err
    }

    return nil
}
```

#### 2. DTO (`internal/application/dto/`)

**DTO (Data Transfer Object)**:
- HTTP 요청/응답과 Domain Model 분리
- 외부 인터페이스 변경 시 Domain 영향 최소화

**예시**:
```go
// internal/application/dto/route_dto.go
package dto

type CreateRouteRequest struct {
    Path           string   `json:"path" validate:"required"`
    Method         string   `json:"method" validate:"required"`
    LegacyURL      string   `json:"legacy_url" validate:"required,url"`
    ModernURL      string   `json:"modern_url" validate:"required,url"`
    ExcludedFields []string `json:"excluded_fields"`
}

type RouteResponse struct {
    ID             string   `json:"id"`
    Path           string   `json:"path"`
    Method         string   `json:"method"`
    Mode           string   `json:"mode"`
    MatchRate      float64  `json:"match_rate"`
    SampleSize     int      `json:"sample_size"`
    ExcludedFields []string `json:"excluded_fields"`
}

// Domain Model → DTO 변환
func ToRouteResponse(route *model.Route) *RouteResponse {
    return &RouteResponse{
        ID:             route.ID,
        Path:           route.Path,
        Method:         route.Method,
        Mode:           string(route.Mode),
        MatchRate:      route.MatchRate,
        SampleSize:     route.SampleSize,
        ExcludedFields: route.ExcludedFields,
    }
}
```

### Application Layer 원칙

1. **UseCase는 독립적**: 각 UseCase는 서로 호출하지 않음
2. **트랜잭션 경계**: UseCase 메서드가 트랜잭션 단위
3. **DTO 사용**: Domain Model을 외부에 직접 노출하지 않음
4. **Port에만 의존**: 구체적인 구현(Adapter)을 모름

---

## Adapter Layer

### 위치
`internal/adapter/`

### 책임

**외부 시스템과의 연동 (Port 인터페이스 구현)**

Adapter Layer는 Domain/Application이 정의한 Port를 실제 기술로 구현합니다.

### 구성 요소

#### 1. Inbound Adapter (`internal/adapter/in/`)

**HTTP Handler 예시**:
```go
// internal/adapter/in/http/handler/route_handler.go
package handler

import (
    "net/http"
    "github.com/gin-gonic/gin"
    "demo-abs/internal/application/usecase"
    "demo-abs/internal/application/dto"
)

type RouteHandler struct {
    routeUseCase *usecase.RouteUseCase
}

func NewRouteHandler(routeUseCase *usecase.RouteUseCase) *RouteHandler {
    return &RouteHandler{routeUseCase: routeUseCase}
}

func (h *RouteHandler) CreateRoute(c *gin.Context) {
    var req dto.CreateRouteRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    route, err := h.routeUseCase.CreateRoute(c.Request.Context(), req)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusCreated, dto.ToRouteResponse(route))
}
```

#### 2. Outbound Adapter (`internal/adapter/out/`)

**Repository 구현 예시**:
```go
// internal/adapter/out/persistence/oracle/route_repository.go
package oracle

import (
    "context"
    "gorm.io/gorm"
    "demo-abs/internal/domain/model"
    "demo-abs/internal/domain/port"
)

type OracleRouteRepository struct {
    db *gorm.DB
}

func NewOracleRouteRepository(db *gorm.DB) port.RouteRepository {
    return &OracleRouteRepository{db: db}
}

func (r *OracleRouteRepository) Save(ctx context.Context, route *model.Route) error {
    entity := toRouteEntity(route)
    return r.db.WithContext(ctx).Create(entity).Error
}

func (r *OracleRouteRepository) FindByID(ctx context.Context, id string) (*model.Route, error) {
    var entity RouteEntity
    if err := r.db.WithContext(ctx).Where("id = ?", id).First(&entity).Error; err != nil {
        return nil, err
    }
    return toRouteModel(&entity), nil
}

// DB Entity (ORM 매핑)
type RouteEntity struct {
    ID             string `gorm:"primaryKey"`
    Path           string `gorm:"index"`
    Method         string
    LegacyURL      string
    ModernURL      string
    Mode           string
    MatchRate      float64
    SampleSize     int
    ExcludedFields string // JSON 직렬화
    CreatedAt      time.Time
    UpdatedAt      time.Time
}

func (RouteEntity) TableName() string {
    return "routes"
}
```

**Cache 구현 예시**:
```go
// internal/adapter/out/cache/redis_cache.go
package cache

import (
    "context"
    "encoding/json"
    "github.com/go-redis/redis/v8"
    "demo-abs/internal/domain/port"
)

type RedisCache struct {
    client *redis.Client
}

func NewRedisCache(client *redis.Client) port.CacheStore {
    return &RedisCache{client: client}
}

func (c *RedisCache) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
    data, err := json.Marshal(value)
    if err != nil {
        return err
    }
    return c.client.Set(ctx, key, data, ttl).Err()
}

func (c *RedisCache) Get(ctx context.Context, key string) (interface{}, error) {
    data, err := c.client.Get(ctx, key).Bytes()
    if err != nil {
        return nil, err
    }
    var result interface{}
    if err := json.Unmarshal(data, &result); err != nil {
        return nil, err
    }
    return result, nil
}
```

### Adapter Layer 원칙

1. **Port 구현**: Domain의 Port 인터페이스를 충실히 구현
2. **기술 세부사항 캡슐화**: ORM, HTTP 프레임워크 등 기술 선택을 숨김
3. **에러 변환**: 기술 스택 고유 에러를 Domain 에러로 변환
4. **독립적 테스트**: 각 Adapter는 독립적으로 통합 테스트 가능

---

## Infrastructure Layer

### 위치
`internal/infrastructure/`

### 책임

**애플리케이션 전반에 걸친 공통 기능 제공**

### 구성 요소

#### 1. Config (`internal/infrastructure/config/`)

```go
// internal/infrastructure/config/config.go
package config

type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    RabbitMQ RabbitMQConfig
}

type ServerConfig struct {
    Port            int
    ReadTimeout     time.Duration
    WriteTimeout    time.Duration
    ShutdownTimeout time.Duration
}

func Load() (*Config, error) {
    // 환경변수 또는 YAML 파일에서 로딩
    return &Config{}, nil
}
```

#### 2. Logger (`internal/infrastructure/logger/`)

```go
// internal/infrastructure/logger/logger.go
package logger

import "go.uber.org/zap"

type Logger interface {
    Info(msg string, fields ...zap.Field)
    Error(msg string, fields ...zap.Field)
    Debug(msg string, fields ...zap.Field)
}

func NewZapLogger() (Logger, error) {
    return zap.NewProduction()
}
```

### Infrastructure Layer 원칙

1. **모든 계층에서 사용 가능**: 횡단 관심사(Cross-cutting Concern)
2. **설정 중앙화**: 모든 설정을 한 곳에서 관리
3. **변경 빈도 높음**: 가장 불안정한 계층

---

## 계층 간 통신 규칙

### 허용되는 통신

```
✅ Handler → UseCase
✅ UseCase → Domain Service
✅ UseCase → Port (Interface)
✅ Adapter → Port (구현)
✅ 모든 계층 → Infrastructure
```

### 금지되는 통신

```
❌ Handler → Domain Service (UseCase 우회)
❌ Domain → Adapter
❌ Domain → Application
❌ UseCase → UseCase (서로 호출)
```

---

## 실전 예시

### 프록시 요청 처리 흐름

```
1. HTTP Request
   ↓
2. RouteHandler (Adapter/In)
   - 요청 파싱
   - DTO 생성
   ↓
3. ProxyUseCase (Application)
   - Route 조회 (RouteRepository)
   - 라우팅 결정 (RoutingService)
   - Legacy/Modern API 호출 (APIClient)
   - 응답 비교 (ComparisonService)
   - 비교 결과 저장 (ComparisonRepository)
   ↓
4. Response 반환
```

**코드 흐름**:
```go
// 1. Handler (Adapter)
func (h *ProxyHandler) HandleRequest(c *gin.Context) {
    req := parseRequest(c)
    resp, err := h.proxyUseCase.Process(c.Request.Context(), req)
    c.JSON(http.StatusOK, resp)
}

// 2. UseCase (Application)
func (uc *ProxyUseCase) Process(ctx context.Context, req ProxyRequest) (*ProxyResponse, error) {
    // 2.1 조회
    route, _ := uc.routeRepo.FindByPath(ctx, req.Path)

    // 2.2 라우팅 결정 (Domain Service)
    target := uc.routingService.DetermineTarget(route, req.ID)

    // 2.3 API 호출 (Port)
    legacyResp, _ := uc.legacyClient.Call(ctx, req.ToAPIRequest())
    modernResp, _ := uc.modernClient.Call(ctx, req.ToAPIRequest())

    // 2.4 비교 (Domain Service)
    result, _ := uc.comparisonService.Compare(legacyResp.Body, modernResp.Body, route.ExcludedFields)

    // 2.5 저장
    uc.comparisonRepo.Save(ctx, toComparison(result))

    // 2.6 응답 선택
    if target == service.TargetLegacy {
        return legacyResp, nil
    }
    return modernResp, nil
}
```

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
