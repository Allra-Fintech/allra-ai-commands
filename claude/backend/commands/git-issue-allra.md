---
description: Allra AI Analysis 메인 이슈 기반 멀티 레포 작업 자동화 (서브 이슈 단위 브랜치/PR/보고서)
argument-hint: "[이슈번호 | report] [report]"
disable-model-invocation: true
---

# Git Issue 작업 자동화 커맨드 (Allra 멀티 레포)

`Allra-Fintech/allra-ai-analysis` 의 **메인 이슈**를 기준으로, 연결된 **서브 이슈(다른 레포)** 들을 순차적으로 구현·PR·보고합니다.

작업 환경은 여러 Allra 레포가 형제 디렉토리로 클론된 **멀티모듈 워크스페이스 루트**(예: `~/vscode/allra-backend/`)에서 실행됩니다. 메인 이슈 레포 자체는 로컬 클론이 필요 없습니다 (`gh --repo` 로만 접근).

**호출 형식:**

| 호출 | 동작 |
|------|------|
| `/git-issue-allra {이슈번호}` | 작업 모드 — 서브 이슈를 우선순위대로 한 레포씩 구현 |
| `/git-issue-allra {이슈번호} report` | 보고서 모드 (이슈 명시) — 모든 서브 PR 검증 → 각 PR 보고서 → 메인 이슈 체크리스트 |
| `/git-issue-allra report` | 보고서 모드 (자동 감지) — 현재 브랜치 PR → 메인 이슈 추적, 모호하면 사용자에게 질문 |

---

## 0단계: 인자 파싱 및 모드 분기

Claude Code 인자 치환 규칙에 따라 `$0`, `$1` 로 직접 접근.

- `$0` 이 `report` 면: **보고서 모드 (자동 감지)**. 현재 브랜치의 PR → `closingIssuesReferences` 로 서브 이슈 → 그 서브 이슈가 추적된 `allra-ai-analysis` 메인 이슈를 역추적. 모호하면 사용자에게 메인 이슈 번호를 묻는다.
- `$0` 이 숫자면: 메인 이슈 번호. `$1` 이 `report` 면 **보고서 모드 (이슈 명시)**, 아니면 **작업 모드**.
- 빈 인자면 사용법을 출력하고 종료.

고정값:
```
MAIN_REPO=Allra-Fintech/allra-ai-analysis
ROOT_DIR=$(pwd)      # 워크스페이스 루트. 후속 호출에서 다시 쓰기 위해 /tmp/git-issue-allra-root.txt 로 저장.
```

메인 이슈 번호가 정해지면 즉시 `gh issue view "$ISSUE_NUMBER" --repo "$MAIN_REPO"` 로 본문을 조회한다.

> **셸 상태 영속성**: Claude Code 의 Bash 도구는 호출 간 셸 변수를 유지하지 않습니다 (working directory만 유지). 후속 단계에서 다시 필요한 값은 `/tmp/git-issue-allra-*.txt` 파일로 기록해두고 매 호출에서 읽어옵니다. bash 코드 블록은 절차 표현일 뿐 단일 스크립트가 아닙니다.

---

## 1단계: 메인 이슈 + 서브 이슈 목록 수집 (모든 모드 공통)

메인 이슈 본문과 함께 서브 이슈를 **두 경로**로 모은다:

1. **GraphQL `trackedIssues`** — cross-repo 서브 이슈 (sub-issue 기능 포함)
2. **본문에 직접 링크된 이슈** — `owner/repo#번호` 또는 `https://github.com/owner/repo/issues/번호` 패턴

