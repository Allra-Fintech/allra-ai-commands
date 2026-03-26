# PR 리뷰 코멘트 처리

PR 코멘트를 확인하고, 반영할 것은 코드에 적용, 건너뛸 것은 사유를 댓글로 남깁니다.

## 인자
- `$ARGUMENTS`: PR 번호 (생략 시 현재 브랜치 PR 자동 탐지)

## 워크플로우

### 1. PR 코멘트 수집
- PR 번호 미입력 시 현재 브랜치로 자동 탐지 (`gh pr list --head {branch}`)
- `gh api repos/{owner}/{repo}/pulls/{prNumber}/comments` 로 코멘트 수집
- 이미 resolved된 코멘트는 건너뜀

### 2. 반영 여부 판단
각 코멘트를 다음 기준으로 분류:
- **반영**: 명확한 버그, 보안 문제, 코드 품질 개선
- **스킵**: 취향 차이, 비즈니스 로직 충돌, 범위 밖 작업

사용자에게 분류 결과를 보여주고 확인받기:
```
반영 ({n}건): [파일:라인] 요약
스킵 ({m}건): [파일:라인] 요약 — 사유
```

### 3. 코드 변경 적용
- 반영 항목 순차 적용
- 하나의 커밋으로 묶기:
  ```
  fix: apply PR review feedback

  - {변경사항 요약}
  ```

### 4. 스킵 항목에 댓글 등록
스킵된 각 코멘트에 사유 댓글:
```
gh api repos/{owner}/{repo}/pulls/{prNumber}/comments \
  -X POST -F in_reply_to={commentId} -f body='스킵 사유'
```

### 5. 푸시
- `git push` 후 완료 요약 보고

## 사용 예시
```
/pr-feedback        # 현재 브랜치 PR
/pr-feedback 58     # PR #58
```
