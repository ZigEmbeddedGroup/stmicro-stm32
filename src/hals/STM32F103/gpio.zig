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
    reserved,
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

pub const Pin = packed struct(u8) {
    number: u4,
    port: u3,
    padding: u1,

    // this could probably be a type
    // according to the manual CRL and CRH registers have to be accessed as 32-bit words
    // We could try accessing them as 4-bit words to acces only the needed bits per pin
    // But it will probably not work
    pub const ConfigReg = u32;

    fn get_config_reg(gpio: Pin) *volatile ConfigReg {
        const port = gpio.get_port();
        return if (gpio.number <= 7)
            &port.CRL.raw
        else
            &port.CRH.raw;
    }

    pub fn get_port(gpio: Pin) Port {
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

    pub inline fn set_direction(gpio: Pin, direction: Direction, mode: ?Mode, speed: ?Speed) void {
        switch (direction) {
            .in => gpio.set_in_mode(mode.?.input),
            .out => gpio.set_out_mode(mode.?.output, speed),
        }
    }

    pub inline fn set_in_mode(gpio: Pin, mode: ?InputMode) void {
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

    pub inline fn set_out_mode(gpio: Pin, mode: ?OutputMode, speed: ?Speed) void {
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
