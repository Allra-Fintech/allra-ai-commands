---
description: Git Issue 기반 기능 개발/버그 수정 및 구현 완료 보고 (Allra)
argument-hint: "[이슈번호 | report] [report]"
disable-model-invocation: true
---

# Git Issue 작업 자동화 커맨드

Git Issue를 기반으로 요구사항 파악 → 계획 수립 → 구현 → 테스트를 수행합니다.
작업 완료 후 PR이 머지되면 `report` 인자를 지정하여 구현 완료 보고서를 **PR 코멘트**로 등록하고, 설계 문서를 업데이트합니다.

**호출 형식:**

| 호출 | 동작 |
|------|------|
| `/git-issue-allra {이슈번호}` | **작업 모드** — 이슈에서 브랜치 생성 + 구현 |
| `/git-issue-allra {이슈번호} report` | **보고서 모드 (이슈 명시)** — 해당 이슈에 연결된 PR에 보고서 코멘트 등록 |
| `/git-issue-allra report` | **보고서 모드 (자동 감지)** — 현재 브랜치의 PR과 연결 이슈를 자동 탐지하여 보고서 코멘트 등록 |

## 워크플로우

### 0단계: 인자 파싱 및 모드 분기

```bash
ARG1=$(echo "$ARGUMENTS" | awk '{print $1}')
ARG2=$(echo "$ARGUMENTS" | awk '{print $2}')

if [ -z "$ARG1" ]; then
  echo "사용법:"
  echo "  /git-issue-allra {이슈번호}             # 작업 모드"
  echo "  /git-issue-allra {이슈번호} report      # 보고서 모드 (이슈 명시)"
  echo "  /git-issue-allra report                # 보고서 모드 (현재 브랜치 자동 감지)"
  exit 1
fi

# 리포지토리 정보 자동 감지
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
OWNER=$(gh repo view --json owner --jq '.owner.login')
NAME=$(gh repo view --json name --jq '.name')

if [ "$ARG1" = "report" ]; then
  MODE=report
  REPORT_SOURCE=branch
  # ISSUE_NUMBER 는 6단계에서 현재 브랜치 → PR → 연결 이슈로 자동 탐지
elif [ "$ARG2" = "report" ]; then
  MODE=report
  REPORT_SOURCE=issue
  ISSUE_NUMBER=$ARG1
  gh issue view "$ISSUE_NUMBER" --repo "$REPO"
else
  MODE=work
  ISSUE_NUMBER=$ARG1
  gh issue view "$ISSUE_NUMBER" --repo "$REPO"
fi
```

**분기 판단:**

- `MODE = report` → **[보고서 모드]** (6단계로 이동, 사전 조건 검증 필요)
  - `REPORT_SOURCE = branch` 면 현재 브랜치에서 PR과 이슈를 자동 탐지
  - `REPORT_SOURCE = issue` 면 지정된 이슈 번호에 연결된 PR을 사용
- 그 외 → **[작업 모드]** (1단계부터 시작)

---

## [작업 모드] — 기능 개발 / 버그 수정

### 1단계: 브랜치 생성

이슈 제목과 본문을 분석하여 작업 유형을 판단한 뒤, **이슈에 자동 연결되는 원격 브랜치**를 생성하고 로컬로 체크아웃합니다. (GitHub UI의 "Create a branch" 버튼과 동일한 효과로, 이슈 페이지의 Development 섹션에 브랜치가 자동 등록됨)

**작업 유형 판단 기준:**

이슈의 제목, 본문, 라벨 등을 종합적으로 분석하여 아래 유형 중 가장 적합한 것을 선택합니다:

| 작업 유형 | 브랜치 접두사 | 판단 기준 |
|----------|-------------|----------|
| 릴리즈 | `release/` | 버전 배포, 릴리즈 준비 관련 작업 |
| 기능 추가 | `feature/` | 새로운 기능 개발, API 추가 등 |
| 버그 수정 | `fix/` | 기존 기능의 오류/결함 수정, 긴급 수정 포함 |
| 리팩토링 | `refactor/` | 기능 변경 없이 코드 구조/품질 개선 |
| 기타 작업 | `chore/` | 설정 변경, 의존성 업데이트, 문서 작업 등 |

