set -euo pipefail
wasm=$1
version=$2
error_status=$3
version_output=$(wasmtime "$wasm" --version)
test "$(printf '%s\n' "$version_output" | head -1)" = "ripgrep $version"
test "$(printf 'abc123\nxyz\n' | wasmtime "$wasm" -o '[0-9]+' -)" = '123'
mkdir -p data/sub
printf 'hello world\nHELLO again\n' > data/sub/input.txt
printf 'hello ignored\n' > data/sub/skip.txt
printf 'skip.txt\n' > data/.ignore
printf 'hello hidden\n' > data/.hidden
test "$(wasmtime --dir data::/data "$wasm" --no-heading --color never -i -c hello /data/sub/input.txt)" = '2'
test "$(wasmtime --dir data::/data "$wasm" --no-heading --color never -l hello /data)" = '/data/sub/input.txt'
set +e
printf 'abc\n' | wasmtime "$wasm" missing -
status=$?
set -e
test "$status" = 1
set +e
wasmtime "$wasm" '[' - </dev/null
status=$?
set -e
test "$status" = "$error_status"
