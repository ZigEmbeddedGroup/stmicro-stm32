const std = @import("std");
const microzig = @import("deps/microzig/src/main.zig");
const boards = @import("src/boards.zig");

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{});
    inline for (@typeInfo(boards).Struct.decls) |decl| {
        if (!decl.is_pub)
            continue;

        const exe = microzig.addEmbeddedExecutable(
            b,
            decl.name ++ ".minimal",
            "test/programs/minimal.zig",
            .{ .board = @field(boards, decl.name) },
            .{ .optimize = optimize },
        );
        exe.install();
    }
}