**판단이 애매한 경우:** 사용자에게 이슈 유형을 질문하여 브랜치 접두사를 결정합니다.

**브랜치 이름 규칙:** `{접두사}{이슈번호}-{english-kebab-case-제목}`

- **이슈 제목이 한글인 경우 영어로 번역**하여 사용 (작업 내용을 간결하게 표현하는 영어 키워드 조합)
- 공백→하이픈, 소문자화, 특수문자/이모지/태그 제거
- 너무 길어지지 않도록 핵심 키워드 3~5개 내외로 요약
- 예시: "회원 가입 API 버그 수정" → `fix/902-signup-api-bug`
- 예시: "결제 수단 추가 기능 개발" → `feature/903-add-payment-method`

사용자에게 생성할 브랜치명을 보여주고 확인을 받습니다:

```text
## 브랜치 생성

- 이슈 제목: {이슈 제목}
- 이슈 유형: {태그}
- 브랜치명: `{브랜치명}`

이 브랜치로 작업을 시작할까요?
```

확인 후 아래 순서로 이슈에 연결된 원격 브랜치를 생성합니다:

```bash
set -euo pipefail

# ISSUE_NUMBER는 0단계에서 파싱된 값을 그대로 사용

# 1) 레포/이슈 노드 ID 및 기본 브랜치 조회 (GraphQL 변수 사용으로 쿼리 인젝션 방지)
OWNER=$(gh repo view --json owner --jq '.owner.login')
NAME=$(gh repo view --json name --jq '.name')

IDS=$(gh api graphql \
  -F owner="$OWNER" -F name="$NAME" -F number="$ISSUE_NUMBER" \
  -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    id
    issue(number: $number) { id title }
    defaultBranchRef { name }
  }
}')
REPO_NODE_ID=$(echo "$IDS" | jq -r '.data.repository.id')
ISSUE_NODE_ID=$(echo "$IDS" | jq -r '.data.repository.issue.id')
DEFAULT_BRANCH=$(echo "$IDS" | jq -r '.data.repository.defaultBranchRef.name')

# 2) base 브랜치 결정 (develop 우선, 없으면 기본 브랜치)
BASE_REF=develop
if ! git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="$DEFAULT_BRANCH"
fi
git fetch origin "$BASE_REF"
BASE_OID=$(git rev-parse "origin/$BASE_REF")

# 3) 브랜치명 결정 후 이슈에 연결된 원격 브랜치 생성
BRANCH_NAME="{접두사}${ISSUE_NUMBER}-{english-kebab-case-제목}"

gh api graphql \
  -F issueId="$ISSUE_NODE_ID" \
  -F oid="$BASE_OID" \
  -F name="$BRANCH_NAME" \
  -F repoId="$REPO_NODE_ID" \
  -f query='
mutation($issueId: ID!, $oid: GitObjectID!, $name: String, $repoId: ID) {
  createLinkedBranch(input: {
    issueId: $issueId,
    oid: $oid,
    name: $name,
    repositoryId: $repoId
  }) {
    linkedBranch { ref { name } }
  }
}'

# 4) 로컬 체크아웃 (refs 전파 대비: 전체 fetch 후 원격 추적 브랜치 기준 체크아웃)
git fetch origin
git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
```

**실패 처리:**

- **`already exists` 에러**: 원격에 동일 이름 브랜치가 이미 존재 → mutation을 건너뛰고 `git fetch origin && git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"`만 수행
- **권한 부족 / API 실패**: `git checkout -b "$BRANCH_NAME"` 로컬 fallback 후 사용자에게 "이슈 링크 실패, 수동 연결 필요" 안내
- **OAuth scope**: `gh auth status` 출력에 `repo` (public은 `public_repo`) scope가 있어야 mutation이 허용됨

