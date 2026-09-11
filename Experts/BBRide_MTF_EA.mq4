//+------------------------------------------------------------------+
//|                                              BBRide_MTF_EA.mq4    |
//|  EA MT4 - "D dang du day BB" + H1 hoi MA10/BB giua + M5 2 day tang|
//|                                                                   |
//|  BO KHUNG THAY DOI DUOC (InpPreset):                              |
//|   0 SWING   : MN1+W1 > D1 du day BB > H1 hoi  > M5 vao lenh       |
//|   1 INTRADAY: W1+D1  > H4 du day BB > M15 hoi > M5 vao lenh       |
//|   2 TU CHON : tu dat 4 khung                                      |
//|                                                                   |
//|  CHIEU BUY:                                                       |
//|   1. Hai khung lon xu huong TANG, chua cham khang cu              |
//|   2. Khung "du day" bam dai TREN BB                               |
//|   3. Khung hoi ve MA10 / BB giua ma khong gay xu huong            |
//|   4. M5/M1 tich luy, tao 2 DAY TANG DAN                           |
//|   5. Pha LEN neckline VA vuot LEN duong trend nhip hoi -> BUY     |
//|      SL duoi day 2                                                |
//|                                                                   |
//|  CHIEU SELL (doi xung):                                           |
//|   1. Hai khung lon xu huong GIAM, chua cham ho tro                |
//|   2. Khung "du day" bam dai DUOI BB                               |
//|   3. Khung hoi LEN MA10 / BB giua ma khong gay xu huong           |
//|   4. M5/M1 tich luy, tao 2 DINH GIAM DAN                          |
//|   5. Pha XUONG neckline VA xuyen XUONG duong trend nhip hoi ->    |
//|      SELL, SL tren dinh 2                                         |
//|                                                                   |
//|  KY LUAT VON (bat buoc, khong the tat bang tay khi dang chay):    |
//|   - Lot = (Balance x Risk%) / (SL pips x gia tri 1 pip cua 1 lot) |
//|   - Dung trade khi lo qua % gioi han trong ngay                   |
//|   - Dung trade sau N lenh thua lien tiep                          |
//|   - KHONG tang lot de go, KHONG noi rong SL, KHONG binh quan gia  |
//|   - Chi vao lenh khi RR thuc te >= RR toi thieu                   |
//+------------------------------------------------------------------+
#property copyright "BBRide MTF"
#property link      ""
#property version   "1.50"
#property strict

#include <BBRide/BBRideCore.mqh>

//--- ================= CHE DO GIAO DICH ============================
input string  __g0__            = "===== CHE DO GIAO DICH =====";
input int     InpTradeMode      = 0;       // 0 = ca hai chieu | 1 = chi BUY | 2 = chi SELL

//--- ================= BO KHUNG THOI GIAN ==========================
input string  __g0b__           = "===== BO KHUNG THOI GIAN =====";
input int     InpPreset         = 0;       // 0 = SWING (MN1+W1>D1>H1>M5) | 1 = INTRADAY (W1+D1>H4>M15>M5) | 2 = TU CHON
input ENUM_TIMEFRAMES InpTfTrend1  = PERIOD_MN1; // [TU CHON] khung xu huong lon nhat
input ENUM_TIMEFRAMES InpTfTrend2  = PERIOD_W1;  // [TU CHON] khung xu huong 2 + quet khang cu/ho tro
input ENUM_TIMEFRAMES InpTfRide    = PERIOD_D1;  // [TU CHON] khung du day BB
input ENUM_TIMEFRAMES InpTfPullback= PERIOD_H1;  // [TU CHON] khung hoi ve MA10/BB giua

//--- ================= THAM SO KHUNG XU HUONG LON ==================
input string  __g1__            = "===== KHUNG XU HUONG LON =====";
input bool    InpUseMonthly     = true;    // Bat loc xu huong khung 1 (MN1/W1)
input int     InpMnFast         = 5;       // Khung 1: MA nhanh
input int     InpMnSlow         = 10;      // Khung 1: MA cham
input bool    InpUseWeekly      = true;    // Bat loc xu huong khung 2 (W1/D1)
input int     InpWFast          = 10;      // Khung 2: MA nhanh
input int     InpWSlow          = 20;      // Khung 2: MA cham
input ENUM_MA_METHOD InpMaMethod= MODE_EMA;// Phuong phap MA
input int     InpResLookback    = 60;      // So nen khung 2 quet khang cu/ho tro
input int     InpResDepth       = 2;       // Do sau fractal xac dinh dinh
input double  InpMinRoomATR     = 1.5;     // Khoang trong toi thieu toi khang cu (xATR W1)

//--- ================= THAM SO D1 - DU DAY BB =======================
input string  __g2__            = "===== D1 DU DAY BB =====";
input int     InpBBPeriod       = 20;      // Chu ky Bollinger
input double  InpBBDev          = 2.0;     // Do lech chuan BB
input int     InpDRideLookback  = 10;      // So phien D1 danh gia
input int     InpDMinRideBars   = 4;       // So phien toi thieu bam dai tren
input double  InpDRideThreshold = 0.80;    // %B toi thieu de tinh "bam dai" (0-1)
input bool    InpDReqExpansion  = true;    // Yeu cau BB dang mo rong

