# allra-ai-commands

Allra 개발팀을 위한 AI 커스텀 커맨드 저장소입니다.

직무별로 유용한 커맨드를 공유하고, 누구나 쉽게 설치해서 사용할 수 있도록 만들었습니다.

## 설치 방법

### 방법 1: 직무별 전체 설치 (권장)

한 줄로 해당 직무의 모든 커맨드를 설치합니다.

```bash
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- <AI도구> <직무명>
```

**AI 도구**: `claude`, `codex`, `cursor`

**직무명**: `backend`, `frontend`, `data-engineering`, `devops`, `common`

```bash
# 예시: Claude Code의 backend 커맨드 전체 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- claude backend
```

```bash
# 예시: Codex의 common 커맨드 전체 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/install.sh \
  | bash -s -- codex common
```

> 이미 같은 이름의 커맨드가 있으면 `.bak` 파일로 백업 후 덮어씁니다.

### 방법 2: 개별 커맨드 설치

원하는 커맨드만 선택해서 설치합니다.

```bash
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/<AI도구>/<직무명>/<커맨드>.md \
  -o <설치 대상 경로>/<커맨드>.md
```

`<AI도구>`에 따라 설치 경로가 다릅니다.
- `claude`: `~/.claude/commands`
- `codex`: `~/.codex/commands`

```bash
# 예시: Claude Code의 pr-create 커맨드만 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/claude/backend/pr-create.md \
  -o ~/.claude/commands/pr-create.md

# 예시: Codex의 linear 커맨드만 설치
curl -sL https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main/codex/common/linear.md \
  -o ~/.codex/commands/linear.md
```

## 커맨드 목록

### claude

#### backend
- `pr-review.md` - PR 생성 전 변경사항을 사전 검토하는 1차 셀프 리뷰 커맨드입니다.
- `pr-create.md` - 변경사항을 분석하여 브랜치 생성부터 PR 생성까지 자동으로 수행합니다.
- `pr-feedback.md` - PR에 달린 리뷰 코멘트를 분석하고 코드에 반영합니다.
- `allra-pr-create.md` - (올라 스쿼드용) 변경사항을 파악하여 커밋 및 템플릿을 준수하여 PR 생성을 수행합니다.
- `pr-feedback-allra.md` - (올라 스쿼드용) PR 피드백 자동 처리 — CI 수정, CodeRabbit 리뷰 반영, 승인 대기까지 반복 수행.
- `git-issue-allra.md` - (올라 스쿼드용) Git Issue 기반 기능 개발/버그 수정 자동화 및 구현 완료 보고서 등록.

#### frontend
(준비 중)

#### data-engineering
(준비 중)

#### devops
(준비 중)

#### common
- `clean-docs-structure-analysis.md` - 문서 구조 분석 및 최적화 가이드입니다.
- `clean-docs-refine.md` - 문서 정제 및 품질 개선 가이드입니다.
- `clean-docs-category.md` - 문서 분류 및 카테고리화 가이드입니다.
- `linear.md` - Linear 이슈 조회(assignee/state/team/query/limit/sort, 인터랙티브 조회).

### cursor
#### frontend
- `commit.md` - 깃모지와 함께 커밋 메시지를 자동 생성하는 커맨드입니다.
- `pr.md` - 변경사항을 분석하여 GitHub Pull Request를 자동 생성하는 커맨드입니다.

### codex

#### backend
#### frontend
(준비 중)

#### data-engineering
(준비 중)

#### devops
(준비 중)

#### common
- `linear.md` - Linear 이슈 조회(조회 우선 UX, slash command `/linear` 기본형).