```bash
MAIN_JSON=$(gh api graphql \
  -F owner=Allra-Fintech -F name=allra-ai-analysis -F number="$ISSUE_NUMBER" \
  -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      id title body
      trackedIssues(first: 50) {
        nodes { number title state body repository { nameWithOwner } }
      }
    }
  }
}')

MAIN_TITLE=$(echo "$MAIN_JSON" | jq -r '.data.repository.issue.title')
MAIN_BODY=$(echo "$MAIN_JSON"  | jq -r '.data.repository.issue.body')

TRACKED=$(echo "$MAIN_JSON" | jq -r '.data.repository.issue.trackedIssues.nodes[]
                                       | "\(.repository.nameWithOwner)#\(.number)"')
LINKED=$(echo "$MAIN_BODY" \
  | grep -oE '([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)|https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+' \
  | sed -E 's|https://github\.com/([^/]+/[^/]+)/issues/([0-9]+)|\1#\2|' || true)

# 합쳐 중복 제거, 메인 자기참조 제외 → 파일에 저장
printf "%s\n%s\n" "$TRACKED" "$LINKED" \
  | grep -v '^$' | sort -u \
  | grep -v "^Allra-Fintech/allra-ai-analysis#${ISSUE_NUMBER}$" \
  > /tmp/git-issue-allra-sub-issues.txt

[ -s /tmp/git-issue-allra-sub-issues.txt ] || {
  echo "메인 이슈 #$ISSUE_NUMBER 에 연결된 서브 이슈가 없습니다. trackedIssues 등록 또는 본문에 'owner/repo#번호' 링크를 추가하세요."
  exit 1
}
```

각 서브 이슈의 상세(제목·본문·체크리스트·라벨)도 `gh issue view {번호} --repo {레포} --json number,title,body,labels,state,url` 로 조회해 사용자에게 요약 제시.

이후 모드별 분기:
- `MODE=work` → 2단계 (작업 모드)
- `MODE=report` → **[보고서 모드]** 섹션 (R-1) 으로 점프

---

## [작업 모드]

### 2단계: 작업 내용 파악 + 복잡도 판단

메인 이슈와 모든 서브 이슈를 읽고 파악:
- 전체 작업 배경/목표
- 서브 이슈별 작업 범위, 체크리스트, 영향 범위
- 레포 간 의존 관계 (예: DB 스키마 → 백엔드 API → 배치/프론트)
- 설계 문서 링크 모두 확인

**복잡도 판단** — 아래 중 하나라도 해당하면 "복잡":
- 서브 이슈 3개 이상이거나 의존 관계 불명확
- 신규 도메인/엔티티/스키마 포함
- 설계 문서에 없는 결정 필요
- 외부 시스템 연동, 마이그레이션, 데이터 백필

| 판단 | 동작 |
|------|------|
| 간단 | 사용자에게 요약·우선순위 보여주고 동의 받은 뒤 3단계로 |
| 복잡 | `EnterPlanMode` 진입 → 전체 작업 계획서 작성 → `ExitPlanMode` 로 사용자 동의 → 3단계로 |

요약 포맷:
```
## 메인 이슈
{제목} (#{번호}, Allra-Fintech/allra-ai-analysis)

## 서브 이슈
1. {레포}#{번호} — {제목}
   - 작업 범위: {요약}  / 체크리스트: {n개}
...

## 복잡도: {간단 | 복잡}
## 제안 작업 순서
1. {레포}#{번호}  (이유: …)
```

### 3단계: 우선순위 결정

메인/서브 이슈의 요구사항·의존 관계를 분석해 작업 순서를 결정하고 사용자에게 확인받는다. 워크스페이스에 클론되지 않은 레포가 순서에 포함되면 사용자에게 클론 안내.

### 4단계: 프로젝트별 순차 작업

`/tmp/git-issue-allra-sub-issues.txt` 의 각 엔트리(`owner/repo#번호`)를 **확정된 순서대로 하나씩** 처리한다. 매 반복마다 처리 중인 엔트리를 사용자에게 명시하고 4-1~4-4 진행, 직전 서브의 PR이 올라간 뒤에만 다음으로.

#### 4-1. 해당 레포 디렉토리로 이동

