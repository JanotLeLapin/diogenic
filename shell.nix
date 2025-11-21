{ zig
, zls
, gcc
, libsndfile
, mkShell
}: mkShell {
  buildInputs = [ zig zls gcc libsndfile ];
}
