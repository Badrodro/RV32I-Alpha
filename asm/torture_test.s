# RV32I-Alpha Torture Test (self-checking)
#
# Every check jumps to "fail" on a wrong result. x30 holds the number of the
# test being run. The program always ends with an ebreak (TRAP signal):
#   - pass: the instruction just before ebreak writes 1 in x31
#   - fail: the instruction just before ebreak writes the failed test number (>= 2) in x31
# The testbench reads this value on testOUT (write-back bus) when TRAP rises.
#
# Rebuild the ROM after editing this file:  python3 asm/build_rom.py

.text
_start:

# ---- 2: BEQ / BNE (equal and not-equal operands) --------------------------
    addi  x30, x0, 2
    addi  x1, x0, 5
    addi  x2, x0, 5
    addi  x3, x0, -3
    bne   x1, x2, fail        # equal -> must not be taken
    beq   x1, x3, fail        # different -> must not be taken
    beq   x1, x2, 1f
    jal   x0, fail
1:  bne   x1, x3, 1f
    jal   x0, fail
1:

# ---- 3: BLT / BGE / BLTU / BGEU (x3 = -3 = 0xFFFFFFFD, x1 = 5) ------------
    addi  x30, x0, 3
    blt   x1, x3, fail        # 5 < -3 is false
    bge   x3, x1, fail        # -3 >= 5 is false
    bltu  x3, x1, fail        # 0xFFFFFFFD < 5 is false
    bgeu  x1, x3, fail        # 5 >= 0xFFFFFFFD is false
    blt   x3, x1, 1f
    jal   x0, fail
1:  bge   x1, x3, 1f
    jal   x0, fail
1:  bge   x1, x2, 1f          # equal operands
    jal   x0, fail
1:  bltu  x1, x3, 1f
    jal   x0, fail
1:  bgeu  x3, x1, 1f
    jal   x0, fail
1:  bgeu  x1, x2, 1f          # equal operands
    jal   x0, fail
1:

# ---- 4: LUI (must ignore the register selected by bits 19:15) -------------
    addi  x30, x0, 4
    addi  x8, x0, 0x55        # 0x12345 puts 01000 (x8) in the rs1 field
    lui   x5, 0x12345
    addi  x6, x0, 0x123       # build 0x12345000 without LUI
    slli  x6, x6, 8
    addi  x6, x6, 0x45
    slli  x6, x6, 12
    bne   x5, x6, fail

# ---- 5: AUIPC (rd = PC + imm) ---------------------------------------------
    addi  x30, x0, 5
    jal   x7, 1f              # x7 = address of the auipc below
1:  auipc x5, 0x1
    sub   x5, x5, x7
    lui   x6, 0x1
    bne   x5, x6, fail

# ---- 6: R-type ALU --------------------------------------------------------
    addi  x30, x0, 6
    addi  x1, x0, 0x0F0
    addi  x2, x0, 0x0FF
    add   x5, x1, x2
    addi  x6, x0, 0x1EF
    bne   x5, x6, fail
    sub   x5, x1, x2
    addi  x6, x0, -15
    bne   x5, x6, fail
    and   x5, x1, x2
    bne   x5, x1, fail
    or    x5, x1, x2
    bne   x5, x2, fail
    xor   x5, x1, x2
    addi  x6, x0, 0x00F
    bne   x5, x6, fail
    addi  x3, x0, 4
    sll   x5, x1, x3
    addi  x6, x0, 0x780
    add   x6, x6, x6          # 0xF00
    bne   x5, x6, fail
    addi  x4, x0, -16         # 0xFFFFFFF0
    srl   x5, x4, x3
    lui   x6, 0x10000
    addi  x6, x6, -1          # 0x0FFFFFFF
    bne   x5, x6, fail
    sra   x5, x4, x3
    addi  x6, x0, -1
    bne   x5, x6, fail
    slt   x5, x4, x1          # -16 < 240
    addi  x6, x0, 1
    bne   x5, x6, fail
    sltu  x5, x4, x1          # 0xFFFFFFF0 < 240 is false
    bne   x5, x0, fail

