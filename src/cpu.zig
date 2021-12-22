const std = @import("std");

pub const CPU = struct {
    /// Program Counter
    PC: u16,

    /// Stack Pointer
    SP: u16,

    AF: extern union {
        S: extern struct {
            A: u8,
            /// Flags: z: zero, n: subtract, h: half-carry, c: carry
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

    pub fn init() CPU {
        return CPU{
            .AF = .{ .AF = 0 },
            .BC = .{ .BC = 0 },
            .DE = .{ .DE = 0 },
            .HL = .{ .HL = 0 },
            .SP = 0,
            .PC = 0,
        };
    }
};