```bash
ENTRY="<현재 처리 중인 owner/repo#번호>"
SUB_REPO=${ENTRY%#*}
SUB_NUM=${ENTRY##*#}
SUB_REPO_NAME=${SUB_REPO##*/}
ROOT_DIR=$(cat /tmp/git-issue-allra-root.txt)

cd "$ROOT_DIR/$SUB_REPO_NAME" || {
  echo "디렉토리 '$ROOT_DIR/$SUB_REPO_NAME' 가 없습니다. 클론 후 다시 진행하세요."
  exit 1
}
[ -d .git ] || { echo "'$SUB_REPO_NAME' 가 git 리포지토리가 아닙니다."; exit 1; }
```

#### 4-2. 서브 이슈에서 브랜치 생성 (Linked Branch)

GitHub UI 의 "Create a branch" 와 동일하게 서브 이슈의 Development 섹션에 자동 연결되는 브랜치를 생성한다.

```bash
SUB_OWNER=${SUB_REPO%/*}
SUB_NAME=${SUB_REPO##*/}

# 1) 노드 ID + 기본 브랜치 조회
IDS=$(gh api graphql \
  -F owner="$SUB_OWNER" -F name="$SUB_NAME" -F number="$SUB_NUM" \
  -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    id
    issue(number: $number) { id title }
    defaultBranchRef { name }
  }
}')
SUB_REPO_NODE_ID=$(echo "$IDS"  | jq -r '.data.repository.id')
SUB_ISSUE_NODE_ID=$(echo "$IDS" | jq -r '.data.repository.issue.id')
SUB_TITLE=$(echo "$IDS"         | jq -r '.data.repository.issue.title')
DEFAULT_BRANCH=$(echo "$IDS"    | jq -r '.data.repository.defaultBranchRef.name')

# 2) base 브랜치 (develop 우선, 없으면 기본 브랜치)
BASE_REF=develop
git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null 2>&1 || BASE_REF="$DEFAULT_BRANCH"
git fetch origin "$BASE_REF"
BASE_OID=$(git rev-parse "origin/$BASE_REF")

# 3) 브랜치명: {접두사}{서브이슈번호}-{english-kebab-case}
BRANCH_NAME="{접두사}${SUB_NUM}-{english-kebab}"

# 4) 이슈에 연결된 원격 브랜치 생성
gh api graphql \
  -F issueId="$SUB_ISSUE_NODE_ID" -F oid="$BASE_OID" \
  -F name="$BRANCH_NAME" -F repoId="$SUB_REPO_NODE_ID" \
  -f query='
mutation($issueId: ID!, $oid: GitObjectID!, $name: String, $repoId: ID) {
  createLinkedBranch(input: {issueId: $issueId, oid: $oid, name: $name, repositoryId: $repoId}) {
    linkedBranch { ref { name } }
  }
}'

# 5) 로컬 체크아웃
git fetch origin
git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
```

**브랜치 접두사** (서브 이슈 제목/라벨로 매번 판단):

| 유형 | 접두사 |
|------|--------|
| 릴리즈 | `release/` |
| 기능 추가 | `feature/` |
| 버그 수정 | `fix/` |
| 리팩토링 | `refactor/` |
| 기타 (설정/문서/의존성) | `chore/` |

이슈 제목이 한글이면 영문 키워드로 의미 번역 (3~5단어). 예: `fix/902-signup-api-bug`, `feature/903-add-payment-method`.

**실패 처리:**
- `already exists` → mutation 건너뛰고 `git fetch && git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"`
- 권한 부족 / API 실패 → `git checkout -b "$BRANCH_NAME"` 로컬 fallback + "이슈 링크 수동 연결 필요" 안내
- `gh auth status` 출력에 `repo` (public 만이면 `public_repo`) scope 필요

#### 4-3. 구현 + 테스트

- 이슈 본문 / 설계 문서 / 참고 파일을 먼저 읽어 기존 컨벤션·패턴 파악
- 서브 이슈 체크리스트를 하나씩 구현
- 설계와 다르게 구현한 부분은 반드시 기록 (보고서 반영)
- 컴파일 → 기존 테스트 → 신규 테스트 → 전체 테스트 (Gradle 프로젝트면 `./gradlew compileJava compileTestJava && ./gradlew test`, 다른 빌드 도구면 그에 맞게)

