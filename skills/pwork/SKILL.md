---
name: pwork
description: "미커밋 변경을 새 세션의 codex·claude 리뷰어(creview·sreview·areview)로 한 번 병렬 리뷰하고, 지적이 있으면 vreview 절차로 검증한 보고서를 출력한다. 코드는 수정하지 않는다."
disable-model-invocation: true
argument-hint: "[리뷰어 구성 (예: c11s01a11, 기본 c20)] [리뷰 참고 사항 (선택)]"
allowed-tools: Read Grep Glob Write Bash(git *) Bash(pwsh -NoProfile -File *run-reviewers.ps1*) PowerShell(git *) PowerShell(pwsh -NoProfile -File *run-reviewers.ps1*)
---

# pwork — 병렬 리뷰·검증

staged·unstaged tracked 변경을 새 세션 리뷰어들이 병렬로 한 번 리뷰하고, 이 세션이 그 결과를 vreview 절차로 검증한 보고서를 출력한다. 권장안은 적용하지 않으며 `git add -N` 외의 stage·커밋은 하지 않는다.

## 인자

첫 인자가 `c11s01a11`처럼 그룹을 붙인 토큰이면 리뷰어 구성이다. 각 그룹 뒤 두 자리는 Codex 수·Claude 수이며 각각 0~2다.

| 그룹 | 종류 | 스킬 |
| ---- | ---- | ---- |
| `c` | 코드 리뷰 | `creview` |
| `s` | 간결성 리뷰 | `sreview` |
| `a` | 구조·설계 리뷰 | `areview` |

- 그룹은 소문자이며 순서는 자유다. 생략한 그룹은 `00`이다. 중복 그룹·범위를 벗어난 숫자·합계 0은 실행 전에 오류로 종료한다.
- 기존 숫자 세 자리도 지원한다. 순서는 Codex 코드·Claude 코드·Claude 간결성 리뷰 수다. 예: `110` = `c11`, `111` = `c11s01`.
- 구성이 없으면 `c20`(기존 `200`과 동일). 숫자만인 토큰이나 그룹 문자 뒤 숫자로 시작하는 잘못된 구성은 참고 사항으로 넘기지 않고 오류로 종료한다.
- 나머지 인자는 리뷰 참고 사항이다.
- 리뷰어는 모두 서로 다른 새 세션이다.
- 실행 전에 해석한 구성을 짧게 알린다. 예: `코드 C1/L1 · 간결 C0/L1 · 설계 C1/L1`.

## 준비

1. `git status --short`로 대상을 확인한다. staged·unstaged tracked 변경이 없으면 종료한다.
2. 리뷰어는 untracked 파일을 보지 않는다. 이번 작업에서 만든 untracked 파일은 `git add -N`으로 리뷰 범위에 넣고, 무관한 파일은 건드리지 않는다.
3. 실행 디렉터리를 만든다: `tmp/pwork/<yyyyMMdd-HHmmss>`
4. 실행 디렉터리에 「brief 원칙」에 따라 `brief.md`를 작성하고 「원문 접근」을 준비한다. 플랜 작업 중이면 확인된 플랜 경로·현재 단계를 리뷰 참고 사항과 별개인 작업 맥락으로 포함한다.

### brief 원칙

- 사용자 요청, 요구사항 원문 위치, 검토 범위를 적는다. 원문에 없는 합의·완료 조건과 사용자가 명시한 제외 사항만 짧게 덧붙인다. 원문이 없으면 합의된 요구사항·완료 조건을 간결히 기록한다.
- 상세 요구사항 재서술, 구현 구조·설계 의도·정당화 설명은 넣지 않는다. 리뷰 참고 사항은 사용자가 제공한 경우에만 적는다.
- 리뷰어는 요구사항 원문을 직접 읽고 평가한다. 필수 원문을 확인할 수 없으면 평가를 완료하지 않고 접근 불가를 보고한다.
- 이전 리뷰의 지적·판정·수정 이력과 해결 여부 확인 요청은 brief·리뷰어 프롬프트에 넣지 않는다. 요구사항은 리뷰 출처·판정 없이 쓰고 이전 리뷰 보고서·기록 파일도 전달하지 않는다.

### 원문 접근

저장소 밖 필수 원문이 있으면 필요한 부모 디렉터리의 절대 경로 목록을 JSON 배열로 실행 디렉터리의 `source-dirs.json`에 저장한다. 스크립트 실행·분리 프로세스에 `-SourceDirsFile "<실행 디렉터리>/source-dirs.json"`을 추가한다. Claude의 추가 접근 범위에 이 경로만 전달하며, 외부 원문이 없으면 생략한다.

