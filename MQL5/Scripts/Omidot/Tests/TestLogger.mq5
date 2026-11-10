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
