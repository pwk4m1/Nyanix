
; Copyright (c) 2019, k4m1 <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license agreement.
;
; This code is responsible of loading the kernel from boot device, and
; then relocating it to 0x100000.
;

%include "src/consoles.asm"
%include "src/bioscall.asm"

USED_SECTORS equ (SECTOR_CNT + 1)

kernel_sectors_left:
	dd 	0

kernel_entry_offset:
	dw 	0

current_target_addr:
	dd 	0x100000
	
current_sector:
	db 	0

loader_main:
	push 	bp
	mov 	bp, sp

	; sector offset on disk is set to be amount of sectors this bootloader
	; uses, so that we don't waste time looking for kernel header from
	; within the bootloader.
	mov 	byte [current_sector], USED_SECTORS

	; normal disk read is used to first find the kernel header, only
	; then after that we'll make use of extended disk read.
	;
	xor 	ecx, ecx
	mov 	cl, 10
	.kernel_load_loop:
		push 	cx
		call 	load_sector
		call 	parse_kernel_header
		jc 	.kernel_found
		add 	byte [current_sector], 1
		pop 	cx
		loop 	.kernel_load_loop

	; kernel was not found, notify user and halt
	mov 	si, msg_no_kernel
	call 	panic

.kernel_found:
	; load kernel expects 3 values to be set, all these are
	; set by parse_kernel_header.
	;  - kernel_sectors_left: size of kernel
	;  - kernel_entry_offset: offset to kernel entry incase there's
	; 			junk between bootloader & kernel
	;  - current_target_addr: address where to read disk to, this
	; 			starts at 0x100000
	;
	call 	load_kernel

	; prepare kernel entry address to EBX & setup 32-bit protected
	; mode with simple GDT & disabled interrupts
	mov 	ebx, 0x100000
	add 	ebx, 8  	; sizeof kernel header

	cli
	lgdt 	[gdt32]
	mov 	eax, cr0
	or 	al, 1
	mov 	cr0, eax
	jmp 	0x08:.protected_mode_entry
	.protected_mode_entry:
		mov 	ax, 0x10
		mov 	es, ax
		mov 	fs, ax
		mov 	ds, ax
		mov 	gs, ax
		mov 	ss, ax
		jmp 	[ebx]
	
; =================================================================== ;
; End of main "logic", rest is helper functions 'n stuff              ;
; =================================================================== ;

; This function loads single sector from disk to memory, sector to read
; is choosen by [current_sector]
;
load_sector:
	push 	bp
	mov 	bp, sp
	pusha

	; do disk read (int 0x13, ax = 0x0210), target = 0x2000
	mov 	bx, 0x2000
	xor 	cx, cx
	mov 	cl, byte [current_sector]
	xor 	dx, dx
	mov 	dl, byte [boot_device] ; this we get from code at mbr.asm

	.read_start:
		mov 	di, 5
	.read:
		mov 	ax, 0x0210
		call 	do_bios_call_13h
		jnc 	.read_done
		dec 	di
		test 	di, di
		jnz 	.read
		mov 	si, msg_disk_read_fail
		call 	panic
	.read_done:
		popa
		mov 	sp, bp
		pop 	bp
		ret

; This function parses kernel header, setting DAP and other
; variables accordingly.
;
parse_kernel_header:
	push 	bp
	mov 	bp, sp
	clc 		; clear carry flag, we'll set it if kernel is found
	pusha

	mov 	si, 0x2000
	.search:
		cmp 	dword [si], 'nyan'
		je 	.found_hdr
		inc 	si
		cmp 	si, 0x2200 ; sector size = 0x200
		jl 	.search
	
	; kernel was not found :(
	popa
.ret:
	mov 	sp, bp
	pop 	bp
	ret

.found_hdr:
	; kernel was found :)
	mov 	eax, dword [si+4]
	mov 	dword [kernel_sectors_left], eax
	sub 	si, 0x2000
	mov 	word [kernel_entry_offset], si
	mov 	si, msg_kernel_found
	call 	write_serial
	popa 
	stc
	jmp 	.ret


; load_kernel function is basicly a loop going through
; extended disk read untill we've loaded the whole kernel.
load_kernel:
	push 	bp
	mov 	bp, sp
	pusha

.start:
	; reads happen 0x28 sectors at time MAX.
	cmp 	dword [kernel_sectors_left], 0x28
	jle 	.final_iteration

	mov 	word [DAP.sector_count], 0x28
	jmp 	.do_read

.final_iteration:
	mov 	ax, word [kernel_sectors_left]
	mov 	word [DAP.sector_count], ax

.do_read:
	; extended disk read: int=0x13, al=0x42
	mov 	dword [DAP.transfer_buffer], 0x2000
	mov 	dl, byte [boot_device]
	mov 	al, 0x42
	mov 	si, DAP
	call 	do_bios_call_13h
	jc 	.fail

	mov 	si, msg_loaded_block
	call 	write_serial

	; relocate sectors to 0x100000 onwards
	; reloaction adjusts target address for us
	call 	kernel_relocate

	; adjust remaining sector count
	xor 	eax, eax
	mov 	ax, word [DAP.sector_count]
	sub 	dword [kernel_sectors_left], eax
	cmp 	dword [kernel_sectors_left], 0
	jne 	.start

	; kernel has been loaded
	popa
	mov 	sp, bp
	pop 	bp
	ret

.fail:
	mov 	si, msg_disk_read_fail
	call 	panic


kernel_relocate:
	push 	bp
	mov 	bp, sp
	pusha

        ; relocate sectors to 0x100000 onwards
        ; We could also relocate less than 0x28 sectors on last read but
	; it's less logic, easier code when it's like this,
	; someday, and that day might never come, but someday I will optimize
	; this and make it better
	mov 	ecx, ((0x28 * 512) / 4) ; amount of dwords to reloacte

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
		mov 	edx, dword [current_target_addr]
		mov 	ebx, 0x2000
	.loop:
		mov 	eax, dword [ebx]
		mov 	dword [edx], eax
		add 	ebx, 4
		add 	edx, 4
		loop 	.loop
	
	; adjust target address
	inc 	edx
	mov 	dword [current_target_addr], edx

	popa
	mov 	sp, bp
	pop 	bp
	ret

; Some pretty messages to print
msg_no_kernel:
	db "Bootloader did not find kernel from disk :(", 0x0

msg_disk_read_fail:
	db "Failed to read disk, firmware bug?", 0x0

msg_kernel_found:
	db "Found kernel, loading...", 0x0A, 0x0D, 0

msg_loaded_block:
	db "Loaded up to 20kb of kernel/os from disk...", 0x0A, 0x0D, 0

; =================================================================== ;
; Disk Address Packet format:                                         ;
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
		db 	0x10
	.zero:
		db 	0x00
	.sector_count:
		dw 	0x0000
	.transfer_buffer:
		dd 	0x00000000
	.lower_lba:
		dd 	0x00000000
	.higher_lba:
		dd 	0x00000000

times 	(USED_SECTORS * 512) - ($ - $$) db 0

