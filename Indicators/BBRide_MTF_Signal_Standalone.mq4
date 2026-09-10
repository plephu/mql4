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
#property version   "1.30"
#property strict

//=== BAN STANDALONE: copy thang vao MQL4/Indicators/ va compile.  ===
//=== Khong can tao thu muc Include/BBRide.                    ===
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_color2  clrOrangeRed
#property indicator_width2  2

//+------------------------------------------------------------------+
//|  PHAN LOGIC LOI (nhung san - KHONG can file Include)              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                  BBRideCore.mqh   |
//|  Thu vien logic dung chung cho EA va Indicator - HAI CHIEU        |
//|                                                                   |
//|  CHIEU MUA (BUY):                                                 |
//|   1) MN1 + W1 xu huong TANG, GIA CHUA CHAM KHANG CU               |
//|   2) D1 "du day" dai TREN BB (dong cua bam dai tren nhieu phien)  |
//|   3) H1 hoi XUONG MA10 hoac BB giua ma khong gay xu huong         |
//|   4) M5/M1 tich luy tao 2 DAY TANG DAN                            |
//|   5) Pha LEN neckline (dinh giua 2 day) -> BUY                    |
//|                                                                   |
//|  CHIEU BAN (SELL) - doi xung hoan toan:                           |
//|   1) MN1 + W1 xu huong GIAM, GIA CHUA CHAM HO TRO                 |
//|   2) D1 "du day" dai DUOI BB (dong cua bam dai duoi nhieu phien)  |
//|   3) H1 hoi LEN MA10 hoac BB giua ma khong gay xu huong           |
//|   4) M5/M1 tich luy tao 2 DINH GIAM DAN                           |
//|   5) Pha XUONG neckline (day giua 2 dinh) -> SELL                 |
//+------------------------------------------------------------------+


#define BBRIDE_NO_LEVEL     9999.0   // khong tim thay khang cu / ho tro
#define BBRIDE_BUY          1
#define BBRIDE_SELL        -1

//--- Che do giao dich
#define BBRIDE_MODE_BOTH    0
#define BBRIDE_MODE_BUY     1
#define BBRIDE_MODE_SELL    2

//+------------------------------------------------------------------+
//| Bo tham so cau hinh                                              |
//+------------------------------------------------------------------+
struct BBRideSettings
  {
   //--- Che do
   int               tradeMode;         // 0=ca hai chieu, 1=chi BUY, 2=chi SELL
   //--- Tang 1: xu huong khung lon (MN1 / W1)
   bool              useMonthly;
   int               mnFast;
   int               mnSlow;
   bool              useWeekly;
   int               wFast;
   int               wSlow;
   ENUM_MA_METHOD    maMethod;
   //--- Khang cu / ho tro
   int               resLookback;
   int               resFractalDepth;
   double            minRoomATR;
   //--- Tang 2: D1 du day BB
   int               bbPeriod;
   double            bbDev;
   int               dRideLookback;
   int               dMinRideBars;
   double            dRideThreshold;    // BUY: %B >= nguong | SELL: %B <= 1-nguong
   bool              dRequireExpansion;
   //--- Tang 3: H1 pullback
   int               h1MaPeriod;
   bool              h1UseBBMid;
   double            h1TouchATR;
   int               h1PullbackBars;
   double            h1MinExtensionATR;
   int               h1TrendMa;
   //--- Tang 4-5: khung vao lenh
   int               entryTF;
   int               entryLookback;
   int               swingDepth;
   double            minHigherLowATR;   // BUY: day2 cao hon day1 | SELL: dinh2 thap hon dinh1
   double            maxHigherLowATR;
   bool              requireContraction;
   bool              requireNeckBreak;
   //--- Quan tri rui ro
   double            slBufferATR;
   double            rr;
   bool              tpAtResistance;    // cat TP tai khang cu (BUY) / ho tro (SELL)
  };

