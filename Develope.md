# OrCAD Capture 17.4 TCL 客製開發紀錄

工作目錄:`G:\Cadence\SPB_17.4\tools\capture\tclscripts`
主要參考:`OrCAD_Capture_TclTk_Extensions.pdf`(Appendix A = 完整 command list,p.113-146)

> 注意:`capAutoLoad\mUtilMenu.tcl` 是自製檔案,不是 Cadence 原廠的。安裝 hotfix 會把它刪掉,升版後要記得補回。

---

## 項目 1 — mUtil > Schematic Compare

**日期**:2026-08-19
**狀態**:完成(Execute 目前只出 message box,尚未接真正的比對)
**變更檔案**:`capAutoLoad\mUtilMenu.tcl`

### 1.1 需求

把 mUtil 選單下的 `EXP output` 改成 `Schematic Compare`,點下去後:

1. 彈出一個頁面
2. 頁面中有 2 個 File 欄位,每個欄位旁邊有 `Browse` 按鈕,可各自選擇 DSN 檔
3. 最下面有 `Execute` 和 `Cancel`
4. 按 `Cancel` → 頁面消失
5. 按 `Execute` → pop up 一個 message,文字為 `CCompare Schematic Circuit...`

### 1.2 前置調查

從 PDF 抽出全文後搜尋 Appendix A,確認可用的 API:

| 指令 | PDF 位置 | 用途 |
|---|---|---|
| `capDisplayMessageBox(message, caption, type=MB_OK)` | p.140-141 | Execute 的 message box |
| `SetAppWindowAsParent(lChildWindowHandle)` | p.134 | 讓 Tk 視窗掛在 Capture 主視窗底下 |
| `svsDiffDesigns(pSrcDesign, pDstDesign, lOccMode=0, ECO_MODE=0)` | p.140 | **兩個 design 的真正比對入口**(本次尚未使用) |
| `capCloseChildViewsExceptCurrent()` | p.136 | 既有的 Close Page 功能沿用 |

`Tools > Export Properties` 在 Appendix A 裡查不到任何對應指令,這也是舊的 `EXP output` 一直是空殼的原因 — 改成 Schematic Compare 正好把這個死項目換掉。

### 1.3 實作內容

**選單標籤與節點**(兩條路徑都改,維持原本可對照的設計)

- `mUtil` top-level(`InsertXMLMenu`):`EXP output` → `Schematic Compare`,節點 id `mUtilExpOut` → `mUtilSchCompare`,action/enabler 改為 `mUtilSchCompareAction` / `mUtilSchCompareEnabler`
- `Accessories > mUtil`(`AddAccessoryMenu`):同步改標籤

**移除**

- `mExportPropsCmd` 變數、`DoExportProperties` proc(連同它那段「開 journaling 去找指令」的註解)

**新增變數**

```tcl
variable mCmpWin   ".mUtilSchCompare"
variable mCmpFileA ""
variable mCmpFileB ""
```

**新增 proc**

| proc | 作用 |
|---|---|
| `DoSchematicCompare {pVia}` | 建 dialog。先 `package require Tk`,失敗就出說明訊息;已開啟則 raise 不重建 |
| `BrowseDesign {pVarName}` | `tk_getOpenFile`,filter `{"OrCAD Design Files" {.dsn}}`,結果經 `file nativename` 寫回欄位 |
| `DoSchematicCompareExecute {}` | 關 dialog → `capDisplayMessageBox "CCompare Schematic Circuit..." "Schematic Compare"` |
| `CloseSchematicCompare {}` | `destroy` dialog。Cancel / 右上 X / Esc 共用 |

**改名的 proc**:`XmlExportProperties` → `XmlSchematicCompare`、`PageExportProperties` → `PageSchematicCompare`、`DesignExportProperties` → `DesignSchematicCompare`

**Dialog 結構**

```
.mUtilSchCompare                     toplevel, title "Schematic Compare"
                                     wm resizable 1 0(只允許橫向拉寬)
                                     SetAppWindowAsParent [winfo id ...]
 ├─ .body   frame -padx 10 -pady 10  grid,column 1 -weight 1(欄位隨視窗拉伸)
 │   ├─ lblA/entA/btnA   row 0       "Design File 1:" / entry(width 60) / "Browse..."
 │   └─ lblB/entB/btnB   row 1       "Design File 2:" / entry(width 60) / "Browse..."
 └─ .btns   frame -padx 10           pack -side bottom -fill x
     ├─ execute  "Execute" -default active
     └─ cancel   "Cancel"            兩顆都 pack -side right
```

**額外處理的細節**(規格沒寫但實務上需要)

- 重複點選單不會疊出第二個視窗 → 改為 `wm deiconify` + `raise` + `focus`
- `wm protocol WM_DELETE_WINDOW` 綁到 `CloseSchematicCompare`,右上 X 行為與 Cancel 一致
- `<Return>` = Execute、`<Escape>` = Cancel
- `remove` proc 連舊的 `mUtilExpOut` 節點一起刪,所以熱重載不會殘留舊項目
- `diag` proc 加入 Tk 版本回報,以及 `svsDiffDesigns` / `capDisplayMessageBox` / `SetAppWindowAsParent` 的存在性檢查

### 1.4 驗證方式

不開 Capture,直接用 Cadence 自己附的 interpreter 驗:

- `G:\Cadence\SPB_17.4\tools\bin\tclsh.exe`(Tcl 8.6)— 語法檢查
- `G:\Cadence\SPB_17.4\tools\bin\wish.exe`(Tk 8.6)— 真的把 dialog 建出來,並用 `$w.btns.execute invoke` 觸發按鈕

把 `capDisplayMessageBox` / `SetAppWindowAsParent` 先 stub 成普通 proc 再 source。

兩個踩到的坑:

1. `wish.exe` 是 GUI subsystem 程式,PowerShell **不會等它**,`$LASTEXITCODE` 是空的 → 必須用 `Start-Process -Wait -PassThru`
2. `wish.exe` 在 Windows 沒有 console,`puts` 完全看不到 → 把 `puts` rename 掉改寫檔案,再讀 log

(另外:Read 工具讀 PDF 需要 poppler,這台機器沒裝;改用已安裝的 `pypdf` 抽全文。)

### 1.5 驗證結果

```
info complete: OK        source: OK                      (tclsh 8.6)

toplevel exists: 1   title: Schematic Compare
  .mUtilSchCompare.body.lblA    Label    text=Design File 1:
  .mUtilSchCompare.body.entA    Entry
  .mUtilSchCompare.body.btnA    Button   text=Browse...
  .mUtilSchCompare.body.lblB    Label    text=Design File 2:
  .mUtilSchCompare.body.entB    Entry
  .mUtilSchCompare.body.btnB    Button   text=Browse...
  .mUtilSchCompare.btns.execute Button   text=Execute
  .mUtilSchCompare.btns.cancel  Button   text=Cancel

第二次呼叫後 body 子元件數 = 6                            ← 沒有疊加
按 Execute → MSGBOX caption="Schematic Compare"
                    text="CCompare Schematic Circuit..."
           → toplevel exists = 0                        ← 視窗關閉
按 Cancel  → toplevel exists = 0
```

截圖確認外觀正確,視窗實際尺寸 567 × 167。

### 1.6 已知限制 / 待確認

- **Tk 依賴**:Capture 預設沒把 Tk 接起來(PDF §1.4「Capture TCL/Tk Advanced Environment Setup」,p.15-16)。若 `package require Tk` 失敗,點選單會跳出說明訊息而不是 dialog。`::mUtilMenu::diag` 會回報 Tk 狀態。
- **`CCompare` 拼字**:照需求原文放入,包含開頭兩個 C。若是 typo 需改為 `Compare`。
- **Execute 後關閉 dialog**:需求未指定,目前選擇關閉。若要留著視窗連續比對需調整。
- **沒有輸入檢查**:兩個欄位空白也會直接出 message。等接上 `svsDiffDesigns` 再加驗證比較合理。

### 1.7 後續

接真功能只需替換 `DoSchematicCompareExecute` 裡那一行:

```tcl
# 現在
catch { capDisplayMessageBox "CCompare Schematic Circuit..." "Schematic Compare" }
# 改成
svsDiffDesigns $mCmpFileA $mCmpFileB
```

此註記已寫在 `mUtilMenu.tcl` 檔頭。

### 1.8 熱重載

```tcl
::mUtilMenu::remove
source {G:/Cadence/SPB_17.4/tools/capture/tclscripts/capAutoLoad/mUtilMenu.tcl}
```

### 1.9 附帶結論:PROJECT_MANAGER_VIEW pane 寬度

同一次工作中順帶查證的問題 —「能否讓 Project Manager pane 開啟時寬度為 1/4?」

**結論:Capture 17.4 沒有任何 TCL API 可以做到。**

- Application 層只有 `SetAppWindowAsParent`、`GetParent`、`capFindActivateWindow`、`capCloseChildViewsExceptCurrent`、`EnableAllWindowCloseMenu`,都不能改視窗幾何
- 所有 `GetSize` / `SetSize` 都屬於 Dbo 物件(page size、package size、DIB size),與 UI 無關
- `PROJECT_MANAGER_VIEW` 只是 menu 的 view scope 字串,用於 `capAutoLoad\capTCLMenu.tcl:28` 的 `CanAddMenu` 判斷,不是可操作的 pane 物件

替代路徑:停靠版面由 BCGSoft control bar 存在 registry

