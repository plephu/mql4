# BBRide MTF — Hệ thống vào lệnh "D đu dây BB" cho MetaTrader 4

Bộ code MQL4 hiện thực hóa quy trình giao dịch top-down, **cả hai chiều**, trên **bộ khung thời gian thay đổi được**:

> **BUY** — 2 khung lớn còn xu hướng **tăng** và chưa chạm **kháng cự** → khung "đu dây" bám dải **trên** BB → khung hồi về MA10 / BB giữa → M5/M1 tích luỹ tạo **2 đáy tăng dần** → phá **lên** neckline **và vượt lên kênh giảm** của nhịp hồi.
>
> **SELL** — 2 khung lớn còn xu hướng **giảm** và chưa chạm **hỗ trợ** → khung "đu dây" bám dải **dưới** BB → khung hồi về MA10 / BB giữa → M5/M1 tích luỹ tạo **2 đỉnh giảm dần** → phá **xuống** neckline **và gãy kênh tăng** của nhịp hồi.

## Hai kịch bản dựng sẵn — `InpPreset`

Cùng một logic, áp ở hai cấp độ khung thời gian khác nhau:

| `InpPreset` | Tên | Xu hướng lớn | Đu dây BB | Hồi trend thuần | Vào lệnh |
|---|---|---|---|---|---|
| **0** | **SWING** (mặc định) | MN1 + W1 | **D1** | H1 | M5 |
| **1** | **INTRADAY** | W1 + D1 | **H4** | M15 | M5 |
| **2** | TU CHON | tự đặt 4 khung qua `InpTfTrend1..InpTfPullback` | | | |

- Preset **0**: sóng dài, ít tín hiệu, lệnh giữ nhiều ngày. Kháng cự/hỗ trợ quét trên **W1**.
- Preset **1**: sóng ngắn, tín hiệu nhiều hơn, lệnh giữ trong ngày đến vài ngày. Kháng cự/hỗ trợ quét trên **D1**.
- Bộ khung bắt buộc **giảm dần** (khung 1 > khung 2 > đu dây > hồi > vào lệnh), sai thứ tự thì EA từ chối khởi động kèm thông báo rõ.
- `InpEntryTF` (M5/M1) luôn do anh quyết, preset không ghi đè.

Muốn chạy cả hai kịch bản cùng lúc trên một cặp: mở **2 chart**, một chart `InpPreset=0`, một chart `InpPreset=1`, **cùng `InpMagic`** để hạn mức rủi ro vẫn gộp chung.

Chọn chiều bằng `InpTradeMode`: `0` = cả hai (mặc định), `1` = chỉ BUY, `2` = chỉ SELL.

## 0. Cấu trúc repo

Repo được sắp đúng theo cây thư mục `MQL4` của MetaTrader 4, nên có thể copy nguyên trạng:

```
Experts/            ->  <MT4 Data Folder>/MQL4/Experts/
Indicators/         ->  <MT4 Data Folder>/MQL4/Indicators/
Include/BBRide/     ->  <MT4 Data Folder>/MQL4/Include/BBRide/
```

File `.ex4` (bản biên dịch) không đưa lên repo — mỗi máy tự compile bằng MetaEditor (F7).

Toàn bộ logic chiến lược nằm **một chỗ duy nhất** là `Include/BBRide/BBRideCore.mqh`; EA và Indicator đều `#include` file này, nên sửa logic một lần là cả hai cùng đổi.

## 1. Thành phần

| File | Vai trò |
|---|---|
| `Include/BBRide/BBRideCore.mqh` | **Toàn bộ logic 5 tầng điều kiện, cả 2 chiều BUY/SELL** — nguồn duy nhất |
| `Experts/BBRide_MTF_EA.mq4` | EA: quét tín hiệu, vào lệnh, quản trị vốn, trailing, dashboard |
| `Indicators/BBRide_MTF_Signal.mq4` | Indicator: chỉ cảnh báo + vẽ mũi tên/Neckline/SL/TP, không vào lệnh |

Cả 3 file đều cần thiết: EA và Indicator không tự chạy được nếu thiếu `BBRideCore.mqh`.

## 2. Cài đặt

1. Clone repo (hoặc tải ZIP rồi giải nén).
2. MT4 → `File` → `Open Data Folder` → mở thư mục `MQL4`.
3. Copy **cả 3 thư mục** `Experts`, `Indicators`, `Include` từ repo vào đè lên `MQL4`. Đường dẫn trong repo đã khớp sẵn, thư mục `Include/BBRide` tự có — **không phải tạo tay**.
4. Kiểm tra 3 file nằm đúng chỗ:
   ```
   MQL4/Include/BBRide/BBRideCore.mqh
   MQL4/Experts/BBRide_MTF_EA.mq4
   MQL4/Indicators/BBRide_MTF_Signal.mq4
   ```
