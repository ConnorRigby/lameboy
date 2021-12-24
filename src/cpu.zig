const std = @import("std");

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
