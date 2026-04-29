# allra-ai-commands

Allra 개발팀을 위한 AI 커스텀 커맨드 저장소입니다.

직무별로 유용한 커맨드를 공유하고, 누구나 쉽게 설치해서 사용할 수 있도록 만들었습니다.

## 설치 방법

### Claude Code — 플러그인 마켓플레이스 (권장)

Claude Code 사용자는 **플러그인 마켓플레이스**로 설치합니다. 한 번 설치하면 이후 레포에 push될 때마다 **다음 세션 시작 시 자동 업데이트**됩니다.

Claude Code 안에서 다음 두 명령을 실행:

```text
/plugin marketplace add Allra-Fintech/allra-ai-commands
/plugin install backend@allra-ai-commands
```

직무별 플러그인:
- `backend@allra-ai-commands` — 백엔드 (Git Issue, PR 생성/피드백/리뷰)
- `common@allra-ai-commands` — 공통 (Linear 이슈 등)

설치 후 커맨드는 네임스페이스가 붙은 형태로 호출합니다:

```text
/backend:pr-create-allra
/backend:pr-feedback-allra
/backend:git-issue-allra
/backend:pr-create
/backend:pr-feedback
/backend:pr-review
/common:linear
```

수동으로 즉시 업데이트하려면:

```text
/plugin update
```

### Cursor / Codex — install.sh

Cursor와 Codex 사용자는 기존 `install.sh` 방식 그대로 사용합니다.

```bash
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- <AI도구> <직무명>
```

**AI 도구**: `cursor`, `codex`

**직무명**: `backend`, `frontend`, `data-engineering`, `devops`, `common`

```bash
# 예시: Cursor의 frontend 커맨드 전체 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- cursor frontend
```

```bash
# 예시: Codex의 common 커맨드 전체 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- codex common
```

> 이미 같은 이름의 커맨드가 있으면 `.bak` 파일로 백업 후 덮어씁니다.

#### 개별 커맨드 설치 (Cursor / Codex)

원하는 커맨드만 선택해서 설치:

```bash
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/<AI도구>/<직무명>/<커맨드>.md \
  -o <설치 대상 경로>/<커맨드>.md
```

`<AI도구>`에 따라 설치 경로:
- `cursor`: `~/.cursor/commands`
- `codex`: `~/.codex/commands`

```bash
# 예시: Codex의 linear 커맨드만 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/codex/common/linear.md \
  -o ~/.codex/commands/linear.md
```

## 커맨드 목록

### claude (플러그인 마켓플레이스)

#### backend
- `pr-review.md` - PR 생성 전 변경사항을 사전 검토하는 1차 셀프 리뷰 커맨드입니다.
- `pr-create.md` - 변경사항을 분석하여 브랜치 생성부터 PR 생성까지 자동으로 수행합니다.
- `pr-feedback.md` - PR에 달린 리뷰 코멘트를 분석하고 코드에 반영합니다.
- `pr-create-allra.md` - (올라 스쿼드용) 변경사항을 파악하여 커밋 및 템플릿을 준수하여 PR 생성을 수행합니다.
- `pr-feedback-allra.md` - (올라 스쿼드용) PR 피드백 자동 처리 — CI 수정, CodeRabbit 리뷰 반영, 승인 대기까지 반복 수행.
- `git-issue-allra.md` - (올라 스쿼드용) Git Issue 기반 기능 개발/버그 수정 자동화 및 구현 완료 보고서 등록.

#### common
- `linear.md` - Linear 이슈 조회(assignee/state/team/query/limit/sort, 인터랙티브 조회).

#### frontend / data-engineering / devops
(준비 중)

### cursor
#### frontend
- `commit.md` - 깃모지와 함께 커밋 메시지를 자동 생성하는 커맨드입니다.
- `pr.md` - 변경사항을 분석하여 GitHub Pull Request를 자동 생성하는 커맨드입니다.

### codex

#### backend / frontend / data-engineering / devops
(준비 중)

#### common
- `linear.md` - Linear 이슈 조회(조회 우선 UX, slash command `/linear` 기본형).

## 마켓플레이스 운영 (메인테이너용)

### 새 커맨드 추가

1. `claude/<role>/commands/<command>.md` 파일을 추가합니다.
2. 커밋 후 `main` 브랜치에 push 합니다.
3. 사용자는 다음 Claude Code 세션 시작 시 자동으로 새 커맨드를 받습니다.

### 새 직무 플러그인 추가

1. `claude/<role>/.claude-plugin/plugin.json` 작성
2. `claude/<role>/commands/` 에 .md 파일들 추가
3. 루트 `.claude-plugin/marketplace.json` 의 `plugins` 배열에 새 항목 추가
4. push

### 버전 정책

`plugin.json` 에 `version` 필드를 **의도적으로 생략**하여 git 커밋 SHA를 버전으로 사용합니다. 즉, 모든 커밋이 자동으로 새 버전으로 인식되어 사용자에게 자동 배포됩니다.

특정 시점에서 사용자에게 강제로 새 버전임을 알리고 싶다면 `plugin.json` 에 `version: "x.y.z"` 를 추가하고 bump 하면 됩니다.
