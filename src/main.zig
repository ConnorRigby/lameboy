const std = @import("std");
const Core = @import("core.zig").Core;
const disassembler = @import("disassembler.zig");

pub fn main() anyerror!void {
    // std.log.info("{b:0>8} {b:0>8}", .{ @as(u8, 0x0), @as(u8, 0x10) });

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
        "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
        .{ .read = true },
    );
    defer testrom.close();
    try testrom.seekTo(0);
    const size = try testrom.readAll(&core.memory.ROM);
    // std.log.info("rom size ${x:0>4}", .{size});
    core.memory.romSize = size;

    while (core.halt != true) {
        if (core.step()) |_| {
            core.debugger.step();
        } else |err| switch (err) {
            else => blk: {
                core.halt = true;
                const opcode = core.memory.read8(core.cpu.PC);
                std.log.info("Error! {s} PC=${x:0>4} OP=${x:0>2} {s}", .{ err, core.cpu.PC, opcode, disassembler.disassemble(opcode) });
                break :blk;
            },
        }
    }
}
