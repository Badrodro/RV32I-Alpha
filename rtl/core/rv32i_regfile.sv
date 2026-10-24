// RV32I-Alpha: register file, 32 x 32 bits, two asynchronous read ports, one write port.
// x0 reads as zero and is never written. Not reset (software writes a register before
// reading it). On FPGA it maps to distributed RAM, on ASIC to flip-flops.

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
    logic [31:0] regs [0:31];

    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

    always_ff @(posedge clk)
        if (we && waddr != 5'd0)
            regs[waddr] <= wdata;
endmodule