```
HKCU\Software\OrCAD\CaptureWorkSpaceEx\17.4.0\BCGWorkspace
    ├─ WindowPlacement
    ├─ BCGPBaseControlBar-<id>
    └─ BCGPControlBar-<id>
```

做法:手動拖到想要的寬度 → **正常關閉** Capture(exit 時才寫入)→ `reg export` 該 key,之後 import 還原。
未驗證項:哪一個 `<id>` 對應 Project Manager(59392、13144、7001… 沒有標籤),需要拖動前後 dump 比對才能確定。

---

## 項目 2 — Page 選擇器、Page Dump 與 O/N 比對

**日期**:2026-08-20 ~ 2026-08-21
**狀態**:程式完成,離線 stub + wish 版面測試通過;**尚未在 Capture 內實跑驗證**
**變更檔案**:`capAutoLoad\mUtilMenu.tcl`

### 2.1 交辦指令原文(依序,共 11 次)

保留原話,因為需求是逐次累加的,語意細節(例如「只比 Value/PCB Footprint/Part_Number/pins」)後面都成了實作依據。

1. `ShowPageSelector` 中 `GetDesignPages` 得到的 Page List 和 `PROJECT_MANAGER_VIEW` 顯示的順序是反過來的,所以請反過來顯示。另外下方 close button 右邊再顯示一個 button `Compare`,按下時檢查 `frame $lBody.colA` `$lBody.colB` 是否其各只有一個 checkBox 被打勾,若不合條件 pop up MessageBox `Please select each one Page to compare`。若滿足條件 pop up MessageBox 顯示字串 `Will Compare` 被選上的 colA Page 和被選上的 colB Page 名稱。
2. Compare button 改放在 close button **左邊**。另外 `GetDesignPages` 讀出來的順序和 `PROJECT_MANAGER_VIEW` 內 page 顯示順序**還是有微差**,是 `set lSession $::DboSession_s_pDboSession` 要作 initial 的動作嗎?
3. `DoPageCompare` 中,額外在 Command Window 顯示出兩個選定頁面內的**所有元件和 netlist 的資訊**。
4. part 和 net 能否也顯示它在該 Page 的**位置**?如 net 的兩端點位置。之後我要比較這 2 個頁面 dump part & net 值的位置差異互相比出來。
5. part 除了 `Part Reference` `Value` `PCB Footprint` 外,再多加 `Part_Number` 欄位。
6. (將以上整理寫入 `Develope.md` 項目 2)
7. part 列表之後多加列出 **Off-Page Connector、Power、GND** 的名字和位置?表列 Net 之後多加 **bus 資訊含 2 個端點**?另外 Nets 名稱為何顯示 `(unnamed)`,可以改讀取 **Name properties** 顯示嗎?
8. part 資訊再多加 `Optional` 欄位。另外 `ShowPageSelector` 下方 `Close` `Compare` 前再加一個按鈕 `Refcompare`,功能和 `DoPageCompare` 類似,但**只 dump Parts**。
9. `label $lBody.lblA` 改為 `Design File 1(O):`、`lblB` 改為 `Design File 2(N):`。之後 `DoPageRefCompare` 對 Parts ref 內容做比對:FileB(N,new)有而 FileA 沒有的設為 **Add components**;FileB 沒有而 FileA 有的設為 **Remove components**,顯示在 `capDisplayMessageBox` 之後。若兩邊 Parts name 及其資訊均相同,顯示 **all the same**。註:比較 Parts 不用比座標,只要比 `Value`、`PCB Footprint`、`Part_Number`、`pins`。
10. Parts RefCompare 直接改在 `RunPageCompare` 內做完,**不要出現 MessageBox 按 OK 再去 show 另一個 MessageBox** 顯示結果。
11. 同樣的,`DoPageCompare` 比對完 O 和 N 的 **Parts / Symbols / Nets / Buses**,若相同顯示 `all the same`,否則 pop up MessageBox **分段顯示**:FileB 有而 FileA 沒有的列在 `New:` 下方,FileB 沒有而 FileA 有的列在 `Remove:` 下方,四類都要比對顯示。

### 2.2 前置調查 — 所有 DBO 呼叫都有原廠 script 佐證

不靠記憶寫 API。每一個呼叫都在 Cadence shipped script 找到實際使用點(檔頭註解也記了出處):

| 呼叫 | 出處 |
|---|---|
| `NewPartInstsIter` / `NextPartInst` | `capAutoLoad\capAssociatePSpiceModel.tcl:343` |
| `DboPartInstToDboPlacedInst` | `capAutoLoad\capAssociatePSpiceModel.tcl:347` |
| `GetSourceLibName` / `GetPackage` | `capAutoLoad\capAssociatePSpiceModel.tcl:349,351` |
| `GetEffectivePropStringValue` | `capAutoLoad\capAssociatePSpiceModel.tcl:359` |
| `NewPinsIter` / `NextPin` / `GetPinName` | `capDRC\capPortPinMismatch.tcl:101,103,109` |
| `DboPageNetsIter` / `NextNet` | `capDB\capShortNet.tcl:133,134` |
| `DboNetWiresIter` / `NextWire` | `capDB\capShortNet.tcl:110,111` |
| `DboWireAliasesIter` / `NextAlias` | `capDB\capShortNet.tcl:82,83` |
| `GetStartPoint` / `GetEndPoint` | `capDRC\capOverlapWires.tcl:41,44` |
| `DboTclHelper_sGetCPointX` / `...Y` | `capDRC\capOverlapWires.tcl:42,43` |
| `GetLocation` | `capAlignObject\capObjectAlignment.tcl:413` |
| `GetBoundingBox` / `sGetCRectTopLeft` / `sGetCRectBottomRight` | `capAlignObject\capObjectAlignment.tcl:375,377,704` |
| `GetPhysicalGranularity`(doc→user 單位) | `capDRCFramework\tcl\capCustomDRC.tcl:159` |
| `Part Number` 屬性名拼法 | `capCustomSamples\capGenerateBOM.tcl:119` |
| `NewOffPageConnectorsIter` / `NextOffPageConnector` | `capDRCFramework\tcl\capProcessDRC.tcl:81,82` |
| off-page connector 的 `GetName` | `capFindAndReplace\tcl\capDesignUtil.tcl:425` |
| `NewGlobalsIter` / `NextGlobal`(power/GND) | `capDRCFramework\tcl\capProcessDRC.tcl:46,47` |
| `NewPortsIter` / `NextPort` / `GetName` | `capDRC\capPortPinMismatch.tcl:31,32,38` |
| `NewWiresIter`(page)/ `NextWire` | `capDRCFramework\tcl\capProcessDRC.tcl:30,31` |
| `NewWiresIter`(net,method 形式) | `capDRC\capOverlapWires.tcl:172` |
| `NewAliasesIter`(wire,method 形式) | `capFindAndReplace\tcl\capDesignUtil.tcl:339`、`orPrmDboStreamer.tcl:993` |
| `WIRE_BUS` / `WIRE_BUNDLE` 物件型別 | `capAlignObject\capObjectAlignment.tcl:371-373` |
| `DBGLOBAL` 型別(power/GND 同一桶) | `cdnTclEncrypted\orPrmDboStreamer.tcl:1721` |
| 四種 instance 都能用 `GetLocation` + `GetBoundingBox` | `cdnTclEncrypted\orPrmDboStreamer.tcl:1755,1798` |

`capDRCFramework\tcl\capProcessDRC.tcl` 的 `capProcessPageObjects` 是**page 層物件的完整清單**(wires / globals / ports / off-page connectors / title blocks / bus entries…),下次要再加區塊先看它。
`cdnTclEncrypted\orPrmDboStreamer.tcl` 雖在 encrypted 目錄但是明碼,是最完整的 DBO 走訪範例(streamInstance / streamWire / streamAliases…)。

**`$::DboSession_s_pDboSession` 不需要任何 initial 動作。** 那個全域就是 Capture 已建好的 session 指標,`DboSession -this $lSession` 只是把它包成 Tcl 物件 — 這是原廠 14 個檔案的共同寫法(`capCM\tcl\capCMImpl.tcl:48`、`capDB\capLibPropUtil.tcl:90`、`capDB\capShortNet.tcl:179`…),全部都沒有 init。而且 session 沒 ready 時 `GetDesignAndSchematics` 會回 NULL 直接丟 error,不會只是「順序有微差」。

**順序微差的真因**:iterator 給的是資料庫內部(插入)順序,Project Manager 是排序後才顯示。頁名剛好照建立順序命名時 `lreverse` 看起來會對,但只要有頁是後來補的、改過名,或有 `PAGE2` / `PAGE10` 這種數字位數不同的,就會錯位。**結論:不要信 iterator 順序,自己排。**

### 2.3 實作內容

**namespace 新增變數**

```tcl
variable mPagesFileA ""        ;# 選擇器目前對應的兩個 .DSN,Compare 訊息要用
variable mPagesFileB ""
variable mPageSortMode "dictionary"   ;# dictionary | ascii | dbreverse | dborder
variable mIterSeq 0            ;# SWIG iterator 命令名的流水號
variable mCoordMode "user"     ;# user(吋,2 位小數) | doc(內部整數)
```

**新增 proc**

