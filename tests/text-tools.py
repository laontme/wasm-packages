import pathlib
import subprocess
import sys
import tempfile

kind, wasm = sys.argv[1:]
assert pathlib.Path(wasm).stat().st_size <= 16 * 1024 * 1024, 'module exceeds Emmux limit'
with tempfile.TemporaryDirectory() as work:
    root = pathlib.Path(work)
    (root / 'sub').mkdir()
    (root / 'input').write_text('alpha\nBeta\nalpha beta\nend\n')
    (root / 'sub/match.txt').write_text('alpha\n')
    (root / 'sub/other').write_text('other\n')
    def run(*args, data=None, status=0):
        result = subprocess.run(['wasmtime', '--dir', f'{work}::/', wasm, *args],
                                input=data, capture_output=True, text=True)
        assert result.returncode == status, (args, result.returncode, result.stdout, result.stderr)
        return result.stdout
    if kind == 'grep':
        run('--help')
        assert run('alpha', '/input') == 'alpha\nalpha beta\n'
        assert run('-i', '-n', '^beta$', '/input') == '2:Beta\n'
        assert run('-E', '^(alpha|Beta)$', '/input') == 'alpha\nBeta\n'
        assert run('-F', 'a.b', data='a.b\naxb\n') == 'a.b\n'
        assert run(r'^\(ab\)\1$', data='abab\nab\n') == 'abab\n'
        assert run('-A', '1', '^Beta$', '/input') == 'Beta\nalpha beta\n'
        assert run('-r', '-l', 'alpha', '/sub').splitlines() == ['/sub/match.txt']
        run('missing', '/input', status=1)
        run('[', '/input', status=2)
        run('alpha', '/absent', status=2)
    elif kind == 'sed':
        run('--help')
        assert run('s/alpha/ALPHA/g', '/input') == 'ALPHA\nBeta\nALPHA beta\nend\n'
        assert run('-n', '2,3p', '/input') == 'Beta\nalpha beta\n'
        assert run(r's/\(alpha\) \(beta\)/\2 \1/', data='alpha beta\n') == 'beta alpha\n'
        assert run('-E', 's/(alpha|beta)/X/g', data='alpha beta\n') == 'X X\n'
        assert run('-n', '1h;2{G;p;}', data='first\nsecond\n') == 'second\nfirst\n'
        (root / 'script').write_text('s/alpha/A/g\n')
        assert run('-f', '/script', data='alpha\n') == 'A\n'
        run('-i.bak', 's/alpha/A/g', '/input')
        assert (root / 'input').read_text().startswith('A\n')
        assert (root / 'input.bak').read_text().startswith('alpha\n')
        run('w /output', '/input')
        assert (root / 'output').read_text() == (root / 'input').read_text()
        run('s/[/', data='a\n', status=1)
        run('e echo hello', data='a\n', status=2)
        run('s/a/echo hello/e', data='a\n', status=2)
    elif kind == 'findutils':
        assert run('--list').splitlines() == ['find', 'locate', 'updatedb']
        for command in ['find', 'locate', 'updatedb']:
            run(command, '--help')
        assert run('find', '/sub', '-type', 'f', '-name', '*.txt') == '/sub/match.txt\n'
        assert set(run('find', '/sub', '-name', 'other', '-o', '-name', '*.txt').splitlines()) == {'/sub/match.txt', '/sub/other'}
        assert run('find', '/sub', '-maxdepth', '0') == '/sub\n'
        assert run('find', '/sub', '-name', 'other', '-print0') == '/sub/other\0'
        assert run('find', '/sub', '-name', 'match.txt', '-printf', '%f\n') == 'match.txt\n'
        assert run('find', '/sub', '-regex', '.*match[.]txt') == '/sub/match.txt\n'
        run('updatedb', '--localpaths=/sub', '--prunepaths=', '--output=/db')
        assert run('locate', '-d', '/db', 'match.txt') == '/sub/match.txt\n'
        assert run('locate', '-d', '/db:/db', '-c', 'match.txt') == '2\n'
        run('find', '/sub', '-name', 'other', '-delete')
        assert not (root / 'sub/other').exists()
        run('xargs', status=2)
    else:
        raise AssertionError(kind)
print(f'verified {kind} WASI command behavior')
