"""Verify the multicall binary exposes every upstream feat_wasm applet."""
import json
import pathlib
import sys
import tomllib

manifest = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
features = manifest['features']
def expand(feature):
    if feature in features:
        return set().union(*(expand(child) for child in features[feature]))
    return {feature}

expected = expand('feat_wasm')
if 'uu_test' in expected:
    expected.remove('uu_test')
    expected.update(['test', '['])
actual = pathlib.Path(sys.argv[2]).read_text().splitlines()
assert len(actual) == len(set(actual))
assert set(actual) == expected, (sorted(expected - set(actual)), sorted(set(actual) - expected))
all_applets = set()
dependency_groups = [manifest['dependencies']]
dependency_groups += [target.get('dependencies', {}) for target in manifest.get('target', {}).values()]
for dependencies in dependency_groups:
    for name, dependency in dependencies.items():
        if dependency.get('optional') and (dependency.get('package', '').startswith('uu_') or name == 'uu_test'):
            all_applets.add('test' if name == 'uu_test' else name)
all_applets.add('[')
output = pathlib.Path(sys.argv[3])
(output / 'excluded-commands.txt').write_text(''.join(f'{name}\n' for name in sorted(all_applets - expected)))
(output / 'inventory.json').write_text(json.dumps({'feature': 'feat_wasm', 'applets': actual, 'excluded': sorted(all_applets - expected)}, indent=2) + '\n')
