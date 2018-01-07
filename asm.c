/*
 * Dwarf - A minimalist 16-bit RISC CPU
 *
 * asm.c: Crude, brutal and unforgiving assembly language translator
 *
 * Copyright (c) 2017, Helmut Sipos <helmut.sipos@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
*/

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>
#include <sysexits.h>
#include <sys/stat.h>


#define OK		0

#define RESET_VECTOR	0x0000


char *save_ptr_token = NULL;


typedef struct {
	const char *instr;
	const uint16_t opcode;
	const uint8_t form;
} tInstr;

const char *regs[] = { "r0" ,"r1" ,"r2" ,"r3" ,"r4" ,"r5" ,"r6" ,"r7"
		      ,"r8" ,"r9" ,"r10" ,"r11" ,"r12" ,"r13" ,"r14" ,"r15" };

#define NR_REGS (sizeof (regs) / sizeof (char*))

static int
get_reg (char *reg, uint8_t *value)
{
	int i;
	int rc = !OK;

	for (i = 0; i < NR_REGS; i++)
		if (!strcmp (regs[i], reg)) {
			*value = i;
			rc = OK;
			break;
		}

	return rc;
}

/* Instruction forms */

#define FRM_OP_NOTHING		0x0  /* "" */
#define FRM_OP_SO_RT		0x1  /* "%s" */
#define FRM_OP_SO_RT_RD		0x2  /* "%s %s" */
#define FRM_OP_SO_RT_IMM4	0x3  /* "%s %s" */
#define FRM_OP_RS_LIMM8		0x4  /* "%s %s" */
#define FRM_OP_RS_UIMM8		0x5  /* "%s %s" */
#define FRM_OP_RS_RT_RD		0x6  /* "%s %s %s" */
#define FRM_OP_IMM12		0x7  /* "%s" */

/* Instruction set */

#define RDM_OP_SO		0x0100  /* r[rd] = *(uint16*)r[rt]; */
#define WRM_OP_SO		0x0200  /* *(uint16*)r[rt] = r[rd]; */
#define MOV_OP_SO               0x0300  /* r[rd] = r[rt]; */
#define NOT_OP_SO		0x0400  /* r[rd] = ~r[rt]; */
#define SKS_OP_SO		0x0500  /* if (r[rt] & (1 << imm4)) pc_next += 4; */
#define SKC_OP_SO		0x0600  /* if (!(r[rt] & (1 << imm4))) pc_next += 4; */
#define SKZ_OP_SO		0x0700  /* if (r[rt] == 0) pc_next += 4; */
#define SKN_OP_SO		0x0800  /* if (r[rt] != 0) pc_next += 4; */
#define BRR_OP_SO		0x0900  /* pc_next = r[rt]; */

#define LDU_OP_SO		0x1000  /* r[rs] = (imm8 << 8) | 0x0; */
#define	SHR_OP_SO		0x2000  /* r[rd] = r[rs] >> r[rt]; */
#define ROR_OP_SO		0x3000  /* r[rd] = r[rs] >>> r[rt]; */
#define SUB_OP_SO		0x4000  /* r[rd] = r[rs] - r[rt]; */
#define SUBI_OP_SO		0x5000  /* r[rs] = r[rs] - imm8; */
#define ADD_OP_SO		0x6000  /* r[rd] = r[rs] + r[rt]; */
#define ADDI_OP_SO		0x7000  /* r[rs] = r[rs] + imm8; */
#define MUL_OP_SO		0x8000  /* r[rd] = r[rs] * r[rt]; */
#define OR_OP_SO		0x9000  /* r[rd] = r[rs] | r[rt]; */
#define ORI_OP_SO		0xA000  /* r[rs] = r[rs] | imm8; */
#define XOR_OP_SO		0xB000  /* r[rd] = r[rs] | r[rt]; */
#define AND_OP_SO		0xC000  /* r[rd] = r[rs] & r[rt]; */
#define ANDI_OP_SO		0xD000  /* r[rs] = r[rs] & imm8; */
#define CMP_OP_SO		0xE000  /* r[rd] = r[rs] ? r[rt]; */
#define BRL_OP_SO		0xF000  /* r[15] = pc_next; pc_next = imm12; */
#define NOP_OP_SO		0x0000  /* nop */

