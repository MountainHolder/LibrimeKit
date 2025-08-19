#!/bin/bash
set -ex

RIME_ROOT="$(cd "$(dirname "$0")"; pwd)"
echo "RIME_ROOT = ${RIME_ROOT}"

cd ${RIME_ROOT}/librime
git submodule update --init

# Apply patch if not applied
if [[ ! -f ${RIME_ROOT}/librime.patch.apply ]]; then
    touch ${RIME_ROOT}/librime.patch.apply
    git apply ${RIME_ROOT}/librime.patch >/dev/null 2>&1
fi

# Install lua plugin
rm -rf ${RIME_ROOT}/librime/plugins/lua
${RIME_ROOT}/librime/install-plugins.sh imfuxiao/librime-lua@main

# Update rime_api.cc for lua module dependencies
sed -i "" '/#if RIME_BUILD_SHARED_LIBS/,/#endif/c\
#if RIME_BUILD_SHARED_LIBS\
#define rime_declare_module_dependencies()\
#else\
extern void rime_require_module_core();\
extern void rime_require_module_dict();\
extern void rime_require_module_gears();\
extern void rime_require_module_levers();\
extern void rime_require_module_lua();\
static void rime_declare_module_dependencies() {\
  rime_require_module_core();\
  rime_require_module_dict();\
  rime_require_module_gears();\
  rime_require_module_levers();\
  rime_require_module_lua();\
}\
#endif\
' ${RIME_ROOT}/librime/src/rime_api.cc

# Build librime dependencies
if [[ ! -d ${RIME_ROOT}/.boost ]]; then
  mkdir ${RIME_ROOT}/.boost
  cp -R ${RIME_ROOT}/boost-iosx/dest ${RIME_ROOT}/.boost
fi
export BOOST_ROOT=${RIME_ROOT}/.boost/dest
make xcode/ios/deps

# Prepare headers
rm -rf ${RIME_ROOT}/lib && mkdir -p ${RIME_ROOT}/lib/headers
cp ${RIME_ROOT}/librime/src/*.h ${RIME_ROOT}/lib/headers


# Helper function to build librime for a platform
build_librime() {
  local platform=$1
  local out_a=$2
  # Set common environment for all builds
  export IPHONEOS_DEPLOYMENT_TARGET=15.0
  export EXCLUDED_ARCHS=""
  export PLATFORM=$platform
  rm -rf ${RIME_ROOT}/librime/build ${RIME_ROOT}/librime/dist
  make xcode/ios/dist
  cp -f ${RIME_ROOT}/librime/dist/lib/librime.a ${RIME_ROOT}/lib/${out_a}
}

# Build for all platforms
build_librime SIMULATOR64 librime_simulator_x86_64.a
build_librime SIMULATORARM64 librime_simulator_arm64.a
build_librime OS64 librime_arm64.a

# Create xcframework for librime
rm -rf ${RIME_ROOT}/Frameworks/librime.xcframework
xcodebuild -create-xcframework \
 -library ${RIME_ROOT}/lib/librime_simulator_x86_64.a -headers ${RIME_ROOT}/lib/headers \
 -library ${RIME_ROOT}/lib/librime_simulator_arm64.a -headers ${RIME_ROOT}/lib/headers \
 -library ${RIME_ROOT}/lib/librime_arm64.a -headers ${RIME_ROOT}/lib/headers \
 -output ${RIME_ROOT}/Frameworks/librime.xcframework

# Copy librime dependencies
cp -f ${RIME_ROOT}/librime/lib/*.a ${RIME_ROOT}/lib

# Build xcframeworks for dependencies
deps=("libglog" "libleveldb" "libmarisa" "libopencc" "libyaml-cpp")
for file in ${deps[@]}; do
    echo "Building xcframework for ${file}"

    rm -rf $RIME_ROOT/lib/${file}_x86.a $RIME_ROOT/lib/${file}_arm64.a $RIME_ROOT/lib/${file}_sim_arm64.a

    lipo $RIME_ROOT/lib/${file}.a -thin x86_64 -output $RIME_ROOT/lib/${file}_x86.a
    lipo $RIME_ROOT/lib/${file}.a -thin arm64 -output $RIME_ROOT/lib/${file}_arm64.a
    lipo $RIME_ROOT/lib/${file}.a -thin arm64 -output $RIME_ROOT/lib/${file}_sim_arm64.a

    rm -rf ${RIME_ROOT}/Frameworks/${file}.xcframework
    xcodebuild -create-xcframework \
      -library ${RIME_ROOT}/lib/${file}_x86.a \
      -library ${RIME_ROOT}/lib/${file}_arm64.a \
      -library ${RIME_ROOT}/lib/${file}_sim_arm64.a \
      -output ${RIME_ROOT}/Frameworks/${file}.xcframework
done

# Clean intermediate .a files
rm -rf ${RIME_ROOT}/lib/librime*.a
