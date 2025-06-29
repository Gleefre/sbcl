#!/bin/sh
set -e

build_started=`date`
export SBCL_ANDROID_CROSS=true

./make-config.sh "$@" --with-android --without-gcc-tls --check-host-lisp || exit $?

. output/prefix.def
. output/build-config

$SBCL_XC_HOST < tools-for-build/canonicalize-whitespace.lisp || exit 1

./make-host-1.sh
./make-target-1.sh
./make-host-2.sh

adb $SBCL_ADB_OPTIONS push ./ "$SBCL_ANDROID_TARGET_LOCATION/"

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-2.sh\""
adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-2.sh"

# Hack needed to replace SB-GROVEL:RUN-C-COMPILER
compile_one() {
    bin=temp-compile-from-android
    adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/contrib/asdf/$2" "$bin.c"
    $CC "$bin.c" -o "$bin"
    dest="$3"
    adb $SBCL_ADB_OPTIONS push "$bin" "$SBCL_ANDROID_TARGET_LOCATION/contrib/asdf/$dest"
    echo "done"
    rm "$bin"
    rm "$bin.c"
}

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-contrib-android.sh\""
adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-contrib-android.sh" | \
    while read line ; do
        line=$(echo "$line" | sed 's/\r//g')  # On older android line terminates with \r
        echo "$line" ;
        case "$line" in
            RUN-C-COMPILER*) compile_one $line ;;
        esac
    done

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-post-checks.sh\""
adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-post-checks.sh"

adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/obj"
adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/output"

./make-shared-library.sh

NPASSED=`ls obj/sbcl-home/contrib/sb-*.fasl | wc -l`
echo
echo "The build seems to have finished successfully, including $NPASSED"
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
