# Redis 캐시 설계

## 문서 목적

본 문서는 ABS의 Redis 캐시 전략을 정의합니다.

**포함 내용**:
- 캐시 키 전략
- TTL (Time To Live) 정책
- Eviction 정책
- 캐시 무효화 전략
- 장애 처리 (Cache Fallback)

---

## 1. Redis 개요

### 1.1 사용 목적

| 용도 | 캐시 대상 | TTL |
|------|-----------|-----|
| **조회 성능 향상** | Route 조회 결과 | 5분 |
| **DB 부하 감소** | 통계 데이터 | 10초 |
| **일치율 임시 저장** | 실시간 일치율 | 10초 |
| **분산 락** | 동시성 제어 | 30초 |
| **세션 저장** | 실험 상태 (선택사항) | 1시간 |

### 1.2 Redis 구성

```
Redis Cluster (3 Master + 3 Replica)
├── Master 1: 0-5460 slots
├── Master 2: 5461-10922 slots
└── Master 3: 10923-16383 slots
```

**특징**:
- **Cluster 모드**: 고가용성 및 샤딩
- **Replica**: 읽기 부하 분산
- **Sentinel**: 자동 Failover (선택사항)

---

## 2. 캐시 키 전략

### 2.1 키 네이밍 규칙

```
{service}:{resource}:{identifier}:{field}

예시:
abs:route:123e4567:info
abs:route:123e4567:match_rate
abs:stats:daily:2025-11-30
abs:lock:experiment:456e7890
```

**구성 요소**:
| 요소 | 설명 | 예시 |
|------|------|------|
| `service` | 서비스명 (고정) | `abs` |
| `resource` | 리소스 타입 | `route`, `experiment`, `stats` |
| `identifier` | 리소스 식별자 | UUID, 날짜 |
| `field` | 필드명 (선택사항) | `info`, `match_rate` |

**규칙**:
- 구분자: 콜론 (`:`)
- 소문자 + 언더스코어 (`_`)
- 최대 길이: 200자

### 2.2 캐시 키 목록

#### 2.2.1 Route 캐시

```go
// Route 전체 정보
key: abs:route:{route_id}:info
type: String (JSON)
TTL: 5분
value: {"id":"123","path":"/api/v1/users","method":"GET",...}

// Route 일치율
key: abs:route:{route_id}:match_rate
type: Float
TTL: 10초
value: 99.95

// Route 목록 (페이지네이션)
key: abs:routes:page:{page}:limit:{limit}
type: String (JSON Array)
TTL: 1분
value: [{"id":"123",...},{"id":"234",...}]
```

#### 2.2.2 통계 캐시

```go
// 일별 통계
key: abs:stats:daily:{date}:{route_id}
type: Hash
TTL: 1시간
fields:
  - total_requests: 5000
  - match_rate: 99.95
  - error_rate: 0.05

// 실시간 메트릭
key: abs:metrics:realtime:{route_id}
type: Hash
TTL: 10초
fields:
  - current_tps: 120
  - avg_response_time: 115
```

#### 2.2.3 실험 상태 캐시

```go
// 현재 실험
key: abs:experiment:current:{route_id}
type: String (JSON)
TTL: 1분
value: {"id":"456","status":"running","current_percentage":10,...}

// 실험 진행 조건
key: abs:experiment:{experiment_id}:conditions
type: Hash
TTL: 30초
fields:
  - stabilization_elapsed: "true"
  - min_requests_met: "true"
  - match_rate_ok: "true"
```

#### 2.2.4 분산 락

```go
// 실험 승인 락
key: abs:lock:experiment:{experiment_id}
type: String
TTL: 30초
value: {lock_holder_id}

// 라우트 수정 락
key: abs:lock:route:{route_id}
type: String
TTL: 10초
value: {lock_holder_id}
```

---

## 3. TTL 정책

### 3.1 TTL 레벨

| 레벨 | TTL | 용도 | 예시 |
|------|-----|------|------|
| **매우 짧음** | 10초 | 실시간 메트릭 | 일치율, TPS |
| **짧음** | 1분 | 자주 변경되는 데이터 | Route 목록 |
| **중간** | 5분 | 조회용 데이터 | Route 상세 정보 |
| **길음** | 1시간 | 통계 데이터 | 일별 통계 |
| **매우 길음** | 24시간 | 거의 변경 안 됨 | 설정 값 |

### 3.2 TTL 설정 예시

