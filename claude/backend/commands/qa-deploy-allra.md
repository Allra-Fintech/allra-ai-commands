---
description: PR/이슈 URL을 레포별 배포 방식(프리뷰 라벨 · qa 브랜치)에 맞게 배포하고 결과 보고
argument-hint: "[YYYYMMDD] <PR_URL...>"
---

GitHub PR/이슈 URL 목록을 받아 각 레포의 배포 방식에 맞게 QA 환경을 올리고 결과를 보고합니다.

입력: $ARGUMENTS

> 사용 예 (프리뷰 레포만): `/backend:qa-deploy-allra https://github.com/Allra-Fintech/allra-front-api/pull/1025 https://github.com/Allra-Fintech/allra-usermanage/pull/1228`
>
> 사용 예 (qa 레포 포함): `/backend:qa-deploy-allra 20260430 https://github.com/Allra-Fintech/allra-v1-admin/pull/181 https://github.com/Allra-Fintech/allra-front-api/pull/910`
>
> URL이 하나도 없으면 즉시 위 사용 예를 보여주고 종료한다.

## 레포마다 배포 방식이 다르다

레포는 두 부류다. **어느 쪽인지 목록으로 외우지 말고 Step 1에서 매번 판정한다** — 프리뷰로 넘어가는 레포가 계속 늘고 있어 하드코딩한 목록은 금방 낡는다.

| 방식 | 하는 일 | QA 대상 |
|---|---|---|
| **프리뷰** | PR에 `preview` 라벨 부착 | PR별 격리 환경 `https://{app}-pr-{번호}.preview.allra.co.kr` |
| **qa 브랜치** | `qa/YYYYMMDD` 생성 후 feature 머지 | 공용 dev 배포 |

프리뷰 레포도 `development-workflow.yaml`이 `qa/*` 푸시에 걸려 있어 두 방식이 기술적으로 공존하지만, 프리뷰가 가능한 레포는 프리뷰로 보낸다. PR별로 환경이 격리돼 서로 덮어쓰지 않기 때문이다.

## 동작 원리

이 커맨드는 **로컬 git을 사용하지 않는다.** 모든 작업을 `gh api` / `gh` CLI로 GitHub 서버에서 직접 실행한다.
- 로컬 클론, 워크스페이스 디렉토리, sync.sh 의존성 없음
- `gh` CLI 인증만 되어 있으면 어느 디렉토리에서든 동작

## 입력 형식

```
/backend:qa-deploy-allra [YYYYMMDD] <URL1> <URL2> ...
```

- 첫 번째 인자가 8자리 숫자면 **QA 날짜**로 해석하고, 아니면 전부 URL로 본다
- 날짜는 qa 브랜치 방식 레포가 하나라도 있을 때만 필요하다. 날짜 없이 들어왔는데 qa 레포가 섞여 있으면 Step 2에서 사용자에게 날짜를 물은 뒤 진행한다
- qa 브랜치명은 `qa/YYYYMMDD`

## 절차

### Step 1: URL 파싱 + PR 정보 + 배포 방식 판별

각 URL에서 `(owner, repo, 종류, 번호)`를 파싱한다:
- **PR URL** (`/<owner>/<repo>/pull/<num>`)
  → `gh pr view <num> --repo <owner>/<repo> --json headRefName,title,state` 로 feature 브랜치명·상태 확인
- **Issue URL** (`/<owner>/<repo>/issues/<num>`)
  → `gh pr list --repo <owner>/<repo> --state open --json number,title,headRefName,body` 에서 해당 이슈를 참조하는 PR을 찾는다 (`closes #<num>`, `fixes #<num>`, `resolves #<num>` 키워드)
  → 관련 PR이 없으면 사용자에게 알리고 스킵

상태가 `CLOSED`(머지 안 된 채 닫힘)인 PR은 사용자에게 알리고 스킵한다.

이어서 레포별로 **배포 방식을 판정**한다:

```bash
gh api repos/<owner>/<repo>/contents/.github/workflows/preview-workflow.yml?ref=develop --jq '.name'
```

- 200 → **프리뷰 방식**
- 404 → **qa 브랜치 방식**

### Step 2: 작업 계획 요약 + 사용자 확인

| 레포 | PR | 방식 | 처리 내용 |
|---|---|---|---|
| (repo) | #(num) (title) | 프리뷰 | `preview` 라벨 부착 |
| (repo) | #(num) (title) | qa 브랜치 | (feature) → qa/YYYYMMDD |

qa 레포가 있는데 날짜 인자가 없으면 여기서 날짜를 묻는다.

"진행할까요?" 확인 후 다음 단계. **확인 없이 진행하지 않는다** — 실제 배포가 나가는 작업이다.

### Step 3A: 프리뷰 방식 레포

**3A-1) PR 브랜치에 워크플로우가 있는지 확인**

```bash
gh api repos/<owner>/<repo>/contents/.github/workflows/preview-workflow.yml?ref=<feature-branch> --jq '.name'
```

