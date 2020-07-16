ENTRY(_start)

SECTIONS {
	. = 1M;

	.text BLOCK (4K) : ALIGN (4K) {
		*(.kern_head)
		*(.text)
	}

	kern_end = .;
	__kernel_size = ((kern_end - 1M + 512) / 512);	
}
