# mUtil — OrCAD Capture 17.4 自製工具選單 -- 
# 新舊版線路比對、
# NETs線距過近檢查

在 Capture 的主選單列加上一個 **mUtil** 選單，提供四個原廠沒有的功能：比對兩份設計、檢查單一設計的畫法問題、拿 BOM 反查設計的位號與包裝尺寸、一次收乾淨開啟的頁面。

| 版本 | 1.02 |
|---|---|
| 檔案 | `capAutoLoad/mUtilMenu.tcl`（單檔，無其他相依） |
| 環境 | OrCAD Capture 17.4，需要 Tcl/Tk |
| 作者 | LEO, ASROCK |

> [!WARNING]
> **這不是 Cadence 原廠檔案。** 安裝 Capture hotfix 會把 `capAutoLoad` 底下它不認得的檔案刪掉，`mUtilMenu.tcl` 也在內。請在 Cadence 安裝目錄以外另存一份，升版後放回去。
<img width="575" height="323" alt="orcad-compare-01" src="https://github.com/user-attachments/assets/9c217f37-a7d5-405a-a847-6d7e1cf31738" />

---

## 安裝

把 `mUtilMenu.tcl` 放進：

```
<Cadence 安裝路徑>\tools\capture\tclscripts\capAutoLoad\
```

`capAutoLoad` 底下的 `.tcl` 會在 Capture 啟動時自動載入。啟動後 Command Window 會出現：