### 2단계: 요구사항 분석

이슈 본문에서 다음을 파악합니다:

- **배경**: 왜 이 작업이 필요한가
- **작업 목록**: 구체적으로 무엇을 해야 하는가
- **핵심 로직**: 비즈니스 로직 흐름
- **참고 파일**: 기존 코드에서 참고할 부분
- **설계 문서**: 연결된 설계 문서가 있는지 확인

설계 문서가 있으면 반드시 읽고 설계 의도를 파악합니다.

사용자에게 분석 결과를 요약하여 보여줍니다:
```
## 요구사항 분석 결과

### 배경
{이슈 배경 요약}

### 작업 범위
- {작업 항목 1}
- {작업 항목 2}
- ...

### 핵심 로직 흐름
1. {단계 1}
2. {단계 2}
...

### 참고 코드
- {파일}: {역할}
```

### 3단계: 구현 계획 수립

분석 결과를 바탕으로 구현 계획을 세웁니다:

- 참고 파일들을 읽어 기존 코드 패턴과 컨벤션 파악
- 관련 엔티티, 서비스, 컨트롤러 구조 확인
- 변경/생성할 파일 목록과 순서 결정
- 테스트 전략 수립

사용자에게 계획을 보여주고 **확인을 받습니다**.

### 4단계: 구현

계획에 따라 순차적으로 코드를 작성합니다:

- 기존 코드의 패턴과 컨벤션을 **반드시** 따름
- 이슈의 작업 목록을 하나씩 완료
- 설계 문서가 있으면 설계를 준수하되, 실제 코드와 충돌하는 부분은 실제 코드 기준으로 조정
- **설계와 다르게 구현한 부분은 반드시 기록** (완료 보고서에 포함)

### 5단계: 테스트

구현 완료 후 테스트를 수행합니다:

1. **컴파일 확인**: `./gradlew compileJava compileTestJava` (또는 프로젝트에 맞는 빌드 명령)
2. **기존 테스트 실행**: `./gradlew test` — 기존 테스트가 깨지지 않는지 확인
3. **신규 테스트 작성**: 핵심 비즈니스 로직에 대한 단위 테스트 작성
   - 정상 케이스 (happy path)
   - 예외/에러 케이스
   - 엣지 케이스
4. **전체 테스트 재실행**: 신규 테스트 포함하여 전체 통과 확인

테스트 결과를 사용자에게 보고합니다.

### 6단계: 작업 완료 안내

작업이 완료되면 다음을 안내합니다:

```
## 작업 완료

### 변경 파일 목록
- {파일 1}: {변경 내용 요약}
- {파일 2}: {변경 내용 요약}

### 설계 대비 변경사항
- {변경 1}: {이유}

### 테스트 결과
- 전체 테스트: {n}건 통과
- 신규 테스트: {m}건 추가

### 다음 단계
1. `/pr-review` — 셀프 코드 리뷰
2. `/pr-create-allra` — PR 생성
3. PR 머지 후 `/git-issue-allra report` — 현재 브랜치의 PR 코멘트로 완료 보고서 등록 (또는 `/git-issue-allra {이슈번호} report` 로 이슈를 명시)
```

---

## [보고서 모드] — 구현 완료 보고서를 PR 코멘트로 등록

인자에 `report` 가 포함된 경우 수행합니다. (`{이슈번호} report` 또는 단독 `report`)

### 6단계: PR/이슈 탐지, 머지 검증 및 변경사항 분석

`REPORT_SOURCE` 에 따라 PR을 조회하고, (자동 모드인 경우) PR에서 연결된 이슈를 추출한 뒤, 머지 여부를 검증합니다. 조건을 충족하지 않으면 명확한 메시지를 출력한 뒤 종료합니다.