| proc | 作用 |
|---|---|
| `SortPages {pPages}` | 依 `mPageSortMode` 排序 `{schematic page}` list |
| `DumpPages {pDsn}` | 診斷用:同一份 page list 印出四種排序,拿去對 Project Manager 樹 |
| `DoPageCompare {}` | Compare 按鈕:檢查各只勾一個 → dump 兩頁 → 出 `Will Compare` message box |
| `PageLabel {pPair}` | `{sch page}` → `"SCH / PAGE"` |
| `DumpPageInfo {pDsn pSch pPage}` | 走訪到指定頁,印 Parts + Nets + 統計;找不到丟 error |
| `DumpPageParts {pPage}` | 每個 placed instance 印 refdes / package / .olb / 位置 + 屬性行 + pin 行,回傳顆數 |
| `DumpPageNets {pPage}` | 每個 net 印名稱、wire 數,及每條 wire 的兩端點,回傳 net 數 |
| `PropStr {pObj pName}` | 單一屬性值(`GetEffectivePropStringValue`),沒設回 `""` |
| `PropStrAny {pObj pNames}` | 依序試多個屬性名,回第一個有值的 |
| `CStr {pObj pGetter}` | CString getter 樣板(`GetName` / `GetPinName` / `GetSourceLibName`) |
| `Coord {pPage pDoc}` / `PointStr` / `PartLocStr` | 座標換算與格式化 |
| `OrDash {pValue}` | 空值印 `-` |
| `NextIterName {pTag}` / `DropIter {pCmd}` | SWIG iterator 命令名配發與回收 |

**修改**

- `ShowPageSelector`:兩個 `catch` 改成 `[::mUtilMenu::SortPages [::mUtilMenu::GetDesignPages $pFileA]]`;開頭記下 `mPagesFileA/B`
- `GetDesignPages`:更正檔頭註解(原本寫「與 Project Manager 同序」是錯的),並註明 session 指標不需 init
- 按鈕列:`-side right` 是由右往左排,所以 `pack` 順序 = Close 先、Compare 後,才會是「Compare 在 Close 左邊」

**按鈕列最終寫法**

```tcl
button $lBtns.close   -text "Close"   -width 12 -command "::mUtilMenu::ClosePageSelector"
button $lBtns.compare -text "Compare" -width 12 -command "::mUtilMenu::DoPageCompare"
pack $lBtns.close   -side right -padx {6 0} -pady {4 10}
pack $lBtns.compare -side right          -pady {4 10}
```

### 2.4 三個關鍵設計決定

**(1) 排序在 `ShowPageSelector` 做,不在 `GetDesignPages` 做**
checkbox 的 index 是照 `mPagesA` / `mPagesB` 的順序建的,`GetCheckedPages` 也靠這個 index 反查。排序必須在**建 checkbox 之前**完成,兩邊才對得上。

**(2) dump 全部排序輸出**
parts 按 Part Reference、nets 按 net 名、net 內 wire 按端點字串,一律 `lsort -dictionary`。資料庫順序是插入序,不排的話同樣的兩頁會 diff 出一堆假差異。屬性行即使全空也照印,讓每個 part 固定行數,兩份 dump 才能行對行比。

**(3) SWIG constructor 型 iterator 要配唯一命令名**
`DboPageNetsIter` / `DboNetWiresIter` / `DboWireAliasesIter` 不是回傳 handle,而是**建立一個同名 Tcl command**(原廠 `capShortNet.tcl` 直接寫死 `lPageNetsIter` 且從不刪)。連按兩次 Compare 就會撞名,所以用 `NextIterName` 發流水號、`DropIter` 收掉(`-delete` 後再 `rename ... {}`,都包 catch)。

### 2.5 Command Window 輸出格式

```
================================================================
one.dsn - SCHEMATIC1 / PAGE1
================================================================
  Parts
    D1         DIODE        diode.olb        (5.00,3.40) bbox (4.90,3.30)-(5.40,3.50)
               Value: 1N4148             PCB Footprint: -                  Part_Number: PN-D-1N4148
               pins: A K
    R1         R            discrete.olb     (1.20,3.40) bbox (1.10,3.30)-(1.60,3.50)
               Value: 10K                PCB Footprint: R0402              Part_Number: PN-R-0402-10K
               pins: 1 2
  Nets
    (unnamed)                    wires: 1
        wire (7.00,1.00)-(7.00,2.50)
    VCC                          wires: 2
        wire (1.00,2.00)-(1.00,3.00)
        wire (1.00,3.00)-(4.50,3.00)
  (2 part(s), 2 net(s))
```

- part 第一行 = refdes / package / 來源 .olb / `GetLocation` 放置原點 + `GetBoundingBox`(原點不動但被 mirror/rotate 時只有 bbox 看得出來)
- `Part_Number` 找不到會 fallback 試 `Part Number`(Cadence 拼法);兩者皆無印 `-`
- 屬性值都是 **effective 值**:instance 有覆寫就用覆寫,沒有才吃 part 預設,與屬性編輯器一致
- net 名稱來自 wire alias(page 層的 net 本身沒有名字);多個 alias 以 ` = ` 串接;沒有 alias 印 `(unnamed)`

**要做程式化比對建議切 `doc` 模式**:整數不會有 `%.2f` 四捨五入造成的假差異。
但 granularity 是 per-page 的,兩頁圖框設定不同時要用 `user` 才有可比性。

```tcl
set ::mUtilMenu::mCoordMode doc
```

### 2.6 驗證方式 — 假造整個 DBO 層

Capture 外面沒有 `DboSession`,但**走訪邏輯**才是最容易寫錯的地方(巢狀 while、iterator 命名、found flag)。做法是在 `tclsh.exe` 裡把 DBO 假造出來,實跑整條路徑:

stub 檔(放 scratchpad,約 130 行)提供:

- 假物件模型:`NewObj`/`NewIter` 建 Tcl command,`Dispatch` 用 dict 分派 method
- CString 存放區:`DboTclHelper_sMakeCString` / `sGetConstCharPtr`
- 點與矩形:point = `{x y}`、rect = `{x1 y1 x2 y2}`,配 `sGetCPointX/Y`、`sGetCRectTopLeft/BottomRight`
- SWIG constructor 型 iterator:`DboPageNetsIter` / `DboNetWiresIter` / `DboWireAliasesIter`
- 一份假 design:`SCHEMATIC1 / PAGE1`,2 個 placed part + 1 個 hierarchical block(必須被跳過)+ 2 個 net(3 條 wire)

**刻意把 DB 順序打亂**(D1 在 R1 前、net2 在 net1 前、W2 在 W1 前),用來確認輸出排序是穩定的。

驗證通過的項目:

- 四種 `mPageSortMode` 的實際排序結果(`PAGE2` / `PAGE10`、`SCH_B` / `SCHEMATIC1` 的差異)
- `DumpPageInfo` 完整輸出;`user` 與 `doc` 兩種座標模式
- hierarchical block(`DRAWN_INSTANCE`)被跳過
- `Part_Number` → `Part Number` fallback、空屬性印 `-`
- page 找不到會丟 error 並被 `DoPageCompare` 的 catch 收掉
- **連按兩次 Compare 不會因 iterator 命令重名而爆掉**
- 勾選數不對(0 個 / 2 個)只跳 `Please select each one Page to compare`

> PowerShell 小坑:`tclsh ... | Select-Object -First N` 會提早關 pipe,導致 tclsh 以 255 結束 — 那是 pipeline 產物,不是腳本錯誤。要看 exit code 就不要截斷輸出。

### 2.7 已知限制 / 待確認

- **`mPageSortMode` 預設值待你確認**:在 Command Window 跑 `::mUtilMenu::DumpPages {…\xxx.dsn}`,四種順序都會印出來,對一下 Project Manager 樹。若 PM 把 `PAGE10` 排在 `PAGE2` 前面 → 改成 `ascii`;否則留 `dictionary`。原廠 14 個 `NewPagesIter` 呼叫點沒有一支是照 PM 順序列頁的,所以只能靠實際 dump 定案。
- **沒有 pin ↔ net 對應**:page 層的 `DboNet` 只有 wire 和 alias,沒有 pin 清單。真正的 netlist(net 接到哪些 refdes.pin)要走 flatten 後的 occurrence(`DboNetOccurrence GetNet`,範例 `capDRCFramework\tcl\capProcessDRC.tcl:255`),與 page 物件是不同路徑。目前 Nets 區塊給的是「這頁有哪些 net、叫什麼、幾條線、線在哪」。
- **尚未在 Capture 內實跑**:上述驗證全部是 stub。真實 design 上還沒確認的是屬性名稱是否吻合(`PCB Footprint` / `Part_Number`)、以及 `GetLocation` 在 placed instance 上是否每種 part 都給得出值(給不出時會 fallback 只印 bbox)。
- **Compare 仍未做真正比對**:只 dump 兩頁,尚未把兩份結果對比出差異 — 這是下一步。

### 2.8 熱重載

```tcl
::mUtilMenu::remove
source {G:/Cadence/SPB_17.4/tools/capture/tclscripts/capAutoLoad/mUtilMenu.tcl}
```

---

## 項目 3 — mUtilMenu.tcl proc 結構樹

**日期**:2026-08-25
**狀態**:文件,對應 `mUtilMenu.tcl` 2953 行版本(98 個 proc)
**變更檔案**:無(本節只描述現況)

行號會隨改版漂移,但層級關係不會 — 找位置以 **proc 名稱** 為準,行號只當參考。

### 3.1 載入 / 註冊

