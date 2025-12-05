# ABS 개발 단계별 체크리스트

## 체크리스트 사용 가이드

본 문서는 ABS 개발 과정에서 각 단계별로 완료해야 할 항목을 체크리스트로 정리한 문서입니다.

**사용 방법**:
- [ ] 체크박스를 사용하여 완료 여부 표시
- 각 항목은 해당 Phase 완료 전에 모두 체크되어야 함
- 체크리스트를 Git으로 관리하여 진행 상황 추적

---

## Phase 0: 요구사항 정의 (Week 0)

### requirements/ - 요구사항 정의서

#### 문서 작성
- [x] `01-overview.md` 작성 완료
  - [x] 서비스 개요 및 배경
  - [x] 비즈니스 가치
  - [x] 프로젝트 범위 및 목표
  - [x] 주요 이해관계자
  - [x] 인프라 아키텍처 다이어그램
- [x] `02-functional-requirements.md` 작성 완료
  - [x] FR-001: 포트 기반 라우팅
  - [x] FR-002: JSON 비교 로직
  - [x] FR-003: 일치율 계산 및 관리
  - [x] FR-004: 반자동 전환 실험 관리
  - [x] FR-005: 관리 API
  - [x] FR-006: 프록시 기능
- [x] `03-non-functional-requirements.md` 작성 완료
  - [x] NFR-001: 성능 요구사항
  - [x] NFR-002: 가용성 요구사항
  - [x] NFR-003: 확장성 요구사항
  - [x] NFR-004: 보안 요구사항
  - [x] NFR-005: 운영성 요구사항
  - [x] NFR-006: 유지보수성 요구사항
- [x] `04-api-specification.md` 작성 완료
  - [x] 라우트 관리 API (5개)
  - [x] 실험 관리 API (6개)
  - [x] 비교 결과 조회 API (2개)
  - [x] 메트릭 조회 API (2개)
  - [x] 알림 설정 API (4개)
  - [x] Health Check API (3개)
  - [x] 에러 코드 체계
- [x] `05-data-requirements.md` 작성 완료
  - [x] 데이터 모델 ERD
  - [x] 주요 엔티티 정의 (4개)
  - [x] 데이터 흐름
  - [x] 데이터 보관 정책
  - [x] GDPR 준수 요구사항
- [x] `06-constraints-and-assumptions.md` 작성 완료
  - [x] 기술 스택 제약
  - [x] 환경 제약
  - [x] 네트워크 제약
  - [x] 가정사항
  - [x] 알려진 제한사항
  - [x] 향후 확장 계획

#### 리뷰
- [x] 요구사항 정의서 리뷰 완료
- [x] 이해관계자 승인 완료

---

## Phase 1: 설계 단계 (Week 1-3)

### 01-architecture/ - 아키텍처 설계

#### 문서 작성
- [x] `01-architecture-overview.md` 작성 완료
  - [x] 헥사고날 아키텍처 선택 이유 명시
  - [x] 계층별 의존성 다이어그램 포함
- [x] `02-project-structure.md` 작성 완료
  - [x] 전체 디렉토리 구조 정의
  - [x] 각 디렉토리의 역할 설명
- [x] `03-layer-design.md` 작성 완료
  - [x] Domain/Application/Adapter/Infrastructure 계층 책임 정의
  - [x] 계층 간 통신 규칙 명시
- [x] `04-dependency-injection.md` 작성 완료
  - [x] DI 컨테이너 선택 및 초기화 전략
  - [x] 수동 DI 방식 결정

#### 리뷰
- [x] 아키텍처 설계 리뷰 완료
- [x] 팀 전체 승인 완료

---

### 02-domain/ - 도메인 모델 설계

#### 문서 작성
- [x] `01-domain-model.md` 작성 완료
  - [x] Route Entity 정의
  - [x] Comparison Entity 정의
  - [x] Experiment Entity 정의
  - [x] Value Object 정의 (APIRequest, APIResponse 등)
