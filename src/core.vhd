----------------------------------------------------------------------------------
-- RV32I-Alpha core
-- Engineer: Badreddine BENFETTOUMA (University of Bourgogne Europe)
--
-- Two-stage pipeline:
--   IF : pc_if is sent to the synchronous instruction memory.
--   EX : the instruction comes out of the memory (imem_rdata) one cycle later and is
--        decoded, executed and written back in the same cycle.
-- The memory output register is the IF/EX pipeline register, so there is no extra
-- instruction register in the core.
--
-- Hazards:
--   - Data: none. The register file is written at the end of EX and read by the next
--     instruction after that clock edge, so no forwarding or interlock is needed.
--   - Control: branches are predicted not taken. A taken branch or a jump kills the
--     instruction fetched behind it (one bubble) and restarts the fetch at the target.
--   - Loads: the data memory is synchronous, so a load stays two cycles in EX. The
--     instruction memory is disabled during the first cycle so that its output (the
--     load) is held.
--
-- Traps: ECALL, EBREAK, illegal instructions, misaligned loads/stores and jumps or
-- taken branches to a misaligned target halt the core (no side effect, "trap" = '1').
--
-- Memories (outside the core):
--   imem: data valid one clock after (imem_en, imem_addr), output held while imem_en = '0'.
--   dmem: same timing, one write enable per byte. Read data is used one cycle after
--         the request.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rv32i_core is
    generic (
        RESET_ADDR: std_logic_vector(31 downto 0) := x"00000000"; -- first instruction (multiple of 4)
        FORMAL: boolean := false -- drive the RVFI trace port (riscv-formal); leave false for synthesis
    );
    port (
        clk: in std_logic;
        rst: in std_logic; -- active high, asynchronous assert, synchronous de-assert (see reset_sync)

        -- instruction memory
        imem_en: out std_logic;
        imem_addr: out std_logic_vector(31 downto 0);
        imem_rdata: in std_logic_vector(31 downto 0);

        -- data memory
        dmem_en: out std_logic;
        dmem_we: out std_logic_vector(3 downto 0); -- one write enable per byte, "0000" = read
        dmem_addr: out std_logic_vector(31 downto 0);
        dmem_wdata: out std_logic_vector(31 downto 0);
        dmem_rdata: in std_logic_vector(31 downto 0);

        trap: out std_logic; -- the core has halted

        -- register write-back, for debug and board demos
        wb_valid: out std_logic; -- a register (other than x0) is written this cycle
        wb_data: out std_logic_vector(31 downto 0);

        -- RISC-V Formal Interface, only driven when FORMAL = true
        rvfi_valid: out std_logic;
        rvfi_order: out std_logic_vector(63 downto 0);
        rvfi_insn: out std_logic_vector(31 downto 0);
        rvfi_trap: out std_logic;
        rvfi_halt: out std_logic;
        rvfi_intr: out std_logic;
        rvfi_mode: out std_logic_vector(1 downto 0);
        rvfi_ixl: out std_logic_vector(1 downto 0);
        rvfi_rs1_addr: out std_logic_vector(4 downto 0);
        rvfi_rs2_addr: out std_logic_vector(4 downto 0);
        rvfi_rs1_rdata: out std_logic_vector(31 downto 0);
        rvfi_rs2_rdata: out std_logic_vector(31 downto 0);
        rvfi_rd_addr: out std_logic_vector(4 downto 0);
        rvfi_rd_wdata: out std_logic_vector(31 downto 0);
        rvfi_pc_rdata: out std_logic_vector(31 downto 0);
        rvfi_pc_wdata: out std_logic_vector(31 downto 0);
        rvfi_mem_addr: out std_logic_vector(31 downto 0);
        rvfi_mem_rmask: out std_logic_vector(3 downto 0);
        rvfi_mem_wmask: out std_logic_vector(3 downto 0);
        rvfi_mem_rdata: out std_logic_vector(31 downto 0);
        rvfi_mem_wdata: out std_logic_vector(31 downto 0)
    );
end rv32i_core;

architecture rtl of rv32i_core is

-- pipeline state (PCs are word addresses: bits 1:0 are always zero)
signal pc_if: unsigned(31 downto 2); -- address being fetched
signal pc_ex: unsigned(31 downto 2); -- address of the instruction in EX
signal ex_valid: std_logic; -- imem_rdata holds an instruction to execute (not a killed one)
signal load_wait: std_logic; -- second cycle of a load
signal halted: std_logic;

-- instruction in EX and its fields
signal instr: std_logic_vector(31 downto 0);
signal rs1, rs2, rd: std_logic_vector(4 downto 0);