5. Mở MetaEditor (F4) → compile (F7) `BBRide_MTF_EA.mq4` và `BBRide_MTF_Signal.mq4`. Phải báo `0 error`. Không cần compile file `.mqh`.
6. Về MT4 → chuột phải trong Navigator → `Refresh`.

### Lỗi hay gặp khi compile

| Thông báo | Nguyên nhân | Cách xử lý |
|---|---|---|
| `cannot open "BBRide/BBRideCore.mqh"` | File `.mqh` không nằm đúng `MQL4/Include/BBRide/` | Kiểm tra lại bước 4; chú ý chữ hoa/thường của tên thư mục `BBRide` |
| Không thấy EA trong Navigator | Chưa compile, hoặc copy nhầm vào thư mục `MQL5` | Compile lại (F7) → MT4 → `Refresh` Navigator |
| Copy khi MT4 đang mở mà không thấy | MT4 chưa quét lại thư mục | Đóng/mở lại MT4, hoặc `Refresh` Navigator |

**Không muốn dùng thư mục con?** Đặt `BBRideCore.mqh` thẳng vào `MQL4/Include/` rồi sửa dòng `#include` ở đầu 2 file `.mq4`:
```mq4
#include <BBRide/BBRideCore.mqh>   // sửa thành:
#include <BBRideCore.mqh>
```

### Sau khi compile

- Gắn EA lên chart **M5** (hoặc M1) của cặp cần giao dịch.
- Bật `AutoTrading`, tab Common tick `Allow live trading`.
- Lần chạy đầu để `InpDryRun = true` (chỉ cảnh báo, không đặt lệnh).

> Bắt buộc: tải đủ lịch sử MN1, W1, D1, H1, M5 (nhấn `Ctrl+B` hoặc mở lần lượt từng khung) — EA cần dữ liệu đa khung, thiếu lịch sử sẽ không ra tín hiệu.

## 3. Logic chi tiết từng tầng

### Bảng đối xứng nhanh

| Tầng | BUY | SELL |
|---|---|---|
| 1. Hai khung lớn | EMA nhanh > chậm, dốc lên, giá đóng > EMA chậm | EMA nhanh < chậm, dốc xuống, giá đóng < EMA chậm |
| 1b. Cản (quét trên khung lớn thứ 2) | **Kháng cự** = đỉnh fractal gần nhất **trên** giá; cần ≥ 1.5 ATR khoảng trống | **Hỗ trợ** = đáy fractal gần nhất **dưới** giá; cần ≥ 1.5 ATR khoảng trống |
| 2. Khung đu dây | `%B ≥ 0.80` (bám dải **trên**), BB giữa **dốc lên**, giá đóng > BB giữa | `%B ≤ 0.20` (bám dải **dưới**), BB giữa **dốc xuống**, giá đóng < BB giữa |
| 3. Khung hồi | Giá hồi **xuống** MA10/BB giữa; không nến nào đóng sâu **dưới** vùng; giá còn **trên** MA50 | Giá hồi **lên** MA10/BB giữa; không nến nào đóng sâu **trên** vùng; giá còn **dưới** MA50 |
| 4. M5/M1 | **2 đáy tăng dần** (đáy 2 > đáy 1) | **2 đỉnh giảm dần** (đỉnh 2 < đỉnh 1) |
| 5. Trigger — neckline | Neckline = **đỉnh** giữa 2 đáy; đóng cửa **phá lên** | Neckline = **đáy** giữa 2 đỉnh; đóng cửa **phá xuống** |
| 5b. Trigger — vượt trend | Đường trend nối **2 đỉnh giảm dần** của nhịp hồi; đóng cửa **vượt lên** | Đường trend nối **2 đáy tăng dần** của nhịp hồi; đóng cửa **xuyên xuống** |
| SL / TP | SL = đáy 2 − 0.5 ATR; TP = Entry + RR×R, cắt trước kháng cự | SL = đỉnh 2 + 0.5 ATR; TP = Entry − RR×R, cắt trước hỗ trợ |

Điều kiện "BB đang mở rộng" (`InpDReqExpansion`) và "biên độ co lại" (`InpReqContraction`) dùng chung cho cả hai chiều — chúng đo độ rộng, không có hướng.

