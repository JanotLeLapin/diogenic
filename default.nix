{ zig
, libsndfile
, stdenv }: stdenv.mkDerivation {
  pname = "diogenic";
  version = "0.1";

  src = ./.;

  nativeBuildInputs = [ zig.hook ];
  buildInputs = [ libsndfile ];
  buildPhase = ''
    zig build --release=fast
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/diogenic $out/bin/diogenic
  '';
}
