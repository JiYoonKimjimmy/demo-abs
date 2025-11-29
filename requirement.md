# API Bridge Service 요구사항 정의서

## 1. 개요

### 1.1 서비스 목적
API Bridge Service(이하 ABS)는 Legacy API 서비스에서 Modern API 서비스로의 안전한 마이그레이션을 지원하는 중개 서비스입니다.

### 1.2 배경
- Legacy 서비스의 오래된 언어, 프레임워크, 라이브러리 등을 업그레이드한 Modern 서비스의 검증 필요
- Modern 서비스에 대한 적합성, 안정성을 보장하면서 점진적으로 전환
- 무중단 마이그레이션을 통한 서비스 연속성 확보

### 1.3 핵심 기능
- Legacy API와 Modern API의 응답 비교 및 일치율 추적
- 일치율 기반 자동 전환 지원
- API 별 상세 모니터링 및 분석 데이터 제공

### 1.4 인프라 아키텍처
```         
Client → API Gateway → ABS → (sync) Legacy Service
                        ↓
            (async) Modern Service
```

- **API Gateway**: 인증/인가, TLS 암호화, Rate Limiting 처리
- **ABS**: 요청 라우팅, 응답 비교, 일치율 관리
- **Legacy/Modern Service**: 실제 비즈니스 로직 처리

**요청 흐름**:
1. 클라이언트 → API Gateway (인증/인가 처리)
2. API Gateway → ABS (검증된 요청 전달)
3. ABS → Legacy Service (동기 호출, 응답 즉시 반환)
4. ABS → Modern Service (비동기 호출, 응답 비교)

---

## 2. 기능 요구사항

### 2.1 API 라우팅 및 비교

#### 2.1.1 라우팅 전략
- **포트 기반 라우팅**: Legacy와 Modern API는 동일한 호스트에서 서로 다른 포트로 서비스
- **URL 변환 규칙**:
  - Legacy API: `http://api-host:8080/api/v1/resource`
  - Modern API: `http://api-host:9080/api/v1/resource`
  - ABS는 요청 URL의 포트만 변경하여 라우팅
- **경로 및 파라미터**: API 경로(path), 쿼리 파라미터, 헤더는 동일하게 전달
- **HTTP Method**: 요청 메서드(GET, POST, PUT, DELETE 등)는 동일하게 유지
- **포트 설정**: Legacy/Modern 서비스의 포트는 설정 파일에서 관리

#### 2.1.2 요청 처리 흐름
1. API Gateway로부터 요청 수신
2. 요청 URL의 포트를 Legacy 포트로 변경하여 라우팅 (동기)
3. 요청 URL의 포트를 Modern 포트로 변경하여 전송 (비동기)
4. Legacy API 응답을 클라이언트에 즉시 반환
5. 비동기로 두 응답 비교 및 결과 저장

#### 2.1.3 응답 비교 로직
- **형식**: 모든 API 응답은 JSON 형식
- **비교 범위**: JSON의 모든 필드 및 값 일치 여부 검증
- **비교 규칙**:
  - 필드명 대소문자 구분
  - null과 빈 문자열("")은 다른 값으로 처리
  - 숫자 타입과 문자열 타입 구분 (예: 123 ≠ "123")
  - 부동소수점 비교 시 소수점 6자리까지 비교
  - 배열 요소 순서 일치 검증
  - 객체 내 필드 순서는 무시

#### 2.1.4 비교 제외 필드
다음 필드들은 비교 시 제외:
- `timestamp`, `requestId`, `traceId` 등 요청별 고유값
- 응답 생성 시간 관련 필드
- API별로 설정 가능한 제외 필드 목록 지원

### 2.2 일치율 관리

#### 2.2.1 일치율 계산
- **표본 수**: API별로 지정한 표본 수만큼 응답 수집 후 일치율 계산
  - 기본 표본 수: 100개
  - 최소 표본 수: 10개
  - 최대 표본 수: 1,000개
- **계산 방식**: (일치한 필드 수 / 전체 필드 수) × 100
- **갱신 주기**: 실시간 갱신 (매 비교 완료 시)

#### 2.2.2 일치율 임계값
- **검증 단계**: 일치율 < 100% → Legacy API 응답 반환
- **전환 단계**: 일치율 = 100% → Modern API 응답 반환
- **롤백 조건**: 전환 후 일치율 < 99.9% 시 자동 롤백

### 2.3 API 전환 정책

