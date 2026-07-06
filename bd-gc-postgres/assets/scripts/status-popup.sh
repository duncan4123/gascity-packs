#!/bin/sh
# status-popup.sh - popup body for status-right clicks.
# Usage: status-popup.sh <agent-name> [city-path]
# Lists hook-ready work through gc hook without claiming and shows mail preview.

agent="$1"
city="${2:-${GC_CITY:-${GC_CITY_PATH:-${GT_ROOT:-${GC_DIR:-}}}}}"
gc_cmd="${GC_BIN:-gc}"

[ -z "$agent" ] && agent="${GC_AGENT:-${GC_SESSION_NAME:-}}"

if [ -n "$city" ] && [ -d "$city" ]; then
    cd "$city" 2>/dev/null || true
fi

run_bounded() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 5s "$@"
    else
        "$@"
    fi
}

render_ready_work() {
    if command -v python3 >/dev/null 2>&1; then
        GC_HOOK_POPUP_LIMIT="${GC_HOOK_POPUP_LIMIT:-20}" python3 -c '
import json
import os
import sys
import textwrap

try:
    limit = int(os.environ.get("GC_HOOK_POPUP_LIMIT", "20"))
except ValueError:
    limit = 20

try:
    data = json.load(sys.stdin)
except Exception:
    data = []

if isinstance(data, dict):
    data = [data]
if not isinstance(data, list):
    data = []

items = []
for item in data:
    if not isinstance(item, dict):
        continue
    ident = item.get("id") or item.get("bead_id") or item.get("issue_id") or item.get("key") or ""
    title = item.get("title") or item.get("summary") or item.get("name") or ""
    status = item.get("status") or ""
    if ident or title:
        items.append((str(ident), str(title), str(status)))

if not items:
    print("No hook-ready work.")
    raise SystemExit(0)

for ident, title, status in items[:limit]:
    prefix = ident
    if status:
        prefix = f"{prefix} [{status}]"
    line = f"{prefix} - {title}" if title else prefix
    wrapped = textwrap.wrap(line, width=92, break_long_words=False) or [line]
    for idx, part in enumerate(wrapped):
        print(part if idx == 0 else "  " + part)

remaining = len(items) - limit
if remaining > 0:
    print(f"... {remaining} more")
'
    elif command -v jq >/dev/null 2>&1; then
        jq -r '
            if type == "array" then . else [] end
            | if length == 0 then "No hook-ready work."
              else .[]
                | ((.id // .bead_id // .issue_id // .key // "") as $id
                  | (.title // .summary // .name // "") as $title
                  | if $title == "" then $id else "\($id) - \($title)" end)
              end
        ' 2>/dev/null || printf 'No hook-ready work.\n'
    else
        printf 'Install python3 or jq to render hook-ready work.\n'
    fi
}

printf 'Hook-ready work'
if [ -n "$agent" ]; then
    printf ' for %s' "$agent"
fi
printf '\n===============\n'

if [ -z "$agent" ]; then
    printf 'No agent name available.\n'
elif command -v "$gc_cmd" >/dev/null 2>&1; then
    if [ -n "$city" ]; then
        run_bounded "$gc_cmd" --city "$city" hook "$agent" 2>/dev/null | render_ready_work
    else
        run_bounded "$gc_cmd" hook "$agent" 2>/dev/null | render_ready_work
    fi
else
    printf 'gc not found.\n'
fi

printf '\nMail preview\n============\n'
if command -v "$gc_cmd" >/dev/null 2>&1; then
    if [ -n "$city" ]; then
        mail_output=$(run_bounded "$gc_cmd" --city "$city" mail inbox 2>/dev/null || true)
    else
        mail_output=$(run_bounded "$gc_cmd" mail inbox 2>/dev/null || true)
    fi
    if [ -n "$mail_output" ]; then
        printf '%s\n' "$mail_output"
    else
        printf 'No unread mail\n'
    fi
else
    printf 'gc not found.\n'
fi

exit 0
