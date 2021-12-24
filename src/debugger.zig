const std = @import("std");
const Core = @import("core.zig").Core;
const RegisterID = @import("cpu.zig").RegisterID;

const lua = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

pub const DebuggerError = error{Load};

export fn lua_readRegister(L: ?*lua.lua_State) c_int {
    lua.luaL_checktype(L, 1, lua.LUA_TTABLE);
    lua.luaL_checktype(L, 2, lua.LUA_TNUMBER);

    const value = lua.lua_tointegerx(L, -1, null);
    lua.lua_pop(L, 1);

    _ = lua.lua_getfield(L, -1, "__core__");
    var voidp = lua.lua_touserdata(L, -1);
    var core = @ptrCast(*Core, @alignCast(@alignOf(*Core), voidp));
    lua.lua_pop(L, 1);

    const registerValue = switch (@intToEnum(RegisterID, value)) {
        RegisterID.A => core.cpu.AF.S.A,
        RegisterID.F => @bitCast(u8, core.cpu.AF.S.F),
        RegisterID.AF => core.cpu.AF.AF,

        RegisterID.B => core.cpu.BC.S.B,
        RegisterID.C => core.cpu.BC.S.C,
        RegisterID.BC => core.cpu.BC.BC,

        RegisterID.D => core.cpu.DE.S.D,
        RegisterID.E => core.cpu.DE.S.E,
        RegisterID.DE => core.cpu.DE.DE,

        RegisterID.H => core.cpu.HL.S.H,
        RegisterID.L => core.cpu.HL.S.L,
        RegisterID.HL => core.cpu.HL.HL,

        RegisterID.PC => core.cpu.PC,
        RegisterID.SP => core.cpu.SP,
    };
    lua.lua_pushinteger(L, registerValue);
    return 1;
}

export fn lua_writeRegister(L: ?*lua.lua_State) c_int {
    lua.luaL_checktype(L, 1, lua.LUA_TTABLE);
    lua.luaL_checktype(L, 2, lua.LUA_TNUMBER);
    lua.luaL_checktype(L, 3, lua.LUA_TNUMBER);

    const value = lua.lua_tointegerx(L, -1, null);
    lua.lua_pop(L, 1);

    const register = lua.lua_tointegerx(L, -1, null);
    lua.lua_pop(L, 1);

    _ = lua.lua_getfield(L, -1, "__core__");
    var voidp = lua.lua_touserdata(L, -1);
    var core = @ptrCast(*Core, @alignCast(@alignOf(*Core), voidp));

    switch (@intToEnum(RegisterID, register)) {
        RegisterID.A, RegisterID.F, RegisterID.B, RegisterID.C, RegisterID.D, RegisterID.E, RegisterID.H, RegisterID.L => blk: {
            if (value > 0xFF) {
                _ = lua.lua_pushstring(L, "Value must be less than 0xff for 8bit loads");
                _ = lua.lua_error(L);
                return 0;
            }
            break :blk;
        },

        RegisterID.AF, RegisterID.BC, RegisterID.DE, RegisterID.HL, RegisterID.PC, RegisterID.SP => blk: {
            if (value > 0xFFFF) {
                _ = lua.lua_pushstring(L, "Value must be less than 0xFF for 16bit loads");
                _ = lua.lua_error(L);
                return 0;
            }
            break :blk;
        },
    }
    switch (@intToEnum(RegisterID, register)) {
        RegisterID.A => core.cpu.AF.S.A = @intCast(u8, value),
        RegisterID.F => core.cpu.AF.AF &= (0xFF00 | @intCast(u16, value)),
        RegisterID.AF => core.cpu.AF.AF = @intCast(u16, value),
        RegisterID.B => core.cpu.BC.S.B = @intCast(u8, value),
        RegisterID.C => core.cpu.BC.S.C = @intCast(u8, value),
        RegisterID.BC => core.cpu.BC.BC = @intCast(u16, value),
        RegisterID.D => core.cpu.DE.S.D = @intCast(u8, value),
        RegisterID.E => core.cpu.DE.S.E = @intCast(u8, value),
        RegisterID.DE => core.cpu.DE.DE = @intCast(u16, value),
        RegisterID.H => core.cpu.HL.S.H = @intCast(u8, value),
        RegisterID.L => core.cpu.HL.S.L = @intCast(u8, value),
        RegisterID.HL => core.cpu.HL.HL = @intCast(u16, value),
        RegisterID.PC => core.cpu.PC = @intCast(u16, value),
        RegisterID.SP => core.cpu.SP = @intCast(u16, value),
    }
    return 0;
}

export fn lua_read8(L: ?*lua.lua_State) c_int {
    lua.luaL_checktype(L, 1, lua.LUA_TTABLE);
    lua.luaL_checktype(L, 2, lua.LUA_TNUMBER);

    var value = lua.lua_tointegerx(L, -1, null);
    if (value > 0xffff) {
        _ = lua.lua_pushstring(L, "Address must be less than 0xffff");
        _ = lua.lua_error(L);
        return 0;
    }
    lua.lua_pop(L, 1);

    _ = lua.lua_getfield(L, -1, "__core__");
    var voidp = lua.lua_touserdata(L, -1);
    var core = @ptrCast(*Core, @alignCast(@alignOf(*Core), voidp));
    lua.lua_pushinteger(L, core.memory.read8(@intCast(u16, value)));
    return 1;
}

