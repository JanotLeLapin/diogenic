(defun builtin/pitch-shift!
  (in
   (target-pitch :doc "pitch difference, in semitones, between dry and wet signal")
   (grain-size :doc "grain size, in milliseconds"))
  "Modifies the pitch of the input signal using granular synthesis."
  (* 0.1
     (grains! :size grain-size
              :density (/ (* 10.0 1000.0) grain-size)
              :speed (exp2 (/ target-pitch 12.0))
              :position (< target-pitch 0.0)
              :in in)))

(defun builtin/comb!
  (in
   (delay :doc "delay, in seconds, between dry and wet signal")
   (depth :doc "mix, in range [0; 1], between the dry and wet signal")
   (polarity :doc "sets the sign of the wet signal"))
  "Adds a delay to the dry signal."
  (+ (* in (- 1 (* 0.5 depth)))
     (* (* polarity (delay! in delay)) (* 0.5 depth))))

(defun builtin/slew!
  (in
   (time :doc "slew time, in seconds"))
  "Smooths the input signal using a lowpass filter."
  (b-lowpass! :in in
              :q 0.2
              :freq (/ 5.0
                       (* (* 2 PI) time))))

(defun builtin/fm!
  ((carrier-freq :doc "carrier frequency, in hertz")
   (mod-freq :doc "modulator frequency, in hertz")
   (mod-index :doc "modulation index"))
  "FM synthesis"
  (sine! (+ carrier-freq
            (* (* mod-freq mod-index)
               (sine! mod-freq)))))
