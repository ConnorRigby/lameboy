const std = @import("std");

const cpu = @import("cpu.zig");
const CPU = cpu.CPU;
const RegisterReference = cpu.RegisterReference;

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

    pub fn nop(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        // std.log.info("NOP", .{});
        core.halt = true;
    }

    pub fn inc_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        r.* +%= 1;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.z = 0;
        core.cpu.AF.S.F.h = 0;

        if ((r.* & 0x0F) == 0)
            core.cpu.AF.S.F.h = 1;

        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn inc_rr(core: *Core, rr: *u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        rr.* += 1;
    }

    pub fn dec_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const value: u8 = r.* -% 1;
        r.* = value;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;
        core.cpu.AF.S.F.n = 1;

        if ((r.* & 0x0f) == 0xf)
            core.cpu.AF.S.F.h = 1;

        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;

        // std.log.info("dec_r result: ${x:0>2} ${x:0>2}", .{r.*, core.cpu.DE.S.D});
    }

    pub fn sub_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const d8: u8 = r.*;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A -%= d8;
        core.cpu.AF.S.F.n = 1;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn add_rr(core: *Core, rr: u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(rr);
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A += d8;
        if ((a + d8) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (d8 & 0xf) > 0x0f)
            core.cpu.AF.S.F.h = 1;
        if ((a + d8) > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn ld_r_d8(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        r.* = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
    }

    pub fn ld_r_r(core: *Core, r: *u8, r8: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        r.* = r8;
    }

    pub fn ld_rr_d16(core: *Core, rr: *u16) void {
        core.cpu.PC += 1;
        core.tCycles += 12;

        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        rr.* = (@as(u16, lsb) << 8) | msb;
    }

    // load r from memory at address rr
    pub fn ld_r_rr(core: *Core, r: *u8, r16: u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        r.* = core.memory.read8(r16);
    }

    // load r into memory at address rr
    pub fn ld_rr_r(core: *Core, r16: u16, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.memory.write8(r16, r);
    }

    pub fn ld_hli_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.memory.write8(core.cpu.HL.HL, r);
        core.cpu.HL.HL +%= 1;
    }

    pub fn ld_hld_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        core.memory.write8(core.cpu.HL.HL, r);
        core.cpu.HL.HL -%= 1;
    }

    // i stole this implementation from sameboy.
    // i do not fully understand it
    pub fn rla(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const bit7: bool = (core.cpu.AF.AF & 0x8000) != 0;
        const carry: bool = (core.cpu.AF.S.F.c) != 0;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.A <<= 1;

        if (carry)
            core.cpu.AF.AF |= 0x0100;

        if (bit7)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn cp_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.n = 1;

        // std.log.info("a=${x:0>2}", .{a});

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.h = 1;
    }

    pub fn cp_rr(core: *Core, rr: u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(rr);
        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.n = 1;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.h = 1;
    }

    pub fn pop_rr(core: *Core, rr: *RegisterReference) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        const msb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;
        rr.*.S.ry = msb;

        const lsb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;
        rr.*.S.rx = lsb;
    }

    pub fn push_rr(core: *Core, rr: *RegisterReference) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, rr.*.S.rx);

        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, rr.*.S.ry);
    }

    pub fn call(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 24;

        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const nn: u16 = (@as(u16, lsb) << 8) | msb;

        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, @intCast(u8, core.cpu.PC >> 8));
        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, @truncate(u8, core.cpu.PC));

        core.cpu.PC = nn;
        // std.log.info("CALL ${x:0>4}", .{nn});
    }

    pub fn ret(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        const msb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;

        const lsb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;

        const nn: u16 = (@as(u16, lsb) << 8) | msb;
        core.cpu.PC = nn;
    }

    pub fn jr_r8(core: *Core) void {
        core.cpu.PC += 1;
        // const r8: i8 = @bitCast(i8, core.memory.Raw[core.cpu.PC]);
        const r8: i8 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;
        core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
    }

    pub fn jr_nz_r8(core: *Core) void {
        core.cpu.PC += 1;
        // const r8: i8 = @bitCast(i8, core.memory.Raw[core.cpu.PC]);
        const r8: i8 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;

        if (core.cpu.AF.S.F.z != 1) {
            core.tCycles += 12;
            // std.log.info("JR NZ,{d} (true) f={B:0>1}", .{r8, core.cpu.AF.S.F});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR NZ,{d} (false) f={B:0>1}", .{r8, core.cpu.AF.S.F});
        }
    }

    pub fn jr_z_r8(core: *Core) void {
        core.cpu.PC += 1;
        // const r8: i8 = @bitCast(i8, core.memory.Raw[core.cpu.PC]);
        const r8: i8 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;

        if (core.cpu.AF.S.F.z == 1) {
            core.tCycles += 12;
            // std.log.info("JR Z,{d} (true)", .{r8});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR Z,{d} (false)", .{r8});
        }
    }

    pub fn xor_a_r(core: *Core, value: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 1;
        core.cpu.AF.S.A ^= value;

        if (core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn step(gb: *Core) !void {
        // std.log.info("\tPC=0x{x:0>2} OP=0x{x:0>2}", .{ gb.cpu.PC, gb.memory.Raw[gb.cpu.PC] });

        switch (gb.memory.Raw[gb.cpu.PC]) {
            // NOP
            0 => nop(gb),

            // INC B
            0x04 => inc_r(gb, &gb.cpu.BC.S.B),

            // DEC B
            0x05 => dec_r(gb, &gb.cpu.BC.S.B),

            // LD B,d8
            0x06 => ld_r_d8(gb, &gb.cpu.BC.S.B),

            // INC C
            0x0C => inc_r(gb, &gb.cpu.BC.S.C),

            // DEC C
            0x0D => dec_r(gb, &gb.cpu.BC.S.C),

            // LD C,d8
            0x0E => ld_r_d8(gb, &gb.cpu.BC.S.C),

            // LD DE,d16
            0x11 => ld_rr_d16(gb, &gb.cpu.DE.DE),

            // INC DE
            0x13 => inc_rr(gb, &gb.cpu.DE.DE),

            // DEC D
            0x15 => dec_r(gb, &gb.cpu.DE.S.D),

            // LD D,d8
            0x16 => ld_r_d8(gb, &gb.cpu.DE.S.D),

            // RLA
            0x17 => rla(gb),

            // JR r8
            0x18 => jr_r8(gb),

            // LD A,(DE)
            0x1A => ld_r_rr(gb, &gb.cpu.AF.S.A, gb.cpu.DE.DE),

            // DEC E
            0x1D => dec_r(gb, &gb.cpu.DE.S.E),

            // LD E,d8
            0x1E => ld_r_d8(gb, &gb.cpu.DE.S.E),

            // JR NZ,r8
            0x20 => jr_nz_r8(gb),

            // LD HL,d16
            0x21 => ld_rr_d16(gb, &gb.cpu.HL.HL),

            // LD (HL+),A
            0x22 => ld_hli_r(gb, gb.cpu.AF.S.A),

            // INC HL
            0x23 => inc_rr(gb, &gb.cpu.HL.HL),

            // INC H
            0x24 => inc_r(gb, &gb.cpu.HL.S.H),

            // JR Z,r8
            0x28 => jr_z_r8(gb),

            // LD L,d8
            0x2E => ld_r_d8(gb, &gb.cpu.HL.S.L),

            // LD SP,u16
            0x31 => ld_rr_d16(gb, &gb.cpu.SP),

            // LD (HL-),A
            0x32 => ld_hld_r(gb, gb.cpu.AF.S.A),

            // DEC A
            0x3D => dec_r(gb, &gb.cpu.AF.S.A),

            // LD A,d8
            0x3E => ld_r_d8(gb, &gb.cpu.AF.S.A),

            // LD B,D
            0x42 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.DE.S.D),

            // LD B,H
            0x44 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.HL.S.H),

            // LD C,A
            0x4F => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.AF.S.A),

            // LD D,A
            0x57 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.AF.S.A),

            // LD H,A
            0x67 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.AF.S.A),

            // LD (HL),A
            0x77 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.AF.S.A),

            // LD A,B
            0x78 => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.BC.S.B),

            // LD A,E
            0x7b => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.DE.S.E),

            // LD A,H
            0x7C => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.HL.S.H),

            // LD A,L
            0x7D => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.HL.S.L),

            // ADD A,(HL)
            0x86 => add_rr(gb, gb.cpu.HL.HL),

            // SUB B
            0x90 => sub_r(gb, &gb.cpu.BC.S.B),

            // XOR A
            0xAF => xor_a_r(gb, gb.cpu.AF.S.A),

            // CP (HL)
            0xBE => cp_rr(gb, gb.cpu.HL.HL),

            // POP BC
            0xC1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),

            // PUSH BC
            0xC5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),

            // RET
            0xC9 => ret(gb),

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
                        // std.log.info("RL C before: {x:0>1} {b:0>8}", .{ gb.cpu.AF.S.F.c, gb.cpu.BC.S.C });
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

                        // std.log.info("RL C after: {x:0>1} {b:0>8} {x:0>1} ", .{ gb.cpu.AF.S.F.c, gb.cpu.BC.S.C, carry });
                        break :cblk;
                    },
                    // BIT 7, H
                    0x7C => cblk: {
                        gb.cpu.PC += 1;
                        gb.tCycles += 8;
                        gb.cpu.AF.S.F.h = 1;
                        gb.cpu.AF.S.F.n = 0;
                        gb.cpu.AF.S.F.z = @intCast(u1, ((gb.cpu.HL.S.H >> 7) & 0x01));
                        // std.log.info("BIT 7, H {B:0>1}", .{gb.cpu.AF.S.F});
                        break :cblk;
                    },
                    else => cblk: {
                        gb.halt = true;
                        // std.log.info("Unimplemented CB Instruction 0x{X}", .{gb.memory.Raw[gb.cpu.PC]});
                        // std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                        break :cblk return RuntimeError.InstructionNotImplemented;
                    },
                }
            },

            // CALL nn
            0xCD => call(gb),

            // LDH (a8), A
            // LD ($FF00+a8),A
            0xE0 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;
                const a8: u16 = gb.memory.read8(gb.cpu.PC);
                gb.cpu.PC += 1;
                gb.memory.write8(0xFF00 + a8, gb.cpu.AF.S.A);
                // std.log.info("LD ($FF00+${x:0>2}),A", .{a8});
                break :blk;
            },

            // LD ($FF00+C),A
            0xE2 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                gb.memory.write8(0xFF00 + @intCast(u16, gb.cpu.BC.S.C), gb.cpu.AF.S.A);
                // std.log.info("LD ($FF00+{X:0>2}),A", .{gb.cpu.BC.S.C});
                break :blk;
            },

            // LD (a16),A
            0xEA => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 16;

                const msb: u8 = gb.memory.read8(gb.cpu.PC);
                gb.cpu.PC += 1;

                const lsb: u8 = gb.memory.read8(gb.cpu.PC);
                gb.cpu.PC += 1;

                gb.memory.write8((@as(u16, lsb) << 8) | msb, gb.cpu.AF.S.A);
                // std.log.info("LD (${x:0>4}),A", .{(@as(u16, lsb) << 8) | msb});
                break :blk;
            },

            // LDH A,(a8)
            0xF0 => blk: {
                gb.cpu.PC += 1;
                gb.tCycles += 12;

                const a8: u16 = gb.memory.read8(gb.cpu.PC);
                gb.cpu.PC += 1;
                gb.cpu.AF.S.A = gb.memory.read8(0xff00 + a8);
                // std.log.info("LDH A,(${x:0>2})=${x:0>2}", .{ a8, gb.cpu.AF.S.A });
                break :blk;
            },

            // CP d8
            0xFE => cp_d8(gb),

            else => blk: {
                gb.halt = true;
                // std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ gb.cpu.PC, gb.memory.Raw[gb.cpu.PC] });
                // std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                break :blk return RuntimeError.InstructionNotImplemented;
            },
        }
    }
};