404면 그 브랜치가 preview-workflow.yml 머지 이전에 분기한 것이다. **라벨을 붙여도 워크플로우 자체가 안 돈다**(실패가 아니라 run이 아예 안 생긴다). 사용자에게 알리고 develop 머지를 안내한다:

```
git checkout <feature-branch> && git pull origin develop && git push
```

머지는 사용자가 하도록 안내만 하고, 이 레포는 스킵한다.

**3A-2) `preview` 라벨 보장**

```bash
gh label create preview --repo <owner>/<repo> --description "PR 프리뷰 환경 생성" --color 1D76DB
```

이미 있으면 실패하는데 정상이므로 무시하고 진행한다. 라벨이 레포에 미리 없으면 다음 단계가 `'preview' not found`로 떨어진다.

**3A-3) 라벨 부착**

```bash
gh pr edit <num> --repo <owner>/<repo> --add-label preview
```

이미 붙어 있으면 아무 일도 일어나지 않는다(정상). 이 경우 새 run이 안 생기므로 Step 4에서 기존 run을 보고한다.

**3A-4) 레포에 앱이 여럿이면 앱 라벨도 함께**

`preview` 하나로는 아무것도 빌드되지 않는 레포가 있다:

| 레포 | 함께 붙일 라벨 |
|---|---|
| allra-admin-monorepo | `app:allra-admin` 또는 `app:cargo-admin` |
| revn-backend | `app:revn-client-api` 또는 `app:revn-admin-api` |

어느 앱인지 PR 내용만으로 단정할 수 없으면 사용자에게 묻는다.

### Step 3B: qa 브랜치 방식 레포

**3B-1) qa/YYYYMMDD 존재 여부 확인**

```bash
gh api repos/<owner>/<repo>/git/refs/heads/qa/YYYYMMDD
```
- 200 → 이미 존재 (3B-2 스킵)
- 404 → 없음 → 3B-2로 생성

**3B-2) develop 기준으로 qa 브랜치 생성**

```bash
DEVELOP_SHA=$(gh api repos/<owner>/<repo>/git/refs/heads/develop --jq '.object.sha')
gh api repos/<owner>/<repo>/git/refs \
  -f ref="refs/heads/qa/YYYYMMDD" \
  -f sha="$DEVELOP_SHA"
```

**3B-3) feature 브랜치를 qa 브랜치에 머지 (서버사이드)**

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

트리거 등록까지 약간의 지연이 있으므로 5초 대기 후 조회한다.

**프리뷰 방식**

```bash
sleep 5
gh run list --repo <owner>/<repo> --workflow preview-workflow.yml --limit 1 \
  --json workflowName,status,conclusion,url,headBranch
```

**qa 브랜치 방식**

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
- `conclusion=skipped` → ⚠️ 라벨 게이트에 걸림 (프리뷰 방식에서 라벨 부착이 반영 안 된 신호)
- 결과 없음 → ➖ (워크플로우 미설정 또는 트리거 조건 미충족)

워크플로우는 끝까지 기다리지 않는다. 즉시 URL만 보고하고 종료.

### Step 5: 결과 보고

| 레포 | 방식 | 결과 | 워크플로우 | 상태 | QA 주소 / Action URL |
|---|---|---|---|---|---|
| (repo) | 프리뷰 | ✅ 라벨 부착 | Preview Workflow | 🟡 | https://{app}-pr-{num}.preview.allra.co.kr |
| (repo) | qa/YYYYMMDD | ✅ 머지 | Development Workflow | ✅ | https://github.com/.../actions/runs/(id) |

프리뷰 주소의 `{app}`은 레포명이 아니라 **앱 이름**이다(allra-admin-monorepo → `allra-admin` / `cargo-admin`, revn-backend → `revn-client-api` / `revn-admin-api`). 나머지 레포는 레포명과 같다.

스킵된 항목(닫힌 PR, 이슈에 연결된 PR 없음, 머지 충돌, 브랜치에 preview-workflow.yml 없음)은 별도 섹션으로 사유와 함께 정리한다.

## 알아둘 것

- 프리뷰는 앱의 실제 dev 값을 물려받으므로 **다른 서비스는 전부 dev를 호출한다.** 프리뷰끼리 연결해야 하면 사내 「브랜치별 배포」 소개자료의 06장(TWO WAYS·USAGE)을 참고하도록 안내한다
- 프리뷰는 dev와 **같은 `app` 네임스페이스·같은 DB**를 쓴다. 격리된 환경이 아니므로 데이터를 건드리는 QA는 dev와 동일한 주의가 필요하다
- `DRY_RUN`은 각 앱의 `values-dev`를 그대로 물려받는다
- 프리뷰는 PR이 닫히거나 `preview` 라벨을 떼면 자동으로 사라진다. 따로 정리할 것 없음
- `*.preview.allra.co.kr`은 사내에서만 접근 가능
