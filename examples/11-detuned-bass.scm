(defun dephased-bass (freq detune)
  "two sawtooths, slight detune"
  (-> (let (offset (* 0.5 detune))
        (+ (sawtooth! (+ freq offset))
           (sawtooth! (- freq offset))))
      (tanh)
      (clip 0.6)
      (b-lowpass!
        :freq (map (sine! 0.085) -1 1 120 600)
        :q 0.6)))

(dephased-bass
  55.0
  (* 0.3 (bi->uni (triangle! 0.1))))
