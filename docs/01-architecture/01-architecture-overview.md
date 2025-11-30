# 아키텍처 개요

## 목차
1. [아키텍처 패턴 선택](#아키텍처-패턴-선택)
2. [헥사고날 아키텍처](#헥사고날-아키텍처)
3. [클린 아키텍처](#클린-아키텍처)
4. [ABS 아키텍처 적용](#abs-아키텍처-적용)
5. [핵심 설계 원칙](#핵심-설계-원칙)

---

## 아키텍처 패턴 선택

### 선택한 패턴
ABS는 **헥사고날 아키텍처(Hexagonal Architecture)**와 **클린 아키텍처(Clean Architecture)**의 원칙을 조합하여 설계합니다.

### 선택 이유

#### 1. 외부 의존성 분리
ABS는 다양한 외부 시스템과 연동해야 합니다:
- **Legacy API / Modern API**: HTTP 클라이언트를 통한 호출
- **OracleDB**: 데이터 영속성
- **Redis**: 캐싱
- **RabbitMQ**: 비동기 메시징

헥사고날 아키텍처의 Port/Adapter 패턴을 적용하면 이러한 외부 의존성을 인터페이스(Port)로 추상화하고, 실제 구현(Adapter)을 분리할 수 있습니다. 이를 통해:
- 외부 시스템 변경 시 비즈니스 로직 영향 최소화
- Mock을 통한 독립적 테스트 가능
- 기술 스택 교체 용이 (예: OracleDB → PostgreSQL)

#### 2. 테스트 용이성
- **도메인 로직 단위 테스트**: 외부 의존성 없이 순수 비즈니스 로직 테스트
- **Mock/Stub 활용**: Port 인터페이스를 Mock으로 구현하여 통합 테스트
- **테스트 커버리지 목표 달성**: 요구사항의 80% 커버리지 목표 충족

#### 3. 확장성
향후 요구사항 변경 및 확장에 유연하게 대응:
- **GraphQL 지원**: HTTP Adapter만 추가
- **gRPC 지원**: gRPC Adapter만 추가
- **새로운 캐시 시스템**: Cache Adapter만 교체
- **메시징 시스템 변경**: Messaging Adapter만 교체

#### 4. 유지보수성
- **계층 분리**: 변경 영향 범위가 명확히 제한됨
- **단일 책임 원칙**: 각 계층과 컴포넌트가 명확한 역할 수행
- **가독성 향상**: 코드 구조가 직관적이고 일관성 있음

---

## 헥사고날 아키텍처

### 개념
헥사고날 아키텍처(Ports and Adapters)는 Alistair Cockburn이 제안한 패턴으로, 애플리케이션을 외부 세계로부터 격리시키는 것을 목표로 합니다.

### 핵심 구성 요소

#### 1. 애플리케이션 코어 (Core)
- 비즈니스 로직과 도메인 모델을 포함
- 외부 기술에 의존하지 않음
- 순수한 비즈니스 규칙만 구현

#### 2. 포트 (Ports)
- 애플리케이션과 외부 세계 간의 경계를 정의하는 인터페이스
- **Inbound Port**: 외부에서 애플리케이션으로 들어오는 요청 (예: UseCase 인터페이스)
- **Outbound Port**: 애플리케이션에서 외부로 나가는 요청 (예: Repository, Cache 인터페이스)

#### 3. 어댑터 (Adapters)
- Port 인터페이스의 실제 구현체
- **Inbound Adapter**: HTTP Handler, gRPC Server 등
- **Outbound Adapter**: DB Repository 구현, HTTP Client 구현 등

### 헥사고날 아키텍처 다이어그램

```
┌─────────────────────────────────┐
│   Inbound Adapters (Primary)    │
│                                 │
│  ┌────────┐      ┌──────────┐   │
│  │  HTTP  │      │  gRPC    │   │
│  │Handler │      │ Server   │   │
│  └────┬───┘      └─────┬────┘   │
└───────┼────────────────┼────────┘
        │                │
┌───────▼────────────────▼────────┐
│         Inbound Ports           │
│    (UseCase Interfaces)         │
├─────────────────────────────────┤
│                                 │
│      Application Core           │
│   (Business Logic / Domain)     │
│                                 │
├─────────────────────────────────┤
│        Outbound Ports           │
│  (Repository, Cache, Client)    │
└───────┬────────────────┬────────┘
        │                │
┌───────▼────────────────▼────────┐
│  Outbound Adapters (Secondary)  │
│                                 │
│  ┌────────┐      ┌──────────┐   │
│  │OracleDB│      │  Redis   │   │
│  │  Repo  │      │  Cache   │   │
│  └────────┘      └──────────┘   │
└─────────────────────────────────┘
```

---

## 클린 아키텍처

### 개념
Robert C. Martin(Uncle Bob)이 제안한 클린 아키텍처는 소프트웨어를 계층으로 분리하고, 의존성 규칙을 통해 안정성을 확보합니다.

### 계층 구조

```
┌─────────────────────────────────────────────┐
│          Infrastructure Layer               │  ← 가장 불안정 (변경 빈번)
│   (Config, Logger, Monitoring)              │
├─────────────────────────────────────────────┤
│            Adapter Layer                    │
│  (HTTP, DB, Cache, Messaging)               │
├─────────────────────────────────────────────┤
│          Application Layer                  │
│         (Use Cases)                         │
├─────────────────────────────────────────────┤
│           Domain Layer                      │  ← 가장 안정 (변경 드묾)
│    (Entities, Business Rules)               │
└─────────────────────────────────────────────┘

         ↑ 의존성 방향 (안쪽으로만)
```

### 의존성 규칙 (Dependency Rule)

**핵심 원칙**: 의존성은 항상 안쪽(Domain)을 향해야 함

- Infrastructure → Adapter → Application → Domain (✅ 허용)
- Domain → Application (❌ 금지)
- Domain → Adapter (❌ 금지)

### 의존성 역전 원칙 (DIP)

Domain 계층이 Adapter 계층의 구현을 직접 참조하지 않고, Port 인터페이스를 통해 추상화에 의존:

```
Domain (Port 인터페이스 정의)
   ↑
   │ implements
   │
Adapter (Port 구현)
```

---

## ABS 아키텍처 적용

### ABS의 계층 구조

```
demo-abs/
├── internal/
│   ├── domain/              ← Domain Layer (가장 안정)
│   ├── application/         ← Application Layer
│   ├── adapter/             ← Adapter Layer
│   └── infrastructure/      ← Infrastructure Layer (가장 불안정)
└── pkg/                     ← 재사용 가능한 공통 라이브러리
```

### 계층별 역할

#### 1. Domain Layer (`internal/domain/`)
- **책임**: 핵심 비즈니스 로직 및 도메인 규칙
- **주요 구성**:
  - `model/`: Entity 및 Value Object (Route, Comparison, Experiment)
  - `service/`: 도메인 서비스 (ComparisonService, MatchRateCalculator)
  - `port/`: Port 인터페이스 (Repository, Cache, APIClient)
- **의존성**: 없음 (순수 Go 표준 라이브러리만 사용)

#### 2. Application Layer (`internal/application/`)
- **책임**: 유스케이스 오케스트레이션 및 트랜잭션 관리
- **주요 구성**:
  - `usecase/`: 비즈니스 흐름 조합 (RouteUseCase, ExperimentUseCase)
  - `dto/`: HTTP 요청/응답 DTO
- **의존성**: Domain의 Port 인터페이스에만 의존

#### 3. Adapter Layer (`internal/adapter/`)
- **책임**: 외부 시스템 연동 (Port 구현)
- **주요 구성**:
  - `in/http/`: HTTP 요청 처리 (Gin/Echo Handler)
  - `out/persistence/`: OracleDB Repository 구현
  - `out/cache/`: Redis Cache 구현
  - `out/messaging/`: RabbitMQ Publisher/Consumer
  - `out/httpclient/`: Legacy/Modern API 호출
- **의존성**: Domain의 Port 인터페이스를 구현

#### 4. Infrastructure Layer (`internal/infrastructure/`)
- **책임**: 애플리케이션 공통 기능 제공
- **주요 구성**:
  - `config/`: 설정 로딩 (환경변수, YAML)
  - `logger/`: 구조화 로깅 (zerolog, zap)
  - `monitoring/`: 메트릭 수집 (Prometheus)
- **의존성**: 모든 계층에서 사용 가능

#### 5. Pkg Layer (`pkg/`)
- **책임**: 프로젝트 독립적 유틸리티
- **주요 구성**:
  - `jsoncompare/`: JSON 비교 알고리즘
  - `circuitbreaker/`: Circuit Breaker 패턴
  - `masking/`: 개인정보 마스킹
- **의존성**: 외부 라이브러리 및 표준 라이브러리만 사용

---

## 핵심 설계 원칙

### 1. 의존성 역전 원칙 (Dependency Inversion Principle)

**원칙**: 고수준 모듈은 저수준 모듈에 의존하지 않으며, 둘 다 추상화에 의존

**적용 예시**:
- Domain의 `RouteRepository` 인터페이스 (고수준)
- Adapter의 `OracleRouteRepository` 구현 (저수준)
- Application UseCase는 `RouteRepository` 인터페이스에만 의존

### 2. 인터페이스 분리 원칙 (Interface Segregation Principle)

**원칙**: 클라이언트는 사용하지 않는 인터페이스에 의존하지 않아야 함

**적용 예시**:
- 큰 Repository 인터페이스를 작은 역할별 인터페이스로 분리
- `RouteReader`, `RouteWriter` 인터페이스 분리
- 읽기 전용 UseCase는 `RouteReader`만 의존

### 3. 단일 책임 원칙 (Single Responsibility Principle)

**원칙**: 하나의 클래스는 하나의 책임만 가짐

**적용 예시**:
- `ComparisonService`: JSON 비교 로직만 담당
- `MatchRateCalculator`: 일치율 계산만 담당
- `RoutingService`: 라우팅 결정만 담당

### 4. 개방-폐쇄 원칙 (Open-Closed Principle)

**원칙**: 확장에는 열려 있고, 수정에는 닫혀 있음

**적용 예시**:
- 새로운 Adapter 추가 시 Domain/Application 코드 수정 불필요
- GraphQL 지원 시 `GraphQLHandler` Adapter만 추가

### 5. Port/Adapter 분리

**원칙**: 비즈니스 로직과 기술 구현을 명확히 분리

**적용 예시**:
```
Port (인터페이스)           Adapter (구현)
────────────────────       ──────────────────
RouteRepository     ←──    OracleRouteRepository
CacheStore          ←──    RedisCache
APIClient           ←──    HTTPAPIClient
```

### 6. 계층 간 통신 규칙

**규칙**:
1. 각 계층은 바로 아래 계층만 호출
2. 계층을 건너뛰는 호출 금지
3. 상위 계층은 하위 계층을 알지 못함

**금지 사항**:
- ❌ HTTP Handler에서 Domain Service 직접 호출 (UseCase 우회)
- ❌ Domain에서 Adapter 직접 import
- ❌ Application에서 Infrastructure 직접 의존

---

## 아키텍처 검증 기준

### 설계 품질 체크리스트

- [ ] Domain 계층은 외부 라이브러리에 의존하지 않는가?
- [ ] 모든 외부 연동은 Port 인터페이스를 통해 추상화되었는가?
- [ ] Adapter 변경 시 Domain/Application 코드 수정이 필요한가? (필요하면 ❌)
- [ ] UseCase는 단일 책임 원칙을 따르는가?
- [ ] 의존성 방향이 Domain을 향하는가?
- [ ] 순환 참조(Circular Dependency)가 존재하는가? (존재하면 ❌)

### 테스트 가능성 검증

- [ ] Domain Service를 외부 의존성 없이 단위 테스트할 수 있는가?
- [ ] UseCase를 Mock Port를 사용하여 테스트할 수 있는가?
- [ ] Adapter를 독립적으로 통합 테스트할 수 있는가?

---

## 참고 자료

- [Hexagonal Architecture - Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/)
- [The Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
- [Go Project Layout](https://github.com/golang-standards/project-layout)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