### Tầng 1 — Xu hướng 2 khung lớn

Khung được coi là **tăng** khi đồng thời: MA nhanh > MA chậm (mặc định EMA5/EMA10 cho khung 1; EMA10/EMA20 cho khung 2), MA nhanh dốc lên, MA chậm không quay đầu, giá đóng cửa nến gần nhất > MA chậm. Chiều **giảm** đảo ngược toàn bộ 4 điều kiện.

Với preset SWING, khung 1 = MN1 và khung 2 = W1. Với preset INTRADAY, khung 1 = W1 và khung 2 = D1 — đúng như "khung lớn D, W vẫn xu hướng tăng hoặc giảm".

### Tầng 1b — "Chưa đến kháng cự / hỗ trợ"

Quét trên **khung lớn thứ 2** (W1 với preset SWING, D1 với preset INTRADAY):

- BUY: quét đỉnh fractal, lấy đỉnh **thấp nhất nằm trên** giá hiện tại.
- SELL: quét đáy fractal, lấy đáy **cao nhất nằm dưới** giá hiện tại.
- Khoảng trống `room = |cản − giá| / ATR(14)` của khung đó, yêu cầu `≥ InpMinRoomATR` (mặc định 1.5).
- Không còn cản nào chắn đường (giá ở vùng đỉnh/đáy lịch sử) → coi như trống hoàn toàn, điều kiện đạt.

### Tầng 2 — "Đu dây BB" trên khung đu dây (D1 hoặc H1)

Với BB(20, 2.0) trên khung đó, `%B = (Close − Lower) / (Upper − Lower)`:

- **BUY**: đếm nến có `%B ≥ InpDRideThreshold` (0.80) trong `InpDRideLookback` nến gần nhất, cần ≥ `InpDMinRideBars` (4).
- **SELL**: dùng ngưỡng đối xứng `%B ≤ 1 − InpDRideThreshold` (tức ≤ 0.20). Một tham số điều khiển cả hai chiều.
- BB giữa phải dốc đúng chiều và giá đóng cửa nằm đúng phía so với BB giữa.
- Tuỳ chọn `InpDReqExpansion`: độ rộng dải hiện tại ≥ độ rộng đầu cửa sổ.

**Vì sao dùng ngưỡng 0.80/0.20 thay vì "đóng cửa vượt hẳn dải"?** Đóng cửa xuyên hẳn dải là hiếm và thường là điểm kiệt sức ngắn hạn. Bám sát vùng 80–100% (hoặc 0–20%) dải mới đúng bản chất "đu dây" bền của một xu hướng mạnh. Siết lên 0.90 nếu muốn khắt khe hơn.

### Tầng 3 — Khung hồi về trend thuần (H1 hoặc M15)

- Vùng hồi = **MA10** hoặc **BB giữa** của khung hồi — code tự chọn mức gần giá hơn (tắt BB giữa bằng `InpPbUseBBMid=false`).
- Trước đó giá phải giãn khỏi vùng ít nhất `InpPbMinExtATR` × ATR — BUY đo đỉnh cao nhất, SELL đo đáy thấp nhất — để chắc chắn có sóng đủ lớn rồi mới hồi.
- Trong `InpPbBars` nến gần nhất phải có nến chạm vùng (BUY: `Low ≤ vùng + dung sai`; SELL: `High ≥ vùng − dung sai`).
- **Chưa gãy**: không nến nào đóng cửa vượt sâu qua vùng theo chiều ngược; BB giữa vẫn dốc đúng chiều; giá vẫn đúng phía so với MA50 của khung hồi.

Tham số đổi tên từ `InpH1*` sang `InpPb*` (pullback) vì khung này không còn cố định là H1.

### Tầng 4 — M5/M1: tích luỹ, 2 điểm xoay

- Tìm 2 **điểm xoay fractal** gần nhất — đáy cho BUY, đỉnh cho SELL (độ sâu `InpSwingDepth`), phải cách nhau tối thiểu vài nến.
- BUY yêu cầu **đáy 2 > đáy 1**; SELL yêu cầu **đỉnh 2 < đỉnh 1**. Chênh lệch phải nằm trong `[InpMinHigherLow, InpMaxHigherLow]` × ATR — quá xa nghĩa là đang đuổi giá, không còn là tích luỹ.
- Điểm xoay thứ 2 phải nằm trong vùng hồi H1.
- `InpReqContraction`: biên độ trung bình đoạn giữa 2 điểm xoay phải co lại so với đoạn trước đó.

