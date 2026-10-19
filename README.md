
# mUtil — OrCAD Capture 17.4 自製工具選單

**新舊版線路比對 · NETs 線距過近檢查 · BOM footprint 反查 · BOM 與設計雙向對帳**

在 Capture 的主選單列加上一個 **mUtil** 選單，提供五個原廠沒有的功能：

| # | 選單項目 | 做什麼 | 怎麼指定範圍 | 結果在哪 |
|---|---|---|---|---|
| 1 | **Schematic Compare** | 比對新舊兩份 .DSN，差異**直接畫在圖頁上** | 對話框選兩個 .DSN，再勾要比的頁：一頁、幾頁、或全部 | 圖頁標記 + 文字視窗 |
| 2 | **Schematic Check** | 單一設計的畫法問題：NET 沒對齊格點、同名 NET 沒 global 參照 | Project Manager 選頁／schematic／.DSN／.OPJ | 圖頁標記 + 文字視窗 |
| 3 | **BOM Footprint Check** | 拿 BOM (.xlsx) 反查設計：位號有沒有、包裝尺寸對不對 | Project Manager 選 schematic／.DSN／.OPJ | 文字視窗 |
| 4 | **BOM Consistency Check** | BOM 與設計**雙向對帳**：BOM 點的料有沒有上板、設計上板的料有沒有進 BOM | Project Manager 選 schematic／.DSN | 文字視窗 |
| 5 | **Close Page** | 關掉所有開著的圖頁，**留住 Project Manager** | 不用選 | — |

文字視窗都是唯讀但可選取複製的（不是訊息方塊），報告可以直接貼進 mail。

