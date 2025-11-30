# API Bridge Service (ABS)

안전한 API 마이그레이션을 위한 중개 서비스

## 목차

- [개요](#개요)
- [주요 기능](#주요-기능)
- [아키텍처](#아키텍처)
- [기술 스택](#기술-스택)
- [시작하기](#시작하기)
- [사용 방법](#사용-방법)
- [API 문서](#api-문서)
- [모니터링](#모니터링)
- [개발 가이드](#개발-가이드)
- [테스트](#테스트)
- [배포](#배포)
- [문서](#문서)

---

## 개요

API Bridge Service(ABS)는 Legacy API 서비스에서 Modern API 서비스로의 안전한 마이그레이션을 지원하는 중개 서비스입니다.

### 배경

- Legacy 서비스의 오래된 언어, 프레임워크, 라이브러리를 업그레이드한 Modern 서비스의 검증 필요
- Modern 서비스에 대한 적합성, 안정성을 보장하면서 점진적으로 전환
- 무중단 마이그레이션을 통한 서비스 연속성 확보

### 핵심 가치

- **안전성**: Legacy와 Modern API 응답을 실시간으로 비교하여 100% 일치 시에만 전환
- **점진성**: 반자동 전환 시스템으로 1% → 5% → 10% → 25% → 50% → 100% 단계별 증가
- **가시성**: 실시간 모니터링 대시보드로 일치율, 에러율, 응답시간 추적
- **복원성**: 자동 롤백 시스템으로 문제 발생 시 즉시 이전 상태로 복원

---

## 주요 기능

### 1. 응답 비교 및 일치율 추적

- Legacy API와 Modern API의 JSON 응답을 필드 단위로 비교
- 실시간 일치율 계산 및 추적
- API별 상세 비교 결과 저장 및 분석

### 2. 반자동 전환 시스템

- 트래픽 점진적 증가 전략 (1% → 5% → 10% → 25% → 50% → 100%)
- 조건 충족 시 자동 알림, 관리자 승인 후 진행
- 안전장치(Kill Switch)로 즉시 중단 가능

### 3. 자동 롤백

- 에러율 또는 응답시간 임계값 초과 시 자동 롤백
- 이전 안정 단계로 즉시 복원
- 롤백 원인 및 상세 메트릭 자동 기록

### 4. 실시간 모니터링

- API별 일치율, TPS, 에러율 실시간 추적
- 실험 진행 현황 대시보드
- 이력 타임라인 시각화

### 5. 포트 기반 라우팅

- Legacy API: `http://api-host:8080/api/v1/resource`
- Modern API: `http://api-host:9080/api/v1/resource`
- 동일 경로, 다른 포트로 간편하게 라우팅

---

## 아키텍처

### 시스템 구성도

```
Client → API Gateway → ABS → (sync) Legacy Service
                        ↓
            (async) Modern Service
```

### 요청 흐름

1. 클라이언트 → API Gateway (인증/인가 처리)
2. API Gateway → ABS (검증된 요청 전달)
3. ABS → Legacy Service (동기 호출, 응답 즉시 반환)
4. ABS → Modern Service (비동기 호출, 응답 비교)

### 아키텍처 패턴

- **헥사고날 아키텍처 (Hexagonal Architecture)**
- **클린 아키텍처 (Clean Architecture)**
- Port(인터페이스)와 Adapter(구현체) 분리
- 도메인 계층의 외부 의존성 최소화

### 계층 구조

```
┌─────────────────────────────────────┐
│         Adapter Layer               │
│  (HTTP Handler, gRPC, etc.)         │
├─────────────────────────────────────┤
│       Application Layer             │
│   (Use Cases, Orchestration)        │
├─────────────────────────────────────┤
│         Domain Layer                │
│  (Business Logic, Entities)         │
├─────────────────────────────────────┤
│      Infrastructure Layer           │
│  (DB, Cache, Message Queue)         │
└─────────────────────────────────────┘
```

---

## 기술 스택

### Backend

- **언어**: Go 1.21+
- **웹 프레임워크**: Gin 또는 Echo
- **ORM**: GORM (OracleDB 드라이버 포함)
- **테스트**: Go testing, testify, gomock

### Infrastructure

- **배포 환경**: 온프레미스(On-Premise)
- **데이터베이스**: OracleDB 19c+
- **캐시**: Redis 7.x (Cluster 모드)
- **메시징**: RabbitMQ 3.x+
- **컨테이너**: Docker (선택사항)

### DevOps

- **CI/CD**: GitHub Actions / GitLab CI
- **코드 품질**: golangci-lint, gofmt
- **버전 관리**: Git (Semantic Versioning)

---

## 시작하기

### Prerequisites

- Go 1.21 이상
- OracleDB 19c 이상
- Redis 7.x 이상
- RabbitMQ 3.x 이상

### Installation

```bash
# 저장소 클론
git clone https://github.com/your-org/demo-abs.git
cd demo-abs

# 의존성 설치
go mod download

# 빌드
go build -o abs ./cmd/abs
```

### Configuration

환경 변수 설정:

```bash
# .env 파일 생성
cp .env.example .env
```

주요 설정 항목:

```bash
# Legacy API
LEGACY_API_HOST=api-host
LEGACY_API_PORT=8080

# Modern API
MODERN_API_HOST=api-host
MODERN_API_PORT=9080

# Database
DB_HOST=localhost
DB_PORT=1521
DB_NAME=absdb
DB_USER=abs_user
DB_PASSWORD=your_password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_CLUSTER_MODE=true

# RabbitMQ
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest

# Application
APP_PORT=8000
LOG_LEVEL=info
```

### Running

```bash
# 개발 모드 실행
go run ./cmd/abs

# 프로덕션 모드 실행
./abs
```

---

## 사용 방법

### 1. API 라우트 등록

```bash
curl -X POST http://localhost:8000/abs/api/v1/routes \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/api/v1/users",
    "method": "GET",
    "sampleSize": 100,
    "excludeFields": ["timestamp", "requestId"]
  }'
```

### 2. 반자동 전환 실험 시작

```bash
curl -X POST http://localhost:8000/abs/api/v1/routes/{id}/experiments \
  -H "Content-Type: application/json" \
  -d '{
    "initialPercentage": 1,
    "stabilizationPeriod": 3600
  }'
```

### 3. 실험 상태 조회

```bash
curl http://localhost:8000/abs/api/v1/routes/{id}/experiments/current
```

### 4. 다음 단계 승인

```bash
curl -X POST http://localhost:8000/abs/api/v1/experiments/{experiment_id}/approve \
  -H "Content-Type: application/json" \
  -d '{
    "approvedBy": "admin@example.com",
    "comment": "메트릭 확인 완료"
  }'
```

### 5. 긴급 중단 (Kill Switch)

```bash
curl -X POST http://localhost:8000/abs/api/v1/experiments/{experiment_id}/abort \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Modern API 이상 감지",
    "rollbackTo": "validation"
  }'
```

---

## API 문서

### Context-Path 구분

- **ABS 관리 API**: `/abs/*` - ABS 자체의 관리, 모니터링, Health Check
- **프록시 API**: `/abs/*` 이외의 모든 경로 - Legacy/Modern 서비스로 라우팅

### 주요 엔드포인트

#### 라우트 관리
- `POST /abs/api/v1/routes` - API 라우트 등록
- `GET /abs/api/v1/routes` - API 라우트 목록 조회
- `GET /abs/api/v1/routes/{id}/stats` - API별 통계 조회

#### 실험 제어
- `POST /abs/api/v1/routes/{id}/experiments` - 실험 시작
- `GET /abs/api/v1/routes/{id}/experiments/current` - 현재 실험 상태
- `POST /abs/api/v1/experiments/{experiment_id}/approve` - 단계 승인
- `POST /abs/api/v1/experiments/{experiment_id}/pause` - 실험 일시 정지
- `POST /abs/api/v1/experiments/{experiment_id}/abort` - 실험 중단

#### 모니터링
- `GET /abs/api/v1/metrics` - 전체 메트릭 조회
- `GET /abs/api/v1/comparisons` - 비교 결과 조회

#### Health Check
- `GET /abs/health/live` - Liveness probe
- `GET /abs/health/ready` - Readiness probe

상세한 API 명세는 [API 문서](./docs/11-api-spec.md)를 참조하세요.

---

## 모니터링

### 핵심 지표

- **일치율**: API별 실시간 일치율
- **처리량**: TPS, 응답 시간 (p50, p95, p99)
- **에러율**: Legacy/Modern API별 에러율
- **전환율**: API별 전환 진행 상태

### 대시보드

- 실시간 모니터링 대시보드
- API별 상세 통계
- 실험 관리 대시보드
- 실험 이력 타임라인

### 알림

- **채널**: Slack, Email
- **조건**:
  - 일치율 < 95%
  - 에러율 > 1%
  - Modern API 연속 실패 (3회 이상)
  - 시스템 리소스 임계값 초과
  - 다음 단계 진행 조건 충족
  - 자동 롤백 발생

---

## 개발 가이드

### 프로젝트 구조

```
demo-abs/
├── cmd/                    # 애플리케이션 엔트리포인트
│   └── abs/
│       └── main.go
├── internal/               # 내부 패키지
│   ├── adapter/           # Adapter 계층 (HTTP, gRPC, etc.)
│   │   ├── http/
│   │   └── messaging/
│   ├── application/       # Application 계층 (Use Cases)
│   │   ├── service/
│   │   └── port/
│   ├── domain/            # Domain 계층 (비즈니스 로직)
│   │   ├── entity/
│   │   ├── repository/
│   │   └── service/
│   └── infrastructure/    # Infrastructure 계층
│       ├── database/
│       ├── cache/
│       └── messaging/
├── pkg/                    # 외부 공개 패키지
├── docs/                   # 문서
├── scripts/                # 스크립트
├── configs/                # 설정 파일
└── tests/                  # 통합 테스트
```

### 코딩 컨벤션

- [Go 코딩 스타일 가이드](https://go.dev/doc/effective_go)
- golangci-lint 설정 준수
- 모든 공개 함수/타입에 godoc 주석 작성

### Git 브랜치 전략

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치
- `feature/*`: 기능 개발 브랜치
- `hotfix/*`: 긴급 수정 브랜치

### 커밋 메시지 규칙

```
<type>(<scope>): <subject>

<body>

<footer>
```

Type: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## 테스트

### 단위 테스트

```bash
# 전체 테스트 실행
go test ./...

# 커버리지 확인
go test -cover ./...

# 커버리지 리포트 생성
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

목표 커버리지: **80% 이상**

### 통합 테스트

```bash
# 통합 테스트 실행 (Docker Compose 필요)
docker-compose -f docker-compose.test.yml up -d
go test -tags=integration ./tests/integration/...
```

### 성능 테스트

```bash
# 부하 테스트 (예: k6 사용)
k6 run scripts/load-test.js

# 목표 성능
# - TPS: 10,000+
# - 응답 시간: Legacy + 50ms 이내
# - 동시 연결: 50,000+
```

---

## 배포

### 배포 전략

- **Rolling Update**: 무중단 배포
- **배포 주기**: 주 1회 정기 배포
- **긴급 패치**: 필요 시 즉시 배포

### Health Check

- **Liveness Probe**: `/abs/health/live` (10초 주기)
- **Readiness Probe**: `/abs/health/ready` (10초 주기)

### Graceful Shutdown

- SIGTERM 수신 시 신규 요청 거부
- 처리 중인 요청 완료 대기 (최대 30초)
- 강제 종료 전 리소스 정리

### Auto-scaling

- 최소 인스턴스: 2개
- 최대 인스턴스: 20개
- Scale-out 조건: CPU > 70% 또는 메모리 > 80%
- Scale-in 조건: CPU < 30% 및 메모리 < 50%

---

## 문서

### 설계 문서

- [아키텍처 설계](./docs/design/01-architecture.md)
- [상세 설계](./docs/design/02-detailed-design.md)
- [데이터베이스 설계](./docs/design/03-database-design.md)
- [인터페이스 설계](./docs/design/04-interface-design.md)

### 개발 가이드

- [개발 환경 설정](./docs/development/setup.md)
- [로컬 개발 가이드](./docs/development/local-development.md)
- [테스트 가이드](./docs/development/testing.md)

### 운영 가이드

- [배포 가이드](./docs/operations/deployment.md)
- [모니터링 가이드](./docs/operations/monitoring.md)
- [트러블슈팅](./docs/operations/troubleshooting.md)

### API 명세

- [API 명세서](./docs/11-api-spec.md)
- [OpenAPI Specification](./docs/openapi.yaml)

---

## 성능 목표

- **응답 시간**: Legacy API 응답 시간 + 50ms 이내
- **처리량**: 최소 10,000 TPS
- **동시 연결**: 최소 50,000 concurrent connections
- **가용성**: 99.9% Uptime
- **장애 복구**: MTTR < 5분

---

## 보안

### 네트워크 보안

- ABS는 내부 네트워크(Private Network)에 배치
- API Gateway를 통해서만 접근 가능
- 외부에서 ABS로 직접 접근 차단

### 데이터 보안

- 로그 마스킹 (개인정보, 비밀번호, API Key 등)
- GDPR 준수 (데이터 최소화, Right to Erasure)
- DB 암호화 및 접근 제어

### 서비스 안정성

- Circuit Breaker 패턴 적용
- Timeout 관리 (Legacy/Modern API: 30초)
- 리소스 제한 (Goroutine Pool, Connection Pool)

---

## 라이센스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.

---

## 기여

기여를 환영합니다! 다음 절차를 따라주세요:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

---

## 문의

- 이슈 트래커: [GitHub Issues](https://github.com/your-org/demo-abs/issues)
- 이메일: abs-team@example.com

---

**API Bridge Service** - Safe and Gradual API Migration
