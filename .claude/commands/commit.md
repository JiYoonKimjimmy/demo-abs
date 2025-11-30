# Git 커밋 실행

다음 단계로 Git 커밋을 진행합니다:

1. **변경사항 확인**: `git status`와 `git diff`로 변경된 파일 확인
2. **변경 내용 분석**: 어떤 작업이 완료되었는지 파악
3. **커밋 메시지 작성**: 변경 내용에 맞는 상세한 커밋 메시지 작성
4. **Git 커밋 실행**: `git add`와 `git commit` 실행
5. **커밋 결과 확인**: `git status`로 커밋 완료 확인

## 커밋 메시지 형식

```
<type>: <subject>

## 주요 내용

### <section>
- <detail>
- <detail>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## 타입
- `docs`: 문서 추가/수정
- `feat`: 새로운 기능 추가
- `fix`: 버그 수정
- `refactor`: 코드 리팩토링
- `test`: 테스트 코드
- `chore`: 기타 작업

## 주의사항
- .DS_Store 같은 시스템 파일은 커밋하지 않음
- 민감 정보(.env 등)는 커밋하지 않음
- 변경사항이 없으면 커밋하지 않음