| 版本 | 1.04 |
|---|---|
| 檔案 | `capAutoLoad/mUtilMenu.tcl`（單檔，無其他相依） |
| 環境 | OrCAD Capture 17.4，需要 Tcl/Tk |
| 作者 | LEO, ASROCK |
| 本版新增 | 新選單項目 **BOM Consistency Check** —— 拿 `Optional` 欄位跟 BOM 雙向對帳，兩條規則一邊一個方向（[說明](#4-bom-consistency-check--bom-與設計雙向對帳)）。比的是 **Reference Designator**（`ORN1`）而不是 Part Reference（`ORN1A`），所以多 part 封裝的各個 section 併成一筆，不會整頁都報成 BOM 沒有 |

> [!WARNING]
> **這不是 Cadence 原廠檔案。** 安裝 Capture hotfix 會把 `capAutoLoad` 底下它不認得的檔案刪掉，`mUtilMenu.tcl` 也在內。請在 Cadence 安裝目錄以外另存一份，升版後放回去。
<img width="212" height="149" alt="Selection item" src="https://github.com/user-attachments/assets/71d55245-2e87-40cc-b620-93437146a32e" />
<img width="575" height="323" alt="orcad-compare-01" src="https://github.com/user-attachments/assets/9c217f37-a7d5-405a-a847-6d7e1cf31738" />

---

## 安裝

把 `mUtilMenu.tcl` 放進：

```
<Cadence 安裝路徑>\tools\capture\tclscripts\capAutoLoad\
```

`capAutoLoad` 底下的 `.tcl` 會在 Capture 啟動時自動載入。啟動後 Command Window 會出現：

```
mUtil 1.04 loaded
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

三顆按鈕比的東西完全一樣（同一套區段比對、同五條網路規則、同樣的圖頁標記），差別在**範圍**與**輸出多寡**：

| 按鈕 | 範圍 | 勾選方式 | 頁名加 `*` | 報告 |
|---|---|---|---|---|
| **OnePageCmp** | 一對頁 | 兩欄**各勾一頁**，不管有沒有配對線 | 不加 | 完整 dump + 文字視窗 |
| **MultiPageCmp** | 勾選的幾對頁 | 兩欄想勾幾頁就勾幾頁，**必須兩兩配對** | 有差異的 (N) 頁加 | 每頁一行進度 + 總結訊息 |
| **AllPagesComp** | 所有有配對線的頁 | 不用勾 | 有差異的 (N) 頁加 | 每頁一行進度 + 總結訊息 |

**(N)(O)BOTH COMP**（選頁視窗下方的勾選框）預設開啟，對 **MultiPageCmp 與 AllPagesComp 都有效**：每對頁面比兩次，反向以 (N) 為基準把差異畫在 (O) 上，但**只有 (N) 會被改名**。

按鈕在視窗底部的排法：**AllPagesComp 單獨靠左**，MultiPageCmp / OnePageCmp / Close 靠右。它是唯一會走完整份設計並改頁名的，刻意跟另外兩顆隔開，避免手滑。

雙向比對不是重複做白工：只有「新增」的那一邊會被畫出來，所以只有 (O) 有的零件、net、接線，正向完全不會畫，正是反向要抓的。

#### MultiPageCmp 的配對檢查（1.03 新增）

只想比其中幾頁時用這顆。開跑前會先檢查勾選**兩邊是否對得起來**：每一個勾到的頁，都必須是某條配對線的一端，而且線的另一端也要有勾（**實線 exact、虛線 similar 都算**）。

| 勾選情況 | 結果 |
|---|---|
| 兩邊勾的頁兩兩都有線相連 | 照配對線一頁一頁比 |
| 只勾了一邊 | **不開跑** |
| 勾到的頁，對面那一頁沒勾 | **不開跑** |
| 勾到完全沒有配對線的頁（紅字那種） | **不開跑** |

不開跑時顯示 `Page selection mis-matching`，底下列出配不到的頁名，直接回到選頁視窗，**勾選原封不動**可以當場改：

```
Page selection mis-matching

Every ticked page must be joined by a line - solid or dashed - to a ticked page of the other design.

Not paired with a ticked page (2):
(O) SCH / P02. VCORE
(N) SCH / P03. DDR
```

這裡是**擋下來**而不是自動略過配不到的頁 —— 安靜跳過一半勾選的比對，比不肯開跑還糟。

每比完一頁在 Command Window 印一行，所以跑長一點的時候看得出進度與跑到哪：

```
MultiPageCmp - (N) new.dsn   (O) old.dsn
  (N)(O)BOTH COMP is on - every pair is compared both ways; only (N) is renamed
  (N) P01. CPU      (O) P01. CPU      Page comparison finished - no difference
  (N) P02. VCORE    (O) P02. VCORE    Page comparison finished - 6 marker(s), '*' added
  (O) P02. VCORE    (N) P02. VCORE    Page comparison finished - 2 marker(s), page name left alone
MultiPageCmp - 2 page pair(s) compared, 1 (N) page(s) marked
```

被標記的那一頁排在行首（`(N)` 或 `(O)`），那就是接下來要打開看的頁。跑完出一個總結訊息方塊，按 OK 會把選頁視窗一起收掉。

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

讀設計每一頁的 `Part Reference` 與 `PCB Footprint`，讀 BOM 的位號與包裝尺寸，用兩條規則比對，報告開在可選取複製的文字視窗。

### 操作

**① 先在 Project Manager 選好範圍**

| 選的是 | 結果 |
|---|---|
| schematic / `.DSN` / `.OPJ` | 跑它底下所有頁 |
| **單一 page** | **不處理**，跳訊息說明原因並關閉視窗 |
| 沒選、或選到別的 | 同上 |

> [!IMPORTANT]
> BOM 是整片板子的料表，每個位號都要在**整份**設計裡找。只比一頁的話，其他四十頁的零件會全部被報成「BOM 有、Design 沒有」—— 幾百筆全錯的結果，把真正該看的那幾筆埋掉，所以直接拒絕。
>
> 同時選了 schematic **和**它底下某一頁時 **schematic 贏**，不會因為那一頁被拒絕。

**② 選 BOM 檔，按 Execute**

| 欄位／按鈕 | 作用 |
|---|---|
| BOM File (.xlsx) | 要讀的檔案。**每次開 Capture 都是空白**，只有資料夾會被記住 |
| **Execute** | 讀 Design → 讀 BOM → 比對 → 開報告視窗，**做完自動關閉本視窗** |
| **Close** | 只關視窗，不做任何事 |

執行順序：

```
① 檢查 BOM 檔欄位      空的／讀不到 → 跳訊息，視窗留著讓你改
② 檢查 PM 選取範圍      選到 page／沒選 → 跳訊息，關閉視窗
③ 關閉視窗
④ 走 Design，印出每頁的 Part Reference + PCB Footprint   → Command Window
⑤ 讀 BOM，印出 FOOTPRINT_SIZE + Part Reference           → Command Window
⑥ 跑 RULE1 / RULE2                                       → 報告視窗
```

兩個檢查都排在工作之前 —— 整份設計走一趟要時間，走完才說「檔案欄位是空的」是最糟的時間點。只有 BOM 檔欄位那兩種錯會**留著視窗**讓你當場改，其他每一條路都會關。

④⑤ 的逐行 dump 是證據，留在 Command Window；⑥ 的報告才是要帶走的東西，所以開在文字視窗。

> [!NOTE]
> **有一邊沒讀成功就不做比對。** Design 讀不到的話，BOM 每一個位號都會變成「Design 沒有」；BOM 讀不到的話，兩條規則都會「什麼都沒查到所以全過」並印出 `No mis-matching ... found.` —— 後者是往最貴的方向說謊。這種情況報告視窗會直接說哪一邊沒讀到。

### BOM 讀哪裡

預設對應目前在用的樣板，換樣板改變數就好（見〈常用設定〉）：

| 變數 | 預設 | 內容 |
|---|---|---|
| `mBomFirstRow` | `5` | 資料從第幾列開始。第 1–4 列是標題區與欄位名稱 |
| `mBomDescCol` | `E` | 描述欄，尺寸埋在裡面：`MLCC 10UF/16V(0805) X5R 10%` |
| `mBomRefCol` | `K` | 位號欄，一格一串逗號分隔：`CP203,CP212,...,PCAON6,` |

位號的前後空白與雙引號都會去掉，`"R1","R2" , "R3"` 和 `R1,R2,R3` 讀出來一樣；空片段丟棄（結尾那個逗號會切出空字串，留著就會拿空位號去查然後回報缺件）。

所有工作表都會走一遍 —— BOM 在第幾個分頁不是程式能知道的事。位號欄空白的列不算，所以封面頁、版本紀錄那種分頁自然就是 0 列。

FOOTPRINT_SIZE 是在描述欄裡找 `0201` `0402` `0603` `0805` `1206` `1210` 這六個字串（`mBomSizes`），**子字串**比對 —— 尺寸寫成 `(0805)`、`0805`、` 0805 ` 的都有，沒有固定分隔符可以靠。找到兩個以上顯示 `0402/0603`，不會替你挑一個；一個都沒有顯示 `-`。

### 兩側的 dump（Command Window）

```
---- SCHEMATIC1 / P01. POWER ----          ---- sheet 1/3  "BOM" ----
  CP203            CAPC2012X110N             0805       CP203 CP212 CP701 ... PCAON6
  PU1              -                         0402       R1 R2 R3
  R2               RESC1005X40N              -          PU1
  R10              RESC1005X40N              0402/0603  F9C1 F9C2
  -> 4 part(s)                               -> 4 row(s) with Part References
```

- 設計側頁內按位號排序（dictionary order，R2 在 R10 前面），頁序照設計原本的順序。只讀兩個屬性、不走腳位，所以一百頁的設計是幾秒而不是幾分鐘。
- 沒有 PCB Footprint 的零件印 `-` 而不是略過 —— 那是 RULE2 要比的屬性不存在，本身就是一筆發現。
- 同一個位號被放兩次時會多印一行 `NOTE`：BOM 寫一次、設計放兩顆，比對會過，但那還是錯的。
- 儲存格裡的換行（Alt+Enter）印成 `\n`，一列還是一行。數字讀出的是**儲存值**不是顯示格式（1.5% 讀出 0.015，日期讀出 45292）—— BOM 要比的位號、描述、footprint 都是文字，那部分是原樣的。

### RULE1 — BOM 有、Design 沒有的位號

兩種情況算「同一顆」：

| BOM | Design | |
|---|---|---|
| `R21` | `R21` | 完全相同（**大小寫不計**） |
| `R21` | `R21A` `R21B` … `R21Z` | Design 後面多**一個** A–Z placement 字碼 |

一顆料拆成好幾個 placement 就是這樣命名的，BOM 上一行 `R21` 涵蓋設計裡所有 `R21x`。除此之外字串必須完全相符（不去空白、不去標點、不忽略前導零）：

| 不算相同 | 為什麼 |
|---|---|
| `R21` vs `R210` | 多的是數字不是字母 —— 這正是 `R2` 不會吃掉 `R21` 的原因 |
| `PU1` vs `PU1AB` | 只允許**一個**字母 |
| `R21C` vs `R21` | 字碼**只能加在 Design 那一側** |

> [!NOTE]
> 方向是固定的：BOM 寫 `R21`、Design 放 `R21C` → 相符；BOM 寫 `R21C`、Design 只有 `R21` → **不相符，會列出來**。BOM 負責點名、Design 負責擺放，所以加字碼是 Design 那一側的權利。

```
BOM_Footprint_Check_RULE1 - Part Reference in the BOM, not in the design
----------------------------------------------------------------
  CP701            BOM sheet "BOM" row 5
  PCAON32          BOM sheet "BOM" row 5

  -> 2 Part Reference(s) not found in the design
```

沒問題時：`BOM_Footprint_Check_RULE1: No mis-matching Part Reference found.`

### RULE2 — BOM 的尺寸跟 Design 的 footprint 不符

只看**有 FOOTPRINT_SIZE、而且 RULE1 有找到**的位號（存在與否用 RULE1 同一套判斷，placement 字碼一起算）。找不到的已經是 RULE1 的結果，再報一次只會讓每筆缺料出現兩遍。

比對是**子字串、不分大小寫**：BOM 寫 `0402`，Design 是 `C0402`、`RESC1005X40N_0402` 或 `0402_L` 都算相符。

```
BOM_Footprint_Check_RULE2 - FOOTPRINT_SIZE in the BOM, not in the design's PCB Footprint
----------------------------------------------------------------
  R21 -> R21C          BOM 0402       design "RES0603"                    SCH1 / P02
  R21 -> R21D          BOM 0402       design (no PCB Footprint)           SCH1 / P02
  F9C2                 BOM 0402/0603  design "CAP1206"                    SCH1 / P02

  -> 3 placement(s) whose PCB Footprint does not carry the BOM's size
```

左欄是**Design 的位號**（那才是要去翻的東西）；placement 字碼讓兩邊不同時寫成 `BOM位號 -> Design位號`，這樣也還找得回 BOM 上那一行。

| 情況 | 處理 |
|---|---|
| footprint 含該尺寸字串 | 相符，不列 |
| footprint 名稱裡根本沒有尺寸 | 查例外表，見下 |
| BOM 那列有兩個尺寸 | 含**任一個**就算相符 —— 含糊的是 BOM，不該拿我們自己的含糊去判零件有罪 |
| Design 沒有 PCB Footprint | 列出，標 `(no PCB Footprint)` |
| 一顆料拆成 `R21A`～`R21D` | **逐個 placement** 比，各自列出 |
| 同一位號在 BOM 出現兩行 | 只列一次 |

沒問題時：`BOM_Footprint_Check_RULE2: No mis-matching PCB Footprint found.`

> [!NOTE]
> 子字串比對的代價：footprint 名稱裡剛好有那四個數字（但不是在講尺寸）會被當成相符，真正的不一致就漏掉。這是兩個方向裡比較安全的那個 —— 這條規則每一筆都要人去看，一個對整套 library 命名慣例狂叫的規則沒人會看第二次。

#### 例外表 KNOWLEDGE_BASE_PCBFOOTPRINT_1

名字裡根本沒寫尺寸的 footprint 沒辦法用子字串找。`4r8p` 是 0603 的腳位，名字完全看不出來，所有用它畫的 0603 料都會被報成不符。這張表就是把這件事寫下來的地方：

```tcl
set ::KNOWLEDGE_BASE_PCBFOOTPRINT_1 {
    {4r8p     0603}
    {4r8p_h24 0603}
}
```

- **整串相符，不分大小寫。** 寫 `4r8p` 指的是 footprint **就是** `4r8p`，不是「含有」—— 所以 `4r8p_h24` 要另外寫一筆。這種四字元短 token 用子字串比對很容易在別的名字裡撞到，然後默默放掉一個真的不符；會亂放行的例外比沒有例外更糟。
- **只在正常比對失敗之後才查**，所以一筆只可能把「不符」變成「相符」。寫錯的代價是漏掉一個不符，不會是冤枉一顆零件。
- **表裡有這個 footprint 但尺寸還是對不上時，報告會寫出來**：`design "4r8p" = 0603`。那跟「一個沒人有意見的 footprint」是兩回事。

例外有生效時，RULE2 結尾會多一行（有沒有 findings 都印）：

```
  (+ 12 placement(s) matched through KNOWLEDGE_BASE_PCBFOOTPRINT_1)
```

看不見在運作的例外表，就是沒人能發現它壞掉的例外表。預期那些料會被放行、結果這行沒出現，代表表沒對上（多半是 footprint 改名了）。

加一筆：`lappend ::KNOWLEDGE_BASE_PCBFOOTPRINT_1 {6r0p 0805}`。跟 `SCH_CHECK_ITEM1` 一樣是裸的全域變數，**重新 source 會蓋回去**，要長期留著請寫進 `mUtilMenu.tcl` 裡那份清單。

### 檔案欄位與記住的資料夾

**BOM File 欄位每次開 Capture 都是空白**，不會自動填上一次用的檔案 —— BOM 改版比設計頻繁，還原回來的路徑多半已經是舊版，而 Execute 就在旁邊一個按鍵的距離。

記住的是**資料夾**，存在 `mUtilMenu.cfg`，用自己的標籤，跟 Schematic Compare 的並排但獨立：

```
mCmpInitDir G:\Project\MB\Yu-hsuan\compare
mBomInitDir G:\Project\MB\W980_WS\BOM
```

兩個標籤而不是一個，因為兩個對話框看的是不同地方（BOM 跟採購文件放一起，.DSN 跟 layout 放一起，常常還在不同磁碟機），共用一個錨點的話替 BOM 按一次 Browse 就會改掉 Schematic Compare 下次開始找設計的位置。設定檔裡**只存資料夾，不存檔案路徑**。

Browse... 起始位置依序取第一個真的存在的：欄位目前指到的資料夾 → `mBomInitDir` → `mCmpInitDir`（只有全新安裝時）。手打路徑不按 Browse 也會在 Execute 時補記一次。記住的資料夾如果已經不在了（網路磁碟沒掛、被刪），載入時直接忽略。

### 印出 0 列的時候

欄位對不上，通常是換了 BOM 樣板。程式會直接告訴你去看哪兩個變數，另外有一個把每一格都印出來的診斷指令：

```tcl
::mUtilMenu::DumpXlsxText {G:/path/board_bom.xlsx}   ;# 印出每一格，含欄位字母
set ::mUtilMenu::mBomFirstRow 3
set ::mUtilMenu::mBomDescCol  F
set ::mUtilMenu::mBomRefCol   D
```

### 讀 .xlsx 的限制

`.xlsx` 是一包 ZIP 裡的 XML，而 Capture 的 Tcl 沒有 `vfs::zip` 也沒有 `tcom`，兩條現成的路都不通，所以 ZIP 目錄與 XML 是用 Tcl 8.6 內建的 `zlib inflate` 自己走的。共用字串、rich text、inlineStr、公式的文字結果都讀得到；圖片、註解、樞紐分析表不讀。

| 錯誤訊息 | 意思 |
|---|---|
| `not a ZIP archive - no end-of-central-directory record` | 根本不是壓縮檔。副檔名改成 `.xlsx` 的 `.xls` 最常見 |
| `xl/workbook.xml is missing - this is not an .xlsx workbook` | 是 ZIP 但不是活頁簿 |
| `ZIP64 archive - not supported by this reader` | 超大檔（>4 GB 或 >65535 個項目），不支援 |

---

## 4. BOM Consistency Check — BOM 與設計雙向對帳

BOM Footprint Check 問的是「BOM 說的料，包裝尺寸畫對了沒」；這一個問的是更前面的問題：**兩份文件對「這塊板子上到底有什麼料」有沒有共識**。

兩邊都可能是錯的那一邊，所以**兩條規則、一邊一個方向**：

| 規則 | 方向 | 問什麼 | 錯了會怎樣 |
|---|---|---|---|
| **RULE1** | BOM → Design | BOM 點名的位號，設計裡**有沒有放**、而且**沒有被標成 `/X`** | 買了不用的料；或更糟，兩份文件在上線那天才發現講的不是同一件事 |
| **RULE2** | Design → BOM | 設計上**會上板**的料（`Optional` 是空的或 `N/A`），BOM 裡**有沒有列** | 沒人去買，板子回來缺一顆 |

### 操作

跟 BOM Footprint Check 同一個形狀的對話框：一個 .xlsx 欄位 + Browse...，底下 Execute / Close，Enter 等於 Execute、Esc 等於 Close。兩個檢查常常是同一個人隔幾分鐘跑的，行為不一樣只會多一套習慣。

**① 先在 Project Manager 選範圍**

| 選的是 | 結果 |
|---|---|
| schematic / `.DSN` | 跑它底下所有頁 |
| **page / `.OPJ` / 沒選** | **不處理**，跳訊息說明是哪一種拒絕，然後關閉視窗 |

> [!NOTE]
> `.OPJ` 雖然解得出跟底下 `.DSN` 一樣的頁，這裡還是擋掉 —— 這是需求訂的（可以點的就是 schematic 跟 design 兩種），不是技術限制。要放寬就改 `DoBomConsistencyCheckExecute` 裡那一行 `[list schematic design]` 加上 `project`。
>
> 對話框上有一行灰字提醒選取範圍：Project Manager 的選取是一半的輸入，卻不在這個視窗上。

**② 選 BOM 檔，按 Execute**

| 欄位／按鈕 | 作用 |
|---|---|
| BOM File (.xlsx) | **每次開 Capture 都是空白**，理由同 BOM Footprint Check：BOM 改版比設計頻繁 |
| **Execute** | 檢查欄位 → 檢查 PM 選取 → 關視窗 → 走 Design → 讀 BOM → 跑兩條規則 → 開報告視窗 |
| **Close** | 只關視窗，不做任何事 |

欄位空的／讀不到檔的兩種錯**留著視窗**讓你當場改，其他每一條拒絕都會關窗。**有一邊沒讀成功就不做比對**：設計讀不到的話 RULE1 會把整份 BOM 報成沒上板、RULE2 什麼都不報；BOM 讀不到的話剛好反過來。兩個方向都會「很有自信地講錯話」，所以直接說哪一邊沒讀到。

BOM 檔欄位記住的資料夾跟 BOM Footprint Check **共用** `mBomInitDir` —— 兩個都是 BOM，放在同一個地方，兩個錨點只會多一個走樣的機會。檔案路徑則各自獨立（`mBomFile` / `mBomCsFile`），免得站在其中一個視窗前面的人被另一個視窗的 Browse 改掉欄位。

### 比的是 Reference Designator，不是 Part Reference

這是本版最重要的一件事：

| | 範例 | 一個對應到 |
|---|---|---|
| Part Reference | `ORN1A`, `ORN1B` | 畫在圖頁上的一個 **section** |
| Reference Designator | `ORN1` | 一個 **package** —— 真正被買、被擺、被 netlist 的那個元件 |

BOM 列的是元件，所以 BOM 上那一行寫的是 `ORN1`。拿 Part Reference 去比的話，每一個多 part 封裝的每一個 section 都會變成「BOM 沒聽過的料」。

Reference Designator 是**跟資料庫要的**，不是把字串尾巴的字母砍掉：砍字串會錯三種 —— `R21` 對上 `R210`、本來就以字母結尾的位號、還有用 `ORN1-1` 這種數字式編號的封裝（根本沒有字母可砍）。哪些 part 是同一顆封裝的 section 只有 Capture 知道。

取得順序是四層，第一個通過檢驗的就用：

| 來源 | 說明 |
|---|---|
| 1. `Reference` 屬性 | 跟原廠 DRC `capPartReferencePrefixMismatch.tcl` 讀的是同一個東西 |
| 2. `GetReferenceDesignator` | DboPlacedInst 的 API（Appendix A p.529） |
| 3. derived | `PQ31A` → `PQ31`。**只有封裝本身說這顆是多 part 的時候才允許**，兩種編號形式都解（`PQ31A` 與 `PQ31-2`） |
| 4. Part Reference 原樣 | 上面都沒答出來，那這顆就用自己的名字去比 —— 也就是沒讀封裝之前的舊行為 |

每一個候選值都要過兩關：**形狀上可能是這顆的封裝名**（相等／多一個 A–Z／多一個 `-數字`），以及**多 part 封裝時不得等於 Part Reference 本身**（section 的封裝名一定比自己短；回一個 `PQ31A` 等於沒回答，實測就遇過）。不像的就丟掉，該 part 退回用自己的名字比 —— 一個共用的錯值（例如 `S` 同時蓋住 `SU1`／`SQ4`／`SRN1`）會把三顆不相干的料焊成一筆沒人能處理的發現，那比降級嚴重得多。

Command Window 的設計側 dump 會把這件事攤開來，四欄加幾行統計：

```
  Pkg: 0 = single-part package, 1 = multi-part homogeneous, 2 = multi-part heterogeneous, - = not available
  RefDes           Part Reference   Pkg  Optional
  ORN1             ORN1A            1    -           <- derived
  ORN1             ORN1B            1    -           <- derived
  R6               R6               0    /X

  -> 1842 part(s) over 46 page(s), 1731 distinct Reference Designator(s), 1842 distinct Part Reference(s)
  -> 23 marked "/X" (not fitted), 1819 with Optional empty or "N/A" (fitted)
  -> Pkg: 1680 single-part, 148 multi-part homogeneous, 14 multi-part heterogeneous, 0 not available
  -> RefDes from: 1680 "Reference" property, 0 GetReferenceDesignator, 162 taken off the Part Reference, 0 left as the Part Reference
  -> 162 part(s) are a section of a multi-part package (RefDes differs from Part Reference)
```

- 設計裡確實有 `ORN1A`／`ORN1B` 卻看到**最後一行是 0**，代表封裝查詢沒生效、全部退回 Part Reference：比對照跑，但跑的是舊的那一套，BOM 的 `ORN1` 會被報成「設計裡沒有」。
- `Pkg` 欄是**獨立**從資料庫讀的，不是從前兩欄推的 —— 它跟 RefDes/Part Reference 這組答案互相對照。兩邊數字對不上時報告會直接寫一行 `NOTE` 說出來。
- 被退掉的候選值會列在該 part 行尾（`<- ignored ...`），結尾再給一個樣本清單，貼回來就知道資料庫實際回了什麼。

### Optional 怎麼讀

| 值 | 意思 | 誰在管 |
|---|---|---|
| `/X`、`/x` | **不上板** | RULE1 會查（BOM 點了它就是一筆不一致）；RULE2 不查（本來就不上板，BOM 不列是對的） |
| 空白、`N/A` | **上板** | RULE2 要求 BOM 必須有這一行 |
| 其他任何值 | 兩條規則**都不碰** | 報告結尾會說有幾顆 |

`DNI`、`option B`、某人打的一段備註 —— 這些是本工具沒被教過怎麼讀的句子，**猜哪一邊都更糟**：當成上板，RULE2 會去要一行可能根本不該存在的 BOM；當成不上板，RULE1 會去指控一份正確的 BOM。所以留著不動，但**數出來講**，免得「沒有發現」被讀成「全部都查過了」。值會去頭尾空白、不分大小寫。

### RULE1 — BOM 有，設計沒放或標了 `/X`

```
BOM_Consistency_Check_RULE1 - Part Reference in the BOM, not fitted in the design
   (the BOM's reference exists, but DSN mark not populated)
----------------------------------------------------------------
  CP701            not in the design                  BOM sheet "BOM" row 182
  R455             in the design but marked "/X"      BOM sheet "BOM" row 349
                     SCH1 / P12. LAN
  ORN1             in the design but marked "/X"      BOM sheet "BOM" row 77
                     ORN1A          SCH1 / P03. DDR
                     ORN1B          SCH1 / P04. DDR

  -> 1 not in the design, 2 marked "/X" - 3 Part Reference(s) the BOM calls for and the design does not fit
```

- **一個位號一筆，不是一列一筆。** 同一個位號在 BOM 出現三列是同一件事，引用第一次出現的那一列，還找得回工作表。
- 「沒放」跟「放了但標 `/X`」**分開列、分開標**：那是兩段對話、對的是兩個人（一個找 BOM 的主人，一個找把料標掉的人），混在一起列等於叫讀的人做報告該做的事。
- **上不上板看的是所有 placement。** `ORN1A` 上板、`ORN1B` 標 `/X` → 這顆封裝還是上板，BOM 那行是對的，不報。只有**每一個 placement 都是 `/X`** 才報。混合的那些只計數、不列出：多 part 封裝出現這種情形是常態，不是錯。

```
  (4 BOM reference(s) have one placement fitted and another "/X" - fitted, so not reported)
```

沒問題時：`BOM_Consistency_Check_RULE1: No mis-matching Part Reference found.`

### RULE2 — 設計會上板，BOM 沒列

```
BOM_Consistency_Check_RULE2 - fitted part in the design, not in the BOM
   (the DSN exists but not appear in xlsx BOM)
----------------------------------------------------------------
  PU12             Optional ""      SCH1 / P07. PCIE
  ORN7             Optional ""      2 placement(s):
                     ORN7A          SCH1 / P03. DDR
                     ORN7B          SCH1 / P05. DDR

  -> 2 fitted Reference Designator(s) not found in the BOM, over 3 placement(s)
```

**一個 Reference Designator 一筆，placement 列在它底下。**「`ORN7` 不在 BOM 裡」是一件事實、一顆要買的料，四個 section 報四次正是搬到 Reference Designator 要消掉的雜訊。placement 還是印出來，因為那是要去翻的地方 —— section 名加頁名，一行一個。同一個位號在同一頁重複收到（同一頁被兩個 occurrence 走到）只算一個 placement。

沒問題時：`BOM_Consistency_Check_RULE2: No mis-matching Part Reference found.`

#### 跳過清單 `mBomCsSkipPrefix`

RULE2 **不去問** BOM 的那些位號前綴，預設 `VT`：

```tcl
lappend ::mUtilMenu::mBomCsSkipPrefix TP   ;# 加一個前綴
set ::mUtilMenu::mBomCsSkipPrefix {}       ;# 全部都查
```

VT 這類東西放在設計裡但沒人會去買，「設計有、BOM 沒有」對它們每一顆都成立、而且什麼都沒說 —— 一整區永遠在的發現，把真正該看的擠出第一個畫面。

**兩個條件都要成立**才跳過：前綴相符（不分大小寫，比的是 **Part Reference**），**而且封裝是單 part（`Pkg 0`）**。只看前綴會連真的是元件的 VT-something 一起消音；`Pkg` 是 `-`（資料庫沒答）**不算 0**，不跳 —— 一個在資料庫沉默時照樣生效的排除會悄悄長大。**RULE1 完全不受影響**：BOM 列了一顆 VT 就是做了一個主張，主張還是要查。

跳掉什麼會數出來、點名出來：

```
  (87 fitted part(s) not looked up - single-part package and the Part Reference starts with VT: VT1, VT2, VT3, VT4, VT5, VT6, ...)
```

看不見的排除就是沒人能發現它壞掉的排除 —— 「沒有發現」前面默默丟掉兩百顆料，跟「沒有發現」不是同一句話。

### 位號怎麼算相符

預設**完全相同**（只是不分大小寫）—— `R1` 跟 `r1` 是同一個位號，字串其他部分一律不動。多 part 封裝已經由 Reference Designator 處理掉了，沒有字母要砍、沒有東西要猜。

`mBomCsPlacement 1` 會額外接受設計側多**一個** A–Z（BOM `R21` ↔ 設計 `R21A`..`R21D`，跟 BOM Footprint Check 同一套規則）。留給資料庫答不出來的那種情況：設計裡 `R21A`／`R21B` 是兩顆**各自封裝**的料，而 BOM 只寫一行 `R21`。Capture 把它們當兩個元件是對的，BOM 合成一行買也不算錯，**只有讀 BOM 的人說得準這份 BOM 是哪個意思** —— 所以是開關，不是規則。

字母**只從設計那一側砍**：BOM 寫 `R21C`、設計只有 `R21` → 不相符。BOM 負責點名、設計負責擺放。這個開關**只影響 BOM Consistency Check**；BOM Footprint Check 本來就建立在後綴規則上，不看它。

---

## 5. Close Page — 收乾淨但留住 Project Manager

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
| `mBomCsPlacement` | `0` | BOM Consistency Check 的位號比對：`0` = 要完全相同，`1` = 設計側可多一個 A–Z |
| `mBomCsSkipPrefix` | `VT` | BOM Consistency Check RULE2 不去問 BOM 的位號前綴（且封裝須為單 part）。清空代表全部都查 |
| `mClosePageMode` | `perdesign` | Close Page 的模式 |
| `mTimeCompare` | `1` | 印出比對各階段耗時 |
| `mQuiet` | `0` | 1 = 不把 dump 印進 Command Window |
| `::BOTH_N_O_COMP` | `1` | MultiPageCmp / AllPagesComp 是否雙向比對（全域變數，非 namespace） |
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
