# MT5 Multi-Strategy EA — Design

## 1. Purpose & scope

An MQL5 Expert Advisor (`OmidotMultiStrategyEA.mq5`) that runs inside the user's own MetaTrader 5 terminal, attached to a live account the user controls. The EA selects one of three independent entry strategies at a time, runs every signal through a shared confirmation-filter layer, sizes and protects every trade through a shared risk-management layer, and manages exits with ATR-based trailing/partial-close logic.

**Explicitly out of scope / non-goals:**
- No guaranteed win rate or profit percentage. No backtest or design choice here is tuned to produce a specific win-rate number; doing so would indicate curve-fitting, not a real edge.
- No martingale, grid, or loss-doubling position sizing.
- No remote execution — the EA only acts inside the user's own MT5 terminal once they compile and attach it. Nothing in this design or its implementation sends orders anywhere outside that terminal.

## 2. Architecture

Single `.mq5` file, compiled with MetaEditor, attached to one chart (default: XAUUSD or EURUSD, H1).

```
OmidotMultiStrategyEA.mq5
├── Inputs (grouped: Mode, Signal params, Filters, Risk, Exits, Session)
├── OnInit()      — validate inputs, cache indicator handles
├── OnTick()       — main loop:
│     1. Manage open positions (smart exit layer)
│     2. On new bar: evaluate signal module selected by TradingMode
│     3. If signal passes confirmation filters → risk layer sizes & sends order
├── Signal modules — GetSignal_Trend(), GetSignal_MeanReversion(), GetSignal_Breakout()
├── Filter layer    — PassesFilters(signal_direction)
├── Risk layer       — CalculateLotSize(), DailyDrawdownLockActive(), CountOpenPositions()
├── Exit layer        — ManageTrailing(), ManagePartialTP(), ManageBreakeven(), CheckEarlyExit()
└── Execution         — CTrade wrapper, fixed MagicNumber, logging to MQL5/Files/
```

All three signal modules share the same filter, risk, and exit layers — only entry-signal generation differs by mode.

## 3. Inputs

| Group | Input | Default | Notes |
|---|---|---|---|
| Mode | `TradingMode` (enum: Trend, MeanReversion, Breakout) | Trend | Selects active signal module |
| Signal: Trend | `FastMAPeriod` / `SlowMAPeriod` | 20 / 50 | MA cross |
| Signal: MeanReversion | `RSI_Period`, `RSI_Oversold`, `RSI_Overbought`, `BB_Period`, `BB_Deviation` | 14, 30, 70, 20, 2.0 | Core entry signal for this mode |
| Signal: Breakout | `BreakoutLookbackBars` | 20 | Donchian-style high/low breakout |
| Filters | `UseEMA200Filter`, `EMA200_Period` | true, 200 | Blocks counter-trend entries |
| Filters | `UseADXFilter`, `ADX_Period`, `ADX_Threshold` | true, 14, 20 | Trend/Breakout only |
| Filters | `UseATRFilter`, `ATR_Period`, `ATR_MinMultiplier` | true, 14, 0.5 | Blocks entries when ATR abnormally low |
| Filters | `UseH4Confirmation` | true | H1 signal must not contradict H4 EMA50/EMA200 direction |
| Filters | `UseRSIExtremeFilter`, `RSI_ExtremeLevel` | true, 70/30 | Trend/Breakout only; blocks chasing extremes |
| Filters | `UseMACDFilter`, `MACD_Fast`, `MACD_Slow`, `MACD_Signal` | true, 12, 26, 9 | Trend/Breakout only; momentum confirmation |
| Risk | `RiskPercentPerTrade` | 1.0 | % of balance risked per trade, via SL distance |
| Risk | `MaxDailyDrawdownPercent` | 3.0 | Locks new entries for the rest of the server day |
| Risk | `MaxConcurrentTrades` | 1 | Counted by MagicNumber |
| Risk | `TradingStartHour` / `TradingEndHour` | 7 / 20 | Server time |
| Exits | `ATR_Multiplier_SL` / `ATR_Multiplier_TP` | 1.5 / 3.0 | Initial SL/TP distance |
| Exits | `UseTrailingStop`, `TrailingATRMultiplier` | true, 1.5 | ATR-based trailing, one-directional |
| Exits | `UsePartialTP`, `PartialTPAtrMultiplier`, `PartialClosePercent` | true, 1.0, 50 | Partial close + breakeven on remainder |
| Exits | `UseBreakeven`, `BreakevenTriggerPips` | true, 20 | Moves SL to entry (+/- spread) once triggered |
| Exits | `UseEarlyReversalExit` | true | Closes early on MACD cross + RSI reversal against position |
| System | `MagicNumber` | 20261110 | Isolates EA's own positions |