```go
// internal/adapter/out/cache/redis_cache.go

const (
    TTL_VERY_SHORT = 10 * time.Second
    TTL_SHORT      = 1 * time.Minute
    TTL_MEDIUM     = 5 * time.Minute
    TTL_LONG       = 1 * time.Hour
    TTL_VERY_LONG  = 24 * time.Hour
)

func (c *RedisCache) SetRoute(routeID string, route *Route) error {
    key := fmt.Sprintf("abs:route:%s:info", routeID)
    value, _ := json.Marshal(route)

    return c.client.Set(context.Background(), key, value, TTL_MEDIUM).Err()
}

func (c *RedisCache) SetMatchRate(routeID string, matchRate float64) error {
    key := fmt.Sprintf("abs:route:%s:match_rate", routeID)

    return c.client.Set(context.Background(), key, matchRate, TTL_VERY_SHORT).Err()
}
```

---

## 4. Eviction 정책

### 4.1 Redis 설정

```conf
# redis.conf

# 최대 메모리 (4GB)
maxmemory 4gb

# Eviction 정책: LRU (Least Recently Used)
maxmemory-policy allkeys-lru

# LRU 샘플 크기
maxmemory-samples 5
```

**Eviction 정책 옵션**:
| 정책 | 설명 | ABS 사용 |
|------|------|----------|
| `noeviction` | Eviction 하지 않음 (메모리 가득 시 쓰기 거부) | ✗ |
| `allkeys-lru` | 모든 키 중 LRU 제거 | **✓ (선택)** |
| `volatile-lru` | TTL 설정된 키 중 LRU 제거 | ✓ (대안) |
| `allkeys-random` | 모든 키 중 무작위 제거 | ✗ |
| `volatile-ttl` | TTL이 짧은 키 먼저 제거 | ✗ |

**ABS 권장**: `allkeys-lru` (모든 캐시가 TTL을 가지므로)

---

## 5. 캐시 무효화 전략

### 5.1 무효화 시점

| 이벤트 | 무효화 대상 | 전략 |
|--------|-------------|------|
| Route 수정 | `abs:route:{id}:*` | 즉시 삭제 |
| Route 삭제 | `abs:route:{id}:*` | 즉시 삭제 |
| 일치율 갱신 | `abs:route:{id}:match_rate` | TTL 짧게 (10초) |
| 실험 상태 변경 | `abs:experiment:*:{id}` | 즉시 삭제 |
| 통계 재계산 | `abs:stats:*` | 즉시 삭제 |

### 5.2 무효화 구현

```go
// Cache-Aside Pattern

// 1. 조회 (Read-Through)
func (s *RouteService) GetRoute(routeID string) (*Route, error) {
    // 캐시 조회
    cached, err := s.cache.Get(fmt.Sprintf("abs:route:%s:info", routeID))
    if err == nil {
        var route Route
        json.Unmarshal([]byte(cached), &route)
        return &route, nil
    }

    // 캐시 미스 → DB 조회
    route, err := s.repository.FindByID(routeID)
    if err != nil {
        return nil, err
    }

    // 캐시 저장
    s.cache.SetRoute(routeID, route)

    return route, nil
}

// 2. 수정 (Write-Through)
func (s *RouteService) UpdateRoute(routeID string, updates *RouteUpdates) error {
    // DB 수정
    err := s.repository.Update(routeID, updates)
    if err != nil {
        return err
    }

    // 캐시 무효화
    s.cache.Delete(fmt.Sprintf("abs:route:%s:info", routeID))
    s.cache.Delete(fmt.Sprintf("abs:route:%s:match_rate", routeID))

    return nil
}

// 3. 삭제 (Write-Through)
func (s *RouteService) DeleteRoute(routeID string) error {
    // DB 삭제
    err := s.repository.Delete(routeID)
    if err != nil {
        return err
    }

    // 캐시 무효화 (패턴 매칭)
    s.cache.DeletePattern(fmt.Sprintf("abs:route:%s:*", routeID))

    return nil
}
```

### 5.3 패턴 기반 무효화

```go
func (c *RedisCache) DeletePattern(pattern string) error {
    ctx := context.Background()

    // SCAN으로 패턴 매칭 키 조회
    var cursor uint64
    var keys []string

    for {
        var err error
        keys, cursor, err = c.client.Scan(ctx, cursor, pattern, 100).Result()
        if err != nil {
            return err
        }

        // 키 삭제
        if len(keys) > 0 {
            c.client.Del(ctx, keys...)
        }

        // 마지막 페이지
        if cursor == 0 {
            break
        }
    }

    return nil
}
```

---

## 6. 분산 락

### 6.1 락 획득/해제

