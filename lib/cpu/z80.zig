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

    pub const Read8Fn = fn (address: u16) u8;
    pub const Write8Fn = fn (address: u16, data: u8) void;
};

pub const InterruptMode = packed enum(u2) {
    Mode0,
    Mode1,
    Mode2,
};

const Timings = [_][]const u8{
    &[_]u8{4}, // 0x00 - NOP
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
    bus: Z80Bus = undefined,

    const Self = @This();

    pub fn init(bus: Z80Bus) Self {
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
    }

    // BUSREQ ?

    pub fn tick(self: *Self) void {
        if (self.current_t == 0 and self.current_m == 0) {
            // Read instruction from memory
            self.current_instruction_storage[0] = self.bus.read8(self.registers.pc);
            self.current_instruction = self.current_instruction_storage[0..1];

            self.current_cycles = Timings[self.current_instruction[0]];
            self.current_m = 0;
            self.current_t = self.current_cycles[self.current_m];
            self.registers.pc += 1;

            switch (self.current_instruction[0]) {
                0x00 => {
                    // NOP
                },
                else => {
                    std.debug.panic("Opcode 0x{x} not implemented!\n", .{self.current_instruction[0]});
                },
            }
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
            self.total_t_cycles += 1;
        }
        // When halted, do NOP
    }
};
