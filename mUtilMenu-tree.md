# mUtilMenu.tcl - proc 結構樹

程式：`tclscripts\capAutoLoad\mUtilMenu.tcl`（本文件在 `tclscripts\` 根目錄）
行號對應 1859 行版本。改過程式後行號會漂，但層級關係不會 —— 用「proc 名稱」指位置最穩。

---

## 0. 載入 / 註冊（檔案最尾端 `::mUtilMenu::init` 在 L1853 被呼叫）

```
::mUtilMenu::init                          L1806   ← 唯一 autoload 入口
├── ::mUtilMenu::initXmlMenu               L1735   Path A：InsertXMLMenu 建 mUtil 主選單
│   ├── RegisterAction  x6                 L1737-1748
│   ├── InsertXMLMenu  "mUtil" popup       L1750   ← 新增「主選單本身」改這裡
│   ├── InsertXMLMenu  "mUtilSchCompare"   L1759   ← 新增選單項目複製這一段
│   ├── InsertXMLMenu  "mUtilClosePage"    L1765
│   └── RefreshMenu                        L1771
└── ::mUtilMenu::initAccessoryMenu         L1796   Path B：AddAccessoryMenu（文件化做法）
    ├── _cdnCapTclAddPageCustomMenu   → addPageAccessoryMenu    L1786
    └── _cdnCapTclAddDesignCustomMenu → addDesignAccessoryMenu   L1791

::mUtilMenu::remove                        L1811   關掉三個視窗 + DeleteXMLMenu (L1816-1819)
::mUtilMenu::diag                          L1827   Command Window 診斷用
```

### 選單 → callback 的轉接層（全部都只是薄薄一層）

```
Path A (mUtil 主選單)
├── XmlSchematicCompare       L1732 → DoSchematicCompare "mUtil menu"
└── XmlClosePage              L1733 → DoClosePage        "mUtil menu"

Path B (Accessories > mUtil)
├── PageSchematicCompare      L1781 (pPage pOcc) → DoSchematicCompare
├── PageClosePage             L1782 (pPage pOcc) → DoClosePage
├── DesignSchematicCompare    L1783 (pLib)       → DoSchematicCompare
└── DesignClosePage           L1784 (pLib)       → DoClosePage
```

---

## 1. 功能主線：三個視窗接力

```
對話框 1（選兩個 .DSN） → 對話框 2（選 page，兩欄）→ 結果視窗（可複製的 text）
DoSchematicCompare        ShowPageSelector           ShowResultWindow
```

```
DoSchematicCompare {pVia}                          L1630  ★ 對話框 1
├── package require Tk / 失敗就跳訊息                 L1634
├── HideTkRoot                                     L1622
├── SetAppWindowAsParent                           L1660
├── [widget] Default Folder 列  → BrowseInitDir     L150   ← 選預設資料夾
├── [widget] Design File 1(O)  → BrowseDesign      L166   ← 選 .dsn（傳變數名）
├── [widget] Design File 2(N)  → BrowseDesign      L166
│           三列 grid 排版                           L1684-1696
├── [button] Execute  L1703     → DoSchematicCompareExecute
└── [button] Cancel / Esc       → CloseSchematicCompare   L1613

DoSchematicCompareExecute                          L1576
├── 兩欄位有空 → capDisplayMessageBox 就 return      L1588
├── CloseSchematicCompare                          L1613
├── Open <path>          （Capture 內建，開兩個設計）  L1598
└── ShowPageSelector $lA $lB                       L1606 → L1493
```

```
ShowPageSelector {pFileA pFileB}                   L1493  ★ 對話框 2（兩欄 page 勾選）
├── GetDesignPages  x2                             L216   ← 走資料庫拿 {sch page} 清單
├── SortPages       x2                             L1103  ← mPageSortMode 排序
├── Page_name_mapping x2（兩個方向）                  L1542-1543  ← 兩欄各自要標紅的判定
│      lMarksA = mapping(B, A)   lMarksB = mapping(A, B)
│      任一邊 0 頁就整個跳過，不上色
├── BuildPageColumn colA + lMarksA + "(O)"          L1548
├── BuildPageColumn colB + lMarksB + "(N)"          L1549 → L1211  ← 欄位長相改這裡
│   └── MakeScrollBox                              L1184  ← 捲動 canvas
├── [button] Refcompare → DoPageRefCompare         L1564
├── [button] Compare    → DoPageCompare            L1562
└── [button] Close/Esc  → ClosePageSelector        L1266
```

```
DoPageCompare      L1402  → RunPageCompare {parts symbols nets buses} "Compare"    full
DoPageRefCompare   L1406  → RunPageCompare {parts}                    "Refcompare" ref
                                    ↑ ★ 新增第三種比較就在這裡加一個 Do... + 一顆按鈕

