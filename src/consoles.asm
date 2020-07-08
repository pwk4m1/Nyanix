
; Copyright (C) 2019, k4m1  <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license text

%ifndef CONSOLE_ASM
%define CONSOLE_ASM

; Both panic, and write_serial require one argument, which is
; a pointer to null-terminated string at esi

write_serial:
	mov	dx, 0x3f8
	lodsb
	out	dx, al
	test	al, al
	jnz	write_serial
	ret

panic:
	push 	si
	mov	edi, 0xB8000
	.loop:
		lodsb
		mov	ah, 0x4F
		mov	word [edi], ax
		add	edi, 2
		test	al, al
		jnz	.loop
	pop 	si
	.serial_loop:
		mov 	dx, 0x3f8
		lodsb
		test 	al, al
		jz 	.hang
		out 	dx, al
		jmp 	.serial_loop
	.hang:
		cli
		hlt
		jmp	.hang

%endif ; CONSOLE_ASM


