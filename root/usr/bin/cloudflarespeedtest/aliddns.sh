#!/bin/sh

LOG_FILE='/tmp/cloudflarespeedtest.log'
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)"

echolog() {
	local d
	d="$(date "+%Y-%m-%d %H:%M:%S")"
	printf '%s: %s\n' "$d" "$*" >>"$LOG_FILE"
}

if ! command -v ucode >/dev/null 2>&1; then
	echolog "# ERROR, ucode command not found"
	exit 1
fi

exec ucode "$SCRIPT_DIR/aliddns.uc" "$@"
