#!/usr/bin/env bash
# Serves a web build on this machine, for testing in a browser. Opening index.html straight
# from disk fails ("failed to fetch"): browsers don't let a file:// page load the engine.
#   tools/serve_web.sh              build/web        at http://localhost:8080
#   tools/serve_web.sh crazygames   build/crazygames at http://localhost:8080
# PORT=<n> picks another port. Every response says "don't cache", so a rebuilt game is what
# loads, not the copy the browser kept from last time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/build/${1:-web}"
PORT="${PORT:-8080}"
[ -f "$DIR/index.html" ] || { echo "No build in $DIR: run tools/build_web.sh ${1:-}" >&2; exit 1; }

echo "Serving $DIR at http://localhost:$PORT (Ctrl+C to stop)"
cd "$DIR"
exec python3 -c '
import http.server, sys
class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
http.server.ThreadingHTTPServer(("", int(sys.argv[1])), NoCache).serve_forever()
' "$PORT"