//--- ================= THAM SO H1 - PULLBACK =======================
input string  __g3__            = "===== H1 HOI VE TREND THUAN =====";
input int     InpPbMaPeriod     = 10;      // MA10 tren H1
input bool    InpPbUseBBMid     = true;    // Chap nhan cham BB giua H1
input double  InpPbTouchATR     = 0.35;    // Dung sai cham vung (xATR H1)
input int     InpPbBars = 6;       // So nen H1 gan nhat tim cu cham
input double  InpPbMinExtATR    = 1.0;     // Song tang truoc do toi thieu (xATR H1)
input int     InpPbTrendMa      = 50;      // MA loc xu huong H1

//--- ================= THAM SO KHUNG VAO LENH ======================
input string  __g4__            = "===== KHUNG VAO LENH (M5/M1) =====";
input ENUM_TIMEFRAMES InpEntryTF= PERIOD_M5; // Khung tim 2 day
input int     InpEntryLookback  = 80;      // So nen quet 2 day
input int     InpSwingDepth     = 2;       // Do sau fractal cho day
input double  InpMinHigherLow   = 0.0;     // Day 2 cao hon day 1 toi thieu (xATR)
input double  InpMaxHigherLow   = 4.0;     // Day 2 cao hon day 1 toi da (xATR)
input bool    InpReqContraction = true;    // Yeu cau bien do co lai (tich luy)
input bool    InpReqNeckBreak   = true;    // Yeu cau pha neckline (dinh/day giua 2 diem xoay)
input bool    InpReqTrendBreak  = true;    // Yeu cau VUOT DUONG TREND cua nhip hoi

//--- ================= KHOI LUONG & RISK/REWARD ====================
input string  __g5__            = "===== KHOI LUONG & RISK/REWARD =====";
input double  InpRiskPercent    = 1.0;     // % rui ro moi lenh (0 = dung lot co dinh)
input double  InpFixedLots      = 0.01;    // Lot co dinh khi RiskPercent = 0
input double  InpMaxLotCap      = 0.0;     // Tran khoi luong tuyet doi (0 = khong chan)
input double  InpSLBufferATR    = 0.5;     // Dem SL duoi day 2 (xATR khung vao lenh)
input double  InpRR             = 2.0;     // RR muc tieu cho TP
input double  InpMinRR          = 1.5;     // RR THUC TE toi thieu moi duoc vao lenh
input bool    InpTPAtResistance = true;    // Cat TP truoc khang cu W1

//--- ================= DANH SACH CAP DUOC PHEP =====================
input string  __g5b__           = "===== CHI DANH CAC CAP NAY =====";
input bool    InpUseWhitelist   = true;    // Chi cho phep chay tren danh sach duoi
input string  InpSymbolWhitelist= "GBPUSD,GBPAUD,GBPJPY,AUDUSD,EURUSD,EURAUD,EURJPY"; // Cach nhau dau phay

//--- ================= GIOI HAN THUA LO (KY LUAT) ==================
input string  __g6__            = "===== GIOI HAN THUA LO =====";
input double  InpMaxDailyLossPct= 2.0;     // Dung trade khi lo vuot % nay trong ngay (0 = tat)
input bool    InpCountFloating  = true;    // Tinh ca lo dang treo vao han muc ngay
input int     InpMaxConsecLoss  = 3;       // Dung trade sau N lenh thua lien tiep (0 = tat)
input int     InpMaxTradesPerDay= 3;       // So lenh toi da moi ngay (0 = khong gioi han)
input bool    InpAllowAveraging = false;   // Cho phep mo them lenh cung chieu (KHUYEN NGHI: false)
input bool    InpRiskScopeAll   = true;    // TRUE = tinh tran lo/chuoi thua TOAN TAI KHOAN (chay nhieu cap)
input int     InpMaxTradesTotal  = 3;      // Toi da lenh mo dong thoi TOAN TAI KHOAN (0 = tat)
input int     InpMaxSameCurrency = 2;      // Toi da lenh mo cung dong tien co so, vd GBPxxx (0 = tat)
input int     InpMaxTrades      = 1;       // So lenh mo dong thoi toi da

//--- ================= SAN PHAM BIEN DONG MANH =====================
input string  __g7__            = "===== XAUUSD / BTC / CRYPTO =====";
input bool    InpHighVolAuto    = true;    // Tu dong nhan dien va giam risk cho san pham bien dong manh
input double  InpHighVolFactor  = 0.5;     // He so nhan vao Risk% cho san pham do (0.5 = giam mot nua)
input string  InpHighVolKeys    = "XAU,GOLD,XAG,SILVER,BTC,XBT,ETH,CRYPTO"; // Tu khoa nhan dien (cach nhau dau phay)

//--- ================= THUC THI LENH ===============================
input string  __g8__            = "===== THUC THI LENH =====";
input double  InpMaxSpreadPips  = 3.0;     // Spread toi da cho phep (pip)
input int     InpSlippage       = 3;       // Slippage (point)
input int     InpMagic          = 20260910;// Magic number

//--- ================= QUAN LY LENH DANG MO ========================
input string  __g9__            = "===== QUAN LY LENH DANG MO =====";
input bool    InpBreakEvenAt1R  = true;    // Dua SL ve hoa von khi lai 1R
input bool    InpTrailBBMidH1   = true;    // Trailing theo BB giua cua khung hoi (H1/M15)
input bool    InpCloseOnH1Break = false;   // Dong lenh khi khung hoi dong cua gay BB giua

//--- ================= HIEN THI / CANH BAO =========================
input string  __g10__           = "===== HIEN THI / CANH BAO =====";
input bool    InpDryRun         = false;   // TRUE = chi canh bao, khong vao lenh
input bool    InpShowPanel      = true;    // Hien bang trang thai tren chart
input bool    InpAlertPopup     = true;    // Popup khi co tin hieu
input bool    InpAlertPush      = false;   // Push notification

