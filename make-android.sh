#!/bin/sh
set -e

build_started=`date`

echo '"ANDROID-WIP"' > version.lisp-expr

./make-config.sh "$@" --with-android --without-gcc-tls --check-host-lisp || exit $?

. output/prefix.def
. output/build-config

$SBCL_XC_HOST < tools-for-build/canonicalize-whitespace.lisp || exit 1

./make-host-1.sh
./make-target-1.sh
./make-host-2.sh

rm -f sbcl.zip
zip -r sbcl.zip *
adb shell rm -rf /data/local/tmp/sbcl
adb shell rm -f /data/local/tmp/sbcl.zip
adb shell mkdir /data/local/tmp/sbcl
adb push sbcl.zip /data/local/tmp/sbcl
rm sbcl.zip
adb shell "cd /data/local/tmp/sbcl ; unzip sbcl.zip ; rm sbcl.zip"
adb shell "cd /data/local/tmp/sbcl ; ./make-target-2.sh"

compile_one() {
    bin=temp-compile-from-android
    adb pull /data/local/tmp/sbcl/contrib/asdf/$2 $bin.c
    $CC $bin.c -o $bin
    adb push $bin /data/local/tmp/sbcl/contrib/asdf/$3
    echo "done"
    rm $bin
    rm $bin.c
}

adb shell "cd /data/local/tmp/sbcl ; sh make-target-contrib-android.sh" | \
    while read line ;
      do echo "$line" ;
      echo $line | grep "RUN-C-COMPILER" | while read line ; do compile_one $line ; done ;
    done

adb pull /data/local/tmp/sbcl/obj
adb pull /data/local/tmp/sbcl/output

./make-shared-library.sh

NPASSED=`ls obj/sbcl-home/contrib/sb-*.fasl | wc -l`
echo
echo "The build seems to have finished successfully, including $NPASSED (out of $NCONTRIBS)"
echo "contributed modules. If you would like to run more extensive tests on"
echo "the new SBCL, you can try:"
echo
echo "  cd ./tests && sh ./run-tests.sh"
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