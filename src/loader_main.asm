
; Copyright (c) 2019, k4m1 <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license agreement.
;
; This code is responsible of loading the kernel from boot device, and
; then relocating it to 0x100000.
;

%include "src/consoles.asm"
%include "src/bioscall.asm"
%include "src/mm.asm"

current_sector:
	db 	0

loader_main:
	push	bp
	mov	bp, sp

	; sector offset, so we don't search for kernel in our bootloader
	mov 	byte [current_sector], SECTOR_CNT

	; We start by finding the kernel header with basic
	; disk read, then proceed with extended disk-read.
	mov 	cl, byte [current_sector]
	call	load_kern_hdr
	call	parse_kern_hdr
	call	load_kernel

	; prepare kernel entry address to ebx
	mov	edi, 0x100000
	add	di, word [kern_offset]
	add	edi, 4
	add	edi, 4
	mov 	ebx, edi

	; enable 32-bit protected mode with simple gdt, disable interrupts
	cli
	lgdt 	[gdt32]
	mov 	eax, cr0
	or 	al, 1
	mov 	cr0, eax
	jmp 	0x08:.pm
.pm:
	mov 	ax, 0x10
	mov 	es, ax
	mov 	fs, ax
	mov 	ds, ax
	mov 	gs, ax
	mov 	ss, ax
	jmp 	[ebx]
	cli
	hlt

; Counter for remaining kernel sectors
kern_sectors_left:
	dd	0x00000000

; Offset to beginning of kernel header
kern_offset:
	dw	0x0000

; address where we store our kernel
current_target_addr:
	dd	0x100000

; =================================================================== ;
; Function to handle actual kernel load process.                      ;
; =================================================================== ;
load_kernel:
	push	bp
	mov	bp, sp

.load_kernel_start:
	cmp	dword [kern_sectors_left], 0x28
	jle	.final_iteration

	; Load 0x28 sectors from disk
	mov	word [DAP.sector_count], 0x28
	jmp	.do_read

.final_iteration:
	; Load remaining needed sectors from disk
	mov	ax, word [kern_sectors_left]
	mov	word [DAP.sector_count], ax

.do_read:
	; do actual disk read with extended disk read (0x13, al=0x42)
	mov	dword [DAP.transfer_buffer], 0x2000
	mov	dl, byte [boot_device]
	mov	al, 0x42
	mov	si, DAP
	call	do_bios_call_13h
	jc	.fail

	mov	si, .msg_loaded_chunk
	call	write_serial

	; relocate sectors to 0x100000 onwards
	; We could also relocate less than 0x28 sectors on last read but
	; it's less logic, easier code when it's like this.
	; Someday when I have motivation to do so, I'll optimize these. maybe
	mov	ecx, ((0x28 * 512) / 4)

	; I'd much more prefer movsd here, but that'd mean we'd need to
	; either constantly swap between 32 and 16 bit mode, as atleast on
	; qemu movsN does use ds:si, es:di on 32-bit unreal mode too. This
	; practically means we could only load to address 0xF:FFFF at most,
	; which is still in MMI/O space (usually MOBO BIOS ROM to be exact).
	; swap to 32-bit mode would allow us to use esi, edi, but that'd mean
	; we'd need to load our whole kernel to low memory first,
	; and find enough space to somehow fit it here.. 
	; that'd limit us a *LOT*.
	;
	; One way would be that constant swap between 16 and 32 bit mode,
	; but that's not something I want to do.
	;
	.relocation_loop_start:
		mov	edx, dword [current_target_addr]
		mov	ebx, 0x2000
	.relocation_loop:
		mov	eax, dword [ebx]
		mov	dword [edx], eax 
		add 	ebx, 4
		add 	edx, 4
		loop	.relocation_loop

	; adjust target address
	inc	edx
	mov	dword [current_target_addr], edx

	; adjust remaining sector count
	mov	ax, word [DAP.sector_count]
	sub	dword [kern_sectors_left], eax
	cmp	dword [kern_sectors_left], 0
	jne	.load_kernel_start

	; we're done reading the kernel !
	mov	sp, bp
	pop	bp
	ret

.fail:
	mov	esi, .msg_kern_load_failed
	call	panic
.msg_kern_load_failed:
	db "KERNEL LOAD FAILED", 0x0A, 0x0D, 0
.msg_loaded_chunk:
	db "Loaded ~ 20Kb chunk from disk.", 0x0A, 0x0D, 0

; =================================================================== ;
; Function to get kernel header.                                      ;
; We'll load kernel header to static address 0x2000                   ;
;                                                                     ;
; CL = sector to load from                                            ;
; =================================================================== ;
load_kern_hdr:
	push	bp
	mov	bp, sp

	; do disk read (0x13, al=10/ah=0x02)
	mov	bx, 0x2000
	mov	ch, 0x00
	mov 	cl, byte [current_sector]
	add	cl, 4
	xor	dh, dh
	mov	dl, byte [boot_device]

	.read_start:
		mov	di, 5
	.read:
		mov	ah, 0x02
		mov	al, 10
		call	do_bios_call_13h
		jnc	.read_done
		dec	di
		test	di, di
		jnz	.read
		mov	si, .msg_disk_read_fail
		call	panic
	.read_done:
		mov	sp, bp
		pop	bp
		ret
	.msg_disk_read_fail:
		db	"DISK READ FAILED", 0x0

; =================================================================== ;
; Function to parse kernel header & populate DAP accordingly. See     ;
; section below.                                                      ;
; =================================================================== ;
parse_kern_hdr:
	push 	bp
	mov 	bp, sp

	mov 	cx, 63
	push 	cx
	mov	si, 0x2000
	.loop:
		cmp	dword [si], 'nyan'
		jne	.invalid_hdr

	sub	si, 0x2000
	mov	word [kern_offset], si
	add	si, 0x2000
	push	si
	mov	si, .msg_kernel_found
	call	write_serial
	pop	si
	mov 	ax, kern_offset

	add	si, 4
	mov	eax, dword [si]
	mov	dword [kern_sectors_left], eax
	pop 	cx

	mov 	sp, bp
	pop 	bp
	ret

.invalid_hdr:
	inc	si
	cmp	si, 0x4000
	jl	.loop
.fail:
	pop 	cx
	dec 	cx
	jz 	.end_of_retries
	push 	cx
	mov 	cl, byte [current_sector]
	inc 	cl
	mov 	byte [current_sector], cl
	call 	load_kern_hdr
	jmp 	.loop

.end_of_retries:
	mov	si, .msg_invalid_hdr
	call	panic

.msg_invalid_hdr:
	db	"INVALID KERNEL HEADER, CORRUPTED DISK?", 0x0
.msg_kernel_found:
	db	"Found kernel"
	db	0x0A, 0x0D, 0

; =================================================================== ;
; Disk address packet format:                                         ;
;                                                                     ;
; Offset | Size | Desc                                                ;
;      0 |    1 | Packet size                                         ;
;      1 |    1 | Zero                                                ;
;      2 |    2 | Sectors to read/write                               ;
;      4 |    4 | transfer-buffer 0xffff:0xffff                       ;
;      8 |    4 | lower 32-bits of 48-bit starting LBA                ;
;     12 |    4 | upper 32-bits of 48-bit starting LBAs               ;
; =================================================================== ;
DAP:
	.size:
		db	0x10
	.zero:
		db	0x00
	.sector_count:
		dw	0x0000
	.transfer_buffer:
		dd	0x00000000
	.lower_lba:
		dd	0x00000000
	.higher_lba:
		dd	0x00000000

sectors equ SECTOR_CNT * 512 + 512
times sectors db 0xff
