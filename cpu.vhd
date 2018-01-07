--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the whole CPU including the program counter logic, memory
--          controller, instruction decoder, ALU, register bank and internal RAM
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
use ieee.std_logic_misc.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity cpu is
	port (
		I_clk			: in std_logic;

		O_address      		: out std_logic_vector(15 downto 1);
		O_write_operation	: out std_logic;
		O_data_w		: out std_logic_vector(15 downto 0);
		O_debug_data		: out std_logic_vector(15 downto 0)
	);
end;

architecture logic of cpu is

	-- constants and types
	constant ZERO          : std_logic_vector(15 downto 0) := "0000000000000000";

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
	constant ALU_FUNC_A_PLUS4	: alu_function_type := "1100";
	constant ALU_FUNC_MIRROR_A	: alu_function_type := "1101";

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
	constant BRANCH_FUNC_IF_ZERO	        : branch_function_type := "000";
	constant BRANCH_FUNC_IF_NOT_ZERO	: branch_function_type := "001";
        constant BRANCH_FUNC_IF_BIT_SET		: branch_function_type := "010";
        constant BRANCH_FUNC_IF_BIT_CLEAR	: branch_function_type := "011";
	constant BRANCH_FUNC_UNCONDITIONAL	: branch_function_type := "100";

	subtype mem_action_type is std_logic_vector(1 downto 0);
	constant MEM_ACTION_FETCH   : mem_action_type := "00";
	constant MEM_ACTION_READ16  : mem_action_type := "01";
	constant MEM_ACTION_WRITE16 : mem_action_type := "10";

	-- CPU
	signal instruction	: std_logic_vector(15 downto 0);
	signal mem_read_val	: std_logic_vector(15 downto 0);
	signal imm8		: std_logic_vector(7 downto 0);
	signal alu_func		: alu_function_type;
	signal mem_source	: mem_action_type;
	signal cpu_pause	: std_logic;

	-- ALU
	signal alu_a		: std_logic_vector(15 downto 0);
	signal alu_b		: std_logic_vector(15 downto 0);
	signal alu_res		: std_logic_vector(15 downto 0);
	signal alu_a_lt_b	: std_logic;
	signal alu_a_eq_b       : std_logic;
	signal alu_a_eq_z       : std_logic;
	signal alu_b_eq_z       : std_logic;
	signal alu_shift_r      : std_logic_vector(15 downto 0);
	signal alu_rotate_r     : std_logic_vector(15 downto 0);
	signal alu_fac_a        : std_logic_vector(17 downto 0);
	signal alu_fac_b        : std_logic_vector(17 downto 0);
	signal alu_prod         : std_logic_vector(35 downto 0);

	-- Program Counter
	signal take_branch	: std_logic;
	signal pc_next		: std_logic_vector(15 downto 1);
	signal pc_current	: std_logic_vector(15 downto 1);
	signal pc_source	: pc_source_type;
	signal pc_reg		: std_logic_vector(15 downto 1);

	-- Memory Controller
	signal instruction_reg	: std_logic_vector(15 downto 0);
	signal next_instruction_reg : std_logic_vector(15 downto 0);
	signal address_reg	: std_logic_vector(15 downto 1);
	signal we_reg		: std_logic;
	signal mem_state_reg	: std_logic;

	constant MEM_STATE_ADDR	  : std_logic := '0';
	constant MEM_STATE_ACCESS : std_logic := '1';

	-- Registers
	signal rs_idx		: std_logic_vector(3 downto 0);
	signal rs_value		: std_logic_vector(15 downto 0);
	signal rt_idx		: std_logic_vector(3 downto 0);
	signal rt_value		: std_logic_vector(15 downto 0);
	signal rd_idx		: std_logic_vector(3 downto 0);
	signal rd_value		: std_logic_vector(15 downto 0);

	signal reg_write_enable	: std_logic;

	-- RAM
	signal ram_enable	 : std_logic;
	signal ram_address	 : std_logic_vector(15 downto 1);
	signal ram_write_enable  : std_logic;
	signal ram_data_write	 : std_logic_vector(15 downto 0);
	signal ram_data_read	 : std_logic_vector(15 downto 0);

begin

--------------------------------------------------------------------------------
-- Debug Interface
--------------------------------------------------------------------------------

-- Map the current value of the program counter to the seven segment display
	O_debug_data <= pc_current & '0';

