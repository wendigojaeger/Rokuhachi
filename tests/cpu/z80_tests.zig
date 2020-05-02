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
    var test_io = TestIO(256, &[_]u8{
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

test "Z80 LD register <- register" {
    var test_io = TestIO(256, &[_]u8{
        0x7f, // LD A,A
        0x78, // LD A,B
        0x79, // LD A,C
        0x7A, // LD A,D
        0x7B, // LD A,E
        0x7C, // LD A,H
        0x7D, // LD A,L

        0x47, // LD B,A
        0x40, // LD B,B
        0x41, // LD B,C
        0x42, // LD B,D
        0x43, // LD B,E
        0x44, // LD B,H
        0x45, // LD B,L

        0x4f, // LD C,A
        0x48, // LD C,B
        0x49, // LD C,C
        0x4A, // LD C,D
        0x4B, // LD C,E
        0x4C, // LD C,H
        0x4D, // LD C,L

        0x57, // LD D,A
        0x50, // LD D,B
        0x51, // LD D,C
        0x52, // LD D,D
        0x53, // LD D,E
        0x54, // LD D,H
        0x55, // LD D,L

        0x5F, // LD E,A
        0x58, // LD E,B
        0x59, // LD E,C
        0x5A, // LD E,D
        0x5B, // LD E,E
        0x5C, // LD E,H
        0x5D, // LD E,L

        0x67, // LD H,A
        0x60, // LD H,B
        0x61, // LD H,C
        0x62, // LD H,D
        0x63, // LD H,E
        0x64, // LD H,H
        0x65, // LD H,L

        0x6F, // LD L,A
        0x68, // LD L,B
        0x69, // LD L,C
        0x6A, // LD L,D
        0x6B, // LD L,E
        0x6C, // LD L,H
        0x6D, // LD L,L
    }).init(std.testing.allocator);
    defer test_io.deinit();

    var cpu = z80.Z80.init(&test_io.bus);

    // LD A,A
    {
        cpu.registers.main.af.pair.A = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0xFF);
    }
    // LD A,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x0B);
    }
    // LD A,C
    {
        cpu.registers.main.bc.pair.C = 0x0C;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x0C);
    }
    // LD A,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x0D);
    }
    // LD A,E
    {
        cpu.registers.main.de.pair.E = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x0D);
    }
    // LD A,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x01);
    }
    // LD A,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x02);
    }

    // LD B,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x0A);
    }
    // LD B,B
    {
        cpu.registers.main.bc.pair.B = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0xFF);
    }
    // LD B,C
    {
        cpu.registers.main.bc.pair.C = 0x0C;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x0C);
    }
    // LD B,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x0D);
    }
    // LD B,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x0E);
    }
    // LD B,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x01);
    }
    // LD B,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x02);
    }

    // LD C,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x0A);
    }
    // LD C,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x0B);
    }
    // LD C,C
    {
        cpu.registers.main.bc.pair.C = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0xFF);
    }
    // LD C,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x0D);
    }
    // LD C,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x0E);
    }
    // LD C,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x01);
    }
    // LD C,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x02);
    }

    // LD D,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x0A);
    }
    // LD D,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x0B);
    }
    // LD D,C
    {
        cpu.registers.main.bc.pair.C = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0xFF);
    }
    // LD D,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x0D);
    }
    // LD D,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x0E);
    }
    // LD D,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x01);
    }
    // LD D,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x02);
    }

    // LD E,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x0A);
    }
    // LD E,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x0B);
    }
    // LD E,C
    {
        cpu.registers.main.bc.pair.C = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0xFF);
    }
    // LD E,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x0D);
    }
    // LD E,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x0E);
    }
    // LD E,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x01);
    }
    // LD E,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x02);
    }

    // LD H,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x0A);
    }
    // LD H,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x0B);
    }
    // LD H,C
    {
        cpu.registers.main.bc.pair.C = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0xFF);
    }
    // LD H,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x0D);
    }
    // LD H,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x0E);
    }
    // LD H,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x01);
    }
    // LD H,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x02);
    }

    // LD L,A
    {
        cpu.registers.main.af.pair.A = 0x0A;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x0A);
    }
    // LD L,B
    {
        cpu.registers.main.bc.pair.B = 0x0B;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x0B);
    }
    // LD L,C
    {
        cpu.registers.main.bc.pair.C = 0xFF;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0xFF);
    }
    // LD L,D
    {
        cpu.registers.main.de.pair.D = 0x0D;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x0D);
    }
    // LD L,E
    {
        cpu.registers.main.de.pair.E = 0x0E;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x0E);
    }
    // LD L,H
    {
        cpu.registers.main.hl.pair.H = 0x01;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x01);
    }
    // LD L,L
    {
        cpu.registers.main.hl.pair.L = 0x02;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x02);
    }
}

test "Z80 LD register <- immediate data" {
    var test_io = TestIO(256, &[_]u8{
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

    expectEq(cpu.registers.main.af.pair.A, 0x02);
    expectEq(cpu.registers.main.bc.pair.B, 0x12);
    expectEq(cpu.registers.main.bc.pair.C, 0x22);
    expectEq(cpu.registers.main.de.pair.D, 0x32);
    expectEq(cpu.registers.main.de.pair.E, 0x42);
    expectEq(cpu.registers.main.hl.pair.H, 0x52);
    expectEq(cpu.registers.main.hl.pair.L, 0x62);

    expectEq(cpu.total_t_cycles, 7 * 7);
    expectEq(cpu.total_m_cycles, 7 * 2);
}

test "Z80 LD register <- (HL)" {
    var test_io = TestIO(256, &[_]u8{
        0x26, 0x80, // LD H, #$80
        0x2e, 0x00, // LD L, #$00
        0x7e, // LD A, (HL)
            0x46, // LD B, (HL)
        0x4e, // LD C, (HL)
            0x56, // LD D, (HL)
        0x5e, // LD E, (HL)
            0x66, // LD H, (HL)
        0x26, 0x80, // LD H, #$80
        0x6e, // LD L, (HL)
    }).init(std.testing.allocator);
    defer test_io.deinit();

    var cpu = z80.Z80.init(&test_io.bus);

    {
        var i: usize = 0;
        while (i < (7 * 2)) : (i += 1) {
            cpu.tick();
        }
    }

    {
        test_io.ram[0] = 1;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.af.pair.A, 0x01);
    }

    {
        test_io.ram[0] = 2;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.B, 0x02);
    }

    {
        test_io.ram[0] = 3;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.bc.pair.C, 0x03);
    }

    {
        test_io.ram[0] = 4;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.D, 0x04);
    }

    {
        test_io.ram[0] = 5;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.de.pair.E, 0x05);
    }

    {
        test_io.ram[0] = 6;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.H, 0x06);
    }

    {
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
    }

    {
        test_io.ram[0] = 7;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            cpu.tick();
        }
        expectEq(cpu.registers.main.hl.pair.L, 0x07);
    }

    expectEq(cpu.total_t_cycles, 10 * 7);
    expectEq(cpu.total_m_cycles, 10 * 2);
}