## 리뷰

### 리뷰어 실행

저장소 루트에서 실행한다. 결과 디렉터리는 실행 디렉터리다.

```
pwsh -NoProfile -File "<pwork 스킬 디렉터리>/scripts/run-reviewers.ps1" -Spec <구성> -OutDir "<결과 디렉터리>" -BriefFile "<실행 디렉터리>/brief.md"
```

「실행 환경과 대기」에 따라 모든 리뷰어가 끝날 때까지 기다린 뒤 `summary.json`을 출력한다. 리뷰어가 도는 동안 작업 트리를 수정하지 않는다.

### 실행 결과 확인

- `ok`가 false인 리뷰어(시작 실패·비정상 종료·타임아웃·빈 출력)는 `log` 끝부분으로 원인을 확인해 보고에 남기고 이번 검증에서 제외한다. 전부 실패하면 중단한다.
- tracked 변경이 있는데 "변경 사항 없음"으로 끝난 리뷰는 실패로 취급한다.
- 필수 원문에 접근하지 못한 리뷰도 실패로 취급하고 통과 근거에서 제외한다.

### 지적 정리

성공한 리뷰어의 출력(`summary.json`의 `output`)을 읽고 리뷰어별로 정리해 보여 준다. 지적마다 `심각도 파일:라인 요지`를 제목으로 쓰고 문제·근거·제안을 각 1~2문장으로 요약한다. 심각도는 creview 지적에만 붙이고, areview의 필수·선택적 개선 구분은 유지한다. 검증 판정은 붙이지 않는다. 지적이 없는 리뷰어는 "지적 없음"으로 적는다.

### 검증

정리한 지적이 있으면 `../vreview/SKILL.md`를 읽고 그 절차로 전부를 한 번에 검증해 보고서를 보여 준다. 이전 리뷰 기록이 있으면 메인 에이전트가 이때 대조한다. 여러 리뷰어의 같은 지적은 묶어서 한 번 판정한다. 지적이 없으면 그렇게 보고한다.

「지적 정리」와 「검증」의 정리·보고서는 진행 메시지로 줄이지 않고 정한 형식 그대로 출력한다. 이어서 작업하는 중간 출력이어도 같다.

## 실행 환경과 대기

- 선택한 리뷰어의 CLI와 인증, Git, PowerShell 7.2 이상이 필요하다. 스크립트는 이 패키지의 리뷰 스킬 파일을 직접 지정해 새 세션을 실행한다.
- 선택 옵션: `-CodexModel`(기본 `~/.codex/config.toml`의 `model`), `-ClaudeModel`(기본 `opus`), `-CodexSandbox`(기본 `read-only`), `-TimeoutMinutes`(기본 60).
- Windows의 codex 샌드박스는 Microsoft Store판 pwsh를 실행하지 못한다. 스크립트는 Store판이 아닌 pwsh(PATH 또는 Codex 앱 번들)를 codex의 PATH 맨 앞에 둔다. 찾지 못하면 경고를 출력하며, codex 리뷰어는 셸 명령을 실행하지 못한다.
- `danger-full-access`는 Claude Code auto 모드 분류기가 실행을 막을 수 있으므로 사용자가 요청할 때만 쓴다.
- 리뷰어 하나가 수십 분 걸릴 수 있다. Claude Code에서는 백그라운드로 실행하고 완료 알림을 기다린다. 폴링하지 않는다. 백그라운드 완료 알림이 없는 에이전트는 타임아웃을 `-TimeoutMinutes`보다 길게 잡고 블로킹으로 실행한다.
- 도구 대기 시간이 그보다 짧으면 스크립트를 분리 프로세스로 띄우고, 도구 제한 안의 대기를 반복해 프로세스가 끝나기를 기다린다. 끝난 뒤 `summary.json`이 없으면 실패로 보고한다.

  ```
  (Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList '-NoProfile -File "<스크립트>" -Spec <구성> -OutDir "<결과 디렉터리>" -BriefFile "<brief>"').Id
  Wait-Process -Id <PID> -Timeout 240 -ErrorAction SilentlyContinue
  ```

## 최종 보고

- 실행한 리뷰어(실패와 원인 포함)
- 리뷰어별 지적 정리
- vreview 보고서 또는 지적 없음
- 실행 디렉터리 경로
