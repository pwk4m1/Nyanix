
as=nasm
flags=-fbin

all: check clean install

check:
	@command -v $(as)>/dev/null 2>&1 || { \
		echo "Missing $(as)!"; \
		exit 1; \
	}

clean:
	rm -rf nyanix

install:
	$(as) $(asflags) -o nyanix src/mbr.asm

install-debug:
	$(as) $(asflags) -dDEBUG -o nyanix src/mbr.asm

qemu:
	dd if=test_kernel/test >> nyanix
	qemu-system-x86_64 -serial stdio -d guest_errors nyanix

