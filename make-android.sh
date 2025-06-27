#!/bin/sh
set -e

build_started=`date`
export SBCL_ANDROID_CROSS=true

if ! command -v adb >/dev/null 2>&1; then
    echo "ADB not found, can't cross-compile for Android"
    exit 1
elif ! adb shell "echo"; then
    echo "adb shell not working. Is the Android device connected?"
    exit 1
fi

./make-config.sh "$@" --with-android --without-gcc-tls --check-host-lisp || exit $?

. output/prefix.def
. output/build-config

$SBCL_XC_HOST < tools-for-build/canonicalize-whitespace.lisp || exit 1

./make-host-1.sh
./make-target-1.sh
./make-host-2.sh

adb push ./ /data/local/tmp/sbcl/

echo adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-target-2.sh"
adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-target-2.sh"

# Hack needed to replace SB-GROVEL:RUN-C-COMPILER
compile_one() {
    bin=temp-compile-from-android
    adb pull /data/local/tmp/sbcl/contrib/asdf/$2 $bin.c
    $CC $bin.c -o $bin
    dest=$(echo $3 | sed 's/\r//g')  # On older android line terminates with \r
    adb push $bin /data/local/tmp/sbcl/contrib/asdf/$dest
    echo "done"
    rm $bin
    rm $bin.c
}

echo adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-target-contrib-android.sh" "|" wrapper
adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-target-contrib-android.sh" | \
    while read line ;
      do echo "$line" ;
      echo $line | grep "RUN-C-COMPILER" | while read line ; do compile_one $line ; done ;
    done

echo adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-post-checks.sh"
adb shell "cd /data/local/tmp/sbcl ; LD_LIBRARY_PATH=/data/local/tmp/sbcl/output/android-libs SBCL_ANDROID_CROSS=true sh make-post-checks.sh"

adb pull /data/local/tmp/sbcl/obj
adb pull /data/local/tmp/sbcl/output

./make-shared-library.sh

NPASSED=`ls obj/sbcl-home/contrib/sb-*.fasl | wc -l`
echo
echo "The build seems to have finished successfully, including $NPASSED (out of $NCONTRIBS)"
echo "contributed modules. If you would like to run more extensive tests on"
echo "the new SBCL, you can try:"
echo
echo "  cd ./tests && sh ./run-tests-android.sh"
echo
echo "To build documentation:"
echo
echo "  cd ./doc/manual && make"
echo
echo "To install SBCL (more information in INSTALL):"
echo
echo "  sh install.sh"

build_finished=`date`
echo
echo "//build started:  $build_started"
echo "//build finished: $build_finished"
