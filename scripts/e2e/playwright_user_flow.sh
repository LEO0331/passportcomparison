#!/usr/bin/env bash
set -euo pipefail

exec node "$(dirname "$0")/playwright_user_flow.cjs" "$@"