//+------------------------------------------------------------------+
//| Ket qua kiem tra tin hieu                                        |
//+------------------------------------------------------------------+
struct BBRideSignal
  {
   bool              valid;
   int               direction;      // BBRIDE_BUY (+1) hoac BBRIDE_SELL (-1)
   double            entry;
   double            sl;
   double            tp;
   double            piv1;           // diem xoay thu nhat (day/dinh cu)
   double            piv2;           // diem xoay thu hai (day cao hon / dinh thap hon)
   double            neckline;
   datetime          signalBar;
   //--- chan doan tung tang
   bool              okMonthly;
   bool              okWeekly;
   bool              okRoom;
   bool              okDailyRide;
   bool              okH1Pullback;
   bool              okDoubleBottom;
   bool              okTrigger;
   double            roomATR;
   double            dailyPB;
   int               dailyRideCount;
   double            h1Zone;
   string            note;
  };

//+------------------------------------------------------------------+
//| Gan tham so mac dinh                                             |
//+------------------------------------------------------------------+
void BBRideDefaults(BBRideSettings &s)
  {
   s.tradeMode         = BBRIDE_MODE_BOTH;
   s.useMonthly        = true;
   s.mnFast            = 5;
   s.mnSlow            = 10;
   s.useWeekly         = true;
   s.wFast             = 10;
   s.wSlow             = 20;
   s.maMethod          = MODE_EMA;
   s.resLookback       = 60;
   s.resFractalDepth   = 2;
   s.minRoomATR        = 1.5;
   s.bbPeriod          = 20;
   s.bbDev             = 2.0;
   s.dRideLookback     = 10;
   s.dMinRideBars      = 4;
   s.dRideThreshold    = 0.80;
   s.dRequireExpansion = true;
   s.h1MaPeriod        = 10;
   s.h1UseBBMid        = true;
   s.h1TouchATR        = 0.35;
   s.h1PullbackBars    = 6;
   s.h1MinExtensionATR = 1.0;
   s.h1TrendMa         = 50;
   s.entryTF           = PERIOD_M5;
   s.entryLookback     = 80;
   s.swingDepth        = 2;
   s.minHigherLowATR   = 0.0;
   s.maxHigherLowATR   = 4.0;
   s.requireContraction= true;
   s.requireNeckBreak  = true;
   s.slBufferATR       = 0.5;
   s.rr                = 2.0;
   s.tpAtResistance    = true;
  }

//+------------------------------------------------------------------+
//| Tien ich                                                         |
//+------------------------------------------------------------------+
bool BBRideHasBars(const string sym,const int tf,const int need)
  {
   return(iBars(sym,tf)>=need);
  }
//+------------------------------------------------------------------+
string BBRideDirName(const int dir)
  {
   return(dir==BBRIDE_BUY?"BUY":"SELL");
  }
//+------------------------------------------------------------------+
//| %B cua Bollinger: (Close - Lower) / (Upper - Lower)              |
//+------------------------------------------------------------------+
double BBRidePercentB(const string sym,const int tf,const int period,const double dev,const int shift)
  {
   double up =iBands(sym,tf,period,dev,0,PRICE_CLOSE,MODE_UPPER,shift);
   double lo =iBands(sym,tf,period,dev,0,PRICE_CLOSE,MODE_LOWER,shift);
   double cl =iClose(sym,tf,shift);
   double w  =up-lo;
   if(w<=0.0) return(0.5);
   return((cl-lo)/w);
  }

