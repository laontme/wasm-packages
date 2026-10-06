import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])


def read(descriptor):
    data = (root / "blobs" / "sha256" / descriptor["digest"].split(":")[1]).read_bytes()
    assert len(data) == descriptor["size"]
    assert "sha256:" + hashlib.sha256(data).hexdigest() == descriptor["digest"]
    return data


assert json.loads((root / "oci-layout").read_text())["imageLayoutVersion"] == "1.0.0"
index = json.loads((root / "index.json").read_text())
assert len(index["manifests"]) == 1
manifest = json.loads(read(index["manifests"][0]))
commands = manifest["annotations"]["me.laont.wasm.commands"].split(",")
assert manifest["annotations"]["org.opencontainers.image.description"]
expected_command = {"ripgrep": "rg", "jq": "jq"}.get(manifest["annotations"]["org.opencontainers.image.title"])
if expected_command:
    assert commands == [expected_command]
assert len(commands) == len(set(commands))
assert all(commands)
if len(sys.argv) > 5:
    assert commands == sys.argv[5].split(",")
assert manifest["schemaVersion"] == 2
assert manifest["mediaType"] == "application/vnd.oci.image.manifest.v1+json"
assert manifest["config"]["mediaType"] == "application/vnd.wasm.config.v0+json"
config = json.loads(read(manifest["config"]))
wasi = sys.argv[3] if len(sys.argv) > 3 else "wasip1"
assert (config["os"], config["architecture"]) == (wasi, "wasm")
if wasi == "wasip2":
    expected_imports = pathlib.Path(sys.argv[4]).read_text().splitlines()
    assert config["component"]["imports"] == expected_imports
    assert config["component"]["exports"] == ["wasi:cli/run@0.2.0"]
else:
    assert "component" not in config
assert "rootfs" not in config
assert len(manifest["layers"]) == 1
layer = manifest["layers"][0]
assert layer["mediaType"] == "application/wasm"
assert config["layerDigests"] == [layer["digest"]]
wasm = read(layer)
if manifest["annotations"]["org.opencontainers.image.title"] == "ripgrep":
    assert len(wasm) <= 16 * 1024 * 1024, "ripgrep exceeds Emmux module limit"
assert wasm == pathlib.Path(sys.argv[2]).read_bytes()
assert wasm[:8] == (b"\0asm\x0d\0\x01\0" if wasi == "wasip2" else b"\0asm\x01\0\0\0")

# Validate the actual OCI payload, so CI cannot publish DWARF-heavy modules.
if wasi == "wasip1":
    def uleb(offset):
        value, shift = 0, 0
        while True:
            byte = wasm[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value, offset
            shift += 7

    offset = 8
    while offset < len(wasm):
        section_id = wasm[offset]
        size, start = uleb(offset + 1)
        offset = start + size
        assert offset <= len(wasm)
        if section_id == 0:
            length, name_start = uleb(start)
            name = wasm[name_start:name_start + length].decode("utf-8")
            assert not name.startswith(".debug_"), name
            assert name not in {"name", "sourceMappingURL", "external_debug_info"}, name
    assert offset == len(wasm)
