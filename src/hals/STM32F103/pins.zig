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
        // function: Function = .SIO,
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
                        // if (0 == function_table[@intFromEnum(pin_config.function)][gpio_num])
                        //     @compileError(comptimePrint("{s} {s} cannot be configured for {}", .{ port_decl.name, field.name, pin_config.function }));

                        // if (pin_config.function == .SIO) {
                        switch (pin_config.get_mode()) {
                            .input => input_gpios |= 1 << gpio_num,
                            .output => output_gpios |= 1 << gpio_num,
                        }
                        // }

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
