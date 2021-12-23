const std = @import("std");
const Core = @import("core.zig").Core;

const lua = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

// #define luaL_newlib(L,l)  \
//   (luaL_checkversion(L), luaL_newlibtable(L,l), luaL_setfuncs(L,l,0))
// pub fn luaL_newlib(L: ?*lua.lua_State, l: [*]const lua.luaL_Reg) void {
//   lua.luaL_checkversion(L);
//   lua.lua_createtable(L, 0, 1);
//   lua.luaL_setfuncs(L, l, 0);
// }

pub const DebuggerError = error{Load};

export fn foo_doSomething(_: ?*lua.lua_State) c_int {
    std.log.info("## foo_doSomething", .{});
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

    pub fn start(debugger: *Debugger, core: *Core) !void {
        std.log.info("starting debugger {*} {*}", .{ debugger, core });

        const status = lua.luaL_loadfilex(debugger.L, "script.lua", "bt");
        if (status != 0) {
            std.log.info("Couldn't load file: {s}", .{lua.lua_tolstring(debugger.L, -1, null)});
            return DebuggerError.Load;
        }

        const methods = &[_]lua.luaL_Reg{ lua.luaL_Reg{ .name = "doSomething", .func = foo_doSomething }, .{ .name = null, .func = null } };

        lua.lua_createtable(debugger.L, 0, 1);
        lua.luaL_setfuncs(debugger.L, @as([*]const lua.luaL_Reg, methods), 0);
        lua.lua_setglobal(debugger.L, "Foo");

        const result = lua.lua_pcallk(debugger.L, 0, lua.LUA_MULTRET, 0, 0, null);
        if (result != 0) {
            std.log.info("Failed to run script: {s}", .{lua.lua_tolstring(debugger.L, -1, null)});
        }
    }
};
