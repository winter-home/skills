# Skills

## Project Overview

다른 프로젝트에서 쓸 범용 스킬을 만든다. 이 저장소에서도 쓸 수 있도록 스킬은 실제 스킬 경로인 `.claude/skills/`에 보관한다.

## Mandatory Constraints

### 스킬 작성

- 스킬 문구는 간결하고 정확하게 쓴다.

### Git 작업

- 현재 작업 브랜치를 유지한다. 시험·CI 실행을 이유로 새 브랜치를 만들거나 체크아웃하지 않으며, 브랜치 변경은 사용자가 직접 요청한 경우에만 수행한다.
- 완료 후 필요한 추적 파일만 stage하고 자동 커밋·푸시하지 않는다. 단, `iplan` 스킬은 통과한 단계마다 커밋한다. ignored 파일은 요청 없이 강제 추가하지 않는다.

## Available CLI Tools

`jq`, `sqlite3`, `rg`, `fd`, `curl`, `rclone`, `pymobiledevice3`