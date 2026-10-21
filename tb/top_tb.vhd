library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Full-system testbench: runs the program in the ROM (asm/torture_test.s) until the core
-- traps on ebreak, then checks the verdict written in x31 just before (1 = pass,
-- otherwise the number of the failed test). basys3_top shows the last register
-- write on testOUT.
entity top_tb is
end top_tb;

architecture sim of top_tb is
    signal clk_tb     : std_logic := '0';
    signal reset_tb   : std_logic := '1';
    signal trap_tb    : std_logic;
    signal testOUT_tb : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;
    constant MAX_CYCLES : integer := 5000;
    signal sim_done   : boolean := false; -- stops the clock so the simulation ends by itself

begin

    uut: entity work.basys3_top
        port map (
            clk     => clk_tb,
            reset   => reset_tb,
            trap    => trap_tb,
            testOUT => testOUT_tb
        );

    clk_process : process
    begin
        while not sim_done loop
            clk_tb <= '0'; wait for clk_period/2;
            clk_tb <= '1'; wait for clk_period/2;
        end loop;
        wait;
    end process;

    stim_proc: process
        variable cycles : integer := 0;
    begin
        reset_tb <= '1';
        wait for 25 ns;
        reset_tb <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk_tb);
            exit when trap_tb = '1';
            cycles := cycles + 1;
        end loop;

        if trap_tb /= '1' then
            assert false report "ERROR: timeout, the processor never reached ebreak/ecall." severity failure;
        elsif unsigned(testOUT_tb) = 1 then
            report "SUCCESS: all checks of the torture test passed in " & integer'image(cycles) & " cycles." severity note;
        else
            assert false report "ERROR: torture test failed at test number " & integer'image(to_integer(unsigned(testOUT_tb))) severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end sim;