- [x] `02-domain-service.md` 작성 완료
  - [x] ComparisonService 설계
  - [x] MatchRateCalculator 설계
  - [x] RoutingService 설계
  - [x] ExperimentService 설계
- [x] `03-port-interface.md` 작성 완료
  - [x] Repository 인터페이스 정의
  - [x] Cache 인터페이스 정의
  - [x] MessagePublisher 인터페이스 정의
  - [x] APIClient 인터페이스 정의

#### 리뷰
- [x] 도메인 모델 리뷰 완료
- [x] 비즈니스 로직 검증 완료

---

### 03-database/ - 데이터베이스 설계

#### 문서 작성
- [x] `01-schema-design.md` 작성 완료
  - [x] routes 테이블 정의
  - [x] comparisons 테이블 정의
  - [x] experiments 테이블 정의
  - [x] experiment_stages 테이블 정의
- [x] `02-entity-relationship.md` 작성 완료
  - [x] ERD 다이어그램 작성 (Mermaid)
  - [x] 테이블 간 관계 명시
- [x] `03-index-strategy.md` 작성 완료
  - [x] 인덱스 전략 수립
  - [x] 파티셔닝 전략 (comparisons 테이블)

#### 구현
- [x] DDL 스크립트 작성 완료
  - [x] 01-create-tables.sql (테이블 생성)
  - [x] 02-create-triggers.sql (트리거)
  - [x] 03-create-indexes.sql (인덱스)
  - [x] 04-sample-data.sql (샘플 데이터)
  - [x] 05-maintenance.sql (유지보수 쿼리)
- [ ] 개발 환경 DB 구축 완료

#### 리뷰
- [x] DB 설계 리뷰 완료
- [x] DBA 검수 완료

---

### 04-business-logic/ - 비즈니스 로직 설계

#### 문서 작성
- [x] `01-comparison-logic.md` 작성 완료
  - [x] JSON 비교 알고리즘 의사코드
  - [x] 비교 제외 필드 처리 로직
  - [x] 엣지 케이스 정의
- [x] `02-match-rate-calculation.md` 작성 완료
  - [x] 일치율 계산 공식
  - [x] 표본 수 관리 전략
  - [x] 갱신 주기 정의
- [x] `03-routing-strategy.md` 작성 완료
  - [x] 검증/Canary/전환 모드 정의
  - [x] 트래픽 라우팅 의사결정 트리
  - [x] 롤백 정책
- [x] `04-experiment-management.md` 작성 완료
  - [x] 실험 상태 머신 다이어그램
  - [x] 단계별 진행 조건
  - [x] 자동 롤백 트리거 정의

#### 리뷰
- [x] 비즈니스 로직 리뷰 완료
- [x] 알고리즘 검증 완료

---

### Phase 1 완료 체크
- [x] 모든 설계 문서 작성 완료
- [x] 전체 설계 리뷰 및 승인 완료
- [x] Phase 2 진행 가능 상태

---

## Phase 2: 구현 설계 및 개발 (Week 4-8)

### 05-api/ - API 설계

#### 문서 작성
- [x] `01-rest-api-design.md` 작성 완료
  - [x] REST API 설계 원칙 정의
  - [x] 버전 관리 전략
  - [x] CORS 정책
- [x] `02-endpoint-specification.md` 작성 완료
  - [x] 관리 API 명세 (`/abs/api/v1/*`)
  - [x] 모니터링 API 명세
  - [x] Health Check API 명세
  - [x] 각 엔드포인트별 Request/Response DTO
- [x] `03-error-response.md` 작성 완료
  - [x] 에러 코드 체계 정의
  - [x] 에러 응답 포맷
  - [x] HTTP 상태 코드 매핑

#### 구현
- [ ] DTO 구조체 구현 (`internal/application/dto/`)
- [ ] HTTP Handler 구현 (`internal/adapter/in/http/handler/`)
- [ ] 라우터 구성 (`internal/adapter/in/http/router/`)
- [ ] Middleware 구현 (로깅, 에러 핸들링 등)

