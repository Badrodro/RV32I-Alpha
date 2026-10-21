library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Data memory of the Basys 3 demo: 1024 words (4 KB), one BRAM.
-- Synchronous read and write, one write enable per byte. Nothing happens while en = '0'
-- (this saves the BRAM read energy on cycles without a load or store).

entity RAM is
    Port (
    clk: in std_logic;
    en: in std_logic; -- access this cycle
    we: in std_logic_vector(3 downto 0); -- one write enable per byte (SB / SH / SW)
    addr: in std_logic_vector(31 downto 0); -- byte address
    dataIN: in std_logic_vector(31 downto 0); -- data to write
    dataOUT: out std_logic_vector(31 downto 0) -- data read, valid one clock after the request
);
end RAM;

architecture Behavioral of RAM is
type ram_type is array (0 to 1023) of std_logic_vector(31 downto 0);
signal s_ram: ram_type; -- no initial value: SRAM macros and formal tools start from an unknown state
begin

process(clk)
begin
    if rising_edge(clk) then
        if en = '1' then
            for i in 0 to 3 loop -- byte-write template, inferred as a single BRAM by Vivado
                if we(i) = '1' then
                    s_ram(to_integer(unsigned(addr(11 downto 2))))(8*i+7 downto 8*i) <= dataIN(8*i+7 downto 8*i);
                end if;
            end loop;
            dataOUT <= s_ram(to_integer(unsigned(addr(11 downto 2))));
        end if;
    end if;
end process;

end Behavioral;
