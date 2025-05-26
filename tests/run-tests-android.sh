#!/bin/sh
set -e

. ../output/ndk-config
CC=$TOOLCHAIN/bin/$TARGET_TAG$ANDROID_API-clang

# Hack needed to replace run-compiler.sh
maybe_compile() {
    if [ "$1" = "ANDROID-RUN-C-COMPILER" ]; then
        dir=$2
        shift 2
        args=
        in=
        out=
        for arg; do
            if [ "$out" = "next" ]; then
                case $arg in
                    /*) out=$arg ;;
                    *) out=$dir/$arg ;;
                esac
            else
                case $arg in
                    /*.c) in=$arg ;;
                    *.c) in=$dir/$arg ;;
                    -o) out="next" ;;
                    *) args="$args $arg" ;;
                esac
            fi
        done
        temp=android_tempfile
        adb pull $in $temp.c
        echo $CC $args $temp.c -o $temp
        $CC $args $temp.c -o $temp || echo "fail"
        if [ -f $temp.h ]; then
            rm $temp.h
        fi
        rm $temp.c
        if [ -f $temp ]; then
            adb push $temp $out
            rm $temp
            echo "done"
        fi
    else
        echo "something is wrong..."
    fi
}

genheaders_pull_tempdir() {
    if [ "$1" = "ANDROID-GENHEADERS-PULL-TEMPDIR" ]; then
        temp="$2"
        dir="$3"
        if [ "$dir" = "done" ]; then
            rm -r $temp
        else
            adb pull $dir $temp
        fi
    else
        echo "something is wrong..."
    fi
}

make_reloc_test() {
    if [ "$1" = "ANDROID-MAKE-RELOC-TEST" ]; then
        if [ -f ../src/runtime/heap-reloc-test ]; then
           rm ../src/runtime/heap-reloc-test
        fi
        (cd ../src/runtime ; make heap-reloc-test)
        adb push ../src/runtime/heap-reloc-test /data/local/tmp/sbcl/src/runtime/heap-reloc-test
        rm ../src/runtime/heap-reloc-test
        echo "done"
    else
        echo "something is wrong..."
    fi
}

echo "adb shell \"(cd /data/local/tmp/sbcl/tests; LD_LIBRARY_PATH=/data/local/tmp/sbcl/android-libs SBCL_ANDROID_CROSS=true ./run-tests.sh $@)\""
adb shell "(cd /data/local/tmp/sbcl/tests; LD_LIBRARY_PATH=/data/local/tmp/sbcl/android-libs SBCL_ANDROID_CROSS=true ./run-tests.sh $@)" 2>&1 | \
    while read line; do
        line=$(echo "$line" | sed 's/\r//g')  # On older android line terminates with \r
        echo "$line" ;
        case "$line" in
            ANDROID-RUN-C-COMPILER*) maybe_compile $line ;;
            ANDROID-GENHEADERS-PULL-TEMPDIR*) genheaders_pull_tempdir $line ;;
            ANDROID-MAKE-RELOC-TEST*) make_reloc_test $line ;;
        esac
    done
