// Minimal test environment for the riscv-tests rv32ui suite on RV32I-Alpha.
// The core has no CSRs, so the standard environments (which set up trap vectors through CSRs)
// cannot run. A test ends with ECALL, which halts the core; the last register written before it
// is gp (x3): 1 = pass, (test number << 1) | 1 = fail.
#ifndef RV32I_ALPHA_RISCV_TEST_H
#define RV32I_ALPHA_RISCV_TEST_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN        \
        .section .text.init;     \
        .globl _start;           \
_start:                          \
        li TESTNUM, 0;

#define RVTEST_CODE_END unimp

#define RVTEST_PASS              \
        fence;                   \
        li TESTNUM, 1;           \
        ecall

#define RVTEST_FAIL              \
        fence;                   \
1:      beqz TESTNUM, 1b;        \
        sll TESTNUM, TESTNUM, 1; \
        or TESTNUM, TESTNUM, 1;  \
        ecall

#define RVTEST_DATA_BEGIN .align 4; .global begin_signature; begin_signature:
#define RVTEST_DATA_END   .align 4; .global end_signature; end_signature:

#endif
