---
name: ppwork
description: "단일 커밋 또는 커밋 범위를 새 세션의 codex·claude 리뷰어(ccreview·ssreview)로 한 번 병렬 리뷰하고, 지적을 vreview 절차로 검증해 보고한다. 코드는 수정하지 않는다."
argument-hint: "<커밋 범위 | 단일 커밋> [리뷰어 구성 3자리, 각 0~2 (기본 200)] [리뷰 집중 영역 (선택)]"
allowed-tools: Read Grep Glob Write Bash(git *) Bash(pwsh -NoProfile -File *run-reviewers.ps1*) PowerShell(git *) PowerShell(pwsh -NoProfile -File *run-reviewers.ps1*)
---

# 커밋 범위 병렬 리뷰·검증

커밋된 최종 누적 변경을 새 세션 리뷰어들이 병렬로 한 번 리뷰하고, 이 세션이 지적을 검증해 보고한다. 권장안 적용·stage·커밋·checkout은 하지 않는다.

## 인자

먼저 단일 커밋 또는 커밋 범위를 해석한다. 범위 뒤의 숫자 세 자리만 리뷰어 구성이며, 단일 숫자 ref를 구성으로 해석하지 않는다. 기본은 `200`, 각 자리 0~2, 합계 0은 오류다. 나머지는 리뷰 집중 영역이다.

| 자리 | 리뷰어 |
| --- | --- |
| 1 | codex 새 세션의 `ccreview` |
| 2 | claude 새 세션의 `ccreview` |
| 3 | claude 새 세션의 `ssreview` |

예: `HEAD 110`, `main...HEAD 111`, `abc123부터 def456까지 110 인증 흐름`.

## 준비

1. `../ccreview/references/commit-range.md`를 완전히 읽고 범위를 확정한다. working tree의 변경 유무와 무관하게 진행하며 `git add -N`은 하지 않는다. 대상 diff가 없으면 종료한다.
2. 실행 디렉터리 `tmp/ppwork/<yyyyMMdd-HHmmss>`를 만든다.
3. `brief.md`에 사용자 입력 범위, 고정한 `<base>..<end>`, 종료 커밋, 사용자 요청·합의한 요구사항·완료 조건·제외 범위·집중 영역을 쓴다. `../pwork/SKILL.md`의 「brief 원칙」을 적용한다. 과거 변경의 목적이 불명확하면 그렇게 적고 현재 요청을 과거 요구사항으로 간주하지 않는다.

## 실행·검증

`../pwork/SKILL.md`를 읽고 「리뷰」·「실행 환경과 대기」·「최종 보고」를 적용하되 아래 차이를 따른다. `pwork`의 인자·준비 절차는 적용하지 않는다.

저장소 루트에서 공유 스크립트에 고정한 범위를 전달한다. 각 리뷰어는 같은 범위를 `ccreview` 또는 `ssreview`로 검토한다.

```
pwsh -NoProfile -File "<pwork 스킬 디렉터리>/scripts/run-reviewers.ps1" -Spec <구성> -CommitRange "<base>..<end>" -OutDir "<실행 디렉터리>" -BriefFile "<실행 디렉터리>/brief.md"
```

- 분리 프로세스로 실행할 때도 `-CommitRange`를 전달한다. 완료 후 `summary.json`을 출력하고 모든 리뷰 결과를 확인한다.
- 대상 diff가 있는데 "변경 사항 없음"으로 끝난 리뷰는 실패다. working tree 변경 유무로 성공을 판단하지 않는다.
- 지적 정리의 `creview`·`sreview`는 각각 `ccreview`·`ssreview`로 읽는다. 심각도는 `ccreview` 지적에만 붙인다.
- vreview 사실 확인과 이력 조회도 고정한 종료 tree·커밋을 기준으로 한다. 현재 checkout의 파일·이력과 섞지 않는다.
- 최종 보고에 사용자 입력 범위, 실제 diff 명령, 종료 커밋을 포함한다.