--------------------------------------------------------------------------------
-- Program Counter
--------------------------------------------------------------------------------

	pc_select: process is
		variable next_pc : std_logic_vector(15 downto 1);
	begin
		next_pc :=  pc_reg + '1';

		case pc_source is
			when PC_FROM_OPCODE11_0 =>
				next_pc := ZERO(15 downto 13) & instruction(11 downto 0);
			when PC_FROM_BRANCH =>
				if take_branch = '1' then
					next_pc := alu_res(15 downto 1);
				end if;
			when others =>
		end case;

		if cpu_pause = '1' then
			next_pc := pc_reg;
		end if;

		if rising_edge(I_clk) then
			pc_reg <= next_pc;
		end if;

		pc_next <= next_pc;
		pc_current <= pc_reg;

	end process;

--------------------------------------------------------------------------------
-- Memory controller
--------------------------------------------------------------------------------

	memctrl_proc: process is

		variable address_var    : std_logic_vector(15 downto 1);
		variable data_read_var  : std_logic_vector(15 downto 0);
		variable ram_write_var : std_logic_vector(15 downto 0);
		variable instruction_next    : std_logic_vector(15 downto 0);
		variable we_var         : std_logic;
		variable mem_state_next : std_logic;
		variable pause_var      : std_logic;
		variable bits           : std_logic_vector(1 downto 0);
	begin
		we_var         := '0';
		pause_var      := '0';
		data_read_var  := ZERO;
		ram_write_var  := ZERO;
		mem_state_next := mem_state_reg;
		instruction_next    := instruction_reg;

		case mem_source is
			when MEM_ACTION_READ16 =>
				data_read_var := ram_data_read;

			when MEM_ACTION_WRITE16 =>
				ram_write_var := rt_value;
				we_var := '1';

			when others =>
		end case;

		if mem_source = MEM_ACTION_FETCH then --instruction fetch
			address_var := pc_next;
			instruction_next := ram_data_read;
			mem_state_next := MEM_STATE_ADDR;
		else
			if mem_state_reg = MEM_STATE_ADDR then
				address_var := alu_res(15 downto 1);
				mem_state_next := MEM_STATE_ACCESS;
				pause_var := '1';
			else  --MEM_STATE_ACCESS
				address_var := pc_next;
				instruction_next := next_instruction_reg;
				mem_state_next := MEM_STATE_ADDR;
				we_var := '0';
			end if;
		end if;

		if rising_edge(I_clk) then
			address_reg <= address_var;
			we_reg <= we_var;
			mem_state_reg <= mem_state_next;
			instruction_reg <= instruction_next;

			if mem_state_reg = MEM_STATE_ADDR then
				next_instruction_reg <= ram_data_read;
			end if;
		end if;

		instruction	  <= instruction_reg;
		mem_read_val	  <= data_read_var;
		cpu_pause         <= pause_var;
		ram_address	  <= address_var;
		ram_write_enable  <= we_var;
		O_write_operation <= we_reg;
		O_address	  <= address_reg;
		ram_data_write    <= ram_write_var;
		O_data_w	  <= ram_write_var;

	end process;

