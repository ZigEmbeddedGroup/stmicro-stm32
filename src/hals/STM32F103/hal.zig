pub const pins = @import("pins.zig");
pub const clocks = @import("clocks.zig");

const microzig = @import("microzig");
const FLASH = microzig.chip.peripherals.FLASH;

pub fn init() void {
    FLASH.ACR.modify(.{ .PRFTBE = 1 });
}
