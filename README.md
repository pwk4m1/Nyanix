# Nyanix
Simple bootloader project. Aiming for clean code.

Usage:
	Your kernel must be at least 5 kilobytes large, and be 512-byte
	aligned in total size. Kernel header needs to be set withing first
	5 kilobytes in image. This should still allow plenty enough space
	for other headers such as ELF or PE.

	Kernel image must be located immediately after bootloader on bootdisk.
	Refer to KERNEL_HEADER.txt to see how to setup the header used by
	the bootloader.

	Bootloader initializes serial port 0x3F7 and A20 gate, and
	enables 32-bit protected mode with fairly simple GDT.
	Kernel is loaded to 0x100000 with CS 0x08, other segments 0x10.

Example kernel formating:

```nasm
	; kernel.asm
	; assemble: nasm -felf32 -o kernel.o kernel.asm
	bits 	32
	db 	"nyan"
	dd 	((kernel_end - _start + 512) / 512)

	global  _start
	_start:
		mov 	eax, 0x0badc0de
		cli
		hlt
	kernel_end:
		times 	512 db 0x41
```

```linker
	/* linker.ld */
	ENTRY(_start)
	SECTIONS {
		. = 0x100000;
		.header BLOCK (1) : ALIGN (1) {
			*(.header)
		}
		.text BLOCK (1) : ALIGN (1) {
			*(.text)
		}
		/* Other sections */
	}
```

```shell
	# Build script
	nasm -felf32 -o kernel.o kernel.asm
	ld --script=linker.ld -o kernel.elf kernel.o
	dd if=kernel.elf bs=1 >> nyanix.bin
```

Contribution:
	General code optimization would be welcome, code as is might be 
	hopefully pretty to read but it has quite a few slow functions.
 	New features, drivers etc. is always welcome too.

