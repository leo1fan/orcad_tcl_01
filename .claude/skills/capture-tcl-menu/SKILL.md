---
name: capture-tcl-menu
description: Add, remove, or reposition menus and toolbars in OrCAD Capture using TCL. Use when asked to create a new main/top-level menu, add items under an existing menu (File, Edit, Tools, Place, SI Analysis, Accessories, Options...), add a toolbar button, hide stock menu items, or when working with InsertXMLMenu / DeleteXMLMenu / FindXMLMenu / RefreshMenu / RegisterAction / AddAccessoryMenu / InsertXMLToolbar in G:\Cadence\SPB_17.4\tools\capture\tclscripts.
---

# OrCAD Capture menu customization via TCL

## Key fact: the menu bar is not defined in any .tcl file

File / Design / Edit / View / Tools / Place / SI Analysis / Accessories / Options /
Window / Help are compiled into the Capture binary. There is **no** shipped `.men`,
`.mnu`, or menu `.xml` to edit anywhere under `tools\capture`.

Do not confuse this with Allegro PCB Editor, whose menus **are** editable text files at
`share\pcb\text\cuimenus\*.men` (`allegro.men`, `orcad.men`, ...). Different tool,
different mechanism. If the user says "Allegro" but means the schematic tool, they mean
Capture — confirm before pointing them at `.men` files.

Capture's TCL API instead **mutates the in-memory menu model at runtime**.

## API

| Command | Purpose |
|---|---|
| `InsertXMLMenu` | Insert a popup / action / separator node |
| `DeleteXMLMenu` | Remove a node by ID path |
| `FindXMLMenu` | Look up a node; returns `NULL` when absent |
| `RefreshMenu` | Redraw the menu bar after changes |
| `RegisterAction` | Bind a named tag to Tcl action + enabler procs |
| `UnregisterAction` | Remove a tag |
| `InsertXMLToolbar` | Add a toolbar / toolbar button |
| `LoadCustomToolBar` | Apply toolbar changes |

### InsertXMLMenu

All arguments are wrapped in **one** Tcl list of 5 elements:

```tcl
InsertXMLMenu [list <idPath> <relPos> <refId> <nodeSpec> <scope>]
```

- **`idPath`** — list of menu **IDs** from root down; the last element is the new node's ID
- **`relPos`** — `"0"` = insert *before* `refId`, `"1"` = insert *after* `refId`, `""` = append
- **`refId`** — sibling ID used as the anchor
- **`nodeSpec`** — one of:
  - popup: `{popup <label> <flag> <actionTag> <enablerTag> <accel> <reserved>}`
  - action: `{action <label> <flag> <actionTag> <updateTag> <accel> <bmp16> <bmp24> <statusText> <checkTag>}`
  - separator: `{separator}`
- **`scope`** — `""` = all views. Every shipped call site passes `""`.

`&` in a label sets the Alt mnemonic (`"Align &Left"`).

### RegisterAction

```tcl
RegisterAction <tag> <shouldProcessProc> <accelerator> <handlerProc> <viewScope>
```

The `actionTag` / `enablerTag` in a `nodeSpec` must match a registered tag, or the item
will be dead. Enabler procs return `true`/`false` to grey the item; `checkTag` procs
return a bool to show a checkmark.

## Reference implementations in this tree

Read these before writing new code — they are the ground truth for argument shapes.

| File | Shows |
|---|---|
| `capCloud\OrCloudMenu.tcl:10` | **Top-level** popup (`Cloud`) inserted before `Help` — the pattern for a new main menu |
| `capULCloudConnector\tcl\OrCloudULMenu.tcl:42-53` | Child into that popup; `DeleteXMLMenu` + `RefreshMenu` teardown |
| `capAutoLoad\capObjectAlignmentInit.tcl:194-207` | Popup + actions + separators + icons + `checkTag` under `Edit` |
| `capAutoLoad\capObjectAlignmentInit.tcl:169-181` | `InsertXMLToolbar` for a toolbar and its buttons |
| `capAutoLoad\orEagleImportInit.tcl:12-13` | Minimal insert-with-anchor under `File > Import Design` |
| `capAutoLoad\capAutoDemoBrowser.tcl:25` | Minimal action insert, guarded by install mode |
| `capAutoLoad\capTCLMenu.tcl` | Enumerates every menu ID per view scope — use it as the ID lookup table |
| `capUtils\capMenuUtil.tcl:15-26` | `AddAccessoryMenu` — the *other*, older hook |

## Menu IDs

IDs are not the visible labels. Notably **`Analysis` is the ID of the menu labelled
"SI Analysis"** (children `AnalysisSILibrarySetup`, `AnalysisAssignSIModel`, ...).

Confirmed as bare top-level IDs in `capTCLMenu.tcl`: `Accessories`, `Analysis`, `Design`,
`Macro`, `Place`, `TestBench`, `View`. The rest (`File`, `Edit`, `Tools`, `Options`,
`Window`, `Help`) are inferred from child prefixes such as `FileImportSelection`,
`EditUndo`, `ToolsAnnotate`, `OptionsDesignProperties`.