#### 2.3.1 전환 시나리오
1. **검증 모드** (기본): Legacy 응답 반환, Modern 응답 비교만 수행
2. **Canary 모드**: 트래픽의 N%만 Modern 응답 반환 (N은 설정 가능)
3. **전환 모드**: 100% Modern 응답 반환

#### 2.3.2 전환 조건
- 일치율 100% 달성
- 최소 표본 수 이상 수집 완료
- Modern API 에러율 < 0.1%
- Modern API 평균 응답 시간 < Legacy API 평균 응답 시간 × 1.5

#### 2.3.3 롤백 정책
- 자동 롤백 조건: 일치율 < 99.9% 또는 에러율 > 1%
- 수동 롤백: 관리자 대시보드에서 즉시 전환 가능

---

## 3. 비기능 요구사항

### 3.1 성능
- **응답 시간**: Legacy API 응답 시간 + 50ms 이내
- **처리량**: 최소 10,000 TPS (Transactions Per Second)
- **동시 연결**: 최소 50,000 concurrent connections 지원

### 3.2 가용성
- **목표 Uptime**: 99.9% (연간 최대 8.76시간 다운타임)
- **장애 복구**: MTTR(Mean Time To Recovery) < 5분
- **무중단 배포**: Rolling update 지원

### 3.3 확장성
- **수평 확장**: Auto-scaling 지원
  - 최소 인스턴스: 2개
  - 최대 인스턴스: 20개
  - Scale-out 조건: CPU > 70% 또는 메모리 > 80%
  - Scale-in 조건: CPU < 30% 및 메모리 < 50%

### 3.4 신뢰성
- **데이터 정합성**: 비교 결과 데이터 무손실 보장
- **트랜잭션**: DB 트랜잭션 ACID 속성 준수
- **재시도**: Modern API 호출 실패 시 최대 3회 재시도 (Exponential backoff)

---

## 4. 오류 처리

### 4.1 Legacy API 오류
- Legacy API 타임아웃: 30초
- Legacy API 실패 시: 클라이언트에 5xx 에러 반환
- Legacy API 응답 불가 시: ABS 자체 장애로 간주, 알림 발송

### 4.2 Modern API 오류
- Modern API 타임아웃: 30초
- Modern API 실패 시: 비교 수행하지 않고 실패 로그 기록
- Modern API 연속 실패: 3회 이상 연속 실패 시 해당 API 비교 일시 중단 및 알림

### 4.3 비교 로직 오류
- JSON 파싱 실패: 에러 로그 기록, 해당 요청 비교 스킵
- 비교 시간 초과: 10초 초과 시 비교 중단, 타임아웃 기록

### 4.4 Third-Party 서비스 장애
- **Redis 장애**: 캐시 미사용 모드로 전환, 성능 저하 알림
- **RabbitMQ 장애**: 메시지 큐 사용 중단, 동기 처리로 전환
- **OracleDB 장애**: 읽기 전용 모드 전환, 신규 비교 결과 저장 중단

---

## 5. 보안 요구사항

### 5.1 네트워크 보안
- **서비스 위치**: ABS는 내부 네트워크(Private Network)에 배치
- **접근 제어**: API Gateway를 통해서만 ABS 접근 가능
- **방화벽 정책**: 외부에서 ABS로 직접 접근 차단
- **내부 통신**: Legacy/Modern Service와는 내부 네트워크에서만 통신
- **인증/인가**: API Gateway 레벨에서 처리 (ABS는 인증된 요청만 수신)

### 5.2 데이터 보안
- **로그 마스킹**:
  - 개인정보 자동 감지 및 마스킹 (이메일, 전화번호, 주민등록번호 등)
  - 비밀번호, API Key, 토큰 등 민감 정보는 로그에 기록하지 않음
  - 마스킹 대상 필드는 설정 파일에서 관리

### 5.3 서비스 안정성 및 보호

- **Circuit Breaker**:
  - Legacy/Modern API 호출 시 Circuit Breaker 패턴 적용
  - 설정값:
    - 연속 실패 임계값: 5회
    - Open 상태 지속 시간: 30초
    - Half-Open 상태에서 성공 1회 시 Close로 전환
  - Circuit Open 시 알림 발송

- **Timeout 관리**:
  - Legacy API 호출: 30초
  - Modern API 호출: 30초
  - DB 쿼리: 10초
  - Redis 작업: 3초
  - 타임아웃 초과 시 에러 로깅 및 적절한 처리

- **리소스 제한**:
  - Goroutine Pool 크기 제한 (메모리 과다 사용 방지)
  - HTTP Connection Pool 크기 제한
  - 메모리 사용량 모니터링 및 임계값(85%) 초과 시 알림
  - CPU 사용률 모니터링 및 임계값(80%) 초과 시 알림

