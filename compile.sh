#!/usr/bin/env bash

set -e

dl_macos_jdks () {
  MACOS_JDKS=`mktemp -d`
  arches=('x64' 'aarch64')
  for arch in ${arches[@]}; do
    mkdir -p $MACOS_JDKS/$arch
  done
  printf "%s\n" "${arches[@]}" | xargs -I{} -P2 -- curl -LOs --output-dir $MACOS_JDKS/{} 'https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.20.1+1/OpenJDK11U-jdk_{}_mac_hotspot_11.0.20.1_1.tar.gz'
  printf "%s\n" "${arches[@]}" | xargs -I{} -P2 -- env MACOS_JDKS=$MACOS_JDKS bash -c 'WORK_DIR=`echo $MACOS_JDKS/{}` && pushd $WORK_DIR >/dev/null && tar -xzf OpenJDK11U-jdk_{}_mac_hotspot_11.0.20.1_1.tar.gz && rm OpenJDK11U-jdk_{}_mac_hotspot_11.0.20.1_1.tar.gz && popd >/dev/null'
}

cleanup () {
  echo "Deleting $MACOS_JDKS..."
  rm -fr "$MACOS_JDKS"
}

trap cleanup EXIT

# Make this smarter (i.e. don't re-download if already done)
dl_macos_jdks

cp -r secp256k1/ secp256k1-tmp/

pushd secp256k1-tmp/

# Modify secp256k1 native code with addition of JNI support
# Files copied from removed JNI support in bitcoin-core/secp256k1 repo
# https://github.com/bitcoin-core/secp256k1/pull/682
cp ../jni/build-aux/m4/* build-aux/m4/
cp -r ../jni/java/ src/java/
cp ../jni/Makefile.am Makefile.am
cp ../jni/configure.ac configure.ac

# Assumption: <https://github.com/tpoechtrager/osxcross> has been installed and is on the $PATH
JNF="$(xcrun --show-sdk-path)/System/Library/Frameworks/JavaNativeFoundation.framework"
unlink $JNF/Headers || true
ln -s "$MACOS_JDKS/x64/jdk-11.0.20.1+1/Contents/Home/include" "$JNF/Headers"

# Compile secp256k1 native code
./autogen.sh
CC=o64-clang ./configure --host='x86_64-apple-darwin23' --enable-jni --enable-module-ecdh --enable-experimental --enable-module-schnorrsig --enable-module-ecdsa-adaptor
# ./configure --enable-jni --enable-module-ecdh
make CFLAGS="-std=c99"
make

# Actually checking would involve emulation of the cross-compiled host, e.g. with qemu. Out of scope.
# make check
