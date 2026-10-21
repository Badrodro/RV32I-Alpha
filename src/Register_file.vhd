library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Register_file is
    Port ( 
        clk: in std_logic;
        registerAddress1: in std_logic_vector(4 downto 0);
        registerAddress2: in std_logic_vector(4 downto 0);
        
        addressWrite: in std_logic_vector(4 downto 0); --where we'll write
        dataWrite: in std_logic_vector(31 downto 0); -- what we'll write at the given address
        
        data1: out std_logic_vector(31 downto 0); -- output data from register 1
        data2: out std_logic_vector(31 downto 0); -- output data from register 2
        
        writeEnable: in std_logic -- writing in register authorization 
    );
end Register_file;

architecture Behavioral of Register_file is
    type ram_type is array (0 to 31) of std_logic_vector(31 downto 0);
    signal regs: ram_type; -- not reset (software must write a register before reading it)

begin

-- read registers value with protection the register 0 is always b"00000"
    data1 <= (others => '0') when (registerAddress1 = "00000") else regs(to_integer(unsigned(registerAddress1)));
    data2 <= (others => '0') when (registerAddress2 = "00000") else regs(to_integer(unsigned(registerAddress2)));

-- write in registers
process(clk)
begin
    if rising_edge(clk) then
       if writeEnable = '1' and addressWrite /= "00000" then
           regs(to_integer(unsigned(addressWrite)))<= dataWrite;
        end if;
    end if;
end process;

            
    



end Behavioral;