```
::mUtilMenu::init                              L2899   ← 檔尾 L2946 呼叫,唯一 autoload 入口
├── initXmlMenu                                L2828   Path A:InsertXMLMenu 建 mUtil 主選單
│   ├── RegisterAction  x6                     L2830-2841
│   ├── InsertXMLMenu "mUtil" popup            L2843   ← 主選單本身
│   ├── InsertXMLMenu "mUtilSchCompare"        L2852   ← 加選單項目複製這段
│   ├── InsertXMLMenu "mUtilClosePage"         L2858
│   └── RefreshMenu                            L2864
└── initAccessoryMenu                          L2889   Path B:AddAccessoryMenu(文件化做法)
    ├── _cdnCapTclAddPageCustomMenu   → addPageAccessoryMenu    L2879
    └── _cdnCapTclAddDesignCustomMenu → addDesignAccessoryMenu   L2884

::mUtilMenu::remove   L2904   關三個視窗 + DeleteXMLMenu x4 (L2909-2912)
::mUtilMenu::diag     L2920   Command Window 診斷(指令在不在 / Tk / menu node)
```

選單 → callback 的轉接層(都只是薄薄一層):

```
Path A ├── XmlSchematicCompare       L2825 → DoSchematicCompare "mUtil menu"
       └── XmlClosePage              L2826 → DoClosePage        "mUtil menu"

Path B ├── PageSchematicCompare      L2874 (pPage pOcc) → DoSchematicCompare
       ├── PageClosePage             L2875 (pPage pOcc) → DoClosePage
       ├── DesignSchematicCompare    L2876 (pLib)       → DoSchematicCompare
       └── DesignClosePage           L2877 (pLib)       → DoClosePage
```

### 3.2 功能主線:三個視窗接力

```
對話框1(選兩個 .DSN) → 對話框2(page 兩欄 + 中間連線) → 結果視窗
DoSchematicCompare       ShowPageSelector                    ShowResultWindow
```

```
DoSchematicCompare {pVia}                      L2723  ★ 對話框 1
├── package require Tk 失敗 → 訊息框             L2727
├── HideTkRoot                                 L2715
├── 已開著就 raise 不重建                        L2737
├── SetAppWindowAsParent                       L2753
├── [row0] Default Folder  → BrowseInitDir     L327
├── [row1] Design File 1(O)→ BrowseDesign      L343  (傳變數名 mCmpFileA)
├── [row2] Design File 2(N)→ BrowseDesign      L343
│         grid 排版                             L2777-2789
├── [btn] Execute / <Return> → DoSchematicCompareExecute
└── [btn] Cancel  / <Escape> → CloseSchematicCompare  L2706

DoSchematicCompareExecute                      L2669
├── 有空欄 → capDisplayMessageBox 就 return     L2680
├── CloseSchematicCompare                      L2706
├── Open <path>  x2(Capture 內建)               L2691
└── ShowPageSelector $lA $lB                   L2699 → L2478
```

```
ShowPageSelector {pFileA pFileB}               L2478  ★ 對話框 2
├── GetDesignPages x2                          L393   ← 走 DBO 拿 {sch page}
├── SortPages      x2                          L1435  ← mPageSortMode
├── Page_name_mapping                          L2541 → L1521
│      回 dict {marksA marksB links};links 存進 mPageLinks
├── [表頭] "(O) file" / "(N) file"(不隨捲動)     L2550-2561
├── [canvas] 一個 canvas 裝兩欄,中間留 gap 畫線   L2567-2599
│   ├── BuildPageColumn colA + lMarksA         L2590 → L1602
│   ├── BuildPageColumn colB + lMarksB         L2591
│   └── bind <Configure> → DrawPageLinks       L2609-2610
├── bind <MouseWheel> 捲 canvas                 L2614
├── [legend] 綠實線 / 紅虛線 / 紅無線             L2617-2628
├── [btn] AllPagesComp(靠左)→ DoTotalPageCompare  L2646
├── [btn] PageComp   (靠右)→ DoPageCompare       L2635
├── [btn] Refcompare  ★建了但沒 pack             L2644(L2655 是註解掉的 pack)
├── [btn] Close / <Escape> → ClosePageSelector  L1733
└── after idle → RedrawPageLinks               L2665  ← 線一次畫齊的關鍵
```

### 3.3 比較的三個進入點

```
DoPageCompare       L2246 ┬ RunPageCompare {parts symbols nets buses} "PageComp" full
                          └ DrawCompareMarkerLine          L2175  ← 比完才畫,順序不能反
DoPageRefCompare    L2255 → RunPageCompare {parts} "Refcompare" ref
DoTotalPageCompare  L2300  ★ AllPagesComp(按鈕名稱改了,proc 名沒改)
├── mPageLinks 為空 → 訊息框 return             L2308
├── mQuiet 1(整段靜音,收尾/出錯都要還原)         L2316 / L2353 / L2359
├── foreach mPageLinks → ComparePagePair        L2333 → L2266
│   └── 有畫到 marker → MarkPageNameChanged      L2344 → L2199(頁名前加 '*')
├── ZoomRedraw                                  L2361
├── 一個 capDisplayMessageBox 報 count           L2383
└── ClosePageSelector                           L2384
```

```
RunPageCompare {pWhat pLabel {pMode none}}     L2389  ★ 單頁比較總管
├── 清 mMarkSegs / mMarkBoxes                   L2398
├── GetCheckedPages A / B                       L1747  (各欄必須剛好 1 頁)
├── DumpPageInfo x2(O 先 N 後)                  L2426 → L1399
├── lWinTitle 決定 banner                        L2436-2440
├── pMode "ref"  → DumpRefCompare               L783   (分支 L2455)
├── pMode "full" → DumpFullCompare              L1023
└── ShowResultWindow                            L2467  ← 失敗才退回 capDisplayMessageBox

ComparePagePair {pFileA pPairA pFileB pPairB}  L2266  AllPagesComp 用的無視窗版
├── 清 mark 狀態 → DumpPageInfo x2 → DumpFullCompare
└── DrawMarkersOnPage $pFileB $pPairB           L2106   回傳畫了幾個 = 有沒有變
```

### 3.4 結果視窗

```
ShowResultWindow {pTitle pText}                L1809
├── Tk 不在 → 退回 capDisplayMessageBox          L1814
├── 每次重建                                     L1822
├── text -wrap none -width 110 -height 30 -font TkFixedFont  L1835
│   + 垂直/水平 scrollbar                        L1838-1839
├── -state disabled(唯讀,仍可選取複製)           L1849
├── [btn] Select All / Copy / Close             L1854-1863
└── bind Control-a / Control-c / Escape         L1866-1868

CloseResultWindow     L1777
SelectAllResultText   L1782
CopyResultText        L1795   有選取複製選取,沒選取複製全部
```

### 3.5 Page 名稱對映(兩欄連線)

```
Page_name_mapping {pPagesA pPagesB}            L1521  ★ 回 dict{marksA marksB links}
├── PageKey        L1493 → StripPageNamePrefix  L1485(去頭字元 mPageNamePrefixChars L190)
├── PageKeyHead    L1498 → 前 mPageSimilarChars 字(L147,預設 10)
├── Pass 1 exact   L1541-1561  去標記後完全相同(含大小寫)→ 綠實線
├── Pass 2 similar L1564-1587  前 N 字相同 → 紅虛線
└── 兩 pass 都 greedy first-come,一頁只能被配走一次

BuildPageColumn {pFrame pPages pArrName {pMarks {}}}   L1602
├── 0 頁 → "(no pages found)"                   L1605
├── 多個 schematic 才印 schematic 標題            L1625
├── checkbutton -variable ::mUtilMenu::<arr>(i)  L1632
└── mark 非 exact → -foreground red              L1638-1640

DrawPageLinks     L1663   讀 winfo y 畫線,tag pagelink,可重複呼叫;mPageLinksReady 是閘門
RedrawPageLinks   L1721   update idletasks → 開閘 → DrawPageLinks(<Configure> 不能用這支)
ClosePageSelector L1733   destroy + 清掉 mPageCanvas / mPageLinksReady
GetCheckedPages   L1747   回勾選的 {sch page}
```

| A 欄 (O) | B 欄 (N) | 結果 |
|---|---|---|
| `PAGE2` | `PAGE2` / `~PAGE2` | exact → 黑字 + 綠實線 |
| `*PAGE3` | `PAGE3` | exact(去標記後相同) |
| `PAGE_A_01` | `PAGE_A_02` | 前 10 字同 → 紅字 + 紅虛線 |
| (無) | `PAGE9` | none → 紅字,無線 |
| `PAGE1` | `page1` | 大小寫不同 → 前 10 字同就是 similar |
| 有頁 | 0 頁 | 整段跳過,兩欄都不上色 |

### 3.6 資料收集層(Collect = 拿,Print = 印)

```
DumpPageInfo {pDsn pSch pPage ?pWhat?}         L1399  回 dict: parts/symbols/nets/buses
├── FindPage                                   L1391 → FindPageObjs L1342(回 {sch page},rename 要 sch)
├── parts   : CollectPageParts   L668  + PrintPartRows   L718
├── symbols : CollectPageSymbols L1141 + PrintSymbolRows L1195  (OFFPAGE/GLOBAL/PORT)
├── nets    : CollectPageNets    L1275 + PrintNetRows    L1319
└── buses   : CollectPageBuses   L1217 + PrintBusRows    L1258  (WIRE_BUS/WIRE_BUNDLE)

Parts row 欄位(CollectPageParts L704):
  0 Reference 1 Value 2 package 3 lib 4 位置字串 5 pins 6 PCB Footprint
  7 Part_Number 8 Optional 9 bbox doc 單位 ← 只給畫框用
Nets  row: 0 name  1 {endpoints 字串...}  2 {docSegs...}
Buses row: 0 name  1 BUS/BUNDLE  2 endpoints 字串  3 docSeg

Command Window 單獨用
├── DumpPageParts   L735   ├── DumpPageBuses  L1266
├── DumpPageSymbols L1204  ├── DumpPageNets   L1330
└── DumpPages       L1459  四種排序模式對照 PROJECT_MANAGER_VIEW
```