#### 테스트
- [ ] API 단위 테스트 작성
- [ ] Postman/Swagger 테스트 컬렉션 작성

#### 리뷰
- [x] API 설계 리뷰 완료
- [x] API 명세 승인 완료

---

### 06-integration/ - 외부 연동 설계

#### 문서 작성
- [x] `01-legacy-modern-client.md` 작성 완료
  - [x] HTTP Client 설정 (Timeout, Connection Pool)
  - [x] Retry 전략
  - [x] 에러 처리
- [x] `02-redis-cache.md` 작성 완료
  - [x] 캐시 키 전략
  - [x] TTL 정책
  - [x] Eviction 정책
- [x] `03-rabbitmq-messaging.md` 작성 완료
  - [x] Exchange/Queue 설계
  - [x] Message 포맷
  - [x] Dead Letter Queue 처리
- [x] `04-circuit-breaker.md` 작성 완료
  - [x] Circuit Breaker 설정값
  - [x] Fallback 전략

#### 구현
- [ ] HTTP Client 구현 (`internal/adapter/out/httpclient/`)
- [ ] Redis Cache 구현 (`internal/adapter/out/cache/`)
- [ ] RabbitMQ Publisher/Consumer 구현 (`internal/adapter/out/messaging/`)
- [ ] Circuit Breaker 구현 (`pkg/circuitbreaker/`)

#### 테스트
- [ ] HTTP Client 단위 테스트
- [ ] Redis 통합 테스트
- [ ] RabbitMQ 통합 테스트
- [ ] Circuit Breaker 단위 테스트

#### 리뷰
- [x] 외부 연동 설계 리뷰 완료

---

### 07-security/ - 보안 설계

#### 문서 작성
- [x] `01-data-masking.md` 작성 완료
  - [x] 마스킹 대상 필드 정의
  - [x] 정규식 패턴
  - [x] 마스킹 알고리즘
- [x] `02-log-security.md` 작성 완료
  - [x] 로그 필터링 정책
  - [x] 민감 정보 제거 규칙
  - [x] 로그 파일 접근 권한
- [x] `03-access-control.md` 작성 완료
  - [x] 관리자 권한 체계
  - [x] API 인증/인가 (API Gateway 연동)
  - [x] 감사 로그 정책

#### 구현
- [ ] 개인정보 마스킹 구현 (`pkg/masking/`)
- [ ] 로그 필터링 구현 (`internal/infrastructure/logger/`)
- [ ] 감사 로그 기록 구현

#### 테스트
- [ ] 마스킹 로직 단위 테스트
- [ ] 로그 보안 검증 테스트

#### 리뷰
- [x] 보안 설계 리뷰 완료
- [ ] 보안팀 검수 완료

---

### 도메인 및 애플리케이션 계층 구현

#### Domain 계층 구현
- [ ] Domain Model 구현 (`internal/domain/model/`)
  - [ ] Route Entity
  - [ ] Comparison Entity
  - [ ] Experiment Entity
- [ ] Domain Service 구현 (`internal/domain/service/`)
  - [ ] ComparisonService
  - [ ] MatchRateCalculator
  - [ ] RoutingService
  - [ ] ExperimentService
- [ ] Port 인터페이스 구현 (`internal/domain/port/`)

#### Application 계층 구현
- [ ] UseCase 구현 (`internal/application/usecase/`)
  - [ ] RouteUseCase
  - [ ] ComparisonUseCase
  - [ ] ExperimentUseCase

#### Adapter 계층 구현
- [ ] Repository 구현 (`internal/adapter/out/persistence/`)
  - [ ] OracleRouteRepository
  - [ ] OracleComparisonRepository
  - [ ] OracleExperimentRepository

#### Pkg 유틸리티 구현
- [ ] JSON 비교 구현 (`pkg/jsoncompare/`)
- [ ] 마스킹 구현 (`pkg/masking/`)
- [ ] Circuit Breaker 구현 (`pkg/circuitbreaker/`)

