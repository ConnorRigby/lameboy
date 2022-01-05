const std = @import("std");
const MMU = @import("mmu.zig").MMU;

const disassembler = @import("disassembler.zig");
pub const RuntimeError = error{ InstructionNotImplemented, YouSuck };
pub const RegisterID = enum(u32) { A = 0x0, F = 0x1, AF = 0x2, B = 0x3, C = 0x4, BC = 0x5, D = 0x6, E = 0x7, DE = 0x8, H = 0x9, L = 0xA, HL = 0xB, PC = 0xC, SP = 0xD };

pub const RegisterReference = extern union {
    S: extern struct {
        rx: u8,
        ry: u8,
    },
    RR: u16,
};

pub const CPU = struct {
    /// Program Counter
    PC: u16,

    /// Stack Pointer
    SP: u16,

    AF: extern union {
        S: extern struct {
            /// Flags: z: zero, n: subtract, h: half-carry, c: carry
            F: packed struct { unused: u4, c: u1, h: u1, n: u1, z: u1 },
            // F: packed struct { z: u1, n: u1, h: u1, c: u1, unused: u4 },

            A: u8,
        },
        AF: u16,
    },

    BC: extern union {
        S: extern struct {
            C: u8,
            B: u8,
        },
        BC: u16,
    },

    DE: extern union {
        S: extern struct {
            E: u8,
            D: u8,
        },
        DE: u16,
    },

    HL: extern union {
        S: extern struct {
            L: u8,
            H: u8,
        },
        HL: u16,
    },

    mCycles: u64,
    halt: bool,

    pub fn init() CPU {
        return CPU{
            .AF = .{ .AF = 0 },
            .BC = .{ .BC = 0 },
            .DE = .{ .DE = 0 },
            .HL = .{ .HL = 0 },
            .SP = 0,
            .PC = 0,
            .mCycles = 0,
            .halt = false,
        };
    }

    pub fn nop(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
    }

    pub fn inc_r(cpu: *CPU, r: *u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        r.* +%= 1;

        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((r.* & 0x0F) == 0)
            cpu.AF.S.F.h = 1;

        if (r.* == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn inc_rr(cpu: *CPU, rr: *u16) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        rr.* +%= 1;
    }

    pub fn inc_dhl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;
        const value: u8 = mmu.read8(cpu.HL.HL) +% 1;
        mmu.write8(cpu.HL.HL, value);

        // cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((value & 0x0F) == 0)
            cpu.AF.S.F.h = 1;

        if ((value & 0xFF) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn dec_dhl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;
        const value: u8 = mmu.read8(cpu.HL.HL) -% 1;
        mmu.write8(cpu.HL.HL, value);

        // cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((value & 0x0F) == 0x0F)
            cpu.AF.S.F.h = 1;
        if ((value & 0xFF) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn ld_dhl_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;

        const d8: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        mmu.write8(cpu.HL.HL, d8);
    }

    pub fn dec_r(cpu: *CPU, r: *u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const value: u8 = r.* -% 1;
        r.* = value;

        // cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((r.* & 0x0f) == 0xf)
            cpu.AF.S.F.h = 1;

        if (r.* == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn dec_rr(cpu: *CPU, rr: *u16) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        rr.* -%= 1;
    }

    pub fn sub_r(cpu: *CPU, r: *u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const d8: u8 = r.*;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A -%= d8;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == d8)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < d8)
            cpu.AF.S.F.c = 1;
    }

    pub fn sub_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const d8: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A -%= d8;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == d8)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < d8)
            cpu.AF.S.F.c = 1;
    }

    pub fn sub_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const d8: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A -%= d8;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == d8)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < d8)
            cpu.AF.S.F.c = 1;
    }

    pub fn sbc_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        const a: u8 = cpu.AF.S.A;
        const carry: u1 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A = (a -% r -% carry);

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a -% r -% carry) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn sbc_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;
        const carry: u1 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A = (a -% r -% carry);

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a -% r -% carry) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn sbc_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;
        const carry: u1 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A = (a -% r -% carry);

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a -% r -% carry) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn add_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A +%= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) > 0x0F)
            cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn add_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A +%= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a +% r) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (r & 0xf) > 0x0f)
            cpu.AF.S.F.h = 1;

        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn add_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A +%= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a +% r) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (r & 0xf) > 0x0f)
            cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn add_hl_rr(cpu: *CPU, rr: u16) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const hl: u16 = cpu.HL.HL;
        cpu.HL.HL +%= rr;
        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.n = 0;
        if ((((hl & 0xFFF) + (rr & 0xFFF)) & 0x1000) != 0)
            cpu.AF.S.F.h = 1;

        if (((@intCast(u64, hl) + @intCast(u64, rr)) & 0x10000) != 0)
            cpu.AF.S.F.c = 1;
    }

    pub fn adc_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        const a: u8 = cpu.AF.S.A;
        const carry: u8 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A = (a +% r +% carry);

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a +% r +% carry) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) + carry > 0x0F)
            cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) + carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn adc_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const a: u8 = cpu.AF.S.A;
        const r: u8 = mmu.read8(cpu.HL.HL);
        const carry: u1 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A = (a +% r +% carry);

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a +% r +% carry) == 0)
            cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) + carry > 0x0F)
            cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) + carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn adc_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const a: u8 = cpu.AF.S.A;
        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const carry: u8 = @boolToInt(cpu.AF.S.F.c != 0);
        cpu.AF.S.A +%= r +% carry;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;

        if ((a & 0xF) + (r & 0xF) + carry > 0x0F)
            cpu.AF.S.F.h = 1;

        if (@intCast(u16, a) +% @intCast(u16, r) +% carry > 0xff)
            cpu.AF.S.F.c = 1;
    }

    pub fn ld_r_d8(cpu: *CPU, mmu: *MMU, r: *u8) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        r.* = mmu.read8(cpu.PC);
        cpu.PC += 1;
    }

    pub fn ld_r_r(cpu: *CPU, r: *u8, r8: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        r.* = r8;
    }

    pub fn ld_rr_d16(cpu: *CPU, mmu: *MMU, rr: *u16) void {
        cpu.PC += 1;
        cpu.mCycles += 12;

        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        rr.* = (@as(u16, lsb) << 8) | msb;
    }

    pub fn ld_r_rr(cpu: *CPU, mmu: *MMU, r: *u8, r16: u16) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        r.* = mmu.read8(r16);
    }

    pub fn ld_rr_r(cpu: *CPU, mmu: *MMU, r16: u16, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        mmu.write8(r16, r);
    }

    pub fn ld_hli_r(cpu: *CPU, mmu: *MMU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        mmu.write8(cpu.HL.HL, r);
        cpu.HL.HL +%= 1;
    }

    pub fn ld_a_hli(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        cpu.AF.AF &= 0xFF;
        cpu.AF.S.A = mmu.read8(cpu.HL.HL);
        cpu.HL.HL +%= 1;
    }

    pub fn ld_hld_r(cpu: *CPU, mmu: *MMU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        mmu.write8(cpu.HL.HL, r);
        cpu.HL.HL -%= 1;
    }

    pub fn ld_r_hld(cpu: *CPU, mmu: *MMU, r: *u8) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        r.* = mmu.read8(cpu.HL.HL);
        cpu.HL.HL -%= 1;
    }

    pub fn ldh_a_a8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;

        const a8: u16 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        cpu.AF.S.A = mmu.read8(0xff00 + a8);
    }

    pub fn ldh_a8_a(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;
        const a8: u16 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        mmu.write8(0xFF00 + a8, cpu.AF.S.A);
    }

    pub fn ld_c_a(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        mmu.write8(0xFF00 + @intCast(u16, cpu.BC.S.C), cpu.AF.S.A);
    }

    pub fn ld_a_c(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        cpu.AF.S.A = mmu.read8(0xFF00 + @intCast(u16, cpu.BC.S.C));
    }

    pub fn ld_a16_a(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 16;

        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        mmu.write8((@as(u16, lsb) << 8) | msb, cpu.AF.S.A);
    }

    pub fn ld_a_a16(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 16;

        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        cpu.AF.S.A = mmu.read8((@as(u16, lsb) << 8) | msb);
    }

    pub fn ld_da16_sp(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 20;

        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const address: u16 = (@as(u16, lsb) << 8) | msb;
        mmu.write8(address, @intCast(u8, cpu.SP & 0xFF));
        mmu.write8(address + 1, @intCast(u8, cpu.SP >> 8));
    }

    pub fn ld_hl_sp_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 12;

        const offset: i16 = mmu.readi8(cpu.PC);
        cpu.PC += 1;
        cpu.HL.HL = cpu.SP +% @bitCast(u16, offset);
        cpu.AF.AF &= 0xFF00;

        if ((cpu.SP & 0xF) + (@bitCast(u16, offset) & 0xF) > 0xF)
            cpu.AF.S.F.h = 1;
        if ((cpu.SP & 0xFF) + (@bitCast(u16, offset) & 0xFF) > 0xFF)
            cpu.AF.S.F.c = 1;
    }

    pub fn ld_sp_hl(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        cpu.SP = cpu.HL.HL;
    }

    pub fn rla(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const bit7: bool = (cpu.AF.AF & 0x8000) != 0;
        const carry: bool = (cpu.AF.S.F.c) != 0;

        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.A <<= 1;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (carry)
            cpu.AF.AF |= 0x0100;

        if (bit7)
            cpu.AF.S.F.c = 1;
    }

    pub fn rlca(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const carry: bool = (cpu.AF.AF & 0x8000) != 0;
        cpu.AF.AF = (cpu.AF.AF & 0xFF00) << 1;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (carry) {
            cpu.AF.S.F.c = 1;
            cpu.AF.AF |= 0x0100;
        }
    }

    pub fn rrca(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const carry: bool = (cpu.AF.AF & 0x100) != 0;
        cpu.AF.AF = (cpu.AF.AF >> 1) & 0xFF00;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (carry) {
            cpu.AF.S.F.c = 1;
            cpu.AF.AF |= 0x8000;
        }
    }

    pub fn rra(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const bit1: bool = (cpu.AF.AF & 0x0100) != 0;
        const carry: bool = (cpu.AF.S.F.c) != 0;

        cpu.AF.S.A >>= 1;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (carry)
            cpu.AF.AF |= 0x8000;
        if (bit1)
            cpu.AF.S.F.c = 1;
    }

    pub fn cpl(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        cpu.AF.AF ^= 0xFF00;

        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 1;
    }

    pub fn scf(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        cpu.AF.S.F.c = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.n = 0;
    }

    pub fn ccf(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        if (cpu.AF.S.F.c == 1) {
            cpu.AF.S.F.c = 0;
        } else {
            cpu.AF.S.F.c = 1;
        }
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.n = 0;
    }

    pub fn cp_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const a: u8 = cpu.AF.S.A;

        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.n = 1;

        if (a == r)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < r)
            cpu.AF.S.F.c = 1;
    }

    pub fn cp_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;

        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == r)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < r)
            cpu.AF.S.F.c = 1;
    }

    pub fn cp_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;

        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == r)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < r)
            cpu.AF.S.F.c = 1;
    }

    pub fn cp_rr(cpu: *CPU, mmu: *MMU, rr: u16) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const d8: u8 = mmu.read8(rr);
        const a: u8 = cpu.AF.S.A;

        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 1;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (a == d8)
            cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            cpu.AF.S.F.h = 1;

        if (a < d8)
            cpu.AF.S.F.c = 1;
    }

    pub fn pop_rr(cpu: *CPU, mmu: *MMU, rr: *RegisterReference) void {
        cpu.PC += 1;
        cpu.mCycles += 16;

        const msb: u8 = mmu.read8(cpu.SP);
        cpu.SP += 1;
        rr.*.S.rx = msb;

        const lsb: u8 = mmu.read8(cpu.SP);
        cpu.SP += 1;
        rr.*.S.ry = lsb;

        cpu.AF.AF &= 0xFFF0;
    }

    pub fn push_rr(cpu: *CPU, mmu: *MMU, rr: *RegisterReference) void {
        cpu.PC += 1;
        cpu.mCycles += 16;

        cpu.SP -= 1;
        mmu.write8(cpu.SP, rr.*.S.ry);

        cpu.SP -= 1;
        mmu.write8(cpu.SP, rr.*.S.rx);
    }

    pub fn call_a16(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 24;

        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const nn: u16 = (@as(u16, lsb) << 8) | msb;

        cpu.SP -= 1;
        mmu.write8(cpu.SP, @intCast(u8, cpu.PC >> 8));
        cpu.SP -= 1;
        mmu.write8(cpu.SP, @truncate(u8, cpu.PC));

        cpu.PC = nn;
    }

    pub fn call_nz_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z != 1) {
            call_a16(cpu, mmu);
        } else {
            cpu.PC += 3;
            cpu.mCycles += 12;
        }
    }

    pub fn call_z_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z == 1) {
            call_a16(cpu, mmu);
        } else {
            cpu.PC += 3;
            cpu.mCycles += 12;
        }
    }

    pub fn call_nc_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c != 1) {
            call_a16(cpu, mmu);
        } else {
            cpu.PC += 3;
            cpu.mCycles += 12;
        }
    }

    pub fn call_c_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c == 1) {
            call_a16(cpu, mmu);
        } else {
            cpu.PC += 3;
            cpu.mCycles += 12;
        }
    }

    pub fn ret(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 16;

        const msb: u8 = mmu.read8(cpu.SP);
        cpu.SP += 1;

        const lsb: u8 = mmu.read8(cpu.SP);
        cpu.SP += 1;

        const nn: u16 = (@as(u16, lsb) << 8) | msb;
        cpu.PC = nn;
    }

    pub fn reti(cpu: *CPU, mmu: *MMU) void {
        ret(cpu, mmu);
        mmu.interruptsEnabled = true;
    }

    pub fn ret_nz(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z != 1) {
            cpu.mCycles += 4;
            ret(cpu, mmu);
        } else {
            cpu.PC += 1;
            cpu.mCycles += 8;
        }
    }

    pub fn ret_z(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z == 1) {
            cpu.mCycles += 4;
            ret(cpu, mmu);
        } else {
            cpu.PC += 1;
            cpu.mCycles += 8;
        }
    }

    pub fn ret_nc(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c != 1) {
            cpu.mCycles += 4;
            ret(cpu, mmu);
        } else {
            cpu.PC += 1;
            cpu.mCycles += 8;
        }
    }

    pub fn ret_c(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c == 1) {
            cpu.mCycles += 4;
            ret(cpu, mmu);
        } else {
            cpu.PC += 1;
            cpu.mCycles += 8;
        }
    }

    pub fn jr_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        const r8: i8 = mmu.readi8(cpu.PC);
        cpu.PC += 1;
        cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
    }

    pub fn jr_nz_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        const r8: i8 = mmu.readi8(cpu.PC);
        cpu.PC += 1;

        if (cpu.AF.S.F.z != 1) {
            cpu.mCycles += 12;
            cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            cpu.mCycles += 8;
        }
    }

    pub fn jr_z_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        const r8: i8 = mmu.readi8(cpu.PC);
        cpu.PC += 1;

        if (cpu.AF.S.F.z == 1) {
            cpu.mCycles += 12;
            cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            cpu.mCycles += 8;
        }
    }

    pub fn jr_nc_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        const r8: i8 = mmu.readi8(cpu.PC);
        cpu.PC += 1;

        if (cpu.AF.S.F.c != 1) {
            cpu.mCycles += 12;
            cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            cpu.mCycles += 8;
        }
    }

    pub fn jr_c_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        const r8: i8 = mmu.readi8(cpu.PC);
        cpu.PC += 1;

        if (cpu.AF.S.F.c == 1) {
            cpu.mCycles += 12;
            cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            cpu.mCycles += 8;
        }
    }

    pub fn jp_a16(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 16;
        const msb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        const lsb: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;

        cpu.PC = (@as(u16, lsb) << 8) | msb;
    }

    pub fn jp_nz_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z != 1) {
            jp_a16(cpu, mmu);
        } else {
            cpu.mCycles += 12;
            cpu.PC += 3;
        }
    }

    pub fn jp_z_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.z == 1) {
            jp_a16(cpu, mmu);
        } else {
            cpu.mCycles += 12;
            cpu.PC += 3;
        }
    }

    pub fn jp_nc_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c != 1) {
            jp_a16(cpu, mmu);
        } else {
            cpu.mCycles += 12;
            cpu.PC += 3;
        }
    }

    pub fn jp_c_a16(cpu: *CPU, mmu: *MMU) void {
        if (cpu.AF.S.F.c == 1) {
            jp_a16(cpu, mmu);
        } else {
            cpu.mCycles += 12;
            cpu.PC += 3;
        }
    }

    pub fn jp_hl(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        cpu.PC = cpu.HL.HL;
    }

    pub fn and_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A = (a & r);
        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.h = 1;
        if ((a & r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn and_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A = (a & r);
        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.unused = 0;
        cpu.AF.S.F.h = 1;
        if ((a & r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn and_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A = (a & r);
        cpu.AF.AF &= 0xFF00;
        cpu.AF.S.F.unused = 0;
        cpu.AF.S.F.h = 1;

        if ((a & r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn add_sp_r8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 16;
        const sp: u16 = cpu.SP;
        const offset: i16 = mmu.readi8(cpu.PC);
        cpu.PC += 1;

        cpu.SP +%= @bitCast(u16, offset);

        cpu.AF.AF &= 0xFF00;
        if ((sp & 0xF) + (@bitCast(u16, offset) & 0xF) > 0xF)
            cpu.AF.S.F.h = 1;
        if ((sp & 0xFF) + (@bitCast(u16, offset) & 0xFF) > 0xFF)
            cpu.AF.S.F.c = 1;
    }

    pub fn xor_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 1;
        cpu.AF.S.A ^= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn xor_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.AF.S.A ^= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn xor_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        cpu.AF.S.A ^= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn or_r(cpu: *CPU, r: u8) void {
        cpu.PC += 1;
        cpu.mCycles += 4;

        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A |= r;
        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn or_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.HL.HL);
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A |= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn or_d8(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 8;

        const r: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        const a: u8 = cpu.AF.S.A;
        cpu.AF.S.A |= r;

        cpu.AF.S.F.c = 0;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.h = 0;
        cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn di(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        mmu.interruptsEnabled = false;
    }

    pub fn ei(cpu: *CPU, mmu: *MMU) void {
        cpu.PC += 1;
        cpu.mCycles += 4;
        mmu.interruptsEnabled = true;
    }

    pub fn rst(cpu: *CPU, mmu: *MMU) void {
        cpu.mCycles += 16;
        const opcode: u8 = mmu.read8(cpu.PC);
        cpu.PC += 1;
        cpu.SP -= 1;
        mmu.write8(cpu.SP, @intCast(u8, cpu.PC >> 8));
        cpu.SP -= 1;
        mmu.write8(cpu.SP, @truncate(u8, cpu.PC));
        cpu.PC = opcode ^ 0xC7;
    }

    pub fn rlc_r(cpu: *CPU, r: *u8) void {
        const carry: bool = (r.* & 0x80) != 0;
        cpu.AF.AF &= 0xFF00;
        const value = (r.* << 1) | @as(u8, @boolToInt(carry));
        r.* = value;
        if (carry)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rlc_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.mCycles += 8;
        cpu.AF.AF &= 0xFF00;
        const r: u8 = mmu.read8(cpu.HL.HL);
        const carry: bool = (r & 0x80) != 0;
        const value = (r << 1) | @intCast(u8, @boolToInt(carry));
        mmu.write8(cpu.HL.HL, value);
        if (carry)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rl_r(cpu: *CPU, r: *u8) void {
        const carry: bool = cpu.AF.S.F.c != 0;
        const bit7: bool = (r.* & 0x80) != 0;
        cpu.AF.AF &= 0xFF00;
        const value: u8 = (r.* << 1) | @as(u8, @boolToInt(carry));
        r.* = value;
        if (bit7)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rl_hl(cpu: *CPU, mmu: *MMU) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        const carry: bool = cpu.AF.S.F.c != 0;
        const bit7: bool = (r & 0x80) != 0;
        cpu.AF.AF &= 0xFF00;
        const value: u8 = (r << 1) | @as(u8, @boolToInt(carry));
        mmu.write8(cpu.HL.HL, value);
        if (bit7)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rrc_r(cpu: *CPU, r: *u8) void {
        const carry: bool = (r.* & 0x01) != 0;
        cpu.AF.AF &= 0xFF00;
        const value = (r.* >> 1) | @as(u8, @boolToInt(carry)) << 7;
        r.* = value;
        if (carry)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rrc_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.mCycles += 8;
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.AF.AF &= 0xFF00;
        const carry: bool = (r & 0x01) != 0;
        cpu.mCycles += 8;
        const value = (r >> 1) | @as(u8, @boolToInt(carry)) << 7;
        mmu.write8(cpu.HL.HL, value);
        if (carry)
            cpu.AF.S.F.c = 1;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rr_r(cpu: *CPU, r: *u8) void {
        const carry: bool = cpu.AF.S.F.c != 0;
        const value = (r.* >> 1) | (@as(u8, @boolToInt(carry)) << 7);
        const bit0: u1 = @intCast(u1, (r.* >> 0) & 1);

        cpu.AF.AF &= 0xFF00;
        r.* = value;
        cpu.AF.S.F.c = bit0;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn rr_hl(cpu: *CPU, mmu: *MMU) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        const carry: bool = cpu.AF.S.F.c != 0;
        const value = (r >> 1) | (@as(u8, @boolToInt(carry)) << 7);
        const bit0: u1 = @intCast(u1, (r >> 0) & 1);

        cpu.AF.AF &= 0xFF00;
        mmu.write8(cpu.HL.HL, value);
        cpu.AF.S.F.c = bit0;
        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn sla_r(cpu: *CPU, r: *u8) void {
        const carry: bool = (r.* & 0x80) != 0;
        cpu.AF.AF &= 0xFF00;
        const value: u8 = (r.* << 1);
        r.* = value;
        if (carry)
            cpu.AF.S.F.c = 1;
        if ((value & 0x7F) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn sla_hl(cpu: *CPU, mmu: *MMU) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        const carry: bool = (r & 0x80) != 0;
        cpu.AF.AF &= 0xFF00;
        const value: u8 = (r << 1);
        mmu.write8(cpu.HL.HL, value);
        if (carry)
            cpu.AF.S.F.c = 1;
        if ((r & 0x7F) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn sra_r(cpu: *CPU, r: *u8) void {
        var value: u8 = r.*;
        const bit7: u8 = value & 0x80;
        cpu.AF.AF &= 0xFF00;

        if ((value & 1) != 0)
            cpu.AF.S.F.c = 1;

        value = (value >> 1) | bit7;
        r.* = value;

        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn sra_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.mCycles += 8;

        var value: u8 = mmu.read8(cpu.HL.HL);
        const bit7: u8 = value & 0x80;
        cpu.AF.AF &= 0xFF00;

        if ((value & 1) != 0)
            cpu.AF.S.F.c = 1;

        value = (value >> 1) | bit7;
        mmu.write8(cpu.HL.HL, value);

        if (value == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn swap_r(cpu: *CPU, r: *u8) void {
        cpu.AF.AF &= 0xFF00;
        r.* = (r.* >> 4) | (r.* << 4);
        if (r.* == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn swap_hl(cpu: *CPU, mmu: *MMU) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        cpu.AF.AF &= 0xFF00;
        mmu.write8(cpu.HL.HL, (r >> 4) | (r << 4));
        if (r == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn srl_r(cpu: *CPU, r: *u8) void {
        cpu.AF.AF &= 0xFF00;
        const value: u8 = r.*;
        r.* = value >> 1;
        if ((value & 1) != 0)
            cpu.AF.S.F.c = 1;
        if ((value >> 1) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn srl_hl(cpu: *CPU, mmu: *MMU) void {
        cpu.AF.AF &= 0xFF00;
        const value: u8 = mmu.read8(cpu.HL.HL);
        mmu.write8(cpu.HL.HL, value >> 1);
        if ((value & 1) != 0)
            cpu.AF.S.F.c = 1;
        if ((value >> 1) == 0)
            cpu.AF.S.F.z = 1;
    }

    pub fn bit_r(cpu: *CPU, which_bit: u3, r: *u8) void {
        cpu.AF.S.F.h = 1;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.z = 0;

        cpu.AF.S.F.z = @intCast(u1, ((r.* >> which_bit) & 1) ^ 1);
    }

    pub fn bit_hl(cpu: *CPU, mmu: *MMU, which_bit: u3) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        cpu.AF.S.F.h = 1;
        cpu.AF.S.F.n = 0;
        cpu.AF.S.F.z = 0;

        cpu.AF.S.F.z = @intCast(u1, ((r >> which_bit) & 1) ^ 1);
    }

    pub fn res_r(_: *CPU, bit: u3, r: *u8) void {
        r.* = r.* & (~(@as(u8, 1) << bit));
    }

    pub fn res_hl(cpu: *CPU, mmu: *MMU, bit: u3) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        mmu.write8(cpu.HL.HL, r & (~(@as(u8, 1) << bit)));
    }

    pub fn set_r(_: *CPU, bit: u3, r: *u8) void {
        r.* = (@as(u8, 1) << bit) | r.*;
    }

    pub fn set_hl(cpu: *CPU, mmu: *MMU, bit: u3) void {
        const r: u8 = mmu.read8(cpu.HL.HL);
        cpu.mCycles += 8;
        mmu.write8(cpu.HL.HL, (@as(u8, 1) << bit) | r);
    }

    pub fn daa(cpu: *CPU) void {
        cpu.PC += 1;
        cpu.AF.S.F.z = 0;
        if (cpu.AF.S.F.n == 0) {
            if (cpu.AF.S.F.c == 1 or (cpu.AF.S.A > 0x99)) {
                cpu.AF.S.A +%= 0x60;
                cpu.AF.S.F.c = 1;
            }
            if (cpu.AF.S.F.h == 1 or (cpu.AF.S.A & 0x0f) > 0x09) {
                cpu.AF.S.A +%= 0x6;
            }
        } else {
            if (cpu.AF.S.F.c == 1) {
                cpu.AF.S.A -%= 0x60;
            }
            if (cpu.AF.S.F.h == 1) {
                cpu.AF.S.A -%= 0x6;
            }
        }

        if (cpu.AF.S.A == 0)
            cpu.AF.S.F.z = 1;

        cpu.AF.S.F.h = 0;
    }

    pub fn tick(cpu: *CPU, mmu: *MMU) !void {
        const opcode: u8 = mmu.read8(cpu.PC);

        // const writer = std.io.getStdOut().writer();
        // // if (cpu.PC >= 0x0100) {
        //     writer.print("A: {X:0>2} F: {X:0>2} B: {X:0>2} C: {X:0>2} D: {X:0>2} E: {X:0>2} H: {X:0>2} L: {X:0>2} SP: {X:0>4} PC: 00:{X:0>4} ({X:0>2} {X:0>2} {X:0>2} {X:0>2})\n", .{
        //         cpu.AF.S.A,              @bitCast(u8, (cpu.AF.S.F)),  cpu.BC.S.B,                  cpu.BC.S.C,                  cpu.DE.S.D, cpu.DE.S.E, cpu.HL.S.H, cpu.HL.S.L, cpu.SP, cpu.PC,
        //         mmu.read8(cpu.PC), mmu.read8(cpu.PC + 1), mmu.read8(cpu.PC + 2), mmu.read8(cpu.PC + 3),
        //     }) catch return;
        // // }

        switch (opcode) {
            // NOP
            0 => nop(cpu),
            // LD BC,d16
            0x01 => ld_rr_d16(cpu, mmu, &cpu.BC.BC),
            // LD (BC),A
            0x02 => ld_rr_r(cpu, mmu, cpu.BC.BC, cpu.AF.S.A),
            // INC BC
            0x03 => inc_rr(cpu, &cpu.BC.BC),
            // INC B
            0x04 => inc_r(cpu, &cpu.BC.S.B),
            // DEC B
            0x05 => dec_r(cpu, &cpu.BC.S.B),
            // LD B,d8
            0x06 => ld_r_d8(cpu, mmu, &cpu.BC.S.B),
            // RLCA
            0x07 => rlca(cpu),
            // LD (a16),SP
            0x08 => ld_da16_sp(cpu, mmu),
            // ADD HL,BC
            0x09 => add_hl_rr(cpu, cpu.BC.BC),
            // LD A,(BC)
            0x0A => ld_r_rr(cpu, mmu, &cpu.AF.S.A, cpu.BC.BC),
            // DEC BC
            0x0B => dec_rr(cpu, &cpu.BC.BC),
            // INC C
            0x0C => inc_r(cpu, &cpu.BC.S.C),
            // DEC C
            0x0D => dec_r(cpu, &cpu.BC.S.C),
            // LD C,d8
            0x0E => ld_r_d8(cpu, mmu, &cpu.BC.S.C),
            // RRCA
            0x0F => rrca(cpu),
            // STOP 0
            // 0x10 => stop(cpu),
            // LD DE,d16
            0x11 => ld_rr_d16(cpu, mmu, &cpu.DE.DE),
            // LD (DE),A
            0x12 => ld_rr_r(cpu, mmu, cpu.DE.DE, cpu.AF.S.A),
            // INC DE
            0x13 => inc_rr(cpu, &cpu.DE.DE),
            // INC D
            0x14 => inc_r(cpu, &cpu.DE.S.D),
            // DEC D
            0x15 => dec_r(cpu, &cpu.DE.S.D),
            // LD D,d8
            0x16 => ld_r_d8(cpu, mmu, &cpu.DE.S.D),
            // RLA
            0x17 => rla(cpu),
            // JR r8
            0x18 => jr_r8(cpu, mmu),
            // ADD HL,DE
            0x19 => add_hl_rr(cpu, cpu.DE.DE),
            // LD A,(DE)
            0x1A => ld_r_rr(cpu, mmu, &cpu.AF.S.A, cpu.DE.DE),
            // DEC DE
            0x1B => dec_rr(cpu, &cpu.DE.DE),
            // INC E
            0x1C => inc_r(cpu, &cpu.DE.S.E),
            // DEC E
            0x1D => dec_r(cpu, &cpu.DE.S.E),
            // LD E,d8
            0x1E => ld_r_d8(cpu, mmu, &cpu.DE.S.E),
            // RRA
            0x1F => rra(cpu),
            // JR NZ,r8
            0x20 => jr_nz_r8(cpu, mmu),
            // LD HL,d16
            0x21 => ld_rr_d16(cpu, mmu, &cpu.HL.HL),
            // LD (HL+),A
            0x22 => ld_hli_r(cpu, mmu, cpu.AF.S.A),
            // INC HL
            0x23 => inc_rr(cpu, &cpu.HL.HL),
            // INC H
            0x24 => inc_r(cpu, &cpu.HL.S.H),
            // DEC H
            0x25 => dec_r(cpu, &cpu.HL.S.H),
            // LD H,d8
            0x26 => ld_r_d8(cpu, mmu, &cpu.HL.S.H),
            // DAA
            0x27 => daa(cpu),
            // JR Z,r8
            0x28 => jr_z_r8(cpu, mmu),
            // ADD HL,HL
            0x29 => add_hl_rr(cpu, cpu.HL.HL),
            // LD A,(HL+)
            0x2A => ld_a_hli(cpu, mmu),
            // DEC HL
            0x2B => dec_rr(cpu, &cpu.HL.HL),
            // INC L
            0x2C => inc_r(cpu, &cpu.HL.S.L),
            // DEC L
            0x2D => dec_r(cpu, &cpu.HL.S.L),
            // LD L,d8
            0x2E => ld_r_d8(cpu, mmu, &cpu.HL.S.L),
            // CPL
            0x2F => cpl(cpu),
            // JR NC,r8
            0x30 => jr_nc_r8(cpu, mmu),
            // LD SP,u16
            0x31 => ld_rr_d16(cpu, mmu, &cpu.SP),
            // LD (HL-),A
            0x32 => ld_hld_r(cpu, mmu, cpu.AF.S.A),
            // INC SP
            0x33 => inc_rr(cpu, &cpu.SP),
            // INC (HL)
            0x34 => inc_dhl(cpu, mmu),
            // DEC (HL)
            0x35 => dec_dhl(cpu, mmu),
            // LD (HL),d8
            0x36 => ld_dhl_d8(cpu, mmu),
            // SCF
            0x37 => scf(cpu),
            // JR C,r8
            0x38 => jr_c_r8(cpu, mmu),
            // ADD HL,SP
            0x39 => add_hl_rr(cpu, cpu.SP),
            // LD A,(HL-)
            0x3A => ld_r_hld(cpu, mmu, &cpu.AF.S.A),
            // DEC SP
            0x3B => dec_rr(cpu, &cpu.SP),
            // INC A
            0x3C => inc_r(cpu, &cpu.AF.S.A),
            // DEC A
            0x3D => dec_r(cpu, &cpu.AF.S.A),
            // LD A,d8
            0x3E => ld_r_d8(cpu, mmu, &cpu.AF.S.A),
            // CCF
            0x3F => ccf(cpu),
            // LD B,B
            0x40 => ld_r_r(cpu, &cpu.BC.S.B, cpu.BC.S.B),
            // LD B,C
            0x41 => ld_r_r(cpu, &cpu.BC.S.B, cpu.BC.S.C),
            // LD B,D
            0x42 => ld_r_r(cpu, &cpu.BC.S.B, cpu.DE.S.D),
            // LD B,E
            0x43 => ld_r_r(cpu, &cpu.BC.S.B, cpu.DE.S.E),
            // LD B,H
            0x44 => ld_r_r(cpu, &cpu.BC.S.B, cpu.HL.S.H),
            // LD B,L
            0x45 => ld_r_r(cpu, &cpu.BC.S.B, cpu.HL.S.L),
            // LD B,(HL)
            0x46 => ld_r_rr(cpu, mmu, &cpu.BC.S.B, cpu.HL.HL),
            // LD B,A
            0x47 => ld_r_r(cpu, &cpu.BC.S.B, cpu.AF.S.A),
            // LD C,B
            0x48 => ld_r_r(cpu, &cpu.BC.S.C, cpu.BC.S.B),
            // LD C,C
            0x49 => ld_r_r(cpu, &cpu.BC.S.C, cpu.BC.S.C),
            // LD C,D
            0x4A => ld_r_r(cpu, &cpu.BC.S.C, cpu.DE.S.D),
            // LD C,E
            0x4B => ld_r_r(cpu, &cpu.BC.S.C, cpu.DE.S.E),
            // LD C,H
            0x4C => ld_r_r(cpu, &cpu.BC.S.C, cpu.HL.S.H),
            // LD C,L
            0x4D => ld_r_r(cpu, &cpu.BC.S.C, cpu.HL.S.L),
            // LD C,(HL)
            0x4E => ld_r_rr(cpu, mmu, &cpu.BC.S.C, cpu.HL.HL),
            // LD C,A
            0x4F => ld_r_r(cpu, &cpu.BC.S.C, cpu.AF.S.A),
            // LD D,B
            0x50 => ld_r_r(cpu, &cpu.DE.S.D, cpu.BC.S.B),
            // LD D,C
            0x51 => ld_r_r(cpu, &cpu.DE.S.D, cpu.BC.S.C),
            // LD D,D
            0x52 => ld_r_r(cpu, &cpu.DE.S.D, cpu.DE.S.D),
            // LD D,E
            0x53 => ld_r_r(cpu, &cpu.DE.S.D, cpu.DE.S.E),
            // LD D,H
            0x54 => ld_r_r(cpu, &cpu.DE.S.D, cpu.HL.S.H),
            // LD D,L
            0x55 => ld_r_r(cpu, &cpu.DE.S.D, cpu.HL.S.L),
            // LD D,(HL)
            0x56 => ld_r_rr(cpu, mmu, &cpu.DE.S.D, cpu.HL.HL),
            // LD D,A
            0x57 => ld_r_r(cpu, &cpu.DE.S.D, cpu.AF.S.A),
            // LD E,B
            0x58 => ld_r_r(cpu, &cpu.DE.S.E, cpu.BC.S.B),
            // LD E,C
            0x59 => ld_r_r(cpu, &cpu.DE.S.E, cpu.BC.S.C),
            // LD E,D
            0x5A => ld_r_r(cpu, &cpu.DE.S.E, cpu.DE.S.D),
            // LD E,E
            0x5B => ld_r_r(cpu, &cpu.DE.S.E, cpu.DE.S.E),
            // LD E,H
            0x5C => ld_r_r(cpu, &cpu.DE.S.E, cpu.HL.S.H),
            // LD E,L
            0x5D => ld_r_r(cpu, &cpu.DE.S.E, cpu.HL.S.L),
            // LD E,(HL)
            0x5E => ld_r_rr(cpu, mmu, &cpu.DE.S.E, cpu.HL.HL),
            // LD E,A
            0x5F => ld_r_r(cpu, &cpu.DE.S.E, cpu.AF.S.A),
            // LD H,B
            0x60 => ld_r_r(cpu, &cpu.HL.S.H, cpu.BC.S.B),
            // LD H,C
            0x61 => ld_r_r(cpu, &cpu.HL.S.H, cpu.BC.S.C),
            // LD H,D
            0x62 => ld_r_r(cpu, &cpu.HL.S.H, cpu.DE.S.D),
            // LD H,E
            0x63 => ld_r_r(cpu, &cpu.HL.S.H, cpu.DE.S.E),
            // LD H,H
            0x64 => ld_r_r(cpu, &cpu.HL.S.H, cpu.HL.S.H),
            // LD H,L
            0x65 => ld_r_r(cpu, &cpu.HL.S.H, cpu.HL.S.L),
            // LD H,(HL)
            0x66 => ld_r_rr(cpu, mmu, &cpu.HL.S.H, cpu.HL.HL),
            // LD H,A
            0x67 => ld_r_r(cpu, &cpu.HL.S.H, cpu.AF.S.A),
            // LD L,B
            0x68 => ld_r_r(cpu, &cpu.HL.S.L, cpu.BC.S.B),
            // LD L,C
            0x69 => ld_r_r(cpu, &cpu.HL.S.L, cpu.BC.S.C),
            // LD L,D
            0x6A => ld_r_r(cpu, &cpu.HL.S.L, cpu.DE.S.D),
            // LD L,E
            0x6B => ld_r_r(cpu, &cpu.HL.S.L, cpu.DE.S.E),
            // LD L,H
            0x6C => ld_r_r(cpu, &cpu.HL.S.L, cpu.HL.S.H),
            // LD L,L
            0x6D => ld_r_r(cpu, &cpu.HL.S.L, cpu.HL.S.L),
            // LD L,(HL)
            0x6E => ld_r_rr(cpu, mmu, &cpu.HL.S.L, cpu.HL.HL),
            // LD L,A
            0x6F => ld_r_r(cpu, &cpu.HL.S.L, cpu.AF.S.A),
            // LD (HL),B
            0x70 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.BC.S.B),
            // LD (HL),C
            0x71 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.BC.S.C),
            // LD (HL),D
            0x72 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.DE.S.D),
            // LD (HL),E
            0x73 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.DE.S.E),
            // LD (HL),H
            0x74 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.HL.S.H),
            // LD (HL),L
            0x75 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.HL.S.L),
            // HALT
            // 0x76 => halt(cpu),
            // LD (HL),A
            0x77 => ld_rr_r(cpu, mmu, cpu.HL.HL, cpu.AF.S.A),
            // LD A,B
            0x78 => ld_r_r(cpu, &cpu.AF.S.A, cpu.BC.S.B),
            // LD A,C
            0x79 => ld_r_r(cpu, &cpu.AF.S.A, cpu.BC.S.C),
            // LD A,D
            0x7A => ld_r_r(cpu, &cpu.AF.S.A, cpu.DE.S.D),
            // LD A,E
            0x7B => ld_r_r(cpu, &cpu.AF.S.A, cpu.DE.S.E),
            // LD A,H
            0x7C => ld_r_r(cpu, &cpu.AF.S.A, cpu.HL.S.H),
            // LD A,L
            0x7D => ld_r_r(cpu, &cpu.AF.S.A, cpu.HL.S.L),
            // LD A,(HL)
            0x7E => ld_r_rr(cpu, mmu, &cpu.AF.S.A, cpu.HL.HL),
            // LD A,A
            0x7F => ld_r_r(cpu, &cpu.AF.S.A, cpu.AF.S.A),
            // ADD A,B
            0x80 => add_r(cpu, cpu.BC.S.B),
            // ADD A,C
            0x81 => add_r(cpu, cpu.BC.S.C),
            // ADD A,D
            0x82 => add_r(cpu, cpu.DE.S.D),
            // ADD A,E
            0x83 => add_r(cpu, cpu.DE.S.E),
            // ADD A,H
            0x84 => add_r(cpu, cpu.HL.S.H),
            // ADD A,L
            0x85 => add_r(cpu, cpu.HL.S.L),
            // ADD A,(HL)
            0x86 => add_hl(cpu, mmu),
            // ADD A,A
            0x87 => add_r(cpu, cpu.AF.S.A),
            // ADC A,B
            0x88 => adc_r(cpu, cpu.BC.S.B),
            // ADC A,C
            0x89 => adc_r(cpu, cpu.BC.S.C),
            // ADC A,D
            0x8A => adc_r(cpu, cpu.DE.S.D),
            // ADC A,E
            0x8B => adc_r(cpu, cpu.DE.S.E),
            // ADC A,H
            0x8C => adc_r(cpu, cpu.HL.S.H),
            // ADC A,L
            0x8D => adc_r(cpu, cpu.HL.S.L),
            // ADC A,(HL)
            0x8E => adc_hl(cpu, mmu),
            // ADC A,A
            0x8F => adc_r(cpu, cpu.AF.S.A),
            // SUB B
            0x90 => sub_r(cpu, &cpu.BC.S.B),
            // SUB C
            0x91 => sub_r(cpu, &cpu.BC.S.C),
            // SUB D
            0x92 => sub_r(cpu, &cpu.DE.S.D),
            // SUB E
            0x93 => sub_r(cpu, &cpu.DE.S.E),
            // SUB H
            0x94 => sub_r(cpu, &cpu.HL.S.H),
            // SUB L
            0x95 => sub_r(cpu, &cpu.HL.S.L),
            // SUB (HL)
            0x96 => sub_hl(cpu, mmu),
            // SUB A
            0x97 => sub_r(cpu, &cpu.AF.S.A),
            // SBC A,B
            0x98 => sbc_r(cpu, cpu.BC.S.B),
            // SBC A,C
            0x99 => sbc_r(cpu, cpu.BC.S.C),
            // SBC A,D
            0x9A => sbc_r(cpu, cpu.DE.S.D),
            // SBC A,E
            0x9B => sbc_r(cpu, cpu.DE.S.E),
            // SBC A,H
            0x9C => sbc_r(cpu, cpu.HL.S.H),
            // SBC A,L
            0x9D => sbc_r(cpu, cpu.HL.S.L),
            // SBC (HL)
            0x9E => sbc_hl(cpu, mmu),
            // SBC A,A
            0x9F => sbc_r(cpu, cpu.AF.S.A),
            // AND B
            0xA0 => and_r(cpu, cpu.BC.S.B),
            // AND C
            0xA1 => and_r(cpu, cpu.BC.S.C),
            // AND D
            0xA2 => and_r(cpu, cpu.DE.S.D),
            // AND E
            0xA3 => and_r(cpu, cpu.DE.S.E),
            // AND H
            0xA4 => and_r(cpu, cpu.HL.S.H),
            // AND L
            0xA5 => and_r(cpu, cpu.HL.S.L),
            // AND (HL)
            0xA6 => and_hl(cpu, mmu),
            // AND A
            0xA7 => and_r(cpu, cpu.AF.S.A),
            // XOR A,B
            0xA8 => xor_r(cpu, cpu.BC.S.B),
            // XOR A,C
            0xA9 => xor_r(cpu, cpu.BC.S.C),
            // XOR A,D
            0xAA => xor_r(cpu, cpu.DE.S.D),
            // XOR A,E
            0xAB => xor_r(cpu, cpu.DE.S.E),
            // XOR A,H
            0xAC => xor_r(cpu, cpu.HL.S.H),
            // XOR A,L
            0xAD => xor_r(cpu, cpu.HL.S.L),
            // XOR (HL)
            0xAE => xor_hl(cpu, mmu),
            // XOR A,A
            0xAF => xor_r(cpu, cpu.AF.S.A),
            // OR B
            0xB0 => or_r(cpu, cpu.BC.S.B),
            // OR C
            0xB1 => or_r(cpu, cpu.BC.S.C),
            // OR D
            0xB2 => or_r(cpu, cpu.DE.S.D),
            // OR E
            0xB3 => or_r(cpu, cpu.DE.S.E),
            // OR H
            0xB4 => or_r(cpu, cpu.HL.S.H),
            // OR L
            0xB5 => or_r(cpu, cpu.HL.S.L),
            // OR (HL)
            0xB6 => or_hl(cpu, mmu),
            // OR A
            0xB7 => or_r(cpu, cpu.AF.S.A),
            // CP A,B
            0xB8 => cp_r(cpu, cpu.BC.S.B),
            // CP A,C
            0xB9 => cp_r(cpu, cpu.BC.S.C),
            // CP A,D
            0xBA => cp_r(cpu, cpu.DE.S.D),
            // CP A,E
            0xBB => cp_r(cpu, cpu.DE.S.E),
            // CP A,H
            0xBC => cp_r(cpu, cpu.HL.S.H),
            // CP A,L
            0xBD => cp_r(cpu, cpu.HL.S.L),
            // CP (HL)
            0xBE => cp_hl(cpu, mmu),
            // CP A,A
            0xBF => cp_r(cpu, cpu.AF.S.A),
            // RET NZ
            0xC0 => ret_nz(cpu, mmu),
            // POP BC
            0xC1 => pop_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.BC))),
            // JP NZ,a16
            0xC2 => jp_nz_a16(cpu, mmu),
            // JP a16
            0xC3 => jp_a16(cpu, mmu),
            // CALL NZ,a16
            0xC4 => call_nz_a16(cpu, mmu),
            // PUSH BC
            0xC5 => push_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.BC))),
            // ADD A,d8
            0xC6 => add_d8(cpu, mmu),
            // RST 00H
            0xC7 => rst(cpu, mmu),
            // RET Z
            0xC8 => ret_z(cpu, mmu),
            // RET
            0xC9 => ret(cpu, mmu),
            // JP Z,a16
            0xCA => jp_z_a16(cpu, mmu),
            // Pefix CB
            0xCB => {
                cpu.PC += 1;
                cpu.mCycles += 8;
                const prefix: u8 = mmu.read8(cpu.PC);
                cpu.PC += 1;
                switch (prefix) {
                    0x00 => rlc_r(cpu, &cpu.BC.S.B),
                    0x01 => rlc_r(cpu, &cpu.BC.S.C),
                    0x02 => rlc_r(cpu, &cpu.DE.S.D),
                    0x03 => rlc_r(cpu, &cpu.DE.S.E),
                    0x04 => rlc_r(cpu, &cpu.HL.S.H),
                    0x05 => rlc_r(cpu, &cpu.HL.S.L),
                    0x06 => rlc_hl(cpu, mmu),
                    0x07 => rlc_r(cpu, &cpu.AF.S.A),

                    0x08 => rrc_r(cpu, &cpu.BC.S.B),
                    0x09 => rrc_r(cpu, &cpu.BC.S.C),
                    0x0A => rrc_r(cpu, &cpu.DE.S.D),
                    0x0B => rrc_r(cpu, &cpu.DE.S.E),
                    0x0C => rrc_r(cpu, &cpu.HL.S.H),
                    0x0D => rrc_r(cpu, &cpu.HL.S.L),
                    0x0E => rrc_hl(cpu, mmu),
                    0x0F => rrc_r(cpu, &cpu.AF.S.A),

                    0x10 => rl_r(cpu, &cpu.BC.S.B),
                    0x11 => rl_r(cpu, &cpu.BC.S.C),
                    0x12 => rl_r(cpu, &cpu.DE.S.D),
                    0x13 => rl_r(cpu, &cpu.DE.S.E),
                    0x14 => rl_r(cpu, &cpu.HL.S.H),
                    0x15 => rl_r(cpu, &cpu.HL.S.L),
                    0x16 => rl_hl(cpu, mmu),
                    0x17 => rl_r(cpu, &cpu.AF.S.A),
                    0x18 => rr_r(cpu, &cpu.BC.S.B),
                    0x19 => rr_r(cpu, &cpu.BC.S.C),
                    0x1A => rr_r(cpu, &cpu.DE.S.D),
                    0x1B => rr_r(cpu, &cpu.DE.S.E),
                    0x1C => rr_r(cpu, &cpu.HL.S.H),
                    0x1D => rr_r(cpu, &cpu.HL.S.L),
                    0x1E => rr_hl(cpu, mmu),
                    0x1F => rr_r(cpu, &cpu.AF.S.A),

                    0x20 => sla_r(cpu, &cpu.BC.S.B),
                    0x21 => sla_r(cpu, &cpu.BC.S.C),
                    0x22 => sla_r(cpu, &cpu.DE.S.D),
                    0x23 => sla_r(cpu, &cpu.DE.S.E),
                    0x24 => sla_r(cpu, &cpu.HL.S.H),
                    0x25 => sla_r(cpu, &cpu.HL.S.L),
                    0x26 => sla_hl(cpu, mmu),
                    0x27 => sla_r(cpu, &cpu.AF.S.A),
                    0x28 => sra_r(cpu, &cpu.BC.S.B),
                    0x29 => sra_r(cpu, &cpu.BC.S.C),
                    0x2A => sra_r(cpu, &cpu.DE.S.D),
                    0x2B => sra_r(cpu, &cpu.DE.S.E),
                    0x2C => sra_r(cpu, &cpu.HL.S.H),
                    0x2D => sra_r(cpu, &cpu.HL.S.L),
                    0x2E => sra_hl(cpu, mmu),
                    0x2F => sra_r(cpu, &cpu.AF.S.A),

                    0x30 => swap_r(cpu, &cpu.BC.S.B),
                    0x31 => swap_r(cpu, &cpu.BC.S.C),
                    0x32 => swap_r(cpu, &cpu.DE.S.D),
                    0x33 => swap_r(cpu, &cpu.DE.S.E),
                    0x34 => swap_r(cpu, &cpu.HL.S.H),
                    0x35 => swap_r(cpu, &cpu.HL.S.L),
                    0x36 => swap_hl(cpu, mmu),
                    0x37 => swap_r(cpu, &cpu.AF.S.A),
                    0x38 => srl_r(cpu, &cpu.BC.S.B),
                    0x39 => srl_r(cpu, &cpu.BC.S.C),
                    0x3A => srl_r(cpu, &cpu.DE.S.D),
                    0x3B => srl_r(cpu, &cpu.DE.S.E),
                    0x3C => srl_r(cpu, &cpu.HL.S.H),
                    0x3D => srl_r(cpu, &cpu.HL.S.L),
                    0x3E => srl_hl(cpu, mmu),
                    0x3F => srl_r(cpu, &cpu.AF.S.A),

                    0x40 => bit_r(cpu, 0, &cpu.BC.S.B),
                    0x41 => bit_r(cpu, 0, &cpu.BC.S.C),
                    0x42 => bit_r(cpu, 0, &cpu.DE.S.D),
                    0x43 => bit_r(cpu, 0, &cpu.DE.S.E),
                    0x44 => bit_r(cpu, 0, &cpu.HL.S.H),
                    0x45 => bit_r(cpu, 0, &cpu.HL.S.L),
                    0x46 => bit_hl(cpu, mmu, 0),
                    0x47 => bit_r(cpu, 0, &cpu.AF.S.A),
                    0x48 => bit_r(cpu, 1, &cpu.BC.S.B),
                    0x49 => bit_r(cpu, 1, &cpu.BC.S.C),
                    0x4A => bit_r(cpu, 1, &cpu.DE.S.D),
                    0x4B => bit_r(cpu, 1, &cpu.DE.S.E),
                    0x4C => bit_r(cpu, 1, &cpu.HL.S.H),
                    0x4D => bit_r(cpu, 1, &cpu.HL.S.L),
                    0x4E => bit_hl(cpu, mmu, 1),
                    0x4F => bit_r(cpu, 1, &cpu.AF.S.A),

                    0x50 => bit_r(cpu, 2, &cpu.BC.S.B),
                    0x51 => bit_r(cpu, 2, &cpu.BC.S.C),
                    0x52 => bit_r(cpu, 2, &cpu.DE.S.D),
                    0x53 => bit_r(cpu, 2, &cpu.DE.S.E),
                    0x54 => bit_r(cpu, 2, &cpu.HL.S.H),
                    0x55 => bit_r(cpu, 2, &cpu.HL.S.L),
                    0x56 => bit_hl(cpu, mmu, 2),
                    0x57 => bit_r(cpu, 2, &cpu.AF.S.A),
                    0x58 => bit_r(cpu, 3, &cpu.BC.S.B),
                    0x59 => bit_r(cpu, 3, &cpu.BC.S.C),
                    0x5A => bit_r(cpu, 3, &cpu.DE.S.D),
                    0x5B => bit_r(cpu, 3, &cpu.DE.S.E),
                    0x5C => bit_r(cpu, 3, &cpu.HL.S.H),
                    0x5D => bit_r(cpu, 3, &cpu.HL.S.L),
                    0x5E => bit_hl(cpu, mmu, 3),
                    0x5F => bit_r(cpu, 3, &cpu.AF.S.A),

                    0x60 => bit_r(cpu, 4, &cpu.BC.S.B),
                    0x61 => bit_r(cpu, 4, &cpu.BC.S.C),
                    0x62 => bit_r(cpu, 4, &cpu.DE.S.D),
                    0x63 => bit_r(cpu, 4, &cpu.DE.S.E),
                    0x64 => bit_r(cpu, 4, &cpu.HL.S.H),
                    0x65 => bit_r(cpu, 4, &cpu.HL.S.L),
                    0x66 => bit_hl(cpu, mmu, 4),
                    0x67 => bit_r(cpu, 4, &cpu.AF.S.A),
                    0x68 => bit_r(cpu, 5, &cpu.BC.S.B),
                    0x69 => bit_r(cpu, 5, &cpu.BC.S.C),
                    0x6A => bit_r(cpu, 5, &cpu.DE.S.D),
                    0x6B => bit_r(cpu, 5, &cpu.DE.S.E),
                    0x6C => bit_r(cpu, 5, &cpu.HL.S.H),
                    0x6D => bit_r(cpu, 5, &cpu.HL.S.L),
                    0x6E => bit_hl(cpu, mmu, 5),
                    0x6F => bit_r(cpu, 5, &cpu.AF.S.A),

                    0x70 => bit_r(cpu, 6, &cpu.BC.S.B),
                    0x71 => bit_r(cpu, 6, &cpu.BC.S.C),
                    0x72 => bit_r(cpu, 6, &cpu.DE.S.D),
                    0x73 => bit_r(cpu, 6, &cpu.DE.S.E),
                    0x74 => bit_r(cpu, 6, &cpu.HL.S.H),
                    0x75 => bit_r(cpu, 6, &cpu.HL.S.L),
                    0x76 => bit_hl(cpu, mmu, 6),
                    0x77 => bit_r(cpu, 6, &cpu.AF.S.A),
                    0x78 => bit_r(cpu, 7, &cpu.BC.S.B),
                    0x79 => bit_r(cpu, 7, &cpu.BC.S.C),
                    0x7A => bit_r(cpu, 7, &cpu.DE.S.D),
                    0x7B => bit_r(cpu, 7, &cpu.DE.S.E),
                    0x7C => bit_r(cpu, 7, &cpu.HL.S.H),
                    0x7D => bit_r(cpu, 7, &cpu.HL.S.L),
                    0x7E => bit_hl(cpu, mmu, 7),
                    0x7F => bit_r(cpu, 7, &cpu.AF.S.A),

                    0x80 => res_r(cpu, 0, &cpu.BC.S.B),
                    0x81 => res_r(cpu, 0, &cpu.BC.S.C),
                    0x82 => res_r(cpu, 0, &cpu.DE.S.D),
                    0x83 => res_r(cpu, 0, &cpu.DE.S.E),
                    0x84 => res_r(cpu, 0, &cpu.HL.S.H),
                    0x85 => res_r(cpu, 0, &cpu.HL.S.L),
                    0x86 => res_hl(cpu, mmu, 0),
                    0x87 => res_r(cpu, 0, &cpu.AF.S.A),
                    0x88 => res_r(cpu, 1, &cpu.BC.S.B),
                    0x89 => res_r(cpu, 1, &cpu.BC.S.C),
                    0x8A => res_r(cpu, 1, &cpu.DE.S.D),
                    0x8B => res_r(cpu, 1, &cpu.DE.S.E),
                    0x8C => res_r(cpu, 1, &cpu.HL.S.H),
                    0x8D => res_r(cpu, 1, &cpu.HL.S.L),
                    0x8E => res_hl(cpu, mmu, 1),
                    0x8F => res_r(cpu, 1, &cpu.AF.S.A),

                    0x90 => res_r(cpu, 2, &cpu.BC.S.B),
                    0x91 => res_r(cpu, 2, &cpu.BC.S.C),
                    0x92 => res_r(cpu, 2, &cpu.DE.S.D),
                    0x93 => res_r(cpu, 2, &cpu.DE.S.E),
                    0x94 => res_r(cpu, 2, &cpu.HL.S.H),
                    0x95 => res_r(cpu, 2, &cpu.HL.S.L),
                    0x96 => res_hl(cpu, mmu, 2),
                    0x97 => res_r(cpu, 2, &cpu.AF.S.A),
                    0x98 => res_r(cpu, 3, &cpu.BC.S.B),
                    0x99 => res_r(cpu, 3, &cpu.BC.S.C),
                    0x9A => res_r(cpu, 3, &cpu.DE.S.D),
                    0x9B => res_r(cpu, 3, &cpu.DE.S.E),
                    0x9C => res_r(cpu, 3, &cpu.HL.S.H),
                    0x9D => res_r(cpu, 3, &cpu.HL.S.L),
                    0x9E => res_hl(cpu, mmu, 3),
                    0x9F => res_r(cpu, 3, &cpu.AF.S.A),

                    0xA0 => res_r(cpu, 4, &cpu.BC.S.B),
                    0xA1 => res_r(cpu, 4, &cpu.BC.S.C),
                    0xA2 => res_r(cpu, 4, &cpu.DE.S.D),
                    0xA3 => res_r(cpu, 4, &cpu.DE.S.E),
                    0xA4 => res_r(cpu, 4, &cpu.HL.S.H),
                    0xA5 => res_r(cpu, 4, &cpu.HL.S.L),
                    0xA6 => res_hl(cpu, mmu, 4),
                    0xA7 => res_r(cpu, 4, &cpu.AF.S.A),
                    0xA8 => res_r(cpu, 5, &cpu.BC.S.B),
                    0xA9 => res_r(cpu, 5, &cpu.BC.S.C),
                    0xAA => res_r(cpu, 5, &cpu.DE.S.D),
                    0xAB => res_r(cpu, 5, &cpu.DE.S.E),
                    0xAC => res_r(cpu, 5, &cpu.HL.S.H),
                    0xAD => res_r(cpu, 5, &cpu.HL.S.L),
                    0xAE => res_hl(cpu, mmu, 5),
                    0xAF => res_r(cpu, 5, &cpu.AF.S.A),

                    0xB0 => res_r(cpu, 6, &cpu.BC.S.B),
                    0xB1 => res_r(cpu, 6, &cpu.BC.S.C),
                    0xB2 => res_r(cpu, 6, &cpu.DE.S.D),
                    0xB3 => res_r(cpu, 6, &cpu.DE.S.E),
                    0xB4 => res_r(cpu, 6, &cpu.HL.S.H),
                    0xB5 => res_r(cpu, 6, &cpu.HL.S.L),
                    0xB6 => res_hl(cpu, mmu, 6),
                    0xB7 => res_r(cpu, 6, &cpu.AF.S.A),
                    0xB8 => res_r(cpu, 7, &cpu.BC.S.B),
                    0xB9 => res_r(cpu, 7, &cpu.BC.S.C),
                    0xBA => res_r(cpu, 7, &cpu.DE.S.D),
                    0xBB => res_r(cpu, 7, &cpu.DE.S.E),
                    0xBC => res_r(cpu, 7, &cpu.HL.S.H),
                    0xBD => res_r(cpu, 7, &cpu.HL.S.L),
                    0xBE => res_hl(cpu, mmu, 7),
                    0xBF => res_r(cpu, 7, &cpu.AF.S.A),

                    0xC0 => set_r(cpu, 0, &cpu.BC.S.B),
                    0xC1 => set_r(cpu, 0, &cpu.BC.S.C),
                    0xC2 => set_r(cpu, 0, &cpu.DE.S.D),
                    0xC3 => set_r(cpu, 0, &cpu.DE.S.E),
                    0xC4 => set_r(cpu, 0, &cpu.HL.S.H),
                    0xC5 => set_r(cpu, 0, &cpu.HL.S.L),
                    0xC6 => set_hl(cpu, mmu, 0),
                    0xC7 => set_r(cpu, 0, &cpu.AF.S.A),
                    0xC8 => set_r(cpu, 1, &cpu.BC.S.B),
                    0xC9 => set_r(cpu, 1, &cpu.BC.S.C),
                    0xCA => set_r(cpu, 1, &cpu.DE.S.D),
                    0xCB => set_r(cpu, 1, &cpu.DE.S.E),
                    0xCC => set_r(cpu, 1, &cpu.HL.S.H),
                    0xCD => set_r(cpu, 1, &cpu.HL.S.L),
                    0xCE => set_hl(cpu, mmu, 1),
                    0xCF => set_r(cpu, 1, &cpu.AF.S.A),

                    0xD0 => set_r(cpu, 2, &cpu.BC.S.B),
                    0xD1 => set_r(cpu, 2, &cpu.BC.S.C),
                    0xD2 => set_r(cpu, 2, &cpu.DE.S.D),
                    0xD3 => set_r(cpu, 2, &cpu.DE.S.E),
                    0xD4 => set_r(cpu, 2, &cpu.HL.S.H),
                    0xD5 => set_r(cpu, 2, &cpu.HL.S.L),
                    0xD6 => set_hl(cpu, mmu, 2),
                    0xD7 => set_r(cpu, 2, &cpu.AF.S.A),
                    0xD8 => set_r(cpu, 3, &cpu.BC.S.B),
                    0xD9 => set_r(cpu, 3, &cpu.BC.S.C),
                    0xDA => set_r(cpu, 3, &cpu.DE.S.D),
                    0xDB => set_r(cpu, 3, &cpu.DE.S.E),
                    0xDC => set_r(cpu, 3, &cpu.HL.S.H),
                    0xDD => set_r(cpu, 3, &cpu.HL.S.L),
                    0xDE => set_hl(cpu, mmu, 3),
                    0xDF => set_r(cpu, 3, &cpu.AF.S.A),

                    0xE0 => set_r(cpu, 4, &cpu.BC.S.B),
                    0xE1 => set_r(cpu, 4, &cpu.BC.S.C),
                    0xE2 => set_r(cpu, 4, &cpu.DE.S.D),
                    0xE3 => set_r(cpu, 4, &cpu.DE.S.E),
                    0xE4 => set_r(cpu, 4, &cpu.HL.S.H),
                    0xE5 => set_r(cpu, 4, &cpu.HL.S.L),
                    0xE6 => set_hl(cpu, mmu, 4),
                    0xE7 => set_r(cpu, 4, &cpu.AF.S.A),
                    0xE8 => set_r(cpu, 5, &cpu.BC.S.B),
                    0xE9 => set_r(cpu, 5, &cpu.BC.S.C),
                    0xEA => set_r(cpu, 5, &cpu.DE.S.D),
                    0xEB => set_r(cpu, 5, &cpu.DE.S.E),
                    0xEC => set_r(cpu, 5, &cpu.HL.S.H),
                    0xED => set_r(cpu, 5, &cpu.HL.S.L),
                    0xEE => set_hl(cpu, mmu, 5),
                    0xEF => set_r(cpu, 5, &cpu.AF.S.A),

                    0xF0 => set_r(cpu, 6, &cpu.BC.S.B),
                    0xF1 => set_r(cpu, 6, &cpu.BC.S.C),
                    0xF2 => set_r(cpu, 6, &cpu.DE.S.D),
                    0xF3 => set_r(cpu, 6, &cpu.DE.S.E),
                    0xF4 => set_r(cpu, 6, &cpu.HL.S.H),
                    0xF5 => set_r(cpu, 6, &cpu.HL.S.L),
                    0xF6 => set_hl(cpu, mmu, 6),
                    0xF7 => set_r(cpu, 6, &cpu.AF.S.A),
                    0xF8 => set_r(cpu, 7, &cpu.BC.S.B),
                    0xF9 => set_r(cpu, 7, &cpu.BC.S.C),
                    0xFA => set_r(cpu, 7, &cpu.DE.S.D),
                    0xFB => set_r(cpu, 7, &cpu.DE.S.E),
                    0xFC => set_r(cpu, 7, &cpu.HL.S.H),
                    0xFD => set_r(cpu, 7, &cpu.HL.S.L),
                    0xFE => set_hl(cpu, mmu, 7),
                    0xFF => set_r(cpu, 7, &cpu.AF.S.A),
                }
            },
            // CALL Z,a16
            0xCC => call_z_a16(cpu, mmu),
            // CALL nn
            0xCD => call_a16(cpu, mmu),
            // ADC A,d8
            0xCE => adc_d8(cpu, mmu),
            // RST 08H
            0xCF => rst(cpu, mmu),
            // RET NC
            0xD0 => ret_nc(cpu, mmu),
            // POP DE
            0xD1 => pop_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.DE))),
            // JP NC,a16
            0xD2 => jp_nc_a16(cpu, mmu),
            // CALL NC,a16
            0xD4 => call_nc_a16(cpu, mmu),
            // PUSH DE
            0xD5 => push_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.DE))),
            // SUB d8
            0xD6 => sub_d8(cpu, mmu),
            // RST 10H
            0xD7 => rst(cpu, mmu),
            // RET C
            0xD8 => ret_c(cpu, mmu),
            // RETI
            0xD9 => reti(cpu, mmu),
            // JP C,a16
            0xDA => jp_c_a16(cpu, mmu),
            // CALL C,a16
            0xDC => call_c_a16(cpu, mmu),
            // SBC A,d8
            0xDE => sbc_d8(cpu, mmu),
            // RST 18H
            0xDF => rst(cpu, mmu),
            // LDH (a8), A | LD ($FF00+a8),A
            0xE0 => ldh_a8_a(cpu, mmu),
            // POP HL
            0xE1 => pop_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.HL))),
            // LD (A),(C) | LD ($FF00+C),A
            0xE2 => ld_c_a(cpu, mmu),
            // PUSH HL
            0xE5 => push_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.HL))),
            // AND d8
            0xE6 => and_d8(cpu, mmu),
            // RST 20H
            0xE7 => rst(cpu, mmu),
            // ADD SP,r8
            0xE8 => add_sp_r8(cpu, mmu),
            // JP (HL)
            0xE9 => jp_hl(cpu),
            // LD (a16),A
            0xEA => ld_a16_a(cpu, mmu),
            // XOR d8
            0xEE => xor_d8(cpu, mmu),
            // RST 28H
            0xEF => rst(cpu, mmu),
            // LDH A,(a8)
            0xF0 => ldh_a_a8(cpu, mmu),
            // POP AF
            0xF1 => pop_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.AF))),
            // LD A,(C) | LD A,($FF00+C)
            0xF2 => ld_a_c(cpu, mmu),
            // DI
            0xF3 => di(cpu, mmu),
            // PUSH AF
            0xF5 => push_rr(cpu, mmu, &(@bitCast(RegisterReference, cpu.AF))),
            // OR d8
            0xF6 => or_d8(cpu, mmu),
            // RST 30H
            0xF7 => rst(cpu, mmu),
            // LD HL,SP+r8
            0xF8 => ld_hl_sp_r8(cpu, mmu),
            // LD SP,HL
            0xF9 => ld_sp_hl(cpu),
            // LD A,(a16)
            0xFA => ld_a_a16(cpu, mmu),
            // EI
            0xFB => ei(cpu, mmu),
            // CP d8
            0xFE => cp_d8(cpu, mmu),
            // RST 38H
            0xFF => rst(cpu, mmu),
            else => blk: {
                cpu.halt = true;
                std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ cpu.PC, mmu.read8(cpu.PC) });
                // std.log.info("Flags={B:0>1}", .{cpu.AF.S.F});
                break :blk return RuntimeError.InstructionNotImplemented;
            },
        }
    }
};
