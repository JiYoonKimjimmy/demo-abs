# 03. Health Check 설계

## 1. 문서 개요

본 문서는 ABS의 Health Check 시스템 설계와 구현 방법을 정의합니다.

### 1.1 포함 내용

- Liveness Probe (생존 확인)
- Readiness Probe (준비 상태 확인)
- Startup Probe (시작 확인)
- Dependency Health Check
- Health Check 엔드포인트
- Load Balancer 연동

### 1.2 Health Check 아키텍처

```mermaid
graph TD
    A[Load Balancer] -->|HTTP GET| B[/health]
    A -->|HTTP GET| C[/health/live]
    A -->|HTTP GET| D[/health/ready]

    B --> E{전체 상태}
    C --> F{Liveness}
    D --> G{Readiness}

    E --> H[DB Check]
    E --> I[Redis Check]
    E --> J[RabbitMQ Check]

    F --> K[프로세스 실행]
    F --> L[고루틴 정상]

    G --> M[의존성 Ready]
    G --> N[초기화 완료]

    H --> O{결과}
    I --> O
    J --> O

    O -->|모두 OK| P[200 OK]
    O -->|하나라도 실패| Q[503 Service Unavailable]

    style P fill:#99ff99
    style Q fill:#ff9999
```

## 2. Health Check 타입

### 2.1 타입별 비교

| 타입 | 목적 | 실패 시 조치 | 확인 주기 | 타임아웃 |
|------|------|------------|---------|---------|
| Liveness | 프로세스 살아있음 | 프로세스 재시작 | 30s | 5s |
| Readiness | 트래픽 처리 가능 | 트래픽 제외 | 10s | 3s |
| Startup | 초기화 완료 | 시작 실패 | 5s | 10s |

### 2.2 Health Check 상태

```go
package health

// Status Health Check 상태
type Status string

const (
    StatusHealthy   Status = "healthy"   // 정상
    StatusDegraded  Status = "degraded"  // 저하 (일부 기능 제한)
    StatusUnhealthy Status = "unhealthy" // 비정상
)

// CheckResult Health Check 결과
type CheckResult struct {
    Status      Status                 `json:"status"`
    Timestamp   string                 `json:"timestamp"`
    Checks      map[string]CheckDetail `json:"checks"`
    Version     string                 `json:"version"`
    Uptime      string                 `json:"uptime"`
}

// CheckDetail 개별 체크 상세
type CheckDetail struct {
    Status    Status        `json:"status"`
    Message   string        `json:"message,omitempty"`
    Duration  string        `json:"duration"`
    Error     string        `json:"error,omitempty"`
}
```

## 3. Liveness Probe

### 3.1 Liveness Probe 개념

Liveness Probe는 애플리케이션이 **살아있는지** 확인합니다. 실패 시 프로세스를 재시작해야 합니다.

**확인 항목:**
- 프로세스가 실행 중인가?
- 데드락 상태가 아닌가?
- 고루틴이 정상적으로 동작하는가?

### 3.2 Liveness Probe 구현

```go
package health

import (
    "net/http"
    "runtime"
    "time"

    "github.com/gin-gonic/gin"
)

var (
    startTime = time.Now()
)

// LivenessHandler Liveness Probe 핸들러
func LivenessHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        checks := make(map[string]CheckDetail)

        // 1. 고루틴 수 확인
        goroutineCheck := checkGoroutines()
        checks["goroutines"] = goroutineCheck

        // 2. 메모리 확인
        memoryCheck := checkMemory()
        checks["memory"] = memoryCheck

        // 전체 상태 결정
        status := StatusHealthy
        for _, check := range checks {
            if check.Status == StatusUnhealthy {
                status = StatusUnhealthy
                break
            }
        }

        result := CheckResult{
            Status:    status,
            Timestamp: time.Now().Format(time.RFC3339),
            Checks:    checks,
            Version:   getVersion(),
            Uptime:    time.Since(startTime).String(),
        }

        statusCode := http.StatusOK
        if status == StatusUnhealthy {
            statusCode = http.StatusServiceUnavailable
        }

        c.JSON(statusCode, result)
    }
}

// checkGoroutines 고루틴 수 확인
func checkGoroutines() CheckDetail {
    start := time.Now()
    count := runtime.NumGoroutine()

    status := StatusHealthy
    message := "Normal"

    // 10,000개 이상이면 경고
    if count > 10000 {
        status = StatusDegraded
        message = "High goroutine count"
    }

    // 50,000개 이상이면 비정상
    if count > 50000 {
        status = StatusUnhealthy
        message = "Critical goroutine count"
    }

    return CheckDetail{
        Status:   status,
        Message:  message,
        Duration: time.Since(start).String(),
    }
}

// checkMemory 메모리 사용량 확인
func checkMemory() CheckDetail {
    start := time.Now()

    var m runtime.MemStats
    runtime.ReadMemStats(&m)

    status := StatusHealthy
    message := "Normal"

    // 메모리 사용량이 80% 이상이면 경고
    usagePercent := float64(m.Alloc) / float64(m.Sys) * 100
    if usagePercent > 80 {
        status = StatusDegraded
        message = "High memory usage"
    }

    // 90% 이상이면 비정상
    if usagePercent > 90 {
        status = StatusUnhealthy
        message = "Critical memory usage"
    }

    return CheckDetail{
        Status:   status,
        Message:  message,
        Duration: time.Since(start).String(),
    }
}
```

