//+------------------------------------------------------------------+
//|                                        BBRide_MTF_Signal.mq4      |
//|  Indicator canh bao (khong vao lenh) - HAI CHIEU:                 |
//|   BUY : MN1/W1 tang  -> D1 du day dai TREN BB -> H1 hoi xuong     |
//|         MA10/BB giua -> M5/M1 tao 2 DAY TANG DAN -> pha LEN neck  |
//|   SELL: MN1/W1 giam  -> D1 du day dai DUOI BB -> H1 hoi len       |
//|         MA10/BB giua -> M5/M1 tao 2 DINH GIAM DAN -> pha XUONG    |
//|                                                                   |
//|  LUU Y: indicator danh gia trang thai THOI GIAN THUC tren nen     |
//|  hien tai (khong ve lai lich su), dung de canh bao setup.         |
//|  Muon backtest hay dung EA BBRide_MTF_EA trong Strategy Tester.   |
//+------------------------------------------------------------------+
#property copyright "BBRide MTF"
#property version   "1.50"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_color2  clrOrangeRed
#property indicator_width2  2

#include <BBRide/BBRideCore.mqh>

//--- Tham so (rut gon so voi EA, phan con lai dung mac dinh)
input int     InpTradeMode      = 0;         // 0 = ca hai chieu | 1 = chi BUY | 2 = chi SELL
input int     InpPreset         = 0;         // 0 = SWING (MN1+W1>D1>H1>M5) | 1 = INTRADAY (W1+D1>H1>M15>M5) | 2 = TU CHON
input ENUM_TIMEFRAMES InpTfTrend1  = PERIOD_MN1; // [TU CHON] khung xu huong lon nhat
input ENUM_TIMEFRAMES InpTfTrend2  = PERIOD_W1;  // [TU CHON] khung xu huong 2 + quet khang cu/ho tro
input ENUM_TIMEFRAMES InpTfRide    = PERIOD_D1;  // [TU CHON] khung du day BB
input ENUM_TIMEFRAMES InpTfPullback= PERIOD_H1;  // [TU CHON] khung hoi ve MA10/BB giua
input bool    InpUseMonthly     = true;      // Loc xu huong MN1
input bool    InpUseWeekly      = true;      // Loc xu huong W1
input double  InpMinRoomATR     = 1.5;       // Khoang trong toi khang cu/ho tro (xATR W1)
input int     InpBBPeriod       = 20;        // Chu ky BB
input double  InpBBDev          = 2.0;       // Do lech chuan BB
input int     InpDRideLookback  = 10;        // So phien D1 danh gia
input int     InpDMinRideBars   = 4;         // So phien du day toi thieu
input double  InpDRideThreshold = 0.80;      // %B nguong (SELL dung 1 - nguong)
input int     InpPbMaPeriod     = 10;        // MA10 tren H1
input double  InpPbTouchATR     = 0.35;      // Dung sai cham vung (xATR H1)
input ENUM_TIMEFRAMES InpEntryTF= PERIOD_M5; // Khung tim 2 diem xoay
input int     InpEntryLookback  = 80;        // So nen quet
input int     InpSwingDepth     = 2;         // Do sau fractal
input bool    InpReqTrendBreak  = true;      // Yeu cau vuot duong trend cua nhip hoi
input double  InpRR             = 2.0;       // RR de tinh TP hien thi
input double  InpMinRR          = 1.5;       // RR toi thieu chap nhan
input double  InpRiskPercent    = 1.0;       // % rui ro de goi y khoi luong (0 = tat)
input bool    InpHighVolAuto    = true;      // Giam risk cho XAU/BTC/crypto
input double  InpHighVolFactor  = 0.5;       // He so risk cho san pham bien dong manh
input bool    InpUseWhitelist   = true;      // Chi canh bao tren danh sach cap duoi
input string  InpSymbolWhitelist= "GBPUSD,GBPAUD,GBPJPY,AUDUSD,EURUSD,EURAUD,EURJPY"; // Cach nhau dau phay
input bool    InpShowPanel      = true;      // Hien bang trang thai
input bool    InpDrawLevels     = true;      // Ve neckline / SL / TP
input bool    InpAlertPopup     = true;      // Popup canh bao
input bool    InpAlertPush      = false;     // Push notification

double         BuyBuf[];
double         SellBuf[];
BBRideSettings g_set;
BBRideSignal   g_sig;
datetime       g_lastAlertBar=0;
datetime       g_lastCalcBar =0;

