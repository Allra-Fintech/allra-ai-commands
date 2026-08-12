---
description: PR/이슈 URL을 레포별 배포 방식(프리뷰 라벨 · qa 브랜치)에 맞게 배포하고 결과 보고
argument-hint: "[YYYYMMDD] <PR_URL...>"
---

GitHub PR/이슈 URL 목록을 받아 각 레포의 배포 방식에 맞게 QA 환경을 올리고 결과를 보고합니다.

입력: $ARGUMENTS

> 사용 예 (프리뷰 레포만): `/backend:qa-deploy-allra https://github.com/Allra-Fintech/<repo>/pull/<번호> https://github.com/Allra-Fintech/<repo>/pull/<번호>`
>
> 사용 예 (qa 레포 포함): `/backend:qa-deploy-allra 20260430 https://github.com/Allra-Fintech/<repo>/pull/<번호> https://github.com/Allra-Fintech/<repo>/pull/<번호>`
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

### Step 6: 프리뷰끼리 연결

프리뷰는 앱의 실제 dev 값을 물려받으므로, 그냥 두면 **다른 서비스는 전부 dev를 호출한다.** 이번 실행으로 프리뷰가 2개 이상 떴다면 서로 연결해 준다. 프리뷰가 하나뿐이면 이 단계는 건너뛴다.

**6-1) 호출 관계 판정**

호출하는 쪽 설정에 대상 앱의 dev 주소(`http://<대상앱>.app:`)가 있으면 호출 관계다.

```bash
gh api repos/<owner>/<repo>/contents/src/main/resources/application.yml?ref=<feature-branch> \
  --jq '.content' | base64 -d | grep -n "<대상앱>.app"
```

프론트·파이썬 앱은 설정 파일 위치가 제각각이라 이 grep이 안 먹는다. 아래 6-2의 지원 앱 목록에 있으면 판정을 생략하고 바로 연결한다.

**6-2) 라벨 오버라이드 지원 앱 — 자동 연결**

지원 앱: allra-front · revn-front · revn-admin-front · allra-admin · settlement-calendar · allra-python-scm-crawler

```bash
gh label create <대상앱>-pr:<대상PR번호> --repo <owner>/<repo> --color 0E8A16
gh pr edit <호출PR번호> --repo <owner>/<repo> --add-label <대상앱>-pr:<대상PR번호>
```

라벨 이름은 **호출당하는 서비스 기준**이고, 붙이는 곳은 **호출하는 쪽 PR**이다. 라벨 생성이 "이미 존재"로 실패하면 무시하고 부착만 한다. 60초 안에 반영되며, 붙여 두면 새 커밋을 푸시해도 유지된다.

대상 PR이 이미 머지·클로즈됐으면 연결해도 connection refused가 난다(살아 있는지는 아무도 검사하지 않는다). 대상 프리뷰가 이번 실행에서 함께 뜬 것인지 확인하고 연결한다.

**6-3) Spring API 4종 — ArgoCD UI 절차를 안내**

allra-front-api · allra-usermanage · revn-client-api · revn-admin-api 는 아직 라벨 오버라이드 대상이 아니다(서비스 간 URL이 이미지 안 `application.yml`에 있어 앱별 프로퍼티 등록이 필요하다). 자동 연결이 불가능하므로 아래 절차를 출력한다.

**`kubectl`은 안내하지 않는다.** 개발자에게 클러스터 접근 권한이 없고, 소개자료도 ArgoCD UI 편집만 제시한다.

```
ArgoCD → Application  <호출앱>-preview-<호출PR번호>
       → Deployment   pv-<호출앱>-pr-<호출PR번호>
       → Edit → env 에 아래 추가 → Save

  - name: <ENV_NAME>
    value: http://pv-<대상앱>-pr-<대상PR번호>.app:8080
```

`<ENV_NAME>`은 6-1에서 찾은 프로퍼티 경로를 대문자·언더바로 바꾼 것이다(`internal.usermanage.url` → `INTERNAL_USERMANAGE_URL`). 저장하면 파드가 재시작되고, ArgoCD가 OutOfSync로 표시하지만 self-heal이 꺼져 있어 되돌려지지 않는다.

**이 값은 다음 sync 때 사라진다**는 점을 함께 알린다. 호출하는 쪽에 새 커밋을 푸시하면 이미지 태그가 바뀌며 다시 배포되고, 손으로 넣은 env는 지워진다. 자주 겪을 조합이면 인프라팀에 라벨 오버라이드 등록을 요청하도록 안내한다.

**6-4) 결과 보고**

| 호출하는 쪽 | 대상 | 연결 방법 | 결과 |
|---|---|---|---|
| `<호출앱>` #`<번호>` | `<대상앱>` #`<번호>` | 라벨 `<대상앱>-pr:<번호>` | ✅ 자동 |
| `<호출앱>` #`<번호>` | `<대상앱>` #`<번호>` | env 직접 편집 | ⚠️ 수동 (위 명령어 실행 필요) |

**6-5) 프리뷰 · qa 혼합이면 안내한다**

한 실행에 프리뷰 레포와 qa 브랜치 레포가 섞였고 둘이 호출 관계면, **qa 레포 쪽은 dev를 호출한다.** qa 레포는 dev에 배포되는 것이라 프리뷰가 없고, 라벨도 env 편집도 프리뷰 Application에만 먹으므로 연결할 방법이 없다.

이때 진행을 막거나 방식을 바꾸지 말고 아래를 안내만 한다. 판단은 사용자가 한다.

```
<qa레포> #<번호> 는 dev에 배포되므로 dev의 <대상앱>을 호출합니다.
프리뷰로 올린 <대상앱> #<번호> 의 변경은 여기서 걸리지 않습니다.

  · <qa레포>에서 <대상앱> 변경까지 함께 검증하려면
    → <대상앱> 도 같은 qa/YYYYMMDD 로 올리세요
  · <대상앱> 변경과 무관한 QA면 그대로 진행하셔도 됩니다
```

호출 관계는 6-1과 같은 방식으로 확인된 조합만 안내한다. 확인되지 않은 조합을 호출 관계로 단정하지 않는다.

## 알아둘 것

- 프리뷰는 dev와 **같은 `app` 네임스페이스·같은 DB**를 쓴다. 격리된 환경이 아니므로 데이터를 건드리는 QA는 dev와 동일한 주의가 필요하다
- `DRY_RUN`은 각 앱의 `values-dev`를 그대로 물려받는다
- 프리뷰는 PR이 닫히거나 `preview` 라벨을 떼면 자동으로 사라진다. 따로 정리할 것 없음
- `*.preview.allra.co.kr`은 사내에서만 접근 가능
