# 의존성 주입 전략

## 목차
1. [의존성 주입 개요](#의존성-주입-개요)
2. [DI 방식 선택](#di-방식-선택)
3. [수동 DI 구현](#수동-di-구현)
4. [초기화 순서](#초기화-순서)
5. [생명주기 관리](#생명주기-관리)
6. [테스트에서의 DI](#테스트에서의-di)

---

## 의존성 주입 개요

### 의존성 주입(Dependency Injection)이란?

객체가 필요로 하는 의존성을 외부에서 주입받는 패턴입니다.

**Before (의존성 직접 생성)**:
```go
type UserService struct {
    repo UserRepository
}

func NewUserService() *UserService {
    return &UserService{
        repo: NewMySQLUserRepository(), // ❌ 구체적 구현에 직접 의존
    }
}
```

**After (의존성 주입)**:
```go
type UserService struct {
    repo UserRepository // 인터페이스에 의존
}

func NewUserService(repo UserRepository) *UserService {
    return &UserService{
        repo: repo, // ✅ 외부에서 주입
    }
}
```

### DI의 장점

1. **테스트 용이성**: Mock 객체 주입으로 단위 테스트 가능
2. **느슨한 결합**: 구현체 변경 시 영향 최소화
3. **유연성**: 런타임에 다른 구현체 사용 가능
4. **명확한 의존성**: 생성자에서 의존성이 명시적으로 드러남

---

## DI 방식 선택

Go에서 DI를 구현하는 방법은 크게 3가지입니다.

### 1. 수동 DI (Manual Dependency Injection)

**특징**:
- 명시적으로 의존성을 생성하고 주입
- 추가 라이브러리 불필요
- 코드가 길어질 수 있음

**장점**:
- 학습 곡선 낮음
- 디버깅 용이
- 빌드 타임에 모든 의존성 검증

**단점**:
- 의존성이 많아지면 코드가 복잡해짐
- 수동으로 생명주기 관리

### 2. Wire (컴파일 타임 DI)

**특징**:
- Google이 만든 코드 생성 기반 DI 도구
- 컴파일 타임에 의존성 그래프 검증
- 생성된 코드를 Git에 커밋

**장점**:
- 컴파일 타임에 순환 참조 감지
- 런타임 오버헤드 없음
- 명시적 의존성 그래프

**단점**:
- 코드 생성 단계 필요
- 러닝 커브 존재

### 3. Dig/Fx (런타임 DI)

**특징**:
- Uber가 만든 리플렉션 기반 DI 프레임워크
- 런타임에 의존성 주입

**장점**:
- 동적 의존성 주입 가능

**단점**:
- 런타임 오버헤드
- 컴파일 타임에 에러 감지 불가
- 리플렉션 사용으로 디버깅 어려움

### ABS 선택: 수동 DI

**이유**:
1. **명확성**: 모든 의존성이 코드에서 명시적으로 보임
2. **단순성**: 추가 도구 없이 순수 Go로 구현
3. **디버깅**: 스택 트레이스가 명확
4. **학습**: 팀원 모두가 쉽게 이해 가능

ABS는 의존성 개수가 관리 가능한 수준이므로 수동 DI로 충분합니다.

---

## 수동 DI 구현

### 기본 패턴

#### 1. 생성자 주입 (Constructor Injection)

Go에서 권장되는 방식입니다.

```go
type RouteUseCase struct {
    routeRepo      port.RouteRepository
    cache          port.CacheStore
    routingService *service.RoutingService
    logger         logger.Logger
}

func NewRouteUseCase(
    routeRepo port.RouteRepository,
    cache port.CacheStore,
    routingService *service.RoutingService,
    logger logger.Logger,
) *RouteUseCase {
    return &RouteUseCase{
        routeRepo:      routeRepo,
        cache:          cache,
        routingService: routingService,
        logger:         logger,
    }
}
```

**장점**:
- 필수 의존성이 명확
- Immutable 객체 생성
- nil 체크 불필요

#### 2. 옵션 패턴 (Functional Options)

선택적 의존성이 많을 때 사용합니다.

```go
type HTTPClient struct {
    timeout        time.Duration
    retryCount     int
    circuitBreaker *circuitbreaker.Breaker
}

type HTTPClientOption func(*HTTPClient)

func WithTimeout(timeout time.Duration) HTTPClientOption {
    return func(c *HTTPClient) {
        c.timeout = timeout
    }
}

func WithRetry(count int) HTTPClientOption {
    return func(c *HTTPClient) {
        c.retryCount = count
    }
}

func NewHTTPClient(opts ...HTTPClientOption) *HTTPClient {
    // 기본값 설정
    client := &HTTPClient{
        timeout:    30 * time.Second,
        retryCount: 3,
    }

    // 옵션 적용
    for _, opt := range opts {
        opt(client)
    }

    return client
}

// 사용 예시
client := NewHTTPClient(
    WithTimeout(60 * time.Second),
    WithRetry(5),
)
```

### DI Container 구현

`cmd/abs/main.go`에서 모든 의존성을 조립합니다.

```go
// cmd/abs/main.go
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"

    "demo-abs/internal/adapter/in/http/handler"
    "demo-abs/internal/adapter/out/cache"
    "demo-abs/internal/adapter/out/persistence/oracle"
    "demo-abs/internal/application/usecase"
    "demo-abs/internal/domain/service"
    "demo-abs/internal/infrastructure/config"
    "demo-abs/internal/infrastructure/logger"
)

func main() {
    // 1. Config 로딩
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }

    // 2. Logger 초기화
    appLogger, err := logger.NewZapLogger()
    if err != nil {
        log.Fatalf("Failed to initialize logger: %v", err)
    }

    // 3. 외부 시스템 연결 초기화
    container := initializeContainer(cfg, appLogger)
    defer container.Close()

    // 4. HTTP Server 시작
    router := setupRouter(container)
    srv := startServer(cfg, router)

    // 5. Graceful Shutdown
    gracefulShutdown(srv, container)
}

// Container는 모든 의존성을 담는 구조체
type Container struct {
    // Infrastructure
    Config *config.Config
    Logger logger.Logger
    DB     *gorm.DB
    Cache  cache.RedisClient

    // Domain Services
    ComparisonService *service.ComparisonService
    RoutingService    *service.RoutingService

    // Repositories
    RouteRepo      port.RouteRepository
    ComparisonRepo port.ComparisonRepository

    // Use Cases
    RouteUseCase *usecase.RouteUseCase
    ProxyUseCase *usecase.ProxyUseCase

    // Handlers
    RouteHandler *handler.RouteHandler
    ProxyHandler *handler.ProxyHandler
}

func initializeContainer(cfg *config.Config, logger logger.Logger) *Container {
    // Infrastructure 계층
    db := initDatabase(cfg)
    redisClient := initRedis(cfg)
    cacheStore := cache.NewRedisCache(redisClient)

    // Domain Services
    comparisonService := service.NewComparisonService()
    routingService := service.NewRoutingService()

    // Adapters - Repositories
    routeRepo := oracle.NewOracleRouteRepository(db)
    comparisonRepo := oracle.NewOracleComparisonRepository(db)

    // Adapters - HTTP Clients
    legacyClient := httpclient.NewLegacyClient(cfg.Legacy.BaseURL)
    modernClient := httpclient.NewModernClient(cfg.Modern.BaseURL)

    // Application - Use Cases
    routeUseCase := usecase.NewRouteUseCase(
        routeRepo,
        cacheStore,
        routingService,
        logger,
    )

    proxyUseCase := usecase.NewProxyUseCase(
        routeRepo,
        comparisonRepo,
        legacyClient,
        modernClient,
        comparisonService,
        routingService,
        logger,
    )

    // Adapters - Handlers
    routeHandler := handler.NewRouteHandler(routeUseCase)
    proxyHandler := handler.NewProxyHandler(proxyUseCase)

    return &Container{
        Config:            cfg,
        Logger:            logger,
        DB:                db,
        Cache:             redisClient,
        ComparisonService: comparisonService,
        RoutingService:    routingService,
        RouteRepo:         routeRepo,
        ComparisonRepo:    comparisonRepo,
        RouteUseCase:      routeUseCase,
        ProxyUseCase:      proxyUseCase,
        RouteHandler:      routeHandler,
        ProxyHandler:      proxyHandler,
    }
}

func (c *Container) Close() {
    // 리소스 정리
    if c.DB != nil {
        sqlDB, _ := c.DB.DB()
        sqlDB.Close()
    }
    if c.Cache != nil {
        c.Cache.Close()
    }
}

func initDatabase(cfg *config.Config) *gorm.DB {
    dsn := cfg.Database.DSN()
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    return db
}

func initRedis(cfg *config.Config) *redis.Client {
    client := redis.NewClient(&redis.Options{
        Addr:     cfg.Redis.Addr,
        Password: cfg.Redis.Password,
        DB:       cfg.Redis.DB,
    })

    if err := client.Ping(context.Background()).Err(); err != nil {
        log.Fatalf("Failed to connect to Redis: %v", err)
    }

    return client
}

func setupRouter(c *Container) *gin.Engine {
    router := gin.New()

    // Middleware
    router.Use(gin.Recovery())
    router.Use(middleware.LoggerMiddleware(c.Logger))

    // Health Check
    router.GET("/abs/health/live", func(ctx *gin.Context) {
        ctx.JSON(200, gin.H{"status": "ok"})
    })

    router.GET("/abs/health/ready", func(ctx *gin.Context) {
        // DB, Redis 등 연결 확인
        ctx.JSON(200, gin.H{"status": "ready"})
    })

    // API Routes
    v1 := router.Group("/abs/api/v1")
    {
        routes := v1.Group("/routes")
        {
            routes.POST("", c.RouteHandler.CreateRoute)
            routes.GET("", c.RouteHandler.ListRoutes)
            routes.GET("/:id", c.RouteHandler.GetRoute)
            routes.PUT("/:id", c.RouteHandler.UpdateRoute)
            routes.DELETE("/:id", c.RouteHandler.DeleteRoute)
        }
    }

    // Proxy (모든 다른 요청)
    router.NoRoute(c.ProxyHandler.HandleRequest)

    return router
}

func startServer(cfg *config.Config, router *gin.Engine) *http.Server {
    srv := &http.Server{
        Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
        Handler:      router,
        ReadTimeout:  cfg.Server.ReadTimeout,
        WriteTimeout: cfg.Server.WriteTimeout,
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server failed: %v", err)
        }
    }()

    log.Printf("Server started on port %d", cfg.Server.Port)
    return srv
}

func gracefulShutdown(srv *http.Server, container *Container) {
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Printf("Server forced to shutdown: %v", err)
    }

    container.Close()
    log.Println("Server exited")
}
```

---

## 초기화 순서

### 의존성 그래프

```
Config
  └─→ Logger
       └─→ Database
            └─→ Repository
                 └─→ Domain Service
                      └─→ UseCase
                           └─→ Handler
```

### 초기화 순서 원칙

1. **Infrastructure 먼저**: Config, Logger
2. **외부 연결**: Database, Redis, RabbitMQ
3. **Domain Services**: 비즈니스 로직 (의존성 없음)
4. **Repositories**: Port 구현체
5. **Use Cases**: Domain + Port 조합
6. **Handlers**: UseCase 사용

**잘못된 순서 예시**:
```go
// ❌ UseCase를 먼저 생성하고 Repository를 나중에 주입
useCase := &RouteUseCase{}
repo := NewRepository(db)
useCase.repo = repo // 생성 후 수정은 지양
```

**올바른 순서**:
```go
// ✅ Repository를 먼저 생성 후 UseCase에 주입
repo := NewRepository(db)
useCase := NewRouteUseCase(repo)
```

---

## 생명주기 관리

### 싱글톤 (Singleton)

**애플리케이션 전체에서 하나의 인스턴스만 사용**

- Config
- Logger
- Database Connection Pool
- Redis Client
- Domain Services (상태 없음)

```go
// 싱글톤 인스턴스
var (
    appLogger logger.Logger
    dbConn    *gorm.DB
)

func main() {
    appLogger = logger.NewZapLogger()
    dbConn = initDatabase(cfg)
    // 모든 곳에서 동일한 인스턴스 사용
}
```

### 요청별 인스턴스 (Per-Request)

**HTTP 요청마다 새로운 인스턴스 생성**

- Context (요청 컨텍스트)
- DTO (요청/응답 데이터)

```go
func (h *RouteHandler) CreateRoute(c *gin.Context) {
    // 요청마다 새로운 DTO 생성
    var req dto.CreateRouteRequest
    c.ShouldBindJSON(&req)

    // 요청 컨텍스트 전달
    route, err := h.useCase.CreateRoute(c.Request.Context(), req)
}
```

### 리소스 정리

**Close 패턴**:
```go
type Container struct {
    DB    *gorm.DB
    Cache *redis.Client
}

func (c *Container) Close() error {
    var errs []error

    if c.DB != nil {
        sqlDB, _ := c.DB.DB()
        if err := sqlDB.Close(); err != nil {
            errs = append(errs, err)
        }
    }

    if c.Cache != nil {
        if err := c.Cache.Close(); err != nil {
            errs = append(errs, err)
        }
    }

    if len(errs) > 0 {
        return fmt.Errorf("close errors: %v", errs)
    }
    return nil
}
```

---

## 테스트에서의 DI

### Mock을 사용한 단위 테스트

**UseCase 테스트 예시**:
```go
// test/unit/application/route_usecase_test.go
package application_test

import (
    "context"
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"

    "demo-abs/internal/application/usecase"
    "demo-abs/internal/domain/model"
    "demo-abs/test/mocks"
)

func TestRouteUseCase_CreateRoute(t *testing.T) {
    // Mock Repository 생성
    mockRepo := new(mocks.MockRouteRepository)
    mockCache := new(mocks.MockCacheStore)
    routingService := service.NewRoutingService()
    mockLogger := new(mocks.MockLogger)

    // UseCase 생성 (Mock 주입)
    useCase := usecase.NewRouteUseCase(
        mockRepo,
        mockCache,
        routingService,
        mockLogger,
    )

    // Mock 동작 정의
    mockRepo.On("Save", mock.Anything, mock.AnythingOfType("*model.Route")).
        Return(nil)
    mockCache.On("Delete", mock.Anything, mock.Anything).
        Return(nil)

    // 테스트 실행
    req := dto.CreateRouteRequest{
        Path:      "/api/v1/users",
        Method:    "GET",
        LegacyURL: "http://legacy:8080",
        ModernURL: "http://modern:9080",
    }

    route, err := useCase.CreateRoute(context.Background(), req)

    // 검증
    assert.NoError(t, err)
    assert.NotNil(t, route)
    mockRepo.AssertExpectations(t)
    mockCache.AssertExpectations(t)
}
```

**Mock 생성 (testify/mock)**:
```go
// test/mocks/repository_mock.go
package mocks

import (
    "context"
    "github.com/stretchr/testify/mock"
    "demo-abs/internal/domain/model"
)

type MockRouteRepository struct {
    mock.Mock
}

func (m *MockRouteRepository) Save(ctx context.Context, route *model.Route) error {
    args := m.Called(ctx, route)
    return args.Error(0)
}

func (m *MockRouteRepository) FindByID(ctx context.Context, id string) (*model.Route, error) {
    args := m.Called(ctx, id)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*model.Route), args.Error(1)
}
```

### 통합 테스트에서의 DI

**실제 DB를 사용한 테스트**:
```go
// test/integration/repository_test.go
package integration_test

import (
    "context"
    "testing"

    "demo-abs/internal/adapter/out/persistence/oracle"
    "demo-abs/test/testutil"
)

func TestOracleRouteRepository_Save(t *testing.T) {
    // 테스트 DB 연결
    db := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, db)

    // 실제 Repository 생성
    repo := oracle.NewOracleRouteRepository(db)

    // 테스트 실행
    route := &model.Route{
        ID:     "test-1",
        Path:   "/api/v1/users",
        Method: "GET",
    }

    err := repo.Save(context.Background(), route)
    assert.NoError(t, err)

    // 조회로 검증
    found, err := repo.FindByID(context.Background(), "test-1")
    assert.NoError(t, err)
    assert.Equal(t, route.Path, found.Path)
}
```

---

## DI 체크리스트

### 설계 단계
- [ ] 모든 의존성이 인터페이스(Port)로 추상화되었는가?
- [ ] 생성자에 필수 의존성이 모두 명시되었는가?
- [ ] 순환 의존성이 없는가?

### 구현 단계
- [ ] `main.go`에서 의존성 초기화 순서가 올바른가?
- [ ] 모든 리소스가 `Close()`에서 정리되는가?
- [ ] Graceful Shutdown이 구현되었는가?

### 테스트 단계
- [ ] 모든 Port에 대한 Mock이 작성되었는가?
- [ ] UseCase 단위 테스트에서 Mock을 주입하는가?
- [ ] 통합 테스트에서 실제 구현체를 사용하는가?

---

## 참고 자료

- [Dependency Injection in Go](https://blog.drewolson.org/dependency-injection-in-go)
- [Functional Options Pattern](https://dave.cheney.net/2014/10/17/functional-options-for-friendly-apis)
- [Google Wire](https://github.com/google/wire)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
