#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C L A U D E   U S A G E                                                │
# │   tokens spent in the current block and this week                        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Report Claude Code usage from its transcripts and the API's rate limits.

Every assistant turn in a Claude Code transcript (JSONL) carries the token
counts the API returned; the default action sums them for the current 5-hour
block and the last 7 days. Transcripts only grow, so each file is read from
its last offset and the totals are cached per hour.

`limits` reports the plan's utilization, which is only exposed in the
`anthropic-ratelimit-unified-*` response headers.
"""

import calendar
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# The billing block, in hours. A block starts on the hour of its first message.
BLOCK_HOURS = 5
WEEK_HOURS = 24 * 7

HOME = Path(os.path.expanduser("~"))
TRANSCRIPTS = HOME / ".claude" / "projects"

STATE = Path(
    os.environ.get("XDG_STATE_HOME") or (HOME / ".local" / "state")
) / "quickshell"
CACHE = STATE / "claude-usage.json"


def fail(message):
    """Report the data as unavailable and exit."""
    print(message, file=sys.stderr)
    print(json.dumps({"available": False}))
    sys.exit(0)


def load_cache():
    try:
        with CACHE.open() as handle:
            cache = json.load(handle)
        if cache.get("version") != 1:
            return {"version": 1, "files": {}}
        return cache
    except (OSError, ValueError):
        return {"version": 1, "files": {}}


def save_cache(cache):
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with CACHE.open("w") as handle:
            json.dump(cache, handle)
    except OSError as error:
        print(f"Cannot write the usage cache: {error}", file=sys.stderr)


def parse_timestamp(text):
    """Parse a UTC ISO 8601 stamp to epoch seconds.

    timegm rather than mktime, which would read it as local time.
    """
    try:
        return calendar.timegm(time.strptime(text[:19], "%Y-%m-%dT%H:%M:%S"))
    except (TypeError, ValueError):
        return None


def scan(path, entry):
    """Read new lines from one transcript into hourly buckets.

    Resumes from the stored offset; a file smaller than that was replaced
    rather than appended to, so it is read again from the start.
    """
    stat = path.stat()
    offset = entry.get("offset", 0)
    buckets = entry.get("buckets", {})
    if stat.st_size < offset:
        offset, buckets = 0, {}

    with path.open("r", errors="ignore") as handle:
        handle.seek(offset)
        for line in handle:
            # Cheap filter first: only assistant turns carry a usage block.
            if '"output_tokens"' not in line:
                continue
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if record.get("type") != "assistant":
                continue
            usage = (record.get("message") or {}).get("usage") or {}
            when = parse_timestamp(record.get("timestamp"))
            if when is None:
                continue
            # Cache reads are excluded: they re-send the same context on every
            # turn and would dwarf the tokens actually processed.
            tokens = (
                usage.get("input_tokens", 0)
                + usage.get("output_tokens", 0)
                + usage.get("cache_creation_input_tokens", 0)
            )
            hour = str(int(when // 3600))
            slot = buckets.setdefault(hour, [0, 0])
            slot[0] += tokens
            slot[1] += 1
        offset = handle.tell()

    return {"offset": offset, "mtime": stat.st_mtime, "buckets": buckets}


def main():
    if not TRANSCRIPTS.is_dir():
        fail(f"No transcripts at {TRANSCRIPTS}")

    cache = load_cache()
    files = cache.get("files", {})
    hours = {}

    for path in TRANSCRIPTS.glob("**/*.jsonl"):
        key = str(path)
        entry = files.get(key, {})
        try:
            stat = path.stat()
            if entry.get("mtime") != stat.st_mtime or not entry.get("buckets"):
                entry = scan(path, entry)
                files[key] = entry
        except OSError:
            continue
        for hour, (tokens, messages) in entry.get("buckets", {}).items():
            total = hours.setdefault(hour, [0, 0])
            total[0] += tokens
            total[1] += messages

    cache["files"] = files
    save_cache(cache)

    if not hours:
        fail("No usage recorded in the transcripts")

    now = time.time()
    this_hour = int(now // 3600)
    ordered = sorted(int(hour) for hour in hours)

    def total_over(first, last):
        tokens = messages = 0
        for hour in range(first, last + 1):
            slot = hours.get(str(hour))
            if slot:
                tokens += slot[0]
                messages += slot[1]
        return tokens, messages

    # The block runs from the hour its first message landed in. Walk back from
    # now while there is still activity within reach of a five-hour window.
    block_start = this_hour
    for hour in reversed(ordered):
        if hour > this_hour or hour <= this_hour - BLOCK_HOURS:
            continue
        block_start = min(block_start, hour)
    while block_start - 1 > this_hour - BLOCK_HOURS and str(block_start - 1) in hours:
        block_start -= 1

    block_tokens, block_messages = total_over(block_start, this_hour)
    week_tokens, week_messages = total_over(this_hour - WEEK_HOURS + 1, this_hour)

    # The busiest block and week on record: the scale the shell uses when the
    # account's limits are unavailable.
    peak_block = 0
    peak_week = 0
    for hour in range(ordered[0], ordered[-1] + 1):
        peak_block = max(peak_block, total_over(hour, hour + BLOCK_HOURS - 1)[0])
    for hour in range(ordered[0], ordered[-1] + 1, 12):
        peak_week = max(peak_week, total_over(hour, hour + WEEK_HOURS - 1)[0])

    print(json.dumps({
        "available": True,
        "blockStart": block_start * 3600,
        "blockEnd": (block_start + BLOCK_HOURS) * 3600,
        "blockTokens": block_tokens,
        "blockMessages": block_messages,
        "weekTokens": week_tokens,
        "weekMessages": week_messages,
        "peakBlockTokens": peak_block,
        "peakWeekTokens": peak_week,
    }))


CREDENTIALS = Path(
    os.environ.get("CLAUDE_CONFIG_DIR") or (HOME / ".claude")
) / ".credentials.json"

# The cheapest request that gets a response: smallest model, one output token.
# Only the headers are used.
LIMITS_ENDPOINT = "https://api.anthropic.com/v1/messages"
LIMITS_BODY = json.dumps({
    "model": "claude-haiku-4-5",
    "max_tokens": 1,
    "messages": [{"role": "user", "content": "."}],
})
LIMITS_TIMEOUT = 12


def limits():
    """Print the 5-hour and 7-day utilization the API reports.

    They arrive as `anthropic-ratelimit-unified-{5h,7d}-utilization` headers,
    with reset times, on every response, and match what `/usage` prints.
    Nothing else exposes them, so this sends a minimal request and discards
    the body; the shell calls it on a slow timer.

    Authenticates with Claude Code's OAuth token from its credentials file,
    for this one request only; the token is never stored or printed.
    """
    try:
        token = json.loads(CREDENTIALS.read_text())["claudeAiOauth"]["accessToken"]
    except (OSError, ValueError, KeyError, TypeError):
        fail(f"No Claude Code credentials at {CREDENTIALS}")

    result = subprocess.run(
        [
            "curl", "-sS", "--max-time", str(LIMITS_TIMEOUT),
            "-o", os.devnull, "-D", "-",
            LIMITS_ENDPOINT,
            "-H", f"authorization: Bearer {token}",
            "-H", "anthropic-version: 2023-06-01",
            "-H", "anthropic-beta: oauth-2025-04-20",
            "-H", "content-type: application/json",
            "-d", LIMITS_BODY,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or "no answer from the API")

    headers = {}
    for line in result.stdout.splitlines():
        name, sep, value = line.partition(":")
        if sep:
            headers[name.strip().lower()] = value.strip()

    def window(prefix):
        used = headers.get(f"anthropic-ratelimit-unified-{prefix}-utilization")
        resets = headers.get(f"anthropic-ratelimit-unified-{prefix}-reset")
        if used is None:
            return None
        try:
            return {
                "used": float(used),
                "resets": int(resets) if resets else 0,
                "status": headers.get(
                    f"anthropic-ratelimit-unified-{prefix}-status", ""),
            }
        except ValueError:
            return None

    session = window("5h")
    week = window("7d")
    if session is None and week is None:
        # A 401, a 429 before the headers, or an API that stopped sending them.
        fail("no rate limit headers in the response")

    print(json.dumps({
        "available": True,
        "session": session,
        "week": week,
        # Which of the two the API is currently enforcing against.
        "claim": headers.get("anthropic-ratelimit-unified-representative-claim", ""),
        "status": headers.get("anthropic-ratelimit-unified-status", ""),
    }))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "limits":
        limits()
    else:
        main()
