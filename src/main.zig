const std = @import("std");

const LameboyRuntimeError = error{InstructionNotImplemented};

const LameboyMemory = extern union {
    S: extern struct {
        ivec: [255]u8,
        cart_header: [80]u8,
        rom0: [0x3E80]u8,
        romN: [0x3E80]u8,
        vram: [0x1770]u8,
        bgmap1: [0x3E8]u8,
        bgmap2: [0x3E8]u8,
        wram: [0x1F40]u8,
        iram0: [4096]u8,
        iramN: [4096]u8,
        eram: [7680]u8,
        oam: [160]u8,
        unused: [96]u8,
        io: [128]u8,
        hram: [127]u8,
        int: u8,
    },
    Raw: [0xFFFF]u8,
};

const Lameboy = struct {
    PC: u16,
    SP: u16,
    AF: extern union {
        S: extern struct {
            A: u8,
            F: packed struct { z: u1, n: u1, h: u1, c: u1, unused: u4 },
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
    HL: extern union {
        S: extern struct {
            H: u8,
            L: u8,
        },
        HL: u16,
    },

    memory: LameboyMemory,

    running: bool,
    tcycles: u64,

    pub fn init() Lameboy {
        return Lameboy{
            .AF = .{ .AF = 0 },
            .BC = .{ .BC = 0 },
            .DE = .{ .DE = 0 },
            .HL = .{ .HL = 0 },
            .PC = 0,
            .SP = 0,
            .memory = .{ .Raw = [_]u8{0} ** 0xFFFF },
            .running = true,
            .tcycles = 0,
        };
    }
};

pub fn step(lameboy: *Lameboy) !void {
    switch (lameboy.memory.Raw[lameboy.PC]) {
        0 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            break :blk;
        },

        // LD B,d8
        0x06 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.BC.S.B = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            std.log.info("LD B,${x:0>2}", .{lameboy.BC.S.B});
            break :blk;
        },

        // INC C
        0x0C => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.BC.S.C & 0xf) + (1 & 0xf)) * 0x10 == 0x10)
                lameboy.AF.S.F.h = 1;

            lameboy.BC.S.C += 1;

            // set z if resulting sum was 0
            if (lameboy.BC.S.C == 0)
                lameboy.AF.S.F.z = 1;

            break :blk;
        },

        // LD C,d8
        0x0E => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.BC.S.C = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            std.log.info("LD C,${x:0>2}", .{lameboy.BC.S.C});
            break :blk;
        },

        // LD DE,d16
        0x11 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            lameboy.DE.DE = (@as(u16, lsb) << 8) | msb;
            std.log.info("LD DE,${x:0>4}", .{(@as(u16, lsb) << 8) | msb});
            break :blk;
        },

        // LD A,(DE)
        0x1A => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.AF.S.A = lameboy.memory.Raw[lameboy.DE.DE];
            std.log.info("LD A,(DE)", .{});
            break :blk;
        },

        // JR NZ,r8
        0x20 => blk: {
            lameboy.PC += 1;
            const r8: i8 = @bitCast(i8, lameboy.memory.Raw[lameboy.PC]);
            lameboy.PC += 1;

            if (lameboy.AF.S.F.z != 0) {
                lameboy.tcycles += 12;
                std.log.info("JR NZ,{d}", .{r8});
                // std.log.info("jr before PC={X:0>4}", .{lameboy.PC});
                lameboy.PC +%= @bitCast(u16, @intCast(i16, r8));
                // std.log.info("jr after PC={X:0>4}", .{lameboy.PC});
            } else {
                lameboy.tcycles += 8;
            }
            break :blk;
        },

        // LD HL,u16
        0x21 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            lameboy.HL.S.H = lsb;
            lameboy.HL.S.L = msb;

            break :blk;
        },

        // LD SP,u16
        0x31 => blk: {
            lameboy.tcycles += 3;
            lameboy.PC += 1;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            lameboy.SP = (@as(u16, lsb) << 8) | msb;
            break :blk;
        },

        // LD (HL-),A
        0x32 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;

            lameboy.HL.HL -= 1;
            lameboy.memory.Raw[lameboy.HL.HL] = lameboy.AF.S.A;
            std.log.info("LD (HL-),A", .{});
            break :blk;
        },

        // LD A,d8
        0x3E => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.AF.S.A = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            std.log.info("LD A,${x:0>2}", .{lameboy.AF.S.A});
            break :blk;
        },

        // LD C,A
        0x4F => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.BC.S.C = lameboy.AF.S.A;
            std.log.info("LD C,A", .{});
            break :blk;
        },

        // LD (HL),A
        0x77 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.memory.Raw[lameboy.HL.HL] = lameboy.AF.S.A;
            std.log.info("LD (HL),A", .{});
            break :blk;
        },

        // XOR A
        0xAF => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 1;
            const A: u8 = lameboy.AF.S.A;
            const value: u8 = A ^ A;
            lameboy.AF.S.A = value;
            if (value == 0) {
                lameboy.AF.S.F.z = 1;
            }
            break :blk;
        },

        // PUSH BC
        0xC5 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 16;

            lameboy.SP -= 1;
            lameboy.memory.Raw[lameboy.SP] = lameboy.BC.S.B;

            lameboy.SP -= 1;
            lameboy.memory.Raw[lameboy.SP] = lameboy.BC.S.C;

            std.log.info("PUSH BC", .{});
            break :blk;
        },

        // Pefix CB
        0xCB => {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            switch (lameboy.memory.Raw[lameboy.PC]) {
                // BIT 7, H
                0x7C => cblk: {
                    lameboy.PC += 1;
                    lameboy.tcycles += 8;
                    lameboy.AF.S.F.h = 1;
                    lameboy.AF.S.F.n = 0;
                    lameboy.AF.S.F.z = @intCast(u1, ((lameboy.HL.S.H >> 7) & 0x01));
                    break :cblk;
                },
                else => cblk: {
                    lameboy.running = false;
                    std.log.info("Unimplemented CB Instruction 0x{X}", .{lameboy.memory.Raw[lameboy.PC]});
                    std.log.info("Flags={B:0>1}", .{lameboy.AF.S.F});
                    break :cblk return LameboyRuntimeError.InstructionNotImplemented;
                },
            }
        },

        // CALL nn
        0xCD => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 24;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const nn: u16 = (@as(u16, lsb) << 8) | msb;

            lameboy.SP -= 1;
            lameboy.memory.Raw[lameboy.SP] = @intCast(u8, lameboy.PC >> 8);
            lameboy.SP -= 1;
            lameboy.memory.Raw[lameboy.SP] = @truncate(u8, lameboy.PC);

            lameboy.PC = nn;
            std.log.info("CALL ${x:0>4}", .{nn});
            break :blk;
        },

        // LDH (a8), A
        0xE0 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;
            const a8: u16 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            lameboy.memory.Raw[0xFF00 + a8] = lameboy.AF.S.A;
            std.log.info("LD ($FF00+${x:0>2}", .{a8});
            break :blk;
        },

        // LD ($FF00+C),A
        0xE2 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.memory.Raw[0xFF00 + @intCast(u16, lameboy.BC.S.C)] = lameboy.AF.S.A;
            std.log.info("LD ($FF00+{X:0>2}),A", .{lameboy.BC.S.C});
            break :blk;
        },

        else => blk: {
            lameboy.running = false;
            std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ lameboy.PC, lameboy.memory.Raw[lameboy.PC] });
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
        .{ .read = true },
    );
    defer bootrom.close();
    try bootrom.seekTo(0);
    _ = try bootrom.readAll(&state.memory.Raw);
    while (state.running) {
        try step(&state);
    }
}
