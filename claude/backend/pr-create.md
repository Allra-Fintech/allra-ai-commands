# PR 워크플로우 자동화

현재 변경사항을 기반으로 브랜치 생성, 커밋, 푸시, PR 생성까지 자동으로 수행합니다.

## 인자
- `$ARGUMENTS`: 대상 브랜치 (기본값: develop)

## 워크플로우

### 1단계: 현재 상태 분석
- `git status`로 변경된 파일 목록 확인
- `git diff`로 변경 내용 상세 분석
- 현재 브랜치 확인

### 2단계: 브랜치 생성
- 변경 내용을 분석하여 적절한 브랜치명 생성
- 브랜치 명명 규칙: `feat/`, `fix/`, `refactor/`, `docs/`, `chore/` 등
- 새 브랜치 생성 및 체크아웃

### 3단계: 논리적 단위로 커밋
- 변경사항을 논리적 개발 단위로 분석
- 각 단위별로 별도 커밋 생성
- Conventional Commits 스타일 준수: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:` 등
- 커밋 메시지는 한글로 작성
- Claude Code 서명은 제거

### 4단계: 원격 저장소 푸시
- 생성한 브랜치를 origin에 푸시
- `-u` 플래그로 업스트림 설정

### 5단계: PR 생성
- 대상 브랜치: `$ARGUMENTS` (기본값: develop)
- PR 템플릿 파일이 있으면 해당 형식 준수 (`.github/PULL_REQUEST_TEMPLATE.md`)
- PR 제목과 본문은 변경 내용을 요약하여 작성
- `gh pr create` 명령어 사용

## 주의사항
- 커밋하기 전에 변경 내용을 충분히 검토
- 민감한 정보(credentials, .env 등)가 포함되지 않았는지 확인
- PR 생성 전 원격 브랜치 상태 확인

## 사용 예시
```
/pr-create              # develop으로 PR 생성
/pr-create main         # main으로 PR 생성
/pr-create feature/base # feature/base로 PR 생성
```