---------------------------------------------------------------------
-- Instruction Decoder
---------------------------------------------------------------------

	decode_proc: process is
		variable opcode          : std_logic_vector(3 downto 0);
		variable subopcode       : std_logic_vector(3 downto 0);
		variable rs              : std_logic_vector(3 downto 0);
		variable rt              : std_logic_vector(3 downto 0);
		variable rd              : std_logic_vector(3 downto 0);
		variable imm8_val        : std_logic_vector(7 downto 0);
		variable imm4_val        : std_logic_vector(3 downto 0);
		variable is_zero	 : std_logic;
                variable is_bit_set      : std_logic;
		variable alu_function    : alu_function_type;
		variable alu_a_from      : alu_a_from_type;
		variable alu_b_from      : alu_b_from_type;
		variable rd_val_new_from : rd_val_new_from_type;
		variable pc_source_val   : pc_source_type;
		variable branch_function : branch_function_type;
		variable mem_action      : mem_action_type;
	begin
		alu_function    := ALU_FUNC_NOP;
		alu_a_from	:= ALU_A_FROM_RS;
		alu_b_from	:= ALU_B_FROM_RT;
		rd_val_new_from := RD_FROM_NULL;
		pc_source_val   := PC_FROM_INC2;
		branch_function := BRANCH_FUNC_IF_ZERO;
		mem_action	:= MEM_ACTION_FETCH;

		opcode		:= instruction(15 downto 12);
		subopcode	:= instruction(11 downto 8);

		imm8_val	:= instruction(7 downto 0);
		imm4_val	:= instruction(3 downto 0);

		rd		:= instruction(3 downto 0);
		if opcode = "0000" then
			rs	:= instruction(7 downto 4);
			rt	:= instruction(3 downto 0);
		else
			rs	:= instruction(11 downto 8);
			rt	:= instruction(7 downto 4);
		end if;

		case opcode is
			when "0000" =>
				case subopcode is
					-- RDM	r[rd] = *(uint16*)r[rt]
					when "0001" =>
						alu_function := ALU_FUNC_MIRROR_A;
						rd_val_new_from := RD_FROM_MEMORY;
						mem_action := MEM_ACTION_READ16;
						rd := rt;

					-- WRM	*(uint16*)r[rt] = r[rd]
					when "0010" =>
						alu_function := ALU_FUNC_MIRROR_A;
						mem_action := MEM_ACTION_WRITE16;

                                        -- MOV  r[rd] = r[rt];
                                        when "0011" =>
                                                alu_function := ALU_FUNC_MIRROR_A;
                                                rd_val_new_from := RD_FROM_ALU;
                                                rd := rt;

					-- NOT	r[rd] = ~r[rt]
					when "0100" =>
						rd_val_new_from := RD_FROM_ALU;
						rd := rt;
						alu_function := ALU_FUNC_NOT;

                                        -- SKS  if (r[rt] & (1 << imm4)) pc_next += 4;
                                        when "0101" =>
                                                alu_a_from := ALU_A_FROM_PC;
                                                alu_function := ALU_FUNC_A_PLUS4;
                                                pc_source_val := PC_FROM_BRANCH;
                                                branch_function := BRANCH_FUNC_IF_BIT_SET;

                                        -- SKC  if (r[rt] & (1 << imm4)) pc_next += 4;
                                        when "0110" =>
                                                alu_a_from := ALU_A_FROM_PC;
                                                alu_function := ALU_FUNC_A_PLUS4;
                                                pc_source_val := PC_FROM_BRANCH;
                                                branch_function := BRANCH_FUNC_IF_BIT_CLEAR;

					-- SKZ	if (r[rt] == 0) pc_next = pc + 4;
					when "0111" =>
						alu_a_from := ALU_A_FROM_PC;
						alu_function := ALU_FUNC_A_PLUS4;
						pc_source_val := PC_FROM_BRANCH;
						branch_function := BRANCH_FUNC_IF_ZERO;

					-- SKN	if (r[rt] != 0) pc_next += 4;
					when "1000" =>
						alu_a_from := ALU_A_FROM_PC;
						alu_function := ALU_FUNC_A_PLUS4;
						pc_source_val := PC_FROM_BRANCH;
						branch_function := BRANCH_FUNC_IF_NOT_ZERO;

					-- BRR	pc_next = r[rt];
					when "1001" =>
						pc_source_val := PC_FROM_BRANCH;
						alu_function := ALU_FUNC_ADD;
						branch_function := BRANCH_FUNC_UNCONDITIONAL;

					-- NOP "0000"
					when others =>
				end case;


			--LDU  r[rs] = imm8 << 8 | 0x0;
			when "0001" =>
				rd_val_new_from := RD_FROM_IMM8_SHL8;
				rd := rs;

			-- SHR  r[rd] = r[rs] >> r[rt];
			when "0010" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_SHR;

			-- ROR  r[rd] = r[rs] >>> r[rt];
			when "0011" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_ROR;

			-- SUB  r[rd] = r[rs] - r[rt];
			when "0100" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_SUB;

			-- SUBI  r[rs] = r[rs] - imm8;
			when "0101" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_b_from := ALU_B_FROM_IMM8;
				rd := rs;
				alu_function := ALU_FUNC_SUB;

			-- ADD  r[rd] = r[rs] + r[rt];
			when "0110" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_ADD;

			-- ADDI  r[rs] = r[rs] + imm8
			when "0111" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_b_from := ALU_B_FROM_IMM8;
				rd := rs;
				alu_function := ALU_FUNC_ADD;

			-- MUL  r[rd] = r[rs] * r[rt];
			when "1000" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_MUL;

			-- OR  r[rd] = r[rs] | r[rt];
			when "1001" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_OR;

			--ORI  r[rs] = r[rs] | imm8;
			when "1010" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_b_from := ALU_B_FROM_IMM8;
				rd := rs;
				alu_function := ALU_FUNC_OR;

			-- XOR	r[rd] = r[rs] ^ r[rt];
			when "1011" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_XOR;

			-- AND  r[rd] = r[rs] & r[rt];
			when "1100" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_AND;

			-- ANDI  r[rs] = r[rs] & imm8;
			when "1101" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_b_from := ALU_B_FROM_IMM8;
				rd := rs;
				alu_function := ALU_FUNC_AND;

			-- CMP  r[rd] = r[rs] ? r[rt];
			when "1110" =>
				rd_val_new_from := RD_FROM_ALU;
				alu_function := ALU_FUNC_CMP;

			-- BRL	r[15] = pc_next; pc_next = imm12;
			when "1111" =>
				alu_a_from := ALU_A_FROM_PC;
				alu_function := ALU_FUNC_A_PLUS2;
				rd_val_new_from := RD_FROM_ALU;
				rd := "1111";
				pc_source_val := PC_FROM_OPCODE11_0;

			-- NOP "0000"
			when others =>

		end case;

		-- Do not write anything to the destination register 0
		if (rd_val_new_from = RD_FROM_NULL) then
			rd := "0000";
		end if;

		rs_idx     <= rs;
		rt_idx     <= rt;
		rd_idx     <= rd;
		imm8       <= imm8_val;
		alu_func   <= alu_function;
		pc_source  <= pc_source_val;
		mem_source <= mem_action;

		-- Determine source for ALU input A
		case alu_a_from is
			when ALU_A_FROM_RS =>
				alu_a <= rs_value;
			when ALU_A_FROM_PC =>
				alu_a <= pc_current & '0';
			when others =>
				alu_a <= pc_current & '0';
		end case;

		-- Determine source for ALU input B
		case alu_b_from is
			when ALU_B_FROM_RT =>
				alu_b <= rt_value;
			when ALU_B_FROM_IMM8 =>
				alu_b <= rt_value(15 downto 8) & imm8;
			when others =>
				alu_b <= rt_value;
		end case;

		-- Determine what will be written to the destination register, if anything
		case rd_val_new_from is
			when RD_FROM_ALU =>
				rd_value <= alu_res;
			when RD_FROM_MEMORY =>
				rd_value <= mem_read_val;
			when RD_FROM_IMM8_SHL8 =>
				rd_value <= imm8 & ZERO(7 downto 0);
			when others =>
				rd_value <= alu_res;
		end case;

                -- Check if the register is zero
		if rs_value = "0000000000000000" then
			is_zero := '1';
		else
			is_zero := '0';
		end if;

                -- Check if the requested bit is set
                case imm4_val is
                        when "0000" => is_bit_set := rs_value(0);
                        when "0001" => is_bit_set := rs_value(1);
                        when "0010" => is_bit_set := rs_value(2);
                        when "0011" => is_bit_set := rs_value(3);
                        when "0100" => is_bit_set := rs_value(4);
                        when "0101" => is_bit_set := rs_value(5);
                        when "0110" => is_bit_set := rs_value(6);
                        when "0111" => is_bit_set := rs_value(7);
                        when "1000" => is_bit_set := rs_value(8);
                        when "1001" => is_bit_set := rs_value(9);
                        when "1010" => is_bit_set := rs_value(10);
                        when "1011" => is_bit_set := rs_value(11);
                        when "1100" => is_bit_set := rs_value(12);
                        when "1101" => is_bit_set := rs_value(13);
                        when "1110" => is_bit_set := rs_value(14);
                        when "1111" => is_bit_set := rs_value(15);
                        when others => is_bit_set := '0';
                end case;

                -- Check conditions to see if a branch shall be taken or not
                -- according to the conditions checked above
		case branch_function is
			when BRANCH_FUNC_IF_ZERO =>
				take_branch <= is_zero;
			when BRANCH_FUNC_IF_NOT_ZERO =>
				take_branch <= not is_zero;
                        when BRANCH_FUNC_IF_BIT_SET =>
                                take_branch <= is_bit_set;
                        when BRANCH_FUNC_IF_BIT_CLEAR =>
                                take_branch <= not is_bit_set;
                        when BRANCH_FUNC_UNCONDITIONAL =>
				take_branch <= '1';
			when others =>
				take_branch <= '0';
		end case;
	end process;

---------------------------------------------------------------------
-- ALU
---------------------------------------------------------------------

	-- shift right (shift amount in alu_b(3 downto 0))
	with alu_b(3 downto 0) select
		alu_shift_r <= alu_a                        when "0000", -- 0
		    ZERO(0)           & alu_a(15 downto 1)  when "0001", -- 1
		    ZERO(1  downto 0) & alu_a(15 downto 2)  when "0010", -- 2
		    ZERO(2  downto 0) & alu_a(15 downto 3)  when "0011", -- 3
		    ZERO(3  downto 0) & alu_a(15 downto 4)  when "0100", -- 4
		    ZERO(4  downto 0) & alu_a(15 downto 5)  when "0101", -- 5
		    ZERO(5  downto 0) & alu_a(15 downto 6)  when "0110", -- 6
		    ZERO(6  downto 0) & alu_a(15 downto 7)  when "0111", -- 7
		    ZERO(7  downto 0) & alu_a(15 downto 8)  when "1000", -- 8
		    ZERO(8  downto 0) & alu_a(15 downto 9)  when "1001", -- 9
		    ZERO(9  downto 0) & alu_a(15 downto 10) when "1010", -- 10
		    ZERO(10 downto 0) & alu_a(15 downto 11) when "1011", -- 11
		    ZERO(11 downto 0) & alu_a(15 downto 12) when "1100", -- 12
		    ZERO(12 downto 0) & alu_a(15 downto 13) when "1101", -- 13
		    ZERO(13 downto 0) & alu_a(15 downto 14) when "1110", -- 14
		    ZERO(14 downto 0) & alu_a(15)           when others; -- 15

	-- rotate right (rotate amount in alu_b(3 downto 0))
	with alu_b(3 downto 0) select
		alu_rotate_r <= alu_a                        when "0000", -- 0
		    alu_a(0)           & alu_a(15 downto 1)  when "0001", -- 1
		    alu_a(1  downto 0) & alu_a(15 downto 2)  when "0010", -- 2
		    alu_a(2  downto 0) & alu_a(15 downto 3)  when "0011", -- 3
		    alu_a(3  downto 0) & alu_a(15 downto 4)  when "0100", -- 4
		    alu_a(4  downto 0) & alu_a(15 downto 5)  when "0101", -- 5
		    alu_a(5  downto 0) & alu_a(15 downto 6)  when "0110", -- 6
		    alu_a(6  downto 0) & alu_a(15 downto 7)  when "0111", -- 7
		    alu_a(7  downto 0) & alu_a(15 downto 8)  when "1000", -- 8
		    alu_a(8  downto 0) & alu_a(15 downto 9)  when "1001", -- 9
		    alu_a(9  downto 0) & alu_a(15 downto 10) when "1010", -- 10
		    alu_a(10 downto 0) & alu_a(15 downto 11) when "1011", -- 11
		    alu_a(11 downto 0) & alu_a(15 downto 12) when "1100", -- 12
		    alu_a(12 downto 0) & alu_a(15 downto 13) when "1101", -- 13
		    alu_a(13 downto 0) & alu_a(15 downto 14) when "1110", -- 14
		    alu_a(14 downto 0) & alu_a(15)           when others; -- 15

	-- MULT18X18: 18 x 18 signed asynchronous multiplier
	-- Expand alu-in A and B to 17 bit values so they can be fed to the HW multiplier
	alu_fac_a <= "00" & alu_a;
	alu_fac_b <= "00" & alu_b;
	MULT18X18_inst : MULT18X18
	port map (
		 P => alu_prod  -- 36-bit multiplier output
		,A => alu_fac_a -- 18-bit multiplier input
		,B => alu_fac_b -- 18-bit multiplier input
		);

	-- CMP operation
	alu_a_eq_z <= '1' when alu_a = "0000000000000000" else '0';
	alu_b_eq_z <= '1' when alu_b = "0000000000000000" else '0';
	alu_a_eq_b <= '1' when alu_a  = alu_b else '0';
	alu_a_lt_b <= '0' when alu_a >= alu_b else '1';

	-- Perform varios ALU operations relying on the syntesis tool correctly inferring the OP
	alu_res <=
		alu_prod(15 downto 0)	when alu_func = ALU_FUNC_MUL else
		alu_a + alu_b		when alu_func = ALU_FUNC_ADD else
		alu_a - alu_b		when alu_func = ALU_FUNC_SUB else
		not alu_a		when alu_func = ALU_FUNC_NOT else
		alu_a or  alu_b		when alu_func = ALU_FUNC_OR else
		alu_a xor  alu_b	when alu_func = ALU_FUNC_XOR else
		alu_a and alu_b		when alu_func = ALU_FUNC_AND else
		alu_shift_r		when alu_func = ALU_FUNC_SHR else
		alu_rotate_r		when alu_func = ALU_FUNC_ROR else
		alu_a			when alu_func = ALU_FUNC_MIRROR_A else
		alu_a + x"2"		when alu_func = ALU_FUNC_A_PLUS2 else
		alu_a + x"4"		when alu_func = ALU_FUNC_A_PLUS4 else
		ZERO(15 downto 4)
			& alu_a_lt_b
			& alu_a_eq_b
			& alu_b_eq_z
			& alu_a_eq_z	when alu_func = ALU_FUNC_CMP else
		ZERO;