#### 테스트
- [ ] Domain Service 단위 테스트
- [ ] UseCase 단위 테스트
- [ ] Repository 통합 테스트
- [ ] JSON 비교 로직 단위 테스트

---

### Phase 2 완료 체크
- [x] 모든 API 설계 문서 작성 완료
- [x] 모든 연동 설계 문서 작성 완료
- [x] 모든 보안 설계 문서 작성 완료
- [ ] 핵심 기능 구현 완료
- [ ] 단위 테스트 및 통합 테스트 통과
- [ ] 코드 커버리지 80% 이상
- [ ] 코드 리뷰 완료

---

## Phase 3: 운영 준비 및 테스트 (Week 9-11)

### 08-monitoring/ - 모니터링 설계

#### 문서 작성
- [x] `01-metrics-design.md` 작성 완료
  - [x] Prometheus 메트릭 정의
  - [x] 메트릭 수집 주기
  - [x] Grafana 대시보드 설계
- [x] `02-logging-strategy.md` 작성 완료
  - [x] 로그 레벨 정책
  - [x] 구조화 로그 포맷
  - [x] 로그 수집 및 저장 전략
- [x] `03-alert-policy.md` 작성 완료
  - [x] 알림 임계값 정의
  - [x] Slack/Email 알림 템플릿
  - [x] 알림 에스컬레이션 정책

#### 구현
- [ ] Prometheus 메트릭 수집 구현 (`internal/infrastructure/monitoring/`)
- [ ] 구조화 로깅 구현 (`internal/infrastructure/logger/`)
- [ ] Slack 알림 구현
- [ ] Email 알림 구현
- [ ] Grafana 대시보드 구성

#### 테스트
- [ ] 메트릭 수집 검증
- [ ] 알림 발송 테스트

#### 리뷰
- [x] 모니터링 설계 리뷰 완료

---

### 09-deployment/ - 배포/운영 설계

#### 문서 작성
- [x] `01-deployment-strategy.md` 작성 완료
  - [x] Rolling Update 절차
  - [x] Rollback 절차
  - [x] Blue-Green 배포 (선택사항)
- [x] `02-configuration.md` 작성 완료
  - [x] 환경별 설정 관리 (dev/stg/prod)
  - [x] 환경변수 목록
  - [x] Secret 관리 전략
- [x] `03-health-check.md` 작성 완료
  - [x] Liveness Probe 구현
  - [x] Readiness Probe 구현
  - [x] Startup Probe (선택사항)

#### 구현
- [ ] Health Check API 구현
- [ ] Graceful Shutdown 구현
- [ ] 설정 로더 구현 (`internal/infrastructure/config/`)
- [ ] CI/CD 파이프라인 구축
  - [ ] 빌드 자동화
  - [ ] 테스트 자동화
  - [ ] 배포 자동화

#### 테스트
- [ ] Health Check 테스트
- [ ] Graceful Shutdown 테스트
- [ ] 스테이징 환경 배포 테스트

#### 리뷰
- [x] 배포 전략 리뷰 완료
- [ ] DevOps팀 검수 완료

---

### 10-development/ - 개발 가이드

#### 문서 작성
- [x] `01-coding-convention.md` 작성 완료
  - [x] Go 코딩 스타일 가이드
  - [x] 네이밍 규칙
  - [x] 주석 작성 규칙
- [x] `02-testing-guide.md` 작성 완료
  - [x] 단위 테스트 작성 가이드
  - [x] Mock 사용 가이드
  - [x] 통합 테스트 작성 가이드
  - [x] E2E 테스트 작성 가이드
- [x] `03-git-workflow.md` 작성 완료
  - [x] 브랜치 전략 (Git Flow)
  - [x] 커밋 메시지 규칙
  - [x] PR 템플릿
  - [x] 코드 리뷰 체크리스트

