library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity RAM is
    Port (
    clk: in std_logic;
    we: in std_logic_vector(3 downto 0); -- one write enable per byte (SB / SH / SW)
    addr: in std_logic_vector(31 downto 0); -- the adress where we want to write/read
    
    dataIN: in std_logic_vector(31 downto 0); -- the data we want to write
    dataOUT: out std_logic_vector(31 downto 0) -- the data we want to readt



);
end RAM;

architecture Behavioral of RAM is
type ram_type is array (0 to 1023) of std_logic_vector(31 downto 0);
signal s_ram: ram_type := (others =>(others => '0'));
begin

-- write and read logic
process(clk)
begin
    if rising_edge(clk) then
        for i in 0 to 3 loop -- byte-write template, inferred as a single BRAM by Vivado
            if we(i) = '1' then
                s_ram(to_integer(unsigned(addr(11 downto 2))))(8*i+7 downto 8*i) <= dataIN(8*i+7 downto 8*i);
            end if;
        end loop;
        dataOUT <= s_ram(to_integer(unsigned(addr(11 downto 2))));
    end if;
end process;


end Behavioral;