### 3.7 比較邏輯層

```
DumpRefCompare {pRowsO pRowsN}                 L783   ★ Refcompare:Parts 依 Reference 配對
├── IndexPartRows  x2                          L767   重覆 ref 會 Trace
├── PartCmpFields                              L749   ← ★ 多比一個屬性只改這支
├── PartCmpStr                                 L757
├── 輸出 Add / Remove / Changed                 L827-852
└── RefListStr                                 L1127

DumpFullCompare {pDictO pDictN}                L1023  ★ PageComp:四大類 signature diff
├── lCats 表                                    L1030  {name key sigsProc oneSigProc geomIdx max markKind}
│      Parts  … 9  box     Symbols … -1 (不標)
│      Nets   … 2  line    Buses   …  3  line
├── PartSigs  L901 → PartSig L887 ┐
├── SymbolSigs L909                ├─ 每筆回 {signature shortName}
├── NetSigs   L933 → NetSig  L925 │
├── BusSigs   L948 → BusSig  L941 ┘
├── SigDiff                                    L986   multiset 差集 → {onlyInN onlyInO}
├── MarkGeomIndex                              L965   signature → doc 座標(填 mMarkSegs/mMarkBoxes)
└── RefListStr                                 L1127  pMax<=0 = 不設上限(Nets/Buses 用)
```

### 3.8 畫在頁面上(全檔唯一會「寫入」設計的部分)

```
DrawMarkersOnPage {pFile pPair}                L2106  ★ 把 mMarkSegs/mMarkBoxes 畫上 (N) 頁
├── 沒東西可畫 → return 0                       L2111
├── FindPage 一次(整批共用,避免 O(n²))          L2119
├── MarkOffsetDoc                              L2052  mLineOffset user→doc 單位換算
├── foreach mMarkSegs  → OffsetSeg L2077 → DrawPageLineOn L1938
├── foreach mMarkBoxes → DrawPageBoxOn         L1997  (框不 offset)
└── MarkModified + ZoomRedraw(畫到才做)         L2164-2165

DrawCompareMarkerLine   L2175   PageComp 的入口:B 欄剛好勾 1 頁才畫
MarkPageNameChanged     L2199   頁名前加 '*';DboSchematic::Rename,失敗退 DboDesign::RenameObject
DrawPageLineOn {pPage pFrom pTo ?color? ?width? ?style?}  L1938  NewGraphicLineInst
DrawPageBoxOn  {pPage pBBox ?color? ?width? ?style?}      L1997  NewGraphicBoxInst + HOLLOW_FILL
DrawPageLine   {pDsn pSch pPage pFrom pTo ...}            L2039  Command Window 一次性用
DboEnum {pName} L1908   $::DboValue_* 查不到就報看得懂的錯
DboSet  {pObj pMethod args} L1919   跑 setter 並 delete 回傳的 DboState(不然會漏)
```

### 3.9 共用工具(leaf)

```
輸出
├── Out   {args}   L304   ★ 全檔唯一 puts;mQuiet 1 就整個靜音
└── Trace {pMsg}   L314   Out + mDebug 時彈訊息框

文字 / 屬性
├── CStr       {pObj pGetter}   L648   CString getter → Tcl string
├── PropStr    {pObj pName}     L490
├── PropStrAny {pObj pNames}    L638   多個名字試到有值(Part_Number / "Part Number")
├── OrDash                      L517   空值印 "-"
└── RefListStr {pRefs pMax}     L1127

座標 / 幾何
├── Coord      {pPage pDoc}     L501   doc → mCoordMode (user/doc)
├── PointStr                    L524   "(x,y)"
├── ObjLocStr                   L536   GetLocation + bbox(字串,四捨五入)
├── ObjBBoxDoc {pObj}           L554   bbox 原始整數 {l t r b}  ← 畫框用
├── WireSegStr                  L567   "(x1,y1)-(x2,y2)"
├── WireSegDoc {pWire pStatus}  L579   原始整數 {x1 y1 x2 y2}   ← 畫線用
├── OffsetSeg                   L2077  水平線往上、垂直線往右、斜線不動
└── MarkOffsetDoc               L2052

網路名稱
├── WireAliases {pWire pStatus} L593
└── NetLabel    {pNet pNames}   L618   aliases → GetName → "Net Name"/"Name" → "(unnamed)"

Page 名稱
├── StripPageNamePrefix L1485 ├── PageKeyHead L1498
├── PageKey             L1493 └── PageLabel   L2474  "SCHEMATIC1 / PAGE1"

Iterator(SWIG constructor 會佔用命令名)
├── NextIterName {pTag} L479   └── DropIter {pCmd} L484

視窗
├── HideTkRoot            L2715   藏掉 package require Tk 產生的空白 "."
├── CloseSchematicCompare L2706
├── ClosePageSelector     L1733
└── CloseResultWindow     L1777

RegisterAction 用的固定 true
└── True L296 / Action L297 / Enabler L298
```

### 3.10 namespace 變數(L98-294)

| 變數 | 行 | 用途 |
|---|---|---|
| `mMenuId` `mMenuLabel` | 99-100 | 主選單 id / 顯示字 |
| `mCmpWin` `mCmpFileA` `mCmpFileB` | 109-111 | 對話框 1 狀態 |
| `mCmpInitDir` | 116 | Browse 預設資料夾 |
| `mPagesWin` `mPagesA` `mPagesB` | 121-123 | page selector 清單 |
| `mPagesFileA` `mPagesFileB` | 126-127 | selector 對應的兩個 .dsn |
| `mPageSelA` `mPageSelB` (array) | 128-131 | checkbox 變數,index = 清單位置 |
| `mPageLinks` | 136 | `{idxA idxB exact\|similar}`;AllPagesComp 就走這個 |
| `mPageColWidth` `mPageLinkGap` | 140-141 | canvas 三段寬度(300 / 120) |
| `mPageSimilarChars` | 147 | similar 要前幾字相同(10) |
| `mLinkColorExact` `mLinkColorSimilar` | 151-152 | 連線顏色(Tk 色名,非 DboValue) |
| `mPageCanvas` `mPageCbsA` `mPageCbsB` `mPageLinkX1/X2` | 157-161 | DrawPageLinks 的即時狀態 |
| `mPageLinksReady` | 168 | 0 = 還在建,不畫線 |
| `mResultWin` | 173 | `.mUtilCmpResult` |
| `mPageSortMode` | 184 | dictionary / ascii / dbreverse / dborder |
| `mPageNamePrefixChars` | 190 | 去頭字元集 `*-?~+%$#@!` + 空白/tab |
| `mIterSeq` | 193 | NextIterName 序號 |
| `mCoordMode` | 198 | user(英吋)/ doc(內部整數) |
| `mMarkSegs` `mMarkBoxes` | 210-211 | 待畫的線 / 框,doc 單位 |
| `mLineOffset` `mLineOffsetUnits` | 222-223 | marker 讓開多少(0 = 蓋在線上) |
| `mRefListMax` | 227 | Parts/Symbols 報告上限 200;Nets/Buses 不設限 |
| `mMarkLineColor/Width/Style` | 274-276 | COLOR7 粉紅 / WIDE / DASH_DOT |
| `mMarkBoxColor/Width/Style` | 277-281 | COLOR9 青綠 / WIDE / 實線 |
| `mDebug` | 286 | 1 = 每個 callback 彈訊息框 |
| `mQuiet` | 293 | 1 = Out 全部吞掉(AllPagesComp 用) |

### 3.11 「我要加功能」快速對照

| 想做的事 | 動這些地方 |
|---|---|
| mUtil 選單多一項 | `initXmlMenu` L2852 複製一段 + RegisterAction L2833 + 新 `Xml***` L2825 + `remove` L2909 補 DeleteXMLMenu |
| Accessories 也要有 | `addPageAccessoryMenu` L2879 / `addDesignAccessoryMenu` L2884 各加一行 |
| selector 多一顆按鈕 | `ShowPageSelector` L2630-2655 + 新 `DoPage***`(L2246 附近) |
| 把 Refcompare 放回畫面 | 取消註解 L2655 那行 `pack $lBtns.refcmp` |
| 新的比較模式 | 新 `DoPage***` → `RunPageCompare $pWhat $pLabel <mode>`,L2436/L2445 加分支 |
| 改結果視窗 banner | `RunPageCompare` L2436-2440 |
| 結果視窗大小 / 字體 | `ShowResultWindow` L1835 |
| 結果視窗多一顆按鈕 | `ShowResultWindow` L1854-1863,照 Copy 鈕加 |
| 讓結果視窗可編輯 | 拿掉 L1849 的 `-state disabled` |
| Refcompare 多比一個屬性 | 只改 `PartCmpFields` L749 |
| PageComp 多比一類物件 | `CollectPageXxx` + `PrintXxxRows` + `DumpPageInfo` L1399 加區塊 + `XxxSig`/`XxxSigs` + `DumpFullCompare` L1030 的 lCats 加一列 |
| Parts 多抓一個欄位 | `CollectPageParts` L704 的 lappend(接在第 10 位,別動 index 9 的 bbox)+ `PrintPartRows` L718 + `PartSig` L887 |
| 改「similar」判定寬鬆度 | `mPageSimilarChars` L147 |
| 改連線顏色 / 虛線樣式 | `mLinkColorExact/Similar` L151-152、`DrawPageLinks` L1701-1705 |
| 改欄寬 / 中間 gap | `mPageColWidth` `mPageLinkGap` L140-141 |
| 改頁面 marker 顏色 / 線型 | `mMarkLineColor/Width/Style` L274-276、`mMarkBox*` L277-281 |
| marker 蓋住線 / 想讓開 | `mLineOffset` L222(0 = 正上方)、`OffsetSeg` L2077 |
| 改 AllPagesComp 的 '*' 標記 | `MarkPageNameChanged` L2212 的 `set lNew "*$lPageName"`(記得 `mPageNamePrefixChars` L190 要含該字元) |
| 讓 AllPagesComp 不靜音 | `DoTotalPageCompare` L2316 的 `set mQuiet 1` |
| 改座標單位 / 排序 | `mCoordMode` L198 / `mPageSortMode` L184 |
| 對話框 1 多一個輸入欄 | `DoSchematicCompare` L2760-2789(grid row 往下加)+ namespace 變數 L109 |