### Tầng 5 — Trigger: phải phá CẢ HAI mức

Setup chỉ được kích hoạt khi giá phá đồng thời 2 thứ, bằng **nến vừa đóng** trên khung vào lệnh:

**a) Neckline (mức ngang)**
- BUY: đỉnh cao nhất giữa 2 đáy → cần đóng cửa **trên** mức này.
- SELL: đáy thấp nhất giữa 2 đỉnh → cần đóng cửa **dưới** mức này.
- Nến trước đó **chưa** được phá — tránh vào muộn khi giá đã chạy.

**b) Đường trend của nhịp hồi (mức nghiêng)** — `InpReqTrendBreak`
- BUY: nối **2 đỉnh gần nhất** trên M5/M1 (phải là 2 đỉnh **giảm dần**) → đường trend giảm. Cần đóng cửa **vượt lên** đường này.
- SELL: nối **2 đáy gần nhất** (phải là 2 đáy **tăng dần**) → đường trend tăng. Cần đóng cửa **xuyên xuống**.
- Đường trend được kéo dài về nến hiện tại theo độ dốc `(giá điểm neo 2 − giá điểm neo 1) / số nến giữa hai điểm`, rồi so sánh với giá đóng cửa.
- Cũng yêu cầu nến trước chưa phá.

**Vì sao cần cả hai?** Chúng bắt hai việc khác nhau:

| | Neckline (ngang) | Đường trend (nghiêng) |
|---|---|---|
| Xác nhận | Giá đã lấy lại được **mức giá** quan trọng | Nhịp điều chỉnh đã **mất đà** |
| Thời điểm | Muộn hơn — phải chờ vượt hẳn đỉnh cũ | Sớm hơn — gãy ngay khi nhịp hồi yếu đi |
| Rủi ro nếu chỉ dùng một | Vào muộn, SL xa, RR kém | Dễ nhiễu — gãy trend nhỏ trong một nhịp hồi vẫn còn tiếp |

Bắt buộc cả hai lọc bớt tín hiệu nhưng loại được phần lớn cú phá giả. Muốn nhiều tín hiệu hơn, tắt `InpReqTrendBreak = false` — khi đó chỉ còn điều kiện neckline như trước.

Nếu không tìm được 2 điểm xoay ngược chiều, hoặc chúng **không** dốc đúng chiều (ví dụ tìm BUY nhưng 2 đỉnh lại tăng dần → nhịp hồi chưa yếu), setup bị loại với ghi chú rõ trên dashboard.

### Entry / SL / TP

- Entry = Ask (BUY) / Bid (SELL).
- SL = điểm xoay 2 ± `InpSLBufferATR` × ATR khung vào lệnh.
- TP = `InpRR` × R, tự cắt trước kháng cự/hỗ trợ W1. Nếu cản kéo RR thực tế xuống dưới `InpMinRR` → **bỏ setup**.

## 4. Bảng tham số EA quan trọng

| Tham số | Mặc định | Ý nghĩa / gợi ý tinh chỉnh |
|---|---|---|
| `InpPreset` | 0 | 0 = SWING (D1 đu dây), 1 = INTRADAY (H4 đu dây), 2 = tự chọn 4 khung |
| `InpTradeMode` | 0 | 0 = cả hai chiều, 1 = chỉ BUY, 2 = chỉ SELL. Khi để 0, EA xét BUY trước; không đạt mới xét SELL |
| `InpMinRoomATR` | 1.5 | Tăng lên 2.0–2.5 nếu hay bị chặn ở kháng cự/hỗ trợ |
| `InpDMinRideBars` | 4 | Tăng lên 5–6 để chỉ bắt xu hướng thật mạnh (ít lệnh hơn) |
| `InpDRideThreshold` | 0.80 | 0.90 = khắt khe hơn (SELL tự dùng ngưỡng đối xứng 0.10) |
| `InpPbTouchATR` | 0.35 | Nới lên 0.5 nếu ít tín hiệu, siết 0.25 nếu vào quá sớm |
| `InpEntryTF` | M5 | M1 cho tín hiệu nhiều và nhiễu hơn; M5 cân bằng tốt hơn |
| `InpReqTrendBreak` | true | Bắt buộc vượt đường trend nhịp hồi. Tắt (`false`) nếu muốn nhiều tín hiệu hơn, chấp nhận nhiều phá giả hơn |
| `InpReqNeckBreak` | true | Bắt buộc phá neckline ngang. Tắt cả hai = vào lệnh ngay khi có mô hình 2 điểm xoay (**không khuyến nghị**) |
| `InpMaxSpreadPips` | 3.0 | Chặn vào lệnh khi spread giãn (tin tức, phiên Á) |
| `InpDryRun` | false | **Bật `true` để chạy thử: chỉ cảnh báo, không đặt lệnh thật** |