### 3.3 Liveness Probe 엔드포인트

```
GET /health/live

응답:
200 OK - 프로세스 정상
503 Service Unavailable - 프로세스 비정상 (재시작 필요)
```

```json
{
  "status": "healthy",
  "timestamp": "2025-11-30T15:30:00Z",
  "checks": {
    "goroutines": {
      "status": "healthy",
      "message": "Normal",
      "duration": "1.234ms"
    },
    "memory": {
      "status": "healthy",
      "message": "Normal",
      "duration": "0.567ms"
    }
  },
  "version": "v1.0.0",
  "uptime": "2h30m15s"
}
```

## 4. Readiness Probe

### 4.1 Readiness Probe 개념

Readiness Probe는 애플리케이션이 **트래픽을 처리할 준비**가 되었는지 확인합니다. 실패 시 Load Balancer에서 트래픽을 제외합니다.

**확인 항목:**
- 모든 의존성이 연결되어 있는가?
- 데이터베이스 쿼리가 가능한가?
- 캐시에 접근할 수 있는가?
- 메시지 큐가 연결되어 있는가?

### 4.2 Readiness Probe 구현

```go
package health

import (
    "context"
    "net/http"
    "time"

    "demo-abs/internal/infrastructure/cache"
    "demo-abs/internal/infrastructure/database"
    "demo-abs/internal/infrastructure/messaging"
    "github.com/gin-gonic/gin"
)

// ReadinessHandler Readiness Probe 핸들러
func ReadinessHandler(
    db database.Database,
    cache cache.Cache,
    mq messaging.MessageQueue,
) gin.HandlerFunc {
    return func(c *gin.Context) {
        ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
        defer cancel()

        checks := make(map[string]CheckDetail)

        // 1. 데이터베이스 확인
        dbCheck := checkDatabase(ctx, db)
        checks["database"] = dbCheck

        // 2. Redis 확인
        cacheCheck := checkCache(ctx, cache)
        checks["cache"] = cacheCheck

        // 3. RabbitMQ 확인
        mqCheck := checkMessageQueue(ctx, mq)
        checks["message_queue"] = mqCheck

        // 전체 상태 결정
        status := StatusHealthy
        for _, check := range checks {
            if check.Status == StatusUnhealthy {
                status = StatusUnhealthy
                break
            } else if check.Status == StatusDegraded {
                status = StatusDegraded
            }
        }

        result := CheckResult{
            Status:    status,
            Timestamp: time.Now().Format(time.RFC3339),
            Checks:    checks,
            Version:   getVersion(),
            Uptime:    time.Since(startTime).String(),
        }

        statusCode := http.StatusOK
        if status == StatusUnhealthy {
            statusCode = http.StatusServiceUnavailable
        }

        c.JSON(statusCode, result)
    }
}

// checkDatabase 데이터베이스 Health Check
func checkDatabase(ctx context.Context, db database.Database) CheckDetail {
    start := time.Now()

    if err := db.Ping(ctx); err != nil {
        return CheckDetail{
            Status:   StatusUnhealthy,
            Message:  "Database unreachable",
            Duration: time.Since(start).String(),
            Error:    err.Error(),
        }
    }

    // Connection Pool 상태 확인
    stats := db.Stats()
    if stats.OpenConnections >= stats.MaxOpenConnections-5 {
        return CheckDetail{
            Status:   StatusDegraded,
            Message:  "Connection pool nearly exhausted",
            Duration: time.Since(start).String(),
        }
    }

    return CheckDetail{
        Status:   StatusHealthy,
        Message:  "Database connected",
        Duration: time.Since(start).String(),
    }
}

// checkCache Redis Health Check
func checkCache(ctx context.Context, cache cache.Cache) CheckDetail {
    start := time.Now()

    if err := cache.Ping(ctx); err != nil {
        return CheckDetail{
            Status:   StatusUnhealthy,
            Message:  "Cache unreachable",
            Duration: time.Since(start).String(),
            Error:    err.Error(),
        }
    }

    // Redis 메모리 확인
    info, err := cache.Info(ctx)
    if err == nil {
        usedMemory := info["used_memory"].(int64)
        maxMemory := info["maxmemory"].(int64)

        if maxMemory > 0 {
            usagePercent := float64(usedMemory) / float64(maxMemory) * 100
            if usagePercent > 90 {
                return CheckDetail{
                    Status:   StatusDegraded,
                    Message:  "Cache memory high",
                    Duration: time.Since(start).String(),
                }
            }
        }
    }

    return CheckDetail{
        Status:   StatusHealthy,
        Message:  "Cache connected",
        Duration: time.Since(start).String(),
    }
}

// checkMessageQueue RabbitMQ Health Check
func checkMessageQueue(ctx context.Context, mq messaging.MessageQueue) CheckDetail {
    start := time.Now()

    if err := mq.Ping(ctx); err != nil {
        return CheckDetail{
            Status:   StatusUnhealthy,
            Message:  "Message queue unreachable",
            Duration: time.Since(start).String(),
            Error:    err.Error(),
        }
    }

    return CheckDetail{
        Status:   StatusHealthy,
        Message:  "Message queue connected",
        Duration: time.Since(start).String(),
    }
}
```