//--- Bien toan cuc
BBRideSettings g_set;
BBRideSignal   g_sig;
datetime       g_lastEntryBar = 0;   // nen da vao lenh (tranh trung tin hieu)
datetime       g_lastCalcBar  = 0;   // nen da tinh toan gan nhat
datetime       g_haltAlertDay = 0;   // da canh bao dung trade cho ngay nao
string         g_blockReason  = "";  // ly do dang bi chan vao lenh

//+------------------------------------------------------------------+
int OnInit()
  {
   BBRideDefaults(g_set);

   g_set.useMonthly        = InpUseMonthly;
   g_set.mnFast            = InpMnFast;
   g_set.mnSlow            = InpMnSlow;
   g_set.useWeekly         = InpUseWeekly;
   g_set.wFast             = InpWFast;
   g_set.wSlow             = InpWSlow;
   g_set.maMethod          = InpMaMethod;
   g_set.resLookback       = InpResLookback;
   g_set.resFractalDepth   = InpResDepth;
   g_set.minRoomATR        = InpMinRoomATR;

   g_set.bbPeriod          = InpBBPeriod;
   g_set.bbDev             = InpBBDev;
   g_set.dRideLookback     = InpDRideLookback;
   g_set.dMinRideBars      = InpDMinRideBars;
   g_set.dRideThreshold    = InpDRideThreshold;
   g_set.dRequireExpansion = InpDReqExpansion;

   g_set.pbMaPeriod        = InpPbMaPeriod;
   g_set.pbUseBBMid        = InpPbUseBBMid;
   g_set.pbTouchATR        = InpPbTouchATR;
   g_set.pbBars    = InpPbBars;
   g_set.pbMinExtATR = InpPbMinExtATR;
   g_set.pbTrendMa         = InpPbTrendMa;

   g_set.entryLookback     = InpEntryLookback;
   g_set.swingDepth        = InpSwingDepth;
   g_set.minHigherLowATR   = InpMinHigherLow;
   g_set.maxHigherLowATR   = InpMaxHigherLow;
   g_set.requireContraction= InpReqContraction;
   g_set.requireNeckBreak  = InpReqNeckBreak;
   g_set.requireTrendBreak = InpReqTrendBreak;

   g_set.slBufferATR       = InpSLBufferATR;
   g_set.rr                = InpRR;
   g_set.tpAtResistance    = InpTPAtResistance;
   g_set.tradeMode         = InpTradeMode;

   //--- bo khung thoi gian: preset hoac tu chon
   if(InpPreset==BBRIDE_PRESET_CUSTOM)
     {
      g_set.tfTrend1   = (int)InpTfTrend1;
      g_set.tfTrend2   = (int)InpTfTrend2;
      g_set.tfRide     = (int)InpTfRide;
      g_set.tfPullback = (int)InpTfPullback;
     }
   else
      BBRideApplyPreset(g_set,InpPreset);

   //--- khung vao lenh luon lay theo InpEntryTF (preset chi dat 4 khung tren)
   g_set.entryTF = (int)InpEntryTF;

   //--- kiem tra tham so
   if(InpDMinRideBars>InpDRideLookback)
     {
      Print("Loi tham so: InpDMinRideBars phai <= InpDRideLookback");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpPreset<0 || InpPreset>2)
     {
      Print("Loi tham so: InpPreset chi nhan 0 (SWING), 1 (INTRADAY) hoac 2 (TU CHON)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!(g_set.tfTrend1>g_set.tfTrend2 && g_set.tfTrend2>g_set.tfRide &&
        g_set.tfRide>g_set.tfPullback && g_set.tfPullback>g_set.entryTF))
     {
      Print("Loi tham so: bo khung phai giam dan: ",
            BBRideTFName(g_set.tfTrend1)," > ",BBRideTFName(g_set.tfTrend2)," > ",
            BBRideTFName(g_set.tfRide)," > ",BBRideTFName(g_set.tfPullback)," > ",
            BBRideTFName(g_set.entryTF));
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpTradeMode<0 || InpTradeMode>2)
     {
      Print("Loi tham so: InpTradeMode chi nhan 0 (ca hai), 1 (chi BUY) hoac 2 (chi SELL)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMinRR<1.0)
     {
      Print("Loi tham so: InpMinRR < 1.0 - he thong nay khong chap nhan RR duoi 1:1");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRR<InpMinRR)
      Print("Canh bao: InpRR (",DoubleToString(InpRR,2),") thap hon InpMinRR (",
            DoubleToString(InpMinRR,2),") - hau het setup se bi loai");
   if(!SymbolAllowed())
     {
      Print("TU CHOI CHAY: ",Symbol()," khong nam trong danh sach cap duoc phep [",
            InpSymbolWhitelist,"]. Go EA khoi chart nay.");
      Comment("BBRide MTF: ",Symbol()," KHONG nam trong danh sach cap duoc phep.\n",
              "Danh sach: ",InpSymbolWhitelist);
      return(INIT_FAILED);
     }
   if(InpEntryTF!=PERIOD_M1 && InpEntryTF!=PERIOD_M5 && InpEntryTF!=PERIOD_M15)
      Print("Canh bao: khung vao lenh khuyen nghi M1/M5 (dang dung ",(int)InpEntryTF," phut)");
   if(InpRiskPercent<=0.0 && IsHighVolSymbol())
      Print("CANH BAO: ",Symbol()," la san pham bien dong manh - dung LOT CO DINH rat rui ro. ",
            "Nen dat InpRiskPercent > 0 de lot tu dong co giai theo do rong SL.");

   PrintFormat("BBRide MTF EA v1.50 | %s | %s | Khung: %s+%s > %s > %s > %s | Risk=%.2f%% (hieu luc %.2f%%) | RR>=%.2f | Tran lo ngay=%.2f%% (%s)",
               Symbol(),BBRideModeName(InpTradeMode),
               BBRideTFName(g_set.tfTrend1),BBRideTFName(g_set.tfTrend2),BBRideTFName(g_set.tfRide),
               BBRideTFName(g_set.tfPullback),BBRideTFName(g_set.entryTF),
               InpRiskPercent,EffectiveRiskPercent(),
               InpMinRR,InpMaxDailyLossPct,(InpRiskScopeAll?"toan tai khoan":"rieng symbol"));
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- quan ly lenh dang mo chay moi tick
   ManageOpenTrades();

   //--- chi danh gia tin hieu khi co nen moi tren khung vao lenh
   datetime curBar=iTime(Symbol(),g_set.entryTF,0);
   if(curBar==g_lastCalcBar) return;
   g_lastCalcBar=curBar;

   BBRideEvaluate(Symbol(),g_set,g_sig);

   //--- kiem tra hang rao ky luat (luon chay de hien thi tren panel)
   g_blockReason="";
   bool allowed=TradingAllowed(g_blockReason);

   if(InpShowPanel) Comment(BuildPanel());

   if(!g_sig.valid) return;
   if(g_sig.signalBar==g_lastEntryBar) return;      // tin hieu da xu ly

   NotifySignal();

   if(InpDryRun) { g_lastEntryBar=g_sig.signalBar; return; }

   if(!allowed)
     {
      Print("BO QUA TIN HIEU - ",g_blockReason);
      g_lastEntryBar=g_sig.signalBar;               // khong xu ly lai tin hieu nay
      return;
     }
   if(!SpreadOK())
     {
      Print("Bo qua tin hieu: spread qua rong (",DoubleToString(CurrentSpreadPips(),1)," pip)");
      return;
     }

   if(OpenTrade()) g_lastEntryBar=g_sig.signalBar;
  }

//+==================================================================+
//|                    KHOI QUAN TRI RUI RO                          |
//+==================================================================+

//+------------------------------------------------------------------+
//| Gia tri mot pip theo so digits cua broker                        |
//+------------------------------------------------------------------+
double PipSize()
  {
   int    d =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double pt=MarketInfo(Symbol(),MODE_POINT);
   if(d==3 || d==5) return(pt*10.0);   // broker 5 so le: 1 pip = 10 point
   return(pt);
  }
//+------------------------------------------------------------------+
//| GIA TRI 1 PIP CUA 1 LOT (tinh bang tien tai khoan)               |
//| = TickValue x (PipSize / TickSize)                               |
//+------------------------------------------------------------------+
double PipValuePerLot()
  {
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize =MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize<=0.0 || tickValue<=0.0) return(0.0);
   return(tickValue*(PipSize()/tickSize));
  }
//+------------------------------------------------------------------+
//| Symbol hien tai co nam trong danh sach duoc phep khong?          |
//| So khop kieu "chua chuoi" nen chap nhan hau to cua broker:       |
//| EURUSD.m, EURUSDpro, EURUSD_i ... deu khop "EURUSD"              |
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
//| Lenh dang xet co thuoc pham vi tinh rui ro khong?                |
//| InpRiskScopeAll = true  -> gop moi symbol co cung Magic          |
//| InpRiskScopeAll = false -> chi symbol cua chart nay              |
//+------------------------------------------------------------------+
bool InRiskScope()
  {
   if(OrderMagicNumber()!=InpMagic) return(false);
   if(!InpRiskScopeAll && OrderSymbol()!=Symbol()) return(false);
   return(true);
  }
//+------------------------------------------------------------------+
//| Nhan dien san pham bien dong manh (XAU, BTC, ...)                |
//+------------------------------------------------------------------+
bool IsHighVolSymbol()
  {
   if(!InpHighVolAuto) return(false);

   string sym=Symbol();
   StringToUpper(sym);
   string keys=InpHighVolKeys;
   StringToUpper(keys);

   string parts[];
   int n=StringSplit(keys,StringGetCharacter(",",0),parts);
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
//| Risk% hieu luc: giam cho san pham bien dong manh                 |
//| (XAUUSD/BTC khong duoc dung cung mot muc rui ro nhu forex)       |
//+------------------------------------------------------------------+
double EffectiveRiskPercent()
  {
   double r=InpRiskPercent;
   if(r>0.0 && IsHighVolSymbol()) r*=InpHighVolFactor;
   return(r);
  }
//+------------------------------------------------------------------+
//| CONG THUC TINH LOT                                               |
//|   Tien rui ro = Balance x Risk%                                  |
//|   Lot = Tien rui ro / (SL pips x Gia tri 1 pip cua 1 lot)        |
//+------------------------------------------------------------------+
double CalcLots(const double entry,const double sl,string &detail)
  {
   detail="";
   if(InpRiskPercent<=0.0)
     {
      detail=StringConcatenate("Lot co dinh ",DoubleToString(InpFixedLots,2));
      return(NormalizeLots(InpFixedLots));
     }

   double riskPct  =EffectiveRiskPercent();
   double riskMoney=AccountBalance()*riskPct/100.0;          // Tien rui ro
   double pip      =PipSize();
   double slPips   =(pip>0.0 ? MathAbs(entry-sl)/pip : 0.0); // SL tinh bang pip
   double pipValue =PipValuePerLot();                        // Gia tri 1 pip cua 1 lot

   if(slPips<=0.0 || pipValue<=0.0)
     {
      Print("Khong tinh duoc lot theo rui ro (slPips=",DoubleToString(slPips,1),
            ", pipValue=",DoubleToString(pipValue,2),") - dung lot co dinh");
      detail="Fallback lot co dinh";
      return(NormalizeLots(InpFixedLots));
     }

   double lots=riskMoney/(slPips*pipValue);

   detail=StringConcatenate("Risk ",DoubleToString(riskPct,2),"% = ",
                            DoubleToString(riskMoney,2)," | SL ",DoubleToString(slPips,1),
                            " pip | 1 pip/lot = ",DoubleToString(pipValue,2),
                            " | lot = ",DoubleToString(lots,2));
   return(NormalizeLots(lots));
  }
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot =MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot =MarketInfo(Symbol(),MODE_MAXLOT);
   double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(lotStep<=0.0) lotStep=0.01;

   lots=MathFloor(lots/lotStep)*lotStep;                 // lam tron XUONG - khong bao gio vuot risk
   if(InpMaxLotCap>0.0 && lots>InpMaxLotCap) lots=InpMaxLotCap;
   if(lots>maxLot) lots=maxLot;
   if(lots<minLot) lots=0.0;                             // khong du von cho lot toi thieu -> bo lenh
   return(NormalizeDouble(lots,2));
  }
//+------------------------------------------------------------------+
//| Moc dau ngay theo gio server                                     |
//+------------------------------------------------------------------+
datetime DayStart()
  {
   return(StringToTime(TimeToString(TimeCurrent(),TIME_DATE)));
  }
//+------------------------------------------------------------------+
//| Lai/lo da dong trong ngay + so lenh da vao trong ngay            |
//+------------------------------------------------------------------+
void DailyClosedStats(double &realized,int &tradesToday)
  {
   realized=0.0; tradesToday=0;
   datetime ds=DayStart();

   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime()<ds) continue;
      realized+=OrderProfit()+OrderSwap()+OrderCommission();
      tradesToday++;
     }
   //--- lenh mo trong ngay nhung chua dong cung tinh vao so lenh
   for(int j=OrdersTotal()-1;j>=0;j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderOpenTime()>=ds) tradesToday++;
     }
  }
