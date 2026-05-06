ASM = nasm
SRC_DIR = src
BUILD_DIR = build

.PHONY: all floppy_image bootloader kernel clean always

all: floppy_image

# Final floppy image
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel always
	# Concatenate bootloader + kernel into floppy image
	cat $(BUILD_DIR)/bootloader.bin $(BUILD_DIR)/kernel.bin > $(BUILD_DIR)/main_floppy.img
	# Pad to 1.44MB (2880 sectors * 512 bytes)
	dd if=/dev/zero bs=512 count=$$((2880 - $$(stat -c%s $(BUILD_DIR)/main_floppy.img)/512)) >> $(BUILD_DIR)/main_floppy.img 2>/dev/null || true

# Build bootloader
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

# Build kernel
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel/kernel.asm always
	$(ASM) $(SRC_DIR)/kernel/kernel.asm -f bin -o $(BUILD_DIR)/kernel.bin

# Ensure build folder exists
always:
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)/*