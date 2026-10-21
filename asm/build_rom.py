#!/usr/bin/env python3
"""Assemble asm/torture_test.s and write the machine code into src/ROM.vhd.

Needs LLVM (llvm-mc and llvm-objcopy). Usage:  python3 asm/build_rom.py [file.s]
"""
import pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ROM = ROOT / "src" / "ROM.vhd"
DEPTH = 256  # must match rom_type in ROM.vhd

src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "asm" / "torture_test.s"

with tempfile.TemporaryDirectory() as tmp:
    obj, binf = f"{tmp}/prog.o", f"{tmp}/prog.bin"
    subprocess.run(["llvm-mc", "-triple=riscv32", "-mattr=-c,-relax", "-filetype=obj", str(src), "-o", obj], check=True)
    subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text", obj, binf], check=True)
    code = pathlib.Path(binf).read_bytes()

words = [int.from_bytes(code[i:i + 4], "little") for i in range(0, len(code), 4)]
if len(words) > DEPTH:
    sys.exit(f"program is {len(words)} words, ROM holds {DEPTH}")

lines = [f'{i} => x"{w:08x}",' for i, w in enumerate(words)]
body = "\n".join(lines) + '\nothers => x"00000013" -- NOP\n'

text = ROM.read_text()
text, n = re.subn(r"(-- BEGIN PROGRAM[^\n]*\n).*?(\s*-- END PROGRAM)",
                  lambda m: m.group(1) + body + m.group(2).lstrip("\n"), text, flags=re.S)
if n != 1:
    sys.exit("markers not found in ROM.vhd")
ROM.write_text(text)
print(f"{src.name}: {len(words)} instructions written to {ROM.relative_to(ROOT)}")
