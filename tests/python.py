import pathlib
import subprocess
import sys
import tempfile

wasm, version = sys.argv[1:]

def run(*args, data=None, directory=None, status=0):
    command = ['wasmtime']
    if directory:
        command += ['--dir', f'{directory}::/']
    result = subprocess.run(command + [wasm, *args], input=data, text=True, capture_output=True)
    assert result.returncode == status, (args, result.stdout, result.stderr)
    if status == 0:
        assert not result.stderr, (args, result.stderr)
    return result.stdout

assert run('--version').strip() == f'Python {version}'
assert run('-c', 'import sys; print(sys.platform)') == 'wasi\n'
assert run('-c', 'import json, math, pathlib, re, decimal, hashlib; print(json.dumps([math.isqrt(81), str(decimal.Decimal("0.1") + decimal.Decimal("0.2")), hashlib.sha256(b"hello").hexdigest()]))') == '[9, "0.3", "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"]\n'
assert '"hello": "world"' in run('-m', 'json.tool', data='{"hello":"world"}')
assert run('-c', 'import gzip; assert gzip.decompress(gzip.compress(b"hello")) == b"hello"; print("gzip")') == 'gzip\n'
assert run('-c', 'import sysconfig; print(sysconfig.get_config_var("SIZEOF_VOID_P"))') == '4\n'
assert run('-', data='print("stdin script")\n') == 'stdin script\n'
with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    (root / 'helper.py').write_text('value = 42\n')
    (root / 'script.py').write_text('import helper, pathlib, sys\npathlib.Path("/output").write_text(str(helper.value))\nprint(sys.argv[1])\n')
    assert run('/script.py', 'argument', directory=directory) == 'argument\n'
    assert (root / 'output').read_text() == '42'
run('-c', 'raise ValueError("expected")', status=1)
run('-c', 'open("/missing")', status=1)
print('verified Python version, frozen stdlib, -c/-m/stdin/scripts, local imports and filesystem I/O')
