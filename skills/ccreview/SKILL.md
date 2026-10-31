---
name: ccreview
description: "단일 커밋 또는 지정한 커밋 범위의 최종 누적 변경을 일반적인 코드 리뷰 기준으로 검토한다. 과거 tree나 임의 Git 범위 리뷰에 사용한다."
disable-model-invocation: true
argument-hint: "<커밋 범위 | 단일 커밋> [리뷰 집중 영역 (선택)]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git *)
---

# 커밋 범위 코드 리뷰

사용자가 호출 시 제공한 인자(`$ARGUMENTS`)로 지정한 단일 커밋 또는 커밋 범위를 하나의 최종 누적 변경으로 리뷰한다. 범위가 없거나 여러 의미로 해석되면 리뷰 전에 사용자에게 확인한다. 리뷰만 수행하고 파일은 수정하지 않는다.

## 범위와 맥락

`references/commit-range.md`를 완전히 읽고 범위 확정·최종 tree·보고 규칙을 적용한다. 나머지 인자는 리뷰 집중 영역이며 해당 관점을 우선하되 전체 변경의 중대한 문제도 놓치지 않는다.

## 리뷰

`../creview/references/review-guidelines.md`를 완전히 읽고 그 기준을 적용한다. `creview`의 working tree 범위 수집 절차는 적용하지 않는다.
