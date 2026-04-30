---
description: PR/이슈 URL을 각 레포의 qa/YYYYMMDD 브랜치에 머지하고 GitHub Actions 결과 보고
argument-hint: "<YYYYMMDD> <PR_URL...>"
---

GitHub PR/이슈 URL 목록을 받아 각 레포의 qa 브랜치에 머지하고 워크플로우 결과를 보고합니다.

입력: $ARGUMENTS

> 사용 예: `/qa-deploy-allra 20260430 https://github.com/Allra-Fintech/allra-v1-admin/pull/181 https://github.com/Allra-Fintech/allra-front-api/pull/910`
>
> 인자가 비었거나 형식이 어긋나면 즉시 위 사용 예를 보여주고 종료한다.

## 입력 형식

첫 번째 인자는 **QA 날짜** (YYYYMMDD), 나머지는 GitHub PR 또는 Issue URL 목록.

```
/qa-deploy-allra 20260417 <URL1> <URL2> ...
```

QA 브랜치명은 `qa/YYYYMMDD` 로 결정된다.

## 동작 원리

이 커맨드는 **로컬 git을 사용하지 않는다.** 모든 작업을 `gh api`로 GitHub 서버에서 직접 실행한다.
- 로컬 클론, 워크스페이스 디렉토리, sync.sh 의존성 없음
- `gh` CLI 인증만 되어 있으면 어느 디렉토리에서든 동작

## 절차

### Step 1: URL 파싱 및 PR 정보 추출

각 URL에서 `(owner, repo, 종류, 번호)`를 파싱한다:
- **PR URL** (`/<owner>/<repo>/pull/<num>`)
  → `gh pr view <num> --repo <owner>/<repo> --json headRefName,title,state` 로 feature 브랜치명·상태 확인
- **Issue URL** (`/<owner>/<repo>/issues/<num>`)
  → `gh pr list --repo <owner>/<repo> --state open --json number,title,headRefName,body` 에서 해당 이슈를 참조하는 PR을 찾는다 (`closes #<num>`, `fixes #<num>`, `resolves #<num>` 키워드)
  → 관련 PR이 없으면 사용자에게 알리고 스킵

상태가 `CLOSED`(머지 안 된 채 닫힘)인 PR은 사용자에게 알리고 스킵한다.

### Step 2: 작업 계획 요약 + 사용자 확인

요약 테이블을 보여준다:

| 레포 | PR | feature 브랜치 → qa 브랜치 |
|---|---|---|
| (repo) | #(num) (title) | (feature) → qa/YYYYMMDD |

"진행할까요?" 확인 후 다음 단계.

### Step 3: qa 브랜치 보장 + 서버사이드 머지

각 레포별로 순서대로:

**3-1) qa/YYYYMMDD 존재 여부 확인**

```bash
gh api repos/<owner>/<repo>/git/refs/heads/qa/YYYYMMDD
```
- 200 → 이미 존재 (3-2 스킵)
- 404 → 없음 → 3-2로 생성

**3-2) develop 기준으로 qa 브랜치 생성**

```bash
DEVELOP_SHA=$(gh api repos/<owner>/<repo>/git/refs/heads/develop --jq '.object.sha')
gh api repos/<owner>/<repo>/git/refs \
  -f ref="refs/heads/qa/YYYYMMDD" \
  -f sha="$DEVELOP_SHA"
```

**3-3) feature 브랜치를 qa 브랜치에 머지 (서버사이드)**

```bash
gh api repos/<owner>/<repo>/merges \
  -f base="qa/YYYYMMDD" \
  -f head="<feature-branch>" \
  -f commit_message="Merge <feature-branch> into qa/YYYYMMDD"
```

응답 처리:
- `201 Created`: 새 머지 커밋 생성 → ✅ OK
- `204 No Content`: 이미 머지됨 → ⚪ 스킵 (정상)
- `409 Conflict`: 충돌 → ❌ 사용자에게 알림 (해결은 수동, 다음 레포로 계속 진행)
- `404 Not Found`: base 또는 head 브랜치 없음 → ❌ 알림

### Step 4: GitHub Actions 워크플로우 조회

푸시 직후 워크플로우 등록까지 약간의 지연이 있으므로 5초 대기 후, 각 레포에서 qa 브랜치로 트리거된 가장 최근 실행을 조회한다:

```bash
sleep 5
gh run list --repo <owner>/<repo> --branch qa/YYYYMMDD --limit 1 \
  --json workflowName,status,conclusion,url,event
```

상태 표시 매핑:
- `status=queued` 또는 `in_progress` → 🟡 진행 중
- `status=completed` + `conclusion=success` → ✅ 성공
- `status=completed` + `conclusion=failure` → ❌ 실패
- `status=completed` + `conclusion=cancelled` → ⚪ 취소
- 결과 없음 → ➖ (워크플로우 미설정 또는 트리거 조건 미충족)

워크플로우는 끝까지 기다리지 않는다. 즉시 URL만 보고하고 종료.

### Step 5: 결과 보고

| 레포 | qa 브랜치 | 머지 결과 | 워크플로우 | 상태 | Action URL |
|---|---|---|---|---|---|
| (repo) | qa/YYYYMMDD | ✅/⚪/❌ | (workflowName) | 🟡/✅/❌/⚪/➖ | https://github.com/.../actions/runs/(id) |

스킵된 항목(닫힌 PR, 이슈에 연결된 PR 없음, 머지 충돌 등)은 별도 섹션으로 사유와 함께 정리한다.