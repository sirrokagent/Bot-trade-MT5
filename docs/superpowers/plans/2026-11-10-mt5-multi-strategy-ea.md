# MT5 Multi-Strategy EA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `OmidotMultiStrategyEA.mq5`, an MQL5 Expert Advisor that runs one of three selectable entry strategies through a shared confirmation-filter layer, a shared risk-management layer, and a shared smart-exit layer, inside the user's own MT5 terminal.

**Architecture:** Pure, side-effect-free decision logic (lot sizing, filters, signals, exit decisions, drawdown lock) lives in small `.mqh` include files under `MQL5/Include/Omidot/`, each with its own MQL5 test script under `MQL5/Scripts/Omidot/Tests/`. The main EA (`MQL5/Experts/Omidot/OmidotMultiStrategyEA.mq5`) is a thin integration layer that wires these pure functions to live MT5 market/indicator/position data.

**Tech Stack:** MQL5, compiled with `C:\Program Files\MetaTrader 5\MetaEditor64.exe` (confirmed present on this machine). Standard library `<Trade\Trade.mqh>` (`CTrade`) for order execution.

## Global Constraints

- No martingale/grid/loss-doubling position sizing anywhere in this project (per spec Section 1).
- The assistant never executes, deploys, or runs this EA — the user compiles and attaches it in their own MetaEditor/MT5 (per spec Section 1 and 9).
- Every order sent must carry both SL and TP; there is no code path that sends an order without both (per spec Section 6).
- `MetaEditor64.exe /compile` **always exits with code 0**, even when compilation fails with errors — this was confirmed experimentally on this machine. Every compile step below checks the **log file content** (the `Result:` line and absence of `error` lines), never the process exit code.
- MetaEditor64.exe compile log files are UTF-16LE encoded. Read them with `powershell -Command "Get-Content -Encoding Unicode '<path>'"` (confirmed working on this machine) — plain `cat` renders them as garbled spaced text.
- This machine's MT5 terminal data folder is `C:\Users\Admin\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\` — confirmed by a successful standard-library compile (`<Trade\Trade.mqh>` resolved from `...\MQL5\Include\Trade\Trade.mqh` under this folder). All angle-bracket includes (`<Trade\Trade.mqh>`) resolve against this folder automatically; our own quoted includes (`"../Types.mqh"`) resolve relative to the including file's own location and do not depend on this folder.
- Mode-specific filter skip: when `TradingMode == MODE_MEAN_REVERSION`, the ADX, RSI-extreme, and MACD filters are never applied, by design (spec Section 5/6) — mean reversion inherently trades against momentum, so momentum filters would contradict it.
- Default input values (spec Section 3), copied verbatim — every task below that defines an `input` must use these exact defaults: `RiskPercentPerTrade=1.0`, `MaxDailyDrawdownPercent=3.0`, `MaxConcurrentTrades=1`, `TradingStartHour=7`, `TradingEndHour=20`, `ATR_Multiplier_SL=1.5`, `ATR_Multiplier_TP=3.0`, `TrailingATRMultiplier=1.5`, `PartialTPAtrMultiplier=1.0`, `PartialClosePercent=50.0`, `BreakevenTriggerPips=20.0`, `MagicNumber=20261110`, `EMA200_Period=200`, `ADX_Period=14`, `ADX_Threshold=20.0`, `ATR_Period=14`, `ATR_MinMultiplier=0.5`, `RSI_ExtremeLevel=70.0`, `MACD_Fast=12`, `MACD_Slow=26`, `MACD_Signal=9`, `RSI_Period=14`, `RSI_Oversold=30.0`, `RSI_Overbought=70.0`, `BB_Period=20`, `BB_Deviation=2.0`, `FastMAPeriod=20`, `SlowMAPeriod=50`, `BreakoutLookbackBars=20`.
- This work happens in an isolated git worktree at `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\` (branch `worktree-mt5-multi-strategy-ea`), checked out from the repo pushed to `https://github.com/sirrokagent/Bot-trade-MT5.git`. All file paths in this plan point into that worktree. Directory junctions into the live MT5 terminal are deliberately **not** created during this branch's tasks (see Task 1's note) — they are created once, after merge, against the permanent path `D:\BOT TRADE\MQL5\...`.

---

### Task 1: Project scaffolding and compiler toolchain verification

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\` (directory)
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Experts\Omidot\` (directory)
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\` (directory)
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\_ToolchainSmokeTest.mq5`

**Interfaces:**
- Produces: a working `compile-and-check` procedure every later task reuses: run `MetaEditor64.exe /compile:"<file>" /log:"<logfile>"`, then read `<logfile>` with PowerShell `Get-Content -Encoding Unicode`, and confirm the last line reads `Result: 0 errors, 0 warnings, ...` with no `error` lines above it.

- [ ] **Step 1: Create the repo-side directory structure**

```bash
mkdir -p "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea/MQL5/Include/Omidot"
mkdir -p "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea/MQL5/Experts/Omidot"
mkdir -p "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea/MQL5/Scripts/Omidot/Tests"
```

