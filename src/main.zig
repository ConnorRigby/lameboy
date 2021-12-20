const std = @import("std");

const LameboyRuntimeError = error {
    InstructionNotImplemented
};

const Lameboy = struct {
    PC: u16,
    SP: u16,
    AF: extern union {
        S: extern struct {
            A: u8,
            F: packed struct {
                z: u1,
                n: u1,
                h: u1,
                c: u1,
                unused: u4
            },
        },
        AF: u16,
    },
    BC: extern union {
        S: extern struct {
            B: u8,
            C: u8,
        },
        BC: u16,
    },
    DE: extern union {
        S: extern struct {
            D: u8,
            E: u8,
        },
        DE: u16,
    },
    
    RAM: [255]u8,
    ROM: [255]u8,

    running: bool,
    tcycles: u64,

    pub fn init() Lameboy {
        return Lameboy {
            .AF = .{.AF=0},
            .BC = .{.BC = 0},
            .DE = .{.DE = 0},
            .PC = 0,
            .SP = 0,
            .RAM = [_]u8{0} ** 255,
            .ROM = [_]u8{0} ** 255,
            .running = true,
            .tcycles = 0,
        };
    }
};

pub fn step(lameboy: *Lameboy) !void {
    switch(lameboy.ROM[lameboy.PC]) {
        0 => blk: {
            lameboy.tcycles += 4;
            lameboy.PC+=1;
            break :blk;
        },

        // LD SP u16
        0x31 => blk: {
            lameboy.tcycles += 3;
            lameboy.PC+=1;

            const msb:u8 = lameboy.ROM[lameboy.PC];
            lameboy.PC+=1;

            const lsb:u8 = lameboy.ROM[lameboy.PC];
            lameboy.PC+=1;

            lameboy.SP = (@as(u16, lsb) << 8) | msb;
            break :blk;
        },

        // XOR A
        0xAF => blk: {
            lameboy.PC+=1;
            lameboy.tcycles+=1;
            const A:u8 = lameboy.AF.S.A;
            const value:u8 = A^A;
            lameboy.AF.S.A = value;
            if(value == 0) {
                lameboy.AF.S.F.z = 1;
            }
            break :blk;
        },

        else => blk: {
            lameboy.running = false;
            std.log.info("Unimplemented Instruction 0x{X}", .{lameboy.ROM[lameboy.PC]});
            std.log.info("Flags={B:0>1}", .{lameboy.AF.S.F});
            break :blk return LameboyRuntimeError.InstructionNotImplemented;
        },
    }
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var state = Lameboy.init();
    const bootrom = try std.fs.cwd().openFile(
        "DMG_ROM.bin",
        .{ .read = true},
    );
    defer bootrom.close();
    try bootrom.seekTo(0);
    _ = try bootrom.readAll(&state.ROM);
    while(state.running) {
        try step(&state);
    }
}