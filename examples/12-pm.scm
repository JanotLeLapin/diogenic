(defun pm!
  ((carrier-freq :doc "carrier frequency, in hertz")
   (mod :doc "modulator wave")
   (mod-amp :doc "modulator amplitude"))
  "phase modulation"
  (sine!
    carrier-freq
    (* mod mod-amp)))

(pm!
  (map (triangle! 0.12) -1 1 210 230)
  (sine!
    :freq (-> (sine! 0.1)
              (* 2.4)
              (tanh)
              (map -1 1 440.0 880.0)
              (+ (* 12.0 (sine! 0.5)))))
  (map
    (sine! (map (sine! 0.8) -1 1 0.2 1.0))
    -1 1
    0.0 10.0))
