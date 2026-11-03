#!/usr/bin/env python3
"""Read saved conversations without starting or resuming an agent turn."""

import argparse
import dataclasses
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unicodedata
import uuid


class CodexReader:
    def __init__(self):
        binary = (shutil.which("codex.exe") if os.name == "nt" else None) or shutil.which("codex")
        if not binary:
            raise RuntimeError("Codex CLI executable not found on PATH")
        self.stderr = tempfile.TemporaryFile()
        try:
            self.process = subprocess.Popen(
                [binary, "app-server", "--listen", "stdio://"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=self.stderr,
                text=True,
                encoding="utf-8",
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
        except BaseException:
            self.stderr.close()
            raise
        self.messages = queue.Queue()
        self.sequence = 0
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        try:
            for line in self.process.stdout:
                self.messages.put(json.loads(line))
        except (ValueError, OSError) as error:
            self.messages.put(error)
        finally:
            self.messages.put(None)

    def send(self, message):
        self.process.stdin.write(json.dumps(message, ensure_ascii=False) + "\n")
        self.process.stdin.flush()

    def request(self, method, params):
        self.sequence += 1
        request_id = self.sequence
        self.send({"id": request_id, "method": method, "params": params})
        deadline = time.monotonic() + 30
        while True:
            try:
                response = self.messages.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty:
                raise RuntimeError(f"Codex {method} timed out") from None
            if response is None:
                raise RuntimeError("Codex app-server closed before returning history")
            if isinstance(response, Exception):
                raise RuntimeError(f"Invalid Codex response: {response}")
            if not isinstance(response, dict):
                raise RuntimeError("Codex response must be a JSON object")
            if response.get("id") != request_id:
                if "id" in response and "method" in response:
                    raise RuntimeError("Unexpected server request during history lookup")
                continue
            if "error" in response:
                raise RuntimeError(f"Codex {method}: {response['error']}")
            return response["result"]

    def close(self):
        try:
            try:
                self.process.stdin.close()
            except BrokenPipeError:
                pass
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait()
        finally:
            self.process.stdout.close()
            try:
                self.stderr.seek(0, os.SEEK_END)
                self.stderr.seek(max(0, self.stderr.tell() - 4096))
                diagnostics = self.stderr.read().decode("utf-8", errors="replace").strip()
            finally:
                self.stderr.close()
        return diagnostics


def read_codex(args):
    reader = CodexReader()
    failure = None
    try:
        reader.request("initialize", {
            "clientInfo": {"name": "wt_takeover", "version": "1.0.0"},
        })
        reader.send({"method": "initialized", "params": {}})
        metadata = reader.request("thread/read", {
            "threadId": args.session_id, "includeTurns": False,
        })["thread"]
        page = reader.request("thread/turns/list", {
            "threadId": args.session_id,
            "limit": args.limit,
            "cursor": args.cursor,
            "sortDirection": "desc",
            "itemsView": "full",
        })
        return {
            "source": "codex", "thread": metadata,
            "order": "newest-first", "items": page["data"],
            "nextCursor": page.get("nextCursor"),
        }
    except Exception as error:
        failure = error
        raise
    finally:
        diagnostics = reader.close()
        if failure is not None and diagnostics:
            raise RuntimeError(f"{failure}\nCodex stderr:\n{diagnostics}") from failure


def read_claude(args):
    try:
        from claude_agent_sdk import get_session_info, get_session_messages
    except ImportError:
        raise RuntimeError(
            "Claude history requires claude-agent-sdk. Use an SDK-enabled Python "
            "or: uv run --no-project --with claude-agent-sdk python <script> claude <ID>"
        ) from None
    offset = int(args.cursor or "0")
    if offset < 0:
        raise ValueError("Claude cursor must be a non-negative offset")
    session_id = str(uuid.UUID(args.session_id))
    info = get_session_info(session_id)
    messages = get_session_messages(
        session_id, limit=args.limit + 1, offset=offset,
    )
    config = os.environ.get("CLAUDE_CONFIG_DIR") or str(Path.home() / ".claude")
    projects = Path(unicodedata.normalize("NFC", config)) / "projects"
    paths = sorted(str(path.resolve()) for path in projects.glob(f"*/{session_id}.jsonl") if path.is_file())
    if info is None and not messages and not paths:
        raise RuntimeError("Claude session not found in accessible local history")
    limitations = [
        "SDK-visible messages may omit pre-compaction, meta, sidechain and team records; "
        "summary markers are not preserved. End of pagination is not end of the raw transcript.",
    ]
    if len(paths) != 1:
        limitations.append("Raw transcript unavailable or ambiguous; do not infer complete history.")
    if info is None:
        limitations.append("Session metadata unavailable; inspect the messages and raw transcript.")
    return {
        "source": "claude", "session": dataclasses.asdict(info) if info is not None else {"session_id": session_id},
        "view": "sdk-visible-messages", "limitations": limitations,
        "rawTranscriptPaths": paths,
        "order": "oldest-first", "offset": offset,
        "items": [dataclasses.asdict(message) for message in messages[:args.limit]],
        "nextCursor": str(offset + args.limit) if len(messages) > args.limit else None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", choices=("codex", "claude"))
    parser.add_argument("session_id")
    parser.add_argument("--cursor")
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args()
    if not 1 <= args.limit <= 100:
        parser.error("--limit must be between 1 and 100")
    try:
        result = read_codex(args) if args.source == "codex" else read_claude(args)
        items = result.pop("items")
        result = {
            "nextCursor": result.pop("nextCursor"),
            "retrievedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            **result, "items": items,
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (RuntimeError, ValueError, OSError, KeyError, TypeError) as error:
        print(f"History lookup failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    sys.exit(main())
