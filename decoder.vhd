--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the instruction decoder
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
use work.dwarf.all;

entity decoder is
	port (
		I_instruction	: in std_logic_vector(15 downto 0);
		I_enable_decoder: in std_logic;
		I_alu_res	: in std_logic_vector(15 downto 0);
		I_rs_value	: in std_logic_vector(15 downto 0);
		I_rt_value	: in std_logic_vector(15 downto 0);
		I_pc_current	: in std_logic_vector(15 downto 1);
		I_ram_read_val	: in std_logic_vector(15 downto 0);

		O_alu_a		: out std_logic_vector(15 downto 0);
		O_alu_b		: out std_logic_vector(15 downto 0);
		O_alu_func	: out alu_function_type;
		O_rs_idx	: out std_logic_vector(3 downto 0);
		O_rt_idx	: out std_logic_vector(3 downto 0);
		O_rd_idx	: out std_logic_vector(3 downto 0);
		O_rd_value	: out std_logic_vector(15 downto 0);
		O_pc_source	: out pc_source_type;
		O_take_branch	: out std_logic;
		O_mem_source	: out mem_source_type
	);
end;

architecture logic of decoder is
	signal R_imm8		: std_logic_vector(7 downto 0);
begin

	decode_proc: process (I_instruction, I_alu_res, I_rs_value, I_rt_value, I_pc_current, I_ram_read_val) is
		variable opcode_var          : std_logic_vector(3 downto 0);
		variable subopcode_var       : std_logic_vector(3 downto 0);
		variable rs_var              : std_logic_vector(3 downto 0);
		variable rt_var              : std_logic_vector(3 downto 0);
		variable rd_var              : std_logic_vector(3 downto 0);
		variable imm8_var    	     : std_logic_vector(7 downto 0);
		variable imm4_var            : std_logic_vector(3 downto 0);
		variable is_zero_var	     : std_logic;
                variable is_bit_set_var      : std_logic;
		variable alu_function_var    : alu_function_type;
		variable alu_a_from_var      : alu_a_from_type;
		variable alu_b_from_var      : alu_b_from_type;
		variable rd_val_new_from_var : rd_val_new_from_type;
		variable pc_source_var       : pc_source_type;
		variable branch_function_var : branch_function_type;
		variable mem_source_var      : mem_source_type;
	begin
		alu_function_var    := ALU_FUNC_NOP;
		alu_a_from_var	    := ALU_A_FROM_RS;
		alu_b_from_var	    := ALU_B_FROM_RT;
		rd_val_new_from_var := RD_FROM_NULL;
		pc_source_var  	    := PC_FROM_INC2;
		branch_function_var := BRANCH_FUNC_NONE;
		mem_source_var	    := MEM_SOURCE_FETCH;

		if I_enable_decoder = '1' then

			opcode_var	    := I_instruction(15 downto 12);
			subopcode_var	    := I_instruction(11 downto 8);

			imm8_var	    := I_instruction(7 downto 0);
			imm4_var	    := I_instruction(3 downto 0);

			rd_var		    := I_instruction(3 downto 0);

			if opcode_var = "0000" then
				rs_var	:= I_instruction(7 downto 4);
				rt_var	:= I_instruction(3 downto 0);
			else
				rs_var	:= I_instruction(11 downto 8);
				rt_var	:= I_instruction(7 downto 4);
			end if;
		else
			opcode_var	:= "0000";
			subopcode_var	:= "0000";
			rd_var		:= "0000";
			rs_var		:= "0000";
			rt_var		:= "0000";
			imm4_var	:= "0000";
			imm8_var 	:= "00000000";
		end if;

		case opcode_var is
			when "0000" =>
				case subopcode_var is
					-- RDM	r[rd] = *(uint16*)r[rt]
					when "0001" =>
						alu_function_var := ALU_FUNC_MIRROR_A;
						rd_val_new_from_var := RD_FROM_MEMORY;
						mem_source_var := MEM_SOURCE_READ16;
						rd_var := rt_var;

					-- WRM	*(uint16*)r[rt] = r[rd]
					when "0010" =>
						alu_function_var := ALU_FUNC_MIRROR_A;
						mem_source_var := MEM_SOURCE_WRITE16;


