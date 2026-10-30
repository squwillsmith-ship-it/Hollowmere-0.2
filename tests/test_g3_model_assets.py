"""Pure-stdlib QA for real authored G3 binary assets and original part binding.
A passing result validates GLB/PNG packaging, not Godot import or visual quality.
"""
from __future__ import annotations
import json
from pathlib import Path
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "game/assets/models/g3/kit"
TEXTURES = ROOT / "game/assets/materials/g3"
DISTRICTS = ROOT / "game/data/v1/brinewick_district_builds.json"
PROFILES = ("stone", "timber", "lime")
GROUPS = {
    "harbour/office", "harbour/net_store", "district/mara_home",
    "district/upper_cottage_cluster_study", "craft/tomas_workshop",
    "chapel/ordinary_hall", "chapel/schoolroom_wing",
    "chapel/aldren_study", "service/boatyard_base",
    "harbour/navigation_light",
}
MAT = {"stone": "stone", "plaster": "lime", "wood": "timber",
       "wood_dark": "timber", "wood_salt": "timber"}
TOKEN = ("wall", "panel", "masonry", "spine", "frame", "stud", "post",
         "pier", "weatherboard", "lintel", "infill", "studyback")
SKIP = ("roof", "slope", "door", "floor", "ramp", "shelf", "rack",
        "window", "lantern")


def png_info(raw: bytes) -> tuple[int, int, bytes]:
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", "PNG signature incorrect"
    pos, image = 8, bytearray()
    width = height = -1
    while pos < len(raw):
        length = struct.unpack_from(">I", raw, pos)[0]
        name = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        crc = struct.unpack_from(">I", raw, pos + 8 + length)[0]
        assert crc == zlib.crc32(name + data), "PNG chunk CRC incorrect"
        pos += length + 12
        if name == b"IHDR":
            width, height = struct.unpack_from(">II", data)
            assert data[8:10] == b"\x08\x02", "Expected RGB8"
        if name == b"IDAT":
            image.extend(data)
        if name == b"IEND":
            break
    assert pos == len(raw), "PNG trailing bytes"
    unpacked = zlib.decompress(image)
    assert len(unpacked) == height * (1 + width * 3), "Bad PNG raster size"
    assert all(unpacked[y * (1 + width * 3)] == 0 for y in range(height)), "PNG scanline filters"
    return width, height, unpacked


def glb_info(raw: bytes) -> tuple[dict, bytes]:
    assert raw[:4] == b"glTF", "Missing glTF magic"
    version, length = struct.unpack_from("<II", raw, 4)
    assert version == 2 and length == len(raw), "Wrong GLB version/length"
    json_size, json_tag = struct.unpack_from("<I4s", raw, 12)
    assert json_tag == b"JSON"
    obj = json.loads(raw[20:20 + json_size])
    offset = 20 + json_size
    bin_size, bin_tag = struct.unpack_from("<I4s", raw, offset)
    assert bin_tag == b"BIN\x00"
    binary = raw[offset + 8:offset + 8 + bin_size]
    assert offset + 8 + bin_size == len(raw)
    assert obj["buffers"][0]["byteLength"] <= len(binary)
    return obj, binary


class G3ModelAssets(unittest.TestCase):
    def test_all_six_models_importable_container(self):
        for profile in PROFILES:
            for axis in ("x", "z"):
                with self.subTest(profile=profile, axis=axis):
                    data = (MODELS / f"{profile}_wall_{axis}.glb").read_bytes()
                    obj, binary = glb_info(data)
                    assert obj["scenes"][0]["nodes"] == [0]
                    assert obj["nodes"][0]["mesh"] == 0
                    assert obj["materials"] and obj["images"]
                    triangles = 0
                    for part in obj["meshes"][0]["primitives"]:
                        indices = obj["accessors"][part["indices"]]
                        vertices = obj["accessors"][part["attributes"]["POSITION"]]
                        normals = obj["accessors"][part["attributes"]["NORMAL"]]
                        uv = obj["accessors"][part["attributes"]["TEXCOORD_0"]]
                        self.assertEqual(indices["count"] % 3, 0)
                        self.assertEqual(vertices["count"], normals["count"])
                        self.assertEqual(vertices["count"], uv["count"])
                        for acc in (indices, vertices, normals, uv):
                            buf = obj["bufferViews"][acc["bufferView"]]
                            self.assertLessEqual(buf["byteOffset"] + buf["byteLength"], len(binary))
                        triangles += indices["count"] // 3
                    self.assertGreaterEqual(triangles, 100)
                    for image in obj["images"]:
                        view = obj["bufferViews"][image["bufferView"]]
                        blob = binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]]
                        self.assertEqual(png_info(blob)[:2], (128, 128))

    def test_pbr_sources_match_embedded_gltf_images(self):
        for profile in PROFILES:
            for axis in ("x", "z"):
                blob = (MODELS / f"{profile}_wall_{axis}.glb").read_bytes()
                gltf, binary = glb_info(blob)
                checked = 0
                for img in gltf["images"]:
                    name = img["name"]
                    for kind in ("stone", "wood", "lime"):
                        if not name.startswith("g3_" + kind + "_"):
                            continue
                        channel = "orm" if name.endswith("_orm") else "albedo"
                        expected = (TEXTURES / f"{kind}_{channel}.png").read_bytes()
                        view = gltf["bufferViews"][img["bufferView"]]
                        start = view["byteOffset"]
                        actual = binary[start:start + view["byteLength"]]
                        self.assertEqual(actual, expected,
                            f"Embedded GLB material diverges from G3 source: {name}")
                        checked += 1
                self.assertGreaterEqual(checked, 2)

    def test_six_editable_pbr_sources(self):
        for material in ("stone", "wood", "lime"):
            for channel in ("albedo", "orm"):
                with self.subTest(material=material, channel=channel):
                    raw = (TEXTURES / f"{material}_{channel}.png").read_bytes()
                    width, height, raster = png_info(raw)
                    self.assertEqual((width, height), (128, 128))
                    self.assertGreaterEqual(len(set(raster)), 16 if channel == "albedo" else 3)

    def test_only_original_buildings_and_saved_owners(self):
        data = json.loads(DISTRICTS.read_text())
        found, total, saved = set(), 0, 0
        for group in data["installations"]:
            if group["id"] not in GROUPS:
                continue
            found.add(group["id"])
            for row in group.get("geometry", []):
                title = row.get("name", "").lower()
                dims = row.get("size", [])
                if (row.get("material") not in MAT or len(dims) != 3
                        or min(dims) <= .05 or any(t in title for t in SKIP)
                        or not any(t in title for t in TOKEN)):
                    continue
                source = f"{MAT[row['material']]}_wall_{'x' if dims[0] < dims[2] else 'z'}.glb"
                self.assertTrue((MODELS / source).is_file())
                total += 1
                saved += bool(row.get("removable_part_id"))
        self.assertEqual(len(found), 10)
        self.assertEqual(total, 122)
        self.assertEqual(saved, 104)


if __name__ == "__main__":
    unittest.main()