//+------------------------------------------------------------------+
//| Lai/lo dang treo cua cac lenh EA                                 |
//+------------------------------------------------------------------+
double FloatingPL()
  {
   double pl=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      pl+=OrderProfit()+OrderSwap()+OrderCommission();
     }
   return(pl);
  }
//+------------------------------------------------------------------+
//| Dem so lenh THUA LIEN TIEP gan nhat                              |
//+------------------------------------------------------------------+
int ConsecutiveLosses()
  {
   //--- cache: chi quet lai khi so lenh trong lich su thay doi
   static int cachedHistory=-1;
   static int cachedValue=0;
   int histTotal=OrdersHistoryTotal();
   if(histTotal==cachedHistory) return(cachedValue);
   //--- lich su thay doi -> quet lai

   int      cnt=0;
   datetime cutoff=TimeCurrent()+86400;      // moc tren de bat dau quet lui

   for(int n=0;n<20;n++)                     // toi da 20 lenh gan nhat
     {
      datetime bestTime=0;
      double   bestPL=0.0;
      bool     found=false;

      for(int i=OrdersHistoryTotal()-1;i>=0;i--)
        {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
         if(!InRiskScope()) continue;
         if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
         datetime ct=OrderCloseTime();
         if(ct<=0 || ct>=cutoff) continue;
         if(ct>bestTime)
           {
            bestTime=ct;
            bestPL  =OrderProfit()+OrderSwap()+OrderCommission();
            found   =true;
           }
        }
      if(!found) break;
      if(bestPL<0.0) cnt++; else break;      // gap lenh khong thua -> dut chuoi
      cutoff=bestTime;
     }
   cachedHistory=histTotal;
   cachedValue=cnt;
   return(cnt);
  }