RunPageCompare {pWhat pLabel {pMode none}}         L1412  ★ 比較流程總管
├── GetCheckedPages A / B                          L1273  （各欄必須剛好勾 1 頁，否則訊息框）
├── PageLabel                                      L1489  "SCHEMATIC1 / PAGE1"
├── DumpPageInfo  x2（O 先、N 後）                    L1067
├── lWinTitle 決定結果視窗 banner                     L1451-1455
│      ref  → "Schematic Page Reference Compare Result"
│      full → "Schematic Page Compare Result"
├── pMode eq "ref"  → DumpRefCompare               L571   （分支在 L1460）
├── pMode eq "full" → DumpFullCompare              L753
└── ShowResultWindow $lWinTitle $lMsg              L1482  ← 失敗才退回 capDisplayMessageBox
                                                          訊息框文字組在 L1447/L1478
```

---

## 2. 結果視窗（可用滑鼠複製）

```
ShowResultWindow {pTitle pText}                    L1335  ★ 取代舊的 capDisplayMessageBox
├── Tk 不在 → 退回 capDisplayMessageBox              L1341
├── 每次重建（第二次比較會換掉舊報告）                  L1348
├── text -wrap none -font TkFixedFont              L1362  ← 報告是 format 對齊的，不能自動換行
│   + 垂直/水平 scrollbar                            L1366-1367
├── configure -state disabled                      L1375  ← 唯讀，但選取/複製照常
└── [button] Select All L1384 / Copy / Close        L1378-1388
    bind Control-a / Control-c / Escape             L1392-1394

CloseResultWindow       L1303   destroy（remove 也會叫它）
SelectAllResultText     L1308   tag add sel 1.0 end-1c
CopyResultText          L1321   有選取就複製選取，沒選取就複製全部
```

`-state disabled` 的行為（在 Capture 內建的 Tk 8.6.5 實測過）：

| 動作 | 結果 |
|---|---|
| 滑鼠拖曳選字 | 可以（class binding 不受 disabled 影響） |
| Ctrl+C / Copy 鈕 | 可以 |
| 打字 / 貼上 / `insert` | 靜默忽略，內容不會被改（不會丟錯） |
| Select All 鈕 / Ctrl+A | 可以 |
| Esc / Close 鈕 | 關閉視窗 |

---

## 3. Page name 對映（兩欄互相標紅）＋ (O)/(N) 表頭

```
Page_name_mapping {pPagesA pPagesB}                L1165  ★ 回傳與 pPagesB 等長的 0/1 清單
├── StripPageNamePrefix  每個名字都過一次             L1153
│      └── string trimleft + trim，字元集 = mPageNamePrefixChars  L119
└── 規則：只比 page name（不比 schematic 名），去掉開頭標記後必須「完全相同」（大小寫有別）

ShowPageSelector 呼叫兩次，參數對調                    L1542-1543
├── lMarksA = Page_name_mapping $mPagesB $mPagesA   → A 欄有、B 欄沒有 → A 標紅
└── lMarksB = Page_name_mapping $mPagesA $mPagesB   → B 欄有、A 欄沒有 → B 標紅

BuildPageColumn {... {pMarks {}} {pTag ""}}        L1211
├── 表頭 "(O) one.dsn" / "(N) two.dsn"              L1212-1216  ← pTag 空字串就只印檔名
└── pMarks 該格為 0 → checkbutton configure -foreground red -activeforeground red   L1256
    pMarks 為空 → 完全不上色（任一邊 0 頁時就是這個狀態）
```

規則整理（A = (O) 舊檔，B = (N) 新檔）：

| A 欄 | B 欄 | 結果 |
|---|---|---|
| `PAGE2` | `PAGE2` | 相同 → 兩邊都不變 |
| `PAGE2` | `~PAGE2` / `**PAGE2` / `- PAGE2` | 去標記後相同 → 兩邊都不變 |
| `*PAGE3` | `PAGE3` | 去標記後相同 → 兩邊都不變 |
| （無） | `PAGE9` | B 多出來的 → **B 標紅** |
| `OLD_ONLY` | （無） | A 才有的 → **A 標紅** |
| `PAGE1` | `page1` | 大小寫不同 → **兩邊都紅** |
| — | `***`（去掉標記後是空字串） | → **紅色** |
| 有頁 | 0 頁（讀檔失敗） | 整個跳過，兩欄都不上色 |

跳過的開頭字元：`* - ? ~ + % $ # @ !` 以及空白 / tab（幾個都可以、混著也可以，只認開頭；
名字中間的同樣字元算名字的一部分，例如 `PAGE-1` 不會被動到）。