-- decoder
signal d_regWrite, d_aluSrc, d_memWrite, d_branch, d_jump, d_jalr, d_isLoad, d_trap: std_logic;
signal d_immType: std_logic_vector(2 downto 0);
signal d_resultSrc, d_aluSrcA, d_aluOP: std_logic_vector(1 downto 0);
signal aluCtrl: std_logic_vector(3 downto 0);

-- datapath
signal imm, data1, data2, src1, src2, aluResult, loadData, resultWB: std_logic_vector(31 downto 0);
signal zero: std_logic;
signal pcBase, pcTarget, linkAddr, pcNextEx: std_logic_vector(31 downto 0);
signal laneMask: std_logic_vector(3 downto 0);
signal storeWord: std_logic_vector(31 downto 0); -- store data placed on the byte lanes
signal misaligned: std_logic;

-- control
signal ex_live: std_logic; -- EX holds a real instruction and the core runs
signal branchCond, branchTaken, takeTarget: std_logic;
signal memMisaligned, pcMisaligned: std_logic;
signal trapNow: std_logic; -- the instruction in EX traps
signal stall: std_logic; -- first cycle of a load
signal freeze: std_logic; -- nothing moves in the pipeline this cycle
signal redirect: std_logic; -- jump or taken branch: restart the fetch at the target
signal regWE: std_logic;
signal storeOK, loadReq: std_logic;
signal retire: std_logic; -- the instruction in EX completes this cycle

begin

instr <= imem_rdata;
rs1 <= instr(19 downto 15);
rs2 <= instr(24 downto 20);
rd <= instr(11 downto 7);

------------------------------------------------------------------ decode
dec_inst: entity work.Main_decoder port map(
    instr => instr,
    regWrite => d_regWrite,
    immType => d_immType,
    aluSrc => d_aluSrc,
    aluSrcA => d_aluSrcA,
    memWrite => d_memWrite,
    resultSrc => d_resultSrc,
    aluOP => d_aluOP,
    branch => d_branch,
    isLoad => d_isLoad,
    jump => d_jump,
    jalr => d_jalr,
    trap => d_trap
    );

aludec_inst: entity work.ALU_decoder port map(
    aluOP => d_aluOP,
    funct3 => instr(14 downto 12),
    funct7_5 => instr(30),
    aluOUT => aluCtrl
    );

imm_inst: entity work.Imm_gen port map(
    instrIN => instr,
    immType => d_immType,
    immOUT => imm
    );

------------------------------------------------------------------ execute
rf_inst: entity work.Register_file port map(
    clk => clk,
    registerAddress1 => rs1,
    registerAddress2 => rs2,
    addressWrite => rd,
    dataWrite => resultWB,
    writeEnable => regWE,
    data1 => data1,
    data2 => data2
    );

src1 <= std_logic_vector(pc_ex) & "00" when d_aluSrcA = "01" else -- AUIPC
        (others => '0') when d_aluSrcA = "10" else -- LUI
        data1;
src2 <= imm when d_aluSrc = '1' else data2;

alu_inst: entity work.ALU port map(
    source1 => unsigned(src1),
    source2 => unsigned(src2),
    aluOP => aluCtrl,
    aluResult => aluResult,
    zero => zero
    );

-- branch decision: the ALU computes SUB (BEQ/BNE), SLT (BLT/BGE) or SLTU (BLTU/BGEU)
-- funct3(2) = '0' -> equality (zero flag), '1' -> comparison result; funct3(0) = '1' -> inverted
branchCond <= zero when instr(14) = '0' else aluResult(0);
branchTaken <= branchCond xor instr(12);
takeTarget <= d_jump or (d_branch and branchTaken);

pcBase <= data1 when d_jalr = '1' else std_logic_vector(pc_ex) & "00";
pcTarget <= std_logic_vector(unsigned(pcBase) + unsigned(imm)) and x"FFFFFFFE"; -- JALR clears bit 0
linkAddr <= std_logic_vector(pc_if) & "00"; -- PC + 4: while EX is valid, pc_if = pc_ex + 4
pcNextEx <= pcTarget when takeTarget = '1' else linkAddr;

lsu_inst: entity work.Load_store_unit port map(
    funct3 => instr(14 downto 12),
    addrLow => aluResult(1 downto 0),
    storeData => data2,
    ramDataIN => dmem_rdata,
    laneMask => laneMask,
    misaligned => misaligned,
    ramDataOUT => storeWord,
    loadData => loadData
    );

with d_resultSrc select resultWB <=
    loadData when "01",
    linkAddr when "10",
    aluResult when others;

------------------------------------------------------------------ control
ex_live <= ex_valid and not halted;