### 5.4 로그 및 감사

- **로그 보안**:
  - API 요청/응답 로그에서 민감 정보 자동 제거
  - 비교 결과에 개인정보 포함 시 마스킹 처리
  - 로그 파일 접근 권한 제한 (운영자만 읽기 가능)

- **로그 관리**:
  - 중앙 로그 시스템으로 로그 전송 (선택사항)
  - 로그 레벨별 분류 (DEBUG, INFO, WARN, ERROR)
  - 운영 환경에서는 INFO 레벨 이상만 기록

- **감사 로그**:
  - API 전환 모드 변경 이력 기록
  - 설정 변경 이력 기록
  - 관리자 작업 로그 기록

---

## 6. 모니터링 및 알림

### 6.1 핵심 지표 (Metrics)
- **일치율**: API별 실시간 일치율
- **처리량**: TPS, 응답 시간 (p50, p95, p99)
- **에러율**: Legacy/Modern API별 에러율
- **전환율**: API별 전환 진행 상태
- **비교 지연 시간**: Legacy-Modern 응답 비교 소요 시간

### 6.2 대시보드
- 실시간 모니터링 대시보드
- API별 상세 통계
- 일치율 추이 그래프
- 에러 로그 조회 및 필터링

### 6.3 알림
- **알림 채널**: Slack, Email
- **알림 조건**:
  - 일치율 < 95%
  - 에러율 > 1%
  - Modern API 연속 실패 (3회 이상)
  - 시스템 리소스 임계값 초과 (CPU > 80%, Memory > 85%)

---

## 7. 데이터 관리

### 7.1 데이터 보관
- **비교 결과**: 30일간 보관
- **로그**: 7일간 보관 (에러 로그는 30일)
- **통계 데이터**: 1년간 보관 (일별 집계)

### 7.2 개인정보 처리
- 요청/응답에 개인정보 포함 시 자동 감지 및 마스킹
- 로그 저장 전 개인정보 제거
- **GDPR 준수** (General Data Protection Regulation, 유럽 일반 데이터 보호 규정):
  - 개인정보 수집 시 명확한 목적 명시
  - 개인정보는 비교 목적으로만 사용하며, 필요 기간 이후 자동 삭제
  - 사용자 요청 시 개인정보 삭제 기능 제공 (Right to Erasure)
  - 개인정보 처리 내역 로깅 및 감사 추적 가능
  - 데이터 최소화 원칙: 비교에 필요한 최소한의 정보만 저장

### 7.3 백업
- **DB 백업**: 일 1회 전체 백업, 시간별 증분 백업
- **백업 보관**: 30일
- **복구 테스트**: 월 1회 정기 테스트

---

## 8. 기술 스택

### 8.1 개발 환경
- **언어**: Go 1.21 이상
- **웹 프레임워크**: Gin 또는 Echo
- **ORM**: GORM (OracleDB 드라이버 포함)
- **테스트**: Go testing, testify, gomock

### 8.2 인프라
- **배포 환경**: 온프레미스(On-Premise)
- **서버**: Stateless 멀티 인스턴스 구조
- **프로세스 관리**: systemd 또는 Supervisor
- **컨테이너화** (선택사항):
  - Docker 사용 가능 (사내 정책에 따라 제한될 수 있음)
  - Kubernetes 오케스트레이션 (컨테이너 사용 시)

### 8.3 Third-Party 서비스
- **DB**: OracleDB 19c 이상
- **Cache**: Redis 7.x 이상 (Cluster 모드)
- **Messaging**: RabbitMQ 3.x 이상

### 8.4 개발 도구
- **CI/CD**: GitHub Actions 또는 GitLab CI
- **코드 품질**: golangci-lint, gofmt
- **버전 관리**: Git (Semantic Versioning)

---

## 9. 운영 요구사항

### 9.1 배포
- **배포 전략**: Rolling Update (무중단 배포)
- **배포 주기**: 주 1회 정기 배포
- **긴급 패치**: 필요 시 즉시 배포

### 9.2 Health Check
- **Liveness Probe**: `/health/live` (HTTP 200)
- **Readiness Probe**: `/health/ready` (DB/Redis/RabbitMQ 연결 확인)
- **체크 주기**: 10초

### 9.3 Graceful Shutdown
- SIGTERM 수신 시 신규 요청 거부
- 처리 중인 요청 완료 대기 (최대 30초)
- 강제 종료 전 리소스 정리

