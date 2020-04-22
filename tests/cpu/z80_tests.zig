const rokuhachi = @import("rokuhachi");
const z80 = rokuhachi.cpu.z80;
const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
usingnamespace @import("../helpers.zig");

fn TestIO(comptime ram_size: usize, comptime rom: []const u8) type {
    return struct {
        bus: z80.Z80Bus,
        ram: []u8,
        allocator: *Allocator,

        pub const ROM = rom;

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .bus = .{
                    .read8 = read8,
                    .write8 = write8,
                },
                .ram = allocator.alloc(u8, ram_size) catch unreachable,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.ram);
        }

        pub fn read8(bus: *z80.Z80Bus, address: u16) u8 {
            const self = @fieldParentPtr(Self, "bus", bus);

            if (address < ROM.len) {
                return ROM[address];
            }

            if (address >= 0x8000 and address < (0x8000 + ram_size)) {
                return self.ram[address - 0x8000];
            }

            return 0;
        }

        pub fn write8(bus: *z80.Z80Bus, address: u16, data: u8) void {
            const self = @fieldParentPtr(Self, "bus", bus);

            if (address >= 0x8000 and address < (0x8000 + ram_size)) {
                self.ram[address - 0x8000] = data;
            }
        }
    };
}

test "Z80 NOP" {
    var test_io = TestIO(2 * 1024, &[_]u8{
        0x00, // NOP
    }).init(std.testing.allocator);
    defer test_io.deinit();

    var cpu = z80.Z80.init(&test_io.bus);

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        cpu.tick();
    }

    expectEq(cpu.total_t_cycles, 4);
    expectEq(cpu.total_m_cycles, 1);
}

test "Z80 LD register <- immediate data" {
    var test_io = TestIO(2 * 1024, &[_]u8{
        0x3e, 0x02, // LD A, #$02
        0x06, 0x12, // LD B, #$12
        0x0e, 0x22, // LD C, #$22
        0x16, 0x32, // LD D, #$32
        0x1e, 0x42, // LD E, #$42
        0x26, 0x52, // LD H, #$52
        0x2e, 0x62, // LD L, #$62
    }).init(std.testing.allocator);
    defer test_io.deinit();

    var cpu = z80.Z80.init(&test_io.bus);

    var i: usize = 0;
    while (i < (7 * 7)) : (i += 1) {
        cpu.tick();
    }

    expectEq(cpu.registers.main_registers.af.pair.A, 0x02);
    expectEq(cpu.registers.main_registers.bc.pair.B, 0x12);
    expectEq(cpu.registers.main_registers.bc.pair.C, 0x22);
    expectEq(cpu.registers.main_registers.de.pair.D, 0x32);
    expectEq(cpu.registers.main_registers.de.pair.E, 0x42);
    expectEq(cpu.registers.main_registers.hl.pair.H, 0x52);
    expectEq(cpu.registers.main_registers.hl.pair.L, 0x62);

    expectEq(cpu.total_t_cycles, 7 * 7);
    expectEq(cpu.total_m_cycles, 7 * 2);
}
