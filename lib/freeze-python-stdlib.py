"""Embed pure-Python stdlib modules using CPython's frozen-module mechanism."""
import marshal
import pathlib
import re

root = pathlib.Path('Lib')
frozen = pathlib.Path('Python/frozen.c')
source = frozen.read_text()
existing = set(re.findall(r'\{"([^"]+)"', source))
existing.update(re.findall(r'frozen_modules/([^"]+)\.h', source))
entries = []
includes = []
modules = []
for path in sorted(root.rglob('*.py')):
    parts = path.relative_to(root).with_suffix('').parts
    if any(p in {'test', 'tests', 'idlelib', 'tkinter', 'turtledemo', 'ensurepip', '__pycache__'} for p in parts):
        continue
    package = parts[-1] == '__init__'
    name = '.'.join(parts[:-1] if package else parts)
    if not name or name in existing:
        continue
    symbol = '_wasm_stdlib_' + name.encode().hex()
    contents = path.read_bytes()
    if name.startswith('_sysconfigdata_'):
        contents = contents.replace(str(pathlib.Path.cwd()).encode(), b'/build')
    data = marshal.dumps(compile(contents, '/stdlib/' + str(path.relative_to(root)), 'exec'))
    header = pathlib.Path('Python/frozen_modules') / (name + '.h')
    header.write_text('static const unsigned char ' + symbol + '[] = {\n' + ','.join(str(b) for b in data) + '\n};\n')
    includes.append(f'#include "frozen_modules/{name}.h"\n')
    entries.append(f'    {{"{name}", {symbol}, sizeof({symbol}), {str(package).lower()}}},\n')
    modules.append(name)
source = source.replace('const struct _frozen *PyImport_FrozenModules = NULL;', ''.join(includes) + '\nstatic const struct _frozen bundled_stdlib[] = {\n' + ''.join(entries) + '    {0, 0, 0}\n};\nconst struct _frozen *PyImport_FrozenModules = bundled_stdlib;')
frozen.write_text(source)
pathlib.Path('frozen-stdlib.txt').write_text('\n'.join(modules) + '\n')

# No on-disk stdlib or shared extension directory is needed by this build.
getpath = pathlib.Path('Modules/getpath.py')
text = getpath.read_text()
for message in ['Could not find platform independent libraries <prefix>', 'Could not find platform dependent libraries <exec_prefix>']:
    text = text.replace(f"warn({message!r})", 'pass  # Standard library is embedded in the module.')
getpath.write_text(text)