> **Note on the MT5 terminal Navigator:** this task does not create directory junctions into the live MT5 terminal data folder. The code is being developed in an isolated git worktree (a separate checkout); junctioning the terminal into a worktree that will later be deleted would leave a dangling link. Junction creation is deferred to after this branch merges back into `main` (see Task 8's final step and the branch-finishing step) — at that point the files live at their permanent path, `D:\BOT TRADE\MQL5\...`, and the junction can safely point there. Every compile/verification step below works without the junction regardless, because `MetaEditor64.exe /compile` takes an explicit file path and does not need the terminal's Navigator to find a file.

- [ ] **Step 2: Write a trivial smoke-test script**

```mql5
void OnStart()
  {
   Print("toolchain ok");
  }
```

Save as `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\_ToolchainSmokeTest.mq5`.

- [ ] **Step 3: Compile it and verify the toolchain**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\_ToolchainSmokeTest.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: last line is `Result: 0 errors, 0 warnings, ... elapsed, cpu='X64 Regular'`.

- [ ] **Step 4: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/
git commit -m "Scaffold MQL5 project structure for Omidot multi-strategy EA"
```

---

### Task 2: RiskMath.mqh — position sizing

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\RiskMath.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskMath.mq5`

**Interfaces:**
- Produces: `double CalculateLotSize(double balance, double riskPercent, double slDistancePoints, double tickValue, double tickSize, double point, double lotStep, double minLot, double maxLot)` — risked-% based lot size, floored to the broker's lot step, clamped to `[minLot, maxLot]`.

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskMath.mq5`:

```mql5
#include "../../../Include/Omidot/RiskMath.mqh"

int g_failCount = 0;

void AssertNear(string testName, double actual, double expected, double tolerance)
  {
   if(MathAbs(actual - expected) > tolerance)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %.5f, got %.5f", testName, expected, actual);
     }
   else
      PrintFormat("PASS: %s", testName);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertNear("normal_no_rounding_needed",
               CalculateLotSize(10000.0, 1.0, 200.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.50, 0.0001);

   AssertNear("floors_down_to_lot_step",
               CalculateLotSize(10000.0, 1.0, 333.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.30, 0.0001);

   AssertNear("clamps_to_min_lot",
               CalculateLotSize(100.0, 1.0, 500.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.01, 0.0001);

   AssertNear("clamps_to_max_lot",
               CalculateLotSize(10000000.0, 5.0, 10.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               100.0, 0.0001);

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails (RiskMath.mqh doesn't exist yet)**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskMath.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: a line containing `error 106: file '...RiskMath.mqh' not found` and `Result: 1 errors, 0 warnings`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\RiskMath.mqh`:

```mql5
#ifndef OMIDOT_RISKMATH_MQH
#define OMIDOT_RISKMATH_MQH

double CalculateLotSize(double balance,
                         double riskPercent,
                         double slDistancePoints,
                         double tickValue,
                         double tickSize,
                         double point,
                         double lotStep,
                         double minLot,
                         double maxLot)
  {
   if(slDistancePoints <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || lotStep <= 0.0)
      return 0.0;

   double riskAmount    = balance * (riskPercent / 100.0);
   double valuePerPoint = tickValue * (point / tickSize);
   double rawLot         = riskAmount / (slDistancePoints * valuePerPoint);

   double steppedLot = MathFloor(rawLot / lotStep + 0.00000001) * lotStep;

   if(steppedLot < minLot)
      steppedLot = minLot;
   if(steppedLot > maxLot)
      steppedLot = maxLot;

   return steppedLot;
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskMath.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertions actually hold**

This requires the MT5 terminal GUI — it cannot be automated headlessly. In MT5: Navigator → Scripts → Omidot → Tests → drag `TestRiskMath` onto any open chart. Check the **Experts** tab of the Toolbox.

Expected log output: four `PASS:` lines and then `ALL TESTS PASSED`. If any line reads `FAIL: ...`, stop and fix `RiskMath.mqh` before continuing — do not proceed to Task 3 with a failing test.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/RiskMath.mqh MQL5/Scripts/Omidot/Tests/TestRiskMath.mq5
git commit -m "Add risk-based lot sizing (RiskMath.mqh)"
```

---

### Task 3: Filters.mqh — confirmation filter layer

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Types.mqh`
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Filters.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestFilters.mq5`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `enum ENUM_TRADE_DIRECTION { DIR_NONE, DIR_BUY, DIR_SELL };` (used by every later task)
  - `enum ENUM_TRADING_MODE { MODE_TREND, MODE_MEAN_REVERSION, MODE_BREAKOUT };` (used by every later task)
  - `struct FilterToggles { bool useEMA200, useADX, useATR, useH4Confirmation, useRSIExtreme, useMACD; };`
  - `struct FilterInputs { double price, ema200, adxValue, adxThreshold, atrValue, atrAverage, atrMinMultiplier; ENUM_TRADE_DIRECTION h4TrendDirection; double rsiValue, rsiExtremeLevel, macdMain, macdSignal; };`
  - `bool PassesFilters(ENUM_TRADE_DIRECTION signalDir, ENUM_TRADING_MODE mode, const FilterInputs &f, const FilterToggles &t)`

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestFilters.mq5`:

```mql5
#include "../../../Include/Omidot/Filters.mqh"

int g_failCount = 0;

void AssertTrue(string name, bool actual)
  {
   if(!actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected true, got false", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertFalse(string name, bool actual)
  {
   if(actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected false, got true", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

FilterToggles AllOn()
  {
   FilterToggles t;
   t.useEMA200 = true;
   t.useADX = true;
   t.useATR = true;
   t.useH4Confirmation = true;
   t.useRSIExtreme = true;
   t.useMACD = true;
   return t;
  }

FilterInputs BaseBuyPassing()
  {
   FilterInputs f;
   f.price = 1.2000;
   f.ema200 = 1.1950;
   f.adxValue = 25.0;
   f.adxThreshold = 20.0;
   f.atrValue = 0.0015;
   f.atrAverage = 0.0010;
   f.atrMinMultiplier = 0.5;
   f.h4TrendDirection = DIR_BUY;
   f.rsiValue = 55.0;
   f.rsiExtremeLevel = 70.0;
   f.macdMain = 0.0020;
   f.macdSignal = 0.0010;
   return f;
  }

void OnStart()
  {
   g_failCount = 0;
   FilterToggles t = AllOn();

   FilterInputs passing = BaseBuyPassing();
   AssertTrue("buy_passes_all_filters", PassesFilters(DIR_BUY, MODE_TREND, passing, t));

   FilterInputs blockedByEma = BaseBuyPassing();
   blockedByEma.price = 1.1900;
   AssertFalse("buy_blocked_by_ema200", PassesFilters(DIR_BUY, MODE_TREND, blockedByEma, t));

   FilterInputs blockedByAdx = BaseBuyPassing();
   blockedByAdx.adxValue = 10.0;
   AssertFalse("buy_blocked_by_adx", PassesFilters(DIR_BUY, MODE_TREND, blockedByAdx, t));

   FilterInputs blockedByRsi = BaseBuyPassing();
   blockedByRsi.rsiValue = 75.0;
   AssertFalse("buy_blocked_by_rsi_extreme", PassesFilters(DIR_BUY, MODE_TREND, blockedByRsi, t));

   FilterInputs blockedByMacd = BaseBuyPassing();
   blockedByMacd.macdMain = 0.0005;
   AssertFalse("buy_blocked_by_macd", PassesFilters(DIR_BUY, MODE_TREND, blockedByMacd, t));

   FilterInputs meanReversionLowAdx = BaseBuyPassing();
   meanReversionLowAdx.adxValue = 5.0;
   AssertTrue("mean_reversion_skips_adx_filter", PassesFilters(DIR_BUY, MODE_MEAN_REVERSION, meanReversionLowAdx, t));

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestFilters.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `error 106: file '...Filters.mqh' not found`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Types.mqh`:

```mql5
#ifndef OMIDOT_TYPES_MQH
#define OMIDOT_TYPES_MQH

enum ENUM_TRADE_DIRECTION
  {
   DIR_NONE,
   DIR_BUY,
   DIR_SELL
  };

enum ENUM_TRADING_MODE
  {
   MODE_TREND,
   MODE_MEAN_REVERSION,
   MODE_BREAKOUT
  };

#endif
```

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Filters.mqh`:

```mql5
#ifndef OMIDOT_FILTERS_MQH
#define OMIDOT_FILTERS_MQH

#include "Types.mqh"

struct FilterToggles
  {
   bool useEMA200;
   bool useADX;
   bool useATR;
   bool useH4Confirmation;
   bool useRSIExtreme;
   bool useMACD;
  };

struct FilterInputs
  {
   double               price;
   double               ema200;
   double               adxValue;
   double               adxThreshold;
   double               atrValue;
   double               atrAverage;
   double               atrMinMultiplier;
   ENUM_TRADE_DIRECTION h4TrendDirection;
   double               rsiValue;
   double               rsiExtremeLevel;
   double               macdMain;
   double               macdSignal;
  };

bool PassesFilters(ENUM_TRADE_DIRECTION signalDir,
                    ENUM_TRADING_MODE mode,
                    const FilterInputs &f,
                    const FilterToggles &t)
  {
   if(signalDir == DIR_NONE)
      return false;

   if(t.useEMA200)
     {
      if(signalDir == DIR_BUY && f.price <= f.ema200)
         return false;
      if(signalDir == DIR_SELL && f.price >= f.ema200)
         return false;
     }

   if(t.useATR)
     {
      if(f.atrAverage > 0.0 && f.atrValue < f.atrAverage * f.atrMinMultiplier)
         return false;
     }

   if(t.useH4Confirmation)
     {
      if(f.h4TrendDirection != DIR_NONE && f.h4TrendDirection != signalDir)
         return false;
     }

   if(mode != MODE_MEAN_REVERSION)
     {
      if(t.useADX && f.adxValue < f.adxThreshold)
         return false;

      if(t.useRSIExtreme)
        {
         if(signalDir == DIR_BUY && f.rsiValue >= f.rsiExtremeLevel)
            return false;
         if(signalDir == DIR_SELL && f.rsiValue <= (100.0 - f.rsiExtremeLevel))
            return false;
        }

      if(t.useMACD)
        {
         if(signalDir == DIR_BUY && f.macdMain <= f.macdSignal)
            return false;
         if(signalDir == DIR_SELL && f.macdMain >= f.macdSignal)
            return false;
        }
     }

   return true;
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestFilters.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertions**

Drag `TestFilters` from Navigator onto a chart. Expected: six `PASS:` lines, then `ALL TESTS PASSED` in the Experts tab.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/Types.mqh MQL5/Include/Omidot/Filters.mqh MQL5/Scripts/Omidot/Tests/TestFilters.mq5
git commit -m "Add shared types and confirmation filter layer (Filters.mqh)"
```

---

### Task 4: Signals.mqh — three entry-signal modules

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Signals.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestSignals.mq5`

**Interfaces:**
- Consumes: `ENUM_TRADE_DIRECTION` from Task 3's `Types.mqh`.
- Produces:
  - `ENUM_TRADE_DIRECTION GetSignal_Trend(double fastMaPrev, double fastMaCurr, double slowMaPrev, double slowMaCurr)`
  - `ENUM_TRADE_DIRECTION GetSignal_MeanReversion(double rsiPrev, double rsiCurr, double rsiOversold, double rsiOverbought, double close, double bbUpper, double bbLower)`
  - `ENUM_TRADE_DIRECTION GetSignal_Breakout(double close, double highestHighExcludingCurrent, double lowestLowExcludingCurrent)`

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestSignals.mq5`:

```mql5
#include "../../../Include/Omidot/Signals.mqh"

int g_failCount = 0;

void AssertDir(string name, ENUM_TRADE_DIRECTION actual, ENUM_TRADE_DIRECTION expected)
  {
   if(actual != expected)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %d, got %d", name, expected, actual);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertDir("trend_cross_up_gives_buy",
             GetSignal_Trend(1.1000, 1.1020, 1.1010, 1.1015), DIR_BUY);

   AssertDir("trend_cross_down_gives_sell",
             GetSignal_Trend(1.1010, 1.0990, 1.1000, 1.1000), DIR_SELL);

   AssertDir("trend_no_cross_gives_none",
             GetSignal_Trend(1.1000, 1.1005, 1.0990, 1.0995), DIR_NONE);

   AssertDir("meanreversion_oversold_recovery_at_lower_band_gives_buy",
             GetSignal_MeanReversion(25.0, 35.0, 30.0, 70.0, 1.0950, 1.1040, 1.0960), DIR_BUY);

   AssertDir("meanreversion_overbought_recovery_at_upper_band_gives_sell",
             GetSignal_MeanReversion(75.0, 65.0, 30.0, 70.0, 1.1050, 1.1040, 1.0960), DIR_SELL);

   AssertDir("meanreversion_recovery_without_band_touch_gives_none",
             GetSignal_MeanReversion(25.0, 35.0, 30.0, 70.0, 1.1000, 1.1040, 1.0960), DIR_NONE);

   AssertDir("breakout_above_highest_high_gives_buy",
             GetSignal_Breakout(1.2050, 1.2000, 1.1950), DIR_BUY);

   AssertDir("breakout_below_lowest_low_gives_sell",
             GetSignal_Breakout(1.1900, 1.2000, 1.1950), DIR_SELL);

   AssertDir("breakout_inside_range_gives_none",
             GetSignal_Breakout(1.1980, 1.2000, 1.1950), DIR_NONE);

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestSignals.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `error 106: file '...Signals.mqh' not found`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Signals.mqh`:

```mql5
#ifndef OMIDOT_SIGNALS_MQH
#define OMIDOT_SIGNALS_MQH

#include "Types.mqh"

ENUM_TRADE_DIRECTION GetSignal_Trend(double fastMaPrev,
                                      double fastMaCurr,
                                      double slowMaPrev,
                                      double slowMaCurr)
  {
   bool crossedUp   = (fastMaPrev <= slowMaPrev && fastMaCurr > slowMaCurr);
   bool crossedDown = (fastMaPrev >= slowMaPrev && fastMaCurr < slowMaCurr);

   if(crossedUp)
      return DIR_BUY;
   if(crossedDown)
      return DIR_SELL;
   return DIR_NONE;
  }

ENUM_TRADE_DIRECTION GetSignal_MeanReversion(double rsiPrev,
                                              double rsiCurr,
                                              double rsiOversold,
                                              double rsiOverbought,
                                              double close,
                                              double bbUpper,
                                              double bbLower)
  {
   bool rsiRecoveringUp   = (rsiPrev <= rsiOversold && rsiCurr > rsiOversold);
   bool touchedLowerBand  = (close <= bbLower);
   if(rsiRecoveringUp && touchedLowerBand)
      return DIR_BUY;

   bool rsiRecoveringDown = (rsiPrev >= rsiOverbought && rsiCurr < rsiOverbought);
   bool touchedUpperBand  = (close >= bbUpper);
   if(rsiRecoveringDown && touchedUpperBand)
      return DIR_SELL;

   return DIR_NONE;
  }

ENUM_TRADE_DIRECTION GetSignal_Breakout(double close,
                                         double highestHighExcludingCurrent,
                                         double lowestLowExcludingCurrent)
  {
   if(close > highestHighExcludingCurrent)
      return DIR_BUY;
   if(close < lowestLowExcludingCurrent)
      return DIR_SELL;
   return DIR_NONE;
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestSignals.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertions**

Drag `TestSignals` onto a chart. Expected: nine `PASS:` lines, then `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/Signals.mqh MQL5/Scripts/Omidot/Tests/TestSignals.mq5
git commit -m "Add Trend/MeanReversion/Breakout entry signal modules (Signals.mqh)"
```

---

### Task 5: ExitLogic.mqh — smart exit layer

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\ExitLogic.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestExitLogic.mq5`

**Interfaces:**
- Consumes: `ENUM_TRADE_DIRECTION` from Task 3's `Types.mqh`.
- Produces:
  - `bool ShouldEarlyExit(ENUM_TRADE_DIRECTION positionDir, double macdMainPrev, double macdSignalPrev, double macdMainCurr, double macdSignalCurr, double rsiPrev, double rsiCurr, double rsiExtremeLevel)`
  - `bool ShouldPartialClose(double profitPoints, double atrPoints, double partialAtrMultiplier, bool alreadyPartiallyClosed)`
  - `double ComputeBreakevenSL(ENUM_TRADE_DIRECTION positionDir, double entryPrice, double spreadPoints, double point)`
  - `double ComputeTrailingSL(ENUM_TRADE_DIRECTION positionDir, double currentPrice, double atrPrice, double trailMultiplier, double currentSL)`

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestExitLogic.mq5`:

```mql5
#include "../../../Include/Omidot/ExitLogic.mqh"

int g_failCount = 0;

void AssertTrue(string name, bool actual)
  {
   if(!actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected true, got false", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertFalse(string name, bool actual)
  {
   if(actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected false, got true", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertNear(string name, double actual, double expected, double tolerance)
  {
   if(MathAbs(actual - expected) > tolerance)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %.5f, got %.5f", name, expected, actual);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertTrue("buy_early_exit_on_macd_and_rsi_reversal",
              ShouldEarlyExit(DIR_BUY, 0.0020, 0.0010, 0.0005, 0.0010, 75.0, 65.0, 70.0));

   AssertFalse("buy_no_early_exit_when_rsi_still_extreme",
               ShouldEarlyExit(DIR_BUY, 0.0020, 0.0010, 0.0005, 0.0010, 75.0, 72.0, 70.0));

   AssertTrue("sell_early_exit_on_macd_and_rsi_reversal",
              ShouldEarlyExit(DIR_SELL, 0.0005, 0.0010, 0.0020, 0.0010, 25.0, 35.0, 70.0));

   AssertTrue("partial_close_triggers_at_target",
              ShouldPartialClose(150.0, 100.0, 1.0, false));

   AssertFalse("partial_close_not_yet_at_target",
               ShouldPartialClose(50.0, 100.0, 1.0, false));

   AssertFalse("partial_close_skipped_if_already_done",
               ShouldPartialClose(500.0, 100.0, 1.0, true));

   AssertNear("breakeven_buy_adds_spread",
              ComputeBreakevenSL(DIR_BUY, 1.1000, 20.0, 0.00001),
              1.1002, 0.00001);

   AssertNear("breakeven_sell_subtracts_spread",
              ComputeBreakevenSL(DIR_SELL, 1.1000, 20.0, 0.00001),
              1.0998, 0.00001);

   AssertNear("trailing_buy_tightens_when_candidate_higher",
              ComputeTrailingSL(DIR_BUY, 1.1050, 0.0010, 1.5, 1.1000),
              1.1035, 0.00001);

   AssertNear("trailing_buy_keeps_sl_when_candidate_lower",
              ComputeTrailingSL(DIR_BUY, 1.1050, 0.0010, 1.5, 1.1040),
              1.1040, 0.00001);

   AssertNear("trailing_sell_tightens_when_candidate_lower",
              ComputeTrailingSL(DIR_SELL, 1.0950, 0.0010, 1.5, 1.1000),
              1.0965, 0.00001);

   AssertNear("trailing_sell_keeps_sl_when_candidate_higher",
              ComputeTrailingSL(DIR_SELL, 1.0950, 0.0010, 1.5, 1.0960),
              1.0960, 0.00001);

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestExitLogic.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `error 106: file '...ExitLogic.mqh' not found`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\ExitLogic.mqh`:

```mql5
#ifndef OMIDOT_EXITLOGIC_MQH
#define OMIDOT_EXITLOGIC_MQH

#include "Types.mqh"

bool ShouldEarlyExit(ENUM_TRADE_DIRECTION positionDir,
                      double macdMainPrev, double macdSignalPrev,
                      double macdMainCurr, double macdSignalCurr,
                      double rsiPrev, double rsiCurr,
                      double rsiExtremeLevel)
  {
   if(positionDir == DIR_NONE)
      return false;

   if(positionDir == DIR_BUY)
     {
      bool macdCrossedDown  = (macdMainPrev >= macdSignalPrev && macdMainCurr < macdSignalCurr);
      bool rsiReversingDown = (rsiPrev >= rsiExtremeLevel && rsiCurr < rsiExtremeLevel);
      return macdCrossedDown && rsiReversingDown;
     }

   double rsiLowExtreme = 100.0 - rsiExtremeLevel;
   bool   macdCrossedUp  = (macdMainPrev <= macdSignalPrev && macdMainCurr > macdSignalCurr);
   bool   rsiReversingUp = (rsiPrev <= rsiLowExtreme && rsiCurr > rsiLowExtreme);
   return macdCrossedUp && rsiReversingUp;
  }

bool ShouldPartialClose(double profitPoints,
                         double atrPoints,
                         double partialAtrMultiplier,
                         bool alreadyPartiallyClosed)
  {
   if(alreadyPartiallyClosed)
      return false;
   if(atrPoints <= 0.0)
      return false;
   return profitPoints >= atrPoints * partialAtrMultiplier;
  }

double ComputeBreakevenSL(ENUM_TRADE_DIRECTION positionDir,
                           double entryPrice,
                           double spreadPoints,
                           double point)
  {
   double spreadPrice = spreadPoints * point;
   if(positionDir == DIR_BUY)
      return entryPrice + spreadPrice;
   if(positionDir == DIR_SELL)
      return entryPrice - spreadPrice;
   return 0.0;
  }

double ComputeTrailingSL(ENUM_TRADE_DIRECTION positionDir,
                          double currentPrice,
                          double atrPrice,
                          double trailMultiplier,
                          double currentSL)
  {
   double distance = atrPrice * trailMultiplier;

   if(positionDir == DIR_BUY)
     {
      double candidate = currentPrice - distance;
      if(candidate > currentSL)
         return candidate;
      return currentSL;
     }

   if(positionDir == DIR_SELL)
     {
      double candidate = currentPrice + distance;
      if(currentSL <= 0.0 || candidate < currentSL)
         return candidate;
      return currentSL;
     }

   return currentSL;
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestExitLogic.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertions**

Drag `TestExitLogic` onto a chart. Expected: eleven `PASS:` lines, then `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/ExitLogic.mqh MQL5/Scripts/Omidot/Tests/TestExitLogic.mq5
git commit -m "Add smart exit layer: early reversal exit, partial TP, breakeven, ATR trailing (ExitLogic.mqh)"
```

---

### Task 6: RiskState.mqh — daily drawdown lock

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\RiskState.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskState.mq5`

**Interfaces:**
- Consumes: nothing from earlier tasks (deliberately independent of `Types.mqh`).
- Produces:
  - `double CalcDailyLossPercent(double dayStartEquity, double currentEquity)`
  - `bool IsDailyDrawdownLocked(double dayStartEquity, double currentEquity, double maxDrawdownPercent)`
  - `bool IsNewServerDay(datetime previousStamp, datetime currentStamp)`

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskState.mq5`:

```mql5
#include "../../../Include/Omidot/RiskState.mqh"

int g_failCount = 0;

void AssertTrue(string name, bool actual)
  {
   if(!actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected true, got false", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertFalse(string name, bool actual)
  {
   if(actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected false, got true", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertNear(string name, double actual, double expected, double tolerance)
  {
   if(MathAbs(actual - expected) > tolerance)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %.5f, got %.5f", name, expected, actual);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertNear("loss_percent_computed_correctly",
              CalcDailyLossPercent(10000.0, 9700.0), 3.0, 0.0001);

   AssertNear("loss_percent_is_zero_when_in_profit",
              CalcDailyLossPercent(10000.0, 10100.0), 0.0, 0.0001);

   AssertTrue("drawdown_locked_at_exact_threshold",
              IsDailyDrawdownLocked(10000.0, 9700.0, 3.0));

   AssertFalse("drawdown_not_locked_below_threshold",
               IsDailyDrawdownLocked(10000.0, 9800.0, 3.0));

   AssertTrue("new_day_true_when_no_previous_stamp",
              IsNewServerDay(0, D'2026.11.10 10:00:00'));

   AssertFalse("new_day_false_for_same_calendar_day",
               IsNewServerDay(D'2026.11.10 10:00:00', D'2026.11.10 15:00:00'));

   AssertTrue("new_day_true_when_calendar_day_changes",
              IsNewServerDay(D'2026.11.10 23:59:00', D'2026.11.11 00:01:00'));

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskState.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `error 106: file '...RiskState.mqh' not found`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\RiskState.mqh`:

```mql5
#ifndef OMIDOT_RISKSTATE_MQH
#define OMIDOT_RISKSTATE_MQH

double CalcDailyLossPercent(double dayStartEquity, double currentEquity)
  {
   if(dayStartEquity <= 0.0)
      return 0.0;

   double loss = dayStartEquity - currentEquity;
   if(loss <= 0.0)
      return 0.0;

   return (loss / dayStartEquity) * 100.0;
  }

bool IsDailyDrawdownLocked(double dayStartEquity, double currentEquity, double maxDrawdownPercent)
  {
   if(dayStartEquity <= 0.0)
      return false;

   double lossPercent = CalcDailyLossPercent(dayStartEquity, currentEquity);
   return lossPercent >= maxDrawdownPercent;
  }

bool IsNewServerDay(datetime previousStamp, datetime currentStamp)
  {
   if(previousStamp == 0)
      return true;

   MqlDateTime prevStruct, currStruct;
   TimeToStruct(previousStamp, prevStruct);
   TimeToStruct(currentStamp, currStruct);

   return (prevStruct.year != currStruct.year ||
           prevStruct.mon  != currStruct.mon  ||
           prevStruct.day  != currStruct.day);
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestRiskState.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertions**

Drag `TestRiskState` onto a chart. Expected: seven `PASS:` lines, then `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/RiskState.mqh MQL5/Scripts/Omidot/Tests/TestRiskState.mq5
git commit -m "Add daily drawdown lock logic (RiskState.mqh)"
```

---

### Task 7: Logger.mqh — CSV audit log

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Logger.mqh`
- Test: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestLogger.mq5`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `string FormatLogLine(string timestampText, string category, string message)` (pure, unit-tested)
  - `void LogEvent(string fileName, string timestampText, string category, string message)` (appends a line to `fileName` under the terminal's `MQL5/Files/`; not unit-tested — it is a thin MT5 file-I/O wrapper around `FormatLogLine`, verified only by compilation and by Task 8's manual Strategy Tester run)

- [ ] **Step 1: Write the failing test**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestLogger.mq5`:

```mql5
#include "../../../Include/Omidot/Logger.mqh"

int g_failCount = 0;

void AssertEqualsStr(string name, string actual, string expected)
  {
   if(actual != expected)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected '%s', got '%s'", name, expected, actual);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertEqualsStr("format_log_line_joins_fields_with_commas",
                    FormatLogLine("2026-11-10 10:15:30", "ENTRY", "BUY signal confirmed"),
                    "2026-11-10 10:15:30,ENTRY,BUY signal confirmed");

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
```

- [ ] **Step 2: Compile and verify it fails**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestLogger.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `error 106: file '...Logger.mqh' not found`.

- [ ] **Step 3: Write the implementation**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Include\Omidot\Logger.mqh`:

```mql5
#ifndef OMIDOT_LOGGER_MQH
#define OMIDOT_LOGGER_MQH

string FormatLogLine(string timestampText, string category, string message)
  {
   return timestampText + "," + category + "," + message;
  }

void LogEvent(string fileName, string timestampText, string category, string message)
  {
   int handle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, FormatLogLine(timestampText, category, message) + "\r\n");
   FileClose(handle);
  }

#endif
```

- [ ] **Step 4: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Scripts\Omidot\Tests\TestLogger.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...`.

- [ ] **Step 5: Manually verify the assertion**

Drag `TestLogger` onto a chart. Expected: one `PASS:` line, then `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Include/Omidot/Logger.mqh MQL5/Scripts/Omidot/Tests/TestLogger.mq5
git commit -m "Add CSV audit logger (Logger.mqh)"
```

---

### Task 8: OmidotMultiStrategyEA.mq5 — main EA integration

**Files:**
- Create: `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Experts\Omidot\OmidotMultiStrategyEA.mq5`

**Interfaces:**
- Consumes everything produced by Tasks 2–7: `CalculateLotSize`, `PassesFilters`/`FilterInputs`/`FilterToggles`, `GetSignal_Trend`/`GetSignal_MeanReversion`/`GetSignal_Breakout`, `ShouldEarlyExit`/`ShouldPartialClose`/`ComputeBreakevenSL`/`ComputeTrailingSL`, `IsDailyDrawdownLocked`/`IsNewServerDay`, `LogEvent`.
- Produces: the finished, attachable EA. Nothing downstream consumes this — it is the final deliverable.

This task is integration code against live MT5 market/account/position APIs, which cannot be driven from a unit-test script. Verification here is: (a) automated compilation, and (b) a manual Strategy Tester smoke run performed by the user — per the spec's Section 9, the assistant does not run or deploy this EA.

- [ ] **Step 1: Write the EA**

Create `D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Experts\Omidot\OmidotMultiStrategyEA.mq5`:

```mql5
//+------------------------------------------------------------------+
//|                                       OmidotMultiStrategyEA.mq5 |
//+------------------------------------------------------------------+
#property copyright "Omidot"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "../../Include/Omidot/Types.mqh"
#include "../../Include/Omidot/RiskMath.mqh"
#include "../../Include/Omidot/Filters.mqh"
#include "../../Include/Omidot/Signals.mqh"
#include "../../Include/Omidot/ExitLogic.mqh"
#include "../../Include/Omidot/RiskState.mqh"
#include "../../Include/Omidot/Logger.mqh"

input group "Mode"
input ENUM_TRADING_MODE TradingMode = MODE_TREND;

input group "Signal: Trend"
input int FastMAPeriod = 20;
input int SlowMAPeriod = 50;

input group "Signal: MeanReversion"
input int    RSI_Period     = 14;
input double RSI_Oversold   = 30.0;
input double RSI_Overbought = 70.0;
input int    BB_Period      = 20;
input double BB_Deviation   = 2.0;

input group "Signal: Breakout"
input int BreakoutLookbackBars = 20;

input group "Filters"
input bool   UseEMA200Filter     = true;
input int    EMA200_Period       = 200;
input bool   UseADXFilter        = true;
input int    ADX_Period          = 14;
input double ADX_Threshold       = 20.0;
input bool   UseATRFilter        = true;
input int    ATR_Period          = 14;
input double ATR_MinMultiplier   = 0.5;
input bool   UseH4Confirmation   = true;
input bool   UseRSIExtremeFilter = true;
input double RSI_ExtremeLevel    = 70.0;
input bool   UseMACDFilter       = true;
input int    MACD_Fast           = 12;
input int    MACD_Slow           = 26;
input int    MACD_Signal         = 9;

input group "Risk"
input double RiskPercentPerTrade     = 1.0;
input double MaxDailyDrawdownPercent = 3.0;
input int    MaxConcurrentTrades     = 1;
input int    TradingStartHour        = 7;
input int    TradingEndHour          = 20;

input group "Exits"
input double ATR_Multiplier_SL      = 1.5;
input double ATR_Multiplier_TP      = 3.0;
input bool   UseTrailingStop        = true;
input double TrailingATRMultiplier  = 1.5;
input bool   UsePartialTP           = true;
input double PartialTPAtrMultiplier = 1.0;
input double PartialClosePercent    = 50.0;
input bool   UseBreakeven           = true;
input double BreakevenTriggerPips   = 20.0;
input bool   UseEarlyReversalExit   = true;

input group "System"
input long MagicNumber = 20261110;

CTrade trade;

int h_FastMA, h_SlowMA, h_RSI, h_BB, h_ADX, h_ATR, h_MACD, h_EMA200;
int h_H4_EMA50, h_H4_EMA200;

datetime g_lastBarTime    = 0;
double   g_dayStartEquity = 0.0;
datetime g_dayStartStamp  = 0;
string   g_logFileName;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);

   h_FastMA    = iMA(_Symbol, _Period, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   h_SlowMA    = iMA(_Symbol, _Period, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   h_RSI       = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   h_BB        = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   h_ADX       = iADX(_Symbol, _Period, ADX_Period);
   h_ATR       = iATR(_Symbol, _Period, ATR_Period);
   h_MACD      = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   h_EMA200    = iMA(_Symbol, _Period, EMA200_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_H4_EMA50  = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   h_H4_EMA200 = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(h_FastMA == INVALID_HANDLE || h_SlowMA == INVALID_HANDLE || h_RSI == INVALID_HANDLE ||
      h_BB == INVALID_HANDLE || h_ADX == INVALID_HANDLE || h_ATR == INVALID_HANDLE ||
      h_MACD == INVALID_HANDLE || h_EMA200 == INVALID_HANDLE ||
      h_H4_EMA50 == INVALID_HANDLE || h_H4_EMA200 == INVALID_HANDLE)
     {
      Print("OmidotMultiStrategyEA: failed to create one or more indicator handles");
      return(INIT_FAILED);
     }

   g_logFileName = "OmidotEA_log_" + AccountInfoString(ACCOUNT_SERVER) + ".csv";
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayStartStamp  = TimeCurrent();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(h_FastMA);
   IndicatorRelease(h_SlowMA);
   IndicatorRelease(h_RSI);
   IndicatorRelease(h_BB);
   IndicatorRelease(h_ADX);
   IndicatorRelease(h_ATR);
   IndicatorRelease(h_MACD);
   IndicatorRelease(h_EMA200);
   IndicatorRelease(h_H4_EMA50);
   IndicatorRelease(h_H4_EMA200);
  }

//+------------------------------------------------------------------+
bool GetLastTwo(int handle, int bufferIndex, double &prevOut, double &currOut)
  {
   double buf[];
   if(CopyBuffer(handle, bufferIndex, 1, 2, buf) < 2)
      return false;
   currOut = buf[0];
   prevOut = buf[1];
   return true;
  }

bool GetLastOne(int handle, int bufferIndex, double &outValue)
  {
   double buf[];
   if(CopyBuffer(handle, bufferIndex, 1, 1, buf) < 1)
      return false;
   outValue = buf[0];
   return true;
  }

double GetAtrAverage(int lookback)
  {
   double buf[];
   if(CopyBuffer(h_ATR, 0, 1, lookback, buf) < lookback)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < lookback; i++)
      sum += buf[i];
   return sum / lookback;
  }

ENUM_TRADE_DIRECTION GetH4TrendDirection()
  {
   double ema50 = 0.0, ema200 = 0.0;
   if(!GetLastOne(h_H4_EMA50, 0, ema50) || !GetLastOne(h_H4_EMA200, 0, ema200))
      return DIR_NONE;
   if(ema50 > ema200)
      return DIR_BUY;
   if(ema50 < ema200)
      return DIR_SELL;
   return DIR_NONE;
  }

//+------------------------------------------------------------------+
ENUM_TRADE_DIRECTION EvaluateEntrySignal()
  {
   if(TradingMode == MODE_TREND)
     {
      double fastPrev, fastCurr, slowPrev, slowCurr;
      if(!GetLastTwo(h_FastMA, 0, fastPrev, fastCurr) || !GetLastTwo(h_SlowMA, 0, slowPrev, slowCurr))
         return DIR_NONE;
      return GetSignal_Trend(fastPrev, fastCurr, slowPrev, slowCurr);
     }

   if(TradingMode == MODE_MEAN_REVERSION)
     {
      double rsiPrev, rsiCurr;
      if(!GetLastTwo(h_RSI, 0, rsiPrev, rsiCurr))
         return DIR_NONE;
      double bbUpper, bbLower, closePrice;
      if(!GetLastOne(h_BB, 1, bbUpper) || !GetLastOne(h_BB, 2, bbLower))
         return DIR_NONE;
      double closeBuf[];
      if(CopyClose(_Symbol, _Period, 1, 1, closeBuf) < 1)
         return DIR_NONE;
      closePrice = closeBuf[0];
      return GetSignal_MeanReversion(rsiPrev, rsiCurr, RSI_Oversold, RSI_Overbought, closePrice, bbUpper, bbLower);
     }

   // MODE_BREAKOUT
   double closeBuf2[];
   if(CopyClose(_Symbol, _Period, 1, 1, closeBuf2) < 1)
      return DIR_NONE;
   double closePrice2 = closeBuf2[0];

   int idxHigh = iHighest(_Symbol, _Period, MODE_HIGH, BreakoutLookbackBars, 2);
   int idxLow  = iLowest(_Symbol, _Period, MODE_LOW, BreakoutLookbackBars, 2);
   if(idxHigh < 0 || idxLow < 0)
      return DIR_NONE;

   double highBuf[], lowBuf[];
   if(CopyHigh(_Symbol, _Period, idxHigh, 1, highBuf) < 1)
      return DIR_NONE;
   if(CopyLow(_Symbol, _Period, idxLow, 1, lowBuf) < 1)
      return DIR_NONE;

   return GetSignal_Breakout(closePrice2, highBuf[0], lowBuf[0]);
  }

//+------------------------------------------------------------------+
bool BuildFilterInputs(ENUM_TRADE_DIRECTION signalDir, FilterInputs &outInputs)
  {
   double closeBuf[];
   if(CopyClose(_Symbol, _Period, 1, 1, closeBuf) < 1)
      return false;
   outInputs.price = closeBuf[0];

   if(!GetLastOne(h_EMA200, 0, outInputs.ema200))
      return false;

   double adxPrev;
   if(!GetLastTwo(h_ADX, 0, adxPrev, outInputs.adxValue))
      return false;
   outInputs.adxThreshold = ADX_Threshold;

   if(!GetLastOne(h_ATR, 0, outInputs.atrValue))
      return false;
   outInputs.atrAverage      = GetAtrAverage(ATR_Period);
   outInputs.atrMinMultiplier = ATR_MinMultiplier;

   outInputs.h4TrendDirection = GetH4TrendDirection();

   double rsiPrevUnused;
   if(!GetLastTwo(h_RSI, 0, rsiPrevUnused, outInputs.rsiValue))
      return false;
   outInputs.rsiExtremeLevel = RSI_ExtremeLevel;

   double macdMainPrevUnused, macdSignalValue;
   if(!GetLastTwo(h_MACD, 0, macdMainPrevUnused, outInputs.macdMain))
      return false;
   if(!GetLastOne(h_MACD, 1, macdSignalValue))
      return false;
   outInputs.macdSignal = macdSignalValue;

   return true;
  }

//+------------------------------------------------------------------+
int CountEAPositions()
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
void TryOpenNewPosition()
  {
   MqlDateTime nowStruct;
   TimeToStruct(TimeCurrent(), nowStruct);
   if(nowStruct.hour < TradingStartHour || nowStruct.hour >= TradingEndHour)
      return;

   if(IsDailyDrawdownLocked(g_dayStartEquity, AccountInfoDouble(ACCOUNT_EQUITY), MaxDailyDrawdownPercent))
      return;

   if(CountEAPositions() >= MaxConcurrentTrades)
      return;

   ENUM_TRADE_DIRECTION signalDir = EvaluateEntrySignal();
   if(signalDir == DIR_NONE)
      return;

   FilterInputs filterInputs;
   if(!BuildFilterInputs(signalDir, filterInputs))
      return;

   FilterToggles toggles;
   toggles.useEMA200         = UseEMA200Filter;
   toggles.useADX            = UseADXFilter;
   toggles.useATR            = UseATRFilter;
   toggles.useH4Confirmation = UseH4Confirmation;
   toggles.useRSIExtreme     = UseRSIExtremeFilter;
   toggles.useMACD           = UseMACDFilter;

   if(!PassesFilters(signalDir, TradingMode, filterInputs, toggles))
      return;

   double atrValue;
   if(!GetLastOne(h_ATR, 0, atrValue))
      return;

   double entryPrice = (signalDir == DIR_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDistancePrice = atrValue * ATR_Multiplier_SL;
   double tpDistancePrice = atrValue * ATR_Multiplier_TP;

   double sl = (signalDir == DIR_BUY) ? entryPrice - slDistancePrice : entryPrice + slDistancePrice;
   double tp = (signalDir == DIR_BUY) ? entryPrice + tpDistancePrice : entryPrice - tpDistancePrice;

   double slDistancePoints = slDistancePrice / _Point;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lot = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE), RiskPercentPerTrade,
                                  slDistancePoints, tickValue, tickSize, _Point,
                                  lotStep, minLot, maxLot);

   if(lot <= 0.0)
      return;

   bool sent = (signalDir == DIR_BUY) ? trade.Buy(lot, _Symbol, 0.0, sl, tp, "OmidotEA")
                                       : trade.Sell(lot, _Symbol, 0.0, sl, tp, "OmidotEA");

   LogEvent(g_logFileName, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
            "ENTRY", (sent ? "order sent" : "order failed") + StringFormat(" dir=%d lot=%.2f", signalDir, lot));
  }

//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   double macdMainPrev, macdMainCurr;
   GetLastTwo(h_MACD, 0, macdMainPrev, macdMainCurr);
   double macdSignalPrev, macdSignalCurr;
   GetLastTwo(h_MACD, 1, macdSignalPrev, macdSignalCurr);

   double rsiPrev, rsiCurr;
   GetLastTwo(h_RSI, 0, rsiPrev, rsiCurr);

   double atrValue;
   GetLastOne(h_ATR, 0, atrValue);
   double atrPoints = atrValue / _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      ENUM_TRADE_DIRECTION posDir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? DIR_BUY : DIR_SELL;
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = PositionGetDouble(POSITION_SL);
      double currentPrice = (posDir == DIR_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(UseEarlyReversalExit &&
         ShouldEarlyExit(posDir, macdMainPrev, macdSignalPrev, macdMainCurr, macdSignalCurr,
                          rsiPrev, rsiCurr, RSI_ExtremeLevel))
        {
         trade.PositionClose(ticket);
         LogEvent(g_logFileName, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                   "EXIT", StringFormat("early_reversal_exit ticket=%I64u", ticket));
         continue;
        }

      double profitPoints = (posDir == DIR_BUY) ? (currentPrice - entryPrice) / _Point
                                                 : (entryPrice - currentPrice) / _Point;

      string partialKey = "Omidot_Partial_" + IntegerToString((long)ticket);
      bool alreadyPartial = GlobalVariableCheck(partialKey);

      if(UsePartialTP && ShouldPartialClose(profitPoints, atrPoints, PartialTPAtrMultiplier, alreadyPartial))
        {
         double closeVolume = NormalizeDouble(volume * (PartialClosePercent / 100.0), 2);
         if(closeVolume > 0.0 && closeVolume < volume)
           {
            trade.PositionClosePartial(ticket, closeVolume);
            GlobalVariableSet(partialKey, 1.0);
            double spreadPoints = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
            double breakevenSL = ComputeBreakevenSL(posDir, entryPrice, spreadPoints, _Point);
            trade.PositionModify(ticket, breakevenSL, PositionGetDouble(POSITION_TP));
            LogEvent(g_logFileName, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                      "EXIT", StringFormat("partial_close ticket=%I64u volume=%.2f", ticket, closeVolume));
            continue;
           }
        }

      if(UseBreakeven && !alreadyPartial && profitPoints >= BreakevenTriggerPips)
        {
         double spreadPoints2 = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
         double breakevenSL2 = ComputeBreakevenSL(posDir, entryPrice, spreadPoints2, _Point);
         bool slNotYetAtBreakeven = (posDir == DIR_BUY) ? (currentSL < breakevenSL2) : (currentSL > breakevenSL2 || currentSL == 0.0);
         if(slNotYetAtBreakeven)
            trade.PositionModify(ticket, breakevenSL2, PositionGetDouble(POSITION_TP));
        }

      if(UseTrailingStop)
        {
         double newSL = ComputeTrailingSL(posDir, currentPrice, atrValue, TrailingATRMultiplier, currentSL);
         if(newSL != currentSL)
            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsNewServerDay(g_dayStartStamp, TimeCurrent()))
     {
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dayStartStamp   = TimeCurrent();
     }

   ManageOpenPositions();

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   TryOpenNewPosition();
  }
//+------------------------------------------------------------------+
```

- [ ] **Step 2: Compile and verify it passes**

```bash
"/c/Program Files/MetaTrader 5/MetaEditor64.exe" /compile:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\MQL5\Experts\Omidot\OmidotMultiStrategyEA.mq5" /log:"D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log"
powershell -Command "Get-Content -Encoding Unicode 'D:\BOT TRADE\.claude\worktrees\mt5-multi-strategy-ea\build.log'"
```

Expected: `Result: 0 errors, 0 warnings, ...` (confirmed on this exact file during plan preparation).

**Known limitation to document, not fix (YAGNI):** partial-close state is tracked per ticket via a terminal global variable (`Omidot_Partial_<ticket>`), which persists across EA restarts on this terminal but is not part of position history — if the user manually deletes it or runs the EA on a different terminal installation mid-trade, a position could be partial-closed a second time. This is an acceptable edge case for a single-terminal live EA, not a defect to engineer around.

> **Note:** the manual Strategy Tester smoke test (Navigator-based) requires the MT5 terminal to see this file, which requires the post-merge junction described in Task 1's note. That manual test is therefore performed after this branch merges into `main`, not here — see the branch-finishing step at the end of this plan's execution.

- [ ] **Step 3: Commit and push the feature branch**

```bash
cd "D:/BOT TRADE/.claude/worktrees/mt5-multi-strategy-ea"
git add MQL5/Experts/Omidot/OmidotMultiStrategyEA.mq5
git commit -m "Add OmidotMultiStrategyEA: wires signals, filters, risk, and exits into a live EA"
git push origin worktree-mt5-multi-strategy-ea
```