**Quản lý lệnh đang mở** (hoạt động đúng cho cả BUY lẫn SELL): `InpBreakEvenAt1R` dời SL về hoà vốn khi lãi 1R; `InpTrailBBMidH1` trailing theo BB giữa H1 — chỉ kéo theo hướng có lợi, BUY kéo lên / SELL kéo xuống; `InpCloseOnH1Break` thoát khi H1 đóng cửa vượt qua BB giữa theo chiều ngược.

---

# PHẦN QUẢN TRỊ RỦI RO (bắt buộc đọc)

## 4.1 Công thức tính lot

EA tính khối lượng đúng theo công thức chuẩn:

```
Tiền rủi ro = Balance × Risk%
Lot         = Tiền rủi ro / (SL pips × Giá trị 1 pip của 1 lot)
```

Trong đó `Giá trị 1 pip của 1 lot = TICKVALUE × (PipSize / TICKSIZE)` — lấy trực tiếp từ broker nên đúng cho mọi cặp, kể cả cặp không có USD làm tiền định giá.

Ví dụ EURUSD, tài khoản USD, balance 5.000, risk 1%, SL 25 pip:

```
Tiền rủi ro = 5.000 × 1% = 50 USD
1 pip / 1 lot (EURUSD) = 10 USD
Lot = 50 / (25 × 10) = 0.20
```

Ví dụ XAUUSD (bật `InpHighVolAuto`, hệ số 0.5), balance 5.000, risk 1% → hiệu lực 0.5%, SL 350 pip (3.5 USD giá vàng):

```
Tiền rủi ro = 5.000 × 0.5% = 25 USD
1 pip / 1 lot (XAUUSD) = 1 USD
Lot = 25 / (350 × 1) = 0.07
```

Nguyên tắc code đã cưỡng chế:
- **Luôn làm tròn XUỐNG** theo `LOTSTEP` → không bao giờ vượt mức rủi ro đã định.
- Nếu vốn không đủ cho lot tối thiểu với SL này → **bỏ lệnh**, không hạ SL cho vừa lot.
- `InpMaxLotCap` đặt trần tuyệt đối cho khối lượng (0 = không chặn).
- Log mỗi lệnh in đầy đủ: risk %, tiền rủi ro, SL pips, giá trị pip, lot — để anh đối chiếu tay.

| Tham số | Mặc định | Ghi chú |
|---|---|---|
| `InpRiskPercent` | 1.0 | % balance rủi ro mỗi lệnh. Đặt 0 để dùng lot cố định (**không khuyến nghị**) |
| `InpFixedLots` | 0.01 | Chỉ dùng khi `InpRiskPercent = 0` |
| `InpMaxLotCap` | 0.0 | Trần khối lượng tuyệt đối |

## 4.2 Giới hạn thua trong ngày & kỷ luật

Toàn bộ các quy tắc dưới đây được EA **cưỡng chế bằng code**, không phụ thuộc ý chí lúc đang thua:

| Quy tắc | Tham số | Mặc định | Cách hoạt động |
|---|---|---|---|
| Tối đa 2% lỗ/ngày | `InpMaxDailyLossPct` | 2.0 | So lỗ (đã đóng + đang treo nếu bật `InpCountFloating`) với **balance đầu ngày**; vượt ngưỡng → chặn mọi lệnh mới tới hết ngày server, có Alert 1 lần |
| Thua 2–3 lệnh liên tiếp → dừng | `InpMaxConsecLoss` | 3 | Quét lịch sử theo thời gian đóng lệnh, đếm chuỗi thua gần nhất. Đặt 2 nếu anh muốn khắt khe hơn |
| Giới hạn số lệnh/ngày | `InpMaxTradesPerDay` | 3 | Chống overtrading khi tín hiệu liên tục |
| **Không tăng lot để gỡ** | — | luôn bật | Lot **chỉ** sinh ra từ công thức risk %; balance giảm sau lệnh thua → lot lệnh sau tự nhỏ đi. Không có martingale/nhân lot trong code |
| **Không dời SL xa hơn** | — | luôn bật | `ManageOpenTrades()` có chặn cứng `if(newSl < sl) newSl = sl;` — SL chỉ đi theo hướng có lợi (hoà vốn → trailing BB giữa H1) |
| **Không bình quân giá** | `InpAllowAveraging` | false | Khi đang có lệnh mở, mọi tín hiệu mới bị chặn. Chỉ bật `true` nếu anh có kế hoạch scale-in rõ ràng bằng văn bản |

Trạng thái chặn hiển thị ngay trên dashboard: `>>> CHAN VAO LENH: DUNG TRADE: lo 2.14% >= tran 2.00% trong ngay`.

> Reset tự động theo **ngày của server broker** (`TimeCurrent()`), không phải giờ máy tính anh. Nếu broker ở GMT+2/+3, "ngày" sẽ lệch với giờ Việt Nam — hãy kiểm tra giờ server trong Market Watch để biết mốc reset.

## 4.3 Risk/Reward tối thiểu

| Tham số | Mặc định | Ghi chú |
|---|---|---|
| `InpRR` | 2.0 | RR mục tiêu dùng để đặt TP |
| `InpMinRR` | 1.5 | **RR thực tế tối thiểu** — kiểm tra tại giá khớp lệnh |

Điểm quan trọng: TP có thể bị **cắt ngắn** khi kháng cự W1 nằm gần hơn mục tiêu 2R. Vì vậy EA tính lại RR **thực tế** ngay trước khi gửi lệnh:

```
RR thực tế = (TP − Ask) / (Ask − SL)
nếu RR thực tế < InpMinRR → bỏ setup, ghi log lý do
```

Nghĩa là: setup đẹp về kỹ thuật nhưng bị kháng cự chặn TP sẽ **không được vào lệnh**, thay vì vào với RR 1:0.8. `InpMinRR < 1.0` bị từ chối ngay ở `OnInit`.

## 4.4 XAUUSD / BTC và các sản phẩm biến động mạnh

Không dùng chung một lot cố định với forex. EA xử lý theo 2 lớp:

1. **Lot tự co giãn theo biên độ.** Vì lot = f(SL pips) mà SL = đáy 2 − 0.5×ATR, khi vàng/BTC biến động mạnh thì SL rộng ra → lot tự nhỏ lại. Số tiền rủi ro mỗi lệnh giữ nguyên. Đây là lý do **không nên** dùng `InpRiskPercent = 0` (lot cố định) cho các sản phẩm này — EA sẽ in cảnh báo ngay khi khởi động nếu anh làm vậy.
2. **Giảm risk % tự động.** `InpHighVolAuto = true` + `InpHighVolFactor = 0.5`: symbol chứa từ khoá trong `InpHighVolKeys` (`XAU, GOLD, XAG, SILVER, BTC, XBT, ETH, CRYPTO`) sẽ dùng risk = 1% × 0.5 = **0.5%/lệnh**. Chỉnh danh sách từ khoá theo cách broker đặt tên symbol (ví dụ `GOLD.m`, `BTCUSD.pro` vẫn khớp).

Khuyến nghị bổ sung khi trade vàng/BTC: hạ `InpMaxTradesPerDay` xuống 2, nới `InpMaxSpreadPips` theo spread thực của broker (vàng thường 15–35 pip chứ không phải 3), và kiểm tra `InpSLBufferATR` — vàng hay quét râu nên 0.7–1.0 thường hợp lý hơn 0.5.

## 4.5 Chỉ giao dịch 7 cặp đã chọn

EA **từ chối khởi động** (`INIT_FAILED`) nếu gắn lên chart ngoài danh sách:

```
InpUseWhitelist    = true
InpSymbolWhitelist = GBPUSD,GBPAUD,GBPJPY,AUDUSD,EURUSD,EURAUD,EURJPY
```

So khớp theo kiểu "chứa chuỗi" nên tự động chấp nhận hậu tố của broker: `EURUSD.m`, `EURUSDpro`, `EURUSD_i`, `GBPJPY.raw` đều khớp. Indicator cũng chặn tương tự (hiện thông báo, không cảnh báo tín hiệu).

> **Ngoại lệ cần biết:** broker đặt **tiền tố** (ví dụ `mEURUSD`) vẫn khớp whitelist, nhưng hàm nhận diện đồng tiền cơ sở (mục dưới) sẽ đọc sai thành `MEU`. Nếu broker của anh đặt tiền tố, hãy tắt `InpMaxSameCurrency` hoặc báo tôi để sửa cách tách.

### Chạy 7 cặp cùng lúc — 3 chốt chặn bắt buộc

