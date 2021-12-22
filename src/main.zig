const std = @import("std");

const LameboyRuntimeError = error{ InstructionNotImplemented, YouSuck };

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
    // if(lameboy.PC == 0x0018) {
    //     std.log.info("{x:0>2}", .{lameboy.memory.Raw[lameboy.PC]});
    //     return LameboyRuntimeError.YouSuck;
    // }
    switch (lameboy.memory.Raw[lameboy.PC]) {
        0 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            std.log.info("NOP", .{});
            break :blk;
        },

        // INC B
        0x04 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 0;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.BC.S.B & 0xf) + (1 & 0xf)) * 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.BC.S.B += 1;

            // set z if resulting sum was 0
            if (lameboy.BC.S.B == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("INC B", .{});
            break :blk;
        },

        // DEC B
        0x05 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.BC.S.B & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.BC.S.B -= 1;

            // set z if resulting sum was 0
            if (lameboy.BC.S.B == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("DEC B", .{});
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
            lameboy.AF.S.F.c = 0;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.BC.S.C & 0xf) + (1 & 0xf)) * 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.BC.S.C += 1;

            // set z if resulting sum was 0
            if (lameboy.BC.S.C == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("INC C", .{});
            break :blk;
        },

        // DEC C
        0x0D => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.BC.S.C & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.BC.S.C -%= 1;

            // set z if resulting sum was 0
            if (lameboy.BC.S.C == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("DEC C", .{});
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

        // INC DE
        0x13 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.DE.DE += 1;
            std.log.info("INC DE", .{});
            break :blk;
        },

        // DEC D
        0x15 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.DE.S.D & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.DE.S.D -%= 1;

            // set z if resulting sum was 0
            if (lameboy.DE.S.D == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("DEC D", .{});
            break :blk;
        },

        // LD D,d8
        0x16 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.DE.S.D = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            std.log.info("LD D,${x:0>2}", .{lameboy.DE.S.D});
            break :blk;
        },

        // RLA
        0x17 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;

            lameboy.AF.S.F.h = 0;
            lameboy.AF.S.F.n = 0;
            lameboy.AF.S.F.z = 0;

            const carry: u1 = lameboy.AF.S.F.c;
            std.log.info("RLA before: {x:0>1} {b:0>8}", .{ lameboy.AF.S.F.c, lameboy.AF.S.A });
            lameboy.AF.S.F.c = @intCast(u1, ((lameboy.AF.S.A >> 7) & 0x01));
            lameboy.AF.S.A <<= 1;
            if (carry == 1)
                return LameboyRuntimeError.YouSuck;

            std.log.info("RLA after: {x:0>1} {b:0>8} {x:0>1} ", .{ lameboy.AF.S.F.c, lameboy.AF.S.A, carry });
            break :blk;
        },

        // JR r8
        0x18 => blk: {
            lameboy.PC += 1;
            const r8: i8 = @bitCast(i8, lameboy.memory.Raw[lameboy.PC]);
            lameboy.PC += 1;

            std.log.info("JR {d} (true)", .{r8});
            lameboy.PC +%= @bitCast(u16, @intCast(i16, r8));
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

        // DEC E
        0x1D => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.DE.S.E & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.DE.S.E -%= 1;

            // set z if resulting sum was 0
            if (lameboy.DE.S.E == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("DEC E", .{});
            break :blk;
        },

        // LD D,d8
        0x1E => blk: {
            lameboy.PC += 1;
            lameboy.DE.S.D = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            std.log.info("LD D,${x:0>2}", .{lameboy.DE.S.D});
            break :blk;
        },

        // JR NZ,r8
        0x20 => blk: {
            lameboy.PC += 1;
            const r8: i8 = @bitCast(i8, lameboy.memory.Raw[lameboy.PC]);
            lameboy.PC += 1;

            if (lameboy.AF.S.F.z != 0) {
                lameboy.tcycles += 12;
                std.log.info("JR NZ,{d} (true)", .{r8});
                // std.log.info("jr before PC={X:0>4}", .{lameboy.PC});
                lameboy.PC +%= @bitCast(u16, @intCast(i16, r8));
                // std.log.info("jr after PC={X:0>4}", .{lameboy.PC});
            } else {
                lameboy.tcycles += 8;
                std.log.info("JR NZ,{d} (false)", .{r8});
            }
            break :blk;
        },

        // LD HL,u16
        0x21 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            lameboy.HL.S.H = lsb;
            lameboy.HL.S.L = msb;

            std.log.info("LD HL,${x:0>4}", .{lameboy.HL.HL});
            break :blk;
        },

        // LD (HL+),A
        0x22 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.memory.Raw[lameboy.HL.HL] = lameboy.AF.S.A;
            lameboy.HL.HL += 1;
            std.log.info("LD (HL+),A", .{});
            break :blk;
        },

        // INC HL
        0x23 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            lameboy.HL.HL += 1;
            std.log.info("INC HL", .{});
            break :blk;
        },

        // INC H
        0x24 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.HL.S.H & 0xf) +% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.HL.S.H -%= 1;

            // set z if resulting sum was 0
            if (lameboy.HL.S.H == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("INC H", .{});
            break :blk;
        },

        0x28 => blk: {
            lameboy.PC += 1;
            const r8: i8 = @bitCast(i8, lameboy.memory.Raw[lameboy.PC]);
            lameboy.PC += 1;

            if (lameboy.AF.S.F.z == 0) {
                lameboy.tcycles += 12;
                std.log.info("JR Z,{d} (true)", .{r8});
                // std.log.info("jr before PC={X:0>4}", .{lameboy.PC});
                lameboy.PC +%= @bitCast(u16, @intCast(i16, r8));
                // std.log.info("jr after PC={X:0>4}", .{lameboy.PC});
            } else {
                lameboy.tcycles += 8;
                std.log.info("JR Z,{d} (false)", .{r8});
            }
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
            std.log.info("LD SP, ${x:0>4}", .{lameboy.SP});
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

        // DEC A
        0x3D => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.F.c = 1;

            // set half-carry if we carried from one nybl to the other
            if (((lameboy.AF.S.A & 0xf) - (1 & 0xf)) * 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            lameboy.AF.S.A -= 1;

            // set z if resulting sum was 0
            if (lameboy.AF.S.A == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            std.log.info("DEC A", .{});
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

        // LD B,D
        0x42 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.BC.S.B = lameboy.DE.S.D;
            std.log.info("LD B,D", .{});
            break :blk;
        },

        // LD B,H
        0x44 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.BC.S.B = lameboy.HL.S.H;
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

        // LD D,A
        0x57 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.DE.S.D = lameboy.AF.S.A;
            std.log.info("LD D,A", .{});
            break :blk;
        },

        // LD H,A
        0x67 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.HL.S.H = lameboy.AF.S.A;
            std.log.info("LD H,A", .{});
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

        // LD A,E
        0x7b => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.A = lameboy.DE.S.E;
            std.log.info("LD A,E", .{});
            break :blk;
        },

        // LD A,H
        0x7C => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            lameboy.AF.S.A = lameboy.HL.S.H;
            std.log.info("LD A,H", .{});
            break :blk;
        },

        // SUB B
        0x90 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 4;

            const cp: u8 = lameboy.AF.S.A -% lameboy.BC.S.B;
            lameboy.AF.S.F.n = 1;

            if (cp == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            if (((cp & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            if (lameboy.BC.S.B > lameboy.AF.S.A) {
                lameboy.AF.S.F.c = 1;
            } else {
                lameboy.AF.S.F.c = 0;
            }

            lameboy.AF.S.A = cp;

            std.log.info("SUB B", .{});
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
            std.log.info("XOR A", .{});
            break :blk;
        },

        // POP BC
        0xC1 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 16;

            const msb: u8 = lameboy.memory.Raw[lameboy.SP];
            lameboy.SP += 1;
            lameboy.BC.S.C = msb;

            const lsb: u8 = lameboy.memory.Raw[lameboy.SP];
            lameboy.SP += 1;
            lameboy.BC.S.B = lsb;
            std.log.info("POP BC {x:0>4}", .{lameboy.BC.BC});
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

            std.log.info("PUSH BC {x:0>4}", .{lameboy.BC.BC});
            break :blk;
        },

        // RET
        0xC9 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 16;

            const msb: u8 = lameboy.memory.Raw[lameboy.SP];
            lameboy.SP += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.SP];
            lameboy.SP += 1;

            const nn: u16 = (@as(u16, lsb) << 8) | msb;
            lameboy.PC = nn;
            std.log.info("RET ${x:0>4}", .{nn});
            break :blk;
        },

        // Pefix CB
        0xCB => {
            lameboy.PC += 1;
            lameboy.tcycles += 4;
            switch (lameboy.memory.Raw[lameboy.PC]) {
                // RL C
                0x11 => cblk: {
                    lameboy.PC += 1;
                    lameboy.tcycles += 8;
                    lameboy.AF.S.F.h = 0;
                    lameboy.AF.S.F.n = 0;

                    const carry: u1 = lameboy.AF.S.F.c;
                    std.log.info("RL C before: {x:0>1} {b:0>8}", .{ lameboy.AF.S.F.c, lameboy.BC.S.C });
                    lameboy.AF.S.F.c = @intCast(u1, ((lameboy.BC.S.C >> 7) & 0x01));
                    lameboy.BC.S.C <<= 1;

                    if (carry == 1) {
                        lameboy.BC.S.C |= 0x1 << 0;
                    }

                    if (lameboy.BC.S.C == 0) {
                        lameboy.AF.S.F.z = 1;
                    } else {
                        lameboy.AF.S.F.z = 0;
                    }

                    std.log.info("RL C after: {x:0>1} {b:0>8} {x:0>1} ", .{ lameboy.AF.S.F.c, lameboy.BC.S.C, carry });
                    break :cblk;
                },
                // BIT 7, H
                0x7C => cblk: {
                    lameboy.PC += 1;
                    lameboy.tcycles += 8;
                    lameboy.AF.S.F.h = 1;
                    lameboy.AF.S.F.n = 0;
                    lameboy.AF.S.F.z = @intCast(u1, ((lameboy.HL.S.H >> 7) & 0x01));
                    std.log.info("BIT 7, H {B:0>1}", .{lameboy.AF.S.F});
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
        // LD ($FF00+a8),A
        0xE0 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;
            const a8: u16 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;
            lameboy.memory.Raw[0xFF00 + a8] = lameboy.AF.S.A;
            std.log.info("LD ($FF00+${x:0>2}),A", .{a8});
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

        // LD (a16),A
        0xEA => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 16;

            const msb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const lsb: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            lameboy.memory.Raw[(@as(u16, lsb) << 8) | msb] = lameboy.AF.S.A;
            std.log.info("LD (${x:0>4}),A", .{(@as(u16, lsb) << 8) | msb});
            break :blk;
        },

        // LDH A,(a8)
        0xF0 => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 12;

            const a8: u16 = lameboy.memory.Raw[lameboy.PC];
            lameboy.AF.S.A = lameboy.memory.Raw[0xff00 + a8];
            std.log.info("LDH A,(${x:0>2})", .{a8});
            break :blk;
        },

        // CP d8
        0xFE => blk: {
            lameboy.PC += 1;
            lameboy.tcycles += 8;
            const d8: u8 = lameboy.memory.Raw[lameboy.PC];
            lameboy.PC += 1;

            const cp: u8 = lameboy.AF.S.A -% d8;
            lameboy.AF.S.F.n = 1;

            if (cp == 0) {
                lameboy.AF.S.F.z = 1;
            } else {
                lameboy.AF.S.F.z = 0;
            }

            if (((cp & 0xf) -% (1 & 0xf)) *% 0x10 == 0x10) {
                lameboy.AF.S.F.h = 1;
            } else {
                lameboy.AF.S.F.h = 0;
            }

            if (d8 > lameboy.AF.S.A) {
                lameboy.AF.S.F.c = 1;
            } else {
                lameboy.AF.S.F.c = 0;
            }

            std.log.info("CP ${x:0>2}", .{d8});
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