const tInstr instrSet[] = {
	 {"rdm",	RDM_OP_SO,	FRM_OP_SO_RT_RD}
	,{"wrm",	WRM_OP_SO,	FRM_OP_SO_RT_RD}
	,{"mov",	MOV_OP_SO,	FRM_OP_SO_RT_RD}
	,{"not",	NOT_OP_SO,	FRM_OP_SO_RT_RD}
	,{"sks",	SKS_OP_SO,	FRM_OP_SO_RT_IMM4}
	,{"skc",	SKC_OP_SO,	FRM_OP_SO_RT_IMM4}
	,{"skz",	SKZ_OP_SO,	FRM_OP_SO_RT}
	,{"skn",	SKN_OP_SO,	FRM_OP_SO_RT}
	,{"brr",	BRR_OP_SO,	FRM_OP_SO_RT}

	,{"ldu",	LDU_OP_SO,	FRM_OP_RS_UIMM8}
	,{"shr",	SHR_OP_SO,	FRM_OP_RS_RT_RD}
	,{"ror",	ROR_OP_SO,	FRM_OP_RS_RT_RD}
	,{"sub",	SUB_OP_SO,	FRM_OP_RS_RT_RD}
	,{"subi",	SUBI_OP_SO,	FRM_OP_RS_LIMM8}
	,{"add",	ADD_OP_SO,	FRM_OP_RS_RT_RD}
	,{"addi",	ADDI_OP_SO,	FRM_OP_RS_LIMM8}
	,{"mul",	MUL_OP_SO,	FRM_OP_RS_RT_RD}
	,{"or",		OR_OP_SO,	FRM_OP_RS_RT_RD}
	,{"ori",	ORI_OP_SO,	FRM_OP_RS_LIMM8}
	,{"xor",	XOR_OP_SO,	FRM_OP_RS_RT_RD}
	,{"and",	AND_OP_SO,	FRM_OP_RS_RT_RD}
	,{"andi",	ANDI_OP_SO,	FRM_OP_RS_LIMM8}
	,{"cmp",	CMP_OP_SO,	FRM_OP_RS_RT_RD}
	,{"brl",        BRL_OP_SO,	FRM_OP_IMM12}
	,{"nop",	NOP_OP_SO,	FRM_OP_NOTHING}
};

#define NR_INSTR (sizeof (instrSet) / sizeof (tInstr))

static int
get_opcode (char *instr, uint16_t *opcode, uint8_t *form)
{
	int i;
	int rc = !OK;

	for (i = 0; i < NR_INSTR; i++)
		if (!strcmp (instrSet[i].instr, instr)) {
			*opcode = instrSet[i].opcode;
			*form = instrSet[i].form;
			rc = OK;
			break;
		}

	return rc;
}

typedef struct sSymbol {
	char *name;
	uint16_t value;
	struct sSymbol *next;
} tSymbol;


tSymbol *symbols = NULL;

static tSymbol*
find_symbol (const char *name)
{
	tSymbol *symb = NULL;

	for (symb = symbols; symb; symb = symb->next)
		if (!strcmp (symb->name, name))
			break;
	return symb;
}


static void
add_symbol (const char *name, uint16_t value)
{
	tSymbol *tmp = NULL;
	tSymbol *symb = (tSymbol*) malloc (sizeof (tSymbol));

	symb->name = strdup (name);
	symb->value = value;
	symb->next = NULL;

	if (!symbols)
		symbols = symb;
	else {
		for (tmp = symbols; tmp->next; tmp = tmp->next)
			;

		tmp->next = symb;
	}
}


static uint8_t
get_reg_param (void)
{
	char *par = NULL;
	uint8_t reg = 0xFF;

	if ((par = strtok_r (NULL, ", \t\n", &save_ptr_token)) == NULL) {
		printf("PANIC: missing register parameter\n");
		exit (EX_DATAERR);
	}

	if (get_reg(par, &reg) != OK)
	{
		printf("PANIC: unknown register '%s'\n", par);
		exit (EX_DATAERR);
	}

	return reg;
}


static uint16_t
get_imm_param (int pass)
{
	char *par = NULL;
	char *endptr = NULL;
	uint16_t imm = 0xDEAD;

	if (pass != 0) {
		if ((par = strtok_r (NULL, ", \t\n", &save_ptr_token)) == NULL) {
			printf("PANIC: missing register parameter\n");
			exit (EX_DATAERR);
		}

		imm = strtol(par, &endptr, 0);

		if ((par == NULL) || (*endptr != '\0')) {
			tSymbol *sym;

			if (!(sym = find_symbol (par))) {
				printf("PANIC: symbol '%s' not found\n", par);
				exit (EX_DATAERR);
			}

			imm = sym->value;
		}
	}

	return imm;
}


static void
usage (void)
{
	printf ("usage: asm [-l] <-f in.s>\n");
	exit (EX_USAGE);
}

