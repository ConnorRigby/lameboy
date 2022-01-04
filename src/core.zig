const std = @import("std");

const cpu = @import("cpu.zig");
const CPU = cpu.CPU;

const mmu = @import("mmu.zig");
const MMU = mmu.MMU;

const ppu = @import("ppu.zig");
const PPU = ppu.PPU;

const debugger = @import("debugger.zig");
const Debugger = debugger.Debugger;

pub const Core = struct {
    cpu: CPU,
    mmu: MMU,
    ppu: PPU,
    debugger: Debugger,

    pub fn init() Core {
        return Core{
            .cpu = CPU.init(),
            .mmu = MMU.init(),
            .ppu = PPU.init(),
            .debugger = Debugger.init(),
        };
    }

    pub fn startDebugger(core: *Core) !void {
        try core.debugger.start(core);
    }

    pub fn tick(core: *Core) !void {
        try core.cpu.tick(&core.mmu);
        try core.ppu.tick(&core.mmu);
        core.debugger.step();
    }

};
