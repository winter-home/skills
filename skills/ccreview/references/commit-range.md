# 커밋 범위와 최종 tree

단일 커밋 또는 커밋 범위를 하나의 최종 누적 변경으로 리뷰한다. 범위가 없거나 여러 의미로 해석되면 리뷰 전에 사용자에게 확인한다. staged·unstaged·untracked 변경은 대상에서 제외하며 checkout·리뷰 대상 파일 수정·stage·빌드·테스트는 하지 않는다.

## 범위 확정

- 단일 ref `X`: 첫 부모부터 `X`까지 비교한다. 루트 커밋이면 빈 tree를 기준으로 한다. merge commit은 사용자가 다른 부모를 지정하지 않은 한 첫 부모를 기준으로 한다.
- 명시적 `A..B`, `A^..B` 또는 `git diff <range>`: 사용자가 적은 범위와 방향을 유지한다. `A...B`는 `git merge-base --all A B`로 구한 공통 조상부터 `B`까지 비교한다.
- `A부터 B까지`, `A ~ B` 같은 자연어 inclusive 범위: 양방향 `git merge-base --is-ancestor`로 오래된 쪽과 최신 쪽을 정한 뒤 `<old>`의 첫 부모부터 `<new>`까지 비교한다. 어느 쪽도 ancestor가 아니면 비교 기준을 사용자에게 확인한다. `<old>`가 루트 커밋이면 빈 tree를 기준으로 한다.

ref는 `git rev-parse --verify <ref>^{commit}`로 검증한다. 루트 비교용 빈 tree 해시가 기준으로 전달된 경우에는 `^{tree}`로 검증한다. 비교 기준과 종료 커밋을 전체 해시로 고정하고 `<base>..<end>`를 실제 diff 범위로 사용한다. merge-base가 하나로 정해지지 않으면 비교 기준을 사용자에게 확인한다.

고정한 범위에 `git log --oneline --reverse`, `git diff --stat`, `git diff --name-status`, `git diff`를 적용해 포함 커밋과 최종 누적 변경을 수집한다. 기준이 빈 tree이면 로그는 `git log --oneline --reverse <end>`로 수집한다. 변경이 없으면 "변경 사항 없음"을 보고하고 종료한다.

## 최종 tree 기준

리뷰 대상은 개별 커밋 과정이 아니라 종료 시점의 최종 코드다. 종료 커밋이 현재 checkout과 다르거나 working tree에 미커밋 변경이 있으면 `git show <end>:<path>`와 `git grep <pattern> <end>`로 파일·호출부·테스트를 확인한다. 삭제 파일은 비교 기준 tree에서 삭제 전 맥락을 확인한다. working tree 내용과 대상 커밋의 내용을 섞지 않는다.

변경 파일에 적용되는 `AGENTS.md`·`AGENTS.override.md`·`CLAUDE.md`와 연결된 관련 규칙도 같은 tree 기준으로 확인한다. 공개 심볼이나 데이터 계약이 바뀌었다면 필요한 소비처까지 추적한다.

결과 상단에 사용자 입력 범위, 실제 사용한 diff 명령, 종료 커밋을 적는다. 발견 위치는 종료 tree 기준이며 삭제된 위치는 삭제 전 기준임을 표시한다.
