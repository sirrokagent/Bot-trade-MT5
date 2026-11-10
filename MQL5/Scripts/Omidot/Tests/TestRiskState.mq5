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