```bash
# 1) PR 조회
if [ "$REPORT_SOURCE" = "branch" ]; then
  BRANCH=$(git branch --show-current)
  PR_JSON=$(gh pr list --head "$BRANCH" --state all \
    --json number,state,mergedAt,url --jq '.[0] // empty')

  if [ -z "$PR_JSON" ]; then
    echo "현재 브랜치 '$BRANCH' 에 연결된 PR을 찾을 수 없습니다. PR을 먼저 생성해주세요."
    exit 1
  fi
else
  PR_JSON=$(gh pr list --search "closes #$ISSUE_NUMBER" --state all \
    --json number,state,mergedAt,url --jq '.[0] // empty')

  if [ -z "$PR_JSON" ]; then
    echo "이슈 #$ISSUE_NUMBER 에 연결된 PR을 찾을 수 없습니다. PR을 먼저 생성해주세요."
    exit 1
  fi
fi

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
PR_MERGED_AT=$(echo "$PR_JSON" | jq -r '.mergedAt')
PR_URL=$(echo "$PR_JSON" | jq -r '.url')

# 2) (자동 모드) PR에 연결된 이슈 자동 탐지
if [ "$REPORT_SOURCE" = "branch" ]; then
  ISSUE_INFO=$(gh api graphql \
    -F owner="$OWNER" -F name="$NAME" -F pr="$PR_NUMBER" \
    -f query='
  query($owner: String!, $name: String!, $pr: Int!) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $pr) {
        closingIssuesReferences(first: 5) {
          nodes { number title }
        }
      }
    }
  }')
  ISSUE_NUMBER=$(echo "$ISSUE_INFO" | jq -r '.data.repository.pullRequest.closingIssuesReferences.nodes[0].number // empty')

  if [ -z "$ISSUE_NUMBER" ]; then
    echo "PR #$PR_NUMBER 에 연결된 이슈를 찾을 수 없습니다. PR 본문에 'closes #이슈번호' 표기를 추가하거나, 이슈를 명시하여 다시 실행해주세요: /git-issue-allra {이슈번호} report"
    exit 1
  fi

  gh issue view "$ISSUE_NUMBER" --repo "$REPO"
fi

# 3) 머지 여부 검증
if [ "$PR_STATE" != "MERGED" ]; then
  echo "PR #$PR_NUMBER 이(가) 아직 머지되지 않았습니다 (현재 상태: $PR_STATE). 머지 후 다시 실행해주세요."
  exit 1
fi

# 4) PR 변경 내용 분석
gh pr diff "$PR_NUMBER"
gh pr view "$PR_NUMBER" --json body,commits
```

- 머지된 PR의 변경 파일, 커밋 이력, PR 본문을 분석
- 이슈 본문의 설계 문서 링크가 있으면 설계 문서 내용도 확인

### 7단계: 구현 완료 보고서 작성

아래 **보고서 템플릿**에 따라 작성합니다. 내용이 없는 섹션은 생략합니다.

```markdown
## ✅ 구현 완료 보고서

> PR: #{PR_NUMBER} | 머지일: {PR_MERGED_AT}

### 📋 작업 요약
{이슈에서 요구한 작업의 핵심을 1~3문장으로 요약}

### 📁 변경 파일
| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `{파일 경로}` | 신규/수정/삭제 | {변경 내용} |

### 🔄 설계 문서 대비 변경사항
{설계 문서와 다르게 구현한 부분을 기술. 각 항목마다 변경 이유를 반드시 포함}

#### {n}. {변경 제목}
- **설계**: {설계 문서의 내용}
- **실제 구현**: {실제로 구현한 내용}
- **변경 이유**: {왜 다르게 구현했는지}

### ⚠️ 주의사항 및 제약조건
{운영/배포 시 주의할 점, 데이터 마이그레이션 필요 여부, 외부 시스템 의존성 등}

### 🧪 테스트 결과
| 구분 | 건수 | 상태 |
|------|------|------|
| 기존 테스트 | {n}건 | ✅ 통과 |
| 신규 테스트 | {m}건 | ✅ 통과 |

{주요 테스트 케이스 나열}
- {테스트 1}: {설명}
- {테스트 2}: {설명}

### 🔗 관련 링크
- PR: #{PR_NUMBER}
- 설계 문서: {설계 문서 링크 (있는 경우)}
```

