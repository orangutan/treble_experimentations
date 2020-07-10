#!/bin/bash

rom_fp="$(date +%y%m%d)"
originFolder="$(dirname "$0")"
mkdir -p release/$rom_fp/
set -e

if [ "$#" -le 1 ];then
	echo "Usage: $0 <android-8.1> <carbon|lineage|rr> '# of jobs'"
	exit 0
fi
localManifestBranch=$1
rom=$2

if [ "$release" == true ];then
    [ -z "$version" ] && exit 1
    [ ! -f "$originFolder/release/config.ini" ] && exit 1
fi

if [ -z "$USER" ];then
	export USER="$(id -un)"
fi
export LC_ALL=C

if [[ -n "$3" ]];then
	jobs=$3
else
    if [[ $(uname -s) = "Darwin" ]];then
        jobs=$(sysctl -n hw.ncpu)
    elif [[ $(uname -s) = "Linux" ]];then
        jobs=$(nproc)
    fi
fi

#We don't want to replace from AOSP since we'll be applying patches by hand
rm -f .repo/local_manifests/replace.xml
if [ "$rom" == "carbon" ];then
	repo init -u https://github.com/CarbonROM/android -b cr-6.1
elif [ "$rom" == "lineage15" ];then
	repo init -u https://github.com/LineageOS/android.git -b lineage-15.1
elif [ "$rom" == "lineage16" ];then
	repo init -u https://github.com/LineageOS/android.git -b lineage-16.0
elif [ "$rom" == "rr" ];then
	repo init -u https://github.com/ResurrectionRemix/platform_manifest.git -b pie
fi

if false ;then
if [ -d .repo/local_manifests ] ;then
	( cd .repo/local_manifests; git fetch; git reset --hard; git checkout origin/$localManifestBranch)
else
	git clone https://github.com/phhusson/treble_manifest .repo/local_manifests -b $localManifestBranch
fi
fi

if [ -z "$local_patches" ];then
    if [ -d patches ];then
        ( cd patches; git fetch; git reset --hard; git checkout origin/$localManifestBranch)
    else
	rm -fr patches_phh patches_andy
        #git clone https://github.com/phhusson/treble_patches patches_phh -b $localManifestBranch
	git clone https://github.com/AndyCGYan/treble_patches patches_andy -b lineage-16.0
	rm -f patches_andy/platform_system_vold/0005-Also-create-vendor_ce-same-reason-as-vendor_de.patch
    fi
else
    rm -Rf patches
    mkdir patches
    unzip  "$local_patches" -d patches
fi

#We don't want to replace from AOSP since we'll be applying patches by hand
rm -f .repo/local_manifests/replace.xml
rm -f .repo/local_manifests/foss.xml
rm -f .repo/local_manifests/opengapps.xml
cp -f ~/work/fz-files/extras/orangutan.xml/Pie-treble/orangutan.xml .repo/local_manifests/orangutan.xml

repo sync -c -j$jobs --force-sync

cd frameworks/base
#git revert e0a5469cf5a2345fae7e81d16d717d285acd3a6e --no-edit #FODCircleView: defer removal to next re-layout
#git revert 817541a8353014e40fa07a1ee27d9d2f35ea2c16 --no-edit #Initial support for in-display fingerprint sensors
cd ../..