### 4.3 Readiness Probe 엔드포인트

```
GET /health/ready

응답:
200 OK - 트래픽 처리 준비 완료
503 Service Unavailable - 트래픽 처리 불가 (LB에서 제외)
```

```json
{
  "status": "healthy",
  "timestamp": "2025-11-30T15:30:00Z",
  "checks": {
    "database": {
      "status": "healthy",
      "message": "Database connected",
      "duration": "15.234ms"
    },
    "cache": {
      "status": "healthy",
      "message": "Cache connected",
      "duration": "5.123ms"
    },
    "message_queue": {
      "status": "healthy",
      "message": "Message queue connected",
      "duration": "8.456ms"
    }
  },
  "version": "v1.0.0",
  "uptime": "2h30m15s"
}
```

## 5. Startup Probe

### 5.1 Startup Probe 개념

Startup Probe는 애플리케이션이 **시작 완료**되었는지 확인합니다. 초기화가 오래 걸리는 애플리케이션에 유용합니다.

**확인 항목:**
- 설정 파일 로드 완료
- 데이터베이스 마이그레이션 완료
- 캐시 워밍업 완료
- 초기 데이터 로드 완료

### 5.2 Startup Probe 구현

```go
package health

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
)

var (
    isStarted   bool
    startupMu   sync.RWMutex
    startupTime time.Time
)

// MarkAsStarted 시작 완료 표시
func MarkAsStarted() {
    startupMu.Lock()
    defer startupMu.Unlock()

    isStarted = true
    startupTime = time.Now()
}

// StartupHandler Startup Probe 핸들러
func StartupHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        startupMu.RLock()
        started := isStarted
        startupMu.RUnlock()

        if !started {
            c.JSON(http.StatusServiceUnavailable, gin.H{
                "status":  "starting",
                "message": "Application is starting up",
            })
            return
        }

        c.JSON(http.StatusOK, gin.H{
            "status":       "started",
            "message":      "Application is ready",
            "startup_time": startupTime.Format(time.RFC3339),
            "elapsed":      time.Since(startupTime).String(),
        })
    }
}
```

### 5.3 Startup Sequence

```go
package main

import (
    "context"
    "log"
    "time"

    "demo-abs/internal/infrastructure/config"
    "demo-abs/internal/infrastructure/database"
    "demo-abs/internal/infrastructure/health"
)

func main() {
    log.Println("Starting ABS...")

    // 1. 설정 로드
    log.Println("[1/5] Loading configuration...")
    cfg, err := config.Load()
    if err != nil {
        log.Fatal(err)
    }

    // 2. 데이터베이스 연결
    log.Println("[2/5] Connecting to database...")
    db, err := database.Connect(cfg.Database)
    if err != nil {
        log.Fatal(err)
    }

    // 3. 캐시 연결
    log.Println("[3/5] Connecting to cache...")
    cache, err := connectCache(cfg.Cache)
    if err != nil {
        log.Fatal(err)
    }

    // 4. 메시지 큐 연결
    log.Println("[4/5] Connecting to message queue...")
    mq, err := connectMessageQueue(cfg.Messaging)
    if err != nil {
        log.Fatal(err)
    }

    // 5. HTTP 서버 시작
    log.Println("[5/5] Starting HTTP server...")
    srv := setupServer(cfg, db, cache, mq)

    go func() {
        if err := srv.ListenAndServe(); err != nil {
            log.Fatal(err)
        }
    }()

    // Startup 완료 표시
    health.MarkAsStarted()
    log.Println("✓ ABS started successfully")

    // Graceful Shutdown 대기
    <-waitForShutdown()
}
```

