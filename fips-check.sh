#!/bin/bash

# fips-check.sh
# This script checks the current revision of the code against the
# previous release of the FIPS code. While wolfSSL and wolfCrypt
# may be advancing, they must work correctly with the last tested
# copy of our FIPS approved code.
#
# This should check out all the approved versions. The command line
# option selects the version.
#
#     $ ./fips-check [version]
#
#     - version: linux (default), ios, android, windows
#

function Usage() {
    echo "Usage: $0 [platform]"
    echo "Where \"platform\" is one of linux (default), ios, android, windows"
}

LINUX_FIPS_VERSION=v3.2.6
LINUX_FIPS_REPO=git@github.com:wolfSSL/fips.git
LINUX_CTAO_VERSION=v3.2.6
LINUX_CTAO_REPO=git@github.com:cyassl/cyassl.git

IOS_FIPS_VERSION=v3.4.8a
IOS_FIPS_REPO=git@github.com:wolfSSL/fips.git
IOS_CTAO_VERSION=v3.4.8.fips
IOS_CTAO_REPO=git@github.com:cyassl/cyassl.git

ANDROID_FIPS_VERSION=v3.5.0
ANDROID_FIPS_REPO=git@github.com:wolfSSL/fips.git
ANDROID_CTAO_VERSION=v3.5.0
ANDROID_CTAO_REPO=git@github.com:cyassl/cyassl.git

#WINDOWS_FIPS_VERSION=v3.6.0
WINDOWS_FIPS_VERSION=master
WINDOWS_FIPS_REPO=git@github.com:wolfSSL/fips.git
WINDOWS_CTAO_VERSION=v3.6.0
WINDOWS_CTAO_REPO=git@github.com:cyassl/cyassl.git

FIPS_SRCS=( fips.c fips_test.c )
WC_MODS=( aes des3 sha sha256 sha512 rsa hmac random )
TEST_DIR=XXX-fips-test
WC_INC_PATH=cyassl/ctaocrypt
WC_SRC_PATH=ctaocrypt/src

if [ "x$1" == "x" ]; then PLATFORM="linux"; else PLATFORM=$1; fi

case $PLATFORM in
ios)
  FIPS_VERSION=$IOS_FIPS_VERSION
  FIPS_REPO=$IOS_FIPS_REPO
  CTAO_VERSION=$IOS_CTAO_VERSION
  CTAO_REPO=$IOS_CTAO_REPO
  ;;
android)
  FIPS_VERSION=$ANDROID_FIPS_VERSION
  FIPS_REPO=$ANDROID_FIPS_REPO
  CTAO_VERSION=$ANDROID_CTAO_VERSION
  CTAO_REPO=$ANDROID_CTAO_REPO
  ;;
windows)
  FIPS_VERSION=$WINDOWS_FIPS_VERSION
  FIPS_REPO=$WINDOWS_FIPS_REPO
  CTAO_VERSION=$WINDOWS_CTAO_VERSION
  CTAO_REPO=$WINDOWS_CTAO_REPO
  ;;
linux)
  FIPS_VERSION=$LINUX_FIPS_VERSION
  FIPS_REPO=$LINUX_FIPS_REPO
  CTAO_VERSION=$LINUX_CTAO_VERSION
  CTAO_REPO=$LINUX_CTAO_REPO
  ;;
*)
  Usage
  exit 1
esac

git clone . $TEST_DIR
[ $? -ne 0 ] && echo "\n\nCouldn't duplicate current working directory.\n\n" && exit 1

pushd $TEST_DIR

# make a clone of the last FIPS release tag
git clone -b $CTAO_VERSION $CTAO_REPO old-tree
[ $? -ne 0 ] && echo "\n\nCouldn't checkout the FIPS release.\n\n" && exit 1

for MOD in ${WC_MODS[@]}
do
    cp old-tree/$WC_SRC_PATH/${MOD}.c $WC_SRC_PATH
    cp old-tree/$WC_INC_PATH/${MOD}.h $WC_INC_PATH
done

# The following is temporary. We are using random.c from a separate release
pushd old-tree
git checkout v3.6.0
popd
cp old-tree/$WC_SRC_PATH/random.c $WC_SRC_PATH
cp old-tree/$WC_INC_PATH/random.h $WC_INC_PATH

# clone the FIPS repository
git clone -b $FIPS_VERSION $FIPS_REPO fips
[ $? -ne 0 ] && echo "\n\nCouldn't checkout the FIPS repository.\n\n" && exit 1

for SRC in ${FIPS_SRCS[@]}
do
    cp fips/$SRC $WC_SRC_PATH
done

# run the make test
./autogen.sh
./configure --enable-fips
make
[ $? -ne 0 ] && echo "\n\nMake failed. Debris left for analysis." && exit 1

NEWHASH=`./wolfcrypt/test/testwolfcrypt | sed -n 's/hash = \(.*\)/\1/p'`
if [ -n "$NEWHASH" ]; then
    sed -i.bak "s/^\".*\";/\"${NEWHASH}\";/" $WC_SRC_PATH/fips_test.c
    make clean
fi

make test
[ $? -ne 0 ] && echo "\n\nTest failed. Debris left for analysis." && exit 1

# Clean up
popd
rm -rf $TEST_DIR