export fn lua_write8(L: ?*lua.lua_State) c_int {
    lua.luaL_checktype(L, 1, lua.LUA_TTABLE);
    lua.luaL_checktype(L, 2, lua.LUA_TNUMBER);
    lua.luaL_checktype(L, 3, lua.LUA_TNUMBER);

    var value = lua.lua_tointegerx(L, -1, null);
    if (value > 0xff) {
        _ = lua.lua_pushstring(L, "value must be less than 0xff");
        _ = lua.lua_error(L);
        return 0;
    }
    lua.lua_pop(L, 1);

    var address = lua.lua_tointegerx(L, -1, null);
    if (address > 0xffff) {
        _ = lua.lua_pushstring(L, "address must be less than 0xffff");
        _ = lua.lua_error(L);
        return 0;
    }
    lua.lua_pop(L, 1);

    _ = lua.lua_getfield(L, -1, "__core__");
    var voidp = lua.lua_touserdata(L, -1);
    var core = @ptrCast(*Core, @alignCast(@alignOf(*Core), voidp));
    core.memory.write8(@intCast(u16, address), @intCast(u8, value));
    return 0;
}

pub const Debugger = struct {
    L: ?*lua.lua_State,

    pub fn init() Debugger {
        var L = lua.luaL_newstate();
        lua.luaL_openlibs(L);
        return Debugger{
            .L = L,
        };
    }

    pub fn step(debugger: *Debugger) void {
        _ = lua.lua_getglobal(debugger.L, "Core");
        _ = lua.lua_getfield(debugger.L, -1, "step");
        if (lua.lua_isfunction(debugger.L, -1)) {
            _ = lua.lua_pcallk(debugger.L, 0, lua.LUA_MULTRET, 0, 0, null);
            lua.lua_pop(debugger.L, -1);
        } else {
            lua.lua_pop(debugger.L, -1);
        }
    }

    pub fn start(debugger: *Debugger, core: *Core) !void {
        // std.log.info("starting debugger {*} {*}", .{ debugger, core });

        const status = lua.luaL_loadfilex(debugger.L, "script.lua", "bt");
        if (status != 0) {
            std.log.info("Couldn't load file: {s}", .{lua.lua_tolstring(debugger.L, -1, null)});
            return DebuggerError.Load;
        }

        // global "core" table
        lua.lua_createtable(debugger.L, 0, 0);
        lua.lua_pushlightuserdata(debugger.L, core);
        lua.lua_setfield(debugger.L, -2, "__core__");

        // Memory table
        lua.lua_createtable(debugger.L, 0, 0);
        lua.lua_pushlightuserdata(debugger.L, core);
        lua.lua_setfield(debugger.L, -2, "__core__");
        const memoryMethods = &[_]lua.luaL_Reg{ lua.luaL_Reg{ .name = "peek", .func = lua_read8 }, lua.luaL_Reg{ .name = "poke", .func = lua_write8 }, .{ .name = null, .func = null } };
        lua.luaL_setfuncs(debugger.L, @as([*]const lua.luaL_Reg, memoryMethods), 0);
        lua.lua_setfield(debugger.L, -2, "Memory");

        // CPU table
        lua.lua_createtable(debugger.L, 0, 0);
        lua.lua_pushlightuserdata(debugger.L, core);
        lua.lua_setfield(debugger.L, -2, "__core__");
        const cpuMethods = &[_]lua.luaL_Reg{ lua.luaL_Reg{ .name = "getRegister", .func = lua_readRegister }, lua.luaL_Reg{ .name = "writeRegister", .func = lua_writeRegister }, .{ .name = null, .func = null } };
        lua.luaL_setfuncs(debugger.L, @as([*]const lua.luaL_Reg, cpuMethods), 0);

        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.A));
        lua.lua_setfield(debugger.L, -2, "A");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.F));
        lua.lua_setfield(debugger.L, -2, "F");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.AF));
        lua.lua_setfield(debugger.L, -2, "AF");

        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.B));
        lua.lua_setfield(debugger.L, -2, "B");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.C));
        lua.lua_setfield(debugger.L, -2, "C");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.BC));
        lua.lua_setfield(debugger.L, -2, "BC");

        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.D));
        lua.lua_setfield(debugger.L, -2, "D");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.E));
        lua.lua_setfield(debugger.L, -2, "E");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.DE));
        lua.lua_setfield(debugger.L, -2, "DE");

        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.H));
        lua.lua_setfield(debugger.L, -2, "H");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.L));
        lua.lua_setfield(debugger.L, -2, "L");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.HL));
        lua.lua_setfield(debugger.L, -2, "HL");

        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.PC));
        lua.lua_setfield(debugger.L, -2, "PC");
        lua.lua_pushinteger(debugger.L, @enumToInt(RegisterID.SP));
        lua.lua_setfield(debugger.L, -2, "SP");

        lua.lua_setfield(debugger.L, -2, "CPU");

        lua.lua_setglobal(debugger.L, "Core");

        const result = lua.lua_pcallk(debugger.L, 0, lua.LUA_MULTRET, 0, 0, null);
        if (result != 0) {
            std.log.info("Failed to run script: {s}", .{lua.lua_tolstring(debugger.L, -1, null)});
        }
    }
};