```go
// internal/adapter/out/cache/distributed_lock.go

type DistributedLock struct {
    client *redis.Client
    logger *slog.Logger
}

func (l *DistributedLock) Acquire(ctx context.Context, key string, ttl time.Duration) (bool, error) {
    // SET NX EX (Not Exists, Expire)
    result, err := l.client.SetNX(ctx, key, uuid.New().String(), ttl).Result()
    if err != nil {
        return false, err
    }

    if result {
        l.logger.Debug("Lock acquired", "key", key, "ttl", ttl)
    } else {
        l.logger.Debug("Lock already held", "key", key)
    }

    return result, nil
}

func (l *DistributedLock) Release(ctx context.Context, key string) error {
    // DEL
    err := l.client.Del(ctx, key).Err()
    if err != nil {
        return err
    }

    l.logger.Debug("Lock released", "key", key)
    return nil
}

func (l *DistributedLock) TryAcquireWithRetry(ctx context.Context, key string, ttl time.Duration, maxRetries int) (bool, error) {
    for attempt := 0; attempt < maxRetries; attempt++ {
        acquired, err := l.Acquire(ctx, key, ttl)
        if err != nil {
            return false, err
        }

        if acquired {
            return true, nil
        }

        // 100ms 대기 후 재시도
        time.Sleep(100 * time.Millisecond)
    }

    return false, nil
}
```

### 6.2 사용 예시

```go
func (s *ExperimentService) ApproveNextStage(experimentID string) error {
    lockKey := fmt.Sprintf("abs:lock:experiment:%s", experimentID)

    // 락 획득 시도 (최대 5회, 30초 TTL)
    acquired, err := s.lock.TryAcquireWithRetry(context.Background(), lockKey, 30*time.Second, 5)
    if err != nil {
        return err
    }

    if !acquired {
        return errors.New("failed to acquire lock")
    }

    defer s.lock.Release(context.Background(), lockKey)

    // 승인 로직 실행
    return s.approveStage(experimentID)
}
```

---

## 7. 장애 처리

### 7.1 Cache Fallback

```go
func (s *RouteService) GetRouteWithFallback(routeID string) (*Route, error) {
    // 1. 캐시 조회
    cached, err := s.cache.Get(fmt.Sprintf("abs:route:%s:info", routeID))
    if err == nil {
        var route Route
        json.Unmarshal([]byte(cached), &route)
        return &route, nil
    }

    // 2. 캐시 에러 → 경고 로그
    if err != redis.Nil {
        s.logger.Warn("Cache error, falling back to DB", "error", err)
    }

    // 3. DB 조회 (Fallback)
    route, err := s.repository.FindByID(routeID)
    if err != nil {
        return nil, err
    }

    // 4. 캐시 저장 시도 (실패해도 무시)
    _ = s.cache.SetRoute(routeID, route)

    return route, nil
}
```

### 7.2 Redis 연결 실패 처리

```go
type ResilientCache struct {
    client        *redis.Client
    circuitBreaker *circuitbreaker.CircuitBreaker
    logger        *slog.Logger
}

func (c *ResilientCache) Get(key string) (string, error) {
    var value string
    var err error

    // Circuit Breaker로 래핑
    cbErr := c.circuitBreaker.Call(func() error {
        value, err = c.client.Get(context.Background(), key).Result()
        return err
    })

    // Circuit Breaker Open → Fallback
    if errors.Is(cbErr, circuitbreaker.ErrCircuitOpen) {
        c.logger.Warn("Redis circuit breaker open, cache unavailable")
        return "", redis.Nil  // 캐시 미스로 처리
    }

    return value, err
}
```

---

## 8. 파이프라인 및 배치 처리

### 8.1 파이프라인

```go
func (c *RedisCache) SetMultiple(items map[string]interface{}, ttl time.Duration) error {
    ctx := context.Background()

    // 파이프라인 시작
    pipe := c.client.Pipeline()

    for key, value := range items {
        pipe.Set(ctx, key, value, ttl)
    }

    // 일괄 실행
    _, err := pipe.Exec(ctx)
    return err
}

// 사용 예시
func (s *RouteService) CacheMultipleRoutes(routes []*Route) error {
    items := make(map[string]interface{})

    for _, route := range routes {
        key := fmt.Sprintf("abs:route:%s:info", route.ID)
        value, _ := json.Marshal(route)
        items[key] = value
    }

    return s.cache.SetMultiple(items, TTL_MEDIUM)
}
```

### 8.2 트랜잭션 (MULTI/EXEC)

