/*
 * Dwarf - A minimalist 16-bit RISC CPU
 *
 * mkramimg.c: Initializes the FPGA's block RAM's initialization vectors which serves as the
 *             CPU's internal RAM with the binary code to be executed by the CPU
 *
 * Implemented 2017.11.08 by Helmut Sipos <helmut.sipos@gmail.com>
 *
 * This program is based on ram_image.c, implemented 11/7/05 by Steve Rhoads (rhoadss@yahoo.com)
 * as part of the Plasma CPU, and therefore uses the same copyright notice:
 *
 * COPYRIGHT: Software placed into the public domain by the author.
 *            Software 'as is' without warranty. Author liable for nothing.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>

#define BUF_SIZE (1024*1024)

int
main (int argc, char **argv)
{
	FILE *file;
	int i, j, index, size, count;
	char *buf, *ptr, *ptr_list[64*4], text[80];
	unsigned *code;
	unsigned *address;

	/* validate parameters */
	if(argc < 3) {
		printf("Usage: mkramimg <target.vhd> <code.txt> \n");
		return EX_USAGE;
	}

	/* allocate the necessary buffer */
	buf = (char*)malloc(BUF_SIZE);
	code = (unsigned *)malloc(BUF_SIZE);
	address = (unsigned *)malloc(BUF_SIZE);

	/* Read target.vhd */
	if ((file = fopen(argv[1], "rb")) == NULL) {
		printf("Can't open %s!\n", argv[1]);
		return EX_NOINPUT;
	}
	size = fread(buf, 1, BUF_SIZE, file);
	fclose(file);

	/* Read code.txt */
	if ((file = fopen(argv[2], "r")) == NULL) {
		printf("Can't open %s!\n", argv[2]);
		return EX_NOINPUT;
	}

	/* Supports a maximum of 1024 instructions a 16 bits */
	for (count = 0; count < 1024; ++count) {
		if(feof(file))
			break;
		fscanf(file, "%x:%x", &address[count], &code[count]);
	}
	fclose(file);

	/* Find 'INIT_00 => X"' */
	ptr = buf;
	for(i = 0; i < 64; ++i) {
		sprintf(text, "INIT_%2.2X => X\"", i % 64);

		if((ptr = strstr(ptr, text)) == NULL) {
			printf("ERROR:  Can't find '%s' in file!\n", text);
			return EX_DATAERR;
		}
		ptr_list[i] = ptr + strlen(text);
	}

	/* Modify VHDL source code - RAM initialization vectors */
	j = 60;
	index = 0;
	int k;
	for(i = 0; i < count; i++) {
		sprintf(text, "%4.4x", code[i]);

		if (address[i] % 2) {
			printf ("\nERROR: Address alignment error @ %4.4x\n"
				,address[i]);

			return EX_DATAERR;
		}

		index = address[i] / 32;
		j = 60 - (address[i] % 32) * 2;

		for (k = 0; k < 4; k++)
			ptr_list[index][j++] = text[k];
	}

	/* Write modified target.vhd back to disk */
	if ((file = fopen(argv[1], "wb")) == NULL) {
		printf("Can't write %s!\n", argv[3]);
		return EX_CANTCREAT;
	}
	fwrite(buf, 1, size, file);
	fclose(file);

	/* Free buffers */
	free(buf);
	free(code);
	free(address);

	return EX_OK;
}
