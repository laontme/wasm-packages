import gzip
import hashlib
import io
import json
import pathlib
import sys
import tarfile

root = pathlib.Path(sys.argv[1])


def read(descriptor):
    data = (root / "blobs" / "sha256" / descriptor["digest"].split(":")[1]).read_bytes()
    assert len(data) == descriptor["size"]
    assert "sha256:" + hashlib.sha256(data).hexdigest() == descriptor["digest"]
    return data


assert json.loads((root / "oci-layout").read_text())["imageLayoutVersion"] == "1.0.0"
descriptor = json.loads((root / "index.json").read_text())["manifests"][0]
assert descriptor["platform"]["os"] == "wasi"
assert descriptor["platform"]["architecture"] == "wasm"
manifest = json.loads(read(descriptor))
config = json.loads(read(manifest["config"]))
assert (config["os"], config["architecture"]) == ("wasi", "wasm")
assert config["config"]["Entrypoint"] == ["/bin/jq.wasm"]
layer = manifest["layers"][0]
assert layer["mediaType"] == "application/vnd.oci.image.layer.v1.tar+gzip"
tar_bytes = gzip.decompress(read(layer))
assert config["rootfs"]["diff_ids"] == ["sha256:" + hashlib.sha256(tar_bytes).hexdigest()]
assert manifest["annotations"]["io.emmux.wasi.preview"] == "1"
with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as archive:
    wasm = archive.extractfile("bin/jq.wasm").read()
    assert wasm == pathlib.Path(sys.argv[2]).read_bytes()
    assert wasm[:8] == b"\0asm\x01\0\0\0"
    assert archive.extractfile("share/licenses/jq/COPYING").read()
    assert archive.extractfile("share/licenses/jq/oniguruma-COPYING").read()
    assert not any("nix/store" in member.name for member in archive)
