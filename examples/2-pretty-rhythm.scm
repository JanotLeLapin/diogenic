(b-lowpass!
  (+ 500.0 (* 350.0 (sine! 0.25 1.2))) ; lowpass cutoff 500+-350
  (exp2 (* 8 (sawtooth! 2.0 0.0))) ; crazy quality factor
  1.0
  (* 0.5
     (let (freq 69.0 noise-amp (+ 1.0 (* 0.5 (sine! 0.2 0.0))))
          (+ (* 0.4 (sine! (+ (* 2 freq) (sine! 0.12 0.1)) 0.0))
             (* 0.02 (square! (+ freq (sine! 0.16 0.9)) (* (noise!) noise-amp)))))))