---

## 4. 資料收集層（走 DBO 資料庫，Collect = 拿資料，Print = 印出來）

```
DumpPageInfo {pDsnPath pSchName pPageName ?pWhat?} L1067  回傳 dict: parts/symbols/nets/buses
├── FindPage                                       L1016  {sch page} → DboPage 物件
├── parts   : CollectPageParts   L457  + PrintPartRows   L506
├── symbols : CollectPageSymbols L834  + PrintSymbolRows L888   (OFFPAGE/GLOBAL/PORT)
├── nets    : CollectPageNets    L960  + PrintNetRows    L998
└── buses   : CollectPageBuses   L907  + PrintBusRows    L947   (WIRE_BUS/WIRE_BUNDLE)
        ↑ ★ 新增一種物件（例如 Title Block、Text）就複製一組 Collect+Print 掛進來，
          再到 DumpPageInfo 加一個 lsearch 區塊、DumpFullCompare 加一個 category

Parts row 欄位順序（CollectPageParts L493）:
  0 Part Reference  1 Value  2 package  3 lib  4 位置  5 pins  6 PCB Footprint  7 Part_Number  8 Optional

單獨用的方便包裝（Command Window 直接叫）
├── DumpPageParts    L523
├── DumpPageSymbols  L897
├── DumpPageBuses    L955
├── DumpPageNets     L1009
└── DumpPages        L1127  ← 四種排序模式對照 PROJECT_MANAGER_VIEW
```

---

## 5. 比較邏輯層

```
DumpRefCompare {pRowsO pRowsN}                     L571   ★ Refcompare：Parts 依 Reference 配對
├── IndexPartRows   x2                             L555   建 ref → row 索引（重覆 ref 會 Trace）
├── PartCmpFields                                  L537   ← ★ 要多比一個屬性就改這一個 proc
├── PartCmpStr                                     L545
├── 輸出 Add / Remove / Changed                     L613-638
└── RefListStr                                     L820   訊息框列名（超過上限就 +N more）

DumpFullCompare {pDictO pDictN}                    L753   ★ Compare：四大類全部 signature diff
├── lCats 表（Parts/Symbols/Nets/Buses）             L754   ← ★ 加新分類就加一列
├── PartSigs    L673 ┐
├── SymbolSigs  L691 ├─ 每個回傳 {signature shortName}
├── NetSigs     L702 │  signature 決定 diff 結果，shortName 進結果視窗
├── BusSigs     L714 ┘
├── SigDiff                                        L727   multiset 差集 → {onlyInN onlyInO}
└── RefListStr                                     L820
```

---

## 6. 共用工具（leaf，幾乎所有上面的東西都會用到）

```
文字 / 屬性
├── CStr        {pObj pGetter}      L441   CString getter → Tcl string
├── PropStr     {pObj pPropName}    L313   單一屬性
├── PropStrAny  {pObj pNames}       L431   多個名字試到有值（Part_Number / "Part Number"）
├── OrDash                          L340   空值印 "-"
└── RefListStr                      L820

座標 / 幾何
├── Coord       {pPage pDoc}        L326   內部單位 → mCoordMode (user/doc)
├── PointStr                        L347   "(x,y)"
├── ObjLocStr                       L359   GetLocation + bbox
└── WireSegStr                      L373   "(x1,y1)-(x2,y2)"

網路名稱
├── WireAliases {pWire pStatus}     L386
└── NetLabel    {pNet pNames}       L411   aliases → GetName → "Net Name"/"Name" → "(unnamed)"

Page 名稱
├── StripPageNamePrefix             L1153
└── PageLabel                       L1489

Iterator 管理（SWIG constructor 會佔用命令名，必須輪流換名）
├── NextIterName {pTag}             L304
└── DropIter     {pCmd}             L309

視窗
├── HideTkRoot              L1622   藏掉 package require Tk 產生的空白 "." 視窗
├── CloseSchematicCompare   L1613
├── ClosePageSelector       L1266
└── CloseResultWindow       L1303

其他
├── Trace {pMsg}                    L139   puts + mDebug 時彈訊息框
└── True / Action / Enabler         L135-137  RegisterAction 用的固定回傳 true
```

