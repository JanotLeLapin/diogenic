(use std/builtin)

(defun lp-freq (freq)
  "lowpass frequency between 150 and 850"
  (map (sine! freq) -1 1 150 850))

(defun quality-factor (freq)
  "crazy quality factor"
  (-> (sawtooth! freq)
      (builtin/slew 0.01)
      (* 8.0)
      (exp2)))

(defun dry ()
  "dry signal"
  (* 0.5
     (let (freq 69.0 noise-amp (+ 1.0 (* 0.5 (sine! 0.2))))
          (+ (* 0.4 (sine! (+ (* 2 freq) (sine! 0.12 0.1))))
             (* 0.02 (square! (+ freq (sine! 0.16 0.9)) (* (noise!) noise-amp)))))))

(b-lowpass!
  :freq (lp-freq 0.25)
  :q (quality-factor 2.0)
  :in (dry))
