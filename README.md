# mUtil — OrCAD Capture 17.4 自製工具選單 -- 
# 新舊版線路比對、
# NETs線距過近檢查

在 Capture 的主選單列加上一個 **mUtil** 選單，提供三個原廠沒有的功能：比對兩份設計、檢查單一設計的畫法問題、一次收乾淨開啟的頁面。

| 版本 | 1.01 |
|---|---|
| 檔案 | `capAutoLoad/mUtilMenu.tcl`（單檔，無其他相依） |
| 環境 | OrCAD Capture 17.4，需要 Tcl/Tk |
| 作者 | LEO, ASROCK |

> [!WARNING]
> **這不是 Cadence 原廠檔案。** 安裝 Capture hotfix 會把 `capAutoLoad` 底下它不認得的檔案刪掉，`mUtilMenu.tcl` 也在內。請在 Cadence 安裝目錄以外另存一份，升版後放回去。

---

## 安裝

把 `mUtilMenu.tcl` 放進：

```
<Cadence 安裝路徑>\tools\capture\tclscripts\capAutoLoad\
```

`capAutoLoad` 底下的 `.tcl` 會在 Capture 啟動時自動載入。啟動後 Command Window 會出現：

```
mUtil 1.01 loaded
```

選單會出現在兩個地方（內容相同，用哪個都可以）：

- 主選單列的 **mUtil**
- **Accessories > mUtil**

### 不重啟 Capture 重新載入

改過 `.tcl` 之後：

```tcl
::mUtilMenu::remove
source {G:/Cadence/SPB_17.4/tools/capture/tclscripts/capAutoLoad/mUtilMenu.tcl}
```

---

## 1. Schematic Compare — 比對兩份 .DSN

找出兩份設計之間的差異，並**直接畫在圖頁上**，不用對著報告找位置。

### 操作流程

**① 選兩個 .DSN**

| 欄位 | 說明 |
|---|---|
| Default Folder | 兩個 Browse 按鈕的起始資料夾。會存進 `mUtilMenu.cfg`，下次開啟與下次 Capture 啟動都從這裡開始 |
| Design File 1 **(O)** | 舊版 |
| Design File 2 **(N)** | 新版 |

兩個設計檔欄位會保留上次用的值；**改選 Default Folder 到不同目錄時會自動清空**，避免拿舊路徑去比新工作。

**② 頁面配對**

按 Execute 後出現頁面選擇器：兩欄各列出一份設計的所有頁面，中間自動畫出配對線。

| 結果 | 畫法 | 條件 |
|---|---|---|
| exact | 黑字 + 實線 | 去掉頁名開頭的 `*` `-` `~` 等標記後完全相同 |
| similar | 紅字 + 虛線 | 下列任一：壓縮掉標點空白後相同／前 10 字元相同／壓縮後前 7 字元相同 |
| none | 紅字，不畫線 | 另一邊沒有對應的頁 |

**③ 執行比對**

| 按鈕 | 作用 |
|---|---|
| **OnePageCmp** | 只比兩欄各勾選的那一頁。輸出完整 dump 與報告，不改頁名 |
| **AllPagesComp** | 比對所有有配對線的頁面。有差異的 (N) 頁自動在名稱前加 `*` |
| **(N)(O)BOTH COMP**（勾選框） | 預設開啟。每對頁面比兩次，反向以 (N) 為基準把差異畫在 (O) 上。**只有 (N) 會被改名** |

雙向比對不是重複做白工：只有「新增」的那一邊會被畫出來，所以只有 (O) 有的零件、net、接線，正向完全不會畫，正是反向要抓的。

### 比對什麼

**四個區段**，逐項比對「有／沒有」：

| 區段 | 納入比對的內容 |
|---|---|
| Parts | 零件編號、Value、PCB Footprint、料號、Optional、package、library、位置、腳位清單 |
| Symbols | Off-Page / Power / Port 的型別、名稱、位置 |
| Nets | net 名稱與所有線段座標 |
| Buses | 匯流排名稱、型別、座標 |