Gắn EA lên 7 chart nghĩa là 7 bản EA chạy độc lập. Nếu không kiểm soát, hạn mức 2%/ngày sẽ thành 2% × 7 = **14%/ngày**. Ba tham số sau xử lý việc đó:

| Tham số | Mặc định | Tác dụng |
|---|---|---|
| `InpRiskScopeAll` | true | Trần lỗ ngày, số lệnh/ngày và chuỗi thua tính **gộp toàn tài khoản** (mọi symbol cùng `InpMagic`), không tính riêng từng cặp. **Bắt buộc giữ `true` khi chạy nhiều chart** |
| `InpMaxTradesTotal` | 3 | Tối đa 3 lệnh mở đồng thời trên toàn tài khoản, dù có 7 chart |
| `InpMaxSameCurrency` | 2 | Tối đa 2 lệnh cùng đồng tiền cơ sở |

Vì sao cần `InpMaxSameCurrency`: danh sách 7 cặp này có **2 nhóm tương quan rất mạnh**:

- `GBPUSD`, `GBPAUD`, `GBPJPY` → cả 3 đều là **long GBP**
- `EURUSD`, `EURAUD`, `EURJPY` → cả 3 đều là **long EUR**

Vào cả 3 lệnh GBP cùng lúc không phải là 3 kèo độc lập — đó là **một kèo GBP với khối lượng gấp 3**. Một tin xấu về Bảng Anh đánh trúng cả ba. Rủi ro thực tế là 3% chứ không phải 1%. `InpMaxSameCurrency = 2` chặn tình huống này; đặt 1 nếu anh muốn tuyệt đối không cộng dồn.

Bộ đếm chỉ cộng dồn các lệnh **cùng đồng tiền VÀ cùng chiều**: 2 lệnh SELL GBPUSD + SELL GBPJPY = 2 lần short GBP (bị đếm), nhưng BUY GBPUSD + SELL GBPJPY thì không, vì hai lệnh triệt tiêu một phần rủi ro GBP. Dashboard hiển thị `Long GBP: 1/2` hoặc `Short GBP: 2/2` tuỳ chiều tín hiệu đang xét.

Dashboard hiển thị đủ 3 con số: `Lenh mo: 1/1 (cap nay) | Toan TK: 2/3 | Long GBP: 2/2`.

> **Quan trọng:** tất cả các chart phải dùng **cùng một `InpMagic`** thì cơ chế gộp mới hoạt động. Đổi Magic khác nhau giữa các chart = mỗi cặp tự tính riêng, mất tác dụng bảo vệ.

### Gợi ý cấu hình cho rổ 7 cặp

| Tham số | Giá trị đề xuất | Lý do |
|---|---|---|
| `InpRiskPercent` | 0.5 – 0.75 | 7 cặp quét tín hiệu song song, hạ risk/lệnh để tổng rủi ro không phình |
| `InpMaxTradesPerDay` | 4 – 6 | Đây là số gộp toàn tài khoản, không phải mỗi cặp |
| `InpMaxSpreadPips` | 3 (EURUSD, GBPUSD, AUDUSD) / 5–6 (GBPJPY, EURJPY, GBPAUD, EURAUD) | Cross và JPY pair có spread rộng hơn hẳn — để 3 cho GBPJPY sẽ chặn gần hết lệnh |
| `InpHighVolKeys` | thêm `GBPJPY` nếu muốn | GBPJPY biến động mạnh hơn hẳn phần còn lại; thêm vào danh sách để tự giảm risk còn một nửa |

## 4.6 Indicator cũng gợi ý khối lượng

`BBRide_MTF_Signal` vẽ mũi tên xanh (BUY) / đỏ (SELL) tại nến trigger, vẽ **đường trend nhịp hồi vừa bị phá** (màu hồng, kéo dài sang phải) cùng các mức Neckline / SL / TP, và hiển thị RR thực tế + lot gợi ý theo đúng công thức trên (input `InpRiskPercent`, `InpMinRR`, `InpHighVolFactor`), và cảnh báo `>>> THAP HON RR TOI THIEU ... - NEN BO SETUP` khi RR không đạt — dùng cho anh trade tay.

---

## 5. Quy trình kiểm thử khuyến nghị

1. **Strategy Tester** (MT4): model `Every tick`, chọn chart M5, backtest tối thiểu 2–3 năm trên cặp có xu hướng rõ (XAUUSD, US30, EURUSD, cổ phiếu CFD).
2. Kiểm tra `Modelling quality ≥ 90%`; nếu thấp, nạp thêm dữ liệu M1 lịch sử.
3. Chạy `InpDryRun = true` trên tài khoản demo tối thiểu 4–6 tuần, đối chiếu từng cảnh báo với chart bằng mắt.
4. Chỉ chuyển sang tài khoản thật khi số mẫu ≥ 30 lệnh và kỳ vọng dương ổn định qua nhiều giai đoạn thị trường.

