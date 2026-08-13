---
description: 현재 브랜치 변경사항을 qa/<번호> 브랜치로 rebase 후 push, 원래 브랜치로 복귀
allowed-tools: Bash(git:*), Bash(gh:*), AskUserQuestion
---

현재 브랜치의 작업을 QA 브랜치(`qa/<번호>`)로 이전합니다.

인자: $ARGUMENTS

`--yes` 가 포함되어 있으면 4단계의 푸쉬 확인을 생략합니다.
단, **force push는 `--yes` 여도 항상 확인**합니다 (원격 히스토리를 덮어쓰는 작업이므로).

## 단계

### 1. 사전 확인
- `git status` 로 working tree가 깨끗한지 확인
  - 변경사항이 있다면 사용자에게 알리고 commit/stash 여부 확인
- `git branch --show-current` 로 현재 브랜치명 추출 (예: `feat/123`, `fix/45`)
- 브랜치명에서 **번호** 추출:
  - 패턴: `<type>/<number>` → `<number>` 부분
  - 추출 실패하면 사용자에게 직접 번호 입력 요청
- QA 브랜치명 구성: `qa/<번호>` (예: `qa/123`)

### 2. 원격 상태 확인
- `git fetch origin` 으로 원격 동기화
- `git ls-remote --heads origin qa/<번호>` 로 qa 브랜치가 원격에 있는지 확인
- 로컬에 qa 브랜치가 있는지도 확인

### 3. QA 브랜치 준비
**케이스 A: qa/<번호> 가 처음 만드는 경우**
- 사용자에게 "qa/<번호>가 아직 없습니다. 새로 만들까요?" 확인
- 승인 시: 현재 브랜치 기반으로 `git checkout -b qa/<번호>` (즉, 현재 브랜치 그대로 복사)
- 4단계의 푸쉬 전 확인을 거친 뒤 `git push -u origin qa/<번호>` 로 푸쉬
- 원래 브랜치로 복귀하고 종료

**케이스 B: qa/<번호> 가 이미 존재하는 경우**
- 로컬에 없으면: `git checkout -b qa/<번호> origin/qa/<번호>`
- 로컬에 있으면: `git checkout qa/<번호>` 후 `git pull origin qa/<번호>` 로 최신화
- `git rebase <원래브랜치>` 실행 (원래 브랜치의 변경사항을 qa에 올림)
- **충돌 발생 시**:
  - 즉시 중단하고 사용자에게 보고
  - `git rebase --abort` 로 안전하게 롤백할지 묻기
  - 충돌 파일 목록 제시
  - 사용자가 해결할지, abort 후 다른 전략 쓸지 결정 요청

### 4. 푸쉬

**푸쉬 전 확인 (필수)**

푸쉬 직전에 아래를 그대로 보여주고 AskUserQuestion으로 승인받습니다.

```
## 푸쉬 전 확인

대상: origin/qa/<번호>
방식: <케이스 A: 신규 브랜치 생성 (-u) | 케이스 B: force push (--force-with-lease)>
소스 브랜치: <원래브랜치> (HEAD: <sha>)

나갈 커밋:
<케이스 A: git log origin/develop..HEAD --oneline
 케이스 B: git log origin/qa/<번호>..HEAD --oneline>

[케이스 B에만] 덮어써서 사라질 원격 커밋:
<git log HEAD..origin/qa/<번호> --oneline 결과. 비어 있으면 "없음 (fast-forward)">

경고:
- <force push 여부 / 브랜치명이 qa/ 로 시작하는지 재검증 결과 / 사라지는 커밋이 있는지. 없으면 "없음">
```

선택지: `푸쉬` / `중단`
- **푸쉬**: 케이스 A는 `git push -u origin qa/<번호>`,
  케이스 B는 `git push origin qa/<번호> --force-with-lease`
  - `--force` 가 아니라 `--force-with-lease` 사용 (다른 사람 작업 덮어쓰기 방지)
- **중단**: 5단계로 넘어가 원래 브랜치로 복귀하고, 로컬 qa 브랜치는 그대로 남겨둠

`--yes` 인자가 있으면 케이스 A의 확인은 생략합니다.
**케이스 B(force push)는 `--yes` 여도 반드시 확인합니다.**

- 푸쉬 실패 시 원인 분석 후 사용자에게 보고
  - `--force-with-lease` 거절은 그 사이 다른 사람이 원격을 갱신했다는 신호. 임의로 `--force` 로 재시도하지 말고 사용자에게 보고

### 5. 원래 브랜치로 복귀
- `git checkout <원래브랜치>` 로 돌아가기
- 원래 브랜치 상태 확인 (`git status`, `git log -3 --oneline`)

### 6. 꼬임 검증
다음 항목 점검:
- 원래 브랜치 HEAD가 작업 전과 동일한지 (`git rev-parse HEAD` 결과 비교)
- working tree가 깨끗한 상태인지
- 원래 브랜치가 원격과 동기 상태인지 (`git status -sb`)
- qa 브랜치에 현재 브랜치의 최신 커밋이 포함됐는지 (`git log qa/<번호> -5 --oneline`)
- 의도치 않은 detached HEAD 상태가 아닌지

### 7. 결과 보고

```
## QA 이전 완료

- 원래 브랜치: <name> (HEAD: <sha>)
- QA 브랜치: qa/<번호> (HEAD: <sha>)
- 푸쉬: 성공
- 원래 브랜치 복귀: 완료
- 꼬임 검증: 이상 없음 / [발견된 이슈]

다음 액션: <필요시 안내>
```

## 주의사항

- `--force` 단독 사용 금지. 반드시 `--force-with-lease` 사용
- **승인 없이 푸쉬 금지.** force push는 `--yes` 인자가 있어도 예외 없이 확인
- rebase 충돌 시 임의로 해결하지 말고 사용자에게 보고
- working tree에 uncommitted 변경이 있으면 절대 진행 금지
- 번호 추출이 모호하면 사용자에게 확인
- main/develop으로 잘못 force push하는 일이 없도록 브랜치명 한번 더 검증
- 매 단계마다 어떤 명령을 실행하는지 사용자에게 한 줄로 알리고 진행
