library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Arithmetic and logic unit, controlled directly by funct3 (as encoded in RV32I):
--   000 ADD/SUB  001 SLL  010 SLT  011 SLTU  100 XOR  101 SRL/SRA  110 OR  111 AND
--
-- Area: one 33-bit adder serves ADD, SUB, SLT, SLTU and the branch comparisons, and
-- one right shifter serves SRL, SRA and SLL (SLL = reverse, shift right, reverse).
-- Timing: equality is compared directly on the operands, in parallel with the adder,
-- instead of testing the adder output for zero (BEQ/BNE no longer wait for the carry).

entity ALU is
    Port (
    a: in std_logic_vector(31 downto 0);
    b: in std_logic_vector(31 downto 0);
    fn: in std_logic_vector(2 downto 0); -- operation (funct3 encoding, see above)
    sub: in std_logic; -- '1': ADD becomes SUB (SLT and SLTU always subtract)
    arith: in std_logic; -- '1': SRL becomes SRA

    result: out std_logic_vector(31 downto 0);
    lt: out std_logic; -- a < b, signed for fn = 010, unsigned for fn = 011
    eq: out std_logic -- a = b
    );
end ALU;

architecture Behavioral of ALU is

function reverse(x: std_logic_vector(31 downto 0)) return std_logic_vector is
    variable r: std_logic_vector(31 downto 0);
begin
    for i in 0 to 31 loop
        r(i) := x(31 - i);
    end loop;
    return r;
end function;

signal doSub, sgn: std_logic;
signal opA, opB: unsigned(33 downto 0);
signal sum: unsigned(33 downto 0);
signal left: std_logic;
signal shIn, shOut: std_logic_vector(31 downto 0);
signal shRes: signed(32 downto 0);

begin

-- adder: a 33-bit subtraction never overflows, so bit 32 is the sign of a - b,
-- i.e. a < b, once both operands are extended with their sign (SLT) or a zero (SLTU).
-- The extra bit at the bottom turns "+ doSub" into the carry-in of a single adder.
doSub <= sub or (not fn(2) and fn(1)); -- SUB, SLT, SLTU
sgn <= not fn(0); -- signed comparison for SLT (and BLT/BGE), unsigned for SLTU
opA <= unsigned((a(31) and sgn) & a & '1');
opB <= unsigned(((b(31) and sgn) & b & doSub) xor (33 downto 1 => doSub) & '0');
sum <= opA + opB;
lt <= sum(33);

eq <= '1' when a = b else '0';

-- shifter
left <= '1' when fn(2) = '0' and fn(0) = '1' else '0'; -- 001: SLL
shIn <= reverse(a) when left = '1' else a;
shRes <= shift_right(signed((arith and a(31) and not left) & shIn), to_integer(unsigned(b(4 downto 0))));
shOut <= reverse(std_logic_vector(shRes(31 downto 0))) when left = '1' else std_logic_vector(shRes(31 downto 0));

with fn select result <=
    std_logic_vector(sum(32 downto 1)) when "000",
    shOut when "001" | "101",
    (31 downto 1 => '0') & sum(33) when "010" | "011",
    a xor b when "100",
    a or b when "110",
    a and b when others;

end Behavioral;
