const std = @import("std");
pub const Memory = struct {
    Raw: [0xFFFF]u8,
    Rom: [0xFFFF]u8,
    inBootrom: bool,

    pub fn init() Memory {
        std.log.info("MEM INIT", .{});
        return Memory{
            .Raw = [_]u8{0} ** 0xFFFF,
            .Rom = [_]u8{0} ** 0xFFFF,
            .inBootrom = true,
        };
    }

    pub fn read8(mem: *Memory, address: u16) u8 {
        if (address == 0x0104) {
            std.log.info("0x0104=0x{x:0>2}", .{mem.Raw[0x0104]});
        }
        if (address == 0x00a8) {
            std.log.info("0x00a8=0x{x:0>2}", .{mem.Raw[0x00a8]});
        }

        if (address <= 0x3FFF) {

            // need to check bootrom here
            return mem.Raw[address];

            // return mem.Rom[address];
        } else if (address == 0xff42) {
            mem.Raw[0xff42] +%= 1;
            return mem.Raw[0xff42];
        } else if (address == 0xff44) {
            return 0x90;
        } else {
            return mem.Raw[address];
        }
    }

    pub fn readi8(mem: *Memory, address: u16) i8 {
        return @bitCast(i8, mem.read8(address));
    }

    pub fn write8(mem: *Memory, address: u16, value: u8) void {
        mem.Raw[address] = value;
        std.log.info("write address={x:0>4} read={x:0>4}", .{ address, mem.read8(address) });
    }
};