### 9.4 설정 관리
- 환경변수 기반 설정
- 동적 설정 변경 (재시작 불필요)
  - Rate Limit
  - 표본 수
  - 타임아웃 값
- 민감 정보는 Secret Manager 사용

---

## 10. 테스트 전략

### 10.1 단위 테스트
- 코드 커버리지: 최소 80%
- 모든 비즈니스 로직 테스트 필수

### 10.2 통합 테스트
- Legacy/Modern API Mock 서버 구축
- DB/Redis/RabbitMQ 통합 테스트
- End-to-End 시나리오 테스트

### 10.3 성능 테스트
- 부하 테스트: 목표 TPS의 150% 처리 가능 여부 검증
- 스트레스 테스트: 한계점 파악
- 내구성 테스트: 24시간 연속 운영

---

## 11. API 명세

### 11.0 Context-Path 구분
- **ABS 관리 API**: `/abs/*` - ABS 자체의 관리, 모니터링, Health Check용 API
- **프록시 API**: `/abs/*` 이외의 모든 경로 - Legacy/Modern 서비스로 라우팅되는 비즈니스 API

**라우팅 규칙**:
- `/abs/*` 요청: ABS 내부에서 직접 처리 (프록시하지 않음)
- 그 외 모든 요청: 포트 기반 라우팅을 통해 Legacy/Modern 서비스로 프록시

### 11.1 관리 API
ABS 자체의 설정 및 관리를 위한 API (Context-Path: `/abs`)

- `POST /abs/api/v1/routes`: API 라우트 등록
- `GET /abs/api/v1/routes`: API 라우트 목록 조회
- `PUT /abs/api/v1/routes/{id}`: API 라우트 수정
- `DELETE /abs/api/v1/routes/{id}`: API 라우트 삭제
- `GET /abs/api/v1/routes/{id}/stats`: API별 통계 조회
- `POST /abs/api/v1/routes/{id}/switch`: API 전환 모드 변경

### 11.2 모니터링 API
ABS의 메트릭 및 비교 결과 조회 API (Context-Path: `/abs`)

- `GET /abs/api/v1/metrics`: 전체 메트릭 조회
- `GET /abs/api/v1/metrics/{api_id}`: API별 메트릭 조회
- `GET /abs/api/v1/comparisons`: 비교 결과 조회
- `GET /abs/api/v1/comparisons/{id}`: 비교 결과 상세 조회

### 11.3 Health Check
시스템 상태 확인 API (Context-Path: `/abs`)

- `GET /abs/health/live`: Liveness probe
- `GET /abs/health/ready`: Readiness probe

### 11.4 프록시 API 예시
Legacy/Modern 서비스로 라우팅되는 비즈니스 API 예시

- `GET /api/v1/users` → Legacy: `http://api-host:8080/api/v1/users` / Modern: `http://api-host:9080/api/v1/users`
- `POST /api/v1/orders` → Legacy: `http://api-host:8080/api/v1/orders` / Modern: `http://api-host:9080/api/v1/orders`
- `GET /service/data` → Legacy: `http://api-host:8080/service/data` / Modern: `http://api-host:9080/service/data`

---

## 12. 제약사항 및 가정

### 12.1 제약사항
- Legacy 시스템 수정 불가
- Modern API는 Legacy API와 동일한 HTTP Method 및 엔드포인트 사용
- 모든 API 응답은 JSON 형식만 지원

### 12.2 가정사항
- Legacy API와 Modern API는 동일 네트워크 내 위치
- Legacy API는 안정적으로 운영 중
- Modern API는 충분히 테스트된 상태
- 클라이언트는 ABS를 통해서만 API 호출

---

## 13. 향후 고려사항

### 13.1 확장 기능
- GraphQL API 지원
- gRPC 프로토콜 지원
- 자동화된 A/B 테스트
- ML 기반 응답 패턴 분석

### 13.2 최적화
- 응답 캐싱 전략
- Connection pooling 최적화
- 비교 로직 병렬 처리

---

## 부록

### A. 용어 정의
- **ABS**: API Bridge Service
- **일치율**: Legacy API와 Modern API 응답의 일치 비율
- **표본 수**: 일치율 계산을 위해 수집할 응답 개수
- **전환**: Legacy API에서 Modern API로 응답 소스 변경

### B. 참고 자료
- [Go 공식 문서](https://golang.org/doc/)
- [Gin Framework](https://gin-gonic.com/)
- [Redis 문서](https://redis.io/documentation)
- [RabbitMQ 문서](https://www.rabbitmq.com/documentation.html)