Menu-bar order is `... Analysis, Accessories, Options, Window, Help`.

**To discover an ID:** grep `capAutoLoad\capTCLMenu.tcl` for a nearby label or command
name, or probe live with `FindXMLMenu [list "Tools"]` in the TCL Command Window.

View scopes used by `capTCLMenu.tcl::CanAddMenu`: `PROJECT_MANAGER_VIEW`, `PART_VIEW`,
`SCHEMATIC_VIEW`, `PROPERTY_EDITOR_VIEW`, `HTML_VIEW`, `LOG_VIEW`, `SYMBOL_VIEW`,
`VHDL_VIEW`, `TEXT_VIEW`, `VERILOG_VIEW`.

## Where to put the script

`<install>\tools\capture\tclscripts\capAutoLoad\<name>.tcl`

**Every `.tcl` in `capAutoLoad\` is sourced automatically at Capture startup.** Adding a
new file there is sufficient — never edit `capinit.tcl`, `capinit_internal.tcl`, or any
Cadence-shipped script to register a menu.

Treat everything else in the tree as vendor code: read freely, do not modify.

## Template — new top-level menu

```tcl
package provide myMenu 1.0

namespace eval ::myMenu {
    variable mMenuId    "myMenu"
    variable mMenuLabel "myMenu"
}

proc ::myMenu::True    { args } { return true }
proc ::myMenu::Action  { args } { return true }
proc ::myMenu::Enabler { args } { return true }

proc ::myMenu::init { } {
    catch {
        RegisterAction "myMenuAction"  "::myMenu::True" "" "::myMenu::Action"  ""
        RegisterAction "myMenuEnabler" "::myMenu::True" "" "::myMenu::Enabler" ""

        InsertXMLMenu [list \
            [list $::myMenu::mMenuId] \
            "0" "Accessories" \
            [list "popup" $::myMenu::mMenuLabel "0" \
                  "myMenuAction" "myMenuEnabler" "" ""] \
            ""]

        RefreshMenu
    }
}

proc ::myMenu::remove { } {
    catch {
        DeleteXMLMenu [list $::myMenu::mMenuId]
        RefreshMenu
    }
}

::myMenu::init
```

Adding a command under it:

```tcl
RegisterAction "myCmdAction"  "::myMenu::True" "" "::myMenu::MyCmd"  ""
RegisterAction "myCmdEnabler" "::myMenu::True" "" "::myMenu::Enabler" ""
InsertXMLMenu [list [list "myMenu" "myCmd"] "" "" \
    [list "action" "&My Command..." "0" "myCmdAction" "myCmdEnabler" \
          "" "" "" "Status bar text"] ""]
```

## Rules

1. **Always wrap in `catch`.** A raw error in a `capAutoLoad` script surfaces as a popup
   at Capture startup. Every shipped script guards this way.
2. **Give the popup action+enabler tags** even when it is only a container —
   `OrCloudMenu.tcl:10` does this for its top-level `Cloud` popup.
3. **Always provide a `remove` proc** so the menu can be torn down and the file
   re-`source`d without restarting Capture.
4. **A childless popup may not render.** If `FindXMLMenu` returns non-`NULL` but nothing
   appears on the menu bar, add one child item.
5. **`AddAccessoryMenu` is not a substitute.** It only adds items *under* Accessories and
   cannot create a top-level menu. Signature:
   `AddAccessoryMenu <userMenu> <subMenu> <callback>` — callback takes `pPage pOcc` for
   the page variant, `pLib` for the design variant, registered via the
   `_cdnCapTclAddPageCustomMenu` / `_cdnCapTclAddDesignCustomMenu` action tags.

## Verification

Syntax-check without launching Capture (Capture-only commands are swallowed by `catch`):

```powershell
& "G:\Cadence\SPB_17.4\tools\bin\tclsh.exe" -c "source {G:/.../capAutoLoad/myMenu.tcl}"
```

Better: stub `InsertXMLMenu` to print its argument list, source both the new file and a
known-good shipped one (`OrCloudMenu.tcl`), and diff the structures. Catches bracket and
quoting errors that a bare source will not.

In Capture's TCL Command Window:

```tcl
FindXMLMenu [list "myMenu"]        ;# non-NULL => insert succeeded
::myMenu::remove                   ;# tear down
source {G:/.../capAutoLoad/myMenu.tcl}   ;# reload, no restart needed
```

Then check the menu bar visually, check the Session Log for TCL errors, and switch
between Project Manager / schematic page / part editor to confirm scope behaviour.

## Caveats to tell the user

- Writing under `G:\Cadence\SPB_17.4\` may need Administrator rights.
- A Cadence ISR/hotfix or upgrade **wipes `capAutoLoad\`**. Keep a master copy outside
  the install tree and re-copy after updates. If a custom menu "disappears", suspect this
  before debugging the Tcl.
