android_run() {
    adb push "$1" "$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out" > /dev/null 2>&1
    adb shell "chmod +x \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\"" > /dev/null 2>&1
    adb shell "LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\" 2>/dev/null"
    adb shell "rm \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\"" > /dev/null 2>&1
}

android_run_for_exit_code() {
    adb push "$1" "$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1" > /dev/null 2>&1
    adb shell "chmod +x \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\"" > /dev/null 2>&1
    adb shell "echo input | LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\" > /dev/null 2>&1 ; echo \"\$?\"" 2>/dev/null
    adb shell "rm \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\"" > /dev/null 2>&1
}
