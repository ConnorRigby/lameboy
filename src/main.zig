const std = @import("std");
const glfw = @import("zglfw.zig");

const Core = @import("core.zig").Core;
const disassembler = @import("disassembler.zig");

pub fn main() anyerror!void {
    // std.log.info("{b:0>8} {b:0>8}", .{ @as(u8, 0x0), @as(u8, 0x10) });

    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.log.info("GLFW {}.{}.{}\n", .{ major, minor, rev });
    //Example of something that fails with GLFW_NOT_INITIALIZED - but will continue with execution
    //var monitor : ?*glfw.Monitor = glfw.getPrimaryMonitor();

    try glfw.init();
    defer glfw.terminate();
    std.log.info("GLFW Init Succeeded.\n", .{});


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
        // "gb-test-roms-master/cpu_instrs/individual/01-special.gb",
        // "gb-test-roms-master/cpu_instrs/individual/03-op sp,hl.gb",
        // "gb-test-roms-master/cpu_instrs/individual/04-op r,imm.gb",
        // "gb-test-roms-master/cpu_instrs/individual/05-op rp.gb",
        // "gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/07-jr,jp,call,ret,rst.gb",
        // "gb-test-roms-master/cpu_instrs/individual/08-misc instrs.gb",
        // "gb-test-roms-master/cpu_instrs/individual/09-op r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/11-op a,(hl).gb",
        "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
        .{ .read = true },
    );
    defer testrom.close();
    try testrom.seekTo(0);
    const size = try testrom.readAll(&core.memory.ROM);
    // std.log.info("rom size ${x:0>4}", .{size});
    core.memory.romSize = size;

    glfw.windowHint(glfw.WindowHint.Floating, 1);
    glfw.windowHint(glfw.WindowHint.Decorated, 1);
    glfw.windowHint(glfw.WindowHint.Resizable, 0);
    // glfw.windowHint(glfw.WindowHint.TransparentFramebuffer, 0);
    var window: *glfw.Window = try glfw.createWindow(160, 144, "gaemboy", null, null);
    glfw.makeContextCurrent(window);

    while (core.halt != true and !glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.Key.Escape) == glfw.KeyState.Press) {
            glfw.setWindowShouldClose(window, true);
            core.halt = true;
        }
        glfw.swapBuffers(window);
        glfw.pollEvents();

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