## 6. Giới hạn cần biết (nói rõ, không tô hồng)

- **Hai kịch bản khung dùng chung một bộ tham số kỹ thuật** (`InpBBPeriod`, `InpPbTouchATR`, `InpSLBufferATR`...). Preset INTRADAY chạy trên khung nhỏ hơn nên nhiễu nhiều hơn — nhiều khả năng cần siết `InpDMinRideBars` lên 5–6 và `InpPbTouchATR` xuống 0.25. Tôi chưa backtest để khẳng định con số, anh phải tự kiểm chứng.
- **Hai chiều dùng chung một bộ tham số.** Thực tế thị trường không đối xứng: xu hướng giảm thường nhanh và dốc hơn xu hướng tăng, nên `InpSLBufferATR` và `InpH1TouchATR` tối ưu cho BUY chưa chắc tối ưu cho SELL. Nếu backtest cho thấy lệch rõ, hãy chạy 2 chart riêng cho cùng một cặp: một chart `InpTradeMode=1`, một chart `InpTradeMode=2`, với tham số khác nhau (nhớ giữ cùng `InpMagic` để hạn mức rủi ro vẫn gộp).
- **Indicator chỉ đánh giá thời gian thực**, không vẽ lại toàn bộ tín hiệu lịch sử (logic dùng dữ liệu đa khung tại nến hiện tại). Muốn thống kê lịch sử, dùng EA trong Strategy Tester.
- **"Kháng cự" chỉ dựa trên đỉnh fractal W1**, chưa tính Fibonacci, số tròn, vùng cung/cầu hay khối lượng — nếu bạn dùng thêm các mốc này, hãy siết `InpMinRoomATR`.
- **Hạn mức lỗ ngày, số lệnh/ngày và chuỗi thua đếm theo `InpMagic`** — mặc định gộp toàn tài khoản (`InpRiskScopeAll = true`). Lệnh anh vào tay hoặc EA khác (Magic khác) **không** được tính vào hạn mức này.
- **Nhận diện đồng tiền cơ sở lấy 3 ký tự đầu của tên symbol.** Broker đặt tiền tố (`mEURUSD`) sẽ làm `InpMaxSameCurrency` hoạt động sai — tắt tham số đó hoặc báo để sửa.
- **Tham số mặc định chưa được tối ưu cho một sản phẩm cụ thể.** Mỗi cặp có biên độ khác nhau, bắt buộc phải backtest và tinh chỉnh trước khi dùng vốn thật.
- Kết quả backtest không đảm bảo kết quả tương lai. Giao dịch có đòn bẩy có rủi ro mất toàn bộ vốn.

## 7. Đọc dashboard trên chart

```
=== BB RIDE MTF - GBPJPY | CA HAI CHIEU ===
Bo khung: W1+D1 > H1 > M15 > M5
Dang xet chieu: SELL  (H1 du day dai DUOI BB)
[OK]  1. W1 xu huong giam
[OK]  2. D1 xu huong giam
[OK]  3. Con khong gian toi ho tro D1: 3.10 ATR
[OK]  4. H1 du day BB: 6 nen, %B=0.09
[OK]  5. M15 hoi ve vung 188.420
[OK]  6. 2 dinh giam dan (M5)
        dinh1=188.640  dinh2=188.410  neck=188.150
[--]  7. Xuyen XUONG duong trend nhip hoi (gay kenh tang)
Trang thai: SELL: Chua XUYEN XUONG duong trend 188.372
---------------- QUAN TRI RUI RO ----------------
Risk/lenh: 0.75%
P/L ngay: -38.20 da dong / 0.00 dang treo  =>  lo 0.76%  (tran 2.00%)
Pham vi tinh rui ro: TOAN TAI KHOAN (moi cap cung Magic)
Lenh hom nay: 1/4  |  Thua lien tiep: 1/3
Spread: 5.2 pip  |  Lenh mo: 0/1 (cap nay)  |  Toan TK: 1/3  |  Short GBP: 1/2
CHE DO: VAO LENH THAT
```
Dòng `Trang thai` luôn cho biết **đang vướng điều kiện nào** — đây là công cụ học và kiểm chứng hệ thống nhanh nhất.