**보고서 작성 규칙:**
- 모든 내용은 **한글**로 작성
- 내용이 없는 섹션은 **생략** (예: 설계 문서가 없으면 "설계 문서 대비 변경사항" 생략)
- 필요 시 섹션 **추가 가능** (예: DB 스키마 변경, API 스펙 변경 등)
- 사실 기반으로 정확하게 작성 — 추측이나 과장 금지
- 코드 변경의 **이유(why)**를 중심으로 서술

### 8단계: 보고서 등록

작성된 보고서를 사용자에게 먼저 보여주고 확인을 받습니다.
확인 후 **이슈에 연결된 PR 코멘트**로 등록합니다:

```bash
gh pr comment "$PR_NUMBER" --repo "$REPO" --body "{보고서 내용}"
```

`PR_NUMBER` 는 6단계에서 조회한 값을 그대로 사용합니다.

### 9단계: 설계 문서 업데이트 (해당 시)

이슈 본문에 설계 문서 링크가 있고, 설계와 다르게 구현된 부분이 있는 경우:

1. 설계 문서를 읽어옴
2. 변경사항을 설계 문서에 반영
   - 변경된 내용을 실제 구현 기준으로 수정
   - 변경 이력 섹션이 있으면 업데이트 내역 추가
3. 설계 문서 변경사항을 사용자에게 보여주고 확인
4. 확인 후 커밋 & 푸시

---

## 주의사항

- **인자 필수**: 인자 없이 실행하면 사용법 안내 메시지 출력
- **보고서 모드 사전 조건**:
  - `{이슈번호} report`: 해당 이슈에 연결된 PR이 존재하고 머지되어 있어야 함
  - `report` 단독: 현재 브랜치에 연결된 PR이 존재하고, PR에 닫을 이슈가 명시되어 있으며, PR이 머지되어 있어야 함
  - 어느 조건이라도 미충족이면 메시지 출력 후 종료
- **자동 모드 이슈 탐지**: GitHub Development 연결 또는 PR 본문의 `closes #N` / `fixes #N` 등 키워드를 통해 GraphQL `closingIssuesReferences` 로 추출
- **리포지토리 자동 감지**: 현재 디렉토리의 git remote에서 owner/repo 추출
- **사용자 확인**: 계획 수립 후, 보고서 등록 전에 반드시 사용자 확인
- **설계 문서 존중**: 설계 문서가 있으면 최대한 따르되, 실제 코드와 충돌 시 코드 기준으로 조정하고 차이점 기록
- **기존 패턴 준수**: 코드 작성 시 기존 코드베이스의 패턴과 컨벤션을 따름
- **저자/저작권 정보 금지**: 커밋 메시지에 `Co-Authored-By`, `Author` 등 저자 관련 정보 포함 금지

## 사용 예시

```bash
# 1. 이슈 기반 작업 시작 (작업 모드)
/git-issue-allra 902

# 2. (작업 진행: 요구사항 분석 → 계획 → 구현 → 테스트)

# 3. PR 생성 (별도 커맨드)
/pr-create-allra

# 4-A. PR 머지 후, 현재 브랜치에 머물러 있으면 자동 감지로 등록
/git-issue-allra report

# 4-B. 또는 이슈를 명시하여 등록
/git-issue-allra 902 report
```

## 워크플로우 연계

```
이슈 확인 → /git-issue-allra {번호} (작업 모드)
→ /pr-review (셀프 리뷰)
→ /pr-create-allra (PR 생성)
→ /pr-feedback (리뷰 반영)
→ PR 머지
→ /git-issue-allra report  (또는 /git-issue-allra {번호} report)
  → 보고서 모드: PR 코멘트 등록 + 설계 문서 업데이트
```