## 6. 통합 Health Check

### 6.1 통합 엔드포인트

```go
package health

// HealthHandler 통합 Health Check 핸들러
func HealthHandler(
    db database.Database,
    cache cache.Cache,
    mq messaging.MessageQueue,
) gin.HandlerFunc {
    return func(c *gin.Context) {
        ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
        defer cancel()

        checks := make(map[string]CheckDetail)

        // Liveness 체크
        checks["liveness"] = combineChecks(
            checkGoroutines(),
            checkMemory(),
        )

        // Readiness 체크
        checks["database"] = checkDatabase(ctx, db)
        checks["cache"] = checkCache(ctx, cache)
        checks["message_queue"] = checkMessageQueue(ctx, mq)

        // 전체 상태
        status := determineOverallStatus(checks)

        result := CheckResult{
            Status:    status,
            Timestamp: time.Now().Format(time.RFC3339),
            Checks:    checks,
            Version:   getVersion(),
            Uptime:    time.Since(startTime).String(),
        }

        statusCode := http.StatusOK
        if status == StatusUnhealthy {
            statusCode = http.StatusServiceUnavailable
        } else if status == StatusDegraded {
            statusCode = http.StatusOK  // Degraded는 200으로
        }

        c.JSON(statusCode, result)
    }
}

func determineOverallStatus(checks map[string]CheckDetail) Status {
    hasUnhealthy := false
    hasDegraded := false

    for _, check := range checks {
        if check.Status == StatusUnhealthy {
            hasUnhealthy = true
        } else if check.Status == StatusDegraded {
            hasDegraded = true
        }
    }

    if hasUnhealthy {
        return StatusUnhealthy
    } else if hasDegraded {
        return StatusDegraded
    }

    return StatusHealthy
}
```

### 6.2 라우터 설정

```go
package router

import (
    "demo-abs/internal/adapter/http/handler"
    "demo-abs/internal/infrastructure/health"
    "github.com/gin-gonic/gin"
)

func SetupHealthRoutes(
    r *gin.Engine,
    db database.Database,
    cache cache.Cache,
    mq messaging.MessageQueue,
) {
    healthGroup := r.Group("/health")
    {
        // 통합 Health Check
        healthGroup.GET("", health.HealthHandler(db, cache, mq))

        // Liveness Probe
        healthGroup.GET("/live", health.LivenessHandler())

        // Readiness Probe
        healthGroup.GET("/ready", health.ReadinessHandler(db, cache, mq))

        // Startup Probe
        healthGroup.GET("/startup", health.StartupHandler())
    }
}
```

## 7. Load Balancer 연동

### 7.1 HAProxy 설정

```cfg
# /etc/haproxy/haproxy.cfg

global
    log /dev/log local0
    maxconn 4096

defaults
    mode http
    timeout connect 5s
    timeout client 30s
    timeout server 30s

frontend abs_frontend
    bind *:80
    default_backend abs_backend

backend abs_backend
    balance roundrobin

    # Health Check 설정
    option httpchk GET /health/ready
    http-check expect status 200

    # 서버 등록
    server abs-1 192.168.1.101:8080 check inter 10s fall 3 rise 2
    server abs-2 192.168.1.102:8080 check inter 10s fall 3 rise 2
    server abs-3 192.168.1.103:8080 check inter 10s fall 3 rise 2

# 통계 페이지
listen stats
    bind *:9000
    stats enable
    stats uri /stats
    stats refresh 30s
```

**설정 설명:**
- `check inter 10s`: 10초마다 Health Check
- `fall 3`: 3번 연속 실패 시 제외
- `rise 2`: 2번 연속 성공 시 복구

### 7.2 Nginx 설정

