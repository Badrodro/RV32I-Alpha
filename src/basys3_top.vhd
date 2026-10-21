----------------------------------------------------------------------------------
-- RV32I-Alpha on the Digilent Basys 3
-- Core + instruction ROM + data RAM + reset synchroniser.
--   reset   : BTNC
--   trap    : LED 15, the program has reached ebreak / ecall (or trapped)
--   testOUT : last value written to a register (Pmod headers); at the end of the
--             torture test it holds the verdict (1 = pass, otherwise the failed test)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity basys3_top is
    Port (
        clk: in std_logic;
        reset: in std_logic;
        trap: out std_logic;
        testOUT: out std_logic_vector(31 downto 0)
    );
end basys3_top;

architecture Behavioral of basys3_top is

signal rst: std_logic;
signal imem_en, dmem_en: std_logic;
signal imem_addr, imem_rdata: std_logic_vector(31 downto 0);
signal dmem_we: std_logic_vector(3 downto 0);
signal dmem_addr, dmem_wdata, dmem_rdata: std_logic_vector(31 downto 0);
signal wb_valid: std_logic;
signal wb_data, last_wb: std_logic_vector(31 downto 0);

begin

rst_inst: entity work.reset_sync port map(
    clk => clk,
    rst_in => reset,
    rst_out => rst
    );

core_inst: entity work.rv32i_core
    generic map(
        RESET_ADDR => x"00000000",
        FORMAL => false
    )
    port map(
        clk => clk,
        rst => rst,
        imem_en => imem_en,
        imem_addr => imem_addr,
        imem_rdata => imem_rdata,
        dmem_en => dmem_en,
        dmem_we => dmem_we,
        dmem_addr => dmem_addr,
        dmem_wdata => dmem_wdata,
        dmem_rdata => dmem_rdata,
        trap => trap,
        wb_valid => wb_valid,
        wb_data => wb_data,
        rvfi_valid => open, rvfi_order => open, rvfi_insn => open, rvfi_trap => open,
        rvfi_halt => open, rvfi_intr => open, rvfi_mode => open, rvfi_ixl => open,
        rvfi_rs1_addr => open, rvfi_rs2_addr => open, rvfi_rs1_rdata => open, rvfi_rs2_rdata => open,
        rvfi_rd_addr => open, rvfi_rd_wdata => open, rvfi_pc_rdata => open, rvfi_pc_wdata => open,
        rvfi_mem_addr => open, rvfi_mem_rmask => open, rvfi_mem_wmask => open,
        rvfi_mem_rdata => open, rvfi_mem_wdata => open
    );

imem_inst: entity work.ROM port map(
    clk => clk,
    en => imem_en,
    addr => imem_addr,
    data => imem_rdata
    );

dmem_inst: entity work.RAM port map(
    clk => clk,
    en => dmem_en,
    we => dmem_we,
    addr => dmem_addr,
    dataIN => dmem_wdata,
    dataOUT => dmem_rdata
    );

-- keep the last register write so that it can be read on the Pmod headers
process(clk, rst)
begin
    if rst = '1' then
        last_wb <= (others => '0');
    elsif rising_edge(clk) then
        if wb_valid = '1' then
            last_wb <= wb_data;
        end if;
    end if;
end process;

testOUT <= last_wb;

end Behavioral;
