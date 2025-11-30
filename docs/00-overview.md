# ABS 개발 설계 문서 개요

## 문서 목적

본 문서는 API Bridge Service(ABS)의 상세 설계를 정리하여 개발자가 구현 시 참고할 수 있도록 작성되었습니다.

- **요구사항 문서**: `/requirement.md` - 비즈니스 요구사항 및 비기능 요구사항 정의
- **설계 문서**: `/docs/` - 요구사항 기반 상세 설계 및 구현 가이드

## 대상 독자

- ABS 백엔드 개발자
- 아키텍처 리뷰어
- 신규 합류 개발자 (온보딩)

## 문서 구조

문서는 개발 진행 순서에 따라 **01 ~ 10** 단계로 구성되어 있습니다.
각 디렉토리와 파일은 인덱스 번호를 포함하여 순서대로 읽고 개발할 수 있도록 구성되었습니다.

```
docs/
├── 00-overview.md                           # 본 문서 (문서 전체 개요)
│
├── plan/                                    # 프로젝트 관리 문서
│   ├── 00-development-schedule.md           # 개발 일정 및 마일스톤
│   └── 01-development-checklist.md          # 개발 단계별 체크리스트
│
├── 01-architecture/                         # [Phase 1] 아키텍처 설계
│   ├── 01-architecture-overview.md          # 아키텍처 개요 및 패턴 선택
│   ├── 02-project-structure.md              # 프로젝트 디렉토리 구조
│   ├── 03-layer-design.md                   # 계층별 설계 및 책임
│   └── 04-dependency-injection.md           # 의존성 주입 전략
│
├── 02-domain/                               # [Phase 1] 도메인 모델 설계
│   ├── 01-domain-model.md                   # 도메인 엔티티 및 Value Object
│   ├── 02-domain-service.md                 # 도메인 서비스 (비즈니스 규칙)
│   └── 03-port-interface.md                 # Port 인터페이스 명세
│
├── 03-database/                             # [Phase 1] 데이터베이스 설계
│   ├── 01-schema-design.md                  # 테이블 스키마 정의
│   ├── 02-entity-relationship.md            # ERD 다이어그램
│   └── 03-index-strategy.md                 # 인덱스 및 성능 최적화
│
├── 04-business-logic/                       # [Phase 1] 비즈니스 로직 설계
│   ├── 01-comparison-logic.md               # JSON 비교 알고리즘
│   ├── 02-match-rate-calculation.md         # 일치율 계산 로직
│   ├── 03-routing-strategy.md               # 라우팅 및 전환 전략
│   └── 04-experiment-management.md          # 반자동 전환 실험 관리
│
├── 05-api/                                  # [Phase 2] API 설계
│   ├── 01-rest-api-design.md                # REST API 설계 원칙
│   ├── 02-endpoint-specification.md         # 엔드포인트 상세 명세
│   └── 03-error-response.md                 # 에러 응답 코드 체계
│
├── 06-integration/                          # [Phase 2] 외부 연동 설계
│   ├── 01-legacy-modern-client.md           # Legacy/Modern API 클라이언트
│   ├── 02-redis-cache.md                    # Redis 캐시 전략
│   ├── 03-rabbitmq-messaging.md             # RabbitMQ 메시징 설계
│   └── 04-circuit-breaker.md                # Circuit Breaker 패턴
│
├── 07-security/                             # [Phase 2] 보안 설계
│   ├── 01-data-masking.md                   # 개인정보 마스킹
│   ├── 02-log-security.md                   # 로그 보안 정책
│   └── 03-access-control.md                 # 접근 제어 및 권한
│
├── 08-monitoring/                           # [Phase 3] 모니터링 설계
│   ├── 01-metrics-design.md                 # 메트릭 수집 전략
│   ├── 02-logging-strategy.md               # 로깅 전략
│   └── 03-alert-policy.md                   # 알림 정책
│
├── 09-deployment/                           # [Phase 3] 배포/운영 설계
│   ├── 01-deployment-strategy.md            # 배포 전략
│   ├── 02-configuration.md                  # 설정 관리
│   └── 03-health-check.md                   # Health Check 구현
│
└── 10-development/                          # [Phase 3] 개발 가이드
    ├── 01-coding-convention.md              # 코딩 컨벤션
    ├── 02-testing-guide.md                  # 테스트 가이드
    └── 03-git-workflow.md                   # Git 워크플로우
```

## 개발 단계별 문서 분류

### Phase 1: 설계 단계 (01 ~ 04)

핵심 아키텍처 및 비즈니스 로직을 설계하는 단계입니다.