```
mUtil 1.02 loaded
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
| Default Folder | 兩個 Browse 按鈕的起始資料夾。以 `mCmpInitDir` 存進 `mUtilMenu.cfg`，下次開啟與下次 Capture 啟動都從這裡開始。BOM Footprint Check 有自己的一個，兩者不互相干擾 |
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

## 3. BOM Footprint Check — 拿 BOM 反查 Design

按 Execute 會讀 Design 每一頁的 Part Reference 與 PCB Footprint、讀 BOM 的 Part Reference 與 FOOTPRINT_SIZE，然後用兩條規則比對，結果開在一個**可以選取複製的文字視窗**裡。

| 欄位／按鈕 | 作用 |
|---|---|
| BOM File (.xlsx) | 要讀的檔案。**每次開 Capture 都是空白**，只有資料夾會被記住 —— 見下節 |
| **Execute** | 讀 Design → 讀 BOM → 比對 → 開報告視窗。**做完自動關閉本視窗** |
| **Close** | 只關視窗，不做任何事 |

### 檔案欄位與記住的資料夾

**BOM File 欄位每次開 Capture 都是空白的**，不會自動填上一次用的檔案。BOM 改版的頻率遠高於它對應的設計，從上週的設定檔還原回來的路徑，指到的很可能已經是舊版了 —— 而 Execute 就在旁邊一個按鍵的距離。空白欄位不會被誤按，它在說「選一個」。

**記住的是資料夾**，存在 `mUtilMenu.cfg` 裡，用自己的標籤 `mBomInitDir`，跟 Schematic Compare 的 `mCmpInitDir` 並排但各自獨立：

```
# mUtilMenu remembered settings - safe to delete
mCmpInitDir G:\Project\MB\Yu-hsuan\compare
mBomInitDir G:\Project\MB\W980_WS\BOM
```

兩個標籤而不是一個，因為兩個對話框看的是不同地方：BOM 跟採購文件放在一起，.DSN 跟 layout 放在一起，常常還在不同的磁碟機上。共用一個錨點的話，替 BOM 按一次 Browse 就會改掉 Schematic Compare 下次開始找設計的位置，反之亦然。設定檔裡**只存資料夾，不存任何檔案路徑**。

Browse... 的起始位置依序取第一個真的存在的：

| 順序 | 來源 | 時機 |
|---|---|---|
| 1 | 欄位目前指到的資料夾 | 同一次 session 內，「上一個旁邊那個」幾乎都是對的 |
| 2 | `mBomInitDir` | 上次 Browse 結束的地方，從 `mUtilMenu.cfg` 讀回來 |
| 3 | `mCmpInitDir` | 只有全新安裝、2 還沒設定過時。有地方總比沒地方好 |

在欄位裡**手打**路徑不按 Browse 也會被記住 —— Execute 時補記一次，跟 Schematic Compare 對手打的 Default Folder 做法一樣。

記住的資料夾如果已經不在了（網路磁碟沒掛、資料夾被刪），載入時會直接忽略那個值，不會讓 Browse 從一個不存在的地方開始。

### 先在 Project Manager 選好範圍

按 Execute 之前，PROJECT_MANAGER_VIEW 要選在 **schematic、.DSN 或 .OPJ** 上。

| 選的是 | 結果 |
|---|---|
| schematic（`DboSchematic`） | 跑這張 schematic 底下所有頁 |
| Design `.DSN`（`DboDesign`） | 跑整份設計 |
| Project `.OPJ` | 同上，用 Project Manager 目前開著的設計 |
| **單一 page（`DboPage`）** | **不處理**，跳訊息方塊說明原因並關閉視窗 |
| 沒選、或選到別的東西 | 同上，不處理並關閉視窗 |

> [!IMPORTANT]
> **為什麼 page 要擋掉。** BOM 是整片板子的料表，裡面每個位號都要在整份設計裡找。只比一頁的話，其他四十頁的零件全部會被報成「BOM 有、Design 沒有」—— 幾百筆全錯的結果，把真正有問題的那幾筆埋掉。沒有有用的答案可以給，所以直接拒絕而不是硬給一個爛答案。

同時選了 schematic **和** 它底下的某一頁時，**schematic 贏**，不會因為那一頁而被拒絕。page 只有在它是唯一選取項目時才會擋下來 —— 這跟 Schematic Check 的「最窄者勝」不一樣，因為在這裡 page 根本不是一個可用的答案。

### Execute 的執行順序

```
① 檢查 BOM 檔欄位      空的／讀不到 → 跳訊息，視窗留著讓你改
② 檢查 PM 選取範圍      選到 page／沒選 → 跳訊息，關閉視窗
③ 關閉視窗
④ 走 Design，印出每頁的 Part Reference + PCB Footprint   → Command Window
⑤ 讀 BOM，印出 FOOTPRINT_SIZE + Part Reference           → Command Window
⑥ 跑 RULE1 / RULE2，報告開在文字視窗                      → 可選取複製
```

兩個檢查都排在所有工作之前：整份設計走一趟要時間，走完才告訴你「檔案欄位是空的」是最糟的時間點。視窗在**開始工作前**就收掉，不然幾千行輸出捲過去時它正好擋在 Command Window 前面。

只有 BOM 檔欄位那兩種錯會把**視窗留著** —— 那是你當下正在看、按個 Browse 就能改好的東西，把人正站著的視窗收掉毫無幫助。其他每一條路都會關。

④ 和 ⑤ 是獨立的：其中一邊讀失敗不會連帶取消另一邊。但**只要有一邊沒讀成功就不做比對** —— Design 讀不到的話 BOM 裡每一個位號都會變成「Design 沒有」，整份 BOM 被報成壞的；BOM 讀不到的話兩條規則都會「什麼都沒查到所以全過」，然後印出 `No mis-matching ... found.`，那是往最貴的方向說謊。這種情況報告視窗會直接說哪一邊沒讀到。

④⑤ 的逐行 dump 是**證據**，留在 Command Window；⑥ 的報告才是要帶走的東西，所以開在文字視窗。Command Window 只留一行總結。

### Design 側輸出

```
================================================================
mUtil 1.02  BOM Footprint Check - design side
================================================================
  scope            Design W980_WS.DSN
  pages            42

---- SCHEMATIC1 / P01. POWER ----
  CP203            CAPC2012X110N
  PU1              -
  R2               RESC1005X40N
  R10              RESC1005X40N
  -> 4 part(s)

  -> 6 part(s) over 2 page(s), 5 distinct Part Reference(s), 1 with no PCB Footprint
  -> NOTE: 1 part(s) share a Part Reference with another part
