--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Constants and type definitions
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

-- constants and types
package dwarf is
	constant ZERO         		: std_logic_vector(15 downto 0) := "0000000000000000";

	subtype alu_function_type is std_logic_vector(3 downto 0);
	constant ALU_FUNC_NOP		: alu_function_type := "0000";
	constant ALU_FUNC_ADD		: alu_function_type := "0001";
	constant ALU_FUNC_SUB		: alu_function_type := "0010";
	constant ALU_FUNC_MUL		: alu_function_type := "0011";
	constant ALU_FUNC_SHR		: alu_function_type := "0100";
        constant ALU_FUNC_ROR		: alu_function_type := "0101";
	constant ALU_FUNC_AND		: alu_function_type := "0110";
	constant ALU_FUNC_OR		: alu_function_type := "0111";
	constant ALU_FUNC_XOR		: alu_function_type := "1000";
	constant ALU_FUNC_NOT		: alu_function_type := "1001";
	constant ALU_FUNC_CMP		: alu_function_type := "1010";
	constant ALU_FUNC_A_PLUS2	: alu_function_type := "1011";
	constant ALU_FUNC_MIRROR_A	: alu_function_type := "1100";

	subtype alu_a_from_type is std_logic_vector(1 downto 0);
	constant ALU_A_FROM_RS		: alu_a_from_type := "00";
	constant ALU_A_FROM_PC		: alu_a_from_type := "01";

	subtype alu_b_from_type is std_logic_vector(1 downto 0);
	constant ALU_B_FROM_RT		: alu_b_from_type := "00";
	constant ALU_B_FROM_IMM8        : alu_b_from_type := "01";

	subtype rd_val_new_from_type is std_logic_vector(2 downto 0);
	constant RD_FROM_NULL		: rd_val_new_from_type := "000";
	constant RD_FROM_ALU		: rd_val_new_from_type := "001";
	constant RD_FROM_MEMORY		: rd_val_new_from_type := "010";
	constant RD_FROM_IMM8_SHL8	: rd_val_new_from_type := "011";

	subtype pc_source_type is std_logic_vector(1 downto 0);
	constant PC_FROM_INC2		: pc_source_type := "00";
	constant PC_FROM_OPCODE11_0	: pc_source_type := "01";
	constant PC_FROM_BRANCH		: pc_source_type := "10";

	subtype branch_function_type is std_logic_vector(2 downto 0);
	constant BRANCH_FUNC_NONE	        : branch_function_type := "000";
	constant BRANCH_FUNC_IF_ZERO	        : branch_function_type := "001";
	constant BRANCH_FUNC_IF_NOT_ZERO	: branch_function_type := "010";
        constant BRANCH_FUNC_IF_BIT_SET		: branch_function_type := "011";
        constant BRANCH_FUNC_IF_BIT_CLEAR	: branch_function_type := "100";
	constant BRANCH_FUNC_UNCONDITIONAL	: branch_function_type := "101";

	subtype mem_source_type is std_logic_vector(1 downto 0);
	constant MEM_SOURCE_FETCH   : mem_source_type := "00";
	constant MEM_SOURCE_READ16  : mem_source_type := "01";
	constant MEM_SOURCE_WRITE16 : mem_source_type := "10";

	subtype mem_state_type is std_logic;
	constant MEM_STATE_ADDR	  : mem_state_type := '0';
	constant MEM_STATE_ACCESS : mem_state_type := '1';
end;