---

## 7. namespace 變數（L56-132）

| 變數 | 用途 |
|---|---|
| `mMenuId` / `mMenuLabel` | L59-60 主選單 id / 顯示字 |
| `mCmpWin` `mCmpFileA` `mCmpFileB` | L75-77 對話框 1 狀態 |
| `mCmpInitDir` | L82 Browse 預設資料夾 |
| `mPagesWin` `mPagesA` `mPagesB` | L87-89 page selector 清單 |
| `mPagesFileA` `mPagesFileB` | L92-93 目前 selector 對應的兩個 .dsn |
| `mPageSelA` `mPageSelB` (array) | L94-97 checkbox 變數，index = 清單位置 |
| `mResultWin` | L102 結果視窗路徑 `.mUtilCmpResult` |
| `mPageSortMode` | L113 dictionary / ascii / dbreverse / dborder |
| `mPageNamePrefixChars` | L119 Page_name_mapping 要跳過的開頭字元集 |
| `mIterSeq` | L122 NextIterName 序號 |
| `mCoordMode` | L127 user（英吋）/ doc（內部整數） |
| `mDebug` | L132 1 = 每個 callback 都彈訊息框 |

---

## 8. 「我要加功能」快速對照

| 想做的事 | 動這些地方 |
|---|---|
| mUtil 選單多一個項目 | `initXmlMenu` L1759 複製一段 InsertXMLMenu + RegisterAction L1740 + 新 `Xml***` 轉接 proc L1732 + `remove` L1816 補 DeleteXMLMenu |
| Accessories 也要有 | `addPageAccessoryMenu` L1786 / `addDesignAccessoryMenu` L1791 各加一行 |
| page selector 多一顆按鈕 | `ShowPageSelector` L1560-1570 + 新 `DoPage***` L1402 附近 |
| 新的比較模式 | 新 `DoPage***` → `RunPageCompare $pWhat $pLabel <newmode>`，再到 L1460 的 `pMode` 分支加一支，banner 在 L1451 |
| 改結果視窗 banner | `RunPageCompare` L1451-1455 的 `lWinTitle` |
| 結果視窗改大小 / 字體 | `ShowResultWindow` L1362 的 `-width 110 -height 30 -font TkFixedFont` |
| 結果視窗多一顆按鈕（存檔…） | `ShowResultWindow` L1378-1388，照 Copy 鈕的樣子加 |
| 讓結果視窗可編輯 | 拿掉 L1375 的 `configure -state disabled` |
| Refcompare 多比一個屬性 | 只改 `PartCmpFields` L537（印出與 diff 都吃它） |
| Compare 多比一類物件 | `CollectPageXxx` + `PrintXxxRows` + `DumpPageInfo` L1067 加區塊 + `XxxSigs` + `DumpFullCompare` L754 的 lCats |
| Parts 多抓一個欄位 | `CollectPageParts` L493 的 lappend（欄位是 index，後面接在第 9 位最安全）+ `PrintPartRows` L506 |
| 改 page 對映規則 | `Page_name_mapping` L1165（比對邏輯）、`mPageNamePrefixChars` L119（跳過的字元） |
| 改標紅顏色 / 改成粗體、刪除線 | `BuildPageColumn` L1256 那行 `configure` |
| 改表頭 (O)/(N) 文字 | `ShowPageSelector` L1548-1549 傳進去的字串；組法在 `BuildPageColumn` L1212-1216 |
| 只標單邊 | `ShowPageSelector` L1542 或 L1543 拿掉一行、對應的 `$lMarks?` 傳 `{}` |
| 改座標單位 / 排序 | `mCoordMode` L127 / `mPageSortMode` L113 |
| 對話框 1 多一個輸入欄 | `DoSchematicCompare` L1662-1696（grid row 往下加）+ namespace 變數 L75 |

---

> 備份提醒：`mUtilMenu.tcl` 必須放在 `capAutoLoad`（autoload 目錄），而 Cadence hotfix 會清掉
> 那個目錄。本文件刻意放在 `tclscripts` 根目錄，比較不會被一起刪掉；更新 Cadence 前還是先把
> mUtilMenu.tcl 另外備份一份。