//+------------------------------------------------------------------+
//| % lo trong ngay so voi balance dau ngay                          |
//| (so duong = dang lo, so am = dang lai)                           |
//+------------------------------------------------------------------+
double DailyLossPercent(double &realized,double &floating,int &tradesToday)
  {
   DailyClosedStats(realized,tradesToday);
   floating=FloatingPL();

   double dayStartBalance=AccountBalance()-realized;   // balance truoc khi vao ngay giao dich
   if(dayStartBalance<=0.0) return(0.0);

   double total=realized+(InpCountFloating?floating:0.0);
   return(-total/dayStartBalance*100.0);
  }
//+------------------------------------------------------------------+
//| HANG RAO KY LUAT: co duoc phep vao lenh moi khong?               |
//+------------------------------------------------------------------+
bool TradingAllowed(string &reason)
  {
   reason="";

   //--- 0) cap giao dich phai nam trong danh sach cho phep
   if(!SymbolAllowed())
     { reason=Symbol()+" khong nam trong danh sach cap duoc phep"; return(false); }

   //--- 1) khong binh quan gia / khong mo them lenh cung chieu
   int openCnt=CountMyTrades();
   if(!InpAllowAveraging && openCnt>0)
     { reason="Da co lenh dang mo - khong binh quan gia"; return(false); }
   if(openCnt>=InpMaxTrades)
     { reason="Da dat so lenh mo toi da tren "+Symbol()+" ("+IntegerToString(InpMaxTrades)+")"; return(false); }

   //--- 1b) tran lenh mo toan tai khoan
   if(InpMaxTradesTotal>0)
     {
      int gCnt=CountOpenTradesGlobal();
      if(gCnt>=InpMaxTradesTotal)
        { reason="Da co "+IntegerToString(gCnt)+" lenh mo toan tai khoan (tran "+
                 IntegerToString(InpMaxTradesTotal)+")"; return(false); }
     }

   //--- 1c) chan cuoc cong don cung mot dong tien (GBPUSD+GBPAUD+GBPJPY = 3 lan long GBP)
   if(InpMaxSameCurrency>0)
     {
      int sCnt=CountOpenSameBase(g_sig.direction);
      if(sCnt>=InpMaxSameCurrency)
        { reason="Da co "+IntegerToString(sCnt)+" lenh dang "+
                 (g_sig.direction==BBRIDE_BUY?"long ":"short ")+BaseCurrency(Symbol())+
                 " (tran "+IntegerToString(InpMaxSameCurrency)+") - tranh cuoc cong don"; return(false); }
     }

   //--- 2) so lenh trong ngay
   double realized=0.0; int tradesToday=0;
   DailyClosedStats(realized,tradesToday);
   if(InpMaxTradesPerDay>0 && tradesToday>=InpMaxTradesPerDay)
     { reason="Da du "+IntegerToString(tradesToday)+" lenh trong ngay"; return(false); }

   //--- 3) tran lo trong ngay
   if(InpMaxDailyLossPct>0.0)
     {
      double rz=0.0,fl=0.0; int tdCnt=0;
      double lossPct=DailyLossPercent(rz,fl,tdCnt);
      if(lossPct>=InpMaxDailyLossPct)
        {
         reason="DUNG TRADE: lo "+DoubleToString(lossPct,2)+"% >= tran "+
                DoubleToString(InpMaxDailyLossPct,2)+"% trong ngay";
         AlertHaltOnce(reason);
         return(false);
        }
     }

   //--- 4) chuoi thua lien tiep
   if(InpMaxConsecLoss>0)
     {
      int cl=ConsecutiveLosses();
      if(cl>=InpMaxConsecLoss)
        {
         reason="DUNG TRADE: "+IntegerToString(cl)+" lenh thua lien tiep (tran "+
                IntegerToString(InpMaxConsecLoss)+") - nghi, review lai setup";
         AlertHaltOnce(reason);
         return(false);
        }
     }
   return(true);
  }
