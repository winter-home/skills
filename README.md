# dw

Codex와 Claude Code에서 쓰는 코드 리뷰·플랜 실행·커밋 스킬 플러그인이다.

## 구성

```text
plugin.json                       Codex용 Agent Plugins 1.0 매니페스트
.claude-plugin/plugin.json        Claude Code 매니페스트
.claude-plugin/marketplace.json   공용 설치 카탈로그
skills/                           두 도구가 사용하는 스킬 원본
```

`skills/`만 수정한다. `.agents/skills`는 로컬 탐색용 링크이며 플러그인 설치에는 필요하지 않다.

| 스킬 | 용도 |
| --- | --- |
| `creview` | 미커밋 변경 코드 리뷰 |
| `ccreview` | 지정한 커밋·범위 리뷰 |
| `sreview` | 변경 범위·불필요한 확장 리뷰 |
| `ssreview` | 지정한 커밋·범위의 불필요한 확장 리뷰 |
| `vreview` | 리뷰 지적과 처방 검증 |
| `pwork` | 새 세션 리뷰어 병렬 실행·검증·보고 |
| `ppwork` | 지정한 커밋·범위의 병렬 리뷰·검증·보고 |
| `lwork` | 리뷰·수정 반복과 실패 복구 |
| `iplan` | 플랜 단계별 구현·검증·리뷰·커밋 |
| `commit` | 프로젝트 메시지 규칙에 따른 커밋 |

## 설치

아래 명령은 플러그인 구성이 저장소에 커밋·푸시된 뒤 사용한다.

### Claude Code

```powershell
claude plugin marketplace add winter-home/skills
claude plugin install dw@winter-home-skills
```

새 세션에서 `/dw:pwork 110`처럼 호출한다.

커밋된 변경은 `/dw:ccreview HEAD`, `/dw:ssreview HEAD~3..HEAD`, `/dw:ppwork main...HEAD 110`처럼 범위를 먼저 지정한다.

### Codex

```powershell
codex plugin marketplace add winter-home/skills
codex plugin add dw@winter-home-skills
```

Codex 앱을 다시 열거나 새 세션을 시작한 뒤 플러그인의 스킬 목록에서 실행한다. 로컬 설치를 시험할 때는 양쪽 `marketplace add`의 저장소 이름 대신 깨끗한 패키지 폴더의 절대 경로를 쓸 수 있다.

## 실행 조건

- 리뷰 스크립트는 Git과 PowerShell 7.2 이상을 사용한다. 선택한 리뷰어의 `codex`·`claude` CLI가 PATH에 있고 각각 인증되어 있어야 한다.
- 리뷰 결과는 작업 대상 저장소의 `tmp/`에 쓴다. 현재 스크립트는 저장소 안의 결과 폴더가 Git ignore 대상일 것을 요구하므로 실행 전에 해당 저장소의 `tmp/` ignore 설정을 확인한다.
- 리뷰어는 패키지의 `creview`·`sreview`(커밋 범위는 `ccreview`·`ssreview`) 파일을 직접 읽는다. 대상 프로젝트에 같은 이름의 스킬을 복사할 필요가 없다.
- 각 스킬의 stage·커밋·초기화·검증 권한은 해당 `SKILL.md`와 대상 프로젝트 규칙을 따른다.

## 로컬 검증과 배포

`plugin.json`, `.claude-plugin/`, `skills/`, 이 README만 별도 폴더에 복사해 검증한다. 기존 `.claude/`, `.agents/`, 개발 환경용 `.mcp.json`, `tmp/`는 패키지에 넣지 않는다.

```powershell
claude plugin validate <패키지폴더> --strict
claude --plugin-dir <패키지폴더> plugin list --json
```

배포할 때 두 플러그인 매니페스트의 이름·버전을 함께 맞춘다. 버전을 올려 설치된 사본이 갱신되도록 한다.

형식 참고: [OpenAI 플러그인 패키징](https://developers.openai.com/plugins/build/plugins), [Claude 플러그인 매니페스트](https://code.claude.com/docs/en/plugins/manifest-reference).
