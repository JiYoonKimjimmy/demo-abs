# 프로젝트 디렉토리 구조

## 목차
1. [전체 구조 개요](#전체-구조-개요)
2. [디렉토리별 상세 설명](#디렉토리별-상세-설명)
3. [패키지 네이밍 규칙](#패키지-네이밍-규칙)
4. [파일 구성 원칙](#파일-구성-원칙)

---

## 전체 구조 개요

```
demo-abs/
├── cmd/                                  # 애플리케이션 진입점
│   └── abs/
│       └── main.go
│
├── internal/                             # 내부 패키지 (외부 import 불가)
│   ├── domain/                           # Domain Layer
│   │   ├── model/
│   │   ├── service/
│   │   └── port/
│   │
│   ├── application/                      # Application Layer
│   │   ├── usecase/
│   │   └── dto/
│   │
│   ├── adapter/                          # Adapter Layer
│   │   ├── in/
│   │   │   └── http/
│   │   └── out/
│   │       ├── persistence/
│   │       ├── cache/
│   │       ├── messaging/
│   │       └── httpclient/
│   │
│   └── infrastructure/                   # Infrastructure Layer
│       ├── config/
│       ├── logger/
│       └── monitoring/
│
├── pkg/                                  # 외부 공개 가능한 공통 라이브러리
│   ├── jsoncompare/
│   ├── circuitbreaker/
│   └── masking/
│
├── test/                                 # 테스트 코드
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── docs/                                 # 문서
├── scripts/                              # 스크립트 (빌드, 배포 등)
├── config/                               # 설정 파일
│   ├── dev/
│   ├── stg/
│   └── prod/
│
├── .gitignore
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

---

## 디렉토리별 상세 설명

### 1. cmd/ - 애플리케이션 진입점

**목적**: 실행 가능한 바이너리를 생성하는 진입점

```
cmd/
└── abs/
    └── main.go          # 애플리케이션 시작점, DI 초기화
```

**책임**:
- 애플리케이션 초기화
- 의존성 주입(DI) 설정
- HTTP 서버 시작
- Graceful Shutdown 처리

**예시 구조**:
```go
// cmd/abs/main.go
package main

func main() {
    // 1. Config 로딩
    // 2. Logger 초기화
    // 3. DB/Redis/RabbitMQ 연결
    // 4. DI Container 구성
    // 5. HTTP Server 시작
    // 6. Graceful Shutdown 대기
}
```

---

### 2. internal/ - 내부 패키지

**목적**: 외부 프로젝트에서 import 불가능한 내부 구현

Go의 `internal` 디렉토리 규칙에 따라 해당 프로젝트 내부에서만 사용 가능합니다.

#### 2.1 internal/domain/ - Domain Layer

```
internal/domain/
├── model/                    # 도메인 엔티티 및 Value Object
│   ├── route.go
│   ├── comparison.go
│   ├── experiment.go
│   ├── api_request.go
│   └── api_response.go
│
├── service/                  # 도메인 서비스
│   ├── comparison_service.go
│   ├── match_rate_calculator.go
│   ├── routing_service.go
│   └── experiment_service.go
│
└── port/                     # Port 인터페이스
    ├── repository.go
    ├── cache.go
    ├── message_publisher.go
    └── api_client.go
```

**책임**:
- **model/**: 핵심 비즈니스 엔티티 정의
- **service/**: 도메인 규칙 및 비즈니스 로직 구현
- **port/**: 외부 연동을 위한 인터페이스 정의

**의존성**: 없음 (순수 Go 표준 라이브러리만 사용)

---

#### 2.2 internal/application/ - Application Layer

```
internal/application/
├── usecase/                  # 유스케이스
│   ├── route_usecase.go
│   ├── comparison_usecase.go
│   └── experiment_usecase.go
│
└── dto/                      # 데이터 전송 객체
    ├── route_dto.go
    ├── comparison_dto.go
    └── experiment_dto.go
```

**책임**:
- **usecase/**: 비즈니스 흐름 조합 및 트랜잭션 관리
- **dto/**: HTTP 요청/응답 DTO (도메인 모델과 분리)

**의존성**: Domain의 Port 인터페이스에만 의존

---

#### 2.3 internal/adapter/ - Adapter Layer

```
internal/adapter/
├── in/                       # 인바운드 어댑터
│   └── http/
│       ├── handler/
│       │   ├── route_handler.go
│       │   ├── experiment_handler.go
│       │   ├── metrics_handler.go
│       │   └── health_handler.go
│       ├── middleware/
│       │   ├── logger_middleware.go
│       │   ├── error_middleware.go
│       │   └── recovery_middleware.go
│       └── router/
│           └── router.go
│
└── out/                      # 아웃바운드 어댑터
    ├── persistence/
    │   ├── oracle/
    │   │   ├── connection.go
    │   │   ├── route_repository.go
    │   │   ├── comparison_repository.go
    │   │   └── experiment_repository.go
    │   └── entity/
    │       ├── route_entity.go
    │       └── experiment_entity.go
    │
    ├── cache/
    │   ├── redis_client.go
    │   └── redis_cache.go
    │
    ├── messaging/
    │   ├── rabbitmq_client.go
    │   ├── rabbitmq_publisher.go
    │   └── rabbitmq_consumer.go
    │
    └── httpclient/
        ├── http_client.go
        ├── legacy_client.go
        └── modern_client.go
```

**책임**:
- **in/http/**: HTTP 요청 처리 (Gin/Echo Handler, Middleware, Router)
- **out/persistence/**: OracleDB 연동 (GORM)
- **out/cache/**: Redis 연동
- **out/messaging/**: RabbitMQ 연동
- **out/httpclient/**: Legacy/Modern API 호출

**의존성**: Domain의 Port 인터페이스를 구현

---

#### 2.4 internal/infrastructure/ - Infrastructure Layer

```
internal/infrastructure/
├── config/
│   ├── config.go
│   └── loader.go
│
├── logger/
│   ├── logger.go
│   └── zap_logger.go
│
└── monitoring/
    ├── metrics.go
    └── prometheus.go
```

**책임**:
- **config/**: 환경변수 및 설정 파일 로딩
- **logger/**: 구조화 로깅 (zerolog 또는 zap)
- **monitoring/**: Prometheus 메트릭 수집

**의존성**: 모든 계층에서 사용 가능

---

### 3. pkg/ - 공통 라이브러리

```
pkg/
├── jsoncompare/
│   ├── comparer.go
│   ├── comparer_test.go
│   └── options.go
│
├── circuitbreaker/
│   ├── breaker.go
│   ├── breaker_test.go
│   └── config.go
│
└── masking/
    ├── masker.go
    ├── masker_test.go
    └── patterns.go
```

**목적**: 프로젝트 독립적인 재사용 가능한 유틸리티

**특징**:
- 외부 프로젝트에서 import 가능 (`import "github.com/org/demo-abs/pkg/jsoncompare"`)
- ABS 비즈니스 로직과 독립적
- 단위 테스트 필수 (각 패키지 내 `_test.go`)

**책임**:
- **jsoncompare/**: JSON 비교 알고리즘
- **circuitbreaker/**: Circuit Breaker 패턴 구현
- **masking/**: 개인정보 마스킹 로직

---

### 4. test/ - 테스트 코드

```
test/
├── unit/                     # 단위 테스트
│   ├── domain/
│   ├── application/
│   └── pkg/
│
├── integration/              # 통합 테스트
│   ├── database/
│   ├── cache/
│   └── messaging/
│
└── e2e/                      # E2E 테스트
    ├── scenarios/
    └── fixtures/
```

**구성 원칙**:
- **unit/**: 외부 의존성 없이 Mock을 사용한 단위 테스트
- **integration/**: 실제 외부 시스템(DB, Redis 등)과 연동 테스트
- **e2e/**: 전체 시나리오 End-to-End 테스트

---

### 5. docs/ - 문서

```
docs/
├── 00-overview.md
├── plan/
├── 01-architecture/
├── 02-domain/
└── ...
```

**목적**: 설계 문서 및 가이드 관리

---

### 6. scripts/ - 스크립트

```
scripts/
├── build.sh              # 빌드 스크립트
├── deploy.sh             # 배포 스크립트
├── db-migrate.sh         # DB 마이그레이션
└── test.sh               # 테스트 실행
```

**목적**: 빌드, 배포, 마이그레이션 등 자동화 스크립트

---

### 7. config/ - 설정 파일

```
config/
├── dev/
│   ├── app.yaml
│   └── database.yaml
├── stg/
│   ├── app.yaml
│   └── database.yaml
└── prod/
    ├── app.yaml
    └── database.yaml
```

**목적**: 환경별 설정 파일 관리 (dev/stg/prod)

**주의**: 민감 정보(DB 비밀번호 등)는 환경변수나 Secret Manager 사용

---

## 패키지 네이밍 규칙

### 1. 패키지명

- **소문자 사용**: `model`, `service`, `usecase`
- **단수형 사용**: `model` (❌ `models`), `repository` (❌ `repositories`)
- **명확하고 간결**: 패키지의 역할을 명확히 표현
- **약어 지양**: `configuration` (❌ `config`는 디렉토리명으로는 사용)

**예외**: 관례적으로 사용되는 약어는 허용
- `dto` (Data Transfer Object)
- `http` (HyperText Transfer Protocol)

### 2. 파일명

- **스네이크 케이스 사용**: `route_usecase.go`, `legacy_client.go`
- **패키지 역할 반영**: `{entity}_{role}.go` 형식
  - `route_repository.go` (Route 엔티티의 Repository)
  - `comparison_service.go` (Comparison 엔티티의 Service)

### 3. 인터페이스명

- **행위 중심 네이밍**: `Repository`, `CacheStore`, `APIClient`
- **역할 명확화**: `RouteRepository`, `ComparisonRepository`

### 4. 구현체명

- **기술 스택 명시**: `OracleRouteRepository`, `RedisCache`, `HTTPAPIClient`
- **인터페이스명 + 기술**: `{Tech}{Interface}` 형식

---

## 파일 구성 원칙

### 1. 파일 크기

- **적절한 크기 유지**: 200~500 라인 권장
- **역할별 분리**: 하나의 파일은 하나의 책임
- **과도한 분리 지양**: 지나치게 작은 파일은 오히려 가독성 저하

### 2. 파일 구성 순서

```go
// 1. Package 선언
package usecase

// 2. Import (표준 → 외부 → 내부)
import (
    "context"
    "time"

    "github.com/google/uuid"

    "demo-abs/internal/domain/model"
    "demo-abs/internal/domain/port"
)

// 3. 타입 정의
type RouteUseCase struct {
    repo   port.RouteRepository
    cache  port.CacheStore
}

// 4. 생성자
func NewRouteUseCase(repo port.RouteRepository, cache port.CacheStore) *RouteUseCase {
    return &RouteUseCase{repo: repo, cache: cache}
}

// 5. 메서드 (Public → Private)
func (uc *RouteUseCase) CreateRoute(ctx context.Context, dto RouteDTO) error {
    // ...
}

func (uc *RouteUseCase) validateRoute(route *model.Route) error {
    // ...
}
```

### 3. 디렉토리 깊이

- **최대 3-4 레벨 권장**: 과도한 중첩 지양
- **논리적 그룹핑**: 관련된 파일끼리 묶기

---

## 패키지 간 의존성 규칙

### 허용되는 의존성

```
✅ internal/application/usecase → internal/domain/port
✅ internal/adapter/out/persistence → internal/domain/port
✅ pkg/jsoncompare → (외부 라이브러리)
✅ internal/infrastructure/logger → (표준 라이브러리)
```

### 금지되는 의존성

```
❌ internal/domain → internal/adapter
❌ internal/domain → internal/application
❌ internal/application → internal/adapter
❌ pkg/* → internal/*
```

### 순환 의존성 금지

```
❌ A → B → C → A (순환 참조)
✅ A → B → C (일방향)
```

---

## 프로젝트 구조 검증

### 체크리스트

- [ ] `cmd/`에는 `main.go`만 존재하는가?
- [ ] `internal/domain/`은 외부 라이브러리에 의존하지 않는가?
- [ ] `pkg/`의 각 패키지는 독립적으로 테스트 가능한가?
- [ ] 패키지명은 모두 소문자, 단수형인가?
- [ ] 파일명은 스네이크 케이스인가?
- [ ] 순환 참조가 존재하지 않는가?
- [ ] 테스트 파일은 `_test.go`로 끝나는가?

### 의존성 검증 도구

```bash
# Go 모듈 그래프 확인
go mod graph

# 순환 참조 검사
go list -f '{{.ImportPath}}: {{.Imports}}' ./...
```

---

## 참고 자료

- [Go Project Layout - golang-standards](https://github.com/golang-standards/project-layout)
- [Effective Go - Package names](https://go.dev/doc/effective_go#names)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