```

頁內按位號排序（dictionary order，所以 R2 排在 R10 前面），頁的順序照設計原本的順序，跟 Project Manager 樹上看到的一致。

沒有 PCB Footprint 的零件印成 `-` 而不是略過 —— 那不是「沒東西」，那是 RULE2 要比的屬性不存在，本身就是一筆發現。

最後兩個數字不一樣時會多印一行 NOTE：代表同一個位號被放了兩次。這會改變 BOM 比對的意義 —— BOM 寫一次、設計放兩顆，比對會過，但那還是錯的。

只讀 `Part Reference` 與 `PCB Footprint` 兩個屬性，不走腳位。Schematic Compare 用的 `CollectPageParts` 一顆零件讀十一項還要走完每支腳（它自己的計時是 312 顆零件 1843 ms），這裡兩個檢查只需要兩個屬性，一百頁的設計差別就是「幾秒」跟「去泡杯咖啡」。

### 讀哪裡（BOM 側）

預設對應的是目前在用的 BOM 樣板，三個位置都是變數，換樣板改變數就好（見〈常用設定〉）：

| 變數 | 預設 | 內容 |
|---|---|---|
| `mBomFirstRow` | `5` | 資料從第幾列開始。第 1–4 列是標題區與欄位名稱，讀進來會把「Part Reference」本身當成位號 |
| `mBomDescCol` | `E` | 描述欄，包裝尺寸埋在裡面：`MLCC 10UF/16V(0805) X5R 10%` |
| `mBomRefCol` | `K` | 位號欄，一格一串逗號分隔：`CP203,CP212,CP701,...,PCAON6,` |

所有工作表都會走一遍 —— BOM 在第幾個分頁不是程式能知道的事。位號欄空白的列不印，所以封面頁、版本紀錄這種分頁自然就是 0 列。

### BOM 側輸出

一個 BOM 列一行，先 FOOTPRINT_SIZE 再該列所有位號，位號之間用空白隔開：

```
================================================================
mUtil 1.02  BOM Footprint Check - W980_WS_BOM.xlsx
================================================================
  file             G:\Project\...\W980_WS_BOM.xlsx
  size             68231 byte(s)
  first data row   5
  FOOTPRINT_SIZE   column E
  Part Reference   column K

---- sheet 1/3  "BOM" ----
  0805       CP203 CP212 CP701 CP702 CP703 CP704 F2C2 F2C3 F4C2 F4C3 F6C2 F6C3 F8C10 F8C11 F8C2 F8C3 F8C7 F8C8 PCAON1 PCAON2 PCAON32 PCAON6
  0402       R1 R2 R3
  -          PU1
  0402/0603  F9C1 F9C2
  -> 4 row(s) with Part References

  -> 4 row(s), 28 part reference(s), 3 row(s) with a FOOTPRINT_SIZE
