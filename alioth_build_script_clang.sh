#!/bin/bash

MAINPATH=$GITHUB_WORKSPACE # change if you want
GCC32=$MAINPATH/gcc32/bin/
GCC64=$MAINPATH/gcc64/bin/
CLANG=$MAINPATH/clang/bin/
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
export KBUILD_COMPILER_STRING=$("$CLANG"clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export LLD=$("$CLANG"ld.lld --version | head -n 1)
export PATH="$CLANG:$PATH"
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
echo "***********************************************"
echo "          BUILDING KERNEL          "
echo "***********************************************"

# Post to CI channel
curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="start building NightQueen kernel from the HEAD commit $COMMIT
OS		: <code>$DISTRO</code>
Branch		: <code>$(git rev-parse --abbrev-ref HEAD)</code>
Compiler Used	: <code>$KBUILD_COMPILER_STRING</code>
LD Version Used : <code>$LLD</code>" -d chat_id=${chat_id} -d parse_mode=HTML

args="ARCH=arm64 \
CC="$CLANG"clang \
LD=ld.lld \
LLVM=1 \
LLVM_IAS=1 \
AR=llvm-ar \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE="$GCC64"aarch64-linux-android- \
CROSS_COMPILE_ARM32="$GCC32"arm-linux-androideabi-"

mkdir out
make O=out $args $KERNEL_DEFCONFIG
cd out || exit
make -j$(nproc --all) $args olddefconfig
cd ../ || exit
make -j$(nproc --all) O=out $args V=$VERBOSE 2>&1 | tee error.log

END=$(date +"%s")
DIFF=$((END - BUILD_START))

if [ -f $(pwd)/out/arch/arm64/boot/Image ]
        then
                find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
                find $DTS -name 'Image' -exec cat {} + > $IMGPATH
                find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH
                cd $ANYKERNEL3_DIR/
                zip -r9 $FINAL_KERNEL_ZIP * -x README $FINAL_KERNEL_ZIP
                curl -F chat_id="${chat_id}"  \
                -F document=@"$FINAL_KERNEL_ZIP" \
                -F caption="<i>Build compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</i> v$KERVER" \
                https://api.telegram.org/bot${token}/sendDocument
        else
                curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="Build failed !" -d chat_id=${chat_id} -d parse_mode=HTML
                curl -F chat_id="${chat_id}"  \
                     -F document=@"error.log" \
                     https://api.telegram.org/bot${token}/sendDocument
fi

echo "**** FINISH.. ****"
