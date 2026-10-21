library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Reset synchroniser: the reset is applied immediately (asynchronously) and released
-- two clock edges after rst_in goes low, in step with the clock, so that every
-- register leaves reset in the same cycle.

entity reset_sync is
    Port (
    clk: in std_logic;
    rst_in: in std_logic; -- asynchronous, active high (push button, power-on reset)
    rst_out: out std_logic -- asynchronous assert, synchronous de-assert, active high
    );
end reset_sync;

architecture Behavioral of reset_sync is
signal sync: std_logic_vector(1 downto 0);
attribute ASYNC_REG: string;
attribute ASYNC_REG of sync: signal is "TRUE"; -- Vivado: keep the two flip-flops together
begin

process(clk, rst_in)
begin
    if rst_in = '1' then
        sync <= "11";
    elsif rising_edge(clk) then
        sync <= sync(0) & '0';
    end if;
end process;

rst_out <= sync(1);

end Behavioral;
