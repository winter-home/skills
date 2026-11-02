---
name: aareview
description: "단일 커밋 또는 지정한 커밋 범위의 최종 누적 변경을 아키텍처 관점에서 검토한다. 여러 기능·계층·하위 시스템에 미치는 구조·설계 영향을 점검할 때 사용한다."
disable-model-invocation: true
argument-hint: "<커밋 범위 | 단일 커밋> [리뷰 참고 사항 (선택)]"
allowed-tools: Read Grep Glob Bash(git *)
---

# 커밋 범위 아키텍처·구조 설계 리뷰

사용자가 제공한 인자(`$ARGUMENTS`)의 단일 커밋 또는 커밋 범위를 하나의 최종 누적 변경으로 리뷰한다. 리뷰만 수행한다.

## 범위와 맥락

`../ccreview/references/commit-range.md`를 완전히 읽고 범위 확정·최종 tree·보고 규칙을 적용한다. 나머지 인자는 리뷰 참고 사항이다.

사용자 요청·합의한 동작은 구조 판단의 맥락으로 확인한다. 별도 요청 원문·플랜 경로·단계가 제공되면 직접 읽고, 없으면 커밋 메시지와 관련 문서에서 목적을 확인한다. 구현 자체를 요구사항의 근거로 삼지 않으며 미확정 요구사항을 단정하지 않는다.

## 리뷰

`../areview/references/architecture-guidelines.md`를 완전히 읽고 그 기준을 적용한다. 기존 구조와 종료 시점의 구조를 비교하며, 관련 코드·문서·규칙도 지정한 tree 기준으로 확인한다. `areview`의 working tree 범위 수집 절차는 적용하지 않는다.
