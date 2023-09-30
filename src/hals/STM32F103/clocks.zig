const std = @import("std");

// const pll = @import("pll.zig");
const assert = std.debug.assert;
const comptimePrint = std.fmt.comptimePrint;

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;
const FLASH = peripherals.FLASH;

const MHz = 1_000_000;

pub const SysConfig = struct {
    pub const Source = enum {
        HSI,
        HSE,
        PLL,
    };

    source: Source,
    freq: u32,
};

pub const PLLConfig = struct {
    pub const Source = enum {
        HSI_DIV_2,
        HSE,
        HSE_DIV_2,
    };

    source: Source,
    freq: u32,
};

pub const GlobalConfiguration = struct {
    sys: ?SysConfig = null,
    hsi_trim: ?u5 = null,
    // frequency of external oscillator. Usually 8 MHz
    hse_freq: u32 = 8 * MHz,
    pll: ?PLLConfig = null,
    ahb_freq: ?u32 = null,
    apb1_freq: ?u32 = null,
    apb2_freq: ?u32 = null,

    pub fn apply(comptime config: GlobalConfiguration) void {
        const sys = config.sys orelse .{ .source = .HSI, .freq = 8 * MHz };

        comptime {
            if (sys.freq > 72 * MHz) {
                @compileError(comptimePrint("Sys frequency is too high. Max frequency: 72 MHz, got {} MHz", .{sys.freq / MHz}));
            }

            if (config.hse_freq < 4 * MHz or config.hse_freq > 16 * MHz) {
                @compileError(comptimePrint("Invalid HSE oscillator: {}. Valid range is from 4 MHz to 16 MHz", .{config.hse_freq / MHz}));
            }

            if (config.pll) |pll| {
                if (pll.freq > 72 * MHz) {
                    @compileError(comptimePrint("PLL frequency is too high. Max frequency: 72 MHz, got {} MHz", .{pll.freq / MHz}));
                }
            }

            const source = @as(SysConfig.Source, sys.source);
            switch (source) {
                .HSI => {
                    if (sys.freq != 8 * MHz) {
                        @compileError(comptimePrint("Incompatible sys frequency {} MHz with HSI source 8 MHz", .{sys.freq / MHz}));
                    }
                },
                .HSE => {
                    if (sys.freq != config.hse_freq) {
                        @compileError(comptimePrint("Incompatible sys frequency {} MHz with HSE source {} MHz", .{ sys.freq / MHz, config.hse_freq / MHz }));
                    }
                },
                .PLL => {
                    if (config.pll) |pll| {
                        if (pll.freq != sys.freq) {
                            @compileError(comptimePrint("Incompatible sys frequency {} MHz with PLL source {} MHz", .{ sys.freq / MHz, pll.freq / MHz }));
                        }
                    } else {
                        @compileError("PLL used as sys source but not configured");
                    }
                },
            }

            if (config.ahb_freq > 72 * MHz) {
                @compileError(comptimePrint("AHB frequency is too high. Max frequency: 72 MHz, got {} MHz", .{config.ahb_freq / MHz}));
            }

            if (config.apb1_freq > 36 * MHz) {
                @compileError(comptimePrint("APB1 frequency is too high. Max frequency: 36 MHz, got {} MHz", .{config.apb1_freq / MHz}));
            }

            if (config.apb2_freq > 72 * MHz) {
                @compileError(comptimePrint("APB2 frequency is too high. Max frequency: 72 MHz, got {} MHz", .{config.apb2_freq / MHz}));
            }
        }

        const hsi_enabled = hsi_blk: {
            if (sys.source == .HSI) {
                break :hsi_blk true;
            }

            if (config.pll) |pll| {
                if (pll.source == .HSI_DIV_2) {
                    break :hsi_blk true;
                }
            }

            break :hsi_blk false;
        };

        const hse_enabled = hse_blk: {
            if (sys.source == .HSE) {
                break :hse_blk true;
            }

            if (config.pll) |pll| {
                if (pll.source == .HSE_DIV_2 or pll.source == .HSE) {
                    break :hse_blk true;
                }
            }

            break :hse_blk false;
        };

        FLASH.ACR.modify(.{ .PRFTBE = 1 });
        if (sys.freq <= 24 * MHz) {
            FLASH.ACR.modify(.{ .LATENCY = 0b000 });
        } else if (sys.freq <= 48 * MHz) {
            FLASH.ACR.modify(.{ .LATENCY = 0b001 });
        } else {
            FLASH.ACR.modify(.{ .LATENCY = 0b010 });
        }

        // NOTE: HSI has to be enabled until sys clock is changed

        if (config.hsi_trim) |trim| {
            RCC.CR.modify(.{ .HSITRIM = trim });
        }

        if (hse_enabled) {
            RCC.CR.modify(.{ .HSEON = 1 });
            while (RCC.CR.read().HSERDY != 1) {}
        } else {
            RCC.CR.modify(.{ .HSEON = 0 });
            while (RCC.CR.read().HSERDY != 0) {}
        }

        if (config.pll) |pll_config| {
            // we need to turn off the pll to configure it
            RCC.CR.modify(.{ .PLLON = 0 });
            while (RCC.CR.read().PLLRDY != 0) {}

            switch (pll_config.source) {
                .HSI_DIV_2 => {
                    const mul = pll_config.freq / (4 * MHz);
                    RCC.CFGR.modify(.{ .PLLSRC = 0, .PLLMUL = getPLLmul(mul) });
                },
                .HSE => {
                    const mul = pll_config.freq / config.hse_freq;
                    RCC.CFGR.modify(.{ .PLLSRC = 1, .PLLXTPRE = 0, .PLLMUL = getPLLmul(mul) });
                },
                .HSE_DIV_2 => {
                    const mul = pll_config.freq / (config.hse_freq / 2);
                    RCC.CFGR.modify(.{ .PLLSRC = 1, .PLLXTPRE = 1, .PLLMUL = getPLLmul(mul) });
                },
            }

            RCC.CR.modify(.{ .PLLON = 1 });
            while (RCC.CR.read().PLLRDY != 1) {}
        } else {
            RCC.CR.modify(.{ .PLLON = 0 });
            while (RCC.CR.read().PLLRDY != 0) {}
        }

        const ahb_freq: u32 = ahb_blk: {
            if (config.ahb_freq) |f| {
                comptime {
                    const divisor = sys.freq / f;
                    // for some reason 32 is not a valid prescaler for AHB
                    if (!isValidPrescaler(divisor, 512) or divisor == 32) {
                        @compileError(comptimePrint("AHB frequency is too low. Min frequency: {} Hz, got {}", .{ sys.freq / 512, f }));
                    }
                }
                break :ahb_blk f;
            }
            break :ahb_blk sys.freq;
        };

        const apb1_freq: u32 = apb1_blk: {
            if (config.apb1_freq) |f| {
                comptime {
                    const divisor = ahb_freq / f;
                    if (!isValidPrescaler(divisor, 16)) {
                        @compileError(comptimePrint("Invalid frequency for APB1: {}, {}", .{ f, divisor }));
                    }
                }
                break :apb1_blk f;
            }
            break :apb1_blk if (ahb_freq <= 36 * MHz)
                ahb_freq
            else
                36 * MHz;
        };

        const apb2_freq: u32 = apb2_blk: {
            if (config.apb2_freq) |f| {
                comptime {
                    const divisor = ahb_freq / f;
                    if (!isValidPrescaler(divisor, 16)) {
                        @compileError(comptimePrint("Invalid frequency for APB1: {}", .{f}));
                    }
                }
                break :apb2_blk f;
            }
            break :apb2_blk if (ahb_freq <= 72 * MHz)
                ahb_freq
            else
                72 * MHz;
        };

        comptime {}

        switch (sys.source) {
            .HSI => {
                while (RCC.CR.read().HSIRDY != 1) {}
            },
            .HSE => {
                while (RCC.CR.read().HSERDY != 1) {}
            },
            .PLL => {
                while (RCC.CR.read().PLLRDY != 1) {}
            },
        }

        // Set the highest APBx dividers in order to ensure that we do not go through
        // a non-spec phase whatever we decrease or increase HCLK.
        RCC.CFGR.modify(.{
            .PPRE1 = 0b111,
            .PPRE2 = 0b111,
        });

        const hpre = sys.freq / ahb_freq;
        RCC.CFGR.modify(.{ .HPRE = getHPREdiv(hpre) });

        // HACK: Ummmmmmm what?
        const source_num = @as(u2, @intFromEnum(@as(SysConfig.Source, sys.source)));
        RCC.CFGR.modify(.{ .SW = source_num });
        while (RCC.CFGR.read().SWS != source_num) {}

        const ppre1 = ahb_freq / apb1_freq;
        const ppre2 = ahb_freq / apb2_freq;
        RCC.CFGR.modify(.{
            .PPRE1 = getAPPREdiv(ppre1),
            .PPRE2 = getAPPREdiv(ppre2),
        });

        if (!hsi_enabled) {
            RCC.CR.modify(.{ .HSION = 0 });
            while (RCC.CR.read().HSIRDY != 0) {}
        }
    }
};

fn isValidPrescaler(comptime d: u32, comptime max: u8) bool {
    return d <= max and std.math.isPowerOfTwo(d);
}

fn getHPREdiv(comptime d: u32) u4 {
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
        else => 0b000,
    };
}

fn getAPPREdiv(comptime d: u32) u3 {
    return switch (d) {
        1 => 0b000,
        2 => 0b100,
        4 => 0b101,
        8 => 0b110,
        16 => 0b111,
        else => 0b000,
    };
}

fn getPLLmul(comptime m: u32) u4 {
    comptime {
        if (m < 2 or m > 16) {
            @compileError(comptimePrint("Invalid PLL mul: {}", .{m}));
        }
    }
    return @as(u4, m - 2);
}
