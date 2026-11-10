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