零件若只是**搬了位置**而其他資料完全相同，會列為 Moved，不算差異也不畫框。

**五條網路規則**，比的是連通性而不是座標：

| 規則 | 條件 | 標記 |
|---|---|---|
| rule 1 | (N) 上沒接任何零件腳、且不跨頁的空接 net（不看 (O)） | 整條 net 的線 |
| rule 2 | (N) 有、(O) 沒有的 net | 整條 net 的線 |
| rule 3 | 同名，但跨頁／不跨頁的屬性變了 | 整條 net 的線 |
| rule 4 | 同名同屬性，但接到的**實體接點**不同 | 只畫端點落在差異接點上的那條線 |
| rule 5 | (O) 有接線、(N) 卻變成未接的腳位 | 腳位向外的短線 |

rule 4 的「實體接點」包含零件腳（`U1D.E43`）與 Off-Page / Power / Port（`OFFPAGE:CLK`），**比身分不比座標** —— 線移動了不算差異，換一顆零件或抽掉一個 off-page connector 才算。

rule 5 走的是 Parts 而不是 netlist：一條 net 掉光最後一支腳之後就不在 (N) 的 netlist 裡，rule 1–4 看不到，但腳還在。

### 畫在圖頁上的標記

| 樣式 | 意義 |
|---|---|
| 粉紅點虛線 | rule 1–4 命中的 net、(N) 新增的匯流排 |
| 綠松色矩形 | (N) 新增的零件（框住外框） |
| 粉紅短線 | rule 5：掉了連線的腳位，從腳位向外 4 個格點（0.4 inch） |

全部是**圖形物件**，不影響電氣連接，不要的話直接框選刪除。工具本身不會存檔 —— 存不存由你按 File > Save 決定。

---

## 2. Schematic Check — 檢查單一設計

在 PROJECT_MANAGER_VIEW 選一頁、一張 schematic、整個 .DSN 或 .OPJ，再按 Start。

| 項目 | 檢查什麼 | 標記 |
|---|---|---|
| **項目 1** | NET 沒對齊格點造成漏接 —— 兩個端點靠得很近卻沒真正接上，畫面看起來接了、網表其實是分開的 | 粉紅／灰線標出兩點 + 藍框。整份設計跑完後有問題的頁名加 `*` |
| **項目 2** | NET 沒有 global 參照但名稱相同 —— 同名畫在不同頁卻沒有 Off-Page/Power 連起來，Capture 會自動改名（`+3.3VSB` → `+3.3VSB_9631`），那就是證據 | 該 net 每條線畫粉紅線。**不改頁名** |

兩個項目都勾選時是**掃一次**，不是兩次。報告輸出在唯讀文字視窗（不是訊息方塊），可以直接選取複製。

兩個核取方塊各自對應一個全域變數，可在 Command Window 讀寫：

```tcl
set ::SCH_CHECK_ITEM1 1    ;# 1 = 勾選
set ::SCH_CHECK_ITEM2 0
```

---

## 3. Close Page — 收乾淨但留住 Project Manager

比對或檢查跑過一輪之後，Capture 裡常常開了幾十個頁面分頁。Close Page 走訪 session 裡每一個設計，關掉頁面、**保留 Project Manager**，原本作用中的專案結束後仍是作用中。

用 `mClosePageMode` 切換四種模式：

| 模式 | 行為 |
|---|---|
| `perdesign` | **預設**。走訪每個開啟的設計，逐一關閉頁面並保留 Project Manager |
| `allbutpm` | 只處理目前作用中的專案 |
| `closeall` | 等同 Window > Close All |
| `allbutthis` | 關掉目前這一個以外的所有分頁 |

---

## 常用設定

全部是 namespace 變數，在 Command Window 隨時可改，改完立即生效：

