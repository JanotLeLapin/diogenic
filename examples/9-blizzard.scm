(use std/builtin)

(defun awesome-lfo (freq)
  (* 0.5
     (+ (square! (* (+ 2.0 (sine! 0.1))
                    freq))
        (triangle! freq))))

(defun carrier ()
  (sine! :freq (* 440.0
                  (-> (triangle! :freq (awesome-lfo 2.0))
                      (tanh)
                      (foldback 0.9)
                      (bi->uni)))))

(builtin/pitch-shift! (+ 24.0 (* 12.0 (sawtooth! 0.089)))
                      (+ 75.0 (* 50.0 (sine! 0.12)))
                      (carrier))
