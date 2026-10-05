import pathlib
import subprocess
import sys
import tempfile

wasm, commands_path = sys.argv[1:]
commands = pathlib.Path(commands_path).read_text().splitlines()
def run(*args, data=None, mounted=False, status=0):
    command = ['wasmtime']
    if mounted:
        command += ['--dir', f'{work}::/']
    result = subprocess.run(command + [wasm, *args], input=data, capture_output=True, text=True)
    assert result.returncode == status, (args, result.returncode, result.stderr)
    return result.stdout
assert commands[0] == 'coreutils'
assert run('--list').splitlines() == commands[1:]
for applet in commands[1:]:
    # false intentionally returns failure, even when passed --help.
    run(applet, '--help', status=1 if applet == 'false' else 0)
assert run('cat', data='hello\n') == 'hello\n'
assert run('base64', data='hello') == 'aGVsbG8=\n'
assert run('sort', data='b\na\n') == 'a\nb\n'
assert run('uniq', data='a\na\nb\n') == 'a\nb\n'
assert run('wc', '-l', data='a\nb\n').strip() == '2'
assert run('printf', '%s:%s', 'a', 'b') == 'a:b'
run('true')
run('false', status=1)
run('[', 'a', '=', 'a', ']')
with tempfile.TemporaryDirectory() as work:
    run('mkdir', '/sub', mounted=True)
    pathlib.Path(work, 'sub/input').write_text('hello\n')
    run('cp', '/sub/input', '/copy', mounted=True)
    assert run('cat', '/copy', mounted=True) == 'hello\n'
    run('mv', '/copy', '/moved', mounted=True)
    assert run('ls', '/', mounted=True).split() == ['moved', 'sub']
    run('rm', '/moved', mounted=True)
    assert not pathlib.Path(work, 'moved').exists()
run('cat', '/missing', status=1)
print(f'verified {len(commands) - 1} applets and multicall file operations')