```

**FOOTPRINT_SIZE** 是在描述欄裡找 `0201` `0402` `0603` `0805` `1206` `1210` 這六個字串（`mBomSizes`），用**子字串**比對 —— 尺寸寫成 `(0805)`、`0805`、` 0805 ` 的都有，沒有一個固定的分隔符可以靠。

| 情況 | 顯示 |
|---|---|
| 找到一個 | `0805` |
| 找到兩個以上 | `0402/0603`，不會替你挑一個 |
| 一個都沒有 | `-` |

> [!IMPORTANT]
> **沒有尺寸的列還是會印**，只是尺寸欄是 `-`。「沒有就不顯示」指的是那個**欄位**，不是整列：那些位號一樣要拿去跟 Design 對存在與否，把列丟掉等於把之後檢查的清單偷偷變小。
>
> 反過來，**位號欄空白的列會整列丟掉** —— 那是標題、分隔列或註解，兩項檢查都用不到。

位號的處理：逗號分隔，前後空白與雙引號都會去掉，所以 `"R1","R2" , "R3"` 和 `R1,R2,R3` 讀出來一樣。**空的片段直接丟棄** —— 結尾那個逗號會切出一個空字串，若不丟，之後就會拿一個空位號去 Design 裡查，然後回報「找不到」，那是讀檔自己憑空造出來的錯誤。

### 讀得到什麼、讀不到什麼

| 內容 | 結果 |
|---|---|
| 一般文字、共用字串 | 原樣讀出 |
| 同一格內多種字型的文字（rich text） | 自動接回一串 |
| 儲存格內嵌文字（inlineStr）、公式的文字結果 | 讀得到 |
| 數字 | 讀出的是**儲存值**，不是畫面上看到的格式。顯示 1.5% 的格子讀出 0.015，日期讀出 45292 之類的序號 |
| 圖片、註解、樞紐分析表 | 不讀 |

數字要照格式呈現得解析 `xl/styles.xml` 並重做一套 Excel 的格式引擎，對現在這一步不划算。BOM 真正要比對的位號、描述、footprint 都是文字，那部分是原樣的。

### 印出 0 列的時候

代表欄位對不上，通常是換了 BOM 樣板。程式會直接告訴你去看哪兩個變數，另外有一個把整份工作表每一格都印出來的診斷指令，用它讀出描述與位號各在哪一欄，再回頭設定：

```tcl
::mUtilMenu::DumpXlsxText {G:/path/board_bom.xlsx}   ;# 印出每一格，含欄位字母
set ::mUtilMenu::mBomFirstRow 3
set ::mUtilMenu::mBomDescCol  F
set ::mUtilMenu::mBomRefCol   D
```

`DumpXlsxText` 就是 1.01 時 Execute 印的東西，現在改成診斷用途，只能從 Command Window 叫。

### 為什麼要自己解 .xlsx

`.xlsx` 是一包 ZIP 裡的 XML，而 Capture 的 Tcl 兩條路都不通：

```tcl
package require vfs::zip   ;# can't find package vfs::zip
package require tcom       ;# can't find package tcom
```

沒有 `vfs::zip` 就不能把壓縮檔掛成檔案系統，沒有 `tcom` 就不能用 COM 去驅動 Excel。能用的是 Capture 載入的 Tcl 8.6.5 核心內建的 `zlib inflate`，所以 ZIP 目錄與 XML 都是在 `mUtilMenu.tcl` 裡自己走的。

就算 `tcom` 裝得起來，驅動 Excel 也是比較差的做法：每台要跑的機器都得裝 Excel、讀一個檔就開一次 Excel，而且檔案裡只要有巨集或外部連結，就會跳出一個**在 Capture 後面、使用者看不到**的強制對話框把整件事卡住。直接讀 bytes 不需要裝任何東西，也不會被檔案內容打斷。

### 錯誤訊息

| 訊息 | 意思 |
|---|---|
| `not a ZIP archive - no end-of-central-directory record` | 根本不是壓縮檔。副檔名改成 `.xlsx` 的 `.xls` 最常見 |
| `xl/workbook.xml is missing - this is not an .xlsx workbook` | 是 ZIP 但不是活頁簿 |
| `ZIP64 archive - not supported by this reader` | 超大檔（>4 GB 或 >65535 個項目），這個 reader 不支援 |

### 比對結果

報告開在一個唯讀文字視窗（跟 Schematic Compare／Schematic Check 共用同一個），有 **Select All**、**Copy**、**Close** 三個按鈕。文字可以直接拉選 + Ctrl-C，Copy 在沒選取時會複製整份。按 Close（或視窗的 X、或 Esc）會把報告視窗和 BOM Footprint Check 視窗一起收掉。

兩條規則都是 **BOM → Design** 方向。BOM 是提出主張的那一方（「這片板子有這些料、用這些包裝」），所以被查的是 BOM 的主張。反過來「Design 有、BOM 沒有」是另一個問題（BOM 漏列），在這裡回答只會讓每一個定位孔、fiducial 把真正該看的結果淹掉。

#### BOM_Footprint_Check_RULE1 — BOM 有、Design 沒有的位號

BOM 的每個 Part Reference 都必須在 Design 裡找得到。兩種情況算「同一顆」：

| BOM | Design | |
|---|---|---|
| `R21` | `R21` | 完全相同（**大小寫不計**，`R21` = `r21`） |
| `R21` | `R21A` `R21B` `R21C` `R21D` … `R21Z` | Design 後面多**一個** A–Z 字碼 |

一顆料拆成好幾個 placement 時就是這樣命名的 —— BOM 上一行 `R21` 涵蓋 Design 裡所有 `R21x`，不認這條規則的話這種料全部會被報成缺件。

除此之外**字串必須完全相符**，是 case fold 不是正規化：不去空白、不去標點、不忽略前導零。

| 不算相同 | 為什麼 |
|---|---|
| `R21` vs `R210` | 多的是數字不是字母。這個判斷正是 `R2` 不會吃掉 `R21` 的原因 |
| `PU1` vs `PU1AB` | 只允許**一個**字母 |
| `R21C` vs `R21` | **字碼只能加在 Design 那一側** |

> [!NOTE]
> **方向是固定的。** BOM 寫 `R21`，Design 放 `R21C` → 相符；BOM 寫 `R21C`，Design 只有 `R21` → **不相符，會列出來**。BOM 負責點名、Design 負責擺放，所以加 placement 字碼是 Design 那一側的權利。反過來的話，BOM 的 `R21C` 會去匹配一份從頭到尾只有 `R21` 的設計 —— 那是兩份文件真的不一樣，不是命名慣例。

```
BOM_Footprint_Check_RULE1 - Part Reference in the BOM, not in the design
----------------------------------------------------------------
  CP701            BOM sheet "BOM" row 5
  PCAON32          BOM sheet "BOM" row 5

  -> 2 Part Reference(s) not found in the design
