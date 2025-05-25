#!/bin/sh

set -e
. ./subr.sh
create_test_subdirectory

run_sbcl <<EOF
;; technically this is "skipped" if not fasteval, but we don't have "skipped"
;; as a status code from shell tests.
(when (member :sb-devel *features*)
  ;; host with #+sb-devel hangs
  ;; exit normally so that the shell doesn't exit abnormally (as per "set -e")
 (format t "~&Skipping test due to sb-devel~%")
 (exit))
(setq *evaluator-mode* :interpret)
(defvar *sbcl-local-target-features-file* "../local-target-features.lisp-expr")
(load "../src/cold/shared.lisp")
(load "../src/cold/set-up-cold-packages.lisp")
(load "../tools-for-build/corefile.lisp")
(in-package "SB-COLD")
(defvar *target-sbcl-version* (read-from-file "../version.lisp-expr"))
(in-host-compilation-mode
 (lambda (&aux (sb-xc:*features* (cons :c-headers-only sb-xc:*features*))
               (*load-verbose* t))
   (do-stems-and-flags (stem flags 1)
     (when (member :c-headers flags)
       (handler-bind ((style-warning (function muffle-warning)))
         (load (merge-pathnames (stem-remap-target stem)
                                (make-pathname :directory '(:relative :up) :type "lisp"))))))
   (load "../src/compiler/generic/genesis.lisp")))
(genesis :c-header-dir-name "$TEST_DIRECTORY/" :verbose t)
(assert (probe-file "$TEST_DIRECTORY/gc-tables.h"))
EOF

src=$TEST_DIRECTORY/test.c
obj=$TEST_DIRECTORY/test.o
# no files exist if the generator test was entirely skipped
if [ -r $TEST_DIRECTORY/cons.h ]
then
    if [ "$SBCL_SOFTWARE_TYPE" = "Android" ]; then
        temp=android_tempdir
        echo "ANDROID-GENHEADERS-PULL-TEMPDIR $temp $TEST_DIRECTORY"
        for i in $TEST_DIRECTORY/*.h
        do
            echo "#include \"$temp/$(basename $i)\"" > ${src}
            ./run-compiler.sh -I../src/runtime -c -o ${obj} ${src}
            rm ${obj}
        done
        echo "ANDROID-GENHEADERS-PULL-TEMPDIR $temp done"
    else
        for i in $TEST_DIRECTORY/*.h
        do
            echo "#include \"$i\"" > ${src}
            ./run-compiler.sh -I../src/runtime -c -o ${obj} ${src}
        done
    fi
fi

exit $EXIT_TEST_WIN
