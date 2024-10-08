const Ticks = @import("ticks.zig");
const std = @import("std");

pub const AgentBias = enum {
    Bullish,
    Bearish,
    Idle,
};

pub const AgentParadigm = enum {
    Contrarian,
    Momentum,
    Hedge,
};

const Tag = struct {
    bias: AgentBias,
    paradigm: AgentParadigm,
};

pub const PositionType = enum {
    Long,
    Short,
};

pub const TradingPlan = struct {
    position_type: PositionType,
    entry_price: f32,
    exit_price: f32,
    stop_loss: f32,
};

pub const Agent = struct {
    id: u64,
    tag: Tag,

    pub fn init(id: u64, bias: AgentBias, paradigm: AgentParadigm) Agent {
        return Agent{
            .id = id,
            .tag = Tag{
                .bias = bias,
                .paradigm = paradigm,
            },
        };
    }

    pub fn plan(self: *Agent, market: *std.ArrayList(Ticks.Tick)) TradingPlan {
        var bias_score: u8 = 0;

        for (market) |tick| {
            const tick_bias = tick.get_bias();

            switch (tick_bias) {
                Ticks.TickBias.Bullish => if (self.tag.bias == AgentBias.Bullish) {
                    bias_score = if (bias_score >= 100) 100 else bias_score + 1;
                } else if (self.tag.bias == AgentBias.Bearish) {
                    bias_score = if (bias_score <= 0) 0 else bias_score - 1;
                },
                Ticks.TickBias.Bearish => if (self.tag.bias == AgentBias.Bullish) {
                    bias_score = if (bias_score <= 0) 0 else bias_score - 1;
                } else if (self.tag.bias == AgentBias.Bearish) {
                    bias_score = if (bias_score >= 100) 100 else bias_score + 1;
                },
            }
        }

        const latest_tick = market[market.items.len - 1];

        // A bias score of 0 means the market is the opposite of the agent's bias.
        // and a contrarian agent would trade against that bias and vice versa.
        switch (self.tag.paradigm) {
            AgentParadigm.Contrarian => if (bias_score == 0) {
                return TradingPlan{
                    .type = PositionType.Long,
                    // TODO - no magic numbers - add Tick pip size
                    .entry_price = latest_tick.close + (latest_tick.close * 0.0001),
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            } else {
                return TradingPlan{
                    .type = PositionType.Short,
                    .entry_price = 0.0,
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            },
            AgentParadigm.Momentum => if (bias_score >= 50) {
                return TradingPlan{
                    .type = PositionType.Long,
                    .entry_price = 0.0,
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            } else {
                return TradingPlan{
                    .type = PositionType.Short,
                    .entry_price = 0.0,
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            },
            AgentParadigm.Hedge => if (bias_score >= 50) {
                return TradingPlan{
                    .type = PositionType.Long,
                    .entry_price = 0.0,
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            } else {
                return TradingPlan{
                    .type = PositionType.Short,
                    .entry_price = 0.0,
                    .exit_price = 0.0,
                    .stop_loss = 0.0,
                };
            },
        }
    }
};