```

沒問題時：

```
BOM_Footprint_Check_RULE1: No mis-matching Part Reference found.
```

#### BOM_Footprint_Check_RULE2 — BOM 的尺寸跟 Design 的 footprint 不符

只看**有 FOOTPRINT_SIZE、而且 RULE1 有找到**的位號 —— 存不存在用的是**跟 RULE1 完全同一套判斷**，placement 字碼一起算，所以 BOM 上一行 `R21` 會去比 `R21A`～`R21D` 每一個的 PCB Footprint。找不到的已經是 RULE1 的結果了，在這裡再報一次「無法比對尺寸」只會讓每一筆缺料在報告裡出現兩遍。

比對方式是**子字串、不分大小寫**：BOM 寫 `0402`，Design 的 PCB Footprint 是 `C0402`、`RESC1005X40N_0402` 還是 `0402_L`，都算相符，不列出。

```
BOM_Footprint_Check_RULE2 - FOOTPRINT_SIZE in the BOM, not in the design's PCB Footprint
----------------------------------------------------------------
  R21 -> R21C          BOM 0402       design "RES0603"                    SCH1 / P02
  R21 -> R21D          BOM 0402       design (no PCB Footprint)           SCH1 / P02
  F9C2                 BOM 0402/0603  design "CAP1206"                    SCH1 / P02

  -> 3 placement(s) whose PCB Footprint does not carry the BOM's size
```

左邊那一欄是**Design 的位號**，因為那才是要去翻的東西；placement 字碼讓兩邊不一樣時會寫成 `BOM位號 -> Design位號`，這樣也還找得回 BOM 上的那一行。

| 情況 | 處理 |
|---|---|
| Design 的 footprint 含該尺寸字串 | 相符，不列 |
| Design 的 footprint 名稱裡根本沒有尺寸 | 查 `KNOWLEDGE_BASE_PCBFOOTPRINT_1`，見下 |
| BOM 那列有兩個尺寸（`0402/0603`） | Design 含**其中任一個**就算相符。含糊的是 BOM，不該拿我們自己的含糊去判零件有罪 |
| Design 沒有 PCB Footprint | 列出來，標 `(no PCB Footprint)` |
| 一顆料拆成 `R21A`～`R21D` | **逐個 placement** 比，各自列出，因為那是四件不同的事實 |
| 同一個位號在 BOM 出現兩行 | 只列一次，不會因為 BOM 重複而重複報 |

沒問題時：

```
BOM_Footprint_Check_RULE2: No mis-matching PCB Footprint found.
```

#### 例外表 KNOWLEDGE_BASE_PCBFOOTPRINT_1

RULE2 是拿 BOM 的尺寸去 PCB Footprint 的名字裡找，對 `C0402`、`RESC1005X40N_0402` 這種命名沒問題，對**名字裡根本沒寫尺寸**的就沒轍了。`4r8p` 是 0603 的腳位，名字完全看不出來，所有用它畫的 0603 料都會被報成不符。這張表就是把這件事寫下來的地方：

| PCB Footprint | 視為 |
|---|---|
| `4r8p` | `0603` |
| `4r8p_h24` | `0603` |

```tcl
set ::KNOWLEDGE_BASE_PCBFOOTPRINT_1 {
    {4r8p     0603}
    {4r8p_h24 0603}
}
```

三個要點：

- **整串相符，不分大小寫。** 這裡寫 `4r8p` 指的是 PCB Footprint **就是** `4r8p`，不是「含有」`4r8p` —— 所以 `4r8p_h24` 要另外寫一筆，不會被第一筆涵蓋。像 `4r8p` 這種四個字元的短 token，用子字串比對很容易在別的 footprint 名字裡撞到，然後**默默放掉一個真的不符**。會亂放行的例外比沒有例外更糟。加一個變體就是多一行，這個交換是划算的。
- **只在正常比對失敗之後才查。** 所以表裡的一筆只可能把「不符」變成「相符」，不可能反過來。寫錯一筆的代價是漏掉一個不符，不會是冤枉一顆零件。
- **表裡有這個 footprint、但尺寸還是對不上時，報告會把它寫出來**：

```
  R1                   BOM 0402       design "4r8p" = 0603                S1 / P1
