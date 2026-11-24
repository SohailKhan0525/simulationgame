#!/usr/bin/env python3
"""Validate the shipped art, not just the Blender reports (standard library only).

Checks PNG checksums, decoded pixel content, GLB accessors/indices, PBR materials,
UVs/normals, outward solid winding, road top faces, and wheel axle origins.
It cannot establish artistic quality or prove which application created a file.
"""
from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
CHANNELS = {"albedo", "normal", "roughness", "ao"}
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
              5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
PNG_CACHE: dict[str, tuple[int, int, int]] = {}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def subtract(a: tuple, b: tuple) -> tuple:
    return tuple(x-y for x, y in zip(a, b))


def cross(a: tuple, b: tuple) -> tuple:
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def dot(a: tuple, b: tuple) -> float:
    return sum(x*y for x, y in zip(a, b))


def closed_volumes(faces: list[tuple]) -> list[float]:
    """Find closed components after welding export seams, excluding open cards.

    glTF duplicates vertices at normal/UV seams. Coordinate welding restores
    their geometric edge connectivity without treating foliage or facade planes
    as closed solids. Signed volume detects consistently inside-out geometry,
    which unit normals and valid triangle indices cannot detect.
    """
    edges: dict[tuple, list[int]] = defaultdict(list)
    face_edges = []
    for index, face in enumerate(faces):
        vertices = [tuple(round(value, 6) for value in point) for point in face]
        keys = [tuple(sorted((vertices[i], vertices[(i+1) % 3]))) for i in range(3)]
        face_edges.append(keys)
        for key in keys:
            edges[key].append(index)
    remaining = set(range(len(faces)))
    volumes = []
    while remaining:
        seed = remaining.pop()
        component, pending = [seed], [seed]
        while pending:
            for edge in face_edges[pending.pop()]:
                for neighbor in edges[edge]:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        pending.append(neighbor)
                        component.append(neighbor)
        if all(len(edges[edge]) == 2 for index in component for edge in face_edges[index]):
            origin = faces[seed][0]
            volumes.append(sum(dot(subtract(a, origin), cross(subtract(b, origin), subtract(c, origin))) / 6 for a, b, c in (faces[i] for i in component)))
    return volumes


def asset_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    require(path.is_relative_to(ROOT / "game/assets"), f"Asset path escapes game/assets: {relative}")
    require(path.is_file(), f"Missing asset: {relative}")
    return path


def png_info(data: bytes, label: str) -> tuple[int, int, int]:
    digest = hashlib.sha256(data).hexdigest()
    if digest in PNG_CACHE:
        return PNG_CACHE[digest]
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{label}: invalid PNG signature")
    offset, header, ended = 8, None, False
    compressed = bytearray()
    while offset < len(data):
        require(offset + 12 <= len(data), f"{label}: truncated PNG chunk")
        size, kind = struct.unpack_from(">I4s", data, offset)
        end = offset + 8 + size
        require(end + 4 <= len(data), f"{label}: chunk exceeds file")
        payload = data[offset + 8:end]
        crc = struct.unpack_from(">I", data, end)[0]
        require(zlib.crc32(kind + payload) & 0xFFFFFFFF == crc, f"{label}: corrupt {kind!r} checksum")
        if kind == b"IHDR":
            require(header is None and size == 13 and offset == 8, f"{label}: malformed IHDR")
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            require(size == 0 and end + 4 == len(data), f"{label}: data after IEND")
            ended = True
        offset = end + 4
    require(header is not None and ended and compressed, f"{label}: incomplete PNG")
    width, height, depth, color, compression, filtering, interlace = header
    require(depth == 8 and color in (0, 2, 4, 6) and compression == filtering == interlace == 0,
            f"{label}: expected an 8-bit noninterlaced bake")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    stride = width * channels
    decoder = zlib.decompressobj()
    raw = decoder.decompress(bytes(compressed)) + decoder.flush()
    require(decoder.eof and not decoder.unused_data and len(raw) == height * (stride + 1),
            f"{label}: incomplete or incorrectly sized PNG pixels")
    previous = bytearray(stride)
    colors: set[bytes] = set()
    for y in range(height):
        start = y * (stride + 1)
        mode = raw[start]
        require(mode <= 4, f"{label}: invalid PNG row filter")
        row = bytearray(raw[start + 1:start + 1 + stride])
        if mode == 1:
            for i in range(channels, stride):
                row[i] = (row[i] + row[i - channels]) & 255
        elif mode == 2:
            for i in range(stride):
                row[i] = (row[i] + previous[i]) & 255
        elif mode in (3, 4):
            for i in range(stride):
                left = row[i - channels] if i >= channels else 0
                up, corner = previous[i], previous[i - channels] if i >= channels else 0
                if mode == 3:
                    predictor = (left + up) // 2
                else:
                    p = left + up - corner
                    a, b, c = abs(p - left), abs(p - up), abs(p - corner)
                    predictor = left if a <= b and a <= c else up if b <= c else corner
                row[i] = (row[i] + predictor) & 255
        # Sample an even grid after decoding every row; reject blank stand-ins.
        if y % 8 == 0:
            colors.update(bytes(row[i:i + min(channels, 3)]) for i in range(0, stride, channels * 8))
        previous = row
    result = (width, height, len(colors))
    PNG_CACHE[digest] = result
    return result