int
main (int argc, char **argv)
{
	struct stat st;
	off_t src_len = 0;
	FILE *fin = NULL;
	char *file = NULL;
	char *src = NULL;
	char *save_ptr_line = NULL;
	char *line = NULL;
	char *ptr = NULL;
	char *token = NULL;
	char *orig_line = NULL;
	uint16_t pc = RESET_VECTOR;
	int line_nr = 0;
	int pass = 0;
	int list = 0;
	int opt;

	if (argc < 2)
		usage ();

	while ((opt = getopt (argc, argv, "lf:")) != -1)
		switch (opt) {
			case 'l':
				list = 1;
				break;
			case 'f':
				file = strdup(optarg);
				break;
			default:
				abort ();
		}

	if (!file)
		usage();

	fin = fopen (file, "r");

	fstat (fileno (fin), &st);
	src_len = st.st_size;

	src = (char *) malloc (src_len + 1);

	memset (src, 0, src_len + 1);

	fread (src, sizeof (char), src_len, fin);
	fclose (fin);

	for (pass = 0; pass < 2; pass++) {

		pc = RESET_VECTOR;

		line_nr = 0;

		line = strtok_r (strdup (src), "\n", &save_ptr_line);

		while (line) {

			orig_line = strdup (line);
			line_nr++;

			if ((ptr = rindex (line, ';')))
				*ptr = 0;

			if ((token = strtok_r (line, ", \t\n", &save_ptr_token)) != NULL) {

				if (token[strlen (token) - 1] == ':') {
					*index(token, ':') = 0;
					if (find_symbol (token)) {
						if (pass == 0) {
							printf ("PANIC: duplicated symbol: '%s' in line: %d\n", token, line_nr);
							exit (EX_DATAERR);
						}
					}
					else
						add_symbol (token, pc);

					if (pass && list)
						printf ("\t\t%s:\n", token);
				}
				else if (token[0] == '.') {
					char *endptr = NULL;
					uint16_t val = 0xDEAD;
					char *par = strtok_r (NULL, " ,\t\n", &save_ptr_token);

					val = strtol(par, &endptr, 0);
					if (*endptr != '\0') {
						printf ("PANIC: can not translate value '%s'\n", par);
						exit (EX_DATAERR);
					}


					if (find_symbol (&token[1])) {
						if (pass == 0) {
							printf ("PANIC: duplicated symbol: '%s' in line: %d\n", &token[1], line_nr);
							exit (EX_DATAERR);
						}
					}
					else
						add_symbol (&token[1], val);

					if (pass && list)
						printf ("\t\t\%s %s\n", &token[1], par);
				}
				else if (token[0] == '$') {
					char *par = NULL;
					int skip = 0;

					if (list)
						printf ("\n");

					while ((par = strtok_r (NULL, ",\t\n", &save_ptr_token)) != NULL) {

						for (skip = 0; par[skip] == ' '; skip++)
							;

						if  (par[skip] == '"') {
							int i;
							for (i=skip + 1; par[i] != '"'; i++) {
								if (pass && list)
									printf ("%04X %04X\t\t'%c'\n", pc, (uint16_t)par[i], par[i]);
								pc += 2;
							}
						}
						else {
							char *endptr = NULL;
							uint16_t val = 0xDEAD;

							val = strtol(&par[skip], &endptr, 0);
							if (*endptr != '\0') {
								printf ("PANIC: can not translate value '%s'\n", &par[skip]);
								exit (EX_DATAERR);
							}

							if (pass && list)
								printf ("%04X %04X\t\t%s\n", pc, val, &par[skip]);
							pc += 2;
						}
					}
					if (list)
						printf ("\n");
				}
				else if (token[0] == '@') {
					char *endptr = NULL;
					uint16_t val = 0xDEAD;

					val = strtol(&token[1], &endptr, 0);
					if (*endptr != '\0') {
						printf ("PANIC: can not translate given address '%s'\n", &token[1]);
						exit (EX_DATAERR);
					}

					pc = val;
				}
				else {
					uint16_t opcode = 0;
					uint16_t val = 0;
					uint8_t form = 0;

					if (get_opcode (token, &opcode, &form) != OK) {
						printf ("PANIC: unknown mnemonic: '%s' in line: %d\n", token, line_nr);
						exit (EX_DATAERR);
					}

					switch (form) {

						case FRM_OP_SO_RT:
							val = get_reg_param ();
							opcode |= val << 4;
							break;

						case FRM_OP_SO_RT_RD:
							val = get_reg_param ();
							opcode |= val << 4;
							val = get_reg_param ();
							opcode |= val;
							break;

						case FRM_OP_SO_RT_IMM4:
							val = get_reg_param ();
							opcode |= val << 4;
							val = get_imm_param(pass);
							opcode |= val & 0xF;
							break;

						case FRM_OP_RS_LIMM8:
							val = get_reg_param ();
							opcode |= val << 8;
							val = get_imm_param(pass);
							opcode |= val & 0xFF;
							break;

						case FRM_OP_RS_UIMM8:
							val = get_reg_param ();
							opcode |= val << 8;
							val = get_imm_param(pass);
							opcode |= (val >> 8) & 0xFF;
							break;

						case FRM_OP_RS_RT_RD:
							val = get_reg_param ();
							opcode |= val << 8;
							val = get_reg_param ();
							opcode |= val << 4;
							val = get_reg_param ();
							opcode |= val;
							break;

						case FRM_OP_IMM12:
							val = get_imm_param(pass);
							opcode |= (val >> 1) & 0xFFF;
							break;

						case FRM_OP_NOTHING:
							break;

						default:
							printf ("PANIC: unknown form: '%02X' in line: %d\n", form, line_nr);
							exit (EX_DATAERR);
							break;
					}

					if (pass) {
						if (list)
							printf ("%04X:%04X\t%s\n",pc, opcode, orig_line);
						else
							printf ("%04X:%04X\n",pc, opcode);
					}

					pc += 2;
				}
			}

			if (orig_line)
				free (orig_line);

			line  = strtok_r (NULL, "\n", &save_ptr_line);
		}
	}
	return EX_OK;
}