| 디렉토리 | 설명 | 주요 산출물 |
|---------|------|-----------|
| `01-architecture/` | 전체 아키텍처 구조 및 계층 설계 | 패키지 구조, 의존성 규칙 |
| `02-domain/` | 도메인 모델 및 비즈니스 규칙 정의 | Entity, Value Object, Port 인터페이스 |
| `03-database/` | 데이터베이스 스키마 및 인덱스 설계 | 테이블 정의, ERD |
| `04-business-logic/` | 핵심 비즈니스 로직 상세화 | 알고리즘, 계산식, 상태 머신 |

### Phase 2: 구현 설계 단계 (05 ~ 07)

외부 인터페이스 및 연동, 보안을 설계하는 단계입니다.

| 디렉토리 | 설명 | 주요 산출물 |
|---------|------|-----------|
| `05-api/` | REST API 명세 및 에러 처리 | 엔드포인트 스펙, DTO, 에러 코드 |
| `06-integration/` | 외부 시스템 연동 방법 | HTTP 클라이언트, Redis, RabbitMQ, Circuit Breaker |
| `07-security/` | 보안 정책 및 구현 방법 | 마스킹 규칙, 로그 보안, 권한 관리 |

### Phase 3: 운영 준비 단계 (08 ~ 10)

모니터링, 배포, 개발 프로세스를 정의하는 단계입니다.

| 디렉토리 | 설명 | 주요 산출물 |
|---------|------|-----------|
| `08-monitoring/` | 관찰 가능성 확보 | 메트릭, 로그, 알림 |
| `09-deployment/` | 배포 및 운영 전략 | 배포 절차, 설정 관리, Health Check |
| `10-development/` | 팀 협업 및 개발 가이드 | 코딩 컨벤션, 테스트 전략, Git 전략 |

## 프로젝트 관리 문서 (plan/)

### plan/00-development-schedule.md - 개발 일정 및 마일스톤
- **목적**: 전체 개발 일정 및 주차별 작업 계획 관리
- **내용**:
  - Phase별 개발 기간 (총 12주)
  - 주차별 상세 일정 및 담당자
  - 12개 주요 마일스톤 정의
  - 위험 요소 및 대응 방안
  - 리소스 계획
- **사용 시점**: 프로젝트 킥오프, 주간 스프린트 계획, 진행 상황 점검

### plan/00-phase-checklist.md - 단계별 개발 체크리스트
- **목적**: 각 Phase별 완료 기준 및 진행 상황 추적
- **내용**:
  - Phase별 문서 작성 체크리스트
  - 구현 완료 체크리스트
  - 테스트 완료 체크리스트
  - 리뷰 및 승인 체크리스트
- **사용 시점**: 일일 스탠드업, 주간 리뷰, Phase 완료 검증

## 문서 읽는 순서

### 신규 합류 개발자

1. **요구사항 이해**: `/requirement.md` 전체 읽기
2. **일정 파악**: `plan/00-development-schedule.md` 읽기
3. **아키텍처 파악**: `01-architecture/` → `02-domain/` 순서로 읽기
4. **비즈니스 로직 이해**: `04-business-logic/` 읽기
5. **개발 가이드**: `10-development/` 읽기

### 프로젝트 매니저

1. **전체 일정 확인**: `plan/00-development-schedule.md` 읽기
2. **진행 상황 추적**: `plan/00-phase-checklist.md`에서 체크박스 확인
3. **마일스톤 점검**: 주차별 완료 여부 검증

### 기능 개발 시

1. **체크리스트 확인**: `plan/00-phase-checklist.md`에서 현재 Phase 항목 확인
2. 관련 도메인 확인: `02-domain/`
3. 비즈니스 로직 확인: `04-business-logic/`
4. API 명세 확인: `05-api/`
5. 연동 설계 확인: `06-integration/`
6. **완료 후**: 체크리스트 항목 체크

### 운영 이슈 대응 시

1. 모니터링 지표 확인: `08-monitoring/`
2. 배포 전략 확인: `09-deployment/`
3. 로그 및 보안 정책 확인: `07-security/`

## 문서 작성 원칙

- **간결성**: 핵심 내용만 포함, 불필요한 설명 제거
- **실용성**: 실제 코드 작성 시 참고할 수 있는 구체적 내용 포함
- **일관성**: 용어, 다이어그램 스타일 통일
- **최신성**: 구현과 괴리가 발생하면 즉시 업데이트

## 참조 문서

- [ABS 요구사항 정의서](/requirement.md)
- [Go 공식 문서](https://golang.org/doc/)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
