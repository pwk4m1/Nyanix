
; Copyright (C) 2019, k4m1  <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license agreement.

%ifndef GDT
%define GDT

gdt:
	dw	.end - .start- 1
	dd	.start
.start:
	dq	0
	dw	0xffff
	dw	0
	db	0
	db	10010010b
	db	11001111b
	db	0
.end:

gdt32:
	dw 	.end - .start - 1
	dd 	.start
	.start:
		dd 	0
		dd 	0
	.code:
		dw 	0xffff
		dw 	0
		db 	0
		db 	0x9a
		db 	0xcf
		db 	0x00
	.data:
		dw 	0xffff
		dw 	0x0000
		db 	0x00
		db 	0x92
		db 	0xcf
		db 	0x00
	.end:
%endif

