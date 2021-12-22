const std = @import("std");
const Core = @import("core.zig").Core;

pub fn main() anyerror!void {
    var core = Core.init();

    const bootrom = try std.fs.cwd().openFile(
        "DMG_ROM.bin",
        .{ .read = true },
    );
    defer bootrom.close();
    try bootrom.seekTo(0);
    _ = try bootrom.readAll(&core.memory.Raw);

    while (core.halt != true)
        try core.step();
    std.log.info("{x:0>2}", .{core});
}
