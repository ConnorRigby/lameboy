const std = @import("std");
const SDL = @cImport({
    @cInclude("SDL.h");
});

const zgt = @import("zgt");

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
    _ = try bootrom.readAll(&core.mmu.Bootrom);

    const testrom = try std.fs.cwd().openFile(
        "gb-test-roms-master/cpu_instrs/individual/01-special.gb",
        // "gb-test-roms-master/cpu_instrs/individual/03-op sp,hl.gb",
        // "gb-test-roms-master/cpu_instrs/individual/04-op r,imm.gb",
        // "gb-test-roms-master/cpu_instrs/individual/05-op rp.gb",
        // "gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/07-jr,jp,call,ret,rst.gb",
        // "gb-test-roms-master/cpu_instrs/individual/08-misc instrs.gb",
        // "gb-test-roms-master/cpu_instrs/individual/09-op r,r.gb",
        // "gb-test-roms-master/cpu_instrs/individual/11-op a,(hl).gb",
        // "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
        // "dmg-acid2.gb",
        .{ .read = true },
    );
    defer testrom.close();
    try testrom.seekTo(0);
    const size = try testrom.readAll(&core.mmu.ROM);
    // std.log.info("rom size ${x:0>4}", .{size});
    core.mmu.romSize = size;


    _ = SDL.SDL_Init(SDL.SDL_INIT_VIDEO);
    defer SDL.SDL_Quit();

    // const char* glsl_version = "#version 150";
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_FLAGS, SDL.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK, SDL.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MINOR_VERSION, 2);
    // and prepare OpenGL stuff
    _ = SDL.SDL_SetHint(SDL.SDL_HINT_RENDER_DRIVER, "opengl");
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DEPTH_SIZE, 24);
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_STENCIL_SIZE, 8);
    _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DOUBLEBUFFER, 1);
    var current: SDL.SDL_DisplayMode = undefined;
    _ = SDL.SDL_GetCurrentDisplayMode(0, &current);

    var window = SDL.SDL_CreateWindow("gaemboy", SDL.SDL_WINDOWPOS_CENTERED, SDL.SDL_WINDOWPOS_CENTERED, 160, 144, SDL.SDL_WINDOW_SHOWN | SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_RESIZABLE);
    defer SDL.SDL_DestroyWindow(window);

    var renderer = SDL.SDL_CreateRenderer(window, 0, SDL.SDL_RENDERER_PRESENTVSYNC);
    defer SDL.SDL_DestroyRenderer(renderer);


    _ = SDL.SDL_SetRenderDrawColor(renderer, 0xFE, 0xFE, 0xFE, 0xFF);
    _ = SDL.SDL_RenderClear(renderer);
    SDL.SDL_RenderPresent(renderer);

    while (core.cpu.halt != true) {
        try core.tick();

        var sdl_event: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL.SDL_QUIT => core.cpu.halt = true,
                else => {},
            }
        }
    }
    SDL.SDL_DestroyWindow(window);
    SDL.SDL_DestroyRenderer(renderer);
    SDL.SDL_Quit();
}
