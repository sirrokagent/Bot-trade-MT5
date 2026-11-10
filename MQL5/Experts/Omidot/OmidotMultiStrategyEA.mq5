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
input bool   UseFixedLotSize         = true;
input double FixedLotSize            = 0.01;
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

   double lot;
   if(UseFixedLotSize)
     {
      lot = MathFloor(FixedLotSize / lotStep + 0.00000001) * lotStep;
      if(lot < minLot)
         lot = minLot;
      if(lot > maxLot)
         lot = maxLot;
     }
   else
     {
      lot = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE), RiskPercentPerTrade,
                              slDistancePoints, tickValue, tickSize, _Point,
                              lotStep, minLot, maxLot);
     }

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
   double macdSignalPrev, macdSignalCurr;
   double rsiPrev, rsiCurr;
   double atrValue;

   if(!GetLastTwo(h_MACD, 0, macdMainPrev, macdMainCurr) ||
      !GetLastTwo(h_MACD, 1, macdSignalPrev, macdSignalCurr) ||
      !GetLastTwo(h_RSI, 0, rsiPrev, rsiCurr) ||
      !GetLastOne(h_ATR, 0, atrValue))
      return;
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

      double pipSize = _Point * ((_Digits == 3 || _Digits == 5) ? 10.0 : 1.0);
      if(UseBreakeven && !alreadyPartial && (profitPoints * _Point) >= BreakevenTriggerPips * pipSize)
        {
         double spreadPoints2 = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
         double breakevenSL2 = ComputeBreakevenSL(posDir, entryPrice, spreadPoints2, _Point);
         bool slNotYetAtBreakeven = (posDir == DIR_BUY) ? (currentSL < breakevenSL2) : (currentSL > breakevenSL2 || currentSL == 0.0);
         if(slNotYetAtBreakeven)
           {
            trade.PositionModify(ticket, breakevenSL2, PositionGetDouble(POSITION_TP));
            currentSL = breakevenSL2;
           }
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