rm -f device/*/sepolicy/common/private/genfs_contexts
(cd device/phh/treble; git clean -fdx; bash generate.sh $rom)

#bash "$(dirname "$0")/apply-patches.sh" patches_phh
bash "$(dirname "$0")/apply-patches.sh" patches_andy

p=$(pwd)

echo "installing individual patches"

#cd frameworks/base
#git am $p/../treble_build_los/0001-Disable-vendor-mismatch-warning.patch
#git am $p/../treble_build_los/0001-Keyguard-Show-shortcuts-by-default.patch
#git am $p/../treble_build_los/0001-core-Add-support-for-MicroG.patch
#cd ../..

#cd lineage-sdk
#git am $p/../treble_build_los/0001-sdk-Invert-per-app-stretch-to-fullscreen.patch
#cd ..

#cd packages/apps/LineageParts
#git am $p/../treble_build_los/0001-LineageParts-Invert-per-app-stretch-to-fullscreen.patch
#cd ../../..

#cd vendor/lineage
#git am $p/../treble_build_los/0001-vendor_lineage-Log-privapp-permissions-whitelist-vio.patch
#cd ../..

#cd build/make
#git am $p/../treble_build_los/0001-Revert-Enable-dyanmic-image-size-for-GSI.patch
#cd ../..

cd device/phh/treble
echo in device p1
#git revert 82b15278bad816632dcaeaed623b569978e9840d --no-edit #Update lineage.mk for LineageOS 16.0
echo in device p2
#git revert df25576594f684ed35610b7cc1db2b72bc1fc4d6 --no-edit #exfat fsck/mkfs selinux label
echo in device p3
#git am $p/../treble_build_los/0001-treble-Add-overlay-lineage.patch
echo in device p3
#git am $p/../treble_build_los/0001-treble-Don-t-specify-config_wallpaperCropperPackage.patch
echo in device p3
#git am $p/../treble_build_los/0001-Increase-system-partition-size-for-arm_ab.patch
echo in device p3
cd ../../..

echo in tinycompress
cd external/tinycompress
git revert fbe2bd5c3d670234c3c92f875986acc148e6d792 --no-edit #tinycompress: Use generated kernel headers
cd ../..

#echo in vendor
#cd vendor/lineage
#git am $p/../treble_build_los/0001-build_soong-Disable-generated_kernel_headers.patch
#cd ../..

echo in cryptfs_hw
cd vendor/qcom/opensource/cryptfs_hw
git revert 6a3fc11bcc95d1abebb60e5d714adf75ece83102 --no-edit #cryptfs_hw: Use generated kernel headers
git am $p/../treble_build_los/0001-Header-hack-to-compile-for-8974.patch
cd ../../../..

sed -i -e 's/BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1610612736/BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648/g' device/phh/treble/phhgsi_arm64_a/BoardConfig.mk

if [ -f vendor/rr/prebuilt/common/Android.mk ];then
    sed -i \
        -e 's/LOCAL_MODULE := Wallpapers/LOCAL_MODULE := WallpapersRR/g' \
        vendor/rr/prebuilt/common/Android.mk
fi

mkdir device/phh/treble/bin
cd $HOME/work/fz-files/main-tree
merge-edits-with-tree.sh . $p
cd $p

#prepare_code_for_pie_build.sh
vi frameworks/base/services/core/java/com/android/server/lights/LightsService.java
#vi frameworks/base/packages/SystemUI/res/values/lineage_config.xml
vi vendor/lineage/build/soong/Android.bp
#vi build/make/target/board/treble_common_32.mk
cp -f ../adb_keys system/core/rootdir/
echo "get new hosts file from ad-away if needed"

if test -f device/phh/treble/lineage.mk
then
	mv device/phh/treble/lineage.mk device/phh/treble/lineage16.mk
fi
. build/envsetup.sh

buildVariant() {
	if false; then
	lunch $1
	make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp installclean
	make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp -j$jobs systemimage
	make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp vndk-test-sepolicy
	xz -c $OUT/system.img -T$jobs > release/$rom_fp/system-${2}.img.xz
	fi
	make-treble.sh -a64 -r a
}

repo manifest -r > release/$rom_fp/manifest.xml
#buildVariant treble_arm64_avN-userdebug arm64-aonly-vanilla-nosu
#buildVariant treble_arm64_agS-userdebug arm64-aonly-gapps-su
#buildVariant treble_arm64_bvN-userdebug arm64-ab-vanilla-nosu
#buildVariant treble_arm64_bgS-userdebug arm64-ab-gapps-su
buildVariant treble_arm_avN-userdebug arm-aonly-vanilla-nosu
#buildVariant treble_arm_aoS-userdebug arm-aonly-gapps
#buildVariant treble_a64_avN-userdebug arm32_binder64-aonly-vanilla-nosu
#buildVariant treble_a64_agS-userdebug arm32_binder64-aonly-gapps-su

if [ "$release" == true ];then
    (
        rm -Rf venv
        pip install virtualenv
        export PATH=$PATH:~/.local/bin/
        virtualenv -p /usr/bin/python3 venv
        source venv/bin/activate
        pip install -r $originFolder/release/requirements.txt

        python $originFolder/release/push.py "${rom^}" "$version" release/$rom_fp/
        rm -Rf venv
    )
fi
