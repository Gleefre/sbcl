#!/bin/sh
set -e

# Confirm that default evaluation strategy is :INTERPRET if sb-fasteval was built
./src/runtime/sbcl --core output/sbcl.core --lose-on-corruption --noinform \
  --no-sysinit --no-userinit --disable-debugger \
  --eval '(when (find-package "SB-INTERPRETER") (assert (eq *evaluator-mode* :interpret)))' \
  --quit

echo //checking for leftover cold-init symbols
./src/runtime/sbcl --core output/sbcl.core \
 --lose-on-corruption --noinform $SBCL_MAKE_TARGET_2_OPTIONS --no-sysinit --no-userinit --eval '
    (progn
      #-sb-devel
      (restart-case
          (let (l1 l2)
            (sb-vm:map-allocated-objects
             (lambda (obj type size)
               (declare (ignore size))
               (when (and (= type sb-vm:symbol-widetag) (not (symbol-package obj))
                          (search "!" (string obj)))
                 (push obj l1))
               (when (and (= type sb-vm:fdefn-widetag)
                          (not (symbol-package
                                (sb-int:fun-name-block-name
                                 (sb-kernel:fdefn-name obj)))))
                 (push obj l2)))
             :all)
            (when l1 (format t "Found ~D:~%~S~%" (length l1) l1))
            ;; Assert that a chosen few symbols not named using the ! convention are removed
            ;; by tree-shaking. This list was made by hand-checking various macros that seemed
            ;; not to be needed after the build. I would have thought
            ;; (EVAL-WHEN (:COMPILE-TOPLEVEL)) to be preferable, but revision fb1ba6de5e makes
            ;; a case for not doing that. Either way is less than fabulous.
            (sb-int:awhen
                (mapcan (quote apropos-list)
                        (quote ("DEFINE-INFO-TYPE" "LVAR-TYPE-USING"
                                                   "TWO-ARG-+/-"
                                                   "PPRINT-TAGBODY-GUTS" "WITH-DESCRIPTOR-HANDLERS"
                                                   "SUBTRACT-BIGNUM-LOOP" "BIGNUM-REPLACE" "WITH-BIGNUM-BUFFERS"
                                                   "GCD-ASSERT" "BIGNUM-NEGATE-LOOP"
                                                   "SHIFT-RIGHT-UNALIGNED"
                                                   "STRING-LESS-GREATER-EQUAL-TESTS")))
              (format t "~&Leftover from [disabled?] tree-shaker:~%~S~%" sb-int:it))
            (when l2
              (format t "Found ~D fdefns named by uninterned symbols:~%~S~%" (length l2) l2)))
        (abort-build ()
          :report "Abort building SBCL."
          (sb-ext:exit :code 1))))' --quit