//+------------------------------------------------------------------+
//| Canh bao dung trade - moi ngay chi bao mot lan                   |
//+------------------------------------------------------------------+
void AlertHaltOnce(const string reason)
  {
   datetime ds=DayStart();
   if(g_haltAlertDay==ds) return;
   g_haltAlertDay=ds;
   Print(reason);
   if(InpAlertPopup) Alert(Symbol()," - ",reason);
   if(InpAlertPush)  SendNotification(Symbol()+" - "+reason);
  }
//+------------------------------------------------------------------+
double CurrentSpreadPips()
  {
   double sp =(MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID));
   double pip=PipSize();
   if(pip<=0.0) return(0.0);
   return(sp/pip);
  }
//+------------------------------------------------------------------+
bool SpreadOK()
  {
   if(InpMaxSpreadPips<=0.0) return(true);
   return(CurrentSpreadPips()<=InpMaxSpreadPips);
  }
//+------------------------------------------------------------------+
int CountMyTrades()
  {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()==OP_BUY || OrderType()==OP_SELL) n++;
     }
   return(n);
  }

//+==================================================================+
//|                       KHOI THUC THI LENH                         |
//+==================================================================+

//+------------------------------------------------------------------+
//| Dem lenh mo tren TOAN TAI KHOAN (cung Magic, moi symbol)         |
//+------------------------------------------------------------------+
int CountOpenTradesGlobal()
  {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()==OP_BUY || OrderType()==OP_SELL) n++;
     }
   return(n);
  }
//+------------------------------------------------------------------+
//| Dong tien co so cua symbol (3 ky tu dau), vd EURJPY -> EUR       |
//| Luu y: broker dat TIEN TO (mEURUSD) se cho ket qua sai           |
//+------------------------------------------------------------------+
string BaseCurrency(const string sym)
  {
   string s2=sym;
   StringToUpper(s2);
   if(StringLen(s2)<3) return(s2);
   return(StringSubstr(s2,0,3));
  }
//+------------------------------------------------------------------+
//| Dem lenh mo dang cuoc cung mot dong tien co so                   |
//| (GBPUSD + GBPAUD + GBPJPY deu la long GBP -> rui ro cong don)    |
//+------------------------------------------------------------------+
int CountOpenSameBase(const int dir)
  {
   string base=BaseCurrency(Symbol());
   int wanted=(dir==BBRIDE_BUY ? OP_BUY : OP_SELL);
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()!=wanted) continue;                  // chi cong don khi CUNG CHIEU
      if(BaseCurrency(OrderSymbol())==base) n++;
     }
   return(n);
  }
