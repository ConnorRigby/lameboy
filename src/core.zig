const std = @import("std");

const cpu = @import("cpu.zig");
const CPU = cpu.CPU;
const RegisterReference = cpu.RegisterReference;

const Memory = @import("memory.zig").Memory;

const debugger = @import("debugger.zig");
const Debugger = debugger.Debugger;

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
        core.cpu.AF.S.A +%= d8;
        if ((a +% d8) == 0)
            core.cpu.AF.S.F.z = 1;
        if ((a & 0xf) + (d8 & 0xf) > 0x0f)
            core.cpu.AF.S.F.h = 1;
        if ((a +% d8) > 0xff)
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

    pub fn ld_r_hli(core: *Core, r: *u8) void {
        core.cpu.PC += 1;
        core.tCycles += 8;
        r.* = core.memory.read8(core.cpu.HL.HL);
        core.cpu.HL.HL +%= 1;
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
            // std.log.info("JR Z,{d} (true) ${B:0>1}", .{r8, core.cpu.AF.S.F});
            core.cpu.PC +%= @bitCast(u16, @intCast(i16, r8));
        } else {
            core.tCycles += 8;
            // std.log.info("JR Z,{d} (false) ${B:0>1}", .{r8, core.cpu.AF.S.F});
        }
    }

    pub fn jp(core: *Core) void {
        core.cpu.PC += 1;
        core.tCycles += 16;
        const msb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        const lsb: u8 = core.memory.read8(core.cpu.PC);
        core.cpu.PC += 1;

        core.cpu.PC = (@as(u16, lsb) << 8) | msb;
    }

    pub fn xor_a_r(core: *Core, value: u8) void {
        core.cpu.PC += 1;
        core.tCycles += 1;
        core.cpu.AF.S.A ^= value;

        if (core.cpu.AF.S.A == 0)
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

    pub fn step(gb: *Core) !void {
        // std.log.info("PC=${x:0>4} OP=${x:0>2}", .{gb.cpu.PC, gb.memory.read8(gb.cpu.PC)});
        switch (gb.memory.read8(gb.cpu.PC)) {
            // NOP
            0 => nop(gb),
            // LD BC,d16
            0x01 => ld_rr_d16(gb, &gb.cpu.BC),
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
            0x08 => ld_a16_rr(gb, gb.cpu.SP),
            // ADD HL,BC
            0x09 => add_rr_rr(gb, gb.cpu.HL.HL, gb.cpu.BC.BC),
            // LD A,(BC)
            0x0A => ld_r_rr(gb, gb.cpu.AF.S.A, gb.cpu.BC.BC),
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
            0x10 => stop(gb),
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
            0x19 => add_rr_rr(gb, gb.cpu.HL.HL, gb.cpu.DE.DE),
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
            0x29 => add_rr_rr(gb, gb.cpu.HL.HL, gb.cpu.HL.HL),
            // LD A,(HL+)
            0x2A => ld_r_hli(gb, &gb.cpu.AF.S.A),
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
            0x34 => inc_rra(gb, gb.cpu.HL.HL),
            // DEC (HL)
            0x35 => dec_rra(gb, gb.cpu.HL.HL),
            // LD (HL),d8
            0x36 => ld_rr_d8(gb, gb.cpu.HL.HL),
            // SCF
            0x37 => scf(gb),
            // JR C,r8
            0x38 => jr_c_r8(gb),
            // ADD HL,SP
            0x39 => add_rr_rr(gb, gb.cpu.HL.HL, gb.cpu.SP),
            // LD A,(HL-)
            0x3A => ld_r_hld(gb),
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
            // LD C,A
            0x48 => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.AF.S.A),
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
            // LD C,H
            0x5C => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.HL.S.H),
            // LD C,L
            0x5D => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.HL.S.L),
            // LD C,(HL)
            0x5E => ld_r_rr(gb, &gb.cpu.BC.S.C, gb.cpu.HL.HL),
            // LD C,A
            0x5F => ld_r_r(gb, &gb.cpu.BC.S.C, gb.cpu.AF.S.A),
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
            0x70 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.BC.S.B),
            // LD (HL),C
            0x71 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.BC.S.C),
            // LD (HL),D
            0x72 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.DE.S.D),
            // LD (HL),E
            0x73 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.DE.S.E),
            // LD (HL),H
            0x74 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.HL.S.H),
            // LD (HL),L
            0x75 => ld_rr_r(gb, gb.cpu.HL, gb.cpu.HL.S.L),
            // HALT
            0x76 => halt(gb),
            // LD (HL),A
            0x77 => ld_rr_r(gb, gb.cpu.HL.HL, gb.cpu.AF.S.A),
            // LD A,B
            0x78 => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.BC.S.B),
            // LD A,C
            0x79 => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.BC.S.C),
            // LD A,D
            0x7C => ld_r_r(gb, &gb.cpu.AF.S.A, gb.cpu.DE.S.D),
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
            0x84 => add_r(gb, gb.cpu.HL.S.h),
            // ADD A,L
            0x85 => add_r(gb, gb.cpu.HL.S.L),
            // ADD A,(HL)
            0x86 => add_rr(gb, gb.cpu.HL.HL),
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
            // ADC (HL)
            0x8E => adc_rr(gb, gb.cpu.HL.HL),
            // ADC A,A
            0x8F => adc_r(gb, gb.cpu.HL.S.A),
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
            0x96 => sub_rr(gb, gb.cpu.HL.HL),
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
            0x9E => sbc_rr(gb, gb.cpu.HL.HL),
            // SBC A,A
            0x9F => sbc_r(gb, gb.cpu.HL.S.A),
            // AND B
            0xA0 => and_r(gb, &gb.cpu.BC.S.B),
            // AND C
            0xA1 => and_r(gb, &gb.cpu.BC.S.C),
            // AND D
            0xA2 => and_r(gb, &gb.cpu.DE.S.D),
            // AND E
            0xA3 => and_r(gb, &gb.cpu.DE.S.E),
            // AND H
            0xA4 => and_r(gb, &gb.cpu.HL.S.H),
            // AND L
            0xA5 => and_r(gb, &gb.cpu.HL.S.L),
            // AND (HL)
            0xA6 => and_rr(gb, gb.cpu.HL.HL),
            // AND A
            0xA7 => and_r(gb, &gb.cpu.AF.S.A),
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
            0xAE => xor_rr(gb, gb.cpu.HL.HL),
            // XOR A,A
            0xAF => xor_r(gb, gb.cpu.HL.S.A),
            // AND B
            0xA0 => and_r(gb, &gb.cpu.BC.S.B),
            // OR C
            0xB1 => or_r(gb, &gb.cpu.BC.S.C),
            // OR D
            0xB2 => or_r(gb, &gb.cpu.DE.S.D),
            // OR E
            0xB3 => or_r(gb, &gb.cpu.DE.S.E),
            // OR H
            0xB4 => or_r(gb, &gb.cpu.HL.S.H),
            // OR L
            0xB5 => or_r(gb, &gb.cpu.HL.S.L),
            // OR (HL)
            0xB6 => or_rr(gb, gb.cpu.HL.HL),
            // OR A
            0xB7 => or_r(gb, &gb.cpu.AF.S.A),
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
            0xBE => cp_rr(gb, gb.cpu.HL.HL),
            // CP A,A
            0xBF => cp_r(gb, gb.cpu.HL.S.A),
            // RET NZ
            0xC0 => ret_nz(gb),
            // POP BC
            0xC1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),
            // JP NZ,a16
            0xC2 => jp_nz(gb),
            // JP a16
            0xC3 => jp(gb),
            // CALL NZ,a16
            0xC4 => call_nz(gb),
            // PUSH BC
            0xC5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.BC))),
            // ADD A,d8
            0xC6 => add_d8(gb),
            // RST 00H
            0xC7 => rst(gb, 0x00),
            // RET Z
            0xC8 => ret_z(gb),
            // RET
            0xC9 => ret(gb),
            // JP Z,a16
            0xCA => jp_z(gb),
            // Pefix CB
            0xCB => {
                gb.cpu.PC += 1;
                gb.tCycles += 4;
                switch (gb.memory.read8(gb.cpu.PC)) {
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
                        gb.tCycles += 4;
                        gb.cpu.AF.S.F.h = 1;
                        gb.cpu.AF.S.F.n = 0;
                        gb.cpu.AF.S.F.z = 0;

                        gb.cpu.AF.S.F.z = @intCast(u1, ((gb.cpu.HL.S.H >> 7) & 1) ^ 1);
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
            // CALL Z,a16
            0xCC => call_z(gb),
            // CALL nn
            0xCD => call(gb),
            // ADC A,d8
            0xCE => adc_r_d8(gb),
            // RST 08H
            0xCF => rst(gb, 0x08),
            // RET NC
            0xD0 => ret_nc(gb),
            // POP DE
            0xD1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.DE))),
            // JP NC,a16
            0xD2 => jp_nc(gb),
            // CALL NC,a16
            0xD4 => call_nc(gb),
            // PUSH DE
            0xD5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.DE))),
            // SUB d8
            0xD6 => sub_d8(gb),
            // RST 10H
            0xD7 => rst(0x10),
            // RET C
            0xD8 => ret_c(gb),
            // RETI
            0xD9 => reti(gb),
            // JP C,a16
            0xDA => jp_c(gb),
            // CALL C,a16
            0xDC => call_c(gb),
            // SBC A,d8
            0xDE => sbc_d8(gb),
            // RST 18H
            0xDF => rst(0x18),
            // LDH (a8), A | LD ($FF00+a8),A
            0xE0 => ldh_a8_a,
            // POP HL
            0xE1 => pop_rr(gb, &(@bitCast(RegisterReference, gb.cpu.HL))),
            // LD (A),(C) | LD ($FF00+C),A
            0xE2 => ldc_a(gb),
            // PUSH HL
            0xE5 => push_rr(gb, &(@bitCast(RegisterReference, gb.cpu.HL))),
            // AND d8
            0xE6 => and_d8(gb),
            // RST 20H
            0xE7 => rst(gb, 0x20),
            // ADD SP,r8
            0xE8 => add_rr_r8(gb, &gb.cpu.SP),
            // JP (HL)
            0xE9 => jp_rr(gb, gb.cpu.HL),
            // LD (a16),A
            0xEA => ld_a16_a(gb),
            // XOR d8
            0xEE => xor_d8(gb),
            // RST 28H
            0xEF => rst(gb, 0x28),
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
            0xF7 => rst(gb, 0x30),
            // LD HL,SP+r8
            0xF8 => ld_hl_sp_r8(gb),
            // LD SP,HL
            0xF9 => ld_rr_rr(gb, &gb.cpu.SP, gb.CPU.HL.HL),
            // LD A,(a16)
            0xFA => ld_a_a16(gb),
            // EI
            0xFB => ei(gb),
            // CP d8
            0xFE => cp_d8(gb),
            // RST 38H
            0xFF => rst(gb, 0x38),
            else => blk: {
                gb.halt = true;
                std.log.info("Unimplemented Instruction at PC=${X:0>4}:0x{X:0>2}", .{ gb.cpu.PC, gb.memory.read8(gb.cpu.PC) });
                // std.log.info("Flags={B:0>1}", .{gb.cpu.AF.S.F});
                break :blk return RuntimeError.InstructionNotImplemented;
            },
        }
    }
};
