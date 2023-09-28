const std = @import("std");

// const pll = @import("pll.zig");
const assert = std.debug.assert;
const comptimePrint = std.fmt.comptimePrint;

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;

pub const Source = enum {
    HSI,
    HSE,
    PLL,
    LSE,
    LSI,
};

pub const SysConfig = struct {
    source: Source,
    freq: u32,
};

pub const GlobalConfiguration = struct {
    sys: ?SysConfig = null,
    ahb_freq: ?u32 = null,
    apb1_freq: ?u32 = null,
    apb2_freq: ?u32 = null,

    pub fn apply(comptime config: GlobalConfiguration) void {
        const sys = config.sys orelse .{ .source = .HSI, .freq = 8_000_000 };
        comptime {
            if (sys.freq > 72_000_000) {
                @compileError(comptimePrint("Sys frequency is too high. Max frequency: 72 MHz, got {}", sys.freq / 1_000_000));
            }

            switch (sys.source) {
                .LSE, .LSI => {
                    @compileError("Invalid source for sys clock");
                },
                else => {},
            }
        }

        const ahb_freq: u32 = ahb_blk: {
            if (config.ahb_freq) |f| {
                const divisor = sys.freq / f;
                // for some reason 32 is not a valid prescaler for AHB
                if (!isValidPrescaler(divisor, 512) or divisor == 32) {
                    @compileError(comptimePrint("AHB frequency is too high. Max frequency: {} Hz, got {}", sys.freq / 512, f));
                }
                break :ahb_blk f;
            }
            sys.freq;
        };

        const apb1_freq: u32 = apb1_blk: {
            if (config.apb1_freq) |f| {
                const divisor = ahb_freq / f;
                if (!isValidPrescaler(divisor, 16)) {
                    @compileError(comptimePrint("Invalid frequency for APB1: {}", f));
                }
                break :apb1_blk f;
            }
            ahb_freq;
        };

        const apb2_freq: u32 = apb1_blk: {
            if (config.apb2_freq) |f| {
                const divisor = ahb_freq / f;
                if (!isValidPrescaler(divisor, 16)) {
                    @compileError(comptimePrint("Invalid frequency for APB1: {}", f));
                }
                break :apb1_blk f;
            }
            ahb_freq;
        };

        comptime {
            if (apb1_freq > 36_000_000) {
                @compileError(comptimePrint("APB1 frequency is too high. Max frequency: 36 MHz, got {} MHz", apb1_freq / 1_000_000));
            }

            if (apb2_freq > 72_000_000) {
                @compileError(comptimePrint("APB2 frequency is too high. Max frequency: 72 MHz, got {} MHz", apb2_freq / 1_000_000));
            }
        }

        switch (sys.source) {
            .HSI => {
                // HSI is enabled by default
                while (RCC.CR.read().HSIRDY != 1) {}
            },
            .HSE => {
                RCC.CR.modify(.{ .HSEON = 1 });
                while (RCC.CR.read().HSERDY != 1) {}
            },
            .PLL => {},
            else => {},
        }

        // Set the highest APBx dividers in order to ensure that we do not go through
        // a non-spec phase whatever we decrease or increase HCLK.
        RCC.CFGR.modify(.{
            .PPRE1 = 0b111,
            .PPRE2 = 0b111,
        });

        const hpre = sys.freq / ahb_freq;
        RCC.CFGR.modify(.{ .HPRE = getHPREdiv(hpre) });

        const source_num = @as(u2, @intFromEnum(sys.source));
        RCC.CFGR.modify(.{ .SW = source_num });
        while (RCC.CFGR.read().SWS != source_num) {}

        const ppre1 = ahb_freq / apb1_freq;
        const ppre2 = ahb_freq / apb2_freq;
        RCC.CFGR.modify(.{
            .PPRE1 = getAPPREdiv(ppre1),
            .PPRE2 = getAPPREdiv(ppre2),
        });
    }
};

fn isValidPrescaler(comptime d: u32, comptime max: u8) bool {
    return d <= max and std.math.isPowerOfTwo(d);
}

fn getHPREdiv(d: u32) u4 {
    return switch (d) {
        1 => 0b0000,
        2 => 0b1000,
        4 => 0b1001,
        8 => 0b1011,
        16 => 0b1011,
        64 => 0b1100,
        128 => 0b1101,
        256 => 0b1101,
        512 => 0b1111,
        else => 0b0000,
    };
}

fn getAPPREdiv(d: u32) u3 {
    return switch (d) {
        1 => 0b000,
        2 => 0b100,
        4 => 0b101,
        8 => 0b110,
        16 => 0b111,
        else => 0b000,
    };
}
