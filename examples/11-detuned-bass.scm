(defun dephased-sawtooth (freq detune)
  "two sawtooths, slight detune"
  (let (offset (* 0.5 detune))
    (+ (sawtooth! (+ freq offset))
       (sawtooth! (- freq offset)))))

(defun dephased-bass (freq detune)
  "dephased, clipped, quantized sawtooth bass"
  (-> (let (offset (* 0.5 detune))
        (+ (dephased-sawtooth freq (* 0.5 detune))
           (pan (dephased-sawtooth (* 3.0 freq) (* 1.5 detune))
                (* 0.6 (sine! 0.067)))))
      (* 1.6)
      (tanh)
      (clip 0.6)
      (b-lowpass!
        :freq (map (sine! 0.085) -1 1 120 600)
        :q 0.6)
      (quantize 5.4)))

(dephased-bass
  (map (sine! (map (sine! 0.06) -1 1 0.06 0.46)) -1 1 40 60)
  (* 0.3 (bi->uni (triangle! 0.1))))
