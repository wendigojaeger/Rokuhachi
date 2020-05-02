const std = @import("std");

pub const FlagRegister = packed union {
    raw: u8,
    flags: Flags,
    symbols: FlagsSymbol,
};

pub const FlagsSymbol = packed struct {
    C: bool,
    N: bool,
    V: bool,
    dummmy1: bool,
    H: bool,
    dummy2: bool,
    Z: bool,
    S: bool,
};

pub const Flags = packed struct {
    carry: bool,
    is_sub: bool,
    overflow: bool,
    dummy1: bool,
    half_carry: bool,
    dummy2: bool,
    zero: bool,
    sign: bool,
};

const AF = packed union {
    raw: u16,
    pair: packed struct {
        F: FlagRegister,
        A: u8,
    },
};

const BC = packed union {
    raw: u16,
    pair: packed struct {
        C: u8,
        B: u8,
    },
};

const DE = packed union {
    raw: u16,
    pair: packed struct {
        E: u8,
        D: u8,
    },
};

const HL = packed union {
    raw: u16,
    pair: packed struct {
        L: u8,
        H: u8,
    },
};

pub const GeneralRegisters = packed struct {
    af: AF,
    bc: BC,
    de: DE,
    hl: HL,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .af = AF{ .raw = 0 },
            .bc = BC{ .raw = 0 },
            .de = DE{ .raw = 0 },
            .hl = HL{ .raw = 0 },
        };
    }
};

pub const Z80Registers = struct {
    main_registers: GeneralRegisters,
    alternate_registers: GeneralRegisters,
    ix: u16 = 0,
    iy: u16 = 0,
    sp: u16 = 0,
    pc: u16 = 0,
    interrupt_vector: u8 = 0,
    dram_refresh: u8 = 0,
    interrupt_enable1: bool = false,
    interrupt_enable2: bool = false,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .main_registers = GeneralRegisters.init(),
            .alternate_registers = GeneralRegisters.init(),
        };
    }
};

pub const Z80Bus = struct {
    read8: Read8Fn,
    write8: Write8Fn,

    pub const Read8Fn = fn (bus: *Z80Bus, address: u16) u8;
    pub const Write8Fn = fn (bus: *Z80Bus, address: u16, data: u8) void;
};

pub const InterruptMode = packed enum(u2) {
    Mode0,
    Mode1,
    Mode2,
};

const Timings = @import("z80/timings.zig").Timings;