---------------------------------------------------------------------
-- Register Bank
---------------------------------------------------------------------

	reg_write_enable <= '1' when ((rd_idx /= "0000") and (cpu_pause = '0')) else
			    '0';

	-- RAM16X1D: 16 x 1 positive edge write, asynchronous read dual-port
	-- distributed RAM for all Xilinx FPGAs

	-- 16 registers
	reg_loop: for i in 0 to 15 generate
	begin
		--Read port A
		reg_bit1a : RAM16X1D
		port map (
			 WCLK  => I_clk,              -- Port A write clock input
			 WE    => reg_write_enable,			  -- Port A write enable input
			 A0    => rd_idx(0),      -- Port A address[0] input bit
			 A1    => rd_idx(1),      -- Port A address[1] input bit
			 A2    => rd_idx(2),      -- Port A address[2] input bit
			 A3    => rd_idx(3),      -- Port A address[3] input bit
			 D     => rd_value(i),      -- Port A 1-bit data input
			 DPRA0 => rs_idx(0),      -- Port B address[0] input bit
			 DPRA1 => rs_idx(1),      -- Port B address[1] input bit
			 DPRA2 => rs_idx(2),      -- Port B address[2] input bit
			 DPRA3 => rs_idx(3),      -- Port B address[3] input bit
			 DPO   => rs_value(i), -- Port B 1-bit data output
			 SPO   => open                -- Port A 1-bit data output
		);

		--Read port B
		reg_bit2a : RAM16X1D
		port map (
			 WCLK  => I_clk,              -- Port A write clock input
			 WE    => reg_write_enable,			  -- Port A write enable input
			 A0    => rd_idx(0),      -- Port A address[0] input bit
			 A1    => rd_idx(1),      -- Port A address[1] input bit
			 A2    => rd_idx(2),      -- Port A address[2] input bit
			 A3    => rd_idx(3),      -- Port A address[3] input bit
			 D     => rd_value(i),      -- Port A 1-bit data input
			 DPRA0 => rt_idx(0),      -- Port B address[0] input bit
			 DPRA1 => rt_idx(1),      -- Port B address[1] input bit
			 DPRA2 => rt_idx(2),      -- Port B address[2] input bit
			 DPRA3 => rt_idx(3),      -- Port B address[3] input bit
			 DPO   => rt_value(i), -- Port B 1-bit data output
			 SPO   => open                -- Port A 1-bit data output
		);
	end generate;

