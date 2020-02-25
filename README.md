# Nyanix
Simple bootloader project. Aiming for clean code.

Usage:
	At very beginnig of your kernel, there *must* be header as defined
	in KERNEL_HEADER.txt file. This header tells the bootloader how
	large your kernel and/or OS is. Refer to test_kernel/test.asm to
	see how-to set up the header.

	Your kernel may be in whatever format you wish, however, it must
	not have any other header before the KERNEL_HEADER.

	After the header, the bootloader assumes to be kernel entry point.
	If you wish to have some sort of data-section there, your kernel
	must be formated in following way:

		section .text
		kernel_header
		jump to code entry
		section .whatever
		...

That's all, I guess. Do enjoy.


Oh one more thing, kernel is loaded to address: 0x000100ee 

