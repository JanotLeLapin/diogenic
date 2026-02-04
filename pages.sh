#!/bin/sh
zig build -Dnative=false -Dwasm=true --release=small
zig build device-docs
zig build std-docs -- std/builtin

cp zig-out/bin/diogenic-wasm.wasm web/public/diogenic-wasm.wasm
cp zig-out/diogenic-device-docs.md web/src/content/docs/_device-docs.md
cp zig-out/diogenic-std-docs.md web/src/content/docs/_std-docs.md
