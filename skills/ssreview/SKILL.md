---
name: ssreview
description: "단일 커밋 또는 지정한 커밋 범위의 최종 누적 변경에 불필요한 구현·테스트 확장이 있는지 검토한다. 커밋된 변경의 범위와 간결성 점검에 사용한다."
argument-hint: "<커밋 범위 | 단일 커밋> [리뷰 집중 영역 (선택)]"
allowed-tools: Read Grep Glob Bash(git *)
---

# 커밋 범위·간결성 리뷰

사용자가 제공한 인자(`$ARGUMENTS`)의 단일 커밋 또는 커밋 범위를 리뷰한다. 리뷰만 수행한다.

## 범위와 맥락

`../ccreview/references/commit-range.md`를 완전히 읽고 범위 확정·최종 tree·보고 규칙을 적용한다. 나머지 인자는 리뷰 집중 영역이다.

사용자 요청·합의한 동작을 기준으로 삼는다. 별도 요청 요약이 있으면 먼저 읽고, 없으면 커밋 메시지와 관련 문서에서 목적을 확인한다. 목적을 확인할 수 없으면 범위 위반을 단정하지 않는다.

## 리뷰

`../sreview/references/simplicity-guidelines.md`를 완전히 읽고 그 기준을 적용한다. `sreview`의 working tree 범위 수집 절차는 적용하지 않는다.
