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
    main: GeneralRegisters,
    alternate: GeneralRegisters,
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
            .main = GeneralRegisters.init(),
            .alternate = GeneralRegisters.init(),
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

const InstructionMask = struct {
    pub const Load_Register_Register = 0b01000000;
    pub const Load_Register_Immediate = 0b00000110;
    pub const Load_Register_IndirectHL = 0b01000110;
    pub const Load_IndirectHL_Register = 0b01110000;
};

const RegisterMask = enum(u3) {
    A = 0b111,
    B = 0b000,
    C = 0b001,
    D = 0b010,
    E = 0b011,
    H = 0b100,
    L = 0b101,
};

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
    temp_pointer: u16 = 0,

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

        const current_opcode = self.current_instruction[0];

        var executed: bool = false;

        // NOP
        if (current_opcode == 0x00) {
            executed = true;
        }
        // LD r,r'
        inline for (std.meta.fields(RegisterMask)) |destination_field| {
            const destination_register = comptime @intToEnum(RegisterMask, destination_field.value);

            inline for (std.meta.fields(RegisterMask)) |source_field| {
                const source_register = comptime @intToEnum(RegisterMask, source_field.value);

                const ld_reg_reg_opcode = InstructionMask.Load_Register_Register | @as(u8, @enumToInt(source_register)) | (@as(u8, @enumToInt(destination_register)) << 3);

                if (current_opcode == ld_reg_reg_opcode) {
                    const dest_fn = comptime dest_reg_fn(destination_register);
                    const source_fn = comptime source_reg_fn(source_register);

                    self.LD(dest_fn, source_fn);
                    executed = true;
                }
            }
        }
        // LD r,n
        inline for (std.meta.fields(RegisterMask)) |destination_field| {
            const destination_register = comptime @intToEnum(RegisterMask, destination_field.value);

            const ld_reg_imm_opcode = InstructionMask.Load_Register_Immediate | (@as(u8, @enumToInt(destination_register)) << 3);

            if (current_opcode == ld_reg_imm_opcode) {
                const dest_fn = comptime dest_reg_fn(destination_register);

                self.LD(dest_fn, source_imm8);
                executed = true;
            }
        }
        // LD r, (HL)
        inline for (std.meta.fields(RegisterMask)) |destination_field| {
            const destination_register = comptime @intToEnum(RegisterMask, destination_field.value);

            const ld_reg_indirect_hl_opcode = InstructionMask.Load_Register_IndirectHL | (@as(u8, @enumToInt(destination_register)) << 3);

            if (current_opcode == ld_reg_indirect_hl_opcode) {
                const dest_fn = comptime dest_reg_fn(destination_register);

                self.LD(dest_fn, source_indirect_hl);
                executed = true;
            }
        }
        // LD (HL), r
        inline for (std.meta.fields(RegisterMask)) |source_field| {
            const source_register = comptime @intToEnum(RegisterMask, source_field.value);

            const ld_indirecthl_reg_opcode = InstructionMask.Load_IndirectHL_Register | @as(u8, @enumToInt(source_register));

            if (current_opcode == ld_indirecthl_reg_opcode) {
                const source_fn = comptime source_reg_fn(source_register);

                self.LD(dest_indirect_hl, source_fn);
                executed = true;
            }
        }

        if (!executed) {
            std.debug.panic("Opcode 0x0{x} not implemented!\n", .{current_opcode});
        }

        if (Timings[current_opcode].len == 0) {
            std.debug.panic("Opcode 0x0{x} does not have timing!\n", .{current_opcode});
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

    fn dest_reg_fn(comptime register: RegisterMask) fn (self: *Self, data: u16) void {
        return switch (register) {
            .A => return dest_reg_A,
            .B => return dest_reg_B,
            .C => return dest_reg_C,
            .D => return dest_reg_D,
            .E => return dest_reg_E,
            .H => return dest_reg_H,
            .L => return dest_reg_L,
        };
    }

    fn source_reg_fn(comptime register: RegisterMask) fn (self: *Self) ?u16 {
        return switch (register) {
            .A => return source_reg_A,
            .B => return source_reg_B,
            .C => return source_reg_C,
            .D => return source_reg_D,
            .E => return source_reg_E,
            .H => return source_reg_H,
            .L => return source_reg_L,
        };
    }

    inline fn dest_reg_A(self: *Self, data: u16) void {
        self.registers.main.af.pair.A = @truncate(u8, data);
    }

    inline fn source_reg_A(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.af.pair.A;
        }

        return null;
    }

    inline fn dest_reg_F(self: *Self, data: u16) void {
        self.registers.main.af.pair.F = @truncate(u8, data);
    }

    inline fn source_reg_F(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.af.pair.F;
        }

        return null;
    }

    inline fn dest_reg_B(self: *Self, data: u16) void {
        self.registers.main.bc.pair.B = @truncate(u8, data);
    }

    inline fn source_reg_B(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.bc.pair.B;
        }

        return null;
    }

    inline fn dest_reg_C(self: *Self, data: u16) void {
        self.registers.main.bc.pair.C = @truncate(u8, data);
    }

    inline fn source_reg_C(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.bc.pair.C;
        }

        return null;
    }

    inline fn dest_reg_D(self: *Self, data: u16) void {
        self.registers.main.de.pair.D = @truncate(u8, data);
    }

    inline fn source_reg_D(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.de.pair.D;
        }

        return null;
    }

    inline fn dest_reg_E(self: *Self, data: u16) void {
        self.registers.main.de.pair.E = @truncate(u8, data);
    }

    inline fn source_reg_E(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.de.pair.E;
        }

        return null;
    }

    inline fn dest_reg_H(self: *Self, data: u16) void {
        self.registers.main.hl.pair.H = @truncate(u8, data);
    }

    inline fn source_reg_H(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.hl.pair.H;
        }

        return null;
    }

    inline fn dest_reg_L(self: *Self, data: u16) void {
        self.registers.main.hl.pair.L = @truncate(u8, data);
    }

    inline fn source_reg_L(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 3) {
            return self.registers.main.hl.pair.L;
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

    inline fn dest_indirect_hl(self: *Self, data: u16) void {
        if (self.current_m == 0 and self.current_t == 3) {
            const pointer = self.registers.main.hl.raw;
            self.bus.write8(self.bus, pointer, @truncate(u8, data));
        }
    }

    inline fn source_indirect_hl(self: *Self) ?u16 {
        if (self.current_m == 0 and self.current_t == 2) {
            self.temp_pointer = self.registers.main.hl.raw;
        } else if (self.current_m == 1 and self.current_t == 3) {
            const result: u16 = self.bus.read8(self.bus, self.temp_pointer);
            return result;
        }

        return null;
    }
};