memMisaligned <= (d_isLoad or d_memWrite) and misaligned;
pcMisaligned <= takeTarget and pcTarget(1); -- no compressed instructions: targets are multiples of 4
trapNow <= ex_live and (d_trap or memMisaligned or pcMisaligned);

stall <= ex_live and d_isLoad and not load_wait and not trapNow;
freeze <= halted or trapNow or stall;
redirect <= ex_live and takeTarget and not trapNow;
retire <= ex_live and not stall;

regWE <= ex_live and d_regWrite and not trapNow and not stall;
storeOK <= ex_live and d_memWrite and not trapNow;
loadReq <= stall; -- the read is issued in the first cycle of the load

process(clk, rst)
begin
    if rst = '1' then
        pc_if <= unsigned(RESET_ADDR(31 downto 2));
        ex_valid <= '0';
        load_wait <= '0';
        halted <= '0';
    elsif rising_edge(clk) then
        load_wait <= stall;
        if trapNow = '1' then
            halted <= '1';
        end if;
        if freeze = '0' then
            if redirect = '1' then
                pc_if <= unsigned(pcTarget(31 downto 2));
                ex_valid <= '0'; -- kill the instruction fetched behind the jump
            else
                pc_if <= pc_if + 1;
                ex_valid <= '1';
            end if;
        end if;
    end if;
end process;

-- pc_ex needs no reset: it is only used when ex_valid = '1'
process(clk)
begin
    if rising_edge(clk) then
        if freeze = '0' then
            pc_ex <= pc_if;
        end if;
    end if;
end process;

------------------------------------------------------------------ outputs
imem_en <= not freeze;
imem_addr <= std_logic_vector(pc_if) & "00";

dmem_en <= storeOK or loadReq;
dmem_we <= laneMask when storeOK = '1' else "0000";
dmem_addr <= aluResult;
dmem_wdata <= storeWord;

trap <= halted;

wb_valid <= '1' when regWE = '1' and rd /= "00000" else '0';
wb_data <= resultWB;

------------------------------------------------------------------ RVFI
rvfi_on: if FORMAL generate
    signal order: unsigned(63 downto 0);
    signal rdWritten: std_logic;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            order <= (others => '0');
        elsif rising_edge(clk) then
            if retire = '1' then
                order <= order + 1;
            end if;
        end if;
    end process;

    rdWritten <= '1' when regWE = '1' and rd /= "00000" else '0';

    rvfi_valid <= retire;
    rvfi_order <= std_logic_vector(order);
    rvfi_insn <= instr;
    rvfi_trap <= trapNow;
    rvfi_halt <= trapNow;
    rvfi_intr <= '0';
    rvfi_mode <= "11"; -- machine mode
    rvfi_ixl <= "01"; -- 32-bit
    rvfi_rs1_addr <= rs1;
    rvfi_rs2_addr <= rs2;
    rvfi_rs1_rdata <= data1;
    rvfi_rs2_rdata <= data2;
    rvfi_rd_addr <= rd when rdWritten = '1' else "00000";
    rvfi_rd_wdata <= resultWB when rdWritten = '1' else (others => '0');
    rvfi_pc_rdata <= std_logic_vector(pc_ex) & "00";
    rvfi_pc_wdata <= pcNextEx;
    rvfi_mem_addr <= aluResult(31 downto 2) & "00";
    rvfi_mem_rmask <= laneMask when (d_isLoad = '1' and trapNow = '0') else "0000";
    rvfi_mem_wmask <= laneMask when storeOK = '1' else "0000";
    rvfi_mem_rdata <= dmem_rdata;
    rvfi_mem_wdata <= storeWord;
end generate;

rvfi_off: if not FORMAL generate
    rvfi_valid <= '0';
    rvfi_order <= (others => '0');
    rvfi_insn <= (others => '0');
    rvfi_trap <= '0';
    rvfi_halt <= '0';
    rvfi_intr <= '0';
    rvfi_mode <= "00";
    rvfi_ixl <= "00";
    rvfi_rs1_addr <= (others => '0');
    rvfi_rs2_addr <= (others => '0');
    rvfi_rs1_rdata <= (others => '0');
    rvfi_rs2_rdata <= (others => '0');
    rvfi_rd_addr <= (others => '0');
    rvfi_rd_wdata <= (others => '0');
    rvfi_pc_rdata <= (others => '0');
    rvfi_pc_wdata <= (others => '0');
    rvfi_mem_addr <= (others => '0');
    rvfi_mem_rmask <= (others => '0');
    rvfi_mem_wmask <= (others => '0');
    rvfi_mem_rdata <= (others => '0');
    rvfi_mem_wdata <= (others => '0');
end generate;

end rtl;