## 4. Signal modules

- **Trend**: `FastMAPeriod`/`SlowMAPeriod` cross on the selected symbol/timeframe generates BUY/SELL.
- **MeanReversion**: RSI crossing back from `RSI_Oversold`/`RSI_Overbought` while price touches the outer Bollinger Band generates BUY/SELL. This mode does not use the ADX, RSI-extreme, or MACD filters (they would contradict its mean-reversion premise).
- **Breakout**: close breaking above/below the highest high / lowest low of the last `BreakoutLookbackBars` bars generates BUY/SELL.

Only the module matching `TradingMode` runs per tick; the other two are inactive code paths, not parallel systems.

## 5. Confirmation filter layer

Applied to every candidate signal before it reaches the risk layer. Trend and Breakout pass through all enabled filters (EMA200, ADX, ATR, H4, RSI-extreme, MACD). MeanReversion passes through EMA200, ATR, and H4 only — ADX, RSI-extreme, and MACD are skipped by design (see Section 4). Each filter is independently toggleable via its `Use...` input so the user can isolate which filters help during testing.

## 6. Risk management layer

- Lot size = `(Balance × RiskPercentPerTrade / 100) / (SL_distance_in_points × point_value)`, rounded to the symbol's lot step and clamped to broker min/max lot.
- Daily drawdown lock: EA records equity at the first tick of each new server day; if current equity drop from that reference exceeds `MaxDailyDrawdownPercent`, no new entries are opened until the next server day resets the reference. Open positions continue to be managed by the exit layer regardless of lock state.
- `MaxConcurrentTrades` counts only positions carrying this EA's `MagicNumber`.
- Trading hours: new entries only between `TradingStartHour` and `TradingEndHour` (server time); existing positions are still managed outside this window.
- Every order sent includes both SL and TP computed from ATR — there is no code path that sends an order without both.

## 7. Smart exit layer

Evaluated every tick for each open position belonging to this EA, in this priority order:

1. **Early reversal exit** — if `UseEarlyReversalExit` and MACD crosses against the position direction while RSI exits its extreme zone back toward midline, close the position immediately.
2. **Partial TP** — if `UsePartialTP` and floating profit reaches `PartialTPAtrMultiplier × ATR`, close `PartialClosePercent` of the volume and move the remaining position's SL to breakeven.
3. **Breakeven** — if `UseBreakeven` and floating profit reaches `BreakevenTriggerPips` and SL hasn't already been moved by step 2, move SL to entry price (+/- spread for the correct side).
4. **Trailing stop** — if `UseTrailingStop`, trail SL behind price at `TrailingATRMultiplier × ATR`, only ever tightening, never loosening.

## 8. Execution & logging

- All orders/modifications go through a `CTrade` instance, tagged with `MagicNumber`; the EA never touches positions without that magic number.
- Every signal evaluation, filter pass/fail reason, order sent, and exit action is appended to a log file under `MQL5/Files/OmidotEA_log_<date>.csv` so the user can audit why the EA did or didn't act.

## 9. Testing & rollout

- Before attaching to the live chart, the user runs the MT5 Strategy Tester against historical data for the chosen symbol/timeframe to catch obvious logic errors (crashes, inverted signals, SL/TP never firing, etc.). This is a minimum correctness check, not a profitability guarantee.
- The user has stated they will attach the EA directly to a live account without a prior demo-forward-test period; this design does not change based on that choice, but the daily-drawdown lock and mandatory SL/TP exist specifically to bound downside given that choice.
- No part of this design or its future implementation will be executed, deployed, or run by the assistant — compiling and attaching the EA in MetaEditor/MT5 is done by the user, on their own machine, under their own account.
