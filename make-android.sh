#!/bin/sh
set -e

export SBCL_ANDROID_CROSS=true

./make-config.sh "$@" --with-android --without-gcc-tls --check-host-lisp || exit $?

. output/prefix.def
. output/build-config

build_started=`date`
echo "//Starting build: $build_started"
# Apparently option parsing succeeded. Print out the results.
echo "//Options: --xc-host='$SBCL_XC_HOST' --android-target-location='$SBCL_ANDROID_TARGET_LOCATION'"

# Enforce the source policy for no bogus whitespace
$SBCL_XC_HOST < tools-for-build/canonicalize-whitespace.lisp || exit 1

maybetime() {
    if command -v time > /dev/null ; then
        time $@
    else
        $@
    fi
}

maybetime sh make-host-1.sh
maybetime sh make-target-1.sh
maybetime sh make-host-2.sh

adb $SBCL_ADB_OPTIONS push ./ "$SBCL_ANDROID_TARGET_LOCATION/"

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-2.sh\""
maybetime adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-2.sh"

# Hack needed to replace SB-GROVEL:RUN-C-COMPILER
compile_one() {
    bin=temp-compile-from-android
    adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/contrib/asdf/$2" "tools-for-build/$bin.c"
    ( cd tools-for-build; make "$bin" -I ../src/runtime )
    dest="$3"
    adb $SBCL_ADB_OPTIONS push "tools-for-build/$bin" "$SBCL_ANDROID_TARGET_LOCATION/contrib/asdf/$dest"
    echo "done"
    rm "tools-for-build/$bin"
    rm "tools-for-build/$bin.c"
}

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-contrib-android.sh\""
maybetime adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-target-contrib-android.sh" | \
    while read line ; do
        line=$(echo "$line" | sed 's/\r//g')  # On older android line terminates with \r
        echo "$line" ;
        case "$line" in
            RUN-C-COMPILER*) compile_one $line ;;
        esac
    done

echo "adb $SBCL_ADB_OPTIONS shell \"cd \\\"$SBCL_ANDROID_TARGET_LOCATION\\\" ; LD_LIBRARY_PATH=\\\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\\\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-post-checks.sh\""
maybetime adb $SBCL_ADB_OPTIONS shell "cd \"$SBCL_ANDROID_TARGET_LOCATION\" ; LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" SBCL_ANDROID_CROSS=true TMPDIR=/data/local/tmp sh make-post-checks.sh"

adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/obj"
adb $SBCL_ADB_OPTIONS pull "$SBCL_ANDROID_TARGET_LOCATION/output"

maybetime sh make-shared-library.sh

# Push libsbcl.so for completeness
adb $SBCL_ADB_OPTIONS push ./src/runtime/libsbcl.so "$SBCL_ANDROID_TARGET_LOCATION/src/runtime/libsbcl.so"

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

build_finished=`date`
echo
echo "//build started:  $build_started"
echo "//build finished: $build_finished"
