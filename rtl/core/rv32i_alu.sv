// RV32I-Alpha: arithmetic and logic unit, controlled by funct3:
//   000 ADD/SUB  001 SLL  010 SLT  011 SLTU  100 XOR  101 SRL/SRA  110 OR  111 AND
// One 33-bit adder serves ADD, SUB, SLT, SLTU and the branch comparisons; one right shifter
// serves SRL, SRA and SLL (SLL = reverse, shift right, reverse). Equality is compared on the
// operands, in parallel with the adder.

module rv32i_alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  fn,
    input  logic        sub,     // ADD -> SUB (SLT and SLTU always subtract)
    input  logic        arith,   // SRL -> SRA
    output logic [31:0] result,
    output logic        lt,      // a < b, signed for fn = 010, unsigned for fn = 011
    output logic        eq       // a == b
);
    function automatic logic [31:0] reverse32(input logic [31:0] x);
        for (int i = 0; i < 32; i++) reverse32[i] = x[31 - i];
    endfunction

    // a 33-bit subtraction never overflows, so bit 32 of a - b is a < b once both operands are
    // extended with their sign (SLT) or a zero (SLTU); the extra low bit makes "+ do_sub" the
    // carry-in of a single adder
    logic        do_sub, sgn, left;
    logic [33:0] op_a, op_b, sum;
    logic [31:0] sh_in, sh_out;
    logic [32:0] sh_res;

    assign do_sub = sub | (~fn[2] & fn[1]);
    assign sgn    = ~fn[0];
    assign op_a   = {a[31] & sgn, a, 1'b1};
    assign op_b   = {{33{do_sub}} ^ {b[31] & sgn, b}, do_sub};
    assign sum    = op_a + op_b;
    assign lt     = sum[33];
    assign eq     = (a == b);

    assign left   = ~fn[2] & fn[0];                              // 001: SLL
    assign sh_in  = left ? reverse32(a) : a;
    assign sh_res = $signed({arith & a[31] & ~left, sh_in}) >>> b[4:0];
    assign sh_out = left ? reverse32(sh_res[31:0]) : sh_res[31:0];

    always_comb begin
        case (fn)
            3'b000:          result = sum[32:1];
            3'b001, 3'b101:  result = sh_out;
            3'b010, 3'b011:  result = {31'b0, sum[33]};
            3'b100:          result = a ^ b;
            3'b110:          result = a | b;
            default:         result = a & b;
        endcase
    end
endmodule
