pub const TickSettings = packed struct {
    open: f32,
    high: f32,
    low: f32,
    close: f32,
    volume: f32,
};

pub const Tick = struct {
    open: f32,
    high: f32,
    low: f32,
    close: f32,
    volume: f32,

    pub fn init(settings: TickSettings) Tick {
        return Tick{
            .open = settings.open,
            .high = settings.high,
            .low = settings.low,
            .close = settings.close,
            .volume = settings.volume,
        };
    }
};
