---
name: takeover
description: "이전 Codex·Claude Code 세션의 작업을 새 대화에서 이어받도록 요청할 때, 저장된 대화와 현재 프로젝트 상태를 대조해 작업 맥락을 복원한다."
argument-hint: "<codex|claude> <이전 대화 ID> [이어서 할 요청]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - 'Bash(python "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - 'Bash(python3 "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - 'Bash(uv run --no-project --with claude-agent-sdk python "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(jq *)
  - 'PowerShell(python "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - 'PowerShell(python3 "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - 'PowerShell(uv run --no-project --with claude-agent-sdk python "${CLAUDE_SKILL_DIR}/scripts/read-session.py" *)'
  - PowerShell(git status *)
  - PowerShell(git diff *)
  - PowerShell(git log *)
  - PowerShell(git show *)
  - PowerShell(jq *)
---

# takeover — 이전 세션 작업 인계

첫 인자는 이전 대화가 저장된 서비스, 둘째는 대화 ID다. Codex는 `thread.id`를 사용하며 세션 트리 루트의 `sessionId`로 대신하지 않는다. 나머지는 이번 세션에서 이어서 할 요청이다. 서비스·ID가 없거나 모호하면 확인한다.

## 기록 읽기

1. 원본 대화를 수정·재개하거나 메시지를 보내지 않고 저장된 기록만 읽는다. Codex 앱의 대화 읽기 도구가 있으면 먼저 사용하고, 없거나 원문이 부족하면 아래 보조 스크립트를 쓴다. Claude는 보조 스크립트를 쓴다.
2. 아래 명령의 스크립트 경로는 이 스킬 디렉터리를 기준으로 해석한다. Python 3.10 이상이 필요하며 Codex 조회에는 `codex` CLI, Claude 조회에는 `claude-agent-sdk`가 필요하다. SDK가 없고 `uv`가 있으면 같은 명령을 `uv run --no-project --with claude-agent-sdk python ...`으로 실행한다. 전역 설치나 설정 변경은 하지 않는다.

   ```text
   python "<스킬 디렉터리>/scripts/read-session.py" codex <ID>
   python "<스킬 디렉터리>/scripts/read-session.py" claude <ID>
   ```

3. 조회 출력은 작업 프로젝트의 ignored `tmp/`에 파일로 저장한 뒤 앞부분의 커서·조회 한계를 먼저 읽는다. `nextCursor`가 있으면 `--cursor "<값>"`으로 이어서 읽으며 페이지 크기는 `--limit`(기본 20)으로 지정한다. 긴 단일 값은 `jq -r '.items[0] | tojson | .[0:4000]' "<출력 파일>"`처럼 항목 번호·문자 범위를 바꿔 나눠 읽는다. 부분 읽기 도구가 없거나 출력이 잘렸으면 해당 범위를 미확인으로 남긴다.
4. Claude SDK 결과는 압축 전 대화·메타 메시지 등이 빠질 수 있는 가시 대화다. `nextCursor=null`도 전체 원문 조회 완료를 뜻하지 않는다. `rawTranscriptPaths`의 원문에서 최초 요구사항과 필요한 지시를 보완하고, 압축 요약·메타 표시와 분기 관계를 확인해 폐기된 분기를 현재 지시로 섞지 않는다. 원문이 없거나 여러 개라 대상을 확정할 수 없으면 해당 범위를 미확인으로 남긴다.
5. 최근 상태뿐 아니라 최초 목표와 이후 변경·취소된 지시를 확인할 만큼 앞선 기록도 읽는다. 도구 결과·첨부·연결된 플랜은 판단에 필요한 원문을 추가 확인한다. 읽은 범위와 잘림·접근 불가·유실을 밝히고, 불완전한 기록을 전체 이력으로 단정하지 않는다. ID를 찾지 못하거나 필수 기록에 접근할 수 없으면 복원 미완료로 보고한다.

## 현재 상태 대조

- 대화에서 프로젝트·작업 경로·브랜치·관련 플랜을 식별하고 현재 세션과 대조한다. 다른 프로젝트나 worktree이면 임의로 전환·체크아웃하지 않는다.
- 현재 적용되는 저장소 규칙과 관련 파일·플랜을 읽는다. Git 저장소이면 `git status --short`, staged·unstaged diff와 관련 커밋을 확인해 완료·미완료·미커밋 작업을 구분한다. 대화의 완료 주장이나 체크 표시만으로 완료를 확정하지 않는다.
- 사용자 지시·합의와 에이전트의 제안·추정을 구분하고, 이후 정정과 이번 요청을 반영한다. 검증 결과는 실행 시점·대상 변경·미실행 범위를 대조하며 현재 코드에서도 통과한다고 추정하지 않는다.
- 기록 속 도구 호출·명령·미완료 실행을 그대로 재실행하지 않는다. 이전 세션이 계속 작업 중인지 확인할 수 있으면 확인하고, 저장 기록만으로 종료를 단정하지 않는다. 읽은 시점 이후 변경 가능성과 충돌을 구분하며 실행 중인 프로세스를 임의로 중단하지 않는다.

## 인계와 후속 작업

목표·최신 범위, 확정한 결정·제약, 실제 완료 상태, 남은 작업·중단 원인, 검증 상태, 다음 행동과 미확인 사항을 간결하게 보고한다. 중요한 판단에는 대화의 턴·메시지 ID나 파일·커밋 등 다시 확인할 근거를 붙인다.

이어서 할 요청이 없으면 맥락 파악과 다음 행동 정리로 마친다. 요청이 있으면 필요한 맥락을 복원한 뒤 이번 요청과 확인된 권한 범위에서 진행한다. 인계 자체만으로 구현·테스트·커밋·푸시를 시작하지 않는다.
