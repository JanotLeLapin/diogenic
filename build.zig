const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const buildNative = b.option(bool, "native", "Build native app") orelse true;
    const buildWasm = b.option(bool, "wasm", "Build wasm binary") orelse true;

    const core_mod = b.addModule("diogenic-core", .{
        .root_source_file = b.path("core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_step = b.step("run", "Run the app");

    if (buildNative) {
        const raylib = b.dependency("raylib_zig", .{
            .target = target,
            .optimize = optimize,
        });

        const exe = b.addExecutable(.{
            .name = "diogenic",
            .root_module = b.createModule(.{
                .root_source_file = b.path("app/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "diogenic-core", .module = core_mod },
                    .{ .name = "raylib", .module = raylib.module("raylib") },
                    .{ .name = "raygui", .module = raylib.module("raygui") },
                },
            }),
        });

        exe.linkLibrary(raylib.artifact("raylib"));

        exe.root_module.link_libc = true;
        exe.root_module.linkSystemLibrary("portaudio", .{});

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const exe_tests = b.addTest(.{
            .root_module = exe.root_module,
        });
        const run_exe_tests = b.addRunArtifact(exe_tests);

        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&run_exe_tests.step);
    }

    if (buildWasm) {
        const wasm_exe = b.addExecutable(.{
            .name = "diogenic-wasm",
            .root_module = b.createModule(.{
                .root_source_file = b.path("wasm/root.zig"),
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .wasm32,
                    .os_tag = .freestanding,
                    .abi = .none,
                }),
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "diogenic-core", .module = core_mod },
                },
            }),
        });

        wasm_exe.entry = .disabled;
        wasm_exe.export_memory = true;
        wasm_exe.rdynamic = true;

        b.installArtifact(wasm_exe);
    }

    const docs_exe = b.addExecutable(.{
        .name = "diogenic-docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("docs/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "diogenic-core", .module = core_mod },
            },
        }),
    });

    const run_docs = b.addRunArtifact(docs_exe);
    const output_file = run_docs.captureStdErr();
    const install_docs = b.addInstallFile(output_file, "diogenic-docs.md");

    const docs_step = b.step("docs", "Generate docs file");
    docs_step.dependOn(&install_docs.step);
}