```go
func (c *RedisCache) AtomicIncrement(key string, value int64, ttl time.Duration) error {
    ctx := context.Background()

    // WATCH로 낙관적 락
    return c.client.Watch(ctx, func(tx *redis.Tx) error {
        // 현재 값 조회
        current, err := tx.Get(ctx, key).Int64()
        if err != nil && err != redis.Nil {
            return err
        }

        // 트랜잭션 시작
        _, err = tx.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
            pipe.Set(ctx, key, current+value, ttl)
            return nil
        })

        return err
    }, key)
}
```

---

## 9. 모니터링

### 9.1 Redis 메트릭

```go
var (
    // 캐시 히트율
    cacheHits = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "abs_cache_hits_total",
            Help: "Total number of cache hits",
        },
        []string{"key_prefix"},
    )

    cacheMisses = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "abs_cache_misses_total",
            Help: "Total number of cache misses",
        },
        []string{"key_prefix"},
    )

    // 캐시 응답 시간
    cacheLatency = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "abs_cache_latency_seconds",
            Help:    "Cache operation latency",
            Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1},
        },
        []string{"operation", "key_prefix"},
    )

    // Redis 연결 상태
    redisConnections = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "abs_redis_connections",
            Help: "Number of active Redis connections",
        },
    )
)

func (c *RedisCache) Get(key string) (string, error) {
    start := time.Now()

    value, err := c.client.Get(context.Background(), key).Result()

    // 메트릭 기록
    prefix := strings.Split(key, ":")[1]  // abs:route:123 → route

    if err == redis.Nil {
        cacheMisses.WithLabelValues(prefix).Inc()
    } else if err == nil {
        cacheHits.WithLabelValues(prefix).Inc()
    }

    cacheLatency.WithLabelValues("get", prefix).Observe(time.Since(start).Seconds())

    return value, err
}
```

### 9.2 캐시 히트율 계산

```
HitRate = CacheHits / (CacheHits + CacheMisses) × 100
```

**대시보드 표시**:
```
┌─────────────────────────────────────────┐
│ Redis 캐시 히트율                        │
├─────────────────────────────────────────┤
│ Route 정보:   85% ████████░░            │
│ 일치율:       92% █████████░            │
│ 통계 데이터:  78% ███████░░░            │
│ 전체 평균:    85% ████████░░            │
└─────────────────────────────────────────┘
```

---

## 10. 구현 예시

### 10.1 Cache 인터페이스

```go
// internal/domain/port/cache.go

type Cache interface {
    // Basic operations
    Get(key string) (string, error)
    Set(key string, value interface{}, ttl time.Duration) error
    Delete(key string) error
    Exists(key string) (bool, error)

    // Batch operations
    GetMultiple(keys []string) (map[string]string, error)
    SetMultiple(items map[string]interface{}, ttl time.Duration) error
    DeletePattern(pattern string) error

    // Hash operations
    HGet(key, field string) (string, error)
    HSet(key, field string, value interface{}) error
    HGetAll(key string) (map[string]string, error)

    // Distributed lock
    AcquireLock(key string, ttl time.Duration) (bool, error)
    ReleaseLock(key string) error
}
```

### 10.2 Redis Cache 구현

```go
// internal/adapter/out/cache/redis_cache.go

type RedisCache struct {
    client *redis.Client
    logger *slog.Logger
}

func NewRedisCache(addr string, password string, db int) (*RedisCache, error) {
    client := redis.NewClient(&redis.Options{
        Addr:         addr,
        Password:     password,
        DB:           db,
        PoolSize:     100,
        MinIdleConns: 10,
        MaxRetries:   3,
    })

    // 연결 테스트
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    _, err := client.Ping(ctx).Result()
    if err != nil {
        return nil, fmt.Errorf("failed to connect to Redis: %w", err)
    }

    return &RedisCache{
        client: client,
        logger: slog.Default(),
    }, nil
}

func (c *RedisCache) Get(key string) (string, error) {
    return c.client.Get(context.Background(), key).Result()
}

func (c *RedisCache) Set(key string, value interface{}, ttl time.Duration) error {
    return c.client.Set(context.Background(), key, value, ttl).Err()
}

func (c *RedisCache) Delete(key string) error {
    return c.client.Del(context.Background(), key).Err()
}
```

---

## 11. 참고 사항

### 11.1 관련 문서

- `01-legacy-modern-client.md`: HTTP Client 설계
- `04-circuit-breaker.md`: Circuit Breaker 설계
- `docs/04-business-logic/02-match-rate-calculation.md`: 일치율 캐싱

### 11.2 구현 위치

```
internal/adapter/out/cache/
├── redis_cache.go        # Redis Cache 구현
├── distributed_lock.go   # 분산 락
└── cache_keys.go         # 캐시 키 상수
```

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
