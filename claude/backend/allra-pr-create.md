---
description: 변경사항 커밋 및 develop 브랜치로 PR 생성 (프로젝트 템플릿 준수)
---

# PR 생성 자동화 커맨드

이 커맨드는 다음을 자동으로 수행합니다:

1. **변경사항 확인 및 커밋**
    - `git status`로 커밋되지 않은 변경사항 확인
    - 변경사항이 있으면 커밋할지 사용자에게 확인
    - 커밋 메시지는 변경사항을 분석하여 **영어로 간결하게** 작성
    - 커밋 메시지는 `.github/PULL_REQUEST_TEMPLATE.md` 양식 준수 (예: "[✨ Feature] Add user authentication")

2. **PR 생성**
    - **develop 브랜치**로 PR 요청
    - PR 제목: **영어**로 작성 (예: "[✨ Feature] Add user authentication")
    - PR 내용: `.github/PULL_REQUEST_TEMPLATE.md` 템플릿 양식 준수(템플릿은 한글 유지, 내용은 **영어로** 작성)
    - PR 생성 전에 PR 제목 사용자에게 확인

## 실행 단계

### 1단계: 변경사항 확인 및 커밋

먼저 `git status`와 `git diff`로 변경사항을 확인합니다.

**변경사항이 있는 경우:**
- **커밋 전 코드 포맷팅**: `./gradlew spotlessApply` 실행(mave)
- 변경사항을 분석하여 적절한 카테고리 선택:
    - [🚀 Release] 릴리즈
    - [✨ Feature] 기능 추가
    - [🐛 Fix] 버그 수정
    - [🚑 HotFix] 긴급 수정
    - [♻️ Refactor] 리팩토링
    - [🔨 Chore] 기타 작업
- 커밋 메시지를 **영어로 간결하게** 작성 (50자 이내 권장)
    - 형식: `[카테고리] 영어 제목\n\n상세 내용(선택)`
    - 예: `[✨ Feature] Add user authentication`
    - 예: `[🐛 Fix] Resolve null pointer in UserService`
- 사용자에게 커밋 제목과 함께 "변경사항을 커밋하시겠습니까?" 확인
- `git add .` 후 `git commit` 실행

### 2단계: PR 생성

**PR 제목 작성 규칙:**
- **영어로** 작성
- 템플릿 양식 준수: `[카테고리] 영어 제목`
- 예: `[✨ Feature] Add user authentication`
- 커밋이 한개인 경우 제목을 커밋 핵심 메시지와 동일하게 작성

**PR 본문 작성 규칙:**
- **한글로** 작성
- `.github/PULL_REQUEST_TEMPLATE.md` 템플릿 준수
- 본문 섹션(관련있는 것만 작성):
    - ✨ 주요 변경 사항
    - 🔍 변경 이유 및 배경
    - 📄 관련 이슈 및 참고 사항
    - ✅ 체크리스트
    - 🧪 테스트 및 검증
    - 📝 배포 후 확인 사항
    - 🛠 추가 변경 사항

**PR 생성:**
```bash
gh pr create --base develop --title "PR 제목" --body "PR 본문"
```

## 중요 사항

- **커밋 메시지**: 영어로 간결하게 핵심만 (50자 이내)
- **PR 제목**: 영어로 간결하게 핵심만 작성 (50자 이내)
- **PR 본문**: 한글로 템플릿 준수
- **base 브랜치**: 항상 `develop`
- **변경사항 분석**: `git diff`를 통해 실제 변경된 파일과 내용을 파악하여 정확한 카테고리와 제목 작성

## 자동화 플로우

1. `git status` 확인
2. 변경사항이 있으면 → **`./gradlew spotlessApply` 실행** → `git add .` → 영어 커밋 메시지 작성 → 사용자에게 커밋 확인 → 커밋
3. 변경사항을 분석하여 PR 제목(영어)과 본문(영어) 생성
4. `gh pr create --base develop` 실행
5. PR URL 반환