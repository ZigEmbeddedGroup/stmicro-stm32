const std = @import("std");
const assert = std.debug.assert;
const comptimePrint = std.fmt.comptimePrint;
const StructField = std.builtin.Type.StructField;

const microzig = @import("microzig");

const RCC = microzig.chip.peripherals.RCC;

const gpio = @import("gpio.zig");
// const pwm = @import("pwm.zig");
// const adc = @import("adc.zig");
// const resets = @import("resets.zig");

pub const Port = enum {
    GPIOA,
    GPIOB,
    GPIOC,
    GPIOD,
    GPIOE,
    GPIOF,
    GPIOG,
};

pub const Pin = enum {
    PIN0,
    PIN1,
    PIN2,
    PIN3,
    PIN4,
    PIN5,
    PIN6,
    PIN7,
    PIN8,
    PIN9,
    PIN10,
    PIN11,
    PIN12,
    PIN13,
    PIN14,
    PIN15,
    pub const Configuration = struct {
        name: ?[]const u8 = null,
        function: Function = .SIO,
        mode: ?gpio.Mode = null,
        speed: ?gpio.Speed = null,
        pull: ?gpio.Pull = null,
        // input/output enable
        // schmitt trigger
        // hysteresis

        pub fn get_mode(comptime config: Configuration) gpio.Mode {
            return if (config.mode) |mode|
                mode
                // else if (comptime config.function.is_pwm())
                //     .out
                // else if (comptime config.function.is_uart_tx())
                //     .out
                // else if (comptime config.function.is_uart_rx())
                //     .in
                // else if (comptime config.function.is_adc())
                //     .in
            else
                @panic("TODO");
        }
    };
};

pub const Function = enum {
    pub fn is_pwm(function: Function) bool {
        return switch (function) {
            .PWM0_A,
            .PWM0_B,
            .PWM1_A,
            .PWM1_B,
            .PWM2_A,
            .PWM2_B,
            .PWM3_A,
            .PWM3_B,
            .PWM4_A,
            .PWM4_B,
            .PWM5_A,
            .PWM5_B,
            .PWM6_A,
            .PWM6_B,
            .PWM7_A,
            .PWM7_B,
            => true,
            else => false,
        };
    }

    pub fn is_uart_tx(function: Function) bool {
        return switch (function) {
            .UART0_TX,
            .UART1_TX,
            => true,
            else => false,
        };
    }

    pub fn is_uart_rx(function: Function) bool {
        return switch (function) {
            .UART0_RX,
            .UART1_RX,
            => true,
            else => false,
        };
    }

    pub fn pwm_slice(comptime function: Function) u32 {
        return switch (function) {
            .PWM0_A, .PWM0_B => 0,
            .PWM1_A, .PWM1_B => 1,
            .PWM2_A, .PWM2_B => 2,
            .PWM3_A, .PWM3_B => 3,
            .PWM4_A, .PWM4_B => 4,
            .PWM5_A, .PWM5_B => 5,
            .PWM6_A, .PWM6_B => 6,
            .PWM7_A, .PWM7_B => 7,
            else => @compileError("not pwm"),
        };
    }

    pub fn is_adc(function: Function) bool {
        return switch (function) {
            .ADC0,
            .ADC1,
            .ADC2,
            .ADC3,
            => true,
            else => false,
        };
    }

    // pub fn pwm_channel(comptime function: Function) pwm.Channel {
    //     return switch (function) {
    //         .PWM0_A,
    //         .PWM1_A,
    //         .PWM2_A,
    //         .PWM3_A,
    //         .PWM4_A,
    //         .PWM5_A,
    //         .PWM6_A,
    //         .PWM7_A,
    //         => .a,
    //         .PWM0_B,
    //         .PWM1_B,
    //         .PWM2_B,
    //         .PWM3_B,
    //         .PWM4_B,
    //         .PWM5_B,
    //         .PWM6_B,
    //         .PWM7_B,
    //         => .b,
    //         else => @compileError("not pwm"),
    //     };
    // }
};

fn all() [30]u1 {
    var ret: [30]u1 = undefined;
    for (&ret) |*elem|
        elem.* = 1;

    return ret;
}

fn list(gpio_list: []const u5) [30]u1 {
    var ret = std.mem.zeroes([30]u1);
    for (gpio_list) |num|
        ret[num] = 1;

    return ret;
}

fn single(gpio_num: u5) [30]u1 {
    var ret = std.mem.zeroes([30]u1);
    ret[gpio_num] = 1;
    return ret;
}

const function_table = [@typeInfo(Function).Enum.fields.len][30]u1{
    all(), // SIO
    all(), // PIO0
    all(), // PIO1
    list(&.{ 0, 4, 16, 20 }), // SPI0_RX
    list(&.{ 1, 5, 17, 21 }), // SPI0_CSn
    list(&.{ 2, 6, 18, 22 }), // SPI0_SCK
    list(&.{ 3, 7, 19, 23 }), // SPI0_TX
    list(&.{ 8, 12, 24, 28 }), // SPI1_RX
    list(&.{ 9, 13, 25, 29 }), // SPI1_CSn
    list(&.{ 10, 14, 26 }), // SPI1_SCK
    list(&.{ 11, 15, 27 }), // SPI1_TX
    list(&.{ 0, 11, 16, 28 }), // UART0_TX
    list(&.{ 1, 13, 17, 29 }), // UART0_RX
    list(&.{ 2, 14, 18 }), // UART0_CTS
    list(&.{ 3, 15, 19 }), // UART0_RTS
    list(&.{ 4, 8, 20, 24 }), // UART1_TX
    list(&.{ 5, 9, 21, 25 }), // UART1_RX
    list(&.{ 6, 10, 22, 26 }), // UART1_CTS
    list(&.{ 7, 11, 23, 27 }), // UART1_RTS
    list(&.{ 0, 4, 8, 12, 16, 20, 24, 28 }), // I2C0_SDA
    list(&.{ 1, 5, 9, 13, 17, 21, 25, 29 }), // I2C0_SCL
    list(&.{ 2, 6, 10, 14, 18, 22, 26 }), // I2C1_SDA
    list(&.{ 3, 7, 11, 15, 19, 23, 27 }), // I2C1_SCL
    list(&.{ 0, 16 }), // PWM0_A
    list(&.{ 1, 17 }), // PWM0_B
    list(&.{ 2, 18 }), // PWM1_A
    list(&.{ 3, 19 }), // PWM1_B
    list(&.{ 4, 20 }), // PWM2_A
    list(&.{ 5, 21 }), // PWM2_B
    list(&.{ 6, 22 }), // PWM3_A
    list(&.{ 7, 23 }), // PWM3_B
    list(&.{ 8, 24 }), // PWM4_A
    list(&.{ 9, 25 }), // PWM4_B
    list(&.{ 10, 26 }), // PWM5_A
    list(&.{ 11, 27 }), // PWM5_B
    list(&.{ 12, 28 }), // PWM6_A
    list(&.{ 13, 29 }), // PWM6_B
    single(14), // PWM7_A
    single(15), // PWM7_B
    single(20), // CLOCK_GPIN0
    single(22), // CLOCK_GPIN1
    single(21), // CLOCK_GPOUT0
    single(23), // CLOCK_GPOUT1
    single(24), // CLOCK_GPOUT2
    single(25), // CLOCK_GPOUT3
    list(&.{ 0, 3, 6, 9, 12, 15, 18, 21, 24, 27 }), // USB_OVCUR_DET
    list(&.{ 1, 4, 7, 10, 13, 16, 19, 22, 25, 28 }), // USB_VBUS_DET
    list(&.{ 2, 5, 8, 11, 14, 17, 20, 23, 26, 29 }), // USB_VBUS_EN
    single(26), // ADC0
    single(27), // ADC1
    single(28), // ADC2
    single(29), // ADC3
};

pub fn GPIO(comptime port: u3, comptime num: u4, comptime mode: gpio.Mode) type {
    return switch (mode) {
        .input => struct {
            const pin = gpio.Pin.init(port, num);

            pub inline fn read(self: @This()) u1 {
                _ = self;
                return pin.read();
            }
        },
        .output => struct {
            const pin = gpio.Pin.init(port, num);

            pub inline fn put(self: @This(), value: u1) void {
                _ = self;
                pin.put(value);
            }

            pub inline fn toggle(self: @This()) void {
                _ = self;
                pin.toggle();
            }
        },
    };
}

pub fn Pins(comptime config: GlobalConfiguration) type {
    comptime {
        var fields: []const StructField = &.{};
        for (@typeInfo(GlobalConfiguration).Struct.decls) |port_decl| {
            const port = @field(config, port_decl.name);

            for (@typeInfo(port).Structs.fields) |field| {
                if (@field(port, field.name)) |pin_config| {
                    var pin_field = StructField{
                        .is_comptime = false,
                        .default_value = null,

                        // initialized below:
                        .name = undefined,
                        .type = undefined,
                        .alignment = undefined,
                    };

                    if (pin_config.function == .SIO) {
                        pin_field.name = pin_config.name orelse field.name;
                        pin_field.type = GPIO(@intFromEnum(@field(Port, port_decl.name)), @intFromEnum(@field(Pin, field.name)), pin_config.mode orelse .input);
                    } else if (pin_config.function.is_pwm()) {
                        // pin_field.name = pin_config.name orelse @tagName(pin_config.function);
                        // pin_field.type = pwm.Pwm(pin_config.function.pwm_slice(), pin_config.function.pwm_channel());
                    } else if (pin_config.function.is_adc()) {
                        // pin_field.name = pin_config.name orelse @tagName(pin_config.function);
                        // pin_field.type = adc.Input;
                        // pin_field.default_value = @as(?*const anyopaque, @ptrCast(switch (pin_config.function) {
                        //     .ADC0 => &adc.Input.ain0,
                        //     .ADC1 => &adc.Input.ain1,
                        //     .ADC2 => &adc.Input.ain2,
                        //     .ADC3 => &adc.Input.ain3,
                        //     else => unreachable,
                        // }));
                    } else {
                        continue;
                    }

                    // if (pin_field.default_value == null) {
                    //     if (@sizeOf(pin_field.field_type) > 0) {
                    //         pin_field.default_value = @ptrCast(?*const anyopaque, &pin_field.field_type{});
                    //     } else {
                    //         const Struct = struct {
                    //             magic_field: pin_field.field_type = .{},
                    //         };
                    //         pin_field.default_value = @typeInfo(Struct).Struct.fields[0].default_value;
                    //     }
                    // }

                    pin_field.alignment = @alignOf(field.type);

                    fields = fields ++ &[_]StructField{pin_field};
                }
            }
        }

        return @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &.{},
            },
        });
    }
}

pub const GlobalConfiguration = struct {
    pub const GPIOA = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    pub const GPIOB = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    pub const GPIOC = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    pub const GPIOD = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    pub const GPIOF = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    pub const GPIOG = struct {
        PIN0: ?Pin.Configuration = null,
        PIN1: ?Pin.Configuration = null,
        PIN2: ?Pin.Configuration = null,
        PIN3: ?Pin.Configuration = null,
        PIN4: ?Pin.Configuration = null,
        PIN5: ?Pin.Configuration = null,
        PIN6: ?Pin.Configuration = null,
        PIN7: ?Pin.Configuration = null,
        PIN8: ?Pin.Configuration = null,
        PIN9: ?Pin.Configuration = null,
        PIN10: ?Pin.Configuration = null,
        PIN11: ?Pin.Configuration = null,
        PIN12: ?Pin.Configuration = null,
        PIN13: ?Pin.Configuration = null,
        PIN14: ?Pin.Configuration = null,
        PIN15: ?Pin.Configuration = null,
    };

    comptime {
        const pin_field_count = @typeInfo(Pin).Enum.fields.len;
        inline for (@typeInfo(GlobalConfiguration).Struct.decls) |decl| {
            const port = @field(GlobalConfiguration, decl.name);
            const config_field_count = @typeInfo(port).Struct.fields.len;
            if (pin_field_count != config_field_count)
                @compileError(comptimePrint("{s} {} {}", .{ decl.name, pin_field_count, config_field_count }));
        }
    }

    pub fn apply(comptime config: GlobalConfiguration) Pins(config) {
        inline for (@typeInfo(GlobalConfiguration).Struct.decls) |port_decl| {
            const port = @field(GlobalConfiguration, port_decl.name);
            comptime var input_gpios: u16 = 0;
            comptime var output_gpios: u16 = 0;
            // comptime var has_adc = false;
            // comptime var has_pwm = false;
            comptime {
                inline for (@typeInfo(port).Struct.fields) |field|
                    if (@field(config, field.name)) |pin_config| {
                        const gpio_num = @intFromEnum(@field(Pin, field.name));
                        if (0 == function_table[@intFromEnum(pin_config.function)][gpio_num])
                            @compileError(comptimePrint("{s} {s} cannot be configured for {}", .{ port_decl.name, field.name, pin_config.function }));

                        if (pin_config.function == .SIO) {
                            switch (pin_config.get_mode()) {
                                .input => input_gpios |= 1 << gpio_num,
                                .output => output_gpios |= 1 << gpio_num,
                            }
                        }

                        // if (pin_config.function.is_adc()) {
                        //     has_adc = true;
                        // }
                        // if (pin_config.function.is_pwm()) {
                        //     has_pwm = true;
                        // }
                    };
            }

            // TODO: ensure only one instance of an input function exists
            const used_gpios = comptime input_gpios | output_gpios;

            if (used_gpios != 0) {
                const bit = @as(u32, 1 << @intFromEnum(@field(Port, port_decl.name)));
                RCC.APB2ENR |= bit;
                // Delay after setting
                _ = RCC.APB2ENR & bit;
            }

            // inline for (@typeInfo(port).Struct.fields) |field| {
            //     if (@field(config, field.name)) |pin_config| {
            //         const pin = gpio.Pin.init(@intFromEnum(@field(Port, port_decl.name)), @intFromEnum(@field(Pin, field.name)));
            //         const func = pin_config.function;
            //
            //         // xip = 0,
            //         // spi,
            //         // uart,
            //         // i2c,
            //         // pio0,
            //         // pio1,
            //         // gpck,
            //         // usb,
            //         // @"null" = 0x1f,
            //
            //         if (func == .SIO) {
            //             pin.set_function(.sio);
            //         } else if (comptime func.is_pwm()) {
            //             pin.set_function(.pwm);
            //         } else if (comptime func.is_adc()) {
            //             pin.set_function(.null);
            //         } else if (comptime func.is_uart_tx() or func.is_uart_rx()) {
            //             pin.set_function(.uart);
            //         } else {
            //             @compileError(std.fmt.comptimePrint("Unimplemented pin function. Please implement setting pin function {s} for GPIO {}", .{
            //                 @tagName(func),
            //                 @intFromEnum(pin),
            //             }));
            //         }
            //     }
            // }

            if (input_gpios != 0) {
                inline for (@typeInfo(port).Struct.fields) |field|
                    if (@field(config, field.name)) |pin_config| {
                        const pin = gpio.Pin.init(@intFromEnum(@field(Port, port_decl.name)), @intFromEnum(@field(Pin, field.name)));
                        const pull = pin_config.pull orelse continue;
                        if (comptime pin_config.get_mode() != .input)
                            @compileError("Only input pins can have pull up/down enabled");

                        pin.set_pull(pull);
                    };
            }

            // if (has_adc) {
            //     adc.init();
            // }

        }

        // fields in the Pins(config) type should be zero sized, so we just
        // default build them all (wasn't sure how to do that cleanly in
        // `Pins()`
        var ret: Pins(config) = undefined;
        inline for (@typeInfo(Pins(config)).Struct.fields) |field| {
            if (field.default_value) |default_value| {
                @field(ret, field.name) = @as(*const field.field_type, @ptrCast(default_value)).*;
            } else {
                @field(ret, field.name) = .{};
            }
        }
        return ret;
        // validate selected function
    }
};
