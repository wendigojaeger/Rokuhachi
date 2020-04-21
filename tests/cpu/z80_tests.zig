const rokuhachi = @import("rokuhachi");
const z80 = rokuhachi.cpu.z80;
const std = @import("std");
const testing = std.testing;
usingnamespace @import("../helpers.zig");

fn testRead8(address: u16) u8 {
    return 0;
}

fn testWrite8(address: u16, data: u8) void {
    // Write
}

const testBus = z80.Z80Bus{
    .read8 = testRead8,
    .write8 = testWrite8,
};

test "Z80 init" {
    var cpu = z80.Z80.init(testBus);
    cpu.tick();
}

test "Z80 NOP" {
    const TestData = struct {
        pub const Data = [_]u8{
            0x00, // NOP
        };

        pub fn read8(address: u16) u8 {
            return if (address < Data.len) Data[address] else 0;
        }

        pub fn write8(address: u16, data: u8) void {}
    };

    var cpu = z80.Z80.init(.{
        .read8 = TestData.read8,
        .write8 = TestData.write8,
    });

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        cpu.tick();
    }

    expectEq(cpu.total_t_cycles, 4);
    expectEq(cpu.total_m_cycles, 1);
}