```tcl
set ::mUtilMenu::mRule4MarkMinPins 5
```

| 變數 | 預設 | 作用 |
|---|---|---|
| `mRule4MarkMinPins` | `1` | rule 4 要標記的腳，其零件至少要幾支腳。設 5 可忽略兩腳被動元件的改接 |
| `mRule4MinPins` | `5` | 成本開關：parts walk 對幾支腳以下的零件跳過讀取腳位座標 |
| `mRule5` | `1` | rule 5 開關。關掉同時省下 (N) 側的額外腳位座標讀取 |
| `mRule5StubLen` | `4` | rule 5 短線長度，單位是格點（0.1 inch），公制頁面也一樣是 4 格 |
| `mPageSimilarChars` | `10` | 頁面配對：前幾個字元相同算 similar |
| `mPageCompactSimilarChars` | `7` | 同上，但比的是壓縮掉標點空白後的名稱 |
| `mPageNameMaxChars` | `32` | Capture 物件名稱上限。加 `*` 會超過就不加，避免整份設計存不了 |
| `mClosePageMode` | `perdesign` | Close Page 的模式 |
| `mTimeCompare` | `1` | 印出比對各階段耗時 |
| `mQuiet` | `0` | 1 = 不把 dump 印進 Command Window |
| `::BOTH_N_O_COMP` | `1` | AllPagesComp 是否雙向比對（全域變數，非 namespace） |

---

## 已知問題

**AllPagesComp 之後第一次 File > Save 可能失敗**，再按一次就成功，資料不會遺失。

Capture 的 `session.log` 會記錄：

```
ERROR(ORCAP-1650): Unable to save '....DSN'.
ERROR(ORDBDLL-1096): Invalid object name. Perhaps greater than 32 characters.
```

Capture 的 DBO 物件名稱上限是 32 字元，而加 `*` 會多一個字。1.01 已加入 `mPageNameMaxChars` 防護：加完會超標的頁**不加星號**（marker 照樣保留，報告會註明原因），所以不會再因此讓整份設計存不了。

**沒有 .opj 的 .DSN 存不了。** Schematic Compare 接受 .DSN 路徑，Capture 會把它載入但不建立專案，之後 File > Save 走專案那一層就會失敗（Save As 可以）。1.01 會在 Execute 時先在 Command Window 警告，但不阻擋比對。

---

## 疑難排解

Command Window 裡的診斷指令：

```tcl
::mUtilMenu::About              ;# 版本、作者
::mUtilMenu::diag               ;# 選單註冊狀態、可用的 Capture 指令、Tk 是否就緒
::mUtilMenu::diagSaveState      ;# 存不了檔時看這個：PM 選取、IsDocModified、兩份設計的 IsModified
::mUtilMenu::DumpSessionDesigns ;# session 裡有哪些設計、各自的修改狀態
::mUtilMenu::DumpPages {C:/path/board.dsn}   ;# 一份設計的所有頁名（四種排序）
```

`diagSaveState` 的判讀：

| 那一行 | 代表 |
|---|---|
| `selected PM items` 空的 | Project Manager 沒有選取項目 |
| `IsDocModified 0` | UI 層認為文件沒改動 |
| `design IsModified 0` | 資料庫層沒被標記 —— 寫入沒有落地 |

比對本身的細節會印在 Command Window。嫌太吵可以 `set ::mUtilMenu::mQuiet 1`，或 `set ::mUtilMenu::mPinDetail 0` 關掉逐腳明細。

---

## 其他文件

| 檔案 | 內容 |
|---|---|
| [`Develope.md`](Develope.md) | 開發紀錄：每項功能的需求、前置調查、設計決定、驗證方式與已知限制 |
| [`mUtilMenu-tree.md`](mUtilMenu-tree.md) | proc 結構樹與呼叫關係，找「我要改某個行為該動哪裡」用 |
