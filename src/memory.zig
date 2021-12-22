pub const Memory = extern union {
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

    pub fn init() Memory {
        return Memory{
            .Raw = [_]u8{0} ** 0xFFFF,
        };
    }
};
