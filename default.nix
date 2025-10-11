{ zig
, stdenv }: stdenv.mkDerivation {
  pname = "diogenic";
  version = "0.1";

  src = ./.;

  nativeBuildInputs = [ zig.hook ];
  buildPhase = ''
    zig build
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/zig_harsh $out/bin/harsh
  '';
}