---------------------------------------------------------------------
-- Random Access Memory
---------------------------------------------------------------------

	ram_enable <= '1' when ram_address(15 downto 11) = "00000" else '0';

	-- RAMB16_S18: 1k x 16 + 2 parity bits single-port RAM
	RAMB16_S18_inst : RAMB16_S18
	generic map (
		INIT_00 => X"062003b60000052032520000f3fda655acf0ab0fa501a2aa12aaa10011800000",
		INIT_01 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000009f00000f0090000f3fd03c60000",
		INIT_02 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_03 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_04 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_05 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_06 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_07 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_08 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_09 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_0F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_10 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_11 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_12 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_13 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_14 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_15 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_16 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_17 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_18 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_19 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_1F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_20 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_21 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_22 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_23 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_24 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_25 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_26 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_27 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_28 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_29 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_2F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_30 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_31 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_32 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_33 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_34 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_35 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_36 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_37 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_38 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_39 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
		INIT_3F => X"000009f00216FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
	port map (
		DO   => ram_data_read,             -- 16-bit Data Output
		DOP  => open,                      -- 2-bit parity Output
		ADDR => ram_address(10 downto 1),  -- 10-bit Address Input
		CLK  => I_clk,                     -- Clock
		DI   => ram_data_write,            -- 16-bit Data Input
		DIP  => ZERO(1 downto 0),          -- 2-bit parity Input
		EN   => ram_enable,		   -- RAM Enable Input
		SSR  => ZERO(0),                   -- Synchronous Set/Reset Input
		WE   => ram_write_enable           -- Write Enable Input
	);

end; -- CPU

