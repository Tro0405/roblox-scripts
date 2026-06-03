#!/usr/bin/env python3
"""
TvFruit — Local obfuscator / build tool.

Quy trình:
  - Source READABLE để trong src/   (sửa ở đây)
  - Chạy: python build.py
  - Bản OBFUSCATE ghi ra games/      (router nạp file này)

Obfuscate ở mức cơ bản: mã hóa toàn bộ file (XOR đa byte + escape \\ddd),
bọc trong 1 loader loadstring. File ra không đọc được bằng mắt, vẫn chạy
nguyên vẹn trong Delta. KHÔNG mạnh bằng VM-obfuscator trả phí — đủ chống
copy-paste source ở mức casual.

theme.lua (games/lib) và TvFruit.lua (router) GIỮ READABLE: chúng là khung
dùng chung + điểm vào, phải chạy/được nạp trực tiếp.
"""
import random, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent
SRC  = ROOT / "src"
OUT  = ROOT / "games"

# các file game cần obfuscate: src/<name> -> games/<name>
TARGETS = ["grow_a_garden.lua", "speed_escape.lua"]


def obfuscate(src_text: str) -> str:
    data = src_text.encode("utf-8")
    klen = random.randint(8, 16)
    key  = [random.randint(1, 255) for _ in range(klen)]
    enc  = bytes(b ^ key[i % klen] for i, b in enumerate(data))

    # self-check: giải mã lại phải khớp source gốc
    dec = bytes(enc[i] ^ key[i % klen] for i in range(len(enc)))
    assert dec == data, "roundtrip mismatch — build huỷ"

    enc_str = "".join("\\%03d" % b for b in enc)   # mỗi byte là escape \ddd (3 số, không nhập nhằng)
    key_str = ",".join(map(str, key))
    rnd = lambda: "_" + "".join(random.choice("lI1") for _ in range(7))
    K, D, O, I = rnd(), rnd(), rnd(), rnd()

    return (
        "-- TvFruit obfuscated build | KHONG sua file nay.\n"
        "-- Sua ban readable trong src/ roi chay: python build.py\n"
        f"local {K}={{{key_str}}}\n"
        f'local {D}="{enc_str}"\n'
        f"local {O}={{}}\n"
        f"for {I}=1,#{D} do {O}[{I}]=string.char(bit32.bxor(string.byte({D},{I}),{K}[(({I}-1)%#{K})+1]))end\n"
        f"return assert(loadstring(table.concat({O})))()\n"
    )


def main():
    if not SRC.exists():
        print("Khong thay thu muc src/"); sys.exit(1)
    OUT.mkdir(exist_ok=True)
    for name in TARGETS:
        src_path = SRC / name
        if not src_path.exists():
            print(f"[skip] khong co src/{name}"); continue
        s = src_path.read_text(encoding="utf-8")
        o = obfuscate(s)
        (OUT / name).write_text(o, encoding="utf-8")
        print(f"[build] {name}: {len(s)} -> {len(o)} bytes (obfuscated OK)")
    print("Xong. games/ da cap nhat ban obfuscate.")


if __name__ == "__main__":
    main()
