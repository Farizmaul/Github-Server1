#!/bin/bash

MAINPATH=$GITHUB_WORKSPACE # change if you want
GCC32=$MAINPATH/gcc-arm/bin/
GCC64=$MAINPATH/gcc-arm64/bin/
ANYKERNEL3_DIR=$MAINPATH/AnyKernel3/
TANGGAL=$(TZ=Asia/Jakarta date "+%Y%m%d-%H%M")
COMMIT=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DTBO=0
KERNEL_DEFCONFIG=vendor/alioth_user_defconfig
FINAL_KERNEL_ZIP=NightQueen-Alioth-$TANGGAL.zip

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="Github-server"
export KBUILD_BUILD_USER="RicoAyuba"
export COMPILER_STRING=$("$GCC64"aarch64-elf-gcc --version | head -n 1)
export LLD=$("$GCC64"aarch64-elf-ld.lld --version | head -n 1)
export PATH=$GCC64:$GCC32:/usr/bin:$PATH
export IMGPATH="$ANYKERNEL3_DIR/Image"
export DTBPATH="$ANYKERNEL3_DIR/dtb"
export DTBOPATH="$ANYKERNEL3_DIR/dtbo.img"
export DISTRO=$(source /etc/os-release && echo "${NAME}")

# Check kernel version
KERVER=$(make kernelversion)
if [ $BUILD_DTBO = 1 ]
	then
		git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
fi

# Speed up build process
MAKE="./makeparallel"
BUILD_START=$(date +"%s")

# Post to CI channel
curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="start building the kernel from the HEAD commit $COMMIT
OS		: <code>$DISTRO</code>
Branch		: <code>$(git rev-parse --abbrev-ref HEAD)</code>
Compiler Used	: <code>$COMPILER_STRING</code>
LD Version Used :<code>$LLD</code>" -d chat_id=${chat_id} -d parse_mode=HTML

args="ARCH=arm64 \
CROSS_COMPILE_ARM32=arm-eabi- \
CROSS_COMPILE=aarch64-elf- \
AR=aarch64-elf-ar \
OBJDUMP=aarch64-elf-objdump \
STRIP=aarch64-elf-strip \
NM=aarch64-elf-nm \
OBJCOPY=aarch64-elf-objcopy \
LD=aarch64-elf-ld.lld"

mkdir out
make -j$(nproc --all) O=out $args $KERNEL_DEFCONFIG
scripts/config --file out/.config \
        -d LD_DEAD_CODE_DATA_ELIMINATION
cd out || exit
make -j$(nproc --all) O=out $args olddefconfig
cd ../ || exit
make -j$(nproc --all) O=out $args V=$VERBOSE 2>&1 | tee error.log

END=$(date +"%s")
DIFF=$((END - BUILD_START))
if [ -f $(pwd)/out/arch/arm64/boot/Image ]
        then
                curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="Build compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds" -d chat_id=${chat_id} -d parse_mode=HTML
                find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
                find $DTS -name 'Image' -exec cat {} + > $IMGPATH
                find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH
                cd $ANYKERNEL3_DIR/
                zip -r9 $FINAL_KERNEL_ZIP * -x README $FINAL_KERNEL_ZIP
                curl -F chat_id="${chat_id}"  \
		-F document=@"$FINAL_KERNEL_ZIP" \
		-F caption="" https://api.telegram.org/bot${token}/sendDocument
        else
                curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="Build failed !" -d chat_id=${chat_id} -d parse_mode=HTML
                curl -F chat_id="${chat_id}"  \
                     -F document=@"error.log" \
                     https://api.telegram.org/bot${token}/sendDocument
fi

echo "**** FINISH.. ****"
