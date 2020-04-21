const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const buildMode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("librokuhachi", "lib/main.zig");
    lib.setTarget(target);
    lib.setBuildMode(buildMode);

    const exe = b.addExecutable("rokuhachi", "src/main.zig");
    exe.addPackagePath("rokuhachi", "lib/main.zig");
    exe.linkLibrary(lib);
    exe.setTarget(target);
    exe.setBuildMode(buildMode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.addTest("tests/tests.zig");
    test_step.setBuildMode(buildMode);
    test_step.addPackagePath("rokuhachi", "lib/main.zig");
    test_step.linkLibrary(lib);

    const test_cmd = b.step("test", "Run the tests");
    test_cmd.dependOn(&test_step.step);
}
