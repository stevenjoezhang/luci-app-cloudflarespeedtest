#!/bin/sh

set -eu

usage() {
	cat <<'EOF'
Usage: astra-dns.sh --result-csv FILE --config FILE [options]

Options:
  --result-csv FILE   CloudflareSpeedTest result CSV file
  --config FILE       astra-dns YAML config file
  --bin FILE          astra-dns binary path (default: /usr/bin/astra-dns)
  --backup FILE       Backup path for the original config (default: CONFIG.bak)
  --no-reload         Update config only, do not send SIGHUP
  -h, --help          Show this help

The target YAML must follow the current astra-dns sample format and include
both Cloudflare rewrite blocks:
  - one rewrite with `ip:`
  - one rewrite with `cname:`
Each block must contain an `answer:` line.
EOF
}

log() {
	printf '%s\n' "$*" >&2
}

extract_best_ip() {
	awk -F, '
		NR >= 2 && $1 !~ /^#/ {
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
			if ($1 != "") {
				print $1
				exit
			}
		}
	' "$1"
}

is_ip() {
	value="$1"
	if printf '%s\n' "$value" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
		return 0
	fi
	if printf '%s\n' "$value" | grep -Eq '^[0-9A-Fa-f:]+$'; then
		return 0
	fi
	return 1
}

find_astra_pids() {
	if command -v pidof >/dev/null 2>&1; then
		pids="$(pidof astra-dns 2>/dev/null || true)"
		if [ -n "$pids" ]; then
			printf '%s\n' "$pids"
			return 0
		fi
	fi

	if command -v pgrep >/dev/null 2>&1; then
		pids="$(pgrep -x astra-dns 2>/dev/null || true)"
		if [ -z "$pids" ]; then
			pids="$(pgrep -f '/astra-dns( |$)' 2>/dev/null || true)"
		fi
		if [ -n "$pids" ]; then
			printf '%s\n' "$pids"
			return 0
		fi
	fi

	return 1
}

rewrite_config() {
	input="$1"
	output="$2"
	best_ip="$3"

	awk -v answer="$best_ip" '
		BEGIN {
			in_ip = 0
			in_cname = 0
			saw_ip = 0
			saw_cname = 0
		}

		/^    -[[:space:]]ip:[[:space:]]*$/ {
			in_ip = 1
			in_cname = 0
			print
			next
		}

		/^    -[[:space:]]cname:[[:space:]]*$/ {
			in_cname = 1
			in_ip = 0
			print
			next
		}

		/^    -[[:space:]]/ {
			in_ip = 0
			in_cname = 0
		}

		in_ip && /^[[:space:]]*answer:[[:space:]]*/ {
			sub(/answer:.*/, "answer: " answer)
			saw_ip = 1
			in_ip = 0
			print
			next
		}

		in_cname && /^[[:space:]]*answer:[[:space:]]*/ {
			sub(/answer:.*/, "answer: " answer)
			saw_cname = 1
			in_cname = 0
			print
			next
		}

		{
			print
		}

		END {
			if (!saw_ip || !saw_cname) {
				exit 42
			}
		}
	' "$input" >"$output"
}

RESULT_CSV=""
CONFIG_FILE=""
ASTRA_BIN="/usr/bin/astra-dns"
BACKUP_FILE=""
DO_RELOAD=1

while [ $# -gt 0 ]; do
	case "$1" in
		--result-csv)
			RESULT_CSV="${2:-}"
			shift 2
			;;
		--config)
			CONFIG_FILE="${2:-}"
			shift 2
			;;
		--bin)
			ASTRA_BIN="${2:-}"
			shift 2
			;;
		--backup)
			BACKUP_FILE="${2:-}"
			shift 2
			;;
		--no-reload)
			DO_RELOAD=0
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			log "unknown option: $1"
			usage
			exit 1
			;;
	esac
done

if [ -z "$RESULT_CSV" ] || [ -z "$CONFIG_FILE" ]; then
	usage
	exit 1
fi

if [ ! -f "$RESULT_CSV" ]; then
	log "result CSV not found: $RESULT_CSV"
	exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
	log "config file not found: $CONFIG_FILE"
	exit 1
fi

if [ ! -x "$ASTRA_BIN" ]; then
	log "astra-dns binary not found or not executable: $ASTRA_BIN"
	exit 1
fi

if [ -z "$BACKUP_FILE" ]; then
	BACKUP_FILE="${CONFIG_FILE}.bak"
fi

BEST_IP="$(extract_best_ip "$RESULT_CSV")"
if [ -z "$BEST_IP" ]; then
	log "failed to extract the best IP from $RESULT_CSV"
	exit 1
fi

if ! is_ip "$BEST_IP"; then
	log "invalid best IP: $BEST_IP"
	exit 1
fi

TMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/astra-dns-config.XXXXXX")"
trap 'rm -f "$TMP_CONFIG"' EXIT INT TERM

if ! rewrite_config "$CONFIG_FILE" "$TMP_CONFIG" "$BEST_IP"; then
	log "failed to update Cloudflare rewrite blocks in $CONFIG_FILE"
	exit 1
fi

log "validating updated config with $ASTRA_BIN"
"$ASTRA_BIN" --validate -c "$TMP_CONFIG"

cp "$CONFIG_FILE" "$BACKUP_FILE"
mv "$TMP_CONFIG" "$CONFIG_FILE"
trap - EXIT INT TERM

log "updated Cloudflare rewrite answers to $BEST_IP"

if [ "$DO_RELOAD" -eq 1 ]; then
	if pids="$(find_astra_pids)" && [ -n "$pids" ]; then
		kill -HUP $pids
		log "sent SIGHUP to astra-dns: $pids"
	else
		log "astra-dns is not running, config updated without reload"
	fi
fi
