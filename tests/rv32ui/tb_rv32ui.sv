// Testbench for the riscv-tests rv32ui suite: SystemVerilog core, one 64 KB memory behind both
// ports. The data port grant is random (one cycle in two on average) to exercise wait states.
// Usage: vvp tb +HEX=<test.hex>   -> prints "PASS <cycles>" or "FAIL test <n>"
`timescale 1ns/1ps
module tb_rv32ui;
    logic clk = 1'b0, rst = 1'b1;
    always #5 clk = ~clk;

    logic [31:0] mem [0:16383];

    logic        imem_en, dmem_en, dmem_gnt, trap, wb_valid;
    logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata, wb_data;
    logic [3:0]  dmem_we;

    rv32i_core #(.FORMAL(1'b0)) dut (
        .clk(clk), .rst(rst),
        .imem_en(imem_en), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_en(dmem_en), .dmem_we(dmem_we), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata), .dmem_gnt(dmem_gnt),
        .trap(trap), .wb_valid(wb_valid), .wb_data(wb_data),
        .rvfi_valid(), .rvfi_order(), .rvfi_insn(), .rvfi_trap(), .rvfi_halt(), .rvfi_intr(),
        .rvfi_mode(), .rvfi_ixl(), .rvfi_rs1_addr(), .rvfi_rs2_addr(), .rvfi_rs1_rdata(),
        .rvfi_rs2_rdata(), .rvfi_rd_addr(), .rvfi_rd_wdata(), .rvfi_pc_rdata(), .rvfi_pc_wdata(),
        .rvfi_mem_addr(), .rvfi_mem_rmask(), .rvfi_mem_wmask(), .rvfi_mem_rdata(), .rvfi_mem_wdata()
    );

    // instruction port: data one clock after the request, held while imem_en = 0
    always_ff @(posedge clk)
        if (imem_en) imem_rdata <= mem[imem_addr[15:2]];

    // data port: grant from a register, random; read data in the cycle after the grant
    logic gnt_q = 1'b0;
    always_ff @(posedge clk) gnt_q <= $urandom % 2;
    assign dmem_gnt = gnt_q;
    always_ff @(posedge clk)
        if (dmem_en && dmem_gnt) begin
            for (int b = 0; b < 4; b++)
                if (dmem_we[b]) mem[dmem_addr[15:2]][8*b +: 8] <= dmem_wdata[8*b +: 8];
            dmem_rdata <= mem[dmem_addr[15:2]];
        end

    logic [31:0] last_wb = 32'd0;
    always_ff @(posedge clk) if (wb_valid) last_wb <= wb_data;

    string hex;
    int cycles = 0;
    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin $display("FAIL no +HEX"); $finish; end
        for (int i = 0; i < 16384; i++) mem[i] = 32'h0;
        $readmemh(hex, mem);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
        while (!trap && cycles < 200000) begin @(posedge clk); cycles++; end
        if (!trap)                $display("FAIL timeout");
        else if (last_wb == 32'd1) $display("PASS %0d", cycles);
        else                      $display("FAIL test %0d", last_wb >> 1);
        $finish;
    end
endmodule
