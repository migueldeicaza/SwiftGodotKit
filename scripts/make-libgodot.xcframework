#!/bin/bash
set -e
if test ! -e make-libgodot.xcframework; then
    echo this script needs to be executed from the SwiftGodotKit/scripts directory
    exit 1
fi
if test x$3 = x; then
    echo usage is: make-libgodot.xcframework SwiftGodotDIR libgodotDIR OUTPUT_DIR [simulator]
    echo the optional flag 'simulator' builds the simulator, but Godot does not currently work with it
    exit 1
fi
SWIFTGODOT_SOURCE_DIR=$1
LIBGODOT_SOURCE_DIR=$2
OUTPUT_DIR=$3
compile_sim=false
if test x$4 = xsimulator; then
    compile_sim=true
fi

# Remote build stuff
intel=macpro
arm=studio.local
arm2=localhost
dir=$(cd $LIBGODOT_SOURCE_DIR; pwd)

# The hash for the godot that has been modified to be embeddable
# lives in libgodot_project/godot in migerans tree
hash=119eb521dc3507405710a45e926062537524176e
target_kind=template_debug
build_base="scons target=$target_kind library_type=shared_library debug_symbols=yes"

build() {
    host=$1
    build=$2
    file=$3
    echo "starting build on $host"
    ssh -A $host "cd $dir && git fetch && git reset --hard $hash && rm -rf bin && $build"
    scp $host:$dir/bin/$file $file
}

arm_dylib=libgodot.macos.$target_kind.arm64.dylib
intel_dylib=libgodot.macos.$target_kind.dev.x86_64.dylib
ios_lib=libgodot.ios.$target_kind.dev.arm64.a
iossim_lib=libgodot.ios.$target_kind.dev.arm64.simulator.a
iossimx86_lib=libgodot.ios.$target_kind.dev.x86_64.simulator.a

if test x$SKIP = x; then
  # Build the Mac payloads
  build $intel "/usr/local/bin/$build_base platform=macos dev_build=yes" $intel_dylib
  build $arm "/opt/homebrew/bin/$build_base platform=macos vulkan_sdk_path=~/MoltenVK/" $arm_dylib

  # Build the iOS payload
  build $arm "/opt/homebrew/bin/$build_base platform=ios vulkan_sdk_path=~/MoltenVK/ dev_build=yes" $ios_lib

  # Godot does not currently work on simulator, need to figure out what to do.
  if $compile_sim; then
    build $arm "/opt/homebrew/bin/$build_base platform=ios ios_simulator=yes vulkan_sdk_path=~/MoltenVK/ dev_build=yes" $iossim_lib
    build $arm "/opt/homebrew/bin/$build_base platform=ios ios_simulator=yes arch=x86_64 vulkan_sdk_path=~/MoltenVK/ dev_build=yes" $iossimx86_lib
  fi
fi

# Now make the xcframework
rm -rf $OUTPUT_DIR/libgodot.xcframework
rm -rf $OUTPUT_DIR/libgodot.xcframework.zip
tmp=/tmp/dir-$$
mkdir $tmp
cp $SWIFTGODOT_SOURCE_DIR/Sources/GDExtension/include/gdextension_interface.h $tmp/gdextension_interface.h
cp $LIBGODOT_SOURCE_DIR/core/extension/libgodot.h $tmp/libgodot.h
cat > $tmp/module.modulemap << EOF
module libgodot {
    header "libgodot.h"
    export *
}
EOF

rm -rf $OUTPUT_DIR/mac/libgodot.xcframework
rm -rf $OUTPUT_DIR/ios/libgodot.xcframework

# Old style, when we had a working simulator:
#    install_name_tool -id @rpath/libgodot.dylib $arm_dylib
#    install_name_tool -id @rpath/libgodot.dylib $intel_dylib
#    lipo -create -output libgodot.dylib -arch arm64 $arm_dylib -arch x86_64 $intel_dylib
#    lipo -create -output libgodotSim.a -arch arm64 $iossim_lib -arch x86_64 $iossimx86_lib
#    xcodebuild -create-xcframework -library libgodot.dylib -headers $tmp -output libgodot.xcframework
#    xcodebuild -create-xcframework -library libgodotSim.a -headers $tmp -output libgodot.xcframework

# Slowly updating this one, the old one lacks the Mac for example
install_name_tool -id @rpath/libgodot.dylib $arm_dylib
install_name_tool -id @rpath/libgodot.dylib $intel_dylib
lipo -create -output libgodot.dylib -arch arm64 $arm_dylib -arch x86_64 $intel_dylib

if $compile_sim; then
    lipo -create -output libgodotSim.a -arch arm64 $iossim_lib
fi

xcodebuild -create-xcframework -library libgodot.dylib -headers $tmp -output $OUTPUT_DIR/mac/libgodot.xcframework
xcodebuild -create-xcframework -library $ios_lib -headers $tmp -output $OUTPUT_DIR/ios/libgodot.xcframework

# Godot does not work on simulator, so do not bother for now:
if $compile_sim; then
    xcodebuild -create-xcframework -library libgodotSim.a -headers $tmp -output $OUTPUT_DIR/ios/libgodot.xcframework
fi

(cd $OUTPUT_DIR/mac; ditto -c -k --sequesterRsrc --keepParent libgodot.xcframework ../mac_libgodot.xcframework.zip)
(cd $OUTPUT_DIR/ios; ditto -c -k --sequesterRsrc --keepParent libgodot.xcframework ../ios_libgodot.xcframework.zip)

checksum_mac=`swift package compute-checksum $OUTPUT_DIR/mac/libgodot.xcframework.zip`
checksum_ios=`swift package compute-checksum $OUTPUT_DIR/ios/libgodot.xcframework.zip`
    
echo Checksums:
echo    Mac: $checksum_mac
echo    iOS: $checksum_ios

#rm -rf /tmp/dir-$$
exit 0