#### 4-4. PR 생성 후 다음 서브로

```
{레포}#{서브이슈번호} 구현+테스트 완료
다음:
  1. /pr-review        — 셀프 리뷰
  2. /pr-create-allra  — PR 생성 (closes #{서브이슈번호} 포함)
PR이 올라오면 다음 서브 이슈로 넘어갑니다. 진행할까요?
```

PR 생성 확인 후 루트로 복귀:
```bash
PR_NUM=$(gh pr list --repo "$SUB_REPO" --head "$BRANCH_NAME" --json number --jq '.[0].number')
[ -n "$PR_NUM" ] || { echo "PR 미생성. /pr-create-allra 실행 후 재시도."; exit 1; }
echo "PR 생성 확인: $SUB_REPO#$PR_NUM"
cd "$(cat /tmp/git-issue-allra-root.txt)"
```

#### 4-5. 모든 서브 이슈 완료 후 안내

```
## 모든 서브 이슈 작업 완료
| 레포 | 서브 이슈 | PR | 브랜치 |
| ... | ... | ... | ... |

각 PR이 머지되면: /git-issue-allra {메인이슈번호} report
또는 현재 브랜치에서: /git-issue-allra report
```

---

## [보고서 모드]

### R-0. 메인 이슈 자동 감지 (인자가 `report` 단독인 경우)

`$0 = report` 이고 `$1` 이 비어있으면 메인 이슈 번호가 주어지지 않은 것. 다음 순서로 추적:

1. 현재 브랜치의 PR 조회: `gh pr list --head "$(git branch --show-current)" --state all --json number,repository,url --jq '.[0]'`
2. PR → `closingIssuesReferences` 로 닫는 서브 이슈 확인
3. 그 서브 이슈를 `trackedIssues` 로 가리키는 `allra-ai-analysis` 메인 이슈를 GraphQL 검색
4. 후보가 정확히 1개면 그것을 `ISSUE_NUMBER` 로 사용. 0개 또는 복수면 사용자에게 메인 이슈 번호를 직접 묻는다.

메인 이슈 번호가 확정되면 1단계(서브 이슈 수집)를 수행한 뒤 R-1 로 진행.

### R-1. 서브 이슈마다 PR 머지 검증

서브 이슈마다 GraphQL `closedByPullRequestsReferences` + 타임라인의 `CROSS_REFERENCED_EVENT` 양쪽에서 PR 후보를 모아 가장 최근 머지된 PR을 선택. 결과는 TSV(`레포\t서브번호\tPR번호\tURL\tmergedAt`)로 `/tmp/git-issue-allra-pr-table.tsv` 에 누적 (Bash 호출 간 영속성 보장).