//+------------------------------------------------------------------+
//| Bao dam SL/TP ton trong STOPLEVEL cua broker                     |
//+------------------------------------------------------------------+
bool ValidateStops(const int dir,const double price,double &sl,double &tp)
  {
   int    digits =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double point  =MarketInfo(Symbol(),MODE_POINT);
   double minDist=MarketInfo(Symbol(),MODE_STOPLEVEL)*point;
   if(minDist<=0.0) minDist=2*point;

   if(dir==BBRIDE_BUY)
     {
      if(price-sl<minDist) sl=NormalizeDouble(price-minDist,digits);
      if(tp-price<minDist) return(false);            // TP qua gan -> bo setup
     }
   else
     {
      if(sl-price<minDist) sl=NormalizeDouble(price+minDist,digits);
      if(price-tp<minDist) return(false);
     }
   sl=NormalizeDouble(sl,digits);
   tp=NormalizeDouble(tp,digits);
   return(true);
  }
//+------------------------------------------------------------------+
//| Mo lenh BUY theo tin hieu                                        |
//+------------------------------------------------------------------+
bool OpenTrade()
  {
   int    dir    =g_sig.direction;
   int    opType =(dir==BBRIDE_BUY ? OP_BUY : OP_SELL);
   color  clrOrd =(dir==BBRIDE_BUY ? clrDodgerBlue : clrOrangeRed);
   string dirName=BBRideDirName(dir);
   double sl=g_sig.sl, tp=g_sig.tp;

   for(int attempt=0;attempt<3;attempt++)
     {
      RefreshRates();
      double price=(dir==BBRIDE_BUY ? MarketInfo(Symbol(),MODE_ASK) : MarketInfo(Symbol(),MODE_BID));
      double slTry=sl, tpTry=tp;
      if(!ValidateStops(dir,price,slTry,tpTry))
        {
         Print("Bo qua: TP khong dat khoang cach toi thieu cua broker");
         return(false);
        }

      //--- RR THUC TE tai gia khop, sau khi TP da bi can chan cat bot
      double riskDist=(dir==BBRIDE_BUY ? price-slTry : slTry-price);
      if(riskDist<=0.0) { Print("Bo qua: SL khong hop le"); return(false); }
      double rrEff=(dir==BBRIDE_BUY ? (tpTry-price) : (price-tpTry))/riskDist;
      if(rrEff<InpMinRR)
        {
         PrintFormat("Bo qua setup %s: RR thuc te %.2f < RR toi thieu %.2f",dirName,rrEff,InpMinRR);
         return(false);
        }

      string lotDetail="";
      double lots=CalcLots(price,slTry,lotDetail);
      if(lots<=0.0)
        {
         Print("Bo qua: khoi luong tinh ra = 0 (von khong du cho lot toi thieu voi SL nay). ",lotDetail);
         return(false);
        }

      int ticket=OrderSend(Symbol(),opType,lots,price,InpSlippage,slTry,tpTry,
                           "BBRide MTF "+dirName,InpMagic,0,clrOrd);
      if(ticket>0)
        {
         PrintFormat("MO %s #%d lots=%.2f entry=%s SL=%s TP=%s RR=%.2f | %s",
                     dirName,ticket,lots,
                     DoubleToString(price,Digits),DoubleToString(slTry,Digits),
                     DoubleToString(tpTry,Digits),rrEff,lotDetail);
         return(true);
        }

      int err=GetLastError();
      PrintFormat("OrderSend that bai (lan %d), loi %d",attempt+1,err);
      if(err==ERR_INVALID_STOPS || err==ERR_NOT_ENOUGH_MONEY || err==ERR_TRADE_DISABLED) break;
      Sleep(500);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Quan ly lenh dang mo                                             |
//| NGUYEN TAC: SL CHI DUOC DI CHUYEN THEO HUONG CO LOI.             |
//| Khong bao gio noi rong SL vi lenh dang am.                       |
//+------------------------------------------------------------------+
void ManageOpenTrades()
  {
   int    digits =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double point  =MarketInfo(Symbol(),MODE_POINT);
   double minDist=MarketInfo(Symbol(),MODE_STOPLEVEL)*point;
   double bid    =MarketInfo(Symbol(),MODE_BID);
   double ask    =MarketInfo(Symbol(),MODE_ASK);
   double bbMidPb=iBands(Symbol(),g_set.tfPullback,InpBBPeriod,InpBBDev,0,PRICE_CLOSE,MODE_MAIN,0);
   double closePb=iClose(Symbol(),g_set.tfPullback,1);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL) continue;

      double open =OrderOpenPrice();
      double sl   =OrderStopLoss();
      bool   isBuy=(type==OP_BUY);

      //--- thoat khi H1 dong cua gay trend thuan
      if(InpCloseOnH1Break)
        {
         bool broken=(isBuy ? closePb<bbMidPb : closePb>bbMidPb);
         if(broken)
           {
            double px=(isBuy?bid:ask);
            if(OrderClose(OrderTicket(),OrderLots(),px,InpSlippage,clrOrangeRed))
               Print("Dong lenh #",OrderTicket()," do ",BBRideTFName(g_set.tfPullback)," dong ",(isBuy?"duoi":"tren")," BB giua");
            continue;
           }
        }

      if(isBuy)
        {
         double newSl=sl;
         //--- hoa von khi lai 1R
         if(InpBreakEvenAt1R && sl<open)
           {
            double r=open-sl;
            if(r>0.0 && bid-open>=r) newSl=MathMax(newSl,open);
           }
         //--- trailing theo BB giua H1 (chi keo LEN)
         if(InpTrailBBMidH1 && bbMidPb>0.0 && bbMidPb>newSl && bbMidPb<bid-minDist)
            newSl=bbMidPb;
         //--- CHAN CUNG: SL khong bao gio lui ve sau
         if(newSl<sl) newSl=sl;

         newSl=NormalizeDouble(newSl,digits);
         if(newSl>sl+point && bid-newSl>minDist)
            if(!OrderModify(OrderTicket(),open,newSl,OrderTakeProfit(),0,clrGreen))
               Print("OrderModify that bai #",OrderTicket()," loi ",GetLastError());
        }
      else
        {
         //--- SL = 0 nghia la chua co SL: dung moc rat xa de logic keo xuong hoat dong
         double newSl=(sl>0.0 ? sl : ask+10000*point);
         //--- hoa von khi lai 1R
         if(InpBreakEvenAt1R && sl>open)
           {
            double r=sl-open;
            if(r>0.0 && open-ask>=r) newSl=MathMin(newSl,open);
           }
         //--- trailing theo BB giua H1 (chi keo XUONG)
         if(InpTrailBBMidH1 && bbMidPb>0.0 && bbMidPb<newSl && bbMidPb>ask+minDist)
            newSl=bbMidPb;
         //--- CHAN CUNG: SL khong bao gio noi rong len tren
         if(sl>0.0 && newSl>sl) newSl=sl;

         newSl=NormalizeDouble(newSl,digits);
         if((sl<=0.0 || newSl<sl-point) && newSl-ask>minDist)
            if(!OrderModify(OrderTicket(),open,newSl,OrderTakeProfit(),0,clrGreen))
               Print("OrderModify that bai #",OrderTicket()," loi ",GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
void NotifySignal()
  {
   double rr=0.0;
   double riskDist=(g_sig.direction==BBRIDE_BUY ? g_sig.entry-g_sig.sl : g_sig.sl-g_sig.entry);
   if(riskDist>0.0)
      rr=(g_sig.direction==BBRIDE_BUY ? g_sig.tp-g_sig.entry : g_sig.entry-g_sig.tp)/riskDist;

   string msg=StringConcatenate("BBRide ",BBRideDirName(g_sig.direction)," ",Symbol(),
                                " | Entry ",DoubleToString(g_sig.entry,Digits),
                                " | SL ",DoubleToString(g_sig.sl,Digits),
                                " | TP ",DoubleToString(g_sig.tp,Digits),
                                " | RR ",DoubleToString(rr,2));
   Print(msg);
   if(InpAlertPopup) Alert(msg);
   if(InpAlertPush)  SendNotification(msg);
  }
//+------------------------------------------------------------------+
//| Bang trang thai tren chart                                       |
//+------------------------------------------------------------------+
string BuildPanel()
  {
   string t=BBRideStatusText(Symbol(),g_set,g_sig);

   double realized=0.0,floating=0.0;
   int    tradesToday=0;
   double lossPct=DailyLossPercent(realized,floating,tradesToday);
   int    consec=ConsecutiveLosses();

   t+="---------------- QUAN TRI RUI RO ----------------\n";
   t+="Risk/lenh: "+DoubleToString(EffectiveRiskPercent(),2)+"%";
   if(IsHighVolSymbol()) t+=" (da giam x"+DoubleToString(InpHighVolFactor,2)+" - san pham bien dong manh)";
   t+="\n";
   t+="P/L ngay: "+DoubleToString(realized,2)+" da dong / "+DoubleToString(floating,2)+" dang treo  =>  ";
   t+=(lossPct>0.0? "lo "+DoubleToString(lossPct,2)+"%" : "lai "+DoubleToString(-lossPct,2)+"%");
   t+="  (tran "+DoubleToString(InpMaxDailyLossPct,2)+"%)\n";
   t+="Pham vi tinh rui ro: "+(InpRiskScopeAll?"TOAN TAI KHOAN (moi cap cung Magic)":"RIENG "+Symbol())+"\n";
   t+="Lenh hom nay: "+IntegerToString(tradesToday);
   if(InpMaxTradesPerDay>0) t+="/"+IntegerToString(InpMaxTradesPerDay);
   t+="  |  Thua lien tiep: "+IntegerToString(consec)+"/"+IntegerToString(InpMaxConsecLoss)+"\n";
   t+="Spread: "+DoubleToString(CurrentSpreadPips(),1)+" pip  |  Lenh mo: "+
      IntegerToString(CountMyTrades())+"/"+IntegerToString(InpMaxTrades)+" (cap nay)";
   t+="  |  Toan TK: "+IntegerToString(CountOpenTradesGlobal());
   if(InpMaxTradesTotal>0) t+="/"+IntegerToString(InpMaxTradesTotal);
   t+="  |  "+(g_sig.direction==BBRIDE_BUY?"Long ":"Short ")+BaseCurrency(Symbol())+": "+
      IntegerToString(CountOpenSameBase(g_sig.direction));
   if(InpMaxSameCurrency>0) t+="/"+IntegerToString(InpMaxSameCurrency);
   t+="\n";
   if(StringLen(g_blockReason)>0) t+=">>> CHAN VAO LENH: "+g_blockReason+"\n";
   t+=(InpDryRun?"CHE DO: CHI CANH BAO (DryRun)":"CHE DO: VAO LENH THAT")+"\n";
   t+="Cap nhat: "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   return(t);
  }
//+------------------------------------------------------------------+
