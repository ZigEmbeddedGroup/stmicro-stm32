const std = @import("std");
const assert = std.debug.assert;

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

const GPIOA = peripherals.GPIOA;
const GPIOB = peripherals.GPIOB;
const GPIOC = peripherals.GPIOC;
const GPIOD = peripherals.GPIOD;
const GPIOE = peripherals.GPIOE;
const GPIOF = peripherals.GPIOF;
const GPIOG = peripherals.GPIOG;

const Port = @TypeOf(GPIOA);

// const SIO = peripherals.SIO;
// const PADS_BANK0 = peripherals.PADS_BANK0;
// const IO_BANK0 = peripherals.IO_BANK0;

const log = std.log.scoped(.gpio);


pub const Direction = enum(u1) {
    in,
    out,
};

pub const Mode = union {
    input: InputMode,
    output: OutputMode,
};

pub const InputMode = enum(u2) {
    analog,
    floating,
    pull,
    reserved,
};

pub const OutputMode = enum(u2) {
    general_purpose_push_pull,
    general_purpose_open_drain,
    alternate_function_push_pull,
    alternate_function_open_drain,
};

pub const Speed = enum(u2) {
    reserver,
    max_10MHz,
    max_2MHz,
    max_50MHz,
};

pub const IrqLevel = enum(u2) {
    low,
    high,
    fall,
    rise,
};

pub const IrqCallback = fn (gpio: u32, events: u32) callconv(.C) void;

pub const Override = enum {
    normal,
    invert,
    low,
    high,
};

pub const SlewRate = enum {
    slow,
    fast,
};

pub const DriveStrength = enum {
    @"2mA",
    @"4mA",
    @"8mA",
    @"12mA",
};

pub const Enabled = enum {
    disabled,
    enabled,
};

pub const Pull = enum {
    floating,
    up,
    down,
};

pub fn num(n: u4) Pin {
    return @as(Pin, @enumFromInt(n));
}

pub fn mask(m: u16) Mask {
    return @as(Mask, @enumFromInt(m));
}

pub const Mask = enum(u16) {
    _,

    pub fn set_function(self: Mask, function: Function) void {
        const raw_mask = @intFromEnum(self);
        for (0..@bitSizeOf(Mask)) |i| {
            const bit = @as(u5, @intCast(i));
            if (0 != raw_mask & (@as(u32, 1) << bit))
                num(bit).set_function(function);
        }
    }

    pub fn set_direction(self: Mask, direction: Direction) void {
        const raw_mask = @intFromEnum(self);
        switch (direction) {
            .out => SIO.GPIO_OE_SET.raw = raw_mask,
            .in => SIO.GPIO_OE_CLR.raw = raw_mask,
        }
    }

    pub fn set_pull(self: Mask, pull: ?Pull) void {
        const raw_mask = @intFromEnum(self);
        for (0..@bitSizeOf(Mask)) |i| {
            const bit = @as(u5, @intCast(i));
            if (0 != raw_mask & (@as(u32, 1) << bit))
                num(bit).set_pull(pull);
        }
    }

    pub fn put(self: Mask, value: u32) void {
        SIO.GPIO_OUT_XOR.raw = (SIO.GPIO_OUT.raw ^ value) & @intFromEnum(self);
    }

    pub fn read(self: Mask) u32 {
        return SIO.GPIO_IN.raw & @intFromEnum(self);
    }
};

pub const Pin1 = packed struct(u8) {
    number: u4,
    port: u3,
    padding: u1,

    // this could probably be a type
    pub const ConfigReg = u32;

    fn get_config_reg(gpio: Pin1) *volatile ConfigReg {
        const port = gpio.get_port();
        return if (gpio.number <= 7)
            &port.CRL.raw
        else
            &port.CRH.raw;
    }

    pub fn get_port(gpio: Pin1) Port {
        switch (gpio.port) {
            0 => GPIOA,
            1 => GPIOB,
            2 => GPIOC,
            3 => GPIOD,
            4 => GPIOE,
            5 => GPIOF,
            6 => GPIOG,
            7 => @panic("The STM32 only has ports 0..6 (A..G)"),
        }
    }

    pub inline fn set_direction(gpio: Pin1, direction: Direction, mode: ?Mode, speed: ?Speed) void {
        switch (direction) {
            .in => gpio.set_in_mode(mode.?.input),
            .out => gpio.set_out_mode(mode.?.output, speed),
        }
    }

    pub inline fn set_in_mode(gpio: Pin1, mode: ?InputMode) void {
        // according to the manual CRL and CRH registers have to be accessed as 32-bit words
        // We could try accessing them as 4-bit words to acces only the needed bits per pin
        // But it will probably not work
        const config_reg = gpio.get_config_reg();
        var ioconfig = 0;
        if (mode) |m| {
            ioconfig = @intFromEnum(m) << 2;
        } else {
            ioconfig = @intFromEnum(InputMode.floating) << 2;
        }
        const offset = if (gpio.number <= 7) 
                            gpio.number << 2 
                       else 
                           (gpio.number - 8) << 2;

        const state = config_reg;
        const clear_msk: u32 = ~(0x15 << offset);
        config_reg = (state & clear_msk) | ioconfig;
    }

    pub inline fn set_out_mode(gpio: Pin1, mode: ?OutputMode, speed: ?Speed) void {
        const config_reg = gpio.get_config_reg();
        var ioconfig = 0;
        if (mode) |m| {
            ioconfig = @intFromEnum(m) << 2;
        } else {
            ioconfig = @intFromEnum(OutputMode.general_purpose_push_pull) << 2;
        }

        var speedconfig = 0x2;
        if (speed) |s| {
            speedconfig = @intFromEnum(s);
        }

        ioconfig += speedconfig;

        const offset = if (gpio.number <= 7) 
                            gpio.number << 2 
                       else 
                           (gpio.number - 8) << 2;

        const state = config_reg;
        const clear_msk: u32 = ~(0x15 << offset);
        config_reg = (state & clear_msk) | ioconfig;
    }

};

pub const Pin = enum(u4) {
    _,

    pub const Regs = struct {
        status: @TypeOf(IO_BANK0.GPIO0_STATUS),
        ctrl: microzig.mmio.Mmio(packed struct(u32) {
            FUNCSEL: packed union {
                raw: u5,
                value: Function,
            },
            reserved8: u3,
            OUTOVER: packed union {
                raw: u2,
                value: Override,
            },
            reserved12: u2,
            OEOVER: packed union {
                raw: u2,
                value: Override,
            },
            reserved16: u2,
            INOVER: packed union {
                raw: u2,
                value: Override,
            },
            reserved28: u10,
            IRQOVER: packed union {
                raw: u2,
                value: Override,
            },
            padding: u2,
        }),
    };

    pub const PadsReg = @TypeOf(PADS_BANK0.GPIO0);

    fn get_regs(gpio: Pin) *volatile Regs {
        const regs = @as(*volatile [30]Regs, @ptrCast(&IO_BANK0.GPIO0_STATUS));
        return &regs[@intFromEnum(gpio)];
    }

    fn get_pads_reg(gpio: Pin) *volatile PadsReg {
        const regs = @as(*volatile [30]PadsReg, @ptrCast(&PADS_BANK0.GPIO0));
        return &regs[@intFromEnum(gpio)];
    }

    pub fn mask(gpio: Pin) u32 {
        return @as(u32, 1) << @intFromEnum(gpio);
    }

    pub inline fn set_pull(gpio: Pin, pull: ?Pull) void {
        const pads_reg = gpio.get_pads_reg();

        if (pull == null) {
            pads_reg.modify(.{ .PUE = 0, .PDE = 0 });
        } else switch (pull.?) {
            .up => pads_reg.modify(.{ .PUE = 1, .PDE = 0 }),
            .down => pads_reg.modify(.{ .PUE = 0, .PDE = 1 }),
        }
    }

    pub inline fn set_direction(gpio: Pin, direction: Direction) void {
        switch (direction) {
            .in => SIO.GPIO_OE_CLR.raw = gpio.mask(),
            .out => SIO.GPIO_OE_SET.raw = gpio.mask(),
        }
    }

    /// Drive a single GPIO high/low
    pub inline fn put(gpio: Pin, value: u1) void {
        switch (value) {
            0 => SIO.GPIO_OUT_CLR.raw = gpio.mask(),
            1 => SIO.GPIO_OUT_SET.raw = gpio.mask(),
        }
    }

    pub inline fn toggle(gpio: Pin) void {
        SIO.GPIO_OUT_XOR.raw = gpio.mask();
    }

    pub inline fn read(gpio: Pin) u1 {
        return if ((SIO.GPIO_IN.raw & gpio.mask()) != 0)
            1
        else
            0;
    }

    pub inline fn set_input_enabled(pin: Pin, enabled: bool) void {
        const pads_reg = pin.get_pads_reg();
        pads_reg.modify(.{ .IE = @intFromBool(enabled) });
    }

    pub inline fn set_function(gpio: Pin, function: Function) void {
        const pads_reg = gpio.get_pads_reg();
        pads_reg.modify(.{
            .IE = 1,
            .OD = 0,
        });

        const regs = gpio.get_regs();
        regs.ctrl.modify(.{
            .FUNCSEL = .{ .value = function },
            .OUTOVER = .{ .value = .normal },
            .INOVER = .{ .value = .normal },
            .IRQOVER = .{ .value = .normal },
            .OEOVER = .{ .value = .normal },

            .reserved8 = 0,
            .reserved12 = 0,
            .reserved16 = 0,
            .reserved28 = 0,
            .padding = 0,
        });
    }
};
