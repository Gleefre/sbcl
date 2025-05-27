android_run() {
    adb $SBCL_ADB_OPTIONS push "$1" "$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out" > /dev/null 2>&1
    adb $SBCL_ADB_OPTIONS shell "chmod +x \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\"" > /dev/null 2>&1
    (adb $SBCL_ADB_OPTIONS shell "LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\" 2>/dev/null") | sed 's/\r//g'
    adb $SBCL_ADB_OPTIONS shell "rm \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/temp.out\"" > /dev/null 2>&1
}

android_run_for_exit_code() {
    adb $SBCL_ADB_OPTIONS push "$1" "$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1" > /dev/null 2>&1
    adb $SBCL_ADB_OPTIONS shell "chmod +x \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\"" > /dev/null 2>&1
    (adb $SBCL_ADB_OPTIONS shell "echo input | LD_LIBRARY_PATH=\"$SBCL_ANDROID_TARGET_LOCATION/output/android-libs\" \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\" > /dev/null 2>&1 ; echo \"\$?\"" 2>/dev/null) | sed 's/\r//g'
    adb $SBCL_ADB_OPTIONS shell "rm \"$SBCL_ANDROID_TARGET_LOCATION/tools-for-build/$1\"" > /dev/null 2>&1
}
