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
    _ = try bootrom.readAll(&core.memory.Bootrom);

    const testrom = try std.fs.cwd().openFile(
        "gb-test-roms-master/cgb_sound/rom_singles/01-registers.gb",
        .{ .read = true },
    );
    defer testrom.close();
    try testrom.seekTo(0);
    _ = try testrom.readAll(&core.memory.ROM);

    while (core.halt != true) {
        try core.step();
        core.debugger.step();
    }
}
