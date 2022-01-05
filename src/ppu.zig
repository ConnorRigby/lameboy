const std = @import("std");
const MMU = @import("mmu.zig").MMU;

pub const PPUState = enum { OAMSearch, PixelTransfer, HBlank, VBlank };

pub const PPU = struct {
    State: PPUState,
    LY: u8,
    cycleCount: u64,
    pixelCount: u8,

    pub fn init() PPU {
        return PPU{
            .LY = 0,
            .cycleCount = 0,
            .pixelCount = 0,
            .State = PPUState.OAMSearch,
        };
    }

    pub fn tick(ppu: *PPU, _: *MMU) !void {
        // check lcd enable, enter oam search etc

        ppu.cycleCount += 1;
        switch (ppu.State) {
            PPUState.OAMSearch => blk: {
                if (ppu.cycleCount == 40) {
                    ppu.pixelCount = 0;

                    ppu.State = PPUState.PixelTransfer;
                }
                break :blk;
            },

            PPUState.PixelTransfer => blk: {
                ppu.pixelCount += 1;
                if (ppu.pixelCount == 160) {
                    ppu.State = PPUState.HBlank;
                }
                break :blk;
            },

            PPUState.HBlank => blk: {
                if (ppu.cycleCount == 456) {
                    ppu.cycleCount = 0;
                    ppu.LY += 1;
                    if (ppu.LY == 144) {
                        ppu.State = PPUState.VBlank;
                    } else {
                        ppu.State = PPUState.OAMSearch;
                    }
                }
                break :blk;
            },

            PPUState.VBlank => blk: {
                if (ppu.cycleCount == 456) {
                    ppu.cycleCount = 0;
                    ppu.LY += 1;
                    if (ppu.LY == 153) {
                        ppu.LY = 0;
                        ppu.State = PPUState.OAMSearch;
                    }
                }
                break :blk;
            },
        }
    }
};