-- redundant pseudo OP
					-- MOV  r[rd] = r[rt];
					when "0011" =>
						alu_function_var := ALU_FUNC_MIRROR_A;
						rd_val_new_from_var := RD_FROM_ALU;
						rd_var := rt_var;

					-- NOT	r[rd] = ~r[rt]
					when "0100" =>
						rd_val_new_from_var := RD_FROM_ALU;
						rd_var := rt_var;
						alu_function_var := ALU_FUNC_NOT;

					-- SKS  if (r[rt] & (1 << imm4)) I_pc_next += 4;
					when "0101" =>
						alu_a_from_var := ALU_A_FROM_PC;
						alu_function_var := ALU_FUNC_A_PLUS2;
						pc_source_var := PC_FROM_BRANCH;
						branch_function_var := BRANCH_FUNC_IF_BIT_SET;

					-- SKC  if (r[rt] & (1 << imm4)) I_pc_next += 4;
					when "0110" =>
						alu_a_from_var := ALU_A_FROM_PC;
						alu_function_var := ALU_FUNC_A_PLUS2;
						pc_source_var := PC_FROM_BRANCH;
						branch_function_var := BRANCH_FUNC_IF_BIT_CLEAR;

					-- SKZ	if (r[rt] == 0) I_pc_next = pc + 4;
					when "0111" =>
						alu_a_from_var := ALU_A_FROM_PC;
						alu_function_var := ALU_FUNC_A_PLUS2;
						pc_source_var := PC_FROM_BRANCH;
						branch_function_var := BRANCH_FUNC_IF_ZERO;

					-- SKN	if (r[rt] != 0) I_pc_next += 4;
					when "1000" =>
						alu_a_from_var := ALU_A_FROM_PC;
						alu_function_var := ALU_FUNC_A_PLUS2;
						pc_source_var := PC_FROM_BRANCH;
						branch_function_var := BRANCH_FUNC_IF_NOT_ZERO;

					-- BRR	I_pc_next = r[rt];
					when "1001" =>
						pc_source_var := PC_FROM_BRANCH;
						alu_function_var := ALU_FUNC_ADD;
						branch_function_var := BRANCH_FUNC_UNCONDITIONAL;

					-- NOP "0000"
					when others =>
				end case;


			--LDU  r[rs] = imm8 << 8 | 0x0;
			when "0001" =>
				rd_val_new_from_var := RD_FROM_IMM8_SHL8;
				rd_var := rs_var;

			-- SHR  r[rd] = r[rs] >> r[rt];
			when "0010" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_SHR;

			-- ROR  r[rd] = r[rs] >>> r[rt];
			when "0011" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_ROR;

			-- SUB  r[rd] = r[rs] - r[rt];
			when "0100" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_SUB;

			-- SUBI  r[rs] = r[rs] - imm8;
			when "0101" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_b_from_var := ALU_B_FROM_IMM8;
				rd_var := rs_var;
				alu_function_var := ALU_FUNC_SUB;

			-- ADD  r[rd] = r[rs] + r[rt];
			when "0110" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_ADD;

			-- ADDI  r[rs] = r[rs] + imm8
			when "0111" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_b_from_var := ALU_B_FROM_IMM8;
				rd_var := rs_var;
				alu_function_var := ALU_FUNC_ADD;

			-- MUL  r[rd] = r[rs] * r[rt];
			when "1000" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_MUL;

			-- OR  r[rd] = r[rs] | r[rt];
			when "1001" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_OR;

			--ORI  r[rs] = r[rs] | imm8;
			when "1010" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_b_from_var := ALU_B_FROM_IMM8;
				rd_var := rs_var;
				alu_function_var := ALU_FUNC_OR;

			-- XOR	r[rd] = r[rs] ^ r[rt];
			when "1011" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_XOR;

			-- AND  r[rd] = r[rs] & r[rt];
			when "1100" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_AND;

			-- ANDI  r[rs] = r[rs] & imm8;
			when "1101" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_b_from_var := ALU_B_FROM_IMM8;
				rd_var := rs_var;
				alu_function_var := ALU_FUNC_AND;

			-- CMP  r[rd] = r[rs] ? r[rt];
			when "1110" =>
				rd_val_new_from_var := RD_FROM_ALU;
				alu_function_var := ALU_FUNC_CMP;

			-- BRL	r[15] = I_pc_next; I_pc_next = imm12;
			when "1111" =>
				alu_a_from_var := ALU_A_FROM_PC;
				alu_function_var := ALU_FUNC_MIRROR_A;
				rd_val_new_from_var := RD_FROM_ALU;
				rd_var := "1111";
				pc_source_var := PC_FROM_OPCODE11_0;
				branch_function_var := BRANCH_FUNC_UNCONDITIONAL;

			-- NOP "0000"
			when others =>

		end case;

		-- Do not write anything to the destination register 0
		if (rd_val_new_from_var = RD_FROM_NULL) then
			rd_var := "0000";
		end if;

		O_rs_idx     <= rs_var;
		O_rt_idx     <= rt_var;
		O_rd_idx     <= rd_var;
		R_imm8       <= imm8_var;
		O_alu_func   <= alu_function_var;
		O_pc_source  <= pc_source_var;
		O_mem_source <= mem_source_var;

		-- Determine source for ALU input A
		case alu_a_from_var is
			when ALU_A_FROM_RS =>
				O_alu_a <= I_rs_value;
			when ALU_A_FROM_PC =>
				O_alu_a <= I_pc_current & '0';
			when others =>
				O_alu_a <= I_pc_current & '0';
		end case;

		-- Determine source for ALU input B
		case alu_b_from_var is
			when ALU_B_FROM_RT =>
				O_alu_b <= I_rt_value;
			when ALU_B_FROM_IMM8 =>
				O_alu_b <= I_rt_value(15 downto 8) & R_imm8;
			when others =>
				O_alu_b <= I_rt_value;
		end case;

		-- Determine what will be written to the destination register, if anything
		case rd_val_new_from_var is
			when RD_FROM_ALU =>
				O_rd_value <= I_alu_res;
			when RD_FROM_MEMORY =>
				O_rd_value <= I_ram_read_val;
			when RD_FROM_IMM8_SHL8 =>
				O_rd_value <= R_imm8 & ZERO(7 downto 0);
			when others =>
				O_rd_value <= I_alu_res;
		end case;

		-- Check if the register is zero
		if I_rs_value = "0000000000000000" then
			is_zero_var := '1';
		else
			is_zero_var := '0';
		end if;

		-- Check if the requested bit is set
		case imm4_var is
			when "0000" => is_bit_set_var := I_rs_value(0);
			when "0001" => is_bit_set_var := I_rs_value(1);
			when "0010" => is_bit_set_var := I_rs_value(2);
			when "0011" => is_bit_set_var := I_rs_value(3);
			when "0100" => is_bit_set_var := I_rs_value(4);
			when "0101" => is_bit_set_var := I_rs_value(5);
			when "0110" => is_bit_set_var := I_rs_value(6);
			when "0111" => is_bit_set_var := I_rs_value(7);
			when "1000" => is_bit_set_var := I_rs_value(8);
			when "1001" => is_bit_set_var := I_rs_value(9);
			when "1010" => is_bit_set_var := I_rs_value(10);
			when "1011" => is_bit_set_var := I_rs_value(11);
			when "1100" => is_bit_set_var := I_rs_value(12);
			when "1101" => is_bit_set_var := I_rs_value(13);
			when "1110" => is_bit_set_var := I_rs_value(14);
			when "1111" => is_bit_set_var := I_rs_value(15);
			when others => is_bit_set_var := '0';
		end case;

		-- Check conditions to see if a branch shall be taken or not
		-- according to the conditions checked above
		case branch_function_var is
			when BRANCH_FUNC_IF_ZERO =>
				O_take_branch <= is_zero_var;
			when BRANCH_FUNC_IF_NOT_ZERO =>
				O_take_branch <= not is_zero_var;
			when BRANCH_FUNC_IF_BIT_SET =>
				O_take_branch <= is_bit_set_var;
			when BRANCH_FUNC_IF_BIT_CLEAR =>
				O_take_branch <= not is_bit_set_var;
			when BRANCH_FUNC_UNCONDITIONAL =>
				O_take_branch <= '1';
			when others =>
				O_take_branch <= '0';
		end case;
	end process;
end;

