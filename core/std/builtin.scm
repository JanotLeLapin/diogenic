(defun builtin/pitch-shift (target-pitch grain-size in)
  "Modifies the pitch of the input signal using granular synthesis."
  (* 0.1
     (grains! :size grain-size
              :density (/ (* 10.0 1000.0) grain-size)
              :speed (exp2 (/ target-pitch 12.0))
              :position (< target-pitch 0.0)
              :in in)))

(defun builtin/comb (in delay depth polarity)
  "Adds a delay to the dry signal."
  (+ (* in (- 1 (* 0.5 depth)))
     (* (* polarity (delay! in delay)) (* 0.5 depth))))

(defun builtin/slew (in time)
  "Smooths the input signal using a lowpass filter."
  (b-lowpass! :in in
              :q 0.2
              :freq (/ 5.0
                       (* (* 2 PI) time))))