> 同一份結構樹也有獨立檔 `tclscripts\mUtilMenu-tree.md`,但那份還停在 1859 行的舊版(行號全錯,且缺 AllPagesComp、頁面 marker、similar 連線三塊)。以本節為準。

> **行號已位移**:項目 4 之後檔案變成 3109 行 / 105 個 proc。本節的行號是 2953 行版本的,位移量見 4.6。

---

## 項目 4 — AllPagesComp 跑完後 File > Save / Save As 被反白

**日期**:2026-08-26
**狀態**:已在 Capture 內實跑驗證通過
**變更檔案**:`capAutoLoad\mUtilMenu.tcl`(2953 → 3109 行,98 → 105 個 proc)

### 4.1 症狀

AllPagesComp 跑完的當下,被修改的 `$pFileB`(N)在 `PROJECT_MANAGER_VIEW` 裡 **`File > Save` 和 `Save As` 兩個都反白**。切到 `$pFileA` 的 PM 再切回 `$pFileB`,兩個就都恢復可用。

### 4.2 判斷過程 — 決定性線索是「Save As 也被反白」

第一直覺會往 `MarkModified` 沒生效去想,但那個方向是錯的:

**`Save As` 不看髒旗標。** 一個開著的設計永遠可以另存到別的路徑,不管它有沒有被改過。所以 `Save` 和 `Save As` **一起**灰掉,不可能是 modified 狀態的問題 —— 只可能是 Capture 當下**不知道要存誰**。

Capture 的存檔 enabler 問的是「Project Manager 現在選了什麼」。佐證是 Cadence 自己的存檔路徑:

```tcl
capAdvancedSaveFramework\tcl\capAdvancedSave.tcl:380
    catch {SelectPMItem "Design Resources"; Menu "File::Save"}
```

它在呼叫 `Menu "File::Save"` 之前**一定先** `SelectPMItem` —— 同一個依賴關係。

**那是什麼弄掉了選取項?** AllPagesComp 比 PageComp 多做的唯一一件事就是改頁名。`MarkPageNameChanged` 走 `DboSchematic::Rename`,PM 會因此重建整棵樹,選取項跟著沒了。手動切到另一個設計再切回來,就是重新給它一個選取項 —— 使用者發現的 workaround 本身就是答案。

### 4.3 用到的 API(全部出自 Appendix A)

| 指令 | PDF 位置 | 用途 |
|---|---|---|
| `SelectPMItem(pValue)` | p.130 | 在 PM 樹選一個項目 — 本次的修法核心 |
| `Open(pPath)` | p.130 | 已在 session 內的設計只會 activate 視窗,不會重讀 |
| `GetSelectedPMItems()` | p.130 | 回傳目前 PM 選取項 — 診斷用 |
| `IsDocModified()` | p.130 | **UI 層**文件髒旗標,與 Dbo 層的 `IsModified` 是兩回事 |
| `GetActivePMDesign()` | p.132 | 目前作用中的 DboDesign |
| `GetActiveOpjName()` | p.129 | 目前 .opj 路徑 |
| `MarkModified()` | p.171 | 在 `DboBaseObject` 上,所以 page / schematic / design 每一層都有 |

### 4.4 實作內容

**namespace 新增變數**

```tcl
variable mRestorePM 1                        ;# 0 = 關掉自動還原 PM 選取
variable mPMSelectItem "Design Resources"    ;# SelectPMItem 要選的節點名
```

**新增 proc**

| proc | 作用 |
|---|---|
| `RestorePMSelection {pFile}` | `Open` 把該設計的 PM 叫到前面 → `SelectPMItem` 給它選取項。備援候選:design root name、檔名 |
| `FindDesign {pDsnPath}` | 由 .dsn 路徑取 `DboDesign`(`GetDesignPages` 的走訪去掉 iterator) |
| `diagSaveState {}` | Save 反白時在 Command Window 跑,一次印出三層狀態,直接指出是哪一層 |

**修改**

- `MarkPageNameChanged`:原本只 `MarkModified` page 和 schematic,再補一次 **design 層**
- `DoTotalPageCompare` 結尾:訊息框 OK、`ClosePageSelector` 之後,若有頁被改名就呼叫 `RestorePMSelection $mPagesFileB`。放在最後是因為要等自己的 Tk 視窗全部消失,activate 才會落在對的地方
- 檔頭 AllPagesComp 段落補上這段行為說明

### 4.5 驗證結果

離線(`tclsh.exe`)先過語法與載入:

```
info complete: OK        source: OK        procs defined: 105
RestorePMSelection ok    FindDesign ok     diagSaveState ok
switched off -> 0        empty file -> 0   stubbed on -> 1
```

Capture 內實跑,AllPagesComp 完成後不再反白,`::mUtilMenu::diagSaveState` 輸出:

```
GetActiveOpjName     G:\PROJECT\MB\REX6_HSU\W980 WS\W980_WS_R100_20260817.opj
IsDocModified        1
selected PM items    {Design Resources}
active PM design     W980_WS
(O) W980_WS_R100_20260810.DSN IsModified = 0
(N) W980_WS_R100_20260817.DSN IsModified = 1
```

這份輸出把 4.2 的推論整條驗證完了:

- `selected PM items` 有東西 → 選取項回來了,這就是被修掉的東西
- **`IsDocModified = 1`** → 文件髒旗標一直都是對的。當初 Save 反白確實與 modified 無關
- `(O) = 0` / `(N) = 1` → marker 和改名只寫到 (N),沒有誤傷 (O)

### 4.6 對項目 3 行號的影響

項目 3 的結構樹是 2953 行版本。本次之後的位移(以 proc 名為準最保險):

| 區段 | 位移 |
|---|---|
| 檔頭註解之後(namespace 之前) | +6 |
| namespace 之後 ~ `MarkPageNameChanged` | +18 |
| `FindDesign` / `RestorePMSelection` 插入之後 | +105 |
| `DoTotalPageCompare` 呼叫點之後(含 `diag`) | +112 |

新舊對照的幾個錨點:`MarkPageNameChanged` 2199 → **2217**、`DoTotalPageCompare` 2300 → **2405**、`diag` 2920 → **3032**;新增的在 `FindDesign` **2269**、`RestorePMSelection` **2306**、`diagSaveState` **3071**。

### 4.7 已知限制

- **備援候選是死碼**。`"Design Resources"` 第一個就成功,而 `SelectPMItem` 遇到不存在的名字很可能只是靜默不動、不丟錯 —— 那樣迴圈永遠停在第一個,後面兩個候選(design root name、檔名)根本輪不到。真要換節點名,直接改 `mPMSelectItem` 比較實在。
- **只掛在 AllPagesComp**。PageComp 不改頁名,不會弄掉 PM 選取,所以沒接;真遇到再說。
- **`Open` 重複呼叫的副作用未窮舉**。對已開啟的設計它只 activate 視窗(p.130),實跑也沒異狀,但沒測過設計在外部被改動過的情況。

### 4.8 熱重載

```tcl
::mUtilMenu::remove
source {G:/Cadence/SPB_17.4/tools/capture/tclscripts/capAutoLoad/mUtilMenu.tcl}
```

---

## 項目 5 — mUtilMenu.tcl 用到的 DBO 核心程序總整理

**日期**:2026-08-31
**狀態**:文件,對應 `mUtilMenu.tcl` 5228 行版本(143 個 proc)
**變更檔案**:無(本節只描述現況)

這節把整個開發過程用到的 **DBO(Design Base Object)API** 收在一起。項目 2 的 2.2 只列了「出處」,這裡列的是「怎麼用、包在哪支 proc 裡、踩過什麼坑」。

> 一句話原則:**Appendix A 沒有的就去 `tools\bin\orDb_Dll_Tcl64.dll` 查 SWIG wrapper**,再不然找原廠 script 的實際使用點。三種來源在下面每一項都標出來了。

### 5.1 三個基礎物件 — 所有 DBO 呼叫的前置

| 呼叫 | 用途 | 備註 |
|---|---|---|
| `$::DboSession_s_pDboSession` | Capture 已建好的 session 指標 | **不需要任何 init**,原廠 14 個檔案共同寫法 |
| `DboSession -this $lSession` | 把指標包成 Tcl 物件 | PDF 3.2.2(p.29) |
| `DboState` | 每次走訪都要一個狀態物件 | 用完 `catch { $lStatus -delete }`,**不刪會 leak** |
| `DboTclHelper_sMakeCString ?str?` | 建 CString(傳入/接回都要) | PDF p.28 |
| `DboTclHelper_sGetConstCharPtr` | CString → Tcl string | 同上 |