```bash
: > /tmp/git-issue-allra-pr-table.tsv
ALL_MERGED=true

while read -r entry; do
  [ -z "$entry" ] && continue
  SUB_REPO=${entry%#*}; SUB_NUM=${entry##*#}
  SUB_OWNER=${SUB_REPO%/*}; SUB_NAME=${SUB_REPO##*/}

  PR_INFO=$(gh api graphql \
    -F owner="$SUB_OWNER" -F name="$SUB_NAME" -F number="$SUB_NUM" \
    -f query='
  query($owner: String!, $name: String!, $number: Int!) {
    repository(owner: $owner, name: $name) {
      issue(number: $number) {
        closedByPullRequestsReferences(first: 5, includeClosedPrs: true) {
          nodes { number url state mergedAt }
        }
        timelineItems(first: 50, itemTypes: [CROSS_REFERENCED_EVENT]) {
          nodes { ... on CrossReferencedEvent { source { ... on PullRequest { number url state mergedAt } } } }
        }
      }
    }
  }')

  PR_ROW=$(echo "$PR_INFO" | jq -r '
    [.data.repository.issue.closedByPullRequestsReferences.nodes[]?,
     .data.repository.issue.timelineItems.nodes[]?.source]
    | map(select(.number != null))
    | sort_by(.mergedAt // "") | last
    | [(.number // ""), (.state // ""), (.url // ""), (.mergedAt // "")] | @tsv')

  PR_NUMBER=$(echo "$PR_ROW" | cut -f1)
  PR_STATE=$(echo "$PR_ROW"  | cut -f2)
  PR_URL=$(echo "$PR_ROW"    | cut -f3)
  PR_MERGED=$(echo "$PR_ROW" | cut -f4)

  if [ -z "$PR_NUMBER" ]; then
    echo "❌ $entry — 연결된 PR 없음"; ALL_MERGED=false; continue
  fi
  if [ "$PR_STATE" != "MERGED" ]; then
    echo "❌ $entry — PR #$PR_NUMBER 미머지 ($PR_STATE)"; ALL_MERGED=false; continue
  fi
  echo "✅ $entry — PR #$PR_NUMBER 머지됨 ($PR_MERGED)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$SUB_REPO" "$SUB_NUM" "$PR_NUMBER" "$PR_URL" "$PR_MERGED" \
    >> /tmp/git-issue-allra-pr-table.tsv
done < /tmp/git-issue-allra-sub-issues.txt

[ "$ALL_MERGED" = "true" ] || { echo "모든 서브 PR이 머지되어야 보고서 모드를 진행할 수 있습니다."; exit 1; }
```

### R-2. PR 별 보고서 작성 + 일괄 코멘트 등록

서브 이슈마다 PR의 diff/커밋/본문 + 이슈 본문을 분석해 보고서를 작성한다.

```bash
# 분석 입력
while IFS=$'\t' read -r SUB_REPO SUB_NUM PR_NUMBER PR_URL PR_MERGED; do
  [ -z "$SUB_REPO" ] && continue
  gh pr diff    "$PR_NUMBER" --repo "$SUB_REPO"
  gh pr view    "$PR_NUMBER" --repo "$SUB_REPO" --json body,commits,files
  gh issue view "$SUB_NUM"   --repo "$SUB_REPO" --json title,body,url
done < /tmp/git-issue-allra-pr-table.tsv
```

**보고서 템플릿** (내용 없는 섹션은 생략, 모두 한글):

```markdown
## ✅ 구현 완료 보고서

> PR: #{PR_NUMBER} | 머지일: {PR_MERGED}
> 메인 이슈: Allra-Fintech/allra-ai-analysis#{메인이슈번호}
> 서브 이슈: {SUB_REPO}#{SUB_NUM}

### 📋 작업 요약
{1~3문장 요약}

### 📁 변경 파일
| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `{경로}` | 신규/수정/삭제 | {내용} |

### 🔄 설계 문서 대비 변경사항
#### {n}. {제목}
- **설계**: …
- **실제 구현**: …
- **변경 이유**: …

### ⚠️ 주의사항 및 제약조건
{운영/배포 주의점, 마이그레이션, 외부 의존성}

### 🧪 테스트 결과
| 구분 | 건수 | 상태 |
|------|------|------|
| 기존 테스트 | {n}건 | ✅ |
| 신규 테스트 | {m}건 | ✅ |

### 🔗 관련 링크
- 메인 이슈: https://github.com/Allra-Fintech/allra-ai-analysis/issues/{메인이슈번호}
- 서브 이슈: {SUB_ISSUE_URL}
- PR: {PR_URL}
```

작성한 보고서를 **모두 사용자에게 먼저 보여주고 확인**받은 뒤 일괄 등록:

