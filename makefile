all: build_floopy
build_floopy: build/loader.bin\
	 		  build/boot.bin
	sh writeimage.sh
	sudo mount build/boot.img /mnt/my_os/ -t vfat -o loop
	sudo cp build/loader.bin /mnt/my_os/
	sudo umount /mnt/my_os/

build/loader.bin: src/bootloader/loader.asm
	nasm src/bootloader/loader.asm  -o build/loader.bin
build/boot.bin : src/bootloader/boot.asm
	nasm src/bootloader/boot.asm -o build/boot.bin
clean:
	rm build/*.bin