固定開頭三行,`GetDesignPages` L893、`FindPageObjs` L3251、`FindDesign` L4245、`MarkPageNameChanged` L4212 都是這段:

```tcl
set lSession $::DboSession_s_pDboSession
DboSession -this $lSession
set lStatus [DboState]
set lPath   [DboTclHelper_sMakeCString [file normalize $pDsnPath]]
set lDesign [$lSession GetDesignAndSchematics $lPath $lStatus]
```

`GetDesignAndSchematics` 回 `NULL` 就是設計沒在 session 裡 — 這也是為什麼 `DoSchematicCompareExecute` 一定要先 `Open`。

### 5.2 階層走訪:design → schematic → page

| 呼叫 | 物件 | PDF / 出處 |
|---|---|---|
| `GetDesignAndSchematics {cstr} {status}` | DboSession | 3.2.4 p.29 |
| `NewViewsIter {status} $::IterDefs_SCHEMATICS` | DboDesign | 3.2.7 p.30 |
| `NextView {status}` | DboLibViewsIter | 同上 |
| `DboViewToDboSchematic` | 型別轉換(dynamic cast) | 3.2.7 |
| `NewPagesIter {status}` | DboSchematic | 3.2.9 p.31 |
| `NextPage {status}` | DboSchematicPagesIter | 同上 |
| `GetName {cstr}` | DboSchematic / DboPage | 回 CString,要配 `CStr` helper |
| `GetRootName {cstr}` | DboDesign | `RestorePMSelection` / `diagSaveState` 用 |
| `IsModified {status}` | DboDesign | `diagSaveState` L5214 |

這段走訪在檔案裡出現 **兩次**,刻意不合併:

- `GetDesignPages` L889 — 蒐集全部 `{schematic page}`,給 page selector
- `FindPageObjs` L3246 — 只找一頁,**同時回傳 schematic 物件**(改頁名要靠它)

> `FindPage` L3295 是 `FindPageObjs` 取 index 1 的薄包裝。**page 物件屬於 design 而不是 iterator**,所以 iterator 刪掉之後 page 還能用 — `DrawMarkersOnPage` 整批共用一次 lookup 就是靠這點(否則 O(n²))。

### 5.3 Page 層物件走訪 — 四大類

**(1) Parts** — `CollectPageParts` L1460

```
$lPage NewPartInstsIter {status}          → NextPartInst
  $lInst GetObjectType == $::DboBaseObject_PLACED_INSTANCE   ← 過濾階層方塊
  DboPartInstToDboPlacedInst $lInst
    GetSourceLibName {cstr}      來源 .olb
    GetPackage {status} → GetName  package 名
    GetEffectivePropStringValue    Part Reference / Value / PCB Footprint /
                                   Part_Number / Optional
    GetLocation {status}  GetBoundingBox
    NewPinsIter {status} → NextPin  (見下)
```

**(2) Pins** — `CollectPinInfo` L1302,**page 層就能拿到 pin↔net**

| 呼叫 | 回什麼 | 來源 |
|---|---|---|
| `GetPinName {cstr}` | "VCC" / "A0" | capPortPinMismatch.tcl:109 |
| `GetPinNumber {cstr}` | 實體腳位號 | **DLL**,Appendix A 沒有 |
| `GetIsNoConnect {status}` | 有沒有 X 記號 | **DLL** |
| `GetNet {status}` | 該 pin 的 page DboNet,沒接回 NULL | **DLL** |
| `GetOffsetHotSpot {status}` | pin 的**連接點**(線落在哪) | capPdfUtil.tcl:1203-1209 |
| `DboPartInst_sGetPinCount` / `$part GetPinCount` | pin 數,不用走 iterator | **DLL**,兩種拼法都試 |

> `NextPin` 回的是 **DboPortInst**,連線資訊在物件本身 —— 所以 **不需要**走 flatten 後的 occurrence(`DboNetOccurrence GetNet`)。這是項目 2 的 2.7「沒有 pin ↔ net 對應」被推翻的地方。
>
> pin 有兩個端點:`GetOffsetStartPoint` = 接部件本體那端,`GetOffsetHotSpot` = **自由端**,net wire 落在這裡。`Offset*` 這組已經把 instance 的擺放/旋轉/鏡射算進去,可以直接跟 wire 端點比 —— net_compare_rule4 靠的就是這個數字。

**(3) Symbols(Off-Page / Power/GND / Port)** — `CollectPageSymbols` L3028

```
NewOffPageConnectorsIter {status} ?$::IterDefs_ALL?  → NextOffPageConnector
NewGlobalsIter           {status}                    → NextGlobal    ← power 和 GND 同一桶
NewPortsIter             {status}                    → NextPort
   三者共用 GetName / GetLocation / GetBoundingBox
```

三種其實底層都是 **DboNetSymbolInstance**(DLL 查證),所以連線也共用一條路 —— `SymbolConn` L1389:

```
1  $obj GetNet  {status}   →  NetLabelOf
2  $obj GetWire {status}   →  該 wire 的 GetNet / aliases
3  ""                       什麼都沒接
```

`NewOffPageConnectorsIter` 的參數數量原廠不一致(capProcessDRC.tcl:81 給 `IterDefs_ALL`、orPrmDboStreamer.tcl:1900 不給),所以**先試兩個參數再試一個**。

**(4) Nets / Buses**

```
Nets  (CollectPageNets L3179)
  DboPageNetsIter <cmdName> $pPage $::IterDefs_ALL     ← SWIG constructor,見 5.6
    → NextNet {status}
      $lNet NewWiresIter {status} → NextWire           ← 方法型
        GetStartPoint / GetEndPoint
        NewAliasesIter → NextAlias → GetName           ← net 名字的唯一來源

Buses (CollectPageBuses L3121)
  $lPage NewWiresIter {status} → NextWire
    $lWire GetObjectType 比對 $::DboBaseObject_WIRE_BUS / _WIRE_BUNDLE
```

> **page 層的 DboNet 沒有自己的名字**,名字在 wire alias 上。`NetLabel` L1127 的順序:aliases → `GetName` → `Net Name`/`Name` 屬性 → `(unnamed)`。
> bus 不是獨立物件,是 `GetObjectType` 為 `WIRE_BUS` 的 wire(同 capObjectAlignment.tcl:371-373)。常數用 `info exists` 檢查,缺了就當作「不是 bus」而不是整個迴圈掛掉。

### 5.4 屬性 / 字串 / 座標 helper

| mUtilMenu proc | 行 | 包住的 DBO 呼叫 |
|---|---|---|
| `CStr {obj getter}` | L1157 | `sMakeCString` + `$obj $getter` + `sGetConstCharPtr` |
| `PropStr {obj name}` | L999 | `GetEffectivePropStringValue`(**effective 值**:instance 覆寫優先) |
| `PropStrAny {obj names}` | L1147 | 依序試多個屬性名(`Part_Number` / `Part Number`) |
| `Coord {page doc}` | L1010 | `GetPhysicalGranularity`,doc → 英吋 |
| `PointStr` | L1033 | `sGetCPointX` / `sGetCPointY` |
| `ObjLocStr` | L1045 | `GetLocation` + `GetBoundingBox` + `sGetCRectTopLeft/BottomRight` |
| `ObjBBoxDoc` | L1063 | 同上,但回**原始整數** `{l t r b}` — 畫框用 |
| `WireSegStr` / `WireSegDoc` | L1076 / L1088 | `GetStartPoint` / `GetEndPoint` |
| `WireAliases` | L1102 | `NewAliasesIter` / `NextAlias` / `GetName` |
| `PinHotSpotDoc` | L1207 | `GetOffsetHotSpot` |
| `PartPinCount` | L1244 | `DboPartInst_sGetPinCount` → `GetPinCount` |

**座標兩套單位,不能混**:`Str` 結尾的印出來給人看(已 `%.2f` 四捨五入),`Doc` 結尾的是原始整數 —— **畫線/畫框一律用 Doc**,絕不從印出來的字串回頭 parse。page 座標 **y 軸向下**(所以 CRect 的 top 是較小的 y)。

### 5.5 寫入設計 — 全檔唯一會改資料庫的部分

| 呼叫 | 物件 | 來源 |
|---|---|---|
| `NewGraphicLineInst {status} {start} {end} {origin} {rotation}` | DboPage | DLL |
| `NewGraphicBoxInst {status} {rect} {origin} {rotation}` | DboPage | DLL |
| `SetColor` / `SetLineWidth` / `SetLineStyle` / `SetFillStyle` | DboGraphic*Inst | DLL |
| `DboTclHelper_sMakeCPoint x y` / `sMakeCRect l t r b` | 建座標參數 | — |
| `Rename {pageObj} {cstr}` | **DboSchematic** | DLL |
| `RenameObject {pageObj} {cstr}` | DboDesign(備援) | DLL |
| `MarkModified` | DboPage / DboSchematic / DboDesign | Appendix A p.171(只有無參數版) |

三個關鍵細節:

**(1) `DboPage` 沒有 `SetName`。** DLL 裡只有 `DboPage_GetName` 和 `DboPage_MarkModified`。改頁名要走 **schematic** 的 `Rename(pObj, newName)`,所以 `FindPageObjs` 才要一併回傳 schematic 物件。

