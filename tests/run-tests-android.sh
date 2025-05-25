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

echo "adb shell \"(cd /data/local/tmp/sbcl/tests; LD_LIBRARY_PATH=/data/local/tmp/sbcl/android-libs ./run-tests.sh $@)\""
adb shell "(cd /data/local/tmp/sbcl/tests; LD_LIBRARY_PATH=/data/local/tmp/sbcl/android-libs ./run-tests.sh $@)" 2>&1 | \
    while read line; do
        line=$(echo "$line" | sed 's/\r//g')  # On older android line terminates with \r
        echo "$line" ;
        case "$line" in
            ANDROID-RUN-C-COMPILER*) maybe_compile $line ;;
        esac
    done