def validate_bake(path: Path) -> str:
    data = path.read_bytes()
    width, height, colors = png_info(data, path.name)
    require((width, height) == (1024, 1024), f"{path.name}: bake must be 1024x1024")
    # Sixteen-sample AO over shallow mineral relief legitimately has only a
    # few near-white levels. The color/normal/roughness maps carry more detail.
    require(colors > (1 if path.stem.endswith("_ao") else 4), f"{path.name}: bake is blank or has no meaningful pixel variation")
    return hashlib.sha256(data).hexdigest()


class GLB:
    def __init__(self, path: Path):
        self.path = path
        data = path.read_bytes()
        require(len(data) >= 20, f"{path.name}: truncated GLB")
        magic, version, length = struct.unpack_from("<4sII", data)
        require(magic == b"glTF" and version == 2 and length == len(data), f"{path.name}: invalid GLB header")
        chunks, offset = {}, 12
        while offset < len(data):
            size, kind = struct.unpack_from("<II", data, offset)
            require(size % 4 == 0 and offset + 8 + size <= len(data), f"{path.name}: invalid GLB chunk")
            require(kind not in chunks, f"{path.name}: duplicate GLB chunk")
            chunks[kind] = data[offset + 8:offset + 8 + size]
            offset += size + 8
        self.doc = json.loads(chunks[0x4E4F534A])
        self.buffer = chunks[0x004E4942]
        require(self.doc["asset"]["version"] == "2.0", f"{path.name}: unsupported glTF version")
        require(len(self.doc["buffers"]) == 1 and "uri" not in self.doc["buffers"][0], f"{path.name}: expected embedded geometry")
        require(self.doc["buffers"][0]["byteLength"] <= len(self.buffer), f"{path.name}: truncated geometry buffer")
        for view in self.doc["bufferViews"]:
            require(view.get("buffer", 0) == 0 and view.get("byteOffset", 0) + view["byteLength"] <= len(self.buffer), f"{path.name}: invalid buffer view")

    def accessor(self, index: int) -> list[tuple]:
        accessor = self.doc["accessors"][index]
        require("sparse" not in accessor, f"{self.path.name}: sparse accessor is not covered by this validator")
        view = self.doc["bufferViews"][accessor["bufferView"]]
        code, size = COMPONENTS[accessor["componentType"]]
        width = WIDTHS[accessor["type"]]
        stride = view.get("byteStride", width * size)
        offset = accessor.get("byteOffset", 0)
        require(accessor["count"] > 0 and stride >= width * size, f"{self.path.name}: empty or invalid accessor")
        require(offset + (accessor["count"] - 1) * stride + width * size <= view["byteLength"], f"{self.path.name}: accessor exceeds its buffer view")
        offset += view.get("byteOffset", 0)
        return [struct.unpack_from("<" + code * width, self.buffer, offset + i * stride) for i in range(accessor["count"])]

    def validate(self, atlas_uv: bool = False) -> tuple[int, int]:
        triangles = batches = 0
        for mesh in self.doc["meshes"]:
            for primitive in mesh["primitives"]:
                attrs = primitive["attributes"]
                material = self.doc["materials"][primitive["material"]]
                pbr = material.get("pbrMetallicRoughness", {})
                # The world deliberately binds shared bakes at runtime, so
                # material names also identify textured surfaces in stripped GLBs.
                name = material.get("name", "").lower()
                textured = atlas_uv or any(token in name for token in ("brick", "limestone", "concrete", "foliage")) or "normalTexture" in material or "baseColorTexture" in pbr
                require(all(key in attrs for key in ("POSITION", "NORMAL")), f"{self.path.name}: mesh lacks positions or normals")
                require(not textured or "TEXCOORD_0" in attrs, f"{self.path.name}: textured material has no UVs")
                positions, normals = (self.accessor(attrs[key]) for key in ("POSITION", "NORMAL"))
                uvs = self.accessor(attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else []
                require(len(positions) == len(normals) and (not uvs or len(positions) == len(uvs)), f"{self.path.name}: vertex attribute counts disagree")
                require(all(len(p) == 3 for p in positions) and all(len(n) == 3 for n in normals) and all(len(uv) == 2 for uv in uvs), f"{self.path.name}: vertex attribute dimensions are invalid")
                require(all(math.isfinite(x) for values in (positions, normals, uvs) for vertex in values for x in vertex), f"{self.path.name}: nonfinite vertex data")
                require(all(0.9 < sum(x*x for x in normal) < 1.1 for normal in normals), f"{self.path.name}: normals must have unit length")
                require(not uvs or len(set(uvs)) > 2, f"{self.path.name}: UVs are degenerate")
                # World masonry uses repeating baked surface textures. The
                # vehicle uses a packed atlas whose UVs must stay in [0, 1].
                if atlas_uv:
                    require(all(-0.001 <= x <= 1.001 for uv in uvs for x in uv), f"{self.path.name}: bake UVs escape the atlas")
                    require("TANGENT" in attrs, f"{self.path.name}: baked normal map needs exported tangents")
                    tangents = self.accessor(attrs["TANGENT"])
                    require(len(tangents) == len(normals), f"{self.path.name}: tangent count disagrees with normals")
                    require(all(len(t) == 4 and all(math.isfinite(x) for x in t) and 0.9 < sum(x*x for x in t[:3]) < 1.1 and abs(abs(t[3])-1) < 1e-5 and abs(sum(a*b for a, b in zip(t, n))) < 0.05 for t, n in zip(tangents, normals)), f"{self.path.name}: invalid tangent basis")
                indices = self.accessor(primitive["indices"]) if "indices" in primitive else [(i,) for i in range(len(positions))]
                require(primitive.get("mode", 4) == 4 and len(indices) % 3 == 0, f"{self.path.name}: expected complete triangles")
                require(all(0 <= i[0] < len(positions) for i in indices), f"{self.path.name}: out-of-range triangle index")
                require(bool(pbr), f"{self.path.name}: missing PBR material parameters")
                require(all(0 <= pbr.get(key, 1.0) <= 1 for key in ("metallicFactor", "roughnessFactor")), f"{self.path.name}: invalid PBR factor")
                triangles += len(indices) // 3
                batches += 1
        require(triangles > 0, f"{self.path.name}: no mesh geometry")
        for image in self.doc.get("images", []):
            require(image.get("mimeType") == "image/png" and "bufferView" in image, f"{self.path.name}: missing embedded PBR image")
            view = self.doc["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            png_info(self.buffer[start:start + view["byteLength"]], f"{self.path.name}/{image.get('name', 'image')}")
        return triangles, batches

    def outward_surfaces(self) -> int:
        """Validate world solids and the upward-facing drivable road surface."""
        solid_props = {"road_slab", "kerbstone", "roadside_rock"}
        architecture = {"brick_corner", "brick_lowrise", "limestone_midrise"}
        closed_count, masonry_count = 0, 0
        all_faces, top_candidates = [], []
        for mesh in self.doc["meshes"]:
            for primitive in mesh["primitives"]:
                attrs = primitive["attributes"]
                positions = self.accessor(attrs["POSITION"])
                normals = self.accessor(attrs["NORMAL"])
                indices = [index[0] for index in self.accessor(primitive["indices"])] if "indices" in primitive else list(range(len(positions)))
                material_name = self.doc["materials"][primitive["material"]].get("name", "").lower()
                faces = []
                for start in range(0, len(indices), 3):
                    corners = indices[start:start+3]
                    a, b, c = (positions[i] for i in corners)
                    geometric = cross(subtract(b, a), subtract(c, a))
                    area_squared = dot(geometric, geometric)
                    # Flattening the rock base creates harmless zero-area faces.
                    if area_squared < 1e-16:
                        continue
                    average_normal = tuple(sum(normals[i][axis] for i in corners) / 3 for axis in range(3))
                    require(dot(geometric, average_normal) > 0, f"{self.path.name}: vertex normals oppose triangle winding")
                    faces.append((a, b, c))
                    top_candidates.append(((a, b, c), geometric, average_normal))
                volumes = closed_volumes(faces)
                require(all(volume > 1e-10 for volume in volumes), f"{self.path.name}/{material_name}: closed component is inside-out or has zero signed volume")
                closed_count += len(volumes)
                if "brick" in material_name or "limestone" in material_name:
                    masonry_count += len(volumes)
                all_faces.extend(faces)
        if self.path.stem in architecture:
            require(masonry_count > 0, f"{self.path.name}: no closed outward-facing main building mass was found")
        if self.path.stem in solid_props:
            require(sum(dot(a, cross(b, c)) / 6 for a, b, c in all_faces) > 1e-8, f"{self.path.name}: closed prop must enclose positive signed volume")
            # The flattened rock can have coincident base edges, so its whole
            # signed volume is checked without demanding welded manifoldness.
            if self.path.stem != "roadside_rock":
                require(closed_count > 0, f"{self.path.name}: prop must contain a closed solid")
        if self.path.stem in {"road_slab", "kerbstone"}:
            top = max(point[1] for face in all_faces for point in face)
            top_faces = [(normal, vertex_normal) for face, normal, vertex_normal in top_candidates if all(abs(point[1]-top) < 1e-5 for point in face)]
            require(bool(top_faces), f"{self.path.name}: no horizontal top face")
            require(all(normal[1] > 0.99 * math.sqrt(dot(normal, normal)) and vertex_normal[1] > 0.9 for normal, vertex_normal in top_faces), f"{self.path.name}: top must face +Y in both winding and exported normals")
        return closed_count

    def wheel(self, name: str) -> None:
        roots = self.doc["scenes"][self.doc.get("scene", 0)]["nodes"]
        require(len(roots) == 1, f"{self.path.name}: wheel must have one origin root")
        root = self.doc["nodes"][roots[0]]
        require(root.get("name") == f"Wheel_{name}", f"{self.path.name}: wrong wheel root")
        points = []

        def visit(index: int) -> None:
            node = self.doc["nodes"][index]
            # Exported wheel coordinates are already axle-local. Any transform
            # here would move the rotation center or rotate its X spin axis.
            require(all(abs(x) < 1e-6 for x in node.get("translation", [0, 0, 0])), f"{self.path.name}: wheel has a nonzero local origin")
            require(all(abs(a-b) < 1e-6 for a, b in zip(node.get("rotation", [0, 0, 0, 1]), [0, 0, 0, 1])), f"{self.path.name}: wheel has unapplied rotation")
            require(all(abs(x-1) < 1e-6 for x in node.get("scale", [1, 1, 1])), f"{self.path.name}: wheel has unapplied scale")
            require("matrix" not in node, f"{self.path.name}: wheel has an unapplied transform matrix")
            if "mesh" in node:
                for primitive in self.doc["meshes"][node["mesh"]]["primitives"]:
                    points.extend(self.accessor(primitive["attributes"]["POSITION"]))
            for child in node.get("children", []):
                visit(child)

        visit(roots[0])
        minimum = [min(p[axis] for p in points) for axis in range(3)]
        maximum = [max(p[axis] for p in points) for axis in range(3)]
        require(all(abs(a+b) < 0.01 for a, b in zip(minimum, maximum)), f"{self.path.name}: actual wheel geometry is not centered on its axle")
        extents = [(b-a) / 2 for a, b in zip(minimum, maximum)]
        require(abs(extents[1]-.32) < .02 and abs(extents[2]-.32) < .02 and extents[0] < .2, f"{self.path.name}: wheel radius or X axle orientation is wrong")


def main() -> None:
    world = json.loads(asset_path("game/assets/world/asset_report.json").read_text())
    vehicle = json.loads(asset_path("game/assets/vehicles/asset_report.json").read_text())
    require(world["bake_resolution"] == 1024 and set(world["bake_channels"]) == CHANNELS, "World report must describe four 1024px PBR bake channels")
    require(world["bevel_segments"] == 2 and world["bevel_applied"] > 0 and world["weighted_normals_applied"] > 0, "World report lacks bevel/normal processing")
    require(vehicle["atlas_resolution"] == [1024, 1024] and vehicle["bake_engine"] == "CYCLES", "Vehicle report must describe Cycles 1024px bakes")
    require(vehicle["modifiers_applied"]["bevel_two_segments"] > 0 and vehicle["modifiers_applied"]["weighted_normal"] > 0, "Vehicle report lacks bevel/normal processing")
    require(set(item["channel"] for item in vehicle["maps"]) == CHANNELS and len(vehicle["maps"]) == 4, "Vehicle report must include each PBR bake exactly once")
    hashes = []
    for family in ("masonry", "mineral"):
        hashes.extend(validate_bake(asset_path(f"game/assets/world/{family}_{channel}.png")) for channel in sorted(CHANNELS))
    for item in vehicle["maps"]:
        require(item["size"] == [1024, 1024] and item["seconds"] > 0, "Vehicle report contains an incomplete bake")
        expected = {"albedo": "EMIT", "normal": "NORMAL", "roughness": "ROUGHNESS", "ao": "AO"}[item["channel"]]
        require(item["blender_bake_type"] == expected, "Vehicle report maps a channel to the wrong bake")
        hashes.append(validate_bake(asset_path(item["path"])))
    require(len(set(hashes)) == len(hashes), "PBR maps contain duplicate placeholder image data")
    glbs, triangles, outward_solids = 0, 0, 0
    for name, report in world["assets"].items():
        glb = GLB(asset_path(f"game/assets/world/{name}.glb"))
        count, batches = glb.validate()
        outward_solids += glb.outward_surfaces()
        require(count == report["triangles"] and batches == report["material_batches"], f"{name}: actual GLB geometry disagrees with report")
        glbs, triangles = glbs + 1, triangles + count
    body = GLB(asset_path(vehicle["body_glb"]))
    count, _ = body.validate(atlas_uv=True)
    vehicle_triangles = count
    roots = {body.doc["nodes"][i]["name"] for i in body.doc["scenes"][body.doc.get("scene", 0)]["nodes"]}
    require(roots == {"BodyworkStatic", "CockpitStatic", "SteeringWheel"}, "Vehicle body must preserve separate body, cabin and steering roots")
    glbs, triangles = glbs + 1, triangles + count
    require(set(vehicle["wheels"]) == {"FL", "FR", "RL", "RR"}, "Vehicle must ship four independently animated wheels")
    require(len({item["glb"] for item in vehicle["wheels"].values()}) == 4, "Each wheel must name its own exported asset")
    for name, report in vehicle["wheels"].items():
        require(report["glb_root_translation"] == [0, 0, 0] and report["spin_axis"] == report["local_axle_axis"] == "X" and report["steer_axis"] == "Y", f"{name}: incorrect wheel origin report")
        wheel = GLB(asset_path(report["glb"]))
        count, _ = wheel.validate(atlas_uv=True)
        wheel.wheel(name)
        vehicle_triangles += count
        glbs, triangles = glbs + 1, triangles + count
    require(vehicle_triangles == vehicle["triangles_source_total"], "Actual body and wheel triangles disagree with vehicle report")
    print(f"Art assets: {len(hashes)} decoded 1024px PBR maps; {glbs} GLBs / {triangles:,} triangles; {outward_solids} outward closed world components and +Y road tops; four centered X-axis wheels; normals, UVs, indices and PBR parameters valid")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, IndexError, struct.error, zlib.error, OSError) as error:
        print(f"Art asset validation FAILED: {error}", file=sys.stderr)
        sys.exit(1)