```bash
while IFS=$'\t' read -r SUB_REPO SUB_NUM PR_NUMBER PR_URL PR_MERGED; do
  [ -z "$SUB_REPO" ] && continue
  SAFE_KEY=$(printf '%s' "${SUB_REPO}-${SUB_NUM}" | tr '/' '-')
  gh pr comment "$PR_NUMBER" --repo "$SUB_REPO" --body-file "/tmp/report-${SAFE_KEY}.md"
done < /tmp/git-issue-allra-pr-table.tsv
```

### R-3. 메인 이슈 체크리스트 업데이트

처리 순서:

1. 메인 이슈 본문 재조회 (R-1 시점 이후 변경 가능성):
   ```bash
   gh issue view "$ISSUE_NUMBER" --repo Allra-Fintech/allra-ai-analysis --json body --jq '.body' > /tmp/main-issue-body.md
   ```
2. Claude 가 `/tmp/main-issue-body.md` 를 `Read` / `Edit` 도구로 직접 편집:
   - 자동 매칭: `- [ ]` 로 시작하는 라인 본문에 `{레포}#{서브이슈번호}` (또는 동등한 URL) 가 포함되면 `- [x]` 로 변경
   - 수동 매칭: 위에 해당하지 않는 자유 텍스트(예: "백엔드 API 구현")는 머지된 서브 PR/이슈 제목과 유사한 후보 라인을 사용자에게 제시하고 선택받아 체크
3. 변경 diff 를 사용자에게 보여주고 동의 받음
4. 반영: `gh issue edit "$ISSUE_NUMBER" --repo Allra-Fintech/allra-ai-analysis --body-file /tmp/main-issue-body.md`

> sed 일괄 치환은 정규식 이스케이프 및 서브쉘 변수 전파 문제로 권장하지 않음. `Edit` 도구로 직접 편집할 것.

### R-4. 종료 보고

```
## 보고서 등록 완료
| 레포 | 서브 이슈 | PR | 보고서 | 메인 체크 |
| ... | ... | ... | ✅ | ✅ |

메인 이슈: https://github.com/Allra-Fintech/allra-ai-analysis/issues/{메인이슈번호}
```

---

## 주의사항

- **`report` 단독 호출**: R-0 자동 감지로 메인 이슈 식별. 모호하면 사용자에게 메인 이슈 번호를 묻는다.
- **레포 디렉토리 가정**: 워크스페이스 루트 아래에 각 서브 레포가 `레포명` 디렉토리로 클론되어 있어야 함. 없으면 사용자에게 클론 안내.
- **메인 이슈 레포는 로컬 클론 불필요**: `gh --repo` 로만 접근.
- **루트 디렉토리 복귀**: 서브 레포 작업 후 반드시 `cd "$(cat /tmp/git-issue-allra-root.txt)"`.
- **PR 생성 단계**: 본 커맨드는 PR을 직접 만들지 않고 `/pr-create-allra` 를 호출하도록 안내 — PR 생성 확인 후에만 다음 서브로.
- **보고서 모드 사전 조건**: 모든 서브 PR이 머지되어야 함. 하나라도 미머지면 전체 등록 거부.
- **저자/저작권 정보 금지**: 커밋 메시지·코멘트에 `Co-Authored-By`, `Author` 등 포함 금지.

## 사용 예시

```bash
/git-issue-allra 410           # 작업 모드
/git-issue-allra 410 report    # 보고서 모드 (이슈 명시)
/git-issue-allra report        # 보고서 모드 (자동 감지)
```

## 워크플로우 연계

```
/git-issue-allra {메인번호}
  → 메인+서브 이슈 분석 (allra-ai-analysis)
  → (복잡 시) EnterPlanMode → 사용자 동의
  → 우선순위 결정
  → 서브 이슈마다 반복:
       cd {레포} → createLinkedBranch → 구현+테스트
       → /pr-review → /pr-create-allra → 다음 서브

(모든 PR 머지 후)
/git-issue-allra {메인번호} report   또는   /git-issue-allra report
  → 모든 서브 PR 머지 검증
  → 각 PR 보고서 코멘트
  → 메인 이슈 체크리스트 체크
```