```

  「`4r8p`，我們知道它是 0603」對上 BOM 寫的 0402，跟「一個沒人有意見的 footprint」是兩回事，不該讓讀的人自己去翻表才知道是哪一種。

例外有生效時，RULE2 結尾會多一行（不管有沒有 findings 都會印）：

```
  (+ 12 placement(s) matched through KNOWLEDGE_BASE_PCBFOOTPRINT_1)
```

看不見在運作的例外表，就是沒人能發現它壞掉的例外表。預期 `4r8p` 那些料會被放行、結果這行是 0 或根本沒出現，代表表沒對上（多半是 footprint 改名了）—— 這行會在你把那堆 findings 當雜訊略過之前先講。

想加一筆，在 Command Window 就能加：

```tcl
lappend ::KNOWLEDGE_BASE_PCBFOOTPRINT_1 {6r0p 0805}
```

跟 `SCH_CHECK_ITEM1` 一樣是裸的全域變數，所以**重新 source 這個檔案會把它蓋回去**。要長期留著的，請直接寫進 `mUtilMenu.tcl` 裡那份清單。

> [!NOTE]
> 子字串比對的代價跟 `mBomSizes` 那邊是一樣的：footprint 名稱裡剛好有那四個數字（但不是在講尺寸）會被當成相符，真正的不一致就漏掉了。這是兩個方向裡比較安全的那個 —— 這條規則的每一筆都是要人一筆一筆去看的，一個對整套 library 命名慣例狂叫的規則沒人會看第二次。

---

## 4. Close Page — 收乾淨但留住 Project Manager

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
| `mBomFirstRow` | `5` | BOM 資料從第幾列開始，之前是標題區與欄位名稱 |
| `mBomDescCol` | `E` | BOM 描述欄，FOOTPRINT_SIZE 從這裡找 |
| `mBomRefCol` | `K` | BOM 位號欄，逗號分隔 |
| `mBomSizes` | `0201 0402 0603 0805 1206 1210` | 認得的包裝尺寸。以子字串比對描述欄 |
| `mBomMaxRows` | `0` | BOM Footprint Check 每張工作表最多印幾列。`0` = 全印，設成正整數後超出的部分印 `+N more` |
| `mClosePageMode` | `perdesign` | Close Page 的模式 |
| `mTimeCompare` | `1` | 印出比對各階段耗時 |
| `mQuiet` | `0` | 1 = 不把 dump 印進 Command Window |
| `::BOTH_N_O_COMP` | `1` | AllPagesComp 是否雙向比對（全域變數，非 namespace） |
| `::KNOWLEDGE_BASE_PCBFOOTPRINT_1` | `{4r8p 0603} {4r8p_h24 0603}` | RULE2 的例外表：名字裡沒有尺寸的 footprint 實際是哪個尺寸（全域變數，非 namespace） |

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
::mUtilMenu::DumpXlsxText {C:/path/bom.xlsx} ;# BOM 每一格的內容，用來確認欄位位置
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
