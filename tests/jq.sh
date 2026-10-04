set -euo pipefail
wasm=$1
version=$2
test "$(wasmtime "$wasm" --version)" = "jq-$version"
test "$(printf '%s' '{"values":[1,2,3]}' | wasmtime "$wasm" -c '.values | map(. * 2)')" = '[2,4,6]'
test "$(wasmtime "$wasm" -nr '"abc123" | capture("(?<digits>[0-9]+)").digits')" = '123'
test "$(wasmtime "$wasm" -nc '1.23 + 2')" = '3.23'
test "$(printf '%s\n' 1 2 3 | wasmtime "$wasm" -sc 'add')" = '6'
mkdir data
printf '%s' '{"ok":true}' > data/input.json
test "$(wasmtime --dir data::/data "$wasm" -r '.ok' /data/input.json)" = 'true'
set +e
wasmtime "$wasm" -ne false
status=$?
set -e
test "$status" = 1
set +e
printf '%s' '{broken' | wasmtime "$wasm" '.'
status=$?
set -e
test "$status" = 5
