(defun builtin/pitch-shift (target-pitch grain-size in)
  (* 0.1
     (grains! :size grain-size
              :density (/ (* 10.0 1000.0) grain-size)
              :speed (exp2 (/ target 12.0))
              :position (< target-pitch 0.0)
              :in in)))