//+------------------------------------------------------------------+
//| TANG 1: xu huong khung lon theo chieu dir                        |
//|  BUY : MA nhanh > MA cham, MA nhanh doc len, gia > MA cham       |
//|  SELL: MA nhanh < MA cham, MA nhanh doc xuong, gia < MA cham     |
//+------------------------------------------------------------------+
bool BBRideTrendOK(const string sym,const int tf,const int fast,const int slow,
                   const ENUM_MA_METHOD method,const int dir)
  {
   if(!BBRideHasBars(sym,tf,slow+5)) return(false);

   double maF1=iMA(sym,tf,fast,0,method,PRICE_CLOSE,1);
   double maF3=iMA(sym,tf,fast,0,method,PRICE_CLOSE,3);
   double maS1=iMA(sym,tf,slow,0,method,PRICE_CLOSE,1);
   double maS3=iMA(sym,tf,slow,0,method,PRICE_CLOSE,3);
   double close1=iClose(sym,tf,1);

   if(dir==BBRIDE_BUY)
     {
      if(maF1<=maS1)   return(false);
      if(maF1<=maF3)   return(false);
      if(maS1<maS3)    return(false);
      if(close1<=maS1) return(false);
      return(true);
     }
   //--- SELL
   if(maF1>=maS1)   return(false);
   if(maF1>=maF3)   return(false);
   if(maS1>maS3)    return(false);
   if(close1>=maS1) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Fractal dinh / day                                               |
//+------------------------------------------------------------------+
bool BBRideIsSwingHigh(const string sym,const int tf,const int shift,const int depth)
  {
   double h=iHigh(sym,tf,shift);
   for(int k=1;k<=depth;k++)
     {
      if(iHigh(sym,tf,shift-k)>h) return(false);
      if(iHigh(sym,tf,shift+k)>h) return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
bool BBRideIsSwingLow(const string sym,const int tf,const int shift,const int depth)
  {
   double l=iLow(sym,tf,shift);
   for(int k=1;k<=depth;k++)
     {
      if(iLow(sym,tf,shift-k)<l) return(false);
      if(iLow(sym,tf,shift+k)<l) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 1b: can gan nhat theo huong di chuyen                       |
//|  BUY : khang cu (dinh fractal gan nhat PHIA TREN gia)            |
//|  SELL: ho tro   (day  fractal gan nhat PHIA DUOI gia)            |
//|  Tra ve 0 neu khong con can nao chan duong                       |
//+------------------------------------------------------------------+
double BBRideNearestLevel(const string sym,const int tf,const int lookback,
                          const int depth,const double price,const int dir)
  {
   if(!BBRideHasBars(sym,tf,lookback+depth+2)) return(0.0);

   double best=0.0;
   for(int i=depth+1;i<=lookback;i++)
     {
      if(dir==BBRIDE_BUY)
        {
         if(!BBRideIsSwingHigh(sym,tf,i,depth)) continue;
         double h=iHigh(sym,tf,i);
         if(h<=price) continue;
         if(best==0.0 || h<best) best=h;         // dinh THAP NHAT nam tren gia
        }
      else
        {
         if(!BBRideIsSwingLow(sym,tf,i,depth)) continue;
         double l=iLow(sym,tf,i);
         if(l>=price) continue;
         if(best==0.0 || l>best) best=l;         // day CAO NHAT nam duoi gia
        }
     }
   return(best);
  }

//+------------------------------------------------------------------+
//| Khoang trong toi can gan nhat, tinh theo ATR khung do            |
//+------------------------------------------------------------------+
double BBRideRoomATR(const string sym,const int tf,const BBRideSettings &s,
                     const int dir,double &levelOut)
  {
   double price=iClose(sym,tf,0);
   double atr  =iATR(sym,tf,14,1);
   levelOut=BBRideNearestLevel(sym,tf,s.resLookback,s.resFractalDepth,price,dir);

   if(atr<=0.0)      return(0.0);
   if(levelOut<=0.0) return(BBRIDE_NO_LEVEL);    // duong di trong hoan toan
   return(dir==BBRIDE_BUY ? (levelOut-price)/atr : (price-levelOut)/atr);
  }

//+------------------------------------------------------------------+
//| TANG 2: D1 dang "du day" theo chieu dir                          |
//|  BUY : %B >= nguong (bam dai TREN)                               |
//|  SELL: %B <= 1 - nguong (bam dai DUOI)                           |
//+------------------------------------------------------------------+
bool BBRideDailyRiding(const string sym,const BBRideSettings &s,const int dir,
                       int &rideCount,double &pbLast)
  {
   rideCount=0;
   pbLast=0.0;
   int need=s.bbPeriod+s.dRideLookback+5;
   if(!BBRideHasBars(sym,PERIOD_D1,need)) return(false);

   double loThreshold=1.0-s.dRideThreshold;

   for(int i=1;i<=s.dRideLookback;i++)
     {
      double pb=BBRidePercentB(sym,PERIOD_D1,s.bbPeriod,s.bbDev,i);
      if(i==1) pbLast=pb;
      if(dir==BBRIDE_BUY) { if(pb>=s.dRideThreshold) rideCount++; }
      else                { if(pb<=loThreshold)      rideCount++; }
     }
   if(rideCount<s.dMinRideBars) return(false);

   //--- BB giua phai doc dung chieu
   double midNow =iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,1);
   double midPast=iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.dRideLookback);
   double close1 =iClose(sym,PERIOD_D1,1);

   if(dir==BBRIDE_BUY)
     {
      if(midNow<=midPast) return(false);
      if(close1<=midNow)  return(false);
     }
   else
     {
      if(midNow>=midPast) return(false);
      if(close1>=midNow)  return(false);
     }

   //--- BB mo rong (chung cho ca hai chieu)
   if(s.dRequireExpansion)
     {
      double wNow =iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,1)
                  -iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,1);
      double wPast=iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,s.dRideLookback)
                  -iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,s.dRideLookback);
      if(wNow<wPast) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 3: H1 hoi ve MA10 / BB giua ma KHONG gay xu huong           |
//|  BUY : gia hoi XUONG vung, khong dong cua sau DUOI vung          |
//|  SELL: gia hoi LEN  vung, khong dong cua sau TREN vung           |
//+------------------------------------------------------------------+
bool BBRideH1Pullback(const string sym,const BBRideSettings &s,const int dir,double &zoneOut)
  {
   zoneOut=0.0;
   int need=MathMax(s.h1TrendMa,s.bbPeriod)+s.h1PullbackBars+30;
   if(!BBRideHasBars(sym,PERIOD_H1,need)) return(false);

   double atr=iATR(sym,PERIOD_H1,14,1);
   if(atr<=0.0) return(false);

   double ma10 =iMA(sym,PERIOD_H1,s.h1MaPeriod,0,s.maMethod,PRICE_CLOSE,0);
   double bbMid=iBands(sym,PERIOD_H1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,0);
   double bbMidPast=iBands(sym,PERIOD_H1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.h1PullbackBars+3);
   double trendMa=iMA(sym,PERIOD_H1,s.h1TrendMa,0,s.maMethod,PRICE_CLOSE,0);
   double close1 =iClose(sym,PERIOD_H1,1);

   //--- xu huong H1 phai con dung chieu
   if(dir==BBRIDE_BUY)
     {
      if(bbMid<=bbMidPast) return(false);
      if(close1<trendMa)   return(false);
     }
   else
     {
      if(bbMid>=bbMidPast) return(false);
      if(close1>trendMa)   return(false);
     }

   double tol  =s.h1TouchATR*atr;
   double price=iClose(sym,PERIOD_H1,0);

   //--- chon vung hoi gan gia nhat
   double zone=ma10;
   if(s.h1UseBBMid && MathAbs(price-bbMid)<MathAbs(price-ma10)) zone=bbMid;
   zoneOut=zone;

   if(dir==BBRIDE_BUY)
     {
      //--- 1) truoc do gia phai gian LEN khoi vung
      double maxHigh=0.0;
      for(int i=1;i<=s.h1PullbackBars+12;i++)
        {
         double h=iHigh(sym,PERIOD_H1,i);
         if(h>maxHigh) maxHigh=h;
        }
      if((maxHigh-zone)<s.h1MinExtensionATR*atr) return(false);

      //--- 2) co cu cham vung tu tren xuong
      bool touched=false;
      for(int j=0;j<=s.h1PullbackBars;j++)
         if(iLow(sym,PERIOD_H1,j)<=zone+tol) { touched=true; break; }
      if(!touched) return(false);

      //--- 3) chua gay: khong nen nao dong cua sau DUOI vung
      for(int k=1;k<=s.h1PullbackBars;k++)
         if(iClose(sym,PERIOD_H1,k)<zone-tol) return(false);
      return(true);
     }

   //--- SELL: doi xung
   double minLow=0.0;
   for(int i2=1;i2<=s.h1PullbackBars+12;i2++)
     {
      double l=iLow(sym,PERIOD_H1,i2);
      if(minLow==0.0 || l<minLow) minLow=l;
     }
   if((zone-minLow)<s.h1MinExtensionATR*atr) return(false);

   bool touched2=false;
   for(int j2=0;j2<=s.h1PullbackBars;j2++)
      if(iHigh(sym,PERIOD_H1,j2)>=zone-tol) { touched2=true; break; }
   if(!touched2) return(false);

   for(int k2=1;k2<=s.h1PullbackBars;k2++)
      if(iClose(sym,PERIOD_H1,k2)>zone+tol) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 4+5: M5/M1 - mo hinh 2 diem xoay + pha neckline             |
//|  BUY : 2 DAY TANG DAN, neckline = dinh giua, pha LEN             |
//|  SELL: 2 DINH GIAM DAN, neckline = day giua, pha XUONG           |
//+------------------------------------------------------------------+
bool BBRideSwingPattern(const string sym,const BBRideSettings &s,const int dir,const double h1Zone,
                        double &piv1,double &piv2,double &neckline,
                        datetime &sigBar,string &why)
  {
   piv1=0; piv2=0; neckline=0; sigBar=0; why="";
   int tf=s.entryTF;
   if(!BBRideHasBars(sym,tf,s.entryLookback+s.swingDepth+10))
     { why="Thieu du lieu khung vao lenh"; return(false); }

   double atr=iATR(sym,tf,14,1);
   if(atr<=0.0) { why="ATR khung vao lenh = 0"; return(false); }

   //--- quet 2 diem xoay gan nhat (day cho BUY, dinh cho SELL)
   int idx1=-1,idx2=-1;
   for(int i=s.swingDepth+1;i<=s.entryLookback;i++)
     {
      bool isPivot=(dir==BBRIDE_BUY ? BBRideIsSwingLow(sym,tf,i,s.swingDepth)
                                    : BBRideIsSwingHigh(sym,tf,i,s.swingDepth));
      if(!isPivot) continue;
      if(idx2<0) { idx2=i; continue; }
      if(idx1<0)
        {
         if(i-idx2<s.swingDepth+2) continue;
         idx1=i;
         break;
        }
     }
   if(idx1<0 || idx2<0)
     { why=(dir==BBRIDE_BUY?"Chua du 2 day swing":"Chua du 2 dinh swing"); return(false); }

   piv2=(dir==BBRIDE_BUY ? iLow(sym,tf,idx2) : iHigh(sym,tf,idx2));
   piv1=(dir==BBRIDE_BUY ? iLow(sym,tf,idx1) : iHigh(sym,tf,idx1));

   //--- BUY: day sau CAO HON | SELL: dinh sau THAP HON
   double diff=(dir==BBRIDE_BUY ? piv2-piv1 : piv1-piv2);
   if(diff<=0.0)
     { why=(dir==BBRIDE_BUY?"Day 2 khong cao hon day 1":"Dinh 2 khong thap hon dinh 1"); return(false); }
   if(diff<s.minHigherLowATR*atr) { why="Chenh lech 2 diem xoay khong dang ke"; return(false); }
   if(diff>s.maxHigherLowATR*atr) { why="Hai diem xoay qua xa nhau - khong phai tich luy"; return(false); }

   //--- diem xoay thu 2 phai nam trong vung hoi H1
   double zoneTol=MathMax(s.h1TouchATR*iATR(sym,PERIOD_H1,14,1),3.0*atr);
   if(h1Zone>0.0 && MathAbs(piv2-h1Zone)>zoneTol)
     { why="Diem xoay 2 khong nam tai vung hoi H1"; return(false); }

   //--- neckline: BUY = dinh cao nhat giua 2 day | SELL = day thap nhat giua 2 dinh
   for(int j=idx2;j<=idx1;j++)
     {
      if(dir==BBRIDE_BUY)
        {
         double h=iHigh(sym,tf,j);
         if(h>neckline) neckline=h;
        }
      else
        {
         double l=iLow(sym,tf,j);
         if(neckline==0.0 || l<neckline) neckline=l;
        }
     }

   //--- tich luy: bien do doan giua 2 diem xoay phai co lai
   if(s.requireContraction)
     {
      double rNow=0.0; int cNow=0;
      for(int a=idx2;a<=idx1;a++) { rNow+=(iHigh(sym,tf,a)-iLow(sym,tf,a)); cNow++; }
      double rPre=0.0; int cPre=0;
      for(int b=idx1+1;b<=MathMin(idx1+(idx1-idx2)+1,s.entryLookback);b++)
        { rPre+=(iHigh(sym,tf,b)-iLow(sym,tf,b)); cPre++; }
      if(cNow>0 && cPre>0)
        {
         double avgNow=rNow/cNow, avgPre=rPre/cPre;
         if(avgNow>avgPre*1.20) { why="Bien do chua co lai (chua tich luy)"; return(false); }
        }
     }

   //--- trigger: pha neckline dung chieu, bang nen vua dong
   if(s.requireNeckBreak)
     {
      int    digits=(int)MarketInfo(sym,MODE_DIGITS);
      double cl1=iClose(sym,tf,1);
      double cl2=iClose(sym,tf,2);
      if(dir==BBRIDE_BUY)
        {
         if(cl1<=neckline) { why="Chua pha LEN neckline "+DoubleToString(neckline,digits); return(false); }
         if(cl2>neckline)  { why="Da pha neckline tu truoc - bo qua"; return(false); }
        }
      else
        {
         if(cl1>=neckline) { why="Chua pha XUONG neckline "+DoubleToString(neckline,digits); return(false); }
         if(cl2<neckline)  { why="Da pha neckline tu truoc - bo qua"; return(false); }
        }
     }

   sigBar=iTime(sym,tf,1);
   why="OK";
   return(true);
  }

//+------------------------------------------------------------------+
//| Danh gia mot chieu cu the                                        |
//+------------------------------------------------------------------+
void BBRideEvaluateDir(const string sym,const BBRideSettings &s,const int dir,BBRideSignal &sig)
  {
   sig.valid=false; sig.direction=dir;
   sig.entry=0; sig.sl=0; sig.tp=0;
   sig.piv1=0; sig.piv2=0; sig.neckline=0; sig.signalBar=0;
   sig.okMonthly=false; sig.okWeekly=false; sig.okRoom=false;
   sig.okDailyRide=false; sig.okH1Pullback=false; sig.okDoubleBottom=false; sig.okTrigger=false;
   sig.roomATR=0; sig.dailyPB=0; sig.dailyRideCount=0; sig.h1Zone=0; sig.note="";

   string dirName=BBRideDirName(dir);

   //--- TANG 1: khung lon
   sig.okMonthly = (!s.useMonthly) || BBRideTrendOK(sym,PERIOD_MN1,s.mnFast,s.mnSlow,s.maMethod,dir);
   sig.okWeekly  = (!s.useWeekly)  || BBRideTrendOK(sym,PERIOD_W1, s.wFast, s.wSlow, s.maMethod,dir);
   if(!sig.okMonthly) { sig.note=dirName+": MN1 chua xac nhan xu huong"; return; }
   if(!sig.okWeekly)  { sig.note=dirName+": W1 chua xac nhan xu huong";  return; }

   //--- TANG 1b: con du khong gian toi can gan nhat
   double level=0.0;
   sig.roomATR=BBRideRoomATR(sym,PERIOD_W1,s,dir,level);
   sig.okRoom=(sig.roomATR>=s.minRoomATR);
   if(!sig.okRoom)
     {
      sig.note=dirName+": gia da sat "+(dir==BBRIDE_BUY?"khang cu":"ho tro")+
               " W1 ("+DoubleToString(sig.roomATR,2)+" ATR)";
      return;
     }

   //--- TANG 2: D1 du day BB
   sig.okDailyRide=BBRideDailyRiding(sym,s,dir,sig.dailyRideCount,sig.dailyPB);
   if(!sig.okDailyRide)
     {
      sig.note=dirName+": D1 chua du day BB ("+IntegerToString(sig.dailyRideCount)+"/"+
               IntegerToString(s.dMinRideBars)+" phien)";
      return;
     }

   //--- TANG 3: H1 hoi ve vung trend thuan
   sig.okH1Pullback=BBRideH1Pullback(sym,s,dir,sig.h1Zone);
   if(!sig.okH1Pullback)
     { sig.note=dirName+": H1 chua hoi ve MA"+IntegerToString(s.h1MaPeriod)+"/BB giua"; return; }

   //--- TANG 4+5: mo hinh 2 diem xoay + pha neckline
   string why="";
   sig.okDoubleBottom=BBRideSwingPattern(sym,s,dir,sig.h1Zone,sig.piv1,sig.piv2,sig.neckline,sig.signalBar,why);
   if(!sig.okDoubleBottom) { sig.note=dirName+": "+why; return; }
   sig.okTrigger=true;

   //--- Tinh entry / SL / TP
   int    digits=(int)MarketInfo(sym,MODE_DIGITS);
   double atrEntry=iATR(sym,s.entryTF,14,1);

   if(dir==BBRIDE_BUY)
     {
      sig.entry=MarketInfo(sym,MODE_ASK);
      sig.sl   =NormalizeDouble(sig.piv2-s.slBufferATR*atrEntry,digits);
      double risk=sig.entry-sig.sl;
      if(risk<=0.0) { sig.note="SL khong hop le"; sig.okTrigger=false; return; }

      sig.tp=NormalizeDouble(sig.entry+s.rr*risk,digits);
      if(s.tpAtResistance && level>0.0 && level<sig.tp)
         sig.tp=NormalizeDouble(level-0.2*atrEntry,digits);     // chot truoc khang cu
      if(sig.tp<=sig.entry) { sig.note=dirName+": TP bi khang cu chan - bo qua setup"; return; }
     }
   else
     {
      sig.entry=MarketInfo(sym,MODE_BID);
      sig.sl   =NormalizeDouble(sig.piv2+s.slBufferATR*atrEntry,digits);
      double risk=sig.sl-sig.entry;
      if(risk<=0.0) { sig.note="SL khong hop le"; sig.okTrigger=false; return; }

      sig.tp=NormalizeDouble(sig.entry-s.rr*risk,digits);
      if(s.tpAtResistance && level>0.0 && level>sig.tp)
         sig.tp=NormalizeDouble(level+0.2*atrEntry,digits);     // chot truoc ho tro
      if(sig.tp>=sig.entry) { sig.note=dirName+": TP bi ho tro chan - bo qua setup"; return; }
     }

   sig.valid=true;
   sig.note="DU DIEU KIEN VAO LENH "+dirName;
  }

//+------------------------------------------------------------------+
//| Diem so tien do cua mot tin hieu (dung de chon chieu hien thi)   |
//+------------------------------------------------------------------+
int BBRideScore(const BBRideSignal &sig)
  {
   int n=0;
   if(sig.okMonthly)      n++;
   if(sig.okWeekly)       n++;
   if(sig.okRoom)         n++;
   if(sig.okDailyRide)    n++;
   if(sig.okH1Pullback)   n++;
   if(sig.okDoubleBottom) n++;
   if(sig.valid)          n++;
   return(n);
  }

//+------------------------------------------------------------------+
//| HAM TONG: danh gia theo che do (ca hai chieu / chi mot chieu)    |
//+------------------------------------------------------------------+
void BBRideEvaluate(const string sym,const BBRideSettings &s,BBRideSignal &sig)
  {
   BBRideSignal sigBuy, sigSell;
   bool triedBuy=false, triedSell=false;

   if(s.tradeMode!=BBRIDE_MODE_SELL)
     {
      BBRideEvaluateDir(sym,s,BBRIDE_BUY,sigBuy);
      triedBuy=true;
      if(sigBuy.valid) { sig=sigBuy; return; }
     }
   if(s.tradeMode!=BBRIDE_MODE_BUY)
     {
      BBRideEvaluateDir(sym,s,BBRIDE_SELL,sigSell);
      triedSell=true;
      if(sigSell.valid) { sig=sigSell; return; }
     }

   //--- khong chieu nao du dieu kien: hien thi chieu di duoc xa hon
   if(triedBuy && triedSell)
      sig=(BBRideScore(sigSell)>BBRideScore(sigBuy) ? sigSell : sigBuy);
   else if(triedBuy)  sig=sigBuy;
   else               sig=sigSell;
  }

//+------------------------------------------------------------------+
//| Chuoi mo ta trang thai tung tang (dashboard)                     |
//+------------------------------------------------------------------+
string BBRideTick(const bool b)
  {
   return(b?"[OK]  ":"[--]  ");
  }
//+------------------------------------------------------------------+
string BBRideModeName(const int mode)
  {
   if(mode==BBRIDE_MODE_BUY)  return("CHI BUY");
   if(mode==BBRIDE_MODE_SELL) return("CHI SELL");
   return("CA HAI CHIEU");
  }
//+------------------------------------------------------------------+
string BBRideStatusText(const string sym,const BBRideSettings &s,const BBRideSignal &sig)
  {
   int    d  =(int)MarketInfo(sym,MODE_DIGITS);
   int    dir=sig.direction;
   bool   isBuy=(dir==BBRIDE_BUY);
   string dirName=BBRideDirName(dir);

   string t="";
   t+="=== BB RIDE MTF - "+sym+" | Che do: "+BBRideModeName(s.tradeMode)+" ===\n";
   t+="Dang xet chieu: "+dirName+(isBuy?"  (D du day dai TREN BB)":"  (D du day dai DUOI BB)")+"\n";
   t+=BBRideTick(sig.okMonthly)     +"1. MN1 xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okWeekly)      +"2. W1 xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okRoom)        +"3. Con khong gian toi "+(isBuy?"khang cu":"ho tro")+": "+
                                     DoubleToString(sig.roomATR,2)+" ATR\n";
   t+=BBRideTick(sig.okDailyRide)   +"4. D1 du day BB: "+IntegerToString(sig.dailyRideCount)+
                                     " phien, %B="+DoubleToString(sig.dailyPB,2)+"\n";
   t+=BBRideTick(sig.okH1Pullback)  +"5. H1 hoi ve vung "+DoubleToString(sig.h1Zone,d)+"\n";
   t+=BBRideTick(sig.okDoubleBottom)+"6. "+(isBuy?"2 day tang dan":"2 dinh giam dan")+
                                     " (M"+IntegerToString(s.entryTF)+")\n";
   if(sig.piv1>0)
      t+="        "+(isBuy?"day1=":"dinh1=")+DoubleToString(sig.piv1,d)+
         "  "+(isBuy?"day2=":"dinh2=")+DoubleToString(sig.piv2,d)+
         "  neck="+DoubleToString(sig.neckline,d)+"\n";
   t+=BBRideTick(sig.valid)         +"7. TRIGGER\n";
   if(sig.valid)
      t+="        "+dirName+" "+DoubleToString(sig.entry,d)+"  SL "+DoubleToString(sig.sl,d)+
         "  TP "+DoubleToString(sig.tp,d)+"\n";
   t+="Trang thai: "+sig.note+"\n";
   return(t);
  }

//+------------------------------------------------------------------+

//--- Tham so (rut gon so voi EA, phan con lai dung mac dinh)
input int     InpTradeMode      = 0;         // 0 = ca hai chieu | 1 = chi BUY | 2 = chi SELL
input bool    InpUseMonthly     = true;      // Loc xu huong MN1
input bool    InpUseWeekly      = true;      // Loc xu huong W1
input double  InpMinRoomATR     = 1.5;       // Khoang trong toi khang cu/ho tro (xATR W1)
input int     InpBBPeriod       = 20;        // Chu ky BB
input double  InpBBDev          = 2.0;       // Do lech chuan BB
input int     InpDRideLookback  = 10;        // So phien D1 danh gia
input int     InpDMinRideBars   = 4;         // So phien du day toi thieu
input double  InpDRideThreshold = 0.80;      // %B nguong (SELL dung 1 - nguong)
input int     InpH1MaPeriod     = 10;        // MA10 tren H1
input double  InpH1TouchATR     = 0.35;      // Dung sai cham vung (xATR H1)
input ENUM_TIMEFRAMES InpEntryTF= PERIOD_M5; // Khung tim 2 diem xoay
input int     InpEntryLookback  = 80;        // So nen quet
input int     InpSwingDepth     = 2;         // Do sau fractal
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
   g_set.useMonthly     = InpUseMonthly;
   g_set.useWeekly      = InpUseWeekly;
   g_set.minRoomATR     = InpMinRoomATR;
   g_set.bbPeriod       = InpBBPeriod;
   g_set.bbDev          = InpBBDev;
   g_set.dRideLookback  = InpDRideLookback;
   g_set.dMinRideBars   = InpDMinRideBars;
   g_set.dRideThreshold = InpDRideThreshold;
   g_set.h1MaPeriod     = InpH1MaPeriod;
   g_set.h1TouchATR     = InpH1TouchATR;
   g_set.entryTF        = (int)InpEntryTF;
   g_set.entryLookback  = InpEntryLookback;
   g_set.swingDepth     = InpSwingDepth;
   g_set.rr             = InpRR;

   if(InpTradeMode<0 || InpTradeMode>2)
     {
      Print("Loi tham so: InpTradeMode chi nhan 0, 1 hoac 2");
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
   datetime curBar=iTime(Symbol(),(int)InpEntryTF,0);
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
   if(Period()!=(int)InpEntryTF) return;         // chart khac khung -> chi canh bao
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
