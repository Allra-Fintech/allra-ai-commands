---
description: develop 체크아웃 → 이슈 생성 → 브랜치 생성 → 작업 → 커밋 → 푸쉬 → PR 풀 워크플로
allowed-tools: Bash(git:*), Bash(gh:*), Read, Edit, Write, Grep, Glob
---

이슈 등록부터 PR 생성까지 한 번에 진행하는 풀 워크플로입니다.

작업할 내용: $ARGUMENTS

## 단계

### 1. 사전 확인
- 현재 working tree가 깨끗한지 `git status` 로 확인
- 작업 중인 변경이 있다면 사용자에게 stash/commit 여부 묻기
- `gh auth status` 로 GitHub CLI 인증 확인

### 2. develop 브랜치로 이동 & 동기화
- `git checkout develop` (develop이 없으면 main으로 fallback하고 사용자에게 안내)
- `git pull origin develop` 으로 최신화

### 3. 이슈 컨벤션 파악
다음 순서로 이슈 템플릿/컨벤션을 확인:
- `.github/ISSUE_TEMPLATE/` 디렉터리의 템플릿 파일들 확인
- 루트의 `CONTRIBUTING.md`, `README.md` 에서 이슈 가이드 확인
- `gh issue list --limit 10` 으로 최근 이슈들의 제목/라벨 패턴 학습
- 라벨 목록 확인: `gh label list`

학습한 컨벤션을 사용자에게 한 줄 요약해서 보여주기 (예: "제목 prefix `[FEAT]`, 라벨 `feature` 사용 패턴 발견")

### 4. 이슈 작성 & 등록
- 사용자가 알려준 작업 내용($ARGUMENTS)을 컨벤션에 맞춰 정리
- 이슈 본문은 템플릿이 있으면 따르고, 없으면 다음 구성:
  - **배경/문제**: 왜 이 작업이 필요한가
  - **할 일**: 구체적인 작업 항목
  - **완료 조건**: Definition of Done
- `gh issue create --title "..." --body "..." --label "..."` 로 이슈 등록
- 이슈 번호와 종류(라벨/제목 prefix)를 추출

### 5. 브랜치 생성
- 이슈 종류와 번호로 브랜치명 구성: `<type>/<issue-number>`
  - 예: `feat/123`, `fix/45`, `refactor/67`
  - 프로젝트에 다른 컨벤션이 있으면 그 패턴을 따름 (최근 브랜치들 확인: `git branch -r --sort=-committerdate | head -10`)
- `git checkout -b <type>/<number>` 로 develop에서 분기

### 6. 작업 수행
- $ARGUMENTS 에 명시된 작업을 수행
- 작업이 복잡하면 TaskCreate로 단계 분해
- 코드 변경 후 가능하면 빠르게 동작 확인 (테스트/실행)

### 7. 커밋
- 변경 파일을 명시적으로 staging
- 커밋 메시지는 최근 커밋 스타일 따름 (`git log -5 --oneline`)
- 메시지 끝에 이슈 참조 포함 (예: `Refs #123` 또는 `Closes #123`)
- 큰 변경은 논리적 단위로 여러 커밋으로 분리

### 8. 푸쉬
- `git push -u origin <branch>` 로 원격에 업스트림과 함께 푸쉬

### 9. PR 생성
- PR 템플릿 확인: `.github/pull_request_template.md`
- 제목은 이슈 제목 또는 커밋 메시지 기반으로 작성
- 본문 구성:
  - **연결된 이슈**: `Closes #<번호>`
  - **변경사항**: 무엇을 바꿨는지
  - **테스트 계획**: 어떻게 검증하는지
- base는 develop, head는 작업 브랜치
- `gh pr create --base develop --title "..." --body "..."`

### 10. 결과 정리
- 이슈 URL
- 브랜치명
- PR URL
- 다음 액션 안내 (리뷰어 지정 필요 등)

## 주의사항

- 각 단계에서 실패하면 즉시 중단하고 사용자에게 보고
- 이슈/PR 본문에는 자동생성 멘트 최소화, 핵심 정보 중심
- $ARGUMENTS가 너무 모호하면 작업 시작 전에 사용자에게 명확히 묻기
- 보호 브랜치(develop/main)는 직접 푸쉬하지 않음, 반드시 PR 경유
- 라벨이 컨벤션에 따라 자동 결정되지 않으면 사용자에게 확인
