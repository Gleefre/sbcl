#!/bin/sh

platform="${SBCL_SOFTWARE_TYPE}-${SBCL_MACHINE_TYPE}"

if [ -z "$CC" ]; then
    if [ -x "`command -v cc`" ]; then
        CC=cc
    else
        CC=gcc
    fi
fi

args=
case "$platform" in
    Darwin-X86-64) args="-arch x86_64" ;;
    Darwin-X86)    args="-arch i386" ;;
    Darwin-PowerPC) args="-arch ppc" ;;
    SunOS-X86-64)  args=-m64 ;;
    Linux-X86)     args="-m32" ;;
    Linux-PowerPC) args="-m32" ;;
    FreeBSD-X86)   args="-m32" ;;
esac

while [ $# -gt 0 ]; do
    arg="$1"
    new=
    case "$arg" in
        -sbcl-pic)
            new=-fPIC
            ;;

        -sbcl-shared)
            case "$platform" in
                Darwin-*)        new=-bundle ;;
                *)               new=-shared ;;
            esac
            ;;

        *)
            break
            ;;
    esac

    shift
    if [ x"$new" != x ]; then
        args="$args $new"
    fi
done

if [ -n "$SBCL_ANDROID_CROSS" ]; then
    echo "ANDROID-RUN-C-COMPILER $(pwd) $args $@"
    out=
    for arg in "$@"; do
        if [ "$out" = "next" ]; then out=$arg; fi
        case "$arg" in -o) out="next" ;; esac
    done
    # KLUDGE: wait for the output file to appear
    waited=0
    while [ ! -f "$out" ] && [ "$waited" -lt 100 ]; do
        waited=$(expr $waited + 1)
        sleep 0.1;
    done
    sleep 0.1;  # wait for adb to finish copying if needed
    if [ ! -f "$out" ]; then
        echo "failed to compile" && exit 1
    fi
else
    echo "/ $CC $args $@"
    "$CC" $args "$@"
fi
