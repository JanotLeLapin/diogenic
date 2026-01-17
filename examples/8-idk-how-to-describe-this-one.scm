(defun bass (freq)
  ; simple low passed square bass
  (b-lowpass!
    :freq 250.0
    :in (square! freq)))

(defun dephased-bass (freq freq-offset)
  ; one bass per channel each with a frequency offset
  (+ (pan (bass (+ freq freq-offset)) -1.0)
     (pan (bass (- freq freq-offset))  1.0)))

(defun harmonic-synth (freq)
  ; rich synth texture, very cool
  (let (panning (* 0.3
                  (+ (* 0.5 (triangle! 0.2))
                     (* 0.5 (square! 0.06)))))
    (b-highpass!
      :freq 400.0
      :in (* 0.5
             (+ (pan (downsample! :sample-rate (+ 6400.0
                                                  (* 1800.0
                                                     (triangle! 0.09)))
                                  :in (sine! freq))
                     panning)
                (diode (chebyshev 2.0 (sine! freq)) (+ 0.8 (* 0.2 (sine! 0.3)))))))))

(let (freq-offset (+ 1.0 (* 0.4 (sine! 0.1))))
     (+ (dephased-bass (midi->freq 28.0) freq-offset)
        (harmonic-synth (midi->freq (+ 53.0 (sine! 0.03))))))
