---
name: areview
description: "미커밋된 staged·unstaged tracked 변경의 아키텍처를 검토한다. 변경이 여러 기능·계층·하위 시스템의 책임 배치, 의존 관계, 데이터 소유권과 변경 파급에 미치는 영향을 점검할 때 사용한다."
disable-model-invocation: true
argument-hint: "[리뷰 참고 사항 (선택)]"
allowed-tools: Read Grep Glob Bash(git status *) Bash(git diff *) Bash(git show *)
---

# 아키텍처·구조 설계 리뷰

리뷰만 수행하며 파일 수정·stage·커밋·빌드·테스트는 하지 않는다.

## 범위와 근거

- `git status --short`, `git diff --staged`, `git diff`로 staged·unstaged tracked 변경의 최종 누적 상태를 확인한다. untracked와 이미 커밋된 변경은 리뷰 대상에서 제외하며, 대상 변경이 없으면 이를 보고하고 종료한다.
- 호출 인자(`$ARGUMENTS`)는 리뷰 참고 사항이다. 리뷰 대상은 미커밋 변경이며, 구조적 영향을 판단하는 데 필요한 기존 코드·문서와 여러 기능·계층·하위 시스템까지 조사한다.
- 사용자 요청 원문·합의한 동작을 기준으로 삼는다. 플랜 경로·현재 단계가 제공되면 해당 요구사항과 완료 조건을 직접 읽는다. 구현 자체를 요구사항의 근거로 삼지 않는다.
- 검토 영역에 적용되는 `AGENTS.md`·`AGENTS.override.md`·`CLAUDE.md`를 읽고 지정된 리뷰·설계 지침을 확인한다. 필수 자료에 접근할 수 없으면 검토 미완료와 접근 불가 범위를 보고한다.

## 리뷰

`references/architecture-guidelines.md`를 완전히 읽고 그 기준을 적용한다.
