---
description: 현재 브랜치 변경사항을 qa/<번호> 브랜치로 rebase 후 push, 원래 브랜치로 복귀
allowed-tools: Bash(git:*), Bash(gh:*)
---

현재 브랜치의 작업을 QA 브랜치(`qa/<번호>`)로 이전합니다.

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
- `git push -u origin qa/<번호>` 로 푸쉬
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
- rebase 성공 시 `git push origin qa/<번호> --force-with-lease` 로 푸쉬
  - `--force` 가 아니라 `--force-with-lease` 사용 (다른 사람 작업 덮어쓰기 방지)
- 푸쉬 실패 시 원인 분석 후 사용자에게 보고

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
- rebase 충돌 시 임의로 해결하지 말고 사용자에게 보고
- working tree에 uncommitted 변경이 있으면 절대 진행 금지
- 번호 추출이 모호하면 사용자에게 확인
- main/develop으로 잘못 force push하는 일이 없도록 브랜치명 한번 더 검증
- 매 단계마다 어떤 명령을 실행하는지 사용자에게 한 줄로 알리고 진행