pub const Z80 = struct {
    registers: Z80Registers,
    interrupt_mode: InterruptMode = .Mode0,
    is_halted: bool = false,
    wait: bool = false,
    total_t_cycles: u64 = 0,
    total_m_cycles: u64 = 0,
    current_cycles: []const u8 = undefined,
    current_t: u8 = 0,
    current_m: u8 = 0,
    current_instruction_storage: [3]u8 = undefined,

    current_instruction: []const u8 = undefined,
    bus: *Z80Bus = undefined,

    const Self = @This();

    pub fn init(bus: *Z80Bus) Self {
        var result = Self{
            .registers = Z80Registers.init(),
            .bus = bus,
        };

        result.reset();

        return result;
    }

    pub fn interuptRequest(self: *Self) void {
        // Interrupt requested from an external device
    }

    pub fn nmiRequest(self: *Self) void {
        // Non Maskable Interrupt
        // Set PC to 0x0066
    }

    pub fn reset(self: *Self) void {
        // RESET signal
        self.registers.pc = 0;
        self.registers.interrupt_vector = 0;
        self.registers.dram_refresh = 0;
        self.registers.interrupt_enable1 = false;
        self.registers.interrupt_enable2 = false;
        self.current_t = 0;
        self.current_m = 0;
        self.total_t_cycles = 0;
        self.total_m_cycles = 0;
    }

    // BUSREQ ?

    pub fn tick(self: *Self) void {
        if (self.current_t == 0 and self.current_m == 0) {
            // When halted, do NOP
            if (self.is_halted) {
                self.current_instruction_storage[0] = 0;
                self.current_instruction = self.current_instruction_storage[0..1];
            } else {
                // Read instruction from memory
                self.current_instruction_storage[0] = self.bus.read8(self.bus, self.registers.pc);
                self.registers.pc += 1;
                self.current_instruction = self.current_instruction_storage[0..1];
            }

            self.current_cycles = Timings[self.current_instruction[0]];
            self.current_m = 0;
            self.current_t = self.current_cycles[self.current_m];
        }

        switch (self.current_instruction[0]) {
            0x00 => {
                // NOP
            },
            0x06 => {
                self.LD(dest_reg_B, source_imm8);
            },
            0x0e => {
                self.LD(dest_reg_C, source_imm8);
            },
            0x16 => {
                self.LD(dest_reg_D, source_imm8);
            },
            0x1e => {
                self.LD(dest_reg_E, source_imm8);
            },
            0x26 => {
                self.LD(dest_reg_H, source_imm8);
            },
            0x2e => {
                self.LD(dest_reg_L, source_imm8);
            },
            0x3e => {
                self.LD(dest_reg_A, source_imm8);
            },
            0x40 => {
                self.LD(dest_reg_B, source_reg_B);
            },
            0x41 => {
                self.LD(dest_reg_B, source_reg_C);
            },
            0x42 => {
                self.LD(dest_reg_B, source_reg_D);
            },
            0x43 => {
                self.LD(dest_reg_B, source_reg_E);
            },
            0x44 => {
                self.LD(dest_reg_B, source_reg_H);
            },
            0x45 => {
                self.LD(dest_reg_B, source_reg_L);
            },
            0x47 => {
                self.LD(dest_reg_B, source_reg_A);
            },
            0x48 => {
                self.LD(dest_reg_C, source_reg_B);
            },
            0x49 => {
                self.LD(dest_reg_C, source_reg_C);
            },
            0x4A => {
                self.LD(dest_reg_C, source_reg_D);
            },
            0x4B => {
                self.LD(dest_reg_C, source_reg_E);
            },
            0x4C => {
                self.LD(dest_reg_C, source_reg_H);
            },
            0x4D => {
                self.LD(dest_reg_C, source_reg_L);
            },
            0x4F => {
                self.LD(dest_reg_C, source_reg_A);
            },
            0x50 => {
                self.LD(dest_reg_D, source_reg_B);
            },
            0x51 => {
                self.LD(dest_reg_D, source_reg_C);
            },
            0x52 => {
                self.LD(dest_reg_D, source_reg_D);
            },
            0x53 => {
                self.LD(dest_reg_D, source_reg_E);
            },
            0x54 => {
                self.LD(dest_reg_D, source_reg_H);
            },
            0x55 => {
                self.LD(dest_reg_D, source_reg_L);
            },
            0x57 => {
                self.LD(dest_reg_D, source_reg_A);
            },
            0x58 => {
                self.LD(dest_reg_E, source_reg_B);
            },
            0x59 => {
                self.LD(dest_reg_E, source_reg_C);
            },
            0x5A => {
                self.LD(dest_reg_E, source_reg_D);
            },
            0x5B => {
                self.LD(dest_reg_E, source_reg_E);
            },
            0x5C => {
                self.LD(dest_reg_E, source_reg_H);
            },
            0x5D => {
                self.LD(dest_reg_E, source_reg_L);
            },
            0x5F => {
                self.LD(dest_reg_E, source_reg_A);
            },
            0x60 => {
                self.LD(dest_reg_H, source_reg_B);
            },
            0x61 => {
                self.LD(dest_reg_H, source_reg_C);
            },
            0x62 => {
                self.LD(dest_reg_H, source_reg_D);
            },
            0x63 => {
                self.LD(dest_reg_H, source_reg_E);
            },
            0x64 => {
                self.LD(dest_reg_H, source_reg_H);
            },
            0x65 => {
                self.LD(dest_reg_H, source_reg_L);
            },
            0x67 => {
                self.LD(dest_reg_H, source_reg_A);
            },
            0x68 => {
                self.LD(dest_reg_L, source_reg_B);
            },
            0x69 => {
                self.LD(dest_reg_L, source_reg_C);
            },
            0x6A => {
                self.LD(dest_reg_L, source_reg_D);
            },
            0x6B => {
                self.LD(dest_reg_L, source_reg_E);
            },
            0x6C => {
                self.LD(dest_reg_L, source_reg_H);
            },
            0x6D => {
                self.LD(dest_reg_L, source_reg_L);
            },
            0x6F => {
                self.LD(dest_reg_L, source_reg_A);
            },
            0x78 => {
                self.LD(dest_reg_A, source_reg_B);
            },
            0x79 => {
                self.LD(dest_reg_A, source_reg_C);
            },
            0x7A => {
                self.LD(dest_reg_A, source_reg_D);
            },
            0x7B => {
                self.LD(dest_reg_A, source_reg_E);
            },
            0x7C => {
                self.LD(dest_reg_A, source_reg_H);
            },
            0x7D => {
                self.LD(dest_reg_A, source_reg_L);
            },
            0x7F => {
                self.LD(dest_reg_A, source_reg_A);
            },
            else => {
                std.debug.panic("Opcode 0x{x} not implemented!\n", .{self.current_instruction[0]});
            },
        }

        if (self.current_t != 0) {
            self.current_t -= 1;
            if (self.current_t == 0) {
                self.current_m += 1;
                self.total_m_cycles += 1;

                if (self.current_m < self.current_cycles.len) {
                    self.current_t = self.current_cycles[self.current_m];
                } else {
                    self.current_m = 0;
                    self.current_t = 0;
                }
            }
        }

        self.total_t_cycles += 1;
    }

    const DestinationFn = fn (self: *Self, data: u16) void;
    const SourceFn = fn (self: *Self) ?u16;

    inline fn LD(self: *Self, comptime destinationFn: DestinationFn, comptime sourceFn: SourceFn) void {
        const readData = sourceFn(self);
        if (readData) |data| {
            destinationFn(self, data);
        }
    }

    inline fn dest_reg_A(self: *Self, data: u16) void {
        self.registers.main_registers.af.pair.A = @truncate(u8, data);
    }

    inline fn source_reg_A(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.af.pair.A;
        }

        return null;
    }

    inline fn dest_reg_F(self: *Self, data: u16) void {
        self.registers.main_registers.af.pair.F = @truncate(u8, data);
    }

    inline fn source_reg_F(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.af.pair.F;
        }

        return null;
    }

    inline fn dest_reg_B(self: *Self, data: u16) void {
        self.registers.main_registers.bc.pair.B = @truncate(u8, data);
    }

    inline fn source_reg_B(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.bc.pair.B;
        }

        return null;
    }

    inline fn dest_reg_C(self: *Self, data: u16) void {
        self.registers.main_registers.bc.pair.C = @truncate(u8, data);
    }

    inline fn source_reg_C(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.bc.pair.C;
        }

        return null;
    }

    inline fn dest_reg_D(self: *Self, data: u16) void {
        self.registers.main_registers.de.pair.D = @truncate(u8, data);
    }

    inline fn source_reg_D(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.de.pair.D;
        }

        return null;
    }

    inline fn dest_reg_E(self: *Self, data: u16) void {
        self.registers.main_registers.de.pair.E = @truncate(u8, data);
    }

    inline fn source_reg_E(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.de.pair.E;
        }

        return null;
    }

    inline fn dest_reg_H(self: *Self, data: u16) void {
        self.registers.main_registers.hl.pair.H = @truncate(u8, data);
    }

    inline fn source_reg_H(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.hl.pair.H;
        }

        return null;
    }

    inline fn dest_reg_L(self: *Self, data: u16) void {
        self.registers.main_registers.hl.pair.L = @truncate(u8, data);
    }

    inline fn source_reg_L(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main_registers.hl.pair.L;
        }

        return null;
    }

    inline fn source_imm8(self: *Self) ?u16 {
        if (self.current_m == 1 and self.current_t == 3) {
            const result: u16 = self.bus.read8(self.bus, self.registers.pc);
            self.registers.pc += 1;
            return result;
        }

        return null;
    }
};
