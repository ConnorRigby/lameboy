const std = @import("std");
const SDL = @cImport({
    @cInclude("SDL.h");
});

const Core = @import("core.zig").Core;
const disassembler = @import("disassembler.zig");

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
        // "gb-test-roms-master/cpu_instrs/individual/01-special.gb",
        // "gb-test-roms-master/cpu_instrs/individual/03-op sp,hl.gb",
        // "gb-test-roms-master/cpu_instrs/individual/04-op r,imm.gb",
        // "gb-test-roms-master/cpu_instrs/individual/05-op rp.gb",
        // "gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/07-jr,jp,call,ret,rst.gb",
        // "gb-test-roms-master/cpu_instrs/individual/08-misc instrs.gb",
        // "gb-test-roms-master/cpu_instrs/individual/09-op r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/11-op a,(hl).gb",
        // "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
        "dmg-acid2.gb",
        .{ .read = true },
    );
    defer testrom.close();
    try testrom.seekTo(0);
    const size = try testrom.readAll(&core.memory.ROM);
    // std.log.info("rom size ${x:0>4}", .{size});
    core.memory.romSize = size;

    _ = SDL.SDL_Init(SDL.SDL_INIT_VIDEO);
    defer SDL.SDL_Quit();

    var window = SDL.SDL_CreateWindow("gaemboy", SDL.SDL_WINDOWPOS_CENTERED, SDL.SDL_WINDOWPOS_CENTERED, 160, 144, 0);
    defer SDL.SDL_DestroyWindow(window);

    var renderer = SDL.SDL_CreateRenderer(window, 0, SDL.SDL_RENDERER_PRESENTVSYNC);
    defer SDL.SDL_DestroyRenderer(renderer);

    while (core.halt != true) {
        var sdl_event: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL.SDL_QUIT => core.halt = true,
                else => {},
            }
        }

        _ = SDL.SDL_SetRenderDrawColor(renderer, 0xFE, 0xFE, 0xFE, 0xFF);
        _ = SDL.SDL_RenderClear(renderer);
        SDL.SDL_RenderPresent(renderer);

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
    SDL.SDL_DestroyWindow(window);
    SDL.SDL_DestroyRenderer(renderer);
    SDL.SDL_Quit();
}
