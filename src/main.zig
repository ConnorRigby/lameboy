const std = @import("std");
const Core = @import("core.zig").Core;

pub fn main() anyerror!void {
    var core = Core.init();
    _ = try core.startDebugger();

    const bootrom = try std.fs.cwd().openFile(
        "DMG_ROM.bin",
        .{ .read = true },
    );
    defer bootrom.close();
    try bootrom.seekTo(0);
    _ = try bootrom.readAll(&core.memory.Raw);

    // const testrom = try std.fs.cwd().openFile(
    //     "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
    //     .{ .read = true },
    // );
    // defer testrom.close();
    // try testrom.seekTo(0);
    // // const slice = core.memory.Raw[256..0x3E80];
    // const result = try testrom.readAll(&core.memory.Rom);

    // std.log.info("result={d} 0x{x:0>2}", .{result, core.memory.Rom[0x0101]});

    core.memory.write8(0x69, 0x42);
    std.log.info("0x69 = {x:0>4}", .{core.memory.read8(0x69)});
    while (core.halt != true)
        try core.step();
    std.log.info("{x:0>2}", .{core});
}
