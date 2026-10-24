// RV32I-Alpha: load/store unit, between the core and the 32-bit data memory.
// Stores: byte / half-word copied on every lane, lane_mask selects the bytes to write.
// Loads: byte / half-word extracted from the memory word and sign- or zero-extended.
// Misaligned accesses are flagged: the core traps on them.

module rv32i_lsu (
    input  logic [2:0]  funct3,      // size and sign (LB/LH/LW/LBU/LHU, SB/SH/SW)
    input  logic [1:0]  addr_low,    // byte position in the word
    input  logic [31:0] store_data,  // rs2
    input  logic [31:0] mem_rdata,   // word read from the memory
    output logic [3:0]  lane_mask,   // bytes touched by the access
    output logic        misaligned,
    output logic [31:0] mem_wdata,   // data sent to the memory
    output logic [31:0] load_data    // value written back to rd
);
    always_comb begin
        case (funct3[1:0])
            2'b00: begin // byte
                misaligned = 1'b0;
                lane_mask  = 4'b0001 << addr_low;
                mem_wdata  = {4{store_data[7:0]}};
            end
            2'b01: begin // half-word
                misaligned = addr_low[0];
                lane_mask  = addr_low[1] ? 4'b1100 : 4'b0011;
                mem_wdata  = {2{store_data[15:0]}};
            end
            default: begin // word
                misaligned = addr_low[1] | addr_low[0];
                lane_mask  = 4'b1111;
                mem_wdata  = store_data;
            end
        endcase
    end

    logic [7:0]  byte_v;
    logic [15:0] half_v;
    assign byte_v = mem_rdata[8*addr_low +: 8];
    assign half_v = addr_low[1] ? mem_rdata[31:16] : mem_rdata[15:0];

    always_comb begin
        case (funct3)
            3'b000:  load_data = {{24{byte_v[7]}}, byte_v};    // LB
            3'b001:  load_data = {{16{half_v[15]}}, half_v};   // LH
            3'b100:  load_data = {24'b0, byte_v};              // LBU
            3'b101:  load_data = {16'b0, half_v};              // LHU
            default: load_data = mem_rdata;                    // LW
        endcase
    end
endmodule
