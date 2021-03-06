const std = @import("std");
pub const MMU = struct {
    Bootrom: [256]u8,
    ROM: [0xFFFFF]u8,
    VRAM: [0x8000]u8,
    ERAM: [0x8000]u8,
    WRAM: [0x4000]u8,
    OAM: [0x9F]u8,
    HRAM: [128]u8,

    romSize: u64,

    interruptsEnabled: bool,
    inBootrom: bool,

    scy: u8,

    pub fn init() MMU {
        return MMU{
            .Bootrom = [_]u8{0} ** 0x100,
            .ROM = [_]u8{0} ** 0xFFFFF,
            .VRAM = [_]u8{0} ** 0x8000,
            .ERAM = [_]u8{0} ** 0x8000,
            .WRAM = [_]u8{0} ** 0x4000,
            .OAM = [_]u8{0} ** 0x9F,
            .HRAM = [_]u8{0} ** 128,
            .inBootrom = true,
            .interruptsEnabled = false,
            .romSize = 0,
            .scy = 0,
        };
    }

    pub fn read8(mem: *MMU, address: u16) u8 {
        // std.log.info("\tread8 ${x:0>4}", .{address});
        // if(address == 0x0104)
        //     return 0xCE;

        if (address <= 0x3FFF) {
            if (address < 0x0100) {
                if (mem.inBootrom) {
                    return mem.Bootrom[address];
                } else {
                    return mem.ROM[address];
                }
            } else {
                return mem.ROM[address];
            }
        } else if (address <= 0x7FFF) {
            // std.log.info("read {x:0>4} {x:0>2}", .{address, mem.ROM[address]});
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
            if (address == 0xff44) {
                return 0x90;
            } else if (address == 0xff42) {
                return mem.scy;
            } else {
                return 0x0;
            }
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

    pub fn readi8(mem: *MMU, address: u16) i8 {
        return @bitCast(i8, mem.read8(address));
    }

    pub fn write8(mem: *MMU, address: u16, value: u8) void {
        // std.log.info("\t write8 ${x:0>4}=${x:0>2}", .{address, value});
        if (address == 0xFF01) {
            const out = std.io.getStdErr();
            var buf = std.io.bufferedWriter(out.writer());
            // Get the Writer interface from BufferedWriter
            var w = buf.writer();
            w.writeByte(value) catch return;
            buf.flush() catch return;

            // const writer = std.io.getStdOut().writer();
            // writer.writeByte(value) catch return;
            // writer.flush();
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
            }
            if (address == 0xff42) {
                mem.scy = value;
            } else {
                // std.log.info("Unknown IO register write ${x:0>4} ${x:0>2}", .{ address, value });
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