```nginx
# /etc/nginx/nginx.conf

upstream abs_backend {
    # Health Check
    zone abs_backend 64k;

    server 192.168.1.101:8080 max_fails=3 fail_timeout=30s;
    server 192.168.1.102:8080 max_fails=3 fail_timeout=30s;
    server 192.168.1.103:8080 max_fails=3 fail_timeout=30s;

    # Health Check 엔드포인트 (Nginx Plus)
    # check interval=10s fails=3 passes=2 uri=/health/ready;
}

server {
    listen 80;
    server_name abs.example.com;

    location / {
        proxy_pass http://abs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Health Check 타임아웃
        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health Check 엔드포인트 노출 (선택사항)
    location /health {
        proxy_pass http://abs_backend/health;
    }
}
```

## 8. 모니터링 연동

### 8.1 Prometheus 메트릭

```go
package health

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // Health Check 상태
    healthStatus = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "abs_health_status",
            Help: "Health check status (0=unhealthy, 1=degraded, 2=healthy)",
        },
        []string{"check_type", "check_name"},
    )

    // Health Check 실행 횟수
    healthCheckTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "abs_health_check_total",
            Help: "Total number of health checks",
        },
        []string{"check_type", "status"},
    )

    // Health Check 실행 시간
    healthCheckDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "abs_health_check_duration_seconds",
            Help:    "Health check duration in seconds",
            Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1},
        },
        []string{"check_type", "check_name"},
    )
)

// RecordHealthCheck Health Check 메트릭 기록
func RecordHealthCheck(checkType, checkName string, status Status, duration time.Duration) {
    // 상태 값 변환
    statusValue := 0.0
    if status == StatusDegraded {
        statusValue = 1.0
    } else if status == StatusHealthy {
        statusValue = 2.0
    }

    healthStatus.WithLabelValues(checkType, checkName).Set(statusValue)
    healthCheckTotal.WithLabelValues(checkType, string(status)).Inc()
    healthCheckDuration.WithLabelValues(checkType, checkName).Observe(duration.Seconds())
}
```

### 8.2 Prometheus 알림 규칙

```yaml
# prometheus/rules/health.yml
groups:
  - name: health_alerts
    interval: 30s
    rules:
      # Health Check 실패
      - alert: HealthCheckFailed
        expr: abs_health_status < 2
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Health check failed for {{ $labels.check_name }}"
          description: "{{ $labels.check_type }} health check failed"

      # Health Check 지속적 실패
      - alert: HealthCheckPersistentlyFailed
        expr: abs_health_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Health check persistently failed"
          description: "{{ $labels.check_name }} has been unhealthy for 5 minutes"
```

## 9. 테스트

### 9.1 Health Check 테스트

```go
package health_test

import (
    "net/http"
    "net/http/httptest"
    "testing"

    "demo-abs/internal/infrastructure/health"
    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
)

func TestLivenessHandler(t *testing.T) {
    gin.SetMode(gin.TestMode)
    router := gin.New()
    router.GET("/health/live", health.LivenessHandler())

    req := httptest.NewRequest("GET", "/health/live", nil)
    w := httptest.NewRecorder()

    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusOK, w.Code)
    assert.Contains(t, w.Body.String(), "healthy")
}

func TestReadinessHandler(t *testing.T) {
    // Mock dependencies
    db := newMockDatabase()
    cache := newMockCache()
    mq := newMockMessageQueue()

    gin.SetMode(gin.TestMode)
    router := gin.New()
    router.GET("/health/ready", health.ReadinessHandler(db, cache, mq))

    req := httptest.NewRequest("GET", "/health/ready", nil)
    w := httptest.NewRecorder()

    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusOK, w.Code)
}
```

### 9.2 부하 테스트

```bash
# Health Check 엔드포인트 부하 테스트
wrk -t4 -c100 -d30s http://localhost:8080/health/ready

# 예상 결과:
# Latency: < 50ms
# Throughput: > 1000 req/s
# 에러율: 0%
```

## 10. 참고 자료

- Kubernetes Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- HAProxy Health Checks: http://www.haproxy.org/download/1.8/doc/configuration.txt
- Health Check Pattern: https://microservices.io/patterns/observability/health-check-api.html

## 11. 구현 위치

```
internal/
├── infrastructure/
│   └── health/
│       ├── health.go           # Health Check 구조체
│       ├── liveness.go         # Liveness Probe
│       ├── readiness.go        # Readiness Probe
│       ├── startup.go          # Startup Probe
│       ├── metrics.go          # Prometheus 메트릭
│       └── health_test.go      # 테스트
├── adapter/
│   └── http/
│       └── router/
│           └── health_routes.go # Health Check 라우트
config/
├── haproxy.cfg                  # HAProxy 설정
└── nginx.conf                   # Nginx 설정
```

---

최종 수정일: 2025-11-30, 작성자: ABS 개발팀