# ---- 7: I-type ALU --------------------------------------------------------
    addi  x30, x0, 7
    andi  x5, x4, 0x0FF
    addi  x6, x0, 0x0F0
    bne   x5, x6, fail
    ori   x5, x1, 0x00F
    bne   x5, x2, fail
    xori  x5, x2, -1          # NOT 0xFF
    addi  x6, x0, -256
    bne   x5, x6, fail
    srai  x5, x4, 2           # bit 30 set inside the immediate
    addi  x6, x0, -4
    bne   x5, x6, fail
    srli  x5, x4, 28
    addi  x6, x0, 15
    bne   x5, x6, fail
    slli  x5, x2, 4
    addi  x6, x0, 0x7F8
    add   x6, x6, x6          # 0xFF0
    bne   x5, x6, fail
    slti  x5, x4, -15
    addi  x6, x0, 1
    bne   x5, x6, fail
    sltiu x5, x1, -1          # 240 < 0xFFFFFFFF
    bne   x5, x6, fail
    addi  x0, x0, 5           # writes to x0 are ignored
    add   x5, x0, x0
    bne   x5, x0, fail

# ---- 8: JAL / JALR (bit 0 of the target must be cleared) ------------------
    addi  x30, x0, 8
    addi  x5, x0, 0
    jal   x1, func
    jal   x0, 1f              # func returns here
func:
    addi  x5, x0, 7
    jalr  x0, 1(x1)           # target = x1 + 1, bit 0 cleared -> x1
1:  addi  x6, x0, 7
    bne   x5, x6, fail

# ---- 9: SW / LW and load-use right after a load ----------------------------
    addi  x30, x0, 9
    addi  x8, x0, 0x100       # base address
    lui   x1, 0x12345
    addi  x1, x1, 0x678       # 0x12345678
    lui   x2, 0xFEDCC
    addi  x2, x2, -0x568      # 0xFEDCBA98
    sw    x1, 0(x8)
    sw    x2, 4(x8)
    lw    x5, 0(x8)
    bne   x5, x1, fail        # used right after the load
    lw    x5, 4(x8)
    lw    x6, 0(x8)           # back-to-back loads
    bne   x5, x2, fail
    bne   x6, x1, fail

# ---- 10: LB / LBU / LH / LHU ----------------------------------------------
    addi  x30, x0, 10
    lb    x5, 0(x8)
    addi  x6, x0, 0x78
    bne   x5, x6, fail
    lb    x5, 3(x8)
    addi  x6, x0, 0x12
    bne   x5, x6, fail
    lh    x5, 2(x8)
    lui   x6, 0x1
    addi  x6, x6, 0x234       # 0x1234
    bne   x5, x6, fail
    lb    x5, 4(x8)           # 0x98 -> sign-extended
    addi  x6, x0, -0x68
    bne   x5, x6, fail
    lbu   x5, 4(x8)
    addi  x6, x0, 0x98
    bne   x5, x6, fail
    lb    x5, 5(x8)           # 0xBA
    addi  x6, x0, -0x46
    bne   x5, x6, fail
    lbu   x5, 7(x8)           # 0xFE
    addi  x6, x0, 0xFE
    bne   x5, x6, fail
    lh    x5, 6(x8)           # 0xFEDC -> sign-extended
    addi  x6, x0, -0x124
    bne   x5, x6, fail
    lhu   x5, 6(x8)
    lui   x6, 0x10
    addi  x6, x6, -0x124      # 0x0000FEDC
    bne   x5, x6, fail

# ---- 11: SB / SH (only the selected bytes change) -------------------------
    addi  x30, x0, 11
    sw    x1, 8(x8)           # 0x12345678
    addi  x3, x0, 0xAB
    sb    x3, 9(x8)           # -> 0x1234AB78
    lw    x5, 8(x8)
    lui   x6, 0x1234B
    addi  x6, x6, -0x488      # 0x1234AB78
    bne   x5, x6, fail
    lui   x3, 0xC
    addi  x3, x3, -0x502      # 0xBAFE
    sh    x3, 10(x8)          # -> 0xBAFEAB78
    lw    x5, 8(x8)
    lui   x6, 0xBAFEB
    addi  x6, x6, -0x488      # 0xBAFEAB78
    bne   x5, x6, fail
    sb    x0, 8(x8)           # -> 0xBAFEAB00
    lw    x5, 8(x8)
    addi  x6, x6, -0x78
    bne   x5, x6, fail

# ---- end ------------------------------------------------------------------
pass:
    addi  x31, x0, 1
    ebreak
fail:
    addi  x31, x30, 0
    ebreak