**(2) 每個 setter 都回一個新的 `DboState`,不刪就漏。** 這是 `DboSet` L3854 存在的理由:

```tcl
proc ::mUtilMenu::DboSet { pObj pMethod args } {
    if { [catch { set lState [eval [list $pObj $pMethod] $args] } lErr] } { ... return 0 }
    catch { set lOK [$lState OK] }
    catch { $lState -delete }        ;# ← 少這行就是每次呼叫漏一個 SWIG 物件
    return $lOK
}
```

**(3) `MarkModified` 不是同一個呼叫。** 每個 class 自己宣告、arity 不同:

```
DboPage::MarkModified()                    無參數
DboSchematic::MarkModified(DboPage*)       裡面那一頁
DboDesign::MarkModified(DboOccurrence*)    一個 occurrence,沒有就 NULL
DboLib::MarkModified(DboCell* / ...)       自己還有好幾個 overload
```

Appendix A p.171 只寫了被這些衍生版**遮蔽**的無參數 `DboBaseObject::MarkModified()`,所以當初 `$lDesign MarkModified` 每改一頁就印一次 `Wrong number of arguments`,**根本沒寫進資料庫**。`MarkObjModified` L3898 的做法是:先試給定的參數,再試無參數,兩種都不收才抱怨。`$lDesign MarkModified NULL` 是原廠認可的寫法(capReplacePathInCache.tcl:736)。

改完一定要 `MarkModified` + `ZoomRedraw`(capDesignUtil.tcl:301-304, :396 的模式)。**存檔留給使用者按 File > Save**,程式不自己存。

### 5.6 Iterator 的三種形式與生命週期 ★最容易寫錯的地方

| 形式 | 寫法 | 收尾 |
|---|---|---|
| **方法型** | `set lIter [$obj NewXxxIter $status]` | `catch { delete_Dbo<Class>XxxIter $lIter }` |
| **SWIG constructor 型** | `DboPageNetsIter <cmdName> $page $iterDefs` | `NextIterName` 發名 + `DropIter` 收 |
| **method 型 alias** | `$wire NewAliasesIter $status` | `delete_DboWireAliasesIter` |

本檔用到的 10 個 `delete_*`:

```
delete_DboLibViewsIter                delete_DboSchematicPagesIter
delete_DboPagePartInstsIter           delete_DboPartInstPinsIter
delete_DboPageWiresIter               delete_DboNetWiresIter
delete_DboWireAliasesIter             delete_DboPageGlobalsIter
delete_DboPageOffPageConnectorsIter   delete_DboPagePortsIter
```

**SWIG constructor 型的坑**:`DboPageNetsIter` 不回 handle,而是**建立一個同名的 Tcl command**。原廠 `capShortNet.tcl` 直接寫死 `lPageNetsIter` 且從不刪 —— 連按兩次 Compare 就撞名爆掉。解法:

```tcl
proc ::mUtilMenu::NextIterName { pTag } { variable mIterSeq; return "mUtilIter${pTag}[incr mIterSeq]" }
proc ::mUtilMenu::DropIter    { pCmd } { catch { $pCmd -delete }; catch { rename $pCmd {} } }
```

NULL 判斷一律 `while { $lObj != $lNullObj }`,其中 `set lNullObj NULL` —— SWIG 的空指標在 Tcl 端就是字串 `NULL`。

### 5.7 用到的常數

| 常數 | 用在哪 |
|---|---|
| `$::IterDefs_SCHEMATICS` | `NewViewsIter` |
| `$::IterDefs_ALL` | `DboPageNetsIter`、`NewOffPageConnectorsIter` |
| `$::DboBaseObject_PLACED_INSTANCE` | 濾掉階層方塊(`DRAWN_INSTANCE`) |
| `$::DboBaseObject_WIRE_BUS` / `_WIRE_BUNDLE` | 認 bus |
| `$::DboValue_NOROTATION` | 畫線/畫框的 rotation 參數 |
| `$::DboValue_HOLLOW_FILL` | 框不填色(填了會蓋住要指的元件) |
| `$::DboValue_COLOR7` / `_COLOR9` | 粉紅線 / 青綠框 |
| `$::DboValue_WIDE_WIDTH` | 線寬 |
| `$::DboValue_SOLID_LINE` / `_DASH_LINE` / `_DOT_LINE` / `_DASH_DOT_LINE` / `_DASH_DOT_DOT_LINE` | 線型,marker 用 DASH_DOT |

`DboEnum` L3843 統一解析:`$::DboValue_*` 查不到就丟看得懂的錯,不會把空字串灌進 Dbo 呼叫。

> **沒有 RGB setter**。`SetColor` 吃的是 Capture 固定 48 色盤的 index(Capture.exe 表在 0xE33E40),粉紅和青綠都只能取最近的一色。

### 5.8 非 DBO 的 Capture 應用層指令(一併記錄)

| 指令 | Appendix A | 用途 |
|---|---|---|
| `Open <path>` | p.130 | 開設計;已開的只 activate 視窗 |
| `SelectPMItem <name>` | p.130 | 還原 PM 選取項(項目 4) |
| `GetSelectedPMItems` / `IsDocModified` / `GetActivePMDesign` / `GetActiveOpjName` | p.129-132 | `diagSaveState` 診斷 |
| `ZoomRedraw` | — | 畫完 marker 重繪 |
| `capDisplayMessageBox` | p.140-141 | 訊息框 |
| `SetAppWindowAsParent` | p.134 | Tk 視窗掛在 Capture 底下 |
| `capCloseChildViewsExceptCurrent` | p.136 | Close Page |
| `svsDiffDesigns` | p.140 | 唯一官方比對入口,**吃整個 design 不吃 page** — 所以 page 級比對才要自己刻 |

### 5.9 效能:哪些 DBO 呼叫是貴的

`mTimeCompare`(預設 ON)量出來的實際數字:

```
timing: CollectPageParts 1843 ms - 312 part(s), 2971 pin(s)
          rule4 part pin count      14 ms over  312 call(s)
          rule4 pin position       431 ms over 1204 call(s), 1767 pin(s) skipped
          the rest of the walk    1398 ms
```

三個已經做掉的最佳化:

1. **net label 快取**(`lNetCache` array,key = SWIG 的物件 handle)。每個 pin、每個 GND 符號都問同一批 net,每答一次要走完該 net 的所有 wire。SWIG 用位址當 handle,所以同一個 `DboNet` 不管從 pin 還是從 nets iterator 來都是同一個 key。
2. **先問 pin 數再決定要不要讀 pin 位置**。`GetOffsetHotSpot` 一次要三個 Dbo 呼叫(本身 + 兩個 CPoint getter),而 `mRule4MinPins`(5)以下的被動元件 rule4 根本不看 —— 上面那行 1767 pins skipped 就是省下來的。pin 數讀不到時當作大零件,寧可慢不可錯。
3. **`DrawMarkersOnPage` 只做一次 `FindPage`**,整批 marker 共用。

而 **最貴的通常不是 DBO 是 `puts`** —— 一頁上千行、每行一次 Command Window append。`mPinDetail 0` 砍掉最大一塊(每個 pin 一行),`mQuiet 1` 全砍。

### 5.10 只在 DLL 查到、Appendix A 沒有的呼叫(清單)

這幾支沒有任何原廠 script 呼叫,是直接對 `tools\bin\orDb_Dll_Tcl64.dll` 的 SWIG wrapper 比對出來的 —— 參數名就是它 `Wrong # args` 訊息印的那些:

```
DboPortInst_GetPinNumber     self number      number 是 CString&
DboPortInst_GetIsNoConnect   self status      no-connect (X) 記號
DboPortInst_GetNet           self status      page DboNet,沒有回 NULL
DboPartInst_GetPinCount      self             兩種拼法都在 DLL 裡
DboPartInst_sGetPinCount     self
DboSchematic_Rename          self pObj newName
DboDesign_RenameObject       self pObj newName
DboPage_NewGraphicBoxInst    self status rect location rotation ?nId?
DboDesign_MarkModified       self pOccurrence  ← 就是這支害 MarkModified 一直失敗
```

查法:`strings`/字串搜尋 DLL 找 `Dbo<Class>_<Method>`,SWIG 會把完整 signature 寫進錯誤訊息表。

### 5.11 一句話速查

| 我要… | 用哪組 |
|---|---|
| 拿到某個 .DSN 的所有頁 | `GetDesignPages` → session → `NewViewsIter` / `NewPagesIter` |
| 拿到某一頁的物件 | `FindPage` / `FindPageObjs`(要改頁名就用後者) |
| 這頁有哪些零件 | `NewPartInstsIter` + `GetObjectType` 濾 `PLACED_INSTANCE` |
| 讀零件屬性 | `PropStr` → `GetEffectivePropStringValue` |
| 這隻 pin 接到哪條 net | `NextPin` 回的 DboPortInst 直接 `GetNet` |
| pin 的實體座標 | `GetOffsetHotSpot`(不是 `GetOffsetStartPoint`) |
| net 叫什麼名字 | wire 的 `NewAliasesIter`,不是 net 自己 |
| 這條線是不是 bus | `GetObjectType` 比 `WIRE_BUS` |
| 在頁上畫線/畫框 | `NewGraphicLineInst` / `NewGraphicBoxInst` + `DboSet` 設顏色 |
| 改頁名 | `DboSchematic Rename`,不是 `DboPage SetName`(沒有這支) |
| 標記已修改 | `MarkObjModified`,三層 arity 不同 |

---

## 項目 6 — (待新增)
