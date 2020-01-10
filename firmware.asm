;
; Dwarf - A minimalist 16-bit RISC CPU
;
; firmware.asm: Blinky demo application
;

.LEDADDR		0x8000

.BIT0			0

@0x0
	ori	r5,	0x01
	ldu	r1,	LEDADDR
	ori	r1,	LEDADDR
	ldu	r2,	0xAA00
	ori	r2,	0xAA
	wrm	r1,	r2
	ldu	r5,	0x0000
	ori	r5,	0x01
	ldu	r11,	0x0000
	ori	r11,	0x0F
	wrm	r1,	r11
	ldu	r12,	0x0000
	ori	r12,	0xF0
	wrm	r1,	r12
	ldu	r6,	0x0000
	ori	r6,	0x55
	brl	writeled
main:
	ror	r2,	r5,	r2
	sks	r2,	BIT0
	mov	r11,	r6
	skc	r2,	BIT0
	mov	r12,	r6
	brl	writeled
	brl	main

@0x7FA
writeled:
	wrm	r1,	r6
	brr	r15

