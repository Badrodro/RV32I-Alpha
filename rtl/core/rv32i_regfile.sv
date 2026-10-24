// RV32I-Alpha: register file, 31 x 32 bits (x1-x31), two asynchronous read ports, one write port.
// x0 reads as zero and has no storage. Not reset (software writes a register before reading
// it). On ASIC it maps to flip-flops. (The VHDL version keeps 32 entries, which map to
// distributed RAM on FPGA; the two are proven equivalent by formal/equiv_vhdl_sv.sh.)

module rv32i_regfile (
    input  logic        clk,
    input  logic [4:0]  raddr1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2,
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata
);
    logic [31:0] regs [1:31];

    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

    always_ff @(posedge clk)
        if (we && waddr != 5'd0)
            regs[waddr] <= wdata;
endmodule