#### 리뷰
- [x] 개발 가이드 리뷰 완료
- [ ] 팀 전체 숙지 완료

---

### 성능 및 부하 테스트

#### 성능 테스트
- [ ] 부하 테스트 시나리오 작성
- [ ] 10,000 TPS 목표 달성 검증
- [ ] 응답 시간 목표 달성 검증 (Legacy + 50ms 이내)
- [ ] 50,000 동시 연결 목표 달성 검증

#### 스트레스 테스트
- [ ] 한계점 파악
- [ ] 메모리 누수 검증
- [ ] CPU/메모리 사용률 모니터링

#### 내구성 테스트
- [ ] 24시간 연속 운영 테스트
- [ ] 안정성 검증

#### 성능 최적화
- [ ] 병목 지점 파악 및 개선
- [ ] 캐시 전략 최적화
- [ ] Connection Pool 튜닝

---

### Phase 3 완료 체크
- [x] 모든 모니터링/배포/개발 문서 작성 완료
- [ ] 모니터링 및 로깅 구현 완료
- [ ] CI/CD 파이프라인 구축 완료
- [ ] 성능 목표 달성 (10,000 TPS)
- [ ] 부하/스트레스/내구성 테스트 통과

---

## Phase 4: 최종 검증 및 배포 (Week 12)

### E2E 테스트
- [ ] 전체 시나리오 E2E 테스트 작성
- [ ] 검증 모드 시나리오 테스트
- [ ] Canary 모드 시나리오 테스트
- [ ] 전환 모드 시나리오 테스트
- [ ] 반자동 전환 실험 E2E 테스트
- [ ] 롤백 시나리오 테스트

### 보안 검수
- [ ] 보안 체크리스트 검증
- [ ] 개인정보 마스킹 검증
- [ ] 로그 보안 검증
- [ ] 접근 제어 검증
- [ ] 보안팀 최종 승인

### 운영 준비
- [ ] 운영 매뉴얼 작성
  - [ ] 서비스 시작/중지 절차
  - [ ] 장애 대응 매뉴얼
  - [ ] 롤백 절차
  - [ ] 모니터링 대시보드 사용법
- [ ] 온콜 체계 수립
- [ ] 장애 대응 시뮬레이션

### 배포
- [ ] 스테이징 환경 배포 및 검증
- [ ] 프로덕션 배포 체크리스트 작성
- [ ] 프로덕션 배포 실행
- [ ] 배포 후 헬스 체크 확인
- [ ] 모니터링 지표 정상 확인

### Phase 4 완료 체크
- [ ] E2E 테스트 통과
- [ ] 보안 검수 완료
- [ ] 운영 매뉴얼 작성 완료
- [ ] 프로덕션 배포 성공
- [ ] 서비스 정상 운영 확인

---

## 최종 검증 체크리스트

### 기능 검증
- [ ] 모든 요구사항 구현 완료 확인
- [ ] 모든 API 엔드포인트 동작 확인
- [ ] JSON 비교 로직 정확성 검증
- [ ] 일치율 계산 정확성 검증
- [ ] 반자동 전환 로직 검증

### 비기능 요구사항 검증
- [ ] 성능 목표 달성 (10,000 TPS)
- [ ] 응답 시간 목표 달성 (Legacy + 50ms)
- [ ] 가용성 목표 달성 (99.9%)
- [ ] 동시 연결 목표 달성 (50,000)

### 보안 검증
- [ ] 개인정보 보호 정책 준수
- [ ] GDPR 요구사항 충족
- [ ] 로그 보안 정책 적용
- [ ] 네트워크 보안 설정 완료

### 운영 검증
- [ ] 모니터링 대시보드 구축 완료
- [ ] 알림 정책 적용 완료
- [ ] CI/CD 파이프라인 동작 확인
- [ ] 백업/복구 절차 검증
- [ ] Graceful Shutdown 검증

---

**최종 수정일**: 2025-11-30
**작성자**: ABS 개발팀
