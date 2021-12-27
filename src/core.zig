const std = @import("std");

const cpu = @import("cpu.zig");
const CPU = cpu.CPU;
const RegisterReference = cpu.RegisterReference;

const Memory = @import("memory.zig").Memory;

const debugger = @import("debugger.zig");
const Debugger = debugger.Debugger;

const disassembler = @import("disassembler.zig");

pub const RuntimeError = error{ InstructionNotImplemented, YouSuck };

pub const Core = struct {
    cpu: CPU,
    memory: Memory,
    debugger: Debugger,
    tCycles: u64,
    halt: bool,
    debugStop: bool,

    pub fn init() Core {
        return Core{
            .cpu = CPU.init(),
            .memory = Memory.init(),
            .debugger = Debugger.init(),
            .tCycles = 0,
            .halt = false,
            .debugStop = false,
        };
    }

    pub fn startDebugger(core: *Core) !void {
        try core.debugger.start(core);
    }

    pub fn nop(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        // std.log.info("NOP", .{});
    }

    pub fn inc_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        r.* +%= 1;

        // core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((r.* & 0x0F) == 0)
            core.cpu.AF.S.F.h = 1;

        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn inc_rr(core: *Core, rr: *u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        rr.* +%= 1;
    }

    pub fn inc_dhl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;
        const value: u8 = core.memory.read8(core.cpu.HL.HL) +% 1;
        core.memory.write8(core.cpu.HL.HL, value);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((value & 0x0F) == 0)
            core.cpu.AF.S.F.h = 1;
        if ((value & 0xFF) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn dec_dhl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;
        const value: u8 = core.memory.read8(core.cpu.HL.HL) -% 1;
        core.memory.write8(core.cpu.HL.HL, value);

        // core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((value & 0x0F) == 0x0F)
            core.cpu.AF.S.F.h = 1;
        if ((value & 0xFF) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn ld_dhl_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;

        const d8: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        core.memory.write8(core.cpu.HL.HL, d8);
    }

    pub fn dec_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const value: u8 = r.* -% 1;
        r.* = value;

        // core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((r.* & 0x0f) == 0xf)
            core.cpu.AF.S.F.h = 1;

        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn dec_rr(core: *Core, rr: *u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        rr.* -%= 1;
    }

    pub fn sub_r(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const d8: u8 = r.*;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A -%= d8;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn sub_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A -%= d8;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn sub_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A -%= d8;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn sbc_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        const a: u8 = core.cpu.AF.S.A;
        const carry: u1 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A = (a -% r -% carry);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a -% r -% carry) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn sbc_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;
        const carry: u1 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A = (a -% r -% carry);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a - r - carry) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn sbc_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;
        const carry: u1 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A = (a -% r -% carry);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a -% r -% carry) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) < (r & 0xF) + carry)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u64, a) -% @intCast(u64, r) -% carry > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn add_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A +%= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) > 0x0F)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn add_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A +%= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a +% r) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (r & 0xf) > 0x0f)
            core.cpu.AF.S.F.h = 1;

        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn add_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A +%= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a +% r) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (r & 0xf) > 0x0f)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn add_hl_rr(core: *Core, rr: u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const hl: u16 = core.cpu.HL.HL;
        core.cpu.HL.HL +%= rr;
// c h n z
        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.n = 0;
        // core.cpu.AF.S.F.z = 0;

        if ((((hl & 0xFFF) + (rr & 0xFFF)) & 0x1000) != 0)
            core.cpu.AF.S.F.h = 1;

        // if ( (hl+rr) &0x10000 != 0)
        if ( ((@intCast(u64, hl) + @intCast(u64, rr)) & 0x10000) != 0)
            core.cpu.AF.S.F.c = 1;
        // if ( ((@intCast(u32, hl) + @intCast(u32, rr)) & 0x10000) != 0)
        // if (@intCast(u16, hl&0xFF) + @intCast(u16, rr & 0xFF) > 0xff)
        // if (@intCast(u16, hl >> 8) + @intCast(u8, rr >> 8) > 0xff)
    }

    pub fn adc_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        const a: u8 = core.cpu.AF.S.A;
        const carry: u8 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A = (a +% r +% carry);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a +% r +% carry) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) + carry > 0x0F)
            core.cpu.AF.S.F.h = 1;
        if (@intCast(u16, a) + @intCast(u16, r) + carry > 0xff)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn adc_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const a: u8 = core.cpu.AF.S.A;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const carry: u1 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A = (a + r + carry);

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a + r + carry) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xF) + (r & 0xF) + carry > 0x0F)
            core.cpu.AF.S.F.h = 1;
        if ((a + r) + carry > 0xFF)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn adc_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const a: u8 = core.cpu.AF.S.A;
        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const carry:u8 = @boolToInt(core.cpu.AF.S.F.c != 0);
        core.cpu.AF.S.A +%= r+%carry;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if(core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
        
        if((a & 0xF) + (r & 0xF) + carry > 0x0F)
            core.cpu.AF.S.F.h = 1;
        
        if (@intCast(u16, a)+% @intCast(u16, r) +% carry > 0xff)
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

    pub fn ld_a_hli(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.cpu.AF.AF &= 0xFF;
        core.cpu.AF.S.A = core.memory.read8(core.cpu.HL.HL);
        core.cpu.HL.HL+%=1;
    }

    pub fn ld_hld_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        core.memory.write8(core.cpu.HL.HL, r);
        core.cpu.HL.HL -%= 1;
    }

    pub fn ld_r_hld(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        r.* = core.memory.read8(core.cpu.HL.HL);
        core.cpu.HL.HL -%= 1;
    }

    pub fn ldh_a_a8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;

        const a8: u16 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        core.cpu.AF.S.A = core.memory.read8(0xff00 + a8);
        // std.log.info("LDH A,(${x:0>2})=${x:0>2}", .{ a8, gb.cpu.AF.S.A });
    }

    pub fn ldh_a8_a(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;
        const a8: u16 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        core.memory.write8(0xFF00 + a8, core.cpu.AF.S.A);
    }

    pub fn ldc_a(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.memory.write8(0xFF00 + @intCast(u16, core.cpu.BC.S.C), core.cpu.AF.S.A);
    }

    pub fn lda_c(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.cpu.AF.S.A = core.memory.read8(0xFF00 + @intCast(u16, core.cpu.BC.S.C));
    }

    pub fn ld_a16_a(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        core.memory.write8((@as(u16, lsb) << 8) | msb, core.cpu.AF.S.A);
    }

    pub fn ld_a_a16(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        core.cpu.AF.S.A = core.memory.read8((@as(u16, lsb) << 8) | msb);
    }

    pub fn ld_da16_sp(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 20;

        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const address: u16 = (@as(u16, lsb) << 8) | msb;
        core.memory.write8(address, @intCast(u8, core.cpu.SP & 0xFF));
        core.memory.write8(address + 1, @intCast(u8, core.cpu.SP >> 8));
    }

    pub fn ld_hl_sp_r8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 12;

        const offset: i16 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;
        core.cpu.HL.HL = core.cpu.SP +% @bitCast(u16, offset);
        core.cpu.AF.AF &= 0xFF00;

        if ((core.cpu.SP & 0xF) + (@bitCast(u16, offset) & 0xF) > 0xF)
            core.cpu.AF.S.F.h = 1;
        if ((core.cpu.SP & 0xFF) + (@bitCast(u16, offset) & 0xFF) > 0xFF)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn ld_sp_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        core.cpu.SP = core.cpu.HL.HL;
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

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (carry)
            core.cpu.AF.AF |= 0x0100;

        if (bit7)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn rlca(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const carry: bool = (core.cpu.AF.AF & 0x8000) != 0;
        core.cpu.AF.AF = (core.cpu.AF.AF & 0xFF00) << 1;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (carry) {
            core.cpu.AF.S.F.c = 1;
            core.cpu.AF.AF |= 0x0100;
        }
    }

    pub fn rrca(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const carry: bool = (core.cpu.AF.AF & 0x100) != 0;
        core.cpu.AF.AF = (core.cpu.AF.AF >> 1) & 0xFF00;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (carry) {
            core.cpu.AF.S.F.c = 1;
            core.cpu.AF.AF |= 0x8000;
        }
    }

    pub fn rra(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const bit1: bool = (core.cpu.AF.AF & 0x0100) != 0;
        const carry: bool = (core.cpu.AF.S.F.c) != 0;

        core.cpu.AF.S.A >>=1;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (carry)
            core.cpu.AF.AF |= 0x8000;
        if (bit1)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn cpl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        core.cpu.AF.AF ^= 0xFF00;

        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 1;
    }

    pub fn scf(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        core.cpu.AF.S.F.c = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.n = 0;
    }

    pub fn ccf(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        if(core.cpu.AF.S.F.c == 1) {
            core.cpu.AF.S.F.c = 0;
        } else {
            core.cpu.AF.S.F.c = 1;
        }
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.n = 0;
    }

    pub fn cp_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.n = 1;

        if (a == r)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < r)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn cp_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == r)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < r)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn cp_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == r)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (r & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < r)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn cp_rr(core: *Core, rr: u16) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const d8: u8 = core.memory.read8(rr);
        const a: u8 = core.cpu.AF.S.A;

        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 1;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (a == d8)
            core.cpu.AF.S.F.z = 1;

        if ((a & 0xf) < (d8 & 0xf))
            core.cpu.AF.S.F.h = 1;

        if (a < d8)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn pop_rr(core: *Core, rr: *RegisterReference) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        const msb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;
        rr.*.S.rx = msb;

        const lsb: u8 = core.memory.read8(core.cpu.SP);
        core.cpu.SP += 1;
        rr.*.S.ry = lsb;

        core.cpu.AF.AF &= 0xFFF0; // Make sure we don't set impossible flags on F! See Blargg's PUSH AF test.
    }

    pub fn push_rr(core: *Core, rr: *RegisterReference) void {
        core.cpu.PC += 1;
        core.tCycles += 16;

        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, rr.*.S.ry);

        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, rr.*.S.rx);
    }

    pub fn call_a16(core: *Core) void {
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

    pub fn call_nz_a16(core: *Core) void {
        if (core.cpu.AF.S.F.z != 1) {
            // std.log.info("(yes)CALL NZ a16", .{});
            call_a16(core);
        } else {
            // std.log.info("(no)CALL NZ a16", .{});
            core.cpu.PC += 3;
            core.tCycles += 12;
        }
    }

    pub fn call_z_a16(core: *Core) void {
        if (core.cpu.AF.S.F.z == 1) {
            call_a16(core);
        } else {
            core.cpu.PC += 3;
            core.tCycles += 12;
        }
    }

    pub fn call_nc_a16(core: *Core) void {
        if (core.cpu.AF.S.F.c != 1) {
            call_a16(core);
        } else {
            core.cpu.PC += 3;
            core.tCycles += 12;
        }
    }

    pub fn call_c_a16(core: *Core) void {
        if (core.cpu.AF.S.F.c == 1) {
            call_a16(core);
        } else {
            core.cpu.PC += 3;
            core.tCycles += 12;
        }
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

    pub fn reti(core: *Core) void {
        ret(core);
        core.memory.interruptsEnabled = true;
    }

    pub fn ret_nz(core: *Core) void {
        if (core.cpu.AF.S.F.z != 1) {
            core.tCycles += 4;
            ret(core);
        } else {
            core.cpu.PC+=1;
            core.tCycles += 8;
        }
    }

    pub fn ret_z(core: *Core) void {
        if (core.cpu.AF.S.F.z == 1) {
            core.tCycles += 4;
            ret(core);
        } else {
            core.cpu.PC+=1;
            core.tCycles += 8;
        }
    }

    pub fn ret_nc(core: *Core) void {
        if (core.cpu.AF.S.F.c != 1) {
            core.tCycles += 4;
            ret(core);
        } else {
            core.cpu.PC+=1;
            core.tCycles += 8;
        }
    }

    pub fn ret_c(core: *Core) void {
        if (core.cpu.AF.S.F.c == 1) {
            core.tCycles += 4;
            ret(core);
        } else {
            core.cpu.PC+=1;
            core.tCycles += 8;
        }
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
            // std.log.info("JR Z,{d} (true) ${B:0>1}", .{r8, core.cpu.AF.S.F});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR Z,{d} (false) ${B:0>1}", .{r8, core.cpu.AF.S.F});
        }
    }

    pub fn jr_nc_r8(core: *Core) void {
        core.cpu.PC += 1;
        // const r8: i8 = @bitCast(i8, core.memory.Raw[core.cpu.PC]);
        const r8: i8 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;

        if (core.cpu.AF.S.F.c != 1) {
            core.tCycles += 12;
            // std.log.info("JR NC,{d} (true) f={B:0>1}", .{r8, core.cpu.AF.S.F});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR NC,{d} (false) f={B:0>1}", .{r8, core.cpu.AF.S.F});
        }
    }

    pub fn jr_c_r8(core: *Core) void {
        core.cpu.PC += 1;
        // const r8: i8 = @bitCast(i8, core.memory.Raw[core.cpu.PC]);
        const r8: i8 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;

        if (core.cpu.AF.S.F.c == 1) {
            core.tCycles += 12;
            // std.log.info("JR C,{d} (true) ${B:0>1}", .{r8, core.cpu.AF.S.F});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR C,{d} (false) ${B:0>1}", .{r8, core.cpu.AF.S.F});
        }
    }

    pub fn jp_a16(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 16;
        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        core.cpu.PC = (@as(u16, lsb) << 8) | msb;
    }

    pub fn jp_nz_a16(core: *Core) void {
        if (core.cpu.AF.S.F.z != 1) {
            jp_a16(core);
        } else {
            core.tCycles += 12;
            core.cpu.PC+=3;
        }
    }

    pub fn jp_z_a16(core: *Core) void {
        if (core.cpu.AF.S.F.z == 1) {
            jp_a16(core);
        } else {
            core.tCycles += 12;
            core.cpu.PC+=3;
        }
    }

    pub fn jp_nc_a16(core: *Core) void {
        if (core.cpu.AF.S.F.c != 1) {
            jp_a16(core);
        } else {
            core.tCycles += 12;
            core.cpu.PC+=3;
        }
    }

    pub fn jp_c_a16(core: *Core) void {
        if (core.cpu.AF.S.F.c == 1) {
            jp_a16(core);
        } else {
            core.tCycles += 12;
            core.cpu.PC+=3;
        }
    }

    pub fn jp_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        core.cpu.PC = core.cpu.HL.HL;
    }

    pub fn and_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A = (a & r);
        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.h = 1;
        if ((a & r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn and_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A = (a & r);
        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.unused = 0;
        core.cpu.AF.S.F.h = 1;
        if ((a & r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn and_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A = (a & r);
        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.unused = 0;
        core.cpu.AF.S.F.h = 1;

        if ((a & r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn add_sp_r8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles+=16;
        const sp: u16 = core.cpu.SP;
        const offset: i16 = core.memory.readi8(core.cpu.PC);
        core.cpu.PC += 1;

        core.cpu.SP +%= @bitCast(u16, offset);

        core.cpu.AF.AF &= 0xFF00;
        // std.log.info("add sp r8 ${x:0>4} ${x:0>2}", .{core.cpu.SP, offset});
        if ((sp & 0xF) + (@bitCast(u16, offset) & 0xF) > 0xF)
            core.cpu.AF.S.F.h = 1;
        if ((sp & 0xFF) + (@bitCast(u16, offset) & 0xFF) > 0xFF)
            core.cpu.AF.S.F.c = 1;
    }

    pub fn xor_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 1;
        core.cpu.AF.S.A ^= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
        // std.log.info("XOR ${B:0>4}", .{core.cpu.AF.S.F});
    }

    pub fn xor_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.cpu.AF.S.A ^= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn xor_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        core.cpu.AF.S.A ^= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if (core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn or_r(core: *Core, r: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 4;

        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A |= r;
        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn or_hl(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A |= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn or_d8(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 8;

        const r: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        const a: u8 = core.cpu.AF.S.A;
        core.cpu.AF.S.A |= r;

        core.cpu.AF.S.F.c = 0;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.h = 0;
        core.cpu.AF.S.F.z = 0;

        if ((a | r) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn di(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        core.memory.interruptsEnabled = false;
    }

    pub fn ei(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 4;
        core.memory.interruptsEnabled = true;
    }

    pub fn rst(core: *Core) void {
        core.tCycles += 16;
        const opcode: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;
        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, @intCast(u8, core.cpu.PC >> 8));
        core.cpu.SP -= 1;
        core.memory.write8(core.cpu.SP, @truncate(u8, core.cpu.PC));
        core.cpu.PC = opcode ^ 0xC7;
    }

    pub fn rlc_r(core: *Core, r: *u8) void {
        const carry: bool = (r.* & 0x80) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value = (r.* << 1) | @as(u8, @boolToInt(carry));
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rlc_hl(core: *Core) void {
        core.tCycles += 8;
        core.cpu.AF.AF &= 0xFF00;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const carry: bool = (r & 0x80) != 0;
        const value = (r << 1) | @intCast(u8, @boolToInt(carry));
        core.memory.write8(core.cpu.HL.HL, value);
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rl_r(core: *Core, r: *u8) void {
        const carry: bool = core.cpu.AF.S.F.c != 0;
        const bit7: bool = (r.* & 0x80) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value: u8 = (r.* << 1) | @as(u8, @boolToInt(carry));
        r.* = value;
        if (bit7)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rl_hl(core: *Core) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        const carry: bool = core.cpu.AF.S.F.c != 0;
        const bit7: bool = (r & 0x80) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value: u8 = (r << 1) | @as(u8, @boolToInt(carry));
        core.memory.write8(core.cpu.HL.HL, value);
        if (bit7)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rrc_r(core: *Core, r: *u8) void {
        const carry: bool = (r.* & 0x01) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value = (r.* >> 1) | @as(u8, @boolToInt(carry)) << 7;
        r.* = value;
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rrc_hl(core: *Core) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.cpu.AF.AF &= 0xFF00;
        const carry: bool = (r & 0x01) != 0;
        core.tCycles += 8;
        const value = (r >> 1) | @as(u8, @boolToInt(carry)) << 7;
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn rr_r(core: *Core, r: *u8) void {
        const carry: bool = core.cpu.AF.S.F.c != 0;
        const value = (r.* >> 1) | (@as(u8, @boolToInt(carry)) << 7);
        // const bit1: bool = (value & 0x1) != 0;
        const bit0:u1 = @intCast(u1, (r.* >> 0) & 1);

        core.cpu.AF.AF &= 0xFF00;
        r.* = value;
        core.cpu.AF.S.F.c = bit0;
        // if (bit1)
        //     core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;

        // const carry:u1 = core.cpu.AF.S.F.c;
        // const bit0:u1 = @intCast(u1, (r.* >> 0) & 1);
        // core.cpu.AF.AF &= 0xFF00;
        // core.cpu.AF.S.F.c = bit0;
        // const value:u8 = r.* >> carry;
        // r.* = value;

        // if(value == 0)
        //     core.cpu.AF.S.F.z = 1;
    }

    pub fn rr_hl(core: *Core) void {
        const carry: bool = core.cpu.AF.S.F.c != 0;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        const value = (r >> 1) | (@as(u8, @boolToInt(carry)) << 7);
        core.tCycles += 8;
        core.memory.write8(core.cpu.HL.HL, value);
        const bit1: bool = (value & 0x1) != 0;
        if (bit1)
            core.cpu.AF.S.F.c = 1;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn sla_r(core: *Core, r: *u8) void {
        const carry: bool = (r.* & 0x80) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value: u8 = (r.* << 1);
        r.* = value;
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if ((value & 0x7F) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn sla_hl(core: *Core) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        const carry: bool = (r & 0x80) != 0;
        core.cpu.AF.AF &= 0xFF00;
        const value: u8 = (r << 1);
        core.memory.write8(core.cpu.HL.HL, r);
        if (carry)
            core.cpu.AF.S.F.c = 1;
        if ((value & 0x7F) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn sra_r(core: *Core, r: *u8) void {
        const bit7: u1 = @intCast(u1, r.* & 0x80);
        core.cpu.AF.AF &= 0xFF00;
        if ((r.* & 1) != 0)
            core.cpu.AF.S.F.c = 1;
        const value: u8 = (r.* >> 1) | bit7;
        r.* = value;
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn sra_hl(core: *Core) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        const bit7: u1 = @intCast(u1, r & 0x80);
        core.cpu.AF.AF &= 0xFF00;
        if ((r & 1) != 0)
            core.cpu.AF.S.F.c = 1;
        const value: u8 = (r >> 1) | bit7;
        core.memory.write8(core.cpu.HL.HL, value);
        if (value == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn swap_r(core: *Core, r: *u8) void {
        core.cpu.AF.AF &= 0xFF00;
        r.* = (r.* >> 4) | (r.* << 4);
        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn swap_hl(core: *Core) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        core.cpu.AF.AF &= 0xFF00;
        core.memory.write8(core.cpu.HL.HL, (r >> 4) | (r << 4));
        if (r == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn srl_r(core: *Core, r: *u8) void {
        const bit0:u1 = @intCast(u1, (r.* >> 0) & 1);
        // std.log.info("bit0: {b:0>1}", .{bit0});
        core.cpu.AF.AF &= 0xFF00;
        core.cpu.AF.S.F.c = bit0;
        r.* = (r.* >> 1);
        if (r.* == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn srl_hl(core: *Core) void {
        core.cpu.AF.AF &= 0xFF00;
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        core.memory.write8(core.cpu.HL.HL, (r >> 1));
        if ((r & 1) != 0)
            core.cpu.AF.S.F.c = 1;
        if ((r >> 1) == 0)
            core.cpu.AF.S.F.z = 1;
    }

    pub fn bit_r(core: *Core, which_bit: u3, r: *u8) void {
        core.cpu.AF.S.F.h = 1;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.z = 0;

        core.cpu.AF.S.F.z = @intCast(u1, ((r.* >> which_bit) & 1) ^ 1);
    }

    pub fn bit_hl(core: *Core, which_bit: u3) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        core.cpu.AF.S.F.h = 1;
        core.cpu.AF.S.F.n = 0;
        core.cpu.AF.S.F.z = 0;

        core.cpu.AF.S.F.z = @intCast(u1, ((r >> which_bit) & 1) ^ 1);
    }

    pub fn res_r(_: *Core, bit: u3, r: *u8) void {
        // newNum = num & (~(1 << n));
        r.* = r.* & (~(@as(u8, 1) << bit));
    }

    pub fn res_hl(core: *Core, bit: u3) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        core.memory.write8(core.cpu.HL.HL,  r & (~(@as(u8, 1) << bit)));
    }

    pub fn set_r(_: *Core, bit: u3, r: *u8) void {
        //     newNum = (1 << n) | num;
        r.* = (@as(u8, 1) << bit) | r.*;
    }

    pub fn set_hl(core: *Core, bit: u3) void {
        const r: u8 = core.memory.read8(core.cpu.HL.HL);
        core.tCycles += 8;
        core.memory.write8(core.cpu.HL.HL,  (@as(u8, 1) << bit) | r);
    }

    pub fn daa(core: *Core) void {
        core.cpu.PC+=1;
        core.cpu.AF.S.F.z = 0;
        // core.cpu.AF.S.F.n = 0;
        if (core.cpu.AF.S.F.n == 0) 
        { 
            if (core.cpu.AF.S.F.c == 1 or (core.cpu.AF.S.A > 0x99)) { 
                core.cpu.AF.S.A +%= 0x60; 
                core.cpu.AF.S.F.c = 1; 
            }
            if (core.cpu.AF.S.F.h == 1 or (core.cpu.AF.S.A & 0x0f) > 0x09) { 
                core.cpu.AF.S.A +%= 0x6; 
            }
        } else { 
            if (core.cpu.AF.S.F.c == 1) { 
                core.cpu.AF.S.A -%= 0x60; 
            }
            if (core.cpu.AF.S.F.h == 1) { 
                core.cpu.AF.S.A -%= 0x6; 
            }
        }

        if(core.cpu.AF.S.A == 0)
            core.cpu.AF.S.F.z = 1;

        core.cpu.AF.S.F.h = 0;
        // core.cpu.AF.S.F.h = 1;
        

        // var result:u8 = core.cpu.AF.S.A;
        // core.cpu.AF.S.F.h = 0;
        // core.cpu.AF.S.F.z = 0;
        // core.cpu.AF.S.F.c = 0;
        // if(core.cpu.AF.S.F.n == 1) {
        //     if(core.cpu.AF.S.F.h == 1)
        //         result = (result - 0x06) & 0xFF;
        //     if(core.cpu.AF.S.F.c == 1)
        //         result -= 0x60;
        // } else {
        //     if(core.cpu.AF.S.F.h == 1 or (result & 0x0F) > 0x09)
        //         result+=0x06;
        //     if(core.cpu.AF.S.F.c == 1 or (result > 0x9F))
        //         result+=0x60;
        // }

        // if(result == 0)
        //     core.cpu.AF.S.F.z = 1;
        // if(((@intCast(u16, result) & 0x100) & 0x100) != 0)
        //     core.cpu.AF.S.F.c = 1;
        // core.cpu.AF.S.F.h = 0;
        // core.cpu.AF.S.A |= result;
    }

    pub fn step(gb: *Core) !void {
        const opcode: u8 = gb.memory.read8(gb.cpu.PC);
        // if (gb.cpu.PC > 0x00FE)
        //     return RuntimeError.YouSuck;
        const writer = std.io.getStdOut().writer();
        if (gb.cpu.PC >= 0x0100) {
            writer.print("A: {X:0>2} F: {X:0>2} B: {X:0>2} C: {X:0>2} D: {X:0>2} E: {X:0>2} H: {X:0>2} L: {X:0>2} SP: {X:0>4} PC: 00:{X:0>4} ({X:0>2} {X:0>2} {X:0>2} {X:0>2})\n", .{
                gb.cpu.AF.S.A,              @bitCast(u8, (gb.cpu.AF.S.F)),  gb.cpu.BC.S.B,                  gb.cpu.BC.S.C,                  gb.cpu.DE.S.D, gb.cpu.DE.S.E, gb.cpu.HL.S.H, gb.cpu.HL.S.L, gb.cpu.SP, gb.cpu.PC,
                gb.memory.read8(gb.cpu.PC), gb.memory.read8(gb.cpu.PC + 1), gb.memory.read8(gb.cpu.PC + 2), gb.memory.read8(gb.cpu.PC + 3),
            }) catch return;
        }
        // A: 01 F: B0 B: 00 C: 13 D: 00 E: D8 H: 01 L: 4D SP: FFFE PC: 00:0100 (00 C3 13 02)

        // std.log.info("PC=${x:0>4} OP=${x:0>2} {s}", .{ gb.cpu.PC, opcode, disassembler.disassemble(opcode) });
        // if(opcode == 0xCB)
        //     std.log.info("\tCB= ${x:0>2}", .{gb.memory.read8(gb.cpu.PC)+1});

        // if(gb.cpu.PC == 0x0C06C)
        //     return RuntimeError.YouSuck;


        switch (opcode) {
            // NOP
            0 => nop(gb),
            // LD BC,d16
            0x01 => ld_rr_d16(gb, &gb.cpu.BC.BC),
            // LD (BC),A
            0x02 => ld_rr_r(gb, gb.cpu.BC.BC, gb.cpu.AF.S.A),
            // INC BC
            0x03 => inc_rr(gb, &gb.cpu.BC.BC),
            // INC B
            0x04 => inc_r(gb, &gb.cpu.BC.S.B),
            // DEC B
            0x05 => dec_r(gb, &gb.cpu.BC.S.B),
            // LD B,d8
            0x06 => ld_r_d8(gb, &gb.cpu.BC.S.B),
            // RLCA
            0x07 => rlca(gb),
            // LD (a16),SP
            0x08 => ld_da16_sp(gb),
            // ADD HL,BC
            0x09 => add_hl_rr(gb, gb.cpu.BC.BC),
            // LD A,(BC)
            0x0A => ld_r_rr(gb, &gb.cpu.AF.S.A, gb.cpu.BC.BC),
            // DEC BC
            0x0B => dec_rr(gb, &gb.cpu.BC.BC),
            // INC C
            0x0C => inc_r(gb, &gb.cpu.BC.S.C),
            // DEC C
            0x0D => dec_r(gb, &gb.cpu.BC.S.C),
            // LD C,d8
            0x0E => ld_r_d8(gb, &gb.cpu.BC.S.C),
            // RRCA
            0x0F => rrca(gb),
            // STOP 0
            // 0x10 => stop(gb),
            // LD DE,d16
            0x11 => ld_rr_d16(gb, &gb.cpu.DE.DE),
            // LD (DE),A
            0x12 => ld_rr_r(gb, gb.cpu.DE.DE, gb.cpu.AF.S.A),
            // INC DE
            0x13 => inc_rr(gb, &gb.cpu.DE.DE),
            // INC D
            0x14 => inc_r(gb, &gb.cpu.DE.S.D),
            // DEC D
            0x15 => dec_r(gb, &gb.cpu.DE.S.D),
            // LD D,d8
            0x16 => ld_r_d8(gb, &gb.cpu.DE.S.D),
            // RLA
            0x17 => rla(gb),
            // JR r8
            0x18 => jr_r8(gb),
            // ADD HL,DE
            0x19 => add_hl_rr(gb, gb.cpu.DE.DE),
            // LD A,(DE)
            0x1A => ld_r_rr(gb, &gb.cpu.AF.S.A, gb.cpu.DE.DE),
            // DEC DE
            0x1B => dec_rr(gb, &gb.cpu.DE.DE),
            // INC E
            0x1C => inc_r(gb, &gb.cpu.DE.S.E),
            // DEC E
            0x1D => dec_r(gb, &gb.cpu.DE.S.E),
            // LD E,d8
            0x1E => ld_r_d8(gb, &gb.cpu.DE.S.E),
            // RRA
            0x1F => rra(gb),
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
            // DEC H
            0x25 => dec_r(gb, &gb.cpu.HL.S.H),
            // LD H,d8
            0x26 => ld_r_d8(gb, &gb.cpu.HL.S.H),
            // DAA
            0x27 => daa(gb),
            // JR Z,r8
            0x28 => jr_z_r8(gb),
            // ADD HL,HL
            0x29 => add_hl_rr(gb, gb.cpu.HL.HL),
            // LD A,(HL+)
            0x2A => ld_a_hli(gb),
            // DEC HL
            0x2B => dec_rr(gb, &gb.cpu.HL.HL),
            // INC L
            0x2C => inc_r(gb, &gb.cpu.HL.S.L),
            // DEC L
            0x2D => dec_r(gb, &gb.cpu.HL.S.L),
            // LD L,d8
            0x2E => ld_r_d8(gb, &gb.cpu.HL.S.L),
            // CPL
            0x2F => cpl(gb),
            // JR NC,r8
            0x30 => jr_nc_r8(gb),
            // LD SP,u16
            0x31 => ld_rr_d16(gb, &gb.cpu.SP),
            // LD (HL-),A
            0x32 => ld_hld_r(gb, gb.cpu.AF.S.A),
            // INC SP
            0x33 => inc_rr(gb, &gb.cpu.SP),
            // INC (HL)
            0x34 => inc_dhl(gb),
            // DEC (HL)
            0x35 => dec_dhl(gb),
            // LD (HL),d8
            0x36 => ld_dhl_d8(gb),
            // SCF
            0x37 => scf(gb),
            // JR C,r8
            0x38 => jr_c_r8(gb),
            // ADD HL,SP
            0x39 => add_hl_rr(gb, gb.cpu.SP),
            // LD A,(HL-)
            0x3A => ld_r_hld(gb, &gb.cpu.AF.S.A),
            // DEC SP
            0x3B => dec_rr(gb, &gb.cpu.SP),
            // INC A
            0x3C => inc_r(gb, &gb.cpu.AF.S.A),
            // DEC A
            0x3D => dec_r(gb, &gb.cpu.AF.S.A),
            // LD A,d8
            0x3E => ld_r_d8(gb, &gb.cpu.AF.S.A),
            // CCF
            0x3F => ccf(gb),
            // LD B,B
            0x40 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.BC.S.B),
            // LD B,C
            0x41 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.BC.S.C),
            // LD B,D
            0x42 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.DE.S.D),
            // LD B,E
            0x43 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.DE.S.E),
            // LD B,H
            0x44 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.HL.S.H),
            // LD B,L
            0x45 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.HL.S.L),
            // LD B,(HL)
            0x46 => ld_r_rr(gb, &gb.cpu.BC.S.B, gb.cpu.HL.HL),
            // LD B,A
            0x47 => ld_r_r(gb, &gb.cpu.BC.S.B, gb.cpu.AF.S.A),
            // LD C,B
            0x48 => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.BC.S.B),
            // LD C,C
            0x49 => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.BC.S.C),
            // LD C,D
            0x4A => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.DE.S.D),
            // LD C,E
            0x4B => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.DE.S.E),
            // LD C,H
            0x4C => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.HL.S.H),
            // LD C,L
            0x4D => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.HL.S.L),
            // LD C,(HL)
            0x4E => ld_r_rr(gb, &gb.cpu.BC.S.C, gb.cpu.HL.HL),
            // LD C,A
            0x4F => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.AF.S.A),
            // LD D,B
            0x50 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.BC.S.B),
            // LD D,C
            0x51 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.BC.S.C),
            // LD D,D
            0x52 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.DE.S.D),
            // LD D,E
            0x53 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.DE.S.E),
            // LD D,H
            0x54 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.HL.S.H),
            // LD D,L
            0x55 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.HL.S.L),
            // LD D,(HL)
            0x56 => ld_r_rr(gb, &gb.cpu.DE.S.D, gb.cpu.HL.HL),
            // LD D,A
            0x57 => ld_r_r(gb, &gb.cpu.DE.S.D, gb.cpu.AF.S.A),
            // LD E,B
            0x58 => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.BC.S.B),
            // LD E,C
            0x59 => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.BC.S.C),
            // LD E,D
            0x5A => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.DE.S.D),
            // LD E,E
            0x5B => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.DE.S.E),
            // LD E,H
            0x5C => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.HL.S.H),
            // LD E,L
            0x5D => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.HL.S.L),
            // LD E,(HL)
            0x5E => ld_r_rr(gb, &gb.cpu.DE.S.E, gb.cpu.HL.HL),
            // LD E,A
            0x5F => ld_r_r(gb, &gb.cpu.DE.S.E, gb.cpu.AF.S.A),
            // LD H,B
            0x60 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.BC.S.B),
            // LD H,C
            0x61 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.BC.S.C),
            // LD H,D
            0x62 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.DE.S.D),
            // LD H,E
            0x63 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.DE.S.E),
            // LD H,H
            0x64 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.HL.S.H),
            // LD H,L
            0x65 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.HL.S.L),
            // LD H,(HL)
            0x66 => ld_r_rr(gb, &gb.cpu.HL.S.H, gb.cpu.HL.HL),
            // LD H,A
            0x67 => ld_r_r(gb, &gb.cpu.HL.S.H, gb.cpu.AF.S.A),
            // LD L,B
            0x68 => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.BC.S.B),
            // LD L,C
            0x69 => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.BC.S.C),
            // LD L,D
            0x6A => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.DE.S.D),
            // LD L,E
            0x6B => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.DE.S.E),
            // LD L,H
            0x6C => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.HL.S.H),
            // LD L,L
            0x6D => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.HL.S.L),
            // LD L,(HL)
            0x6E => ld_r_rr(gb, &gb.cpu.HL.S.L, gb.cpu.HL.HL),
            // LD L,A
            0x6F => ld_r_r(gb, &gb.cpu.HL.S.L, gb.cpu.AF.S.A),
            // LD (HL),B
            0x70 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.BC.S.B),
            // LD (HL),C
            0x71 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.BC.S.C),
            // LD (HL),D
            0x72 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.DE.S.D),
            // LD (HL),E
            0x73 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.DE.S.E),
            // LD (HL),H
            0x74 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.HL.S.H),
            // LD (HL),L
            0x75 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.HL.S.L),
            // HALT
            // 0x76 => halt(gb),
            // LD (HL),A
            0x77 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.AF.S.A),
            // LD A,B
            0x78 => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.BC.S.B),
            // LD A,C
            0x79 => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.BC.S.C),
            // LD A,D
            0x7A => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.DE.S.D),
            // LD A,E
            0x7B => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.DE.S.E),
            // LD A,H
            0x7C => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.HL.S.H),
            // LD A,L
            0x7D => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.HL.S.L),
            // LD A,(HL)
            0x7E => ld_r_rr(gb, &gb.cpu.AF.S.A, gb.cpu.HL.HL),
            // LD A,A
            0x7F => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.AF.S.A),
            // ADD A,B
            0x80 => add_r(gb, gb.cpu.BC.S.B),
            // ADD A,C
            0x81 => add_r(gb, gb.cpu.BC.S.C),
            // ADD A,D
            0x82 => add_r(gb, gb.cpu.DE.S.D),
            // ADD A,E
            0x83 => add_r(gb, gb.cpu.DE.S.E),
            // ADD A,H
            0x84 => add_r(gb, gb.cpu.HL.S.H),
            // ADD A,L
            0x85 => add_r(gb, gb.cpu.HL.S.L),
            // ADD A,(HL)
            0x86 => add_hl(gb),
            // ADD A,A
            0x87 => add_r(gb, gb.cpu.AF.S.A),
            // ADC A,B
            0x88 => adc_r(gb, gb.cpu.BC.S.B),
            // ADC A,C
            0x89 => adc_r(gb, gb.cpu.BC.S.C),
            // ADC A,D
            0x8A => adc_r(gb, gb.cpu.DE.S.D),
            // ADC A,E
            0x8B => adc_r(gb, gb.cpu.DE.S.E),
            // ADC A,H
            0x8C => adc_r(gb, gb.cpu.HL.S.H),
            // ADC A,L
            0x8D => adc_r(gb, gb.cpu.HL.S.L),
            // ADC A,(HL)
            0x8E => adc_hl(gb),
            // ADC A,A
            0x8F => adc_r(gb, gb.cpu.AF.S.A),
            // SUB B
            0x90 => sub_r(gb, &gb.cpu.BC.S.B),
            // SUB C
            0x91 => sub_r(gb, &gb.cpu.BC.S.C),
            // SUB D
            0x92 => sub_r(gb, &gb.cpu.DE.S.D),
            // SUB E
            0x93 => sub_r(gb, &gb.cpu.DE.S.E),
            // SUB H
            0x94 => sub_r(gb, &gb.cpu.HL.S.H),
            // SUB L
            0x95 => sub_r(gb, &gb.cpu.HL.S.L),
            // SUB (HL)
            0x96 => sub_hl(gb),
            // SUB A
            0x97 => sub_r(gb, &gb.cpu.AF.S.A),
            // SBC A,B
            0x98 => sbc_r(gb, gb.cpu.BC.S.B),
            // SBC A,C
            0x99 => sbc_r(gb, gb.cpu.BC.S.C),
            // SBC A,D
            0x9A => sbc_r(gb, gb.cpu.DE.S.D),
            // SBC A,E
            0x9B => sbc_r(gb, gb.cpu.DE.S.E),
            // SBC A,H
            0x9C => sbc_r(gb, gb.cpu.HL.S.H),
            // SBC A,L
            0x9D => sbc_r(gb, gb.cpu.HL.S.L),
            // SBC (HL)
            0x9E => sbc_hl(gb),
            // SBC A,A
            0x9F => sbc_r(gb, gb.cpu.AF.S.A),
            // AND B
            0xA0 => and_r(gb, gb.cpu.BC.S.B),
            // AND C
            0xA1 => and_r(gb, gb.cpu.BC.S.C),
            // AND D
            0xA2 => and_r(gb, gb.cpu.DE.S.D),
            // AND E
            0xA3 => and_r(gb, gb.cpu.DE.S.E),
            // AND H
            0xA4 => and_r(gb, gb.cpu.HL.S.H),
            // AND L
            0xA5 => and_r(gb, gb.cpu.HL.S.L),
            // AND (HL)
            0xA6 => and_hl(gb),
            // AND A
            0xA7 => and_r(gb, gb.cpu.AF.S.A),
            // XOR A,B
            0xA8 => xor_r(gb, gb.cpu.BC.S.B),
            // XOR A,C
            0xA9 => xor_r(gb, gb.cpu.BC.S.C),
            // XOR A,D
            0xAA => xor_r(gb, gb.cpu.DE.S.D),
            // XOR A,E
            0xAB => xor_r(gb, gb.cpu.DE.S.E),
            // XOR A,H
            0xAC => xor_r(gb, gb.cpu.HL.S.H),
            // XOR A,L
            0xAD => xor_r(gb, gb.cpu.HL.S.L),
            // XOR (HL)
            0xAE => xor_hl(gb),
            // XOR A,A
            0xAF => xor_r(gb, gb.cpu.AF.S.A),
            // OR B
            0xB0 => or_r(gb, gb.cpu.BC.S.B),
            // OR C
            0xB1 => or_r(gb, gb.cpu.BC.S.C),
            // OR D
            0xB2 => or_r(gb, gb.cpu.DE.S.D),
            // OR E
            0xB3 => or_r(gb, gb.cpu.DE.S.E),
            // OR H
            0xB4 => or_r(gb, gb.cpu.HL.S.H),
            // OR L
            0xB5 => or_r(gb, gb.cpu.HL.S.L),
            // OR (HL)
            0xB6 => or_hl(gb),
            // OR A
            0xB7 => or_r(gb, gb.cpu.AF.S.A),
            // CP A,B
            0xB8 => cp_r(gb, gb.cpu.BC.S.B),
            // CP A,C
            0xB9 => cp_r(gb, gb.cpu.BC.S.C),
            // CP A,D
            0xBA => cp_r(gb, gb.cpu.DE.S.D),
            // CP A,E
            0xBB => cp_r(gb, gb.cpu.DE.S.E),
            // CP A,H
            0xBC => cp_r(gb, gb.cpu.HL.S.H),
            // CP A,L
            0xBD => cp_r(gb, gb.cpu.HL.S.L),
            // CP (HL)
            0xBE => cp_hl(gb),
            // CP A,A
            0xBF => cp_r(gb, gb.cpu.AF.S.A),
            // RET NZ
            0xC0 => ret_nz(gb),
            // POP BC
            0xC1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),
            // JP NZ,a16
            0xC2 => jp_nz_a16(gb),
            // JP a16
            0xC3 => jp_a16(gb),
            // CALL NZ,a16
            0xC4 => call_nz_a16(gb),
            // PUSH BC
            0xC5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),
            // ADD A,d8
            0xC6 => add_d8(gb),
            // RST 00H
            0xC7 => rst(gb),
            // RET Z
            0xC8 => ret_z(gb),
            // RET
            0xC9 => ret(gb),
            // JP Z,a16
            0xCA => jp_z_a16(gb),
            // Pefix CB
            0xCB => {
                gb.cpu.PC += 1;
                gb.tCycles += 8;
                const prefix:u8 = gb.memory.read8(gb.cpu.PC);
                gb.cpu.PC+=1;
                switch (prefix) {
                    0x00 => rlc_r(gb, &gb.cpu.BC.S.B),
                    0x01 => rlc_r(gb, &gb.cpu.BC.S.C),
                    0x02 => rlc_r(gb, &gb.cpu.DE.S.D),
                    0x03 => rlc_r(gb, &gb.cpu.DE.S.E),
                    0x04 => rlc_r(gb, &gb.cpu.HL.S.H),
                    0x05 => rlc_r(gb, &gb.cpu.HL.S.L),
                    0x06 => rlc_hl(gb),
                    0x07 => rlc_r(gb, &gb.cpu.AF.S.A),

                    0x08 => rrc_r(gb, &gb.cpu.BC.S.B),
                    0x09 => rrc_r(gb, &gb.cpu.BC.S.C),
                    0x0A => rrc_r(gb, &gb.cpu.DE.S.D),
                    0x0B => rrc_r(gb, &gb.cpu.DE.S.E),
                    0x0C => rrc_r(gb, &gb.cpu.HL.S.H),
                    0x0D => rrc_r(gb, &gb.cpu.HL.S.L),
                    0x0E => rrc_hl(gb),
                    0x0F => rrc_r(gb, &gb.cpu.AF.S.A),

                    0x10 => rl_r(gb, &gb.cpu.BC.S.B),
                    0x11 => rl_r(gb, &gb.cpu.BC.S.C),
                    0x12 => rl_r(gb, &gb.cpu.DE.S.D),
                    0x13 => rl_r(gb, &gb.cpu.DE.S.E),
                    0x14 => rl_r(gb, &gb.cpu.HL.S.H),
                    0x15 => rl_r(gb, &gb.cpu.HL.S.L),
                    0x16 => rl_hl(gb),
                    0x17 => rl_r(gb, &gb.cpu.AF.S.A),
                    0x18 => rr_r(gb, &gb.cpu.BC.S.B),
                    0x19 => rr_r(gb, &gb.cpu.BC.S.C),
                    0x1A => rr_r(gb, &gb.cpu.DE.S.D),
                    0x1B => rr_r(gb, &gb.cpu.DE.S.E),
                    0x1C => rr_r(gb, &gb.cpu.HL.S.H),
                    0x1D => rr_r(gb, &gb.cpu.HL.S.L),
                    0x1E => rr_hl(gb),
                    0x1F => rr_r(gb, &gb.cpu.AF.S.A),

                    0x20 => sla_r(gb, &gb.cpu.BC.S.B),
                    0x21 => sla_r(gb, &gb.cpu.BC.S.C),
                    0x22 => sla_r(gb, &gb.cpu.DE.S.D),
                    0x23 => sla_r(gb, &gb.cpu.DE.S.E),
                    0x24 => sla_r(gb, &gb.cpu.HL.S.H),
                    0x25 => sla_r(gb, &gb.cpu.HL.S.L),
                    0x26 => sla_hl(gb),
                    0x27 => sla_r(gb, &gb.cpu.AF.S.A),
                    0x28 => sra_r(gb, &gb.cpu.BC.S.B),
                    0x29 => sra_r(gb, &gb.cpu.BC.S.C),
                    0x2A => sra_r(gb, &gb.cpu.DE.S.D),
                    0x2B => sra_r(gb, &gb.cpu.DE.S.E),
                    0x2C => sra_r(gb, &gb.cpu.HL.S.H),
                    0x2D => sra_r(gb, &gb.cpu.HL.S.L),
                    0x2E => sra_hl(gb),
                    0x2F => sra_r(gb, &gb.cpu.AF.S.A),

                    0x30 => swap_r(gb, &gb.cpu.BC.S.B),
                    0x31 => swap_r(gb, &gb.cpu.BC.S.C),
                    0x32 => swap_r(gb, &gb.cpu.DE.S.D),
                    0x33 => swap_r(gb, &gb.cpu.DE.S.E),
                    0x34 => swap_r(gb, &gb.cpu.HL.S.H),
                    0x35 => swap_r(gb, &gb.cpu.HL.S.L),
                    0x36 => swap_hl(gb),
                    0x37 => swap_r(gb, &gb.cpu.AF.S.A),
                    0x38 => srl_r(gb, &gb.cpu.BC.S.B),
                    0x39 => srl_r(gb, &gb.cpu.BC.S.C),
                    0x3A => srl_r(gb, &gb.cpu.DE.S.D),
                    0x3B => srl_r(gb, &gb.cpu.DE.S.E),
                    0x3C => srl_r(gb, &gb.cpu.HL.S.H),
                    0x3D => srl_r(gb, &gb.cpu.HL.S.L),
                    0x3E => srl_hl(gb),
                    0x3F => srl_r(gb, &gb.cpu.AF.S.A),

                    0x40 => bit_r(gb, 0, &gb.cpu.BC.S.B),
                    0x41 => bit_r(gb, 0, &gb.cpu.BC.S.C),
                    0x42 => bit_r(gb, 0, &gb.cpu.DE.S.D),
                    0x43 => bit_r(gb, 0, &gb.cpu.DE.S.E),
                    0x44 => bit_r(gb, 0, &gb.cpu.HL.S.H),
                    0x45 => bit_r(gb, 0, &gb.cpu.HL.S.L),
                    0x46 => bit_hl(gb, 0),
                    0x47 => bit_r(gb, 0, &gb.cpu.AF.S.A),
                    0x48 => bit_r(gb, 1, &gb.cpu.BC.S.B),
                    0x49 => bit_r(gb, 1, &gb.cpu.BC.S.C),
                    0x4A => bit_r(gb, 1, &gb.cpu.DE.S.D),
                    0x4B => bit_r(gb, 1, &gb.cpu.DE.S.E),
                    0x4C => bit_r(gb, 1, &gb.cpu.HL.S.H),
                    0x4D => bit_r(gb, 1, &gb.cpu.HL.S.L),
                    0x4E => bit_hl(gb, 1),
                    0x4F => bit_r(gb, 1, &gb.cpu.AF.S.A),

                    0x50 => bit_r(gb, 2, &gb.cpu.BC.S.B),
                    0x51 => bit_r(gb, 2, &gb.cpu.BC.S.C),
                    0x52 => bit_r(gb, 2, &gb.cpu.DE.S.D),
                    0x53 => bit_r(gb, 2, &gb.cpu.DE.S.E),
                    0x54 => bit_r(gb, 2, &gb.cpu.HL.S.H),
                    0x55 => bit_r(gb, 2, &gb.cpu.HL.S.L),
                    0x56 => bit_hl(gb, 2),
                    0x57 => bit_r(gb, 2, &gb.cpu.AF.S.A),
                    0x58 => bit_r(gb, 3, &gb.cpu.BC.S.B),
                    0x59 => bit_r(gb, 3, &gb.cpu.BC.S.C),
                    0x5A => bit_r(gb, 3, &gb.cpu.DE.S.D),
                    0x5B => bit_r(gb, 3, &gb.cpu.DE.S.E),
                    0x5C => bit_r(gb, 3, &gb.cpu.HL.S.H),
                    0x5D => bit_r(gb, 3, &gb.cpu.HL.S.L),
                    0x5E => bit_hl(gb, 3),
                    0x5F => bit_r(gb, 3, &gb.cpu.AF.S.A),

                    0x60 => bit_r(gb, 4, &gb.cpu.BC.S.B),
                    0x61 => bit_r(gb, 4, &gb.cpu.BC.S.C),
                    0x62 => bit_r(gb, 4, &gb.cpu.DE.S.D),
                    0x63 => bit_r(gb, 4, &gb.cpu.DE.S.E),
                    0x64 => bit_r(gb, 4, &gb.cpu.HL.S.H),
                    0x65 => bit_r(gb, 4, &gb.cpu.HL.S.L),
                    0x66 => bit_hl(gb, 4),
                    0x67 => bit_r(gb, 4, &gb.cpu.AF.S.A),
                    0x68 => bit_r(gb, 5, &gb.cpu.BC.S.B),
                    0x69 => bit_r(gb, 5, &gb.cpu.BC.S.C),
                    0x6A => bit_r(gb, 5, &gb.cpu.DE.S.D),
                    0x6B => bit_r(gb, 5, &gb.cpu.DE.S.E),
                    0x6C => bit_r(gb, 5, &gb.cpu.HL.S.H),
                    0x6D => bit_r(gb, 5, &gb.cpu.HL.S.L),
                    0x6E => bit_hl(gb, 5),
                    0x6F => bit_r(gb, 5, &gb.cpu.AF.S.A),

                    0x70 => bit_r(gb, 6, &gb.cpu.BC.S.B),
                    0x71 => bit_r(gb, 6, &gb.cpu.BC.S.C),
                    0x72 => bit_r(gb, 6, &gb.cpu.DE.S.D),
                    0x73 => bit_r(gb, 6, &gb.cpu.DE.S.E),
                    0x74 => bit_r(gb, 6, &gb.cpu.HL.S.H),
                    0x75 => bit_r(gb, 6, &gb.cpu.HL.S.L),
                    0x76 => bit_hl(gb, 6),
                    0x77 => bit_r(gb, 6, &gb.cpu.AF.S.A),
                    0x78 => bit_r(gb, 7, &gb.cpu.BC.S.B),
                    0x79 => bit_r(gb, 7, &gb.cpu.BC.S.C),
                    0x7A => bit_r(gb, 7, &gb.cpu.DE.S.D),
                    0x7B => bit_r(gb, 7, &gb.cpu.DE.S.E),
                    0x7C => bit_r(gb, 7, &gb.cpu.HL.S.H),
                    0x7D => bit_r(gb, 7, &gb.cpu.HL.S.L),
                    0x7E => bit_hl(gb, 7),
                    0x7F => bit_r(gb, 7, &gb.cpu.AF.S.A),

                    0x80 => res_r(gb, 0, &gb.cpu.BC.S.B),
                    0x81 => res_r(gb, 0, &gb.cpu.BC.S.C),
                    0x82 => res_r(gb, 0, &gb.cpu.DE.S.D),
                    0x83 => res_r(gb, 0, &gb.cpu.DE.S.E),
                    0x84 => res_r(gb, 0, &gb.cpu.HL.S.H),
                    0x85 => res_r(gb, 0, &gb.cpu.HL.S.L),
                    0x86 => res_hl(gb,0),
                    0x87 => res_r(gb, 0, &gb.cpu.AF.S.A),
                    0x88 => res_r(gb, 1, &gb.cpu.BC.S.B),
                    0x89 => res_r(gb, 1, &gb.cpu.BC.S.C),
                    0x8A => res_r(gb, 1, &gb.cpu.DE.S.D),
                    0x8B => res_r(gb, 1, &gb.cpu.DE.S.E),
                    0x8C => res_r(gb, 1, &gb.cpu.HL.S.H),
                    0x8D => res_r(gb, 1, &gb.cpu.HL.S.L),
                    0x8E => res_hl(gb,1),
                    0x8F => res_r(gb, 1, &gb.cpu.AF.S.A),

                    0x90 => res_r(gb, 2, &gb.cpu.BC.S.B),
                    0x91 => res_r(gb, 2, &gb.cpu.BC.S.C),
                    0x92 => res_r(gb, 2, &gb.cpu.DE.S.D),
                    0x93 => res_r(gb, 2, &gb.cpu.DE.S.E),
                    0x94 => res_r(gb, 2, &gb.cpu.HL.S.H),
                    0x95 => res_r(gb, 2, &gb.cpu.HL.S.L),
                    0x96 => res_hl(gb, 2),
                    0x97 => res_r(gb, 2, &gb.cpu.AF.S.A),
                    0x98 => res_r(gb, 3, &gb.cpu.BC.S.B),
                    0x99 => res_r(gb, 3, &gb.cpu.BC.S.C),
                    0x9A => res_r(gb, 3, &gb.cpu.DE.S.D),
                    0x9B => res_r(gb, 3, &gb.cpu.DE.S.E),
                    0x9C => res_r(gb, 3, &gb.cpu.HL.S.H),
                    0x9D => res_r(gb, 3, &gb.cpu.HL.S.L),
                    0x9E => res_hl(gb, 3),
                    0x9F => res_r(gb, 3, &gb.cpu.AF.S.A),

                    0xA0 => res_r(gb, 4, &gb.cpu.BC.S.B),
                    0xA1 => res_r(gb, 4, &gb.cpu.BC.S.C),
                    0xA2 => res_r(gb, 4, &gb.cpu.DE.S.D),
                    0xA3 => res_r(gb, 4, &gb.cpu.DE.S.E),
                    0xA4 => res_r(gb, 4, &gb.cpu.HL.S.H),
                    0xA5 => res_r(gb, 4, &gb.cpu.HL.S.L),
                    0xA6 => res_hl(gb,4),
                    0xA7 => res_r(gb, 4, &gb.cpu.AF.S.A),
                    0xA8 => res_r(gb, 5, &gb.cpu.BC.S.B),
                    0xA9 => res_r(gb, 5, &gb.cpu.BC.S.C),
                    0xAA => res_r(gb, 5, &gb.cpu.DE.S.D),
                    0xAB => res_r(gb, 5, &gb.cpu.DE.S.E),
                    0xAC => res_r(gb, 5, &gb.cpu.HL.S.H),
                    0xAD => res_r(gb, 5, &gb.cpu.HL.S.L),
                    0xAE => res_hl(gb,5),
                    0xAF => res_r(gb, 5, &gb.cpu.AF.S.A),

                    0xB0 => res_r(gb, 6, &gb.cpu.BC.S.B),
                    0xB1 => res_r(gb, 6, &gb.cpu.BC.S.C),
                    0xB2 => res_r(gb, 6, &gb.cpu.DE.S.D),
                    0xB3 => res_r(gb, 6, &gb.cpu.DE.S.E),
                    0xB4 => res_r(gb, 6, &gb.cpu.HL.S.H),
                    0xB5 => res_r(gb, 6, &gb.cpu.HL.S.L),
                    0xB6 => res_hl(gb,6),
                    0xB7 => res_r(gb, 6, &gb.cpu.AF.S.A),
                    0xB8 => res_r(gb, 7, &gb.cpu.BC.S.B),
                    0xB9 => res_r(gb, 7, &gb.cpu.BC.S.C),
                    0xBA => res_r(gb, 7, &gb.cpu.DE.S.D),
                    0xBB => res_r(gb, 7, &gb.cpu.DE.S.E),
                    0xBC => res_r(gb, 7, &gb.cpu.HL.S.H),
                    0xBD => res_r(gb, 7, &gb.cpu.HL.S.L),
                    0xBE => res_hl(gb,7),
                    0xBF => res_r(gb, 7, &gb.cpu.AF.S.A),

                    0xC0 => set_r(gb, 0, &gb.cpu.BC.S.B),
                    0xC1 => set_r(gb, 0, &gb.cpu.BC.S.C),
                    0xC2 => set_r(gb, 0, &gb.cpu.DE.S.D),
                    0xC3 => set_r(gb, 0, &gb.cpu.DE.S.E),
                    0xC4 => set_r(gb, 0, &gb.cpu.HL.S.H),
                    0xC5 => set_r(gb, 0, &gb.cpu.HL.S.L),
                    0xC6 => set_hl(gb,0),
                    0xC7 => set_r(gb, 0, &gb.cpu.AF.S.A),
                    0xC8 => set_r(gb, 1, &gb.cpu.BC.S.B),
                    0xC9 => set_r(gb, 1, &gb.cpu.BC.S.C),
                    0xCA => set_r(gb, 1, &gb.cpu.DE.S.D),
                    0xCB => set_r(gb, 1, &gb.cpu.DE.S.E),
                    0xCC => set_r(gb, 1, &gb.cpu.HL.S.H),
                    0xCD => set_r(gb, 1, &gb.cpu.HL.S.L),
                    0xCE => set_hl(gb,1),
                    0xCF => set_r(gb, 1, &gb.cpu.AF.S.A),

                    0xD0 => set_r(gb, 2, &gb.cpu.BC.S.B),
                    0xD1 => set_r(gb, 2, &gb.cpu.BC.S.C),
                    0xD2 => set_r(gb, 2, &gb.cpu.DE.S.D),
                    0xD3 => set_r(gb, 2, &gb.cpu.DE.S.E),
                    0xD4 => set_r(gb, 2, &gb.cpu.HL.S.H),
                    0xD5 => set_r(gb, 2, &gb.cpu.HL.S.L),
                    0xD6 => set_hl(gb,2),
                    0xD7 => set_r(gb, 2, &gb.cpu.AF.S.A),
                    0xD8 => set_r(gb, 3, &gb.cpu.BC.S.B),
                    0xD9 => set_r(gb, 3, &gb.cpu.BC.S.C),
                    0xDA => set_r(gb, 3, &gb.cpu.DE.S.D),
                    0xDB => set_r(gb, 3, &gb.cpu.DE.S.E),
                    0xDC => set_r(gb, 3, &gb.cpu.HL.S.H),
                    0xDD => set_r(gb, 3, &gb.cpu.HL.S.L),
                    0xDE => set_hl(gb,3),
                    0xDF => set_r(gb, 3, &gb.cpu.AF.S.A),

                    0xE0 => set_r(gb, 4, &gb.cpu.BC.S.B),
                    0xE1 => set_r(gb, 4, &gb.cpu.BC.S.C),
                    0xE2 => set_r(gb, 4, &gb.cpu.DE.S.D),
                    0xE3 => set_r(gb, 4, &gb.cpu.DE.S.E),
                    0xE4 => set_r(gb, 4, &gb.cpu.HL.S.H),
                    0xE5 => set_r(gb, 4, &gb.cpu.HL.S.L),
                    0xE6 => set_hl(gb,4),
                    0xE7 => set_r(gb, 4, &gb.cpu.AF.S.A),
                    0xE8 => set_r(gb, 5, &gb.cpu.BC.S.B),
                    0xE9 => set_r(gb, 5, &gb.cpu.BC.S.C),
                    0xEA => set_r(gb, 5, &gb.cpu.DE.S.D),
                    0xEB => set_r(gb, 5, &gb.cpu.DE.S.E),
                    0xEC => set_r(gb, 5, &gb.cpu.HL.S.H),
                    0xED => set_r(gb, 5, &gb.cpu.HL.S.L),
                    0xEE => set_hl(gb,5),
                    0xEF => set_r(gb, 5, &gb.cpu.AF.S.A),

                    0xF0 => set_r(gb, 6, &gb.cpu.BC.S.B),
                    0xF1 => set_r(gb, 6, &gb.cpu.BC.S.C),
                    0xF2 => set_r(gb, 6, &gb.cpu.DE.S.D),
                    0xF3 => set_r(gb, 6, &gb.cpu.DE.S.E),
                    0xF4 => set_r(gb, 6, &gb.cpu.HL.S.H),
                    0xF5 => set_r(gb, 6, &gb.cpu.HL.S.L),
                    0xF6 => set_hl(gb,6),
                    0xF7 => set_r(gb, 6, &gb.cpu.AF.S.A),
                    0xF8 => set_r(gb, 7, &gb.cpu.BC.S.B),
                    0xF9 => set_r(gb, 7, &gb.cpu.BC.S.C),
                    0xFA => set_r(gb, 7, &gb.cpu.DE.S.D),
                    0xFB => set_r(gb, 7, &gb.cpu.DE.S.E),
                    0xFC => set_r(gb, 7, &gb.cpu.HL.S.H),
                    0xFD => set_r(gb, 7, &gb.cpu.HL.S.L),
                    0xFE => set_hl(gb,7),
                    0xFF => set_r(gb, 7, &gb.cpu.AF.S.A),


                    // else => cblk: {
                    //     gb.halt = true;
                    //     std.log.info("Unimplemented CB Instruction 0x{X}", .{gb.memory.read8(gb.cpu.PC)});
                    //     // std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                    //     break :cblk return RuntimeError.InstructionNotImplemented;
                    // },
                }
            },
            // CALL Z,a16
            0xCC => call_z_a16(gb),
            // CALL nn
            0xCD => call_a16(gb),
            // ADC A,d8
            0xCE => adc_d8(gb),
            // RST 08H
            0xCF => rst(gb),
            // RET NC
            0xD0 => ret_nc(gb),
            // POP DE
            0xD1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.DE))),
            // JP NC,a16
            0xD2 => jp_nc_a16(gb),
            // CALL NC,a16
            0xD4 => call_nc_a16(gb),
            // PUSH DE
            0xD5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.DE))),
            // SUB d8
            0xD6 => sub_d8(gb),
            // RST 10H
            0xD7 => rst(gb),
            // RET C
            0xD8 => ret_c(gb),
            // RETI
            0xD9 => reti(gb),
            // JP C,a16
            0xDA => jp_c_a16(gb),
            // CALL C,a16
            0xDC => call_c_a16(gb),
            // SBC A,d8
            0xDE => sbc_d8(gb),
            // RST 18H
            0xDF => rst(gb),
            // LDH (a8), A | LD ($FF00+a8),A
            0xE0 => ldh_a8_a(gb),
            // POP HL
            0xE1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.HL))),
            // LD (A),(C) | LD ($FF00+C),A
            0xE2 => ldc_a(gb),
            // PUSH HL
            0xE5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.HL))),
            // AND d8
            0xE6 => and_d8(gb),
            // RST 20H
            0xE7 => rst(gb),
            // ADD SP,r8
            0xE8 => add_sp_r8(gb),
            // JP (HL)
            0xE9 => jp_hl(gb),
            // LD (a16),A
            0xEA => ld_a16_a(gb),
            // XOR d8
            0xEE => xor_d8(gb),
            // RST 28H
            0xEF => rst(gb),
            // LDH A,(a8)
            0xF0 => ldh_a_a8(gb),
            // POP AF
            0xF1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.AF))),
            // LD A,(C) | LD A,($FF00+C)
            0xF2 => lda_c(gb),
            // DI
            0xF3 => di(gb),
            // PUSH AF
            0xF5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.AF))),
            // OR d8
            0xF6 => or_d8(gb),
            // RST 30H
            0xF7 => rst(gb),
            // LD HL,SP+r8
            0xF8 => ld_hl_sp_r8(gb),
            // LD SP,HL
            0xF9 => ld_sp_hl(gb),
            // LD A,(a16)
            0xFA => ld_a_a16(gb),
            // EI
            0xFB => ei(gb),
            // CP d8
            0xFE => cp_d8(gb),
            // RST 38H
            0xFF => rst(gb),
            else => blk: {
                gb.halt = true;
                std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ gb.cpu.PC, gb.memory.read8(gb.cpu.PC) });
                // std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                break :blk return RuntimeError.InstructionNotImplemented;
            },
        }
    }
};
