const std = @import("std");

const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;

pub const RuntimeError = error{ InstructionNotImplemented, YouSuck };

pub const Core = struct {
    cpu: CPU,
    memory: Memory,
    tCycles: u64,
    halt: bool,
    debugStop: bool,

    pub fn init() Core {
        return Core{
            .cpu = CPU.init(),
            .memory = Memory.init(),
            .tCycles = 0,
            .halt = false,
            .debugStop = false,
        };
    }

    pub fn step(gb: *Core) !void {
        std.log.info("\tPC=0x{x:0>2} OP=0x{x:0>2}", .{ gb.cpu.PC, gb.memory.Raw[gb.cpu.PC] });
        // try break_step();

        switch (gb.memory.Raw[gb.cpu.PC]) {
            0 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                std.log.info("NOP", .{});
                gb.halt = true;
                break :blk;
            },

            // INC B
            0x04 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                gb.cpu.BC.S.B += 1;
                gb.cpu.AF.S.F.n = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.h = 0;

                if ((gb.cpu.BC.S.B & 0x0F) == 0)
                    gb.cpu.AF.S.F.h = 1;
                if (gb.cpu.BC.S.B == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("INC B", .{});
                break :blk;
            },

            // DEC B
            0x05 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const value: u8 = gb.cpu.BC.S.B -% 1;
                gb.cpu.BC.S.B = value;
                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.n = 1;

                if ((gb.cpu.BC.S.B & 0x0f) == 0xf)
                    gb.cpu.AF.S.F.h = 1;

                if (gb.cpu.BC.S.B == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("DEC B", .{});
                break :blk;
            },

            // LD B,d8
            0x06 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.BC.S.B = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD B,${x:0>2}", .{gb.cpu.BC.S.B});
                break :blk;
            },

            // INC C
            0x0C => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                gb.cpu.BC.S.C += 1;
                gb.cpu.AF.S.F.n = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.h = 0;

                if ((gb.cpu.BC.S.C & 0x0F) == 0)
                    gb.cpu.AF.S.F.h = 1;
                if (gb.cpu.BC.S.C == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("INC C", .{});
                break :blk;
            },

            // DEC C
            0x0D => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const value: u8 = gb.cpu.BC.S.C -% 1;
                gb.cpu.BC.S.C = value;
                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.n = 1;

                if ((gb.cpu.BC.S.C & 0x0f) == 0xf)
                    gb.cpu.AF.S.F.h = 1;

                if (gb.cpu.BC.S.C == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("DEC C", .{});
                break :blk;
            },

            // LD C,d8
            0x0E => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.BC.S.C = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD C,${x:0>2}", .{gb.cpu.BC.S.C});
                break :blk;
            },

            // LD DE,d16
            0x11 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;

                const msb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const lsb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                gb.cpu.DE.DE = (@as(u16, lsb) << 8) | msb;
                std.log.info("LD DE,${x:0>4}", .{(@as(u16, lsb) << 8) | msb});
                break :blk;
            },

            // INC DE
            0x13 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.DE.DE += 1;
                std.log.info("INC DE", .{});
                break :blk;
            },

            // DEC D
            0x15 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const value: u8 = gb.cpu.DE.S.D -% 1;
                gb.cpu.DE.S.D = value;
                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.n = 1;

                if ((gb.cpu.DE.S.D & 0x0f) == 0xf)
                    gb.cpu.AF.S.F.h = 1;

                if (gb.cpu.DE.S.D == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("DEC D", .{});
                break :blk;
            },

            // LD D,d8
            0x16 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.DE.S.D = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD D,${x:0>2}", .{gb.cpu.DE.S.D});
                break :blk;
            },

            // RLA
            0x17 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.n = 0;
                gb.cpu.AF.S.F.z = 0;

                const carry: u1 = gb.cpu.AF.S.F.c;
                std.log.info("RLA before: {x:0>1} {b:0>8}", .{ gb.cpu.AF.S.F.c, gb.cpu.AF.S.A });
                gb.cpu.AF.S.F.c = @intCast(u1, ((gb.cpu.AF.S.A >> 7) & 0x01));
                gb.cpu.AF.S.A <<= 1;
                if (carry == 1)
                    return RuntimeError.YouSuck;

                std.log.info("RLA after: {x:0>1} {b:0>8} {x:0>1} ", .{ gb.cpu.AF.S.F.c, gb.cpu.AF.S.A, carry });
                break :blk;
            },

            // JR r8
            0x18 => blk: {
                gb.cpu.PC += 1;
                const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.cpu.PC]);
                gb.cpu.PC += 1;

                std.log.info("JR {d} (true)", .{r8});
                gb.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
                break :blk;
            },

            // LD A,(DE)
            0x1A => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.AF.S.A = gb.memory.Raw[gb.cpu.DE.DE];
                std.log.info("LD A,(DE)", .{});
                break :blk;
            },

            // DEC E
            0x1D => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const value: u8 = gb.cpu.DE.S.E -% 1;
                gb.cpu.DE.S.E = value;
                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.n = 1;

                if ((gb.cpu.DE.S.E & 0x0f) == 0xf)
                    gb.cpu.AF.S.F.h = 1;

                if (gb.cpu.DE.S.E == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("DEC E", .{});
                break :blk;
            },

            // LD D,d8
            0x1E => blk: {
                gb.cpu.PC += 1;
                gb.cpu.DE.S.D = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD D,${x:0>2}", .{gb.cpu.DE.S.D});
                break :blk;
            },

            // JR NZ,r8
            0x20 => blk: {
                gb.cpu.PC += 1;
                const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.cpu.PC]);
                gb.cpu.PC += 1;

                if (gb.cpu.AF.S.F.z != 1) {
                    gb.tCycles += 12;
                    std.log.info("JR NZ,{d} (true)", .{r8});
                    // std.log.info("jr before PC={X:0>4}", .{gb.cpu.PC});
                    gb.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
                    // std.log.info("jr after PC={X:0>4}", .{gb.cpu.PC});
                } else {
                    gb.tCycles += 8;
                    std.log.info("JR NZ,{d} (false)", .{r8});
                }
                break :blk;
            },

            // LD HL,u16
            0x21 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;

                const lsb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const msb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                gb.cpu.HL.S.H = lsb;
                gb.cpu.HL.S.L = msb;

                std.log.info("LD HL,${x:0>4}", .{gb.cpu.HL.HL});
                break :blk;
            },

            // LD (HL+),A
            0x22 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.memory.Raw[gb.cpu.HL.HL] = gb.cpu.AF.S.A;
                gb.cpu.HL.HL += 1;
                std.log.info("LD (HL+),A", .{});
                break :blk;
            },

            // INC HL
            0x23 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.HL.HL += 1;
                std.log.info("INC HL", .{});
                break :blk;
            },

            // INC H
            0x24 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                gb.cpu.HL.S.H += 1;
                gb.cpu.AF.S.F.n = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.h = 0;

                if ((gb.cpu.HL.S.H & 0x0F) == 0)
                    gb.cpu.AF.S.F.h = 1;
                if (gb.cpu.HL.S.H == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("INC H", .{});
                break :blk;
            },

            // JR Z,r8
            0x28 => blk: {
                gb.cpu.PC += 1;
                const r8: i8 = @bitCast(i8, gb.memory.Raw[gb.cpu.PC]);
                gb.cpu.PC += 1;

                if (gb.cpu.AF.S.F.z == 1) {
                    gb.tCycles += 12;
                    std.log.info("JR Z,{d} (true)", .{r8});
                    // std.log.info("jr before PC={X:0>4}", .{gb.cpu.PC});
                    gb.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
                    // std.log.info("jr after PC={X:0>4}", .{gb.cpu.PC});
                } else {
                    gb.tCycles += 8;
                    std.log.info("JR Z,{d} (false)", .{r8});
                }
                break :blk;
            },

            // LD L,d8
            0x2E => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.HL.S.L = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD L,${x:0>2}", .{gb.cpu.HL.S.L});
                break :blk;
            },

            // LD SP,u16
            0x31 => blk: {
                gb.tCycles += 3;
                gb.cpu.PC += 1;

                const msb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const lsb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                gb.cpu.SP = (@as(u16, lsb) << 8) | msb;
                std.log.info("LD SP, ${x:0>4}", .{gb.cpu.SP});
                break :blk;
            },

            // LD (HL-),A
            0x32 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;

                gb.cpu.HL.HL -= 1;
                gb.memory.Raw[gb.cpu.HL.HL] = gb.cpu.AF.S.A;
                std.log.info("LD (HL-),A", .{});
                break :blk;
            },

            // DEC A
            0x3D => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const value: u8 = gb.cpu.AF.S.A -% 1;
                gb.cpu.AF.S.A = value;
                gb.cpu.AF.S.F.h = 0;
                gb.cpu.AF.S.F.z = 0;
                gb.cpu.AF.S.F.n = 1;

                if ((gb.cpu.AF.S.A & 0x0f) == 0xf)
                    gb.cpu.AF.S.F.h = 1;

                if (gb.cpu.AF.S.A == 0)
                    gb.cpu.AF.S.F.z = 1;

                std.log.info("DEC A", .{});
                break :blk;
            },

            // LD A,d8
            0x3E => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.cpu.AF.S.A = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                std.log.info("LD A,${x:0>2}", .{gb.cpu.AF.S.A});
                break :blk;
            },

            // LD B,D
            0x42 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.BC.S.B = gb.cpu.DE.S.D;
                std.log.info("LD B,D", .{});
                break :blk;
            },

            // LD B,H
            0x44 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.BC.S.B = gb.cpu.HL.S.H;
                std.log.info("LD B,H", .{});
                break :blk;
            },

            // LD C,A
            0x4F => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.BC.S.C = gb.cpu.AF.S.A;
                std.log.info("LD C,A", .{});
                break :blk;
            },

            // LD D,A
            0x57 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.DE.S.D = gb.cpu.AF.S.A;
                std.log.info("LD D,A", .{});
                break :blk;
            },

            // LD H,A
            0x67 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.HL.S.H = gb.cpu.AF.S.A;
                std.log.info("LD H,A", .{});
                break :blk;
            },

            // LD (HL),A
            0x77 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.memory.Raw[gb.cpu.HL.HL] = gb.cpu.AF.S.A;
                std.log.info("LD (HL),A", .{});
                break :blk;
            },

            // LD A,B
            0x78 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.AF.S.A = gb.cpu.BC.S.B;
                std.log.info("LD A,B", .{});
                break :blk;
            },

            // LD A,E
            0x7b => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.AF.S.A = gb.cpu.DE.S.E;
                std.log.info("LD A,E", .{});
                break :blk;
            },

            // LD A,H
            0x7C => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.AF.S.A = gb.cpu.HL.S.H;
                std.log.info("LD A,H", .{});
                break :blk;
            },

            // LD A,L
            0x7D => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                gb.cpu.AF.S.A = gb.cpu.HL.S.L;
                std.log.info("LD A,L", .{});
                break :blk;
            },

            // ADD A,(HL)
            0x86 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                const d8: u8 = gb.memory.Raw[gb.cpu.HL.HL];
                const a: u8 = gb.cpu.AF.S.A;
                gb.cpu.AF.S.A += d8;
                if ((a + d8) == 0)
                    gb.cpu.AF.S.F.z = 1;
                if ((a & 0xf) + (d8 & 0xf) > 0x0f)
                    gb.cpu.AF.S.F.h = 1;
                if ((a + d8) > 0xff)
                    gb.cpu.AF.S.F.c = 1;

                std.log.info("ADD A,(HL)", .{});
                break :blk;
            },

            // SUB B
            0x90 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 4;

                const d8: u8 = gb.cpu.BC.S.B;
                const a: u8 = gb.cpu.AF.S.A;
                gb.cpu.AF.S.A -%= d8;
                gb.cpu.AF.S.F.n = 1;

                if (a == d8)
                    gb.cpu.AF.S.F.z = 1;

                if ((a & 0xf) < (d8 & 0xf))
                    gb.cpu.AF.S.F.h = 1;

                if (a < d8)
                    gb.cpu.AF.S.F.c = 1;

                std.log.info("SUB B", .{});
                break :blk;
            },

            // XOR A
            0xAF => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 1;
                const A: u8 = gb.cpu.AF.S.A;
                const value: u8 = A ^ A;
                gb.cpu.AF.S.A = value;
                if (value == 0) {
                    gb.cpu.AF.S.F.z = 1;
                }
                std.log.info("XOR A", .{});
                break :blk;
            },

            // CP (HL)
            0xBE => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;

                const d8: u8 = gb.memory.Raw[gb.cpu.HL.HL];
                const a: u8 = gb.cpu.AF.S.A;
                // clear all flags?
                gb.cpu.AF.AF &= 0xFF00;
                gb.cpu.AF.S.F.n = 1;

                if (a == d8)
                    gb.cpu.AF.S.F.z = 1;

                if ((a & 0xf) < (d8 & 0xf))
                    gb.cpu.AF.S.F.h = 1;

                if (a < d8)
                    gb.cpu.AF.S.F.h = 1;

                std.log.info("CP (HL)", .{});
                break :blk;
            },

            // POP BC
            0xC1 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 16;

                const msb: u8 = gb.memory.Raw[gb.cpu.SP];
                gb.cpu.SP += 1;
                gb.cpu.BC.S.C = msb;

                const lsb: u8 = gb.memory.Raw[gb.cpu.SP];
                gb.cpu.SP += 1;
                gb.cpu.BC.S.B = lsb;
                std.log.info("POP BC {x:0>4}", .{gb.cpu.BC.BC});
                break :blk;
            },

            // PUSH BC
            0xC5 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 16;

                gb.cpu.SP -= 1;
                gb.memory.Raw[gb.cpu.SP] = gb.cpu.BC.S.B;

                gb.cpu.SP -= 1;
                gb.memory.Raw[gb.cpu.SP] = gb.cpu.BC.S.C;

                std.log.info("PUSH BC {x:0>4}", .{gb.cpu.BC.BC});
                break :blk;
            },

            // RET
            0xC9 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 16;

                const msb: u8 = gb.memory.Raw[gb.cpu.SP];
                gb.cpu.SP += 1;

                const lsb: u8 = gb.memory.Raw[gb.cpu.SP];
                gb.cpu.SP += 1;

                const nn: u16 = (@as(u16, lsb) << 8) | msb;
                gb.cpu.PC = nn;
                std.log.info("RET ${x:0>4}", .{nn});
                break :blk;
            },

            // Pefix CB
            0xCB => {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                switch (gb.memory.Raw[gb.cpu.PC]) {
                    // RL C
                    0x11 => cblk: {
                        gb.cpu.PC += 1;
                        gb.tCycles += 8;
                        gb.cpu.AF.S.F.h = 0;
                        gb.cpu.AF.S.F.n = 0;

                        const carry: u1 = gb.cpu.AF.S.F.c;
                        std.log.info("RL C before: {x:0>1} {b:0>8}", .{ gb.cpu.AF.S.F.c, gb.cpu.BC.S.C });
                        gb.cpu.AF.S.F.c = @intCast(u1, ((gb.cpu.BC.S.C >> 7) & 0x01));
                        gb.cpu.BC.S.C <<= 1;

                        if (carry == 1) {
                            gb.cpu.BC.S.C |= 0x1 << 0;
                        }

                        if (gb.cpu.BC.S.C == 0) {
                            gb.cpu.AF.S.F.z = 1;
                        } else {
                            gb.cpu.AF.S.F.z = 0;
                        }

                        std.log.info("RL C after: {x:0>1} {b:0>8} {x:0>1} ", .{ gb.cpu.AF.S.F.c, gb.cpu.BC.S.C, carry });
                        break :cblk;
                    },
                    // BIT 7, H
                    0x7C => cblk: {
                        gb.cpu.PC += 1;
                        gb.tCycles += 8;
                        gb.cpu.AF.S.F.h = 1;
                        gb.cpu.AF.S.F.n = 0;
                        gb.cpu.AF.S.F.z = @intCast(u1, ((gb.cpu.HL.S.H >> 7) & 0x01));
                        std.log.info("BIT 7, H {B:0>1}", .{gb.cpu.AF.S.F});
                        break :cblk;
                    },
                    else => cblk: {
                        gb.halt = true;
                        std.log.info("Unimplemented CB Instruction 0x{X}", .{gb.memory.Raw[gb.cpu.PC]});
                        std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                        break :cblk return RuntimeError.InstructionNotImplemented;
                    },
                }
            },

            // CALL nn
            0xCD => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 24;

                const msb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const lsb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const nn: u16 = (@as(u16, lsb) << 8) | msb;

                gb.cpu.SP -= 1;
                gb.memory.Raw[gb.cpu.SP] = @intCast(u8, gb.cpu.PC >> 8);
                gb.cpu.SP -= 1;
                gb.memory.Raw[gb.cpu.SP] = @truncate(u8, gb.cpu.PC);

                gb.cpu.PC = nn;
                std.log.info("CALL ${x:0>4}", .{nn});
                break :blk;
            },

            // LDH (a8), A
            // LD ($FF00+a8),A
            0xE0 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;
                const a8: u16 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                gb.memory.Raw[0xFF00 + a8] = gb.cpu.AF.S.A;
                std.log.info("LD ($FF00+${x:0>2}),A", .{a8});
                break :blk;
            },

            // LD ($FF00+C),A
            0xE2 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.memory.Raw[0xFF00 + @intCast(u16, gb.cpu.BC.S.C)] = gb.cpu.AF.S.A;
                std.log.info("LD ($FF00+{X:0>2}),A", .{gb.cpu.BC.S.C});
                break :blk;
            },

            // LD (a16),A
            0xEA => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 16;

                const msb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                const lsb: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;

                gb.memory.Raw[(@as(u16, lsb) << 8) | msb] = gb.cpu.AF.S.A;
                std.log.info("LD (${x:0>4}),A", .{(@as(u16, lsb) << 8) | msb});
                break :blk;
            },

            // LDH A,(a8)
            0xF0 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;

                const a8: u16 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                gb.cpu.AF.S.A = gb.memory.Raw[0xff00 + a8];
                std.log.info("LDH A,(${x:0>2})=${x:0>2}", .{ a8, gb.cpu.AF.S.A });
                break :blk;
            },

            // CP d8
            0xFE => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;

                const d8: u8 = gb.memory.Raw[gb.cpu.PC];
                gb.cpu.PC += 1;
                const a: u8 = gb.cpu.AF.S.A;

                gb.cpu.AF.AF &= 0xFF00;
                gb.cpu.AF.S.F.n = 1;

                std.log.info("a=${x:0>2}", .{a});

                if (a == d8)
                    gb.cpu.AF.S.F.z = 1;

                if ((a & 0xf) < (d8 & 0xf))
                    gb.cpu.AF.S.F.h = 1;

                if (a < d8)
                    gb.cpu.AF.S.F.h = 1;

                std.log.info("CP ${x:0>2} ${B:0>1}", .{ d8, gb.cpu.AF.S.F });
                break :blk;
            },

            else => blk: {
                gb.halt = true;
                std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ gb.cpu.PC, gb.memory.Raw[gb.cpu.PC] });
                std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                break :blk return RuntimeError.InstructionNotImplemented;
            },
        }
    }
};
