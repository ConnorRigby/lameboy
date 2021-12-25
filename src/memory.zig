const std = @import("std");
pub const Memory = struct {
    Bootrom: [256]u8,
    ROM: [0x3FFF]u8,
    VRAM: [0x8000]u8,
    ERAM: [0x8000]u8,
    WRAM: [0x4000]u8,
    OAM: [0x9F]u8,
    HRAM: [128]u8,

    romSize: u64,

    interruptsEnabled: bool,
    inBootrom: bool,

    pub fn init() Memory {
        return Memory{
            .Bootrom = [_]u8{0} ** 0x100,
            .ROM = [_]u8{0} ** 0x3FFF,
            .VRAM = [_]u8{0} ** 0x8000,
            .ERAM = [_]u8{0} ** 0x8000,
            .WRAM = [_]u8{0} ** 0x4000,
            .OAM = [_]u8{0} ** 0x9F,
            .HRAM = [_]u8{0} ** 128,
            .inBootrom = true,
            .interruptsEnabled = false,
            .romSize = 0,
        };
    }

    pub fn read8(mem: *Memory, address: u16) u8 {
        // std.log.info("\tread8 ${x:0>4}", .{address});
        if (address <= 0x3FFF) {
            if (address <= 0x100 and mem.inBootrom) {
                return mem.Bootrom[address];
            } else {
                return mem.ROM[address];
            }
        } else if (address <= 0x7FFF) {
            return mem.ROM[address];
        } else if (address <= 0x9FFF) {
            return mem.VRAM[0xA000 - address];
        } else if (address <= 0xBFFF) {
            return mem.ERAM[0xC000 - address];
        } else if (address <= 0xCFFF) {
            return mem.WRAM[0xD000 - address];
        } else if (address <= 0xFDFF) {
            return mem.WRAM[0xFE00 - address];
        } else if (address <= 0xFE9F) {
            return mem.OAM[0xFEA0 - address];
        } else if (address <= 0xFEFF) {
            std.log.info("you can't do that!!!!!", .{});
            return 0;
        } else if (address <= 0xFF7F) {
            // std.log.info("\tRead IO register ${x:0>4}", .{address});
            // std.os.exit(1);
            return 0x90;
        } else if (address <= 0xFFFE) {
            return mem.HRAM[0xFFFF - address];
        } else if (address == 0xFFFF) {
            return @boolToInt(mem.interruptsEnabled);
        } else {
            std.log.info("oops, something bad happened", .{});
            std.os.exit(1);
            return 0;
        }
    }

    pub fn readi8(mem: *Memory, address: u16) i8 {
        return @bitCast(i8, mem.read8(address));
    }

    pub fn write8(mem: *Memory, address: u16, value: u8) void {
        // std.log.info("\t write8 ${x:0>4}=${x:0>2}", .{address, value});
        if (address == 0xFF01) {
            std.log.info("{c}", .{value});
            // std.io.bufferedWriter(stdout)
            // const stdout = std.io.getStdOut().writer();
            // const array = [1]u8{value};
            // stdout.write(&array) catch {};
        }

        // mem.Raw[address] = value;
        // std.log.info("write address={x:0>4} read={x:0>4}", .{ address, mem.read8(address) });
        if (address <= 0x3FFF) {
            if (address <= 0x100 and mem.inBootrom) {
                std.log.info("can't write to bootrom ${x:0>4}=${x:0>4}", .{ address, value });
            } else {
                std.log.info("can't write to rom ${x:0>4}=${x:0>4}", .{ address, value });
            }
        } else if (address <= 0x7FFF) {
            std.log.info("can't write to rom", .{});
            std.os.exit(1);
        } else if (address <= 0x9FFF) {
            // std.log.info("VRAM[${x:0>4}]=${x:0>2}", .{0xA000-address,value});
            mem.VRAM[0xA000 - address] = value;
        } else if (address <= 0xBFFF) {
            mem.ERAM[0xC000 - address] = value;
        } else if (address <= 0xCFFF) {
            mem.WRAM[0xD000 - address] = value;
        } else if (address <= 0xFDFF) {
            mem.WRAM[0xFE00 - address] = value;
        } else if (address <= 0xFE9F) {
            mem.OAM[0xFEA0 - address] = value;
        } else if (address <= 0xFEFF) {
            std.log.info("you can't do that!!!!!", .{});
        } else if (address >= 0xFF00 and address <= 0xFF7F) {
            if (address == 0xFF50) {
                mem.inBootrom = false;
            } else if (address == 0xFF42) {
                // fix this later
            } else {
                std.log.info("Unknown IO register write ${x:0>4} ${x:0>2}", .{ address, value });
            }
        } else if (address <= 0xFFFE) {
            mem.HRAM[0xFFFF - address] = value;
        } else if (address == 0xFFFF) {
            if (value == 1) {
                mem.interruptsEnabled = true;
            } else {
                mem.interruptsEnabled = false;
            }
        } else {
            std.log.info("oops, something bad happened", .{});
        }
    }
};
