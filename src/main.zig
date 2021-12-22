const std = @import("std");

const GbRuntimeError = error{ InstructionNotImplemented, YouSuck };

const GbMemory = extern union {
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

const Gb = struct {
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

    memory: GbMemory,

    running: bool,
    tcycles: u64,

    pub fn init() Gb {
        return Gb{
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

pub fn break_step() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [10]u8 = undefined;

    try stdout.print(">", .{});
    _ = try stdin.readUntilDelimiterOrEof(buf[0..], '\n');
}

pub fn step(gb: *Gb) !void {
    if (gb.PC == 0x0070) {
        std.log.info("{x:0>2}", .{gb.memory.Raw[gb.PC]});
        return GbRuntimeError.YouSuck;
    }
    std.log.info("\tPC=0x{x:0>2} OP=0x{x:0>2}", .{ gb.PC, gb.memory.Raw[gb.PC] });
    // try break_step();

    switch (gb.memory.Raw[gb.PC]) {
        0 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            std.log.info("NOP", .{});
            gb.running = false;
            break :blk;
        },

        // INC B
        0x04 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            gb.BC.S.B += 1;
            gb.AF.S.F.n = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.h = 0;

            if ((gb.BC.S.B & 0x0F) == 0)
                gb.AF.S.F.h = 1;
            if (gb.BC.S.B == 0)
                gb.AF.S.F.z = 1;

            std.log.info("INC B", .{});
            break :blk;
        },

        // DEC B
        0x05 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const value: u8 = gb.BC.S.B -% 1;
            gb.BC.S.B = value;
            gb.AF.S.F.h = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.n = 1;

            if ((gb.BC.S.B & 0x0f) == 0xf)
                gb.AF.S.F.h = 1;

            if (gb.BC.S.B == 0)
                gb.AF.S.F.z = 1;

            std.log.info("DEC B", .{});
            break :blk;
        },

        // LD B,d8
        0x06 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.BC.S.B = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD B,${x:0>2}", .{gb.BC.S.B});
            break :blk;
        },

        // INC C
        0x0C => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            gb.BC.S.C += 1;
            gb.AF.S.F.n = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.h = 0;

            if ((gb.BC.S.C & 0x0F) == 0)
                gb.AF.S.F.h = 1;
            if (gb.BC.S.C == 0)
                gb.AF.S.F.z = 1;

            std.log.info("INC C", .{});
            break :blk;
        },

        // DEC C
        0x0D => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const value: u8 = gb.BC.S.C -% 1;
            gb.BC.S.C = value;
            gb.AF.S.F.h = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.n = 1;

            if ((gb.BC.S.C & 0x0f) == 0xf)
                gb.AF.S.F.h = 1;

            if (gb.BC.S.C == 0)
                gb.AF.S.F.z = 1;

            std.log.info("DEC C", .{});
            break :blk;
        },

        // LD C,d8
        0x0E => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.BC.S.C = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD C,${x:0>2}", .{gb.BC.S.C});
            break :blk;
        },

        // LD DE,d16
        0x11 => blk: {
            gb.PC += 1;
            gb.tcycles += 12;

            const msb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const lsb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            gb.DE.DE = (@as(u16, lsb) << 8) | msb;
            std.log.info("LD DE,${x:0>4}", .{(@as(u16, lsb) << 8) | msb});
            break :blk;
        },

        // INC DE
        0x13 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.DE.DE += 1;
            std.log.info("INC DE", .{});
            break :blk;
        },

        // DEC D
        0x15 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const value: u8 = gb.DE.S.D -% 1;
            gb.DE.S.D = value;
            gb.AF.S.F.h = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.n = 1;

            if ((gb.DE.S.D & 0x0f) == 0xf)
                gb.AF.S.F.h = 1;

            if (gb.DE.S.D == 0)
                gb.AF.S.F.z = 1;

            std.log.info("DEC D", .{});
            break :blk;
        },

        // LD D,d8
        0x16 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.DE.S.D = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD D,${x:0>2}", .{gb.DE.S.D});
            break :blk;
        },

        // RLA
        0x17 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            gb.AF.S.F.h = 0;
            gb.AF.S.F.n = 0;
            gb.AF.S.F.z = 0;

            const carry: u1 = gb.AF.S.F.c;
            std.log.info("RLA before: {x:0>1} {b:0>8}", .{ gb.AF.S.F.c, gb.AF.S.A });
            gb.AF.S.F.c = @intCast(u1, ((gb.AF.S.A >> 7) & 0x01));
            gb.AF.S.A <<= 1;
            if (carry == 1)
                return GbRuntimeError.YouSuck;

            std.log.info("RLA after: {x:0>1} {b:0>8} {x:0>1} ", .{ gb.AF.S.F.c, gb.AF.S.A, carry });
            break :blk;
        },

        // JR r8
        0x18 => blk: {
            gb.PC += 1;
            const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.PC]);
            gb.PC += 1;

            std.log.info("JR {d} (true)", .{r8});
            gb.PC +%= @bitCast(u16, @intCast(i16, r8));
            break :blk;
        },

        // LD A,(DE)
        0x1A => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.AF.S.A = gb.memory.Raw[gb.DE.DE];
            std.log.info("LD A,(DE)", .{});
            break :blk;
        },

        // DEC E
        0x1D => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const value: u8 = gb.DE.S.E -% 1;
            gb.DE.S.E = value;
            gb.AF.S.F.h = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.n = 1;

            if ((gb.DE.S.E & 0x0f) == 0xf)
                gb.AF.S.F.h = 1;

            if (gb.DE.S.E == 0)
                gb.AF.S.F.z = 1;

            std.log.info("DEC E", .{});
            break :blk;
        },

        // LD D,d8
        0x1E => blk: {
            gb.PC += 1;
            gb.DE.S.D = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD D,${x:0>2}", .{gb.DE.S.D});
            break :blk;
        },

        // JR NZ,r8
        0x20 => blk: {
            gb.PC += 1;
            const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.PC]);
            gb.PC += 1;

            if (gb.AF.S.F.z != 1) {
                gb.tcycles += 12;
                std.log.info("JR NZ,{d} (true)", .{r8});
                // std.log.info("jr before PC={X:0>4}", .{gb.PC});
                gb.PC +%= @bitCast(u16, @intCast(i16, r8));
                // std.log.info("jr after PC={X:0>4}", .{gb.PC});
            } else {
                gb.tcycles += 8;
                std.log.info("JR NZ,{d} (false)", .{r8});
            }
            break :blk;
        },

        // LD HL,u16
        0x21 => blk: {
            gb.PC += 1;
            gb.tcycles += 12;

            const lsb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const msb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            gb.HL.S.H = lsb;
            gb.HL.S.L = msb;

            std.log.info("LD HL,${x:0>4}", .{gb.HL.HL});
            break :blk;
        },

        // LD (HL+),A
        0x22 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.memory.Raw[gb.HL.HL] = gb.AF.S.A;
            gb.HL.HL += 1;
            std.log.info("LD (HL+),A", .{});
            break :blk;
        },

        // INC HL
        0x23 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.HL.HL += 1;
            std.log.info("INC HL", .{});
            break :blk;
        },

        // INC H
        0x24 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            gb.HL.S.H += 1;
            gb.AF.S.F.n = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.h = 0;

            if ((gb.HL.S.H & 0x0F) == 0)
                gb.AF.S.F.h = 1;
            if (gb.HL.S.H == 0)
                gb.AF.S.F.z = 1;

            std.log.info("INC H", .{});
            break :blk;
        },

        // JR Z,r8
        0x28 => blk: {
            gb.PC += 1;
            const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.PC]);
            gb.PC += 1;

            if (gb.AF.S.F.z == 1) {
                gb.tcycles += 12;
                std.log.info("JR Z,{d} (true)", .{r8});
                // std.log.info("jr before PC={X:0>4}", .{gb.PC});
                gb.PC +%= @bitCast(u16, @intCast(i16, r8));
                // std.log.info("jr after PC={X:0>4}", .{gb.PC});
            } else {
                gb.tcycles += 8;
                std.log.info("JR Z,{d} (false)", .{r8});
            }
            break :blk;
        },

        // LD L,d8
        0x2E => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.HL.S.L = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD L,${x:0>2}", .{gb.HL.S.L});
            break :blk;
        },

        // LD SP,u16
        0x31 => blk: {
            gb.tcycles += 3;
            gb.PC += 1;

            const msb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const lsb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            gb.SP = (@as(u16, lsb) << 8) | msb;
            std.log.info("LD SP, ${x:0>4}", .{gb.SP});
            break :blk;
        },

        // LD (HL-),A
        0x32 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;

            gb.HL.HL -= 1;
            gb.memory.Raw[gb.HL.HL] = gb.AF.S.A;
            std.log.info("LD (HL-),A", .{});
            break :blk;
        },

        // DEC A
        0x3D => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const value: u8 = gb.AF.S.A -% 1;
            gb.AF.S.A = value;
            gb.AF.S.F.h = 0;
            gb.AF.S.F.z = 0;
            gb.AF.S.F.n = 1;

            if ((gb.AF.S.A & 0x0f) == 0xf)
                gb.AF.S.F.h = 1;

            if (gb.AF.S.A == 0)
                gb.AF.S.F.z = 1;

            std.log.info("DEC A", .{});
            break :blk;
        },

        // LD A,d8
        0x3E => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.AF.S.A = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            std.log.info("LD A,${x:0>2}", .{gb.AF.S.A});
            break :blk;
        },

        // LD B,D
        0x42 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.BC.S.B = gb.DE.S.D;
            std.log.info("LD B,D", .{});
            break :blk;
        },

        // LD B,H
        0x44 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.BC.S.B = gb.HL.S.H;
            std.log.info("LD B,H", .{});
            break :blk;
        },

        // LD C,A
        0x4F => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.BC.S.C = gb.AF.S.A;
            std.log.info("LD C,A", .{});
            break :blk;
        },

        // LD D,A
        0x57 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.DE.S.D = gb.AF.S.A;
            std.log.info("LD D,A", .{});
            break :blk;
        },

        // LD H,A
        0x67 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.HL.S.H = gb.AF.S.A;
            std.log.info("LD H,A", .{});
            break :blk;
        },

        // LD (HL),A
        0x77 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.memory.Raw[gb.HL.HL] = gb.AF.S.A;
            std.log.info("LD (HL),A", .{});
            break :blk;
        },

        // LD A,B
        0x78 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.AF.S.A = gb.BC.S.B;
            std.log.info("LD A,B", .{});
            break :blk;
        },

        // LD A,E
        0x7b => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.AF.S.A = gb.DE.S.E;
            std.log.info("LD A,E", .{});
            break :blk;
        },

        // LD A,H
        0x7C => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.AF.S.A = gb.HL.S.H;
            std.log.info("LD A,H", .{});
            break :blk;
        },

        // LD A,L
        0x7D => blk: {
            gb.PC += 1;
            gb.tcycles += 4;
            gb.AF.S.A = gb.HL.S.L;
            std.log.info("LD A,L", .{});
            break :blk;
        },

        // ADD A,(HL)
        0x86 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            const d8: u8 = gb.memory.Raw[gb.HL.HL];
            const a: u8 = gb.AF.S.A;
            gb.AF.S.A += d8;
            if ((a + d8) == 0)
                gb.AF.S.F.z = 1;
            if ((a & 0xf) + (d8 & 0xf) > 0x0f)
                gb.AF.S.F.h = 1;
            if ((a + d8) > 0xff)
                gb.AF.S.F.c = 1;

            std.log.info("ADD A,(HL)", .{});
            break :blk;
        },

        // SUB B
        0x90 => blk: {
            gb.PC += 1;
            gb.tcycles += 4;

            const d8: u8 = gb.BC.S.B;
            const a: u8 = gb.AF.S.A;
            gb.AF.S.A -%= d8;
            gb.AF.S.F.n = 1;

            if (a == d8)
                gb.AF.S.F.z = 1;

            if ((a & 0xf) < (d8 & 0xf))
                gb.AF.S.F.h = 1;

            if (a < d8)
                gb.AF.S.F.c = 1;

            std.log.info("SUB B", .{});
            break :blk;
        },

        // XOR A
        0xAF => blk: {
            gb.PC += 1;
            gb.tcycles += 1;
            const A: u8 = gb.AF.S.A;
            const value: u8 = A ^ A;
            gb.AF.S.A = value;
            if (value == 0) {
                gb.AF.S.F.z = 1;
            }
            std.log.info("XOR A", .{});
            break :blk;
        },

        // CP (HL)
        0xBE => blk: {
            gb.PC += 1;
            gb.tcycles += 8;

            const d8: u8 = gb.memory.Raw[gb.HL.HL];
            const a: u8 = gb.AF.S.A;
            // clear all flags?
            gb.AF.AF &= 0xFF00;
            gb.AF.S.F.n = 1;

            if (a == d8)
                gb.AF.S.F.z = 1;

            if ((a & 0xf) < (d8 & 0xf))
                gb.AF.S.F.h = 1;

            if (a < d8)
                gb.AF.S.F.h = 1;

            std.log.info("CP (HL)", .{});
            break :blk;
        },

        // POP BC
        0xC1 => blk: {
            gb.PC += 1;
            gb.tcycles += 16;

            const msb: u8 = gb.memory.Raw[gb.SP];
            gb.SP += 1;
            gb.BC.S.C = msb;

            const lsb: u8 = gb.memory.Raw[gb.SP];
            gb.SP += 1;
            gb.BC.S.B = lsb;
            std.log.info("POP BC {x:0>4}", .{gb.BC.BC});
            break :blk;
        },

        // PUSH BC
        0xC5 => blk: {
            gb.PC += 1;
            gb.tcycles += 16;

            gb.SP -= 1;
            gb.memory.Raw[gb.SP] = gb.BC.S.B;

            gb.SP -= 1;
            gb.memory.Raw[gb.SP] = gb.BC.S.C;

            std.log.info("PUSH BC {x:0>4}", .{gb.BC.BC});
            break :blk;
        },

        // RET
        0xC9 => blk: {
            gb.PC += 1;
            gb.tcycles += 16;

            const msb: u8 = gb.memory.Raw[gb.SP];
            gb.SP += 1;

            const lsb: u8 = gb.memory.Raw[gb.SP];
            gb.SP += 1;

            const nn: u16 = (@as(u16, lsb) << 8) | msb;
            gb.PC = nn;
            std.log.info("RET ${x:0>4}", .{nn});
            break :blk;
        },

        // Pefix CB
        0xCB => {
            gb.PC += 1;
            gb.tcycles += 4;
            switch (gb.memory.Raw[gb.PC]) {
                // RL C
                0x11 => cblk: {
                    gb.PC += 1;
                    gb.tcycles += 8;
                    gb.AF.S.F.h = 0;
                    gb.AF.S.F.n = 0;

                    const carry: u1 = gb.AF.S.F.c;
                    std.log.info("RL C before: {x:0>1} {b:0>8}", .{ gb.AF.S.F.c, gb.BC.S.C });
                    gb.AF.S.F.c = @intCast(u1, ((gb.BC.S.C >> 7) & 0x01));
                    gb.BC.S.C <<= 1;

                    if (carry == 1) {
                        gb.BC.S.C |= 0x1 << 0;
                    }

                    if (gb.BC.S.C == 0) {
                        gb.AF.S.F.z = 1;
                    } else {
                        gb.AF.S.F.z = 0;
                    }

                    std.log.info("RL C after: {x:0>1} {b:0>8} {x:0>1} ", .{ gb.AF.S.F.c, gb.BC.S.C, carry });
                    break :cblk;
                },
                // BIT 7, H
                0x7C => cblk: {
                    gb.PC += 1;
                    gb.tcycles += 8;
                    gb.AF.S.F.h = 1;
                    gb.AF.S.F.n = 0;
                    gb.AF.S.F.z = @intCast(u1, ((gb.HL.S.H >> 7) & 0x01));
                    std.log.info("BIT 7, H {B:0>1}", .{gb.AF.S.F});
                    break :cblk;
                },
                else => cblk: {
                    gb.running = false;
                    std.log.info("Unimplemented CB Instruction 0x{X}", .{gb.memory.Raw[gb.PC]});
                    std.log.info("Flags={B:0>1}", .{gb.AF.S.F});
                    break :cblk return GbRuntimeError.InstructionNotImplemented;
                },
            }
        },

        // CALL nn
        0xCD => blk: {
            gb.PC += 1;
            gb.tcycles += 24;

            const msb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const lsb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const nn: u16 = (@as(u16, lsb) << 8) | msb;

            gb.SP -= 1;
            gb.memory.Raw[gb.SP] = @intCast(u8, gb.PC >> 8);
            gb.SP -= 1;
            gb.memory.Raw[gb.SP] = @truncate(u8, gb.PC);

            gb.PC = nn;
            std.log.info("CALL ${x:0>4}", .{nn});
            break :blk;
        },

        // LDH (a8), A
        // LD ($FF00+a8),A
        0xE0 => blk: {
            gb.PC += 1;
            gb.tcycles += 12;
            const a8: u16 = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            gb.memory.Raw[0xFF00 + a8] = gb.AF.S.A;
            std.log.info("LD ($FF00+${x:0>2}),A", .{a8});
            break :blk;
        },

        // LD ($FF00+C),A
        0xE2 => blk: {
            gb.PC += 1;
            gb.tcycles += 8;
            gb.memory.Raw[0xFF00 + @intCast(u16, gb.BC.S.C)] = gb.AF.S.A;
            std.log.info("LD ($FF00+{X:0>2}),A", .{gb.BC.S.C});
            break :blk;
        },

        // LD (a16),A
        0xEA => blk: {
            gb.PC += 1;
            gb.tcycles += 16;

            const msb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            const lsb: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;

            gb.memory.Raw[(@as(u16, lsb) << 8) | msb] = gb.AF.S.A;
            std.log.info("LD (${x:0>4}),A", .{(@as(u16, lsb) << 8) | msb});
            break :blk;
        },

        // LDH A,(a8)
        0xF0 => blk: {
            gb.PC += 1;
            gb.tcycles += 12;

            const a8: u16 = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            gb.AF.S.A = gb.memory.Raw[0xff00 + a8];
            std.log.info("LDH A,(${x:0>2})=${x:0>2}", .{ a8, gb.AF.S.A });
            break :blk;
        },

        // CP d8
        0xFE => blk: {
            gb.PC += 1;
            gb.tcycles += 8;

            const d8: u8 = gb.memory.Raw[gb.PC];
            gb.PC += 1;
            const a: u8 = gb.AF.S.A;

            gb.AF.AF &= 0xFF00;
            gb.AF.S.F.n = 1;

            std.log.info("a=${x:0>2}", .{a});

            if (a == d8)
                gb.AF.S.F.z = 1;

            if ((a & 0xf) < (d8 & 0xf))
                gb.AF.S.F.h = 1;

            if (a < d8)
                gb.AF.S.F.h = 1;

            std.log.info("CP ${x:0>2} ${B:0>1}", .{ d8, gb.AF.S.F });
            break :blk;
        },

        else => blk: {
            gb.running = false;
            std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ gb.PC, gb.memory.Raw[gb.PC] });
            std.log.info("Flags={B:0>1}", .{gb.AF.S.F});
            break :blk return GbRuntimeError.InstructionNotImplemented;
        },
    }
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var state = Gb.init();
    const bootrom = try std.fs.cwd().openFile(
        "DMG_ROM.bin",
        .{ .read = true },
    );
    defer bootrom.close();
    try bootrom.seekTo(0);
    _ = try bootrom.readAll(&state.memory.Raw);

    // const rom = try std.fs.cwd().openFile(
    //     "gb-test-roms-master/cpu_instrs/cpu_instrs.gb",
    //     .{ .read = true },
    // );
    // defer rom.close();
    // try rom.seekTo(0);
    // _ = try bootrom.readAll(&state.memory.S.rom0);

    _ = try bootrom.readAll(&state.memory.Raw);

    while (state.running) {
        try step(&state);
    }
}