#define OBJ_PREFIX "BBRide_"

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,BuyBuf);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,233);                 // mui ten len
   SetIndexEmptyValue(0,0.0);
   SetIndexLabel(0,"BBRide BUY");

   SetIndexBuffer(1,SellBuf);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,234);                 // mui ten xuong
   SetIndexEmptyValue(1,0.0);
   SetIndexLabel(1,"BBRide SELL");

   IndicatorShortName("BBRide MTF Signal");

   BBRideDefaults(g_set);
   g_set.tradeMode      = InpTradeMode;

   if(InpPreset==BBRIDE_PRESET_CUSTOM)
     {
      g_set.tfTrend1   = (int)InpTfTrend1;
      g_set.tfTrend2   = (int)InpTfTrend2;
      g_set.tfRide     = (int)InpTfRide;
      g_set.tfPullback = (int)InpTfPullback;
     }
   else
      BBRideApplyPreset(g_set,InpPreset);
   g_set.useMonthly     = InpUseMonthly;
   g_set.useWeekly      = InpUseWeekly;
   g_set.minRoomATR     = InpMinRoomATR;
   g_set.bbPeriod       = InpBBPeriod;
   g_set.bbDev          = InpBBDev;
   g_set.dRideLookback  = InpDRideLookback;
   g_set.dMinRideBars   = InpDMinRideBars;
   g_set.dRideThreshold = InpDRideThreshold;
   g_set.pbMaPeriod     = InpPbMaPeriod;
   g_set.pbTouchATR     = InpPbTouchATR;
   g_set.entryLookback  = InpEntryLookback;
   g_set.swingDepth     = InpSwingDepth;
   g_set.requireTrendBreak = InpReqTrendBreak;
   g_set.rr             = InpRR;
   g_set.entryTF        = (int)InpEntryTF;   // luon theo InpEntryTF, preset chi dat 4 khung tren

   if(InpTradeMode<0 || InpTradeMode>2)
     {
      Print("Loi tham so: InpTradeMode chi nhan 0, 1 hoac 2");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpPreset<0 || InpPreset>2)
     {
      Print("Loi tham so: InpPreset chi nhan 0, 1 hoac 2");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!(g_set.tfTrend1>g_set.tfTrend2 && g_set.tfTrend2>g_set.tfRide &&
        g_set.tfRide>g_set.tfPullback && g_set.tfPullback>g_set.entryTF))
     {
      Print("Loi tham so: bo khung phai giam dan");
      return(INIT_PARAMETERS_INCORRECT);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   DeleteLevels();
  }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
  {
   if(prev_calculated==0)
      for(int i=0;i<rates_total;i++) { BuyBuf[i]=0.0; SellBuf[i]=0.0; }

   //--- ngoai danh sach cap cho phep -> khong danh gia, khong canh bao
   if(!SymbolAllowed())
     {
      Comment("BBRide MTF: ",Symbol()," KHONG nam trong danh sach cap duoc phep.\n",
              "Danh sach: ",InpSymbolWhitelist);
      return(rates_total);
     }

   //--- chi danh gia lai khi co nen moi tren khung vao lenh
   datetime curBar=iTime(Symbol(),g_set.entryTF,0);
   if(curBar!=g_lastCalcBar)
     {
      g_lastCalcBar=curBar;
      BBRideEvaluate(Symbol(),g_set,g_sig);

      if(g_sig.valid && g_sig.signalBar!=g_lastAlertBar)
        {
         g_lastAlertBar=g_sig.signalBar;
         MarkSignal();
         if(InpDrawLevels) DrawLevels();

         string msg=StringConcatenate("BBRide ",BBRideDirName(g_sig.direction)," ",Symbol(),
                                      " | Entry ",DoubleToString(g_sig.entry,Digits),
                                      " | SL ",DoubleToString(g_sig.sl,Digits),
                                      " | TP ",DoubleToString(g_sig.tp,Digits));
         Print(msg);
         if(InpAlertPopup) Alert(msg);
         if(InpAlertPush)  SendNotification(msg);
        }
     }

   if(InpShowPanel)
      Comment(BBRideStatusText(Symbol(),g_set,g_sig)+SizingText());

   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Symbol co nam trong danh sach cap duoc phep khong?               |
//| So khop kieu "chua chuoi" -> chap nhan hau to broker (EURUSD.m)  |
//+------------------------------------------------------------------+
bool SymbolAllowed()
  {
   if(!InpUseWhitelist) return(true);
   string sym=Symbol();
   StringToUpper(sym);
   string list=InpSymbolWhitelist;
   StringToUpper(list);
   string parts[];
   int n=StringSplit(list,StringGetCharacter(",",0),parts);
   for(int i=0;i<n;i++)
     {
      string k=parts[i];
      StringTrimLeft(k); StringTrimRight(k);
      if(StringLen(k)==0) continue;
      if(StringFind(sym,k)>=0) return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
double PipSize()
  {
   int    d =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double pt=MarketInfo(Symbol(),MODE_POINT);
   if(d==3 || d==5) return(pt*10.0);
   return(pt);
  }
//+------------------------------------------------------------------+
double PipValuePerLot()
  {
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize =MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize<=0.0 || tickValue<=0.0) return(0.0);
   return(tickValue*(PipSize()/tickSize));
  }
//+------------------------------------------------------------------+
bool IsHighVolSymbol()
  {
   if(!InpHighVolAuto) return(false);
   string sym=Symbol();
   StringToUpper(sym);
   return(StringFind(sym,"XAU")>=0 || StringFind(sym,"GOLD")>=0 || StringFind(sym,"XAG")>=0 ||
          StringFind(sym,"BTC")>=0 || StringFind(sym,"XBT")>=0  || StringFind(sym,"ETH")>=0);
  }
//+------------------------------------------------------------------+
//| Goi y khoi luong:                                                |
//|   Tien rui ro = Balance x Risk%                                  |
//|   Lot = Tien rui ro / (SL pips x gia tri 1 pip cua 1 lot)        |
//+------------------------------------------------------------------+
string SizingText()
  {
   if(!g_sig.valid || InpRiskPercent<=0.0) return("");

   bool   isBuy=(g_sig.direction==BBRIDE_BUY);
   double risk =(isBuy ? g_sig.entry-g_sig.sl : g_sig.sl-g_sig.entry);
   if(risk<=0.0) return("");
   double rr   =(isBuy ? g_sig.tp-g_sig.entry : g_sig.entry-g_sig.tp)/risk;

   double riskPct=InpRiskPercent;
   if(IsHighVolSymbol()) riskPct*=InpHighVolFactor;

   double riskMoney=AccountBalance()*riskPct/100.0;
   double pip      =PipSize();
   double slPips   =(pip>0.0 ? risk/pip : 0.0);
   double pipValue =PipValuePerLot();

   string t="---------------- GOI Y KHOI LUONG ----------------\n";
   t+="Chieu: "+BBRideDirName(g_sig.direction)+"  |  RR thuc te: "+DoubleToString(rr,2);
   t+=(rr<InpMinRR ? "  >>> THAP HON RR TOI THIEU "+DoubleToString(InpMinRR,2)+" - NEN BO SETUP" : "  (dat)");
   t+="\n";
   t+="Risk: "+DoubleToString(riskPct,2)+"%";
   if(IsHighVolSymbol()) t+=" (da giam cho san pham bien dong manh)";
   t+=" = "+DoubleToString(riskMoney,2)+"\n";
   t+="SL: "+DoubleToString(slPips,1)+" pip  |  1 pip/lot = "+DoubleToString(pipValue,2)+"\n";
   if(slPips>0.0 && pipValue>0.0)
      t+="=> Lot goi y: "+DoubleToString(riskMoney/(slPips*pipValue),2)+"\n";
   return(t);
  }
//+------------------------------------------------------------------+
//| Danh dau mui ten tai nen trigger (neu chart dang o khung vao lenh)|
//+------------------------------------------------------------------+
void MarkSignal()
  {
   if(Period()!=g_set.entryTF) return;         // chart khac khung -> chi canh bao
   int shift=iBarShift(Symbol(),Period(),g_sig.signalBar,true);
   if(shift<0 || shift>=Bars) return;

   double off=0.5*iATR(Symbol(),Period(),14,1);
   if(g_sig.direction==BBRIDE_BUY) BuyBuf[shift] =Low[shift]-off;
   else                            SellBuf[shift]=High[shift]+off;
  }
//+------------------------------------------------------------------+
void DrawLevels()
  {
   bool isBuy=(g_sig.direction==BBRIDE_BUY);
   DeleteLevels();
   DrawLine(OBJ_PREFIX+"neck",g_sig.neckline,clrGold,      STYLE_DASH,"Neckline");
   DrawLine(OBJ_PREFIX+"sl",  g_sig.sl,      clrOrangeRed, STYLE_DOT, "SL");
   DrawLine(OBJ_PREFIX+"tp",  g_sig.tp,      clrLimeGreen, STYLE_DOT, "TP");
   DrawLine(OBJ_PREFIX+"piv2",g_sig.piv2,    clrDodgerBlue,STYLE_DOT, (isBuy?"Day 2":"Dinh 2"));
   DrawTrendLine();
  }
//+------------------------------------------------------------------+
//| Ve duong trend cua nhip hoi vua bi pha vo                        |
//+------------------------------------------------------------------+
void DrawTrendLine()
  {
   if(g_sig.tlTime1<=0 || g_sig.tlTime2<=0) return;
   string nm=OBJ_PREFIX+"trend";
   if(ObjectFind(0,nm)<0)
      ObjectCreate(0,nm,OBJ_TREND,0,g_sig.tlTime1,g_sig.tlPrice1,g_sig.tlTime2,g_sig.tlPrice2);
   ObjectSetInteger(0,nm,OBJPROP_TIME1,g_sig.tlTime1);
   ObjectSetDouble (0,nm,OBJPROP_PRICE1,g_sig.tlPrice1);
   ObjectSetInteger(0,nm,OBJPROP_TIME2,g_sig.tlTime2);
   ObjectSetDouble (0,nm,OBJPROP_PRICE2,g_sig.tlPrice2);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clrMagenta);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);
   ObjectSetString (0,nm,OBJPROP_TEXT,"Trend nhip hoi");
  }
//+------------------------------------------------------------------+
void DrawLine(const string name,const double price,const color clr,
              const int style,const string text)
  {
   if(price<=0.0) return;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
  }
//+------------------------------------------------------------------+
void DeleteLevels()
  {
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     {
      string nm=ObjectName(0,i);
      if(StringFind(nm,OBJ_PREFIX)==0) ObjectDelete(0,nm);
     }
  }
//+------------------------------------------------------------------+
