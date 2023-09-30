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
    hse_freq: ?u32 = null,
    ahb_freq: ?u32 = null,
    apb1_freq: ?u32 = null,
    apb2_freq: ?u32 = null,
    pll: ?PLLConfig = null,

    pub fn apply(comptime config: GlobalConfiguration) void {
        const sys = config.sys orelse .{ .source = .HSI, .freq = 8 * MHz };

        comptime var pll_config: ?PLLConfig = null;
        comptime var pll_mul = 0;

        comptime var hsi_enabled = false;
        comptime var hse_enabled = false;

        comptime var hse_freq = config.hse_freq orelse 8 * MHz;

        comptime var ahb_freq = config.ahb_freq orelse sys.freq;
        comptime var ahb_div = sys.freq / ahb_freq;

        comptime var apb1_freq = config.apb1_freq orelse if (ahb_freq <= 36 * MHz) ahb_freq else 36 * MHz;
        comptime var apb1_div = ahb_freq / apb1_freq;

        comptime var apb2_freq = config.apb2_freq orelse if (ahb_freq <= 72 * MHz) ahb_freq else 72 * MHz;
        comptime var apb2_div = ahb_freq / apb1_freq;

        // Do a comptime validation of config
        comptime {
            if (sys.freq > 72 * MHz) {
                @compileError(comptimePrint("Sys frequency is too high. Max frequency: 72 MHz, got {} MHz", .{sys.freq / MHz}));
            }

            if (hse_freq < 4 * MHz or hse_freq > 16 * MHz) {
                @compileError(comptimePrint("Invalid HSE oscillator: {}. Valid range is from 4 MHz to 16 MHz", .{hse_freq / MHz}));
            }

            if (config.pll) |pll| {
                pll_config = pll;
                if (pll.freq > 72 * MHz) {
                    @compileError(comptimePrint("PLL frequency is too high. Max frequency: 72 MHz, got {} MHz", .{pll.freq / MHz}));
                }

                var source_freq = 0;
                switch (pll.source) {
                    .HSI_DIV_2 => {
                        source_freq = 4 * MHz;
                        hsi_enabled = true;
                    },
                    .HSE_DIV_2 => {
                        source_freq = hse_freq / 2;
                        hse_enabled = true;
                    },
                    .HSE => {
                        source_freq = hse_freq;
                        hse_enabled = true;
                    },
                }

                pll_mul = pll.freq / source_freq;
                if (!isValidPLLmul(pll_mul)) {
                    @compileError(comptimePrint("Invalid PLL multiplier {}", .{pll_mul}));
                }
            }

            switch (sys.source) {
                .HSI => {
                    if (sys.freq != 8 * MHz) {
                        @compileError(comptimePrint("Incompatible sys frequency {} MHz with HSI source 8 MHz", .{sys.freq / MHz}));
                    }
                    hsi_enabled = true;
                },
                .HSE => {
                    if (sys.freq != hse_freq) {
                        @compileError(comptimePrint("Incompatible sys frequency {} MHz with HSE source {} MHz", .{ sys.freq / MHz, hse_freq / MHz }));
                    }
                    hse_enabled = true;
                },
                .PLL => {
                    if (config.pll) |pll| {
                        if (pll.freq != sys.freq) {
                            @compileError(comptimePrint("Incompatible sys frequency {} MHz with PLL source {} MHz", .{ sys.freq / MHz, pll.freq / MHz }));
                        }
                    } else {
                        pll_config = .{ .source = .HSE, .freq = sys.freq };
                        hse_enabled = true;
                    }
                },
            }

            if (ahb_freq > 72 * MHz) {
                @compileError(comptimePrint("AHB frequency is too high. Max frequency: 72 MHz, got {} MHz", .{ahb_freq / MHz}));
            }

            // for some reason 32 is not a valid prescaler
            if (!isValidPrescaler(ahb_div, 512) or ahb_div == 32) {
                @compileError(comptimePrint("Invalid frequency for AHB: {} Hz.", .{ahb_freq}));
            }

            if (apb1_freq > 36 * MHz) {
                @compileError(comptimePrint("APB1 frequency is too high. Max frequency: 36 MHz, got {} MHz", .{apb1_freq / MHz}));
            }

            if (!isValidPrescaler(apb1_div, 16)) {
                @compileError(comptimePrint("Invalid frequency for APB1: {}.\nValid prescalers: 1, 2, 4, 18 and 16. Got {}", .{ apb1_freq, apb1_div }));
            }

            if (apb2_freq > 72 * MHz) {
                @compileError(comptimePrint("APB2 frequency is too high. Max frequency: 72 MHz, got {} MHz", .{apb2_freq / MHz}));
            }

            if (!isValidPrescaler(apb2_div, 16)) {
                @compileError(comptimePrint("Invalid frequency for APB2: {}.\nValid prescalers: 1, 2, 4, 8 and 16. Got {}", .{ apb2_freq, apb2_div }));
            }
        }

        // Apply config
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

        if (pll_config) |pll| {
            // we need to turn off the pll to configure it
            RCC.CR.modify(.{ .PLLON = 0 });
            while (RCC.CR.read().PLLRDY != 0) {}

            switch (pll.source) {
                .HSI_DIV_2 => {
                    RCC.CFGR.modify(.{ .PLLSRC = 0, .PLLMUL = getPLLmul(pll_mul) });
                },
                .HSE => {
                    RCC.CFGR.modify(.{ .PLLSRC = 1, .PLLXTPRE = 0, .PLLMUL = getPLLmul(pll_mul) });
                },
                .HSE_DIV_2 => {
                    RCC.CFGR.modify(.{ .PLLSRC = 1, .PLLXTPRE = 1, .PLLMUL = getPLLmul(pll_mul) });
                },
            }

            RCC.CR.modify(.{ .PLLON = 1 });
            while (RCC.CR.read().PLLRDY != 1) {}
        } else {
            RCC.CR.modify(.{ .PLLON = 0 });
            while (RCC.CR.read().PLLRDY != 0) {}
        }

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

        RCC.CFGR.modify(.{ .HPRE = getHPREdiv(ahb_div) });

        // HACK: Ummmmmmm what?
        const source_num = @as(u2, @intFromEnum(@as(SysConfig.Source, sys.source)));
        RCC.CFGR.modify(.{ .SW = source_num });
        while (RCC.CFGR.read().SWS != source_num) {}

        RCC.CFGR.modify(.{
            .PPRE1 = getAPPREdiv(apb1_div),
            .PPRE2 = getAPPREdiv(apb2_div),
        });

        if (!hsi_enabled) {
            RCC.CR.modify(.{ .HSION = 0 });
            while (RCC.CR.read().HSIRDY != 0) {}
        }
    }
};

fn isValidPrescaler(comptime d: u32, comptime max: u16) bool {
    return d <= max and std.math.isPowerOfTwo(d);
}

fn isValidPLLmul(comptime m: u32) bool {
    return m >= 2 and m <= 16;
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
        else => @panic("Invalid prescaler"),
    };
}

fn getAPPREdiv(comptime d: u32) u3 {
    return switch (d) {
        1 => 0b000,
        2 => 0b100,
        4 => 0b101,
        8 => 0b110,
        16 => 0b111,
        else => @panic("Invalid prescaler"),
    };
}

fn getPLLmul(comptime m: u32) u4 {
    return @as(u4, m - 2);
}
