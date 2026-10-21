----------------------------------------------------------------------------------
-- University: University of Bourgogne Europe
-- Engineer: Badreddine BENFETTOUMA
-- Create Date: 04.01.2026 10:15:33
-- Design Name: RV32I
-- Module Name: top - Behavioral
-- Project Name: RV32I
-- Target Devices: Basys 3
-- Tool Versions: Vivado 2025.2
-- Description: My first RISC V ! 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: This is my first big VHDL project, im still learning and if you have some advices or you want to contact me here is my e-mail: Badreddine_Benfettouma@etu.ube.fr
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity top is
    Port (
        clk: in std_logic;
        reset: in std_logic;
        
        trap: out std_logic;
        testOUT: out std_logic_vector(31 downto 0)
        
 );
end top;

architecture Behavioral of top is

-- control unit
signal s_regWrite, s_aluSrc, s_memWrite, s_branch, s_jump, s_stall, s_trap: std_logic;
signal s_immType: std_logic_vector(2 downto 0);
signal s_resultSrc: std_logic_vector(1 downto 0);
signal s_aluOUT: std_logic_vector(3 downto 0);
signal s_jalr : std_logic;
signal s_aluSrcA: std_logic_vector(1 downto 0);

-- ALU
signal s_aluResult: std_logic_vector(31 downto 0);
signal s_zero: std_logic;

--imm generator
signal s_immOUT: std_logic_vector(31 downto 0);

-- PC
signal s_pcOUT: std_logic_vector(31 downto 0);

--RAM
signal s_dataOUT: std_logic_vector(31 downto 0);

-- load/store unit
signal s_byteEnable: std_logic_vector(3 downto 0);
signal s_ramDataIN: std_logic_vector(31 downto 0);
signal s_loadData: std_logic_vector(31 downto 0);

--ROM
signal s_instrOUT: std_logic_vector(31 downto 0);

-- register file
signal s_data1: std_logic_vector(31 downto 0);
signal s_data2: std_logic_vector(31 downto 0);


--MUX logic
signal s_pcSel: std_logic;
signal s_pcNext: std_logic_vector(31 downto 0);
signal s_src1: std_logic_vector(31 downto 0);
signal s_src2: std_logic_vector(31 downto 0);    
signal s_branchCond: std_logic;
signal s_branchTaken: std_logic;
signal s_resultWB: std_logic_vector(31 downto 0); 
signal s_pcBase: std_logic_vector(31 downto 0);
signal s_pcTarget : std_logic_vector(31 downto 0);

------

signal s_combined_stall: std_logic; -- added combined signal of stall and trap to stop the PC 

begin
s_pcBase <= s_pcOUT when s_jalr = '0' else s_data1; -- pc or rs1 (jal/branch or jalr)

-- branch condition: the ALU computes SUB (BEQ/BNE), SLT (BLT/BGE) or SLTU (BLTU/BGEU)
-- funct3(2) = '0' -> equality test with the zero flag, '1' -> result of the comparison
-- funct3(0) = '1' -> inverted condition (BNE, BGE, BGEU)
s_branchCond <= s_zero when s_instrOUT(14) = '0' else s_aluResult(0);
s_branchTaken <= s_branchCond XOR s_instrOUT(12);

s_pcSel <= s_jump OR (s_branch AND s_branchTaken) OR s_jalr; -- we jump if its a jump or a branch (with the condition)

s_pcTarget <= std_logic_vector(unsigned(s_pcBase) + unsigned(s_immOUT));
s_pcNext <= s_pcTarget(31 downto 1) & '0';

s_src1 <= s_pcOUT when s_aluSrcA = "01" else -- AUIPC
          (others => '0') when s_aluSrcA = "10" else -- LUI
          s_data1;
s_src2 <= s_immOUT when s_aluSRC = '1' else s_data2; -- either imm or the data2  

s_combined_stall <= s_stall OR s_trap; -- the PC is stopped if we wait the RAM or if there is a SYSTEM instruction

-- final MUX
s_resultWB <= s_aluResult when s_resultSrc = "00" else -- result from ALU
              s_loadData when s_resultSrc = "01" else -- data from RAM (aligned and extended)
              std_logic_vector(unsigned(s_pcOUT)+4) when s_resultSrc = "10" else -- link to the next instruction
              (others => '0');
-----
trap <= s_trap;

PC_inst: entity work.Program_Counter port map(
    reset =>reset,
    pcNext => s_pcNext,
    pcSel => s_pcSel,
    clk => clk,
    stall => s_combined_stall,
    pcOUT => s_pcOUT
    );

CU_inst: entity work.Control_unit port map(
    opcode => s_instrOUT(6 downto 0),
    funct3 => s_instrOUT(14 downto 12),
    reset => reset,
    clk => clk,
    funct7_5 => s_instrOUT(30),
    
    regWrite => s_regWrite,
    immType => s_immType,
    aluSrc => s_aluSrc,
    aluSrcA => s_aluSrcA,
    memWrite => s_memWrite,
    resultSrc => s_resultSrc,
    branch => s_branch,
    jump => s_jump,
    stall => s_stall,
    aluOUT => s_aluOUT,
    jalr => s_jalr,
    trap => s_trap
    );

ALU_inst: entity work.ALU port map(
    source1 => unsigned(s_src1),
    source2 => unsigned(s_src2),
    aluOP => s_aluOUT,
    
    aluResult => s_aluResult,
    zero => s_zero
    );

Imm_inst: entity work.Imm_gen port map(
    instrIN => s_instrOUT,
    immType => s_immType,
    
    immOUT => s_immOUT

    );    
    
LSU_inst: entity work.Load_store_unit port map(
    funct3 => s_instrOUT(14 downto 12),
    addrLow => s_aluResult(1 downto 0),
    memWrite => s_memWrite,
    storeData => s_data2,
    ramDataIN => s_dataOUT,

    byteEnable => s_byteEnable,
    ramDataOUT => s_ramDataIN,
    loadData => s_loadData
    );

RAM_inst: entity work.RAM port map(
    clk => clk,
    we => s_byteEnable,
    addr => s_aluResult,
    dataIN => s_ramDataIN,
    
    dataOUT => s_dataOUT
    );    
 
ROM_inst: entity work.ROM port map(
   instrIN => s_pcOUT,
    
   instrOUT => s_instrOUT
    );   

RegisterFile_inst: entity work.Register_file port map(
    registerAddress1 => s_instrOUT(19 downto 15), -- rs1
    registerAddress2 => s_instrOUT(24 downto 20), -- rs2
    addressWrite => s_instrOUT(11 downto 7), -- rd
    dataWrite => s_resultWB,
    clk => clk,
    writeEnable => s_regWrite,
    
    data1 => s_data1,
    data2 => s_data2
    );
    
testOUT <= s_resultWB;    
end Behavioral;
