# Linear 이슈 조회

이 커맨드의 목적은 Linear MCP를 이용해 이슈 조회만 빠르게 수행하는 것입니다.

## 사용 원칙
- 기본 동작은 조회이며, 생성/수정/전환 같은 쓰기 액션은 수행하지 않는다.
- 사람용 기본 출력은 짧고 정렬된 표 형식이다.

## 인자
- `$ARGUMENTS`: 추가 파싱 없이 기본 동작을 포함한 전체 인자 문자열
- 단축 인자:
  - `-t, --team <팀명|팀ID>`
  - `-p, --project <프로젝트명|프로젝트ID>`
  - `-a, --assignee <사용자|me>`
  - `-s, --state <상태>`
  - `-l, --label <라벨>`
  - `-q, --query <검색어>`
  - `-n, --limit <숫자>` (기본 20)
  - `--sort <컬럼>` (기본 updatedAt desc)
  - `-f, --format <table|compact|md|json>` (기본 table)

## 동작 (strict)

1) `/linear` 단독 호출
- team 미지정: 팀 후보를 보여주고 선택
- assignee 미지정: `me`
- state 미지정: `open` 계열 기본값
- limit 기본 `20`
- 결과 출력: `[ID] [Title] [State] [Assignee] [Updated] [URL]`

2) `/linear -t platform -a me -s open -n 30`
- platform 팀 내 내 담당 오픈 이슈 30개 조회

3) `/linear -q "로그인" -f json`
- 검색어 "로그인"으로 조회, JSON으로 출력

## 파이프라인
1. 인자 파싱
2. 누락 값은 기본값/질문으로 보정
3. `linear.list_issues` 쿼리 실행
4. 정렬 후 출력

## 실패 처리
- `team` 없음: 후보 조회 실패 또는 후보 다수 시 선택 요청
- 인증 문제: 토큰/연동 상태 점검 요청
- 0건: 더 짧은 조건/검색어 변경 제안

## 출력 포맷
- `table`: 기본 테이블(사람이 읽기 쉬움)
- `compact`: 핵심 필드 압축
- `md`: 마크다운 표
- `json`: 자동 파이프 처리

## 중요
- 이 커맨드는 조회만 수행한다.
- 결과는 항상 정렬(`updatedAt desc`)을 유지한다.
