--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the arithmetic logic unit
--
-- Copyright (c) 2017, Helmut Sipos <helmut.sipos@gmail.com>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.vcomponents.all;
use work.dwarf.all;

entity alu is
	port (
		I_alu_func	: in  alu_function_type;
		I_alu_a		: in std_logic_vector(15 downto 0);
		I_alu_b		: in std_logic_vector(15 downto 0);

		O_alu_res	: out std_logic_vector(15 downto 0)
	);
end;

architecture logic of alu is

	signal R_alu_a_lt_b   : std_logic;
	signal R_alu_a_eq_b   : std_logic;
	signal R_alu_a_eq_z   : std_logic;
	signal R_alu_b_eq_z   : std_logic;
	signal R_alu_shift_r  : std_logic_vector(15 downto 0);
	signal R_alu_rotate_r : std_logic_vector(15 downto 0);
	signal R_alu_fac_a    : std_logic_vector(17 downto 0);
	signal R_alu_fac_b    : std_logic_vector(17 downto 0);
	signal R_alu_prod     : std_logic_vector(35 downto 0);

begin
	-- shift right (shift amount in I_alu_b(3 downto 0))
	with I_alu_b(3 downto 0) select
		R_alu_shift_r <= I_alu_a                        when "0000", -- 0
		    ZERO(0)           & I_alu_a(15 downto 1)  when "0001", -- 1
		    ZERO(1  downto 0) & I_alu_a(15 downto 2)  when "0010", -- 2
		    ZERO(2  downto 0) & I_alu_a(15 downto 3)  when "0011", -- 3
		    ZERO(3  downto 0) & I_alu_a(15 downto 4)  when "0100", -- 4
		    ZERO(4  downto 0) & I_alu_a(15 downto 5)  when "0101", -- 5
		    ZERO(5  downto 0) & I_alu_a(15 downto 6)  when "0110", -- 6
		    ZERO(6  downto 0) & I_alu_a(15 downto 7)  when "0111", -- 7
		    ZERO(7  downto 0) & I_alu_a(15 downto 8)  when "1000", -- 8
		    ZERO(8  downto 0) & I_alu_a(15 downto 9)  when "1001", -- 9
		    ZERO(9  downto 0) & I_alu_a(15 downto 10) when "1010", -- 10
		    ZERO(10 downto 0) & I_alu_a(15 downto 11) when "1011", -- 11
		    ZERO(11 downto 0) & I_alu_a(15 downto 12) when "1100", -- 12
		    ZERO(12 downto 0) & I_alu_a(15 downto 13) when "1101", -- 13
		    ZERO(13 downto 0) & I_alu_a(15 downto 14) when "1110", -- 14
		    ZERO(14 downto 0) & I_alu_a(15)           when others; -- 15

	-- rotate right (rotate amount in I_alu_b(3 downto 0))
	with I_alu_b(3 downto 0) select
		R_alu_rotate_r <= I_alu_a                        when "0000", -- 0
		    I_alu_a(0)           & I_alu_a(15 downto 1)  when "0001", -- 1
		    I_alu_a(1  downto 0) & I_alu_a(15 downto 2)  when "0010", -- 2
		    I_alu_a(2  downto 0) & I_alu_a(15 downto 3)  when "0011", -- 3
		    I_alu_a(3  downto 0) & I_alu_a(15 downto 4)  when "0100", -- 4
		    I_alu_a(4  downto 0) & I_alu_a(15 downto 5)  when "0101", -- 5
		    I_alu_a(5  downto 0) & I_alu_a(15 downto 6)  when "0110", -- 6
		    I_alu_a(6  downto 0) & I_alu_a(15 downto 7)  when "0111", -- 7
		    I_alu_a(7  downto 0) & I_alu_a(15 downto 8)  when "1000", -- 8
		    I_alu_a(8  downto 0) & I_alu_a(15 downto 9)  when "1001", -- 9
		    I_alu_a(9  downto 0) & I_alu_a(15 downto 10) when "1010", -- 10
		    I_alu_a(10 downto 0) & I_alu_a(15 downto 11) when "1011", -- 11
		    I_alu_a(11 downto 0) & I_alu_a(15 downto 12) when "1100", -- 12
		    I_alu_a(12 downto 0) & I_alu_a(15 downto 13) when "1101", -- 13
		    I_alu_a(13 downto 0) & I_alu_a(15 downto 14) when "1110", -- 14
		    I_alu_a(14 downto 0) & I_alu_a(15)           when others; -- 15

	-- MULT18X18: 18 x 18 signed asynchronous multiplier
	-- Expand alu-in A and B to 17 bit values so they can be fed to the HW multiplier
	R_alu_fac_a <= "00" & I_alu_a;
	R_alu_fac_b <= "00" & I_alu_b;
	MULT18X18_inst : MULT18X18
	port map (
		 P => R_alu_prod  -- 36-bit multiplier output
		,A => R_alu_fac_a -- 18-bit multiplier input
		,B => R_alu_fac_b -- 18-bit multiplier input
		);

	-- CMP operation
	R_alu_a_eq_z <= '1' when I_alu_a = "0000000000000000" else '0';
	R_alu_b_eq_z <= '1' when I_alu_b = "0000000000000000" else '0';
	R_alu_a_eq_b <= '1' when I_alu_a  = I_alu_b else '0';
	R_alu_a_lt_b <= '0' when I_alu_a >= I_alu_b else '1';

	-- Perform varios ALU operations relying on the syntesis tool correctly inferring the OP
	O_alu_res <=
		R_alu_prod(15 downto 0)	when I_alu_func = ALU_FUNC_MUL else
		I_alu_a + I_alu_b	when I_alu_func = ALU_FUNC_ADD else
		I_alu_a - I_alu_b	when I_alu_func = ALU_FUNC_SUB else
		not I_alu_a		when I_alu_func = ALU_FUNC_NOT else
		I_alu_a or  I_alu_b	when I_alu_func = ALU_FUNC_OR else
		I_alu_a xor  I_alu_b	when I_alu_func = ALU_FUNC_XOR else
		I_alu_a and I_alu_b	when I_alu_func = ALU_FUNC_AND else
		R_alu_shift_r		when I_alu_func = ALU_FUNC_SHR else
		R_alu_rotate_r		when I_alu_func = ALU_FUNC_ROR else
		I_alu_a			when I_alu_func = ALU_FUNC_MIRROR_A else
		I_alu_a + x"2"		when I_alu_func = ALU_FUNC_A_PLUS2 else
		ZERO(15 downto 4)
			& R_alu_a_lt_b
			& R_alu_a_eq_b
			& R_alu_b_eq_z
			& R_alu_a_eq_z	when I_alu_func = ALU_FUNC_CMP else
		ZERO;

end;

