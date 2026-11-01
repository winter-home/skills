# Skills

## Project Overview

Codex와 Claude Code에서 쓸 공용 플러그인을 만든다. 스킬 원본은 표준 경로인 `skills/`에 보관한다.

## Mandatory Constraints

### 스킬 작성

- 스킬 문구는 간결하고 정확하게 쓴다.

### Git 작업

- 현재 작업 브랜치를 유지한다. 시험·CI 실행을 이유로 새 브랜치를 만들거나 체크아웃하지 않으며, 브랜치 변경은 사용자가 직접 요청한 경우에만 수행한다.
- 작업 완료 후 필요한 추적 파일만 stage하고 자동 커밋·푸시하지 않는다. 단, 실행 중인 스킬이 명시적으로 지시한 커밋은 해당 절차에 따라 수행한다. ignored 파일은 요청 없이 강제 추가하지 않는다.

## Available CLI Tools

`jq`, `sqlite3`, `rg`, `fd`, `curl`, `rclone`, `pymobiledevice3`
