#!/usr/bin/env python3
"""目录树 -> XJPAK10 live root 镜像（initramfs 等价物）。用法：makepak.py <root_dir> <out.img>"""
import os, struct, sys

MAGIC = b"XJPAK10"           # 8 字节（含 NUL）
TYPE_FILE = 1
TYPE_DIR  = 2

def pack(root_dir, out_path):
    root_dir = os.path.abspath(root_dir)
    entries = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        rel = os.path.relpath(dirpath, root_dir)
        for d in sorted(dirnames):
            p = ("/" + os.path.join(rel, d).replace(os.sep, "/")).replace("//", "/")
            entries.append((p, TYPE_DIR, b""))
        for f in sorted(filenames):
            fp = os.path.join(dirpath, f)
            p = ("/" + os.path.join(rel, f).replace(os.sep, "/")).replace("//", "/")
            entries.append((p, TYPE_FILE, open(fp, "rb").read()))

    out = bytearray()
    out += MAGIC.ljust(8, b"\x00")
    out += struct.pack("<Q", len(entries))
    for (path, typ, data) in entries:
        pb = path.encode("utf-8")
        assert 0 < len(pb) < 512, "path too long: " + path
        out += struct.pack("<HHIQ", len(pb), typ, 0, len(data))
        out += pb
        if typ == TYPE_FILE:
            out += data
    with open(out_path, "wb") as fp:
        fp.write(out)
    print(f"makepak: {root_dir} -> {out_path} ({len(entries)} entries, {len(out)} bytes)")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: makepak.py <root_dir> <out.pak>"); sys.exit(1)
    pack(sys.argv[1], sys.argv[2])
