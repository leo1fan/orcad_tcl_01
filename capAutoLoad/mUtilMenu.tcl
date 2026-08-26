#/////////////////////////////////////////////////////////////////////////////////
#  TCL file: mUtilMenu.tcl
#
#  Adds a top-level "mUtil" menu, plus the SAME two commands under
#  Accessories > mUtil, so the two menu mechanisms can be compared:
#
#     mUtil        -> built with InsertXMLMenu   (undocumented, Cadence-internal)
#     Accessories  -> built with AddAccessoryMenu (documented, ch.10 of
#                     OrCAD_Capture_TclTk_Extensions.pdf)
#
#  Items:
#     Schematic Compare -> Tk dialog: two .DSN fields + Browse, Execute/Cancel
#     Close Page        -> tab RMB > Close All Tabs But This
#
#  Schematic Compare flow:
#     dialog        Default Folder + two .DSN fields, each with Browse
#     Execute       both fields filled?  no  -> "Please select two DSN file..."
#                                        yes -> Open(pPath) both designs
#                                               (Appendix A, p.130), then show
#                                               the page selector
#     page selector two columns, one per design, both drawn inside ONE canvas so
#                   the gap between them can be drawn in as well: filename header,
#                   then one checkbox per page, listed in PROJECT_MANAGER_VIEW
#                   order.  ::mUtilMenu::GetCheckedPages A|B returns the ticked
#                   {schematicName pageName} pairs.
#                   Columns are headed "(O) <file>" and "(N) <file>".
#                   Page_name_mapping pairs the two columns up by page name and
#                   the canvas draws the result between them:
#                     exact    same name after StripPageNamePrefix - black text,
#                              solid line from one column to the other
#                     similar  same first mPageSimilarChars characters - red text,
#                              dashed line
#                     none     no counterpart at all - red text, no line
#                   The lines are all drawn in one go once the window is finished
#                   (mPageLinksReady / RedrawPageLinks), not while it is being
#                   built, so they do not appear and then shift about.
#                   Buttons, left to right: AllPagesComp, then a wide gap, then
#                   PageComp and Close.  Refcompare is built but not packed - see
#                   ShowPageSelector.
#     PageComp      exactly one page ticked per column?
#                       no  -> "Please select each one Page to compare"
#                       yes -> dump both pages to the Command Window (parts,
#                              off-page/power/ports, nets, buses), diff every
#                              section O vs N, and report New / Remove (or
#                              "all the same") in one result window
#                   Nets and Buses are reported in full rather than capped, and
#                   everything (N) has that (O) has not is then marked on (N)'s
#                   page: a thick pink DASH-DOT line over each new net/bus wire's
#                   own coordinates, nudged clear of the wire by mLineOffset, and
#                   a thick turquoise rectangle round each new part's bounding box.
#                   Broken rather than solid so a marker can never be read as a
#                   wire the compare added - see mMarkLineStyle for the five
#                   styles available.
#                   DrawCompareMarkerLine / DrawPageLineOn / DrawPageBoxOn are the
#                   only part of this file that *writes* to a design.
#     Refcompare    same check, Parts only, matched by Part Reference:
#                              Add / Remove / Changed, or "all the same"
#                   (no marker lines - PageComp is the one that marks)
#                   Its button is hidden; the code is all still here and
#                   ::mUtilMenu::DoPageRefCompare still runs it.
#     AllPagesComp  the same compare PageComp does, but over every mapped page
#                   pair at once - every pair the selector drew a line for, solid
#                   or dashed.  A page with no line is not compared and not
#                   touched.  Silent: no report window and nothing in the Command
#                   Window (mQuiet), because one full page dump per pair would be
#                   thousands of lines for a one-number answer.  Each (N) page
#                   that came out different keeps its markers AND gets a '*' put
#                   in front of its name, so PROJECT_MANAGER_VIEW shows which
#                   pages changed.  Ends in one message box with the count; OK
#                   closes it and the page selector with it, and then puts the
#                   Project Manager's selection back on the (N) design - the
#                   renaming rebuilds the PM tree and empties the selection, which
#                   is what leaves File > Save and Save As both greyed out until
#                   another design is clicked and clicked back.  See
#                   RestorePMSelection / mRestorePM, and ::mUtilMenu::diagSaveState
#                   if Save is ever greyed out again.
#     result window read-only Tk text widget, not a message box - the report can
#                   be selected with the mouse and copied out.  Banner is
#                   "Schematic Page Compare Result" / "Schematic Page Reference
#                   Compare Result".
#
#  Both compares are page-level and built on the database walk below.  The one
#  documented compare entry point is svsDiffDesigns (Appendix A, p.140):
#
#       svsDiffDesigns <srcDesign> <dstDesign> ?lOccMode? ?ECO_MODE?
#
#  It takes whole designs, not page lists, which is why a page-level compare has
#  to be built on GetDesignPages / DumpPageInfo instead.
#
#  NOTE on Tk: the dialog needs a working Tk.  Capture ships Tcl without Tk
#  wired up by default - see section 1.4 "Capture TCL/Tk Advanced Environment
#  Setup" (p.15-16) of the PDF.  Verify with:
#
#       package require Tk
#       toplevel .new
#
#  If that fails, Schematic Compare falls back to a message box telling you so.
#
#  Location: <install dir>/tools/capture/tclscripts/capAutoLoad
#/////////////////////////////////////////////////////////////////////////////////

package provide mUtilMenu 1.0

namespace eval ::mUtilMenu {
    variable mMenuId    "mUtil"
    variable mMenuLabel "mUtil"

    # Menu "<TopMenu>::<ItemLabel>" is how Cadence's own shipped scripts invoke
    # built-in menu commands - 28 call sites under tclscripts, e.g.
    #   capAssociatePSpiceModel.tcl:103   Menu "File::Save"
    #   caplearningresbase.tcl:99         Menu "Design::Make Root"
    # Kept here because Close Page and any future item may need it.

    # Schematic Compare dialog state
    variable mCmpWin   ".mUtilSchCompare"
    variable mCmpFileA ""
    variable mCmpFileB ""

    # Where Browse... starts when the field is still empty.  Shown as the first
    # row of the dialog and editable there (its own Browse picks a folder), so
    # this line is only the startup default.
    variable mCmpInitDir {G:\Project\MB\Rex6_Hsu\W980 WS}

    # Page-selector window state.  mPagesA/mPagesB hold {schematicName pageName}
    # pairs; mPageSelA/mPageSelB are the checkbox variables, indexed by the
    # position of the page in that list.
    variable mPagesWin ".mUtilSchPages"
    variable mPagesA   [list]
    variable mPagesB   [list]
    # The two .DSN paths the current page selector was built from, so Compare
    # can name the designs in its message box.
    variable mPagesFileA ""
    variable mPagesFileB ""
    variable mPageSelA
    variable mPageSelB
    array set mPageSelA {}
    array set mPageSelB {}

    # What Page_name_mapping paired up, as {indexA indexB exact|similar} triples -
    # the same list the canvas draws its lines from, kept because AllPagesComp is
    # going to walk exactly these pairs.
    variable mPageLinks [list]

    # Geometry of the page selector's single canvas, in pixels: one column of
    # checkboxes, a gap wide enough to draw a line across, then the other column.
    variable mPageColWidth 300
    variable mPageLinkGap  120

    # How many leading characters of the stripped page name have to agree before
    # two pages that are NOT identically named count as "similar" - the dashed
    # line.  A name shorter than this compares whole, so it can only ever be
    # similar to a name of the same length, which would have matched exactly.
    variable mPageSimilarChars 10

    # Colours of the two link styles.  Tk colour names, not DboValue enums - these
    # are drawn in the dialog, not on a page.
    variable mLinkColorExact   "#2e8b57"
    variable mLinkColorSimilar "red"

    # Live state of the page-selector canvas, so RefreshPageLinks can redraw the
    # links whenever the columns are laid out again (window resize, first map)
    # without ShowPageSelector having to thread it all through a binding.
    variable mPageCanvas ""
    variable mPageCbsA   [list]
    variable mPageCbsB   [list]
    variable mPageLinkX1 0
    variable mPageLinkX2 0

    # 0 = the columns are still being built, so DrawPageLinks draws nothing.
    # ShowPageSelector leaves it at 0 the whole way through and RedrawPageLinks
    # raises it, which is what makes the lines appear in one go at the end
    # instead of being drawn against a half-finished layout and then jumping
    # every time Tk moves something.
    variable mPageLinksReady 0

    # Compare result window.  The result used to go in a capDisplayMessageBox,
    # whose text cannot be selected - this is a plain Tk text widget instead, so
    # the report can be dragged over with the mouse and copied out.
    variable mResultWin ".mUtilCmpResult"

    # How the page list is ordered before it is shown.  The database walk hands
    # pages back in the design's internal (insertion) order, which is NOT what
    # PROJECT_MANAGER_VIEW displays - reversing it only happens to line up when
    # every page was created in name order.  So sort explicitly:
    #   dictionary - natural sort, PAGE2 before PAGE10   (default)
    #   ascii      - plain string sort, PAGE10 before PAGE2
    #   dbreverse  - reverse of the iterator order
    #   dborder    - raw iterator order, unsorted
    # Use ::mUtilMenu::DumpPages <dsn> to see all four against the real tree.
    variable mPageSortMode "dictionary"

    # Marker characters a page name may be prefixed with - "*PAGE1", "--PAGE1",
    # "~PAGE1" all mean PAGE1 as far as the A/B mapping is concerned, so they are
    # stripped off the front before the two names are compared.  Whitespace is in
    # the set too, otherwise "* PAGE1" would keep a leading space and never match.
    variable mPageNamePrefixChars "*-?~+%\$#@! \t"

    # Serial number for the SWIG iterator command names built in NextIterName.
    variable mIterSeq 0

    # Units the page dump prints coordinates in:
    #   user - inches as Capture's status bar shows them, 2 decimals (default)
    #   doc  - raw internal integers, exact but granularity-dependent
    variable mCoordMode "user"

    # What Compare marks on the (N) page once it is done.  Both are filled by
    # DumpFullCompare, consumed by DrawCompareMarkerLine, and reset at the top of
    # every compare so a second Compare never redraws the first one's findings.
    # Coordinates are doc units, straight off the object - never re-parsed out of
    # the printed dump, which is rounded to two decimals.
    #
    #   mMarkSegs   one line per net wire / bus wire (N) has and (O) has not,
    #               {label x1 y1 x2 y2}
    #   mMarkBoxes  one rectangle per part (N) has and (O) has not, around its
    #               bounding box, {label left top right bottom}
    variable mMarkSegs  [list]
    variable mMarkBoxes [list]

    # How far the marker is moved off the wire it marks, so it does not simply
    # cover it: a horizontal wire's marker goes up by this much, a vertical wire's
    # marker goes right by it.  Diagonal wires are marked in place.
    #
    # Given in the user units the dump prints - the 220.22 / 65.02 in
    # "(220.22,65.02)-(204.22,65.02)" - and multiplied by the page's physical
    # granularity to reach the doc units the Dbo call wants.  Set
    # mLineOffsetUnits to "doc" to give it in raw doc units instead.
    # 0 = no nudge at all: the marker sits exactly on top of the wire it marks.
    variable mLineOffset      0
    variable mLineOffsetUnits "user"

    # pMax for RefListStr on the categories that are still capped (Parts, Symbols,
    # and everything Refcompare reports).  Nets and Buses are listed in full.
    variable mRefListMax 200

    # Colour and width are DboValue enum *names*; DrawPageLineOn / DrawPageBoxOn
    # resolve them to $::DboValue_<name> at call time so a session missing one says
    # so instead of dying inside the Dbo call.
    #
    # There is no RGB setter - SetColor takes an index into Capture's fixed
    # 48-entry palette (Capture.exe, table at 0xE33E40; index 40 is black and 47
    # is white, which is what capDParts/capDynObjects.tcl:17-23 maps "black" and
    # "white" onto, so the index and the COLORn number line up).  Neither wanted
    # colour is in it exactly, so each is the nearest entry:
    #
    #   pink RGB(255,192,203)         turquoise RGB(64,224,208)
    #     COLOR7   RGB(255,128,255)     COLOR9   RGB(  0,255,255)  cyan  <- default
    #       light magenta   <- default   COLOR1   RGB(128,255,255)  pale cyan
    #     COLOR21  RGB(255,128,128)     COLOR42  RGB( 64,128,128)  dark teal
    #       salmon
    #     COLOR31  RGB(255,  0,128)   COLOR9 and COLOR1 are the same RGB distance
    #       rose / hot pink            away; COLOR9 wins on lightness (turquoise is
    #                                  56% light, COLOR9 is 50%, COLOR1 is 75%) and
    #                                  on contrast against this project's pale green
    #                                  page background, RGB(199,237,204).
    #
    # Widths are THIN_WIDTH / MEDIUM_WIDTH / WIDE_WIDTH / DEFAULT_LINE_WIDTH.
    #
    # Styles are the DboValue::LineStyleT set, which is the same five the Edit
    # Graphic dialog offers plus the two defaults (checked against
    # orDb_Dll_Tcl64.dll, DboValue_SetLineStyle / LineStyleT):
    #
    #   DboValue_SOLID_LINE            unbroken            <- Capture's default
    #   DboValue_DASH_LINE             - - - - - -
    #   DboValue_DOT_LINE              . . . . . .
    #   DboValue_DASH_DOT_LINE         - . - . - .         <- marker lines
    #   DboValue_DASH_DOT_DOT_LINE     - . . - . .
    #   DboValue_DEFAULT_LINE_STYLE    whatever the page default is
    #   DboValue_INVALID_LINE_STYLE    not a style - never set this
    #
    # The marker lines are dash-dot so a marker cannot be mistaken for a wire the
    # compare added: a pink solid line over a net looks like schematic content, a
    # pink dash-dot one does not - and dash-dot is more clearly deliberate than a
    # plain dash, which a schematic can legitimately contain.  "" leaves the style
    # alone.
    #
    # NOTE: a broken line and WIDE_WIDTH together are a GDI pen combination that
    # some renderers collapse back to solid.  If the dashes do not show up on the
    # page, drop mMarkLineWidth to MEDIUM_WIDTH or THIN_WIDTH - the style is the
    # part that carries the meaning, the width is only there to be visible.
    variable mMarkLineColor "DboValue_COLOR7"
    variable mMarkLineWidth "DboValue_WIDE_WIDTH"
    variable mMarkLineStyle "DboValue_DASH_DOT_LINE"
    variable mMarkBoxColor  "DboValue_COLOR9"
    variable mMarkBoxWidth  "DboValue_WIDE_WIDTH"
    # Boxes stay solid - a rectangle round a part is already unmistakably not
    # schematic content.  Same enum set as mMarkLineStyle if that ever changes.
    variable mMarkBoxStyle  ""

    # 1 = pop a message box every time a callback fires, so it is obvious
    #     which menu mechanism actually reaches the TCL code.
    #     Close Page is confirmed working, so this is off.
    variable mDebug 0

    # 1 = swallow everything Out would print to the Command Window.  AllPagesComp
    #     runs one full compare per mapped page pair, so left alone it would push
    #     several thousand lines of page dump into the window for a result that is
    #     a single count; it raises this for the length of its run and puts it
    #     back afterwards.  Nothing else touches it.
    variable mQuiet 0

    # 1 = after AllPagesComp, put the Project Manager back on the (N) design and
    #     give it a selected item again - see RestorePMSelection for why File >
    #     Save and Save As both come back greyed out without it.  0 turns it off
    #     if activating the window ever gets in the way.
    variable mRestorePM 1

    # The PM tree node RestorePMSelection selects.  "Design Resources" is the one
    # Cadence's own save path uses (capAdvancedSaveFramework/tcl/capAdvancedSave.tcl:380);
    # the design's own root name is tried after it, for a bare .DSN opened without
    # a project.
    variable mPMSelectItem "Design Resources"
}

proc ::mUtilMenu::True    { args } { return true }
proc ::mUtilMenu::Action  { args } { return true }
proc ::mUtilMenu::Enabler { args } { return true }

# Every line this file writes to the Command Window goes through here - there is
# no bare "puts" left in it - so mQuiet is the one switch that silences a whole
# compare.  Same signature as puts, minus the channel argument, which nothing
# here was passing anyway.
proc ::mUtilMenu::Out { args } {
    variable mQuiet
    if { $mQuiet } {
        return
    }
    # {*} rather than "eval puts $args": a net name really can be "ADDR[0..7]",
    # and eval would try to run the brackets.
    puts {*}$args
}

proc ::mUtilMenu::Trace { pMsg } {
    variable mDebug
    ::mUtilMenu::Out "mUtil: $pMsg"
    if { $mDebug } {
        catch { capDisplayMessageBox $pMsg "mUtil" }
    }
}

#=============================================================================
# Schematic Compare
#=============================================================================

# Pick the folder that the two Design File Browse... buttons start in.
proc ::mUtilMenu::BrowseInitDir { } {
    variable mCmpWin
    variable mCmpInitDir

    set lOpts [list -parent $mCmpWin -title "Select Default Folder" -mustexist 1]
    if { [file isdirectory $mCmpInitDir] } {
        lappend lOpts -initialdir $mCmpInitDir
    }

    set lDir [eval tk_chooseDirectory $lOpts]
    if { $lDir ne "" } {
        set mCmpInitDir [file nativename $lDir]
    }
}

# Browse for one .DSN and drop it into the given namespace variable.
proc ::mUtilMenu::BrowseDesign { pVarName } {
    variable mCmpWin
    variable mCmpInitDir

    # Prefer the folder of whatever is already in the field, so a second Browse
    # reopens where the user was.  Otherwise start at mCmpInitDir.
    set lDir ""
    set lCur [set ::mUtilMenu::$pVarName]
    if { $lCur ne "" && [file isdirectory [file dirname $lCur]] } {
        set lDir [file dirname $lCur]
    } elseif { [file isdirectory $mCmpInitDir] } {
        set lDir $mCmpInitDir
    }

    set lOpts [list \
        -parent $mCmpWin \
        -title "Select Design File" \
        -defaultextension ".dsn" \
        -filetypes { {"OrCAD Design Files" {.dsn}} {"All Files" *} }]
    if { $lDir ne "" } {
        lappend lOpts -initialdir $lDir
    }

    set lFile [eval tk_getOpenFile $lOpts]

    if { $lFile ne "" } {
        set ::mUtilMenu::$pVarName [file nativename $lFile]
    }
}

#-----------------------------------------------------------------------------
# Page selector - the window that comes up after both designs are opened.
#-----------------------------------------------------------------------------

# Walk one .DSN and return a list of {schematicName pageName} pairs.
#
# NOTE: the iterators hand schematics and pages back in the design's internal
# order, which is neither PROJECT_MANAGER_VIEW order nor its exact reverse - see
# SortPages, which is what callers should put the result through.
#
# The session pointer needs no setup: $::DboSession_s_pDboSession already holds
# Capture's live session and "DboSession -this" only wraps it as a Tcl object.
# Same two lines as the shipped scripts, e.g. capCM/tcl/capCMImpl.tcl:48.
#
# Database walk follows the PDF exactly:
#   3.2.2  get current session          (p.29)
#   3.2.4  GetDesignAndSchematics       (p.29)
#   3.2.7  NewViewsIter / NextView      (p.30)
#   3.2.9  NewPagesIter / NextPage      (p.31)
# Names come back as CString, so GetName + DboTclHelper_sGetConstCharPtr (p.28).
proc ::mUtilMenu::GetDesignPages { pDsnPath } {
    set lResult  [list]
    set lNullObj NULL

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession

    set lStatus [DboState]
    set lPath   [DboTclHelper_sMakeCString [file normalize $pDsnPath]]
    set lDesign [$lSession GetDesignAndSchematics $lPath $lStatus]

    if { $lDesign == $lNullObj } {
        catch { $lStatus -delete }
        error "design not found in session"
    }

    set lSchIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
    set lView    [$lSchIter NextView $lStatus]

    while { $lView != $lNullObj } {
        # dynamic cast DboView -> DboSchematic, per 3.2.7
        set lSch     [DboViewToDboSchematic $lView]
        set lSchName [DboTclHelper_sMakeCString]
        $lSch GetName $lSchName
        set lSchStr [DboTclHelper_sGetConstCharPtr $lSchName]

        set lPagesIter [$lSch NewPagesIter $lStatus]
        set lPage      [$lPagesIter NextPage $lStatus]

        while { $lPage != $lNullObj } {
            set lPgName [DboTclHelper_sMakeCString]
            $lPage GetName $lPgName
            lappend lResult [list $lSchStr [DboTclHelper_sGetConstCharPtr $lPgName]]
            set lPage [$lPagesIter NextPage $lStatus]
        }
        catch { delete_DboSchematicPagesIter $lPagesIter }

        set lView [$lSchIter NextView $lStatus]
    }

    catch { delete_DboLibViewsIter $lSchIter }
    catch { $lStatus -delete }

    return $lResult
}

#-----------------------------------------------------------------------------
# Page dump - parts + nets of one page, printed to the Command Window.
#
# Every call below is lifted from a shipped Cadence script, so none of it is
# guesswork:
#   NewPartInstsIter / NextPartInst      capAutoLoad/capAssociatePSpiceModel.tcl:343
#   DboPartInstToDboPlacedInst           capAutoLoad/capAssociatePSpiceModel.tcl:347
#   GetSourceLibName / GetPackage        capAutoLoad/capAssociatePSpiceModel.tcl:349
#   GetEffectivePropStringValue          capAutoLoad/capAssociatePSpiceModel.tcl:359
#   NewPinsIter / NextPin / GetPinName   capDRC/capPortPinMismatch.tcl:101,109
#   DboPageNetsIter / NextNet            capDB/capShortNet.tcl:133
#   DboNetWiresIter / NextWire           capDB/capShortNet.tcl:110
#   DboWireAliasesIter / NextAlias       capDB/capShortNet.tcl:82
#   GetStartPoint / GetEndPoint          capDRC/capOverlapWires.tcl:41,44
#   DboTclHelper_sGetCPointX / ...Y      capDRC/capOverlapWires.tcl:42,43
#   GetLocation                          capAlignObject/capObjectAlignment.tcl:413
#   GetBoundingBox / sGetCRectTopLeft    capAlignObject/capObjectAlignment.tcl:375,377
#   GetPhysicalGranularity               capDRCFramework/tcl/capCustomDRC.tcl:159
#   NewOffPageConnectorsIter / Next...   capDRCFramework/tcl/capProcessDRC.tcl:81
#   off-page connector GetName           capFindAndReplace/tcl/capDesignUtil.tcl:425
#   NewGlobalsIter / NextGlobal          capDRCFramework/tcl/capProcessDRC.tcl:46
#   NewPortsIter / NextPort / GetName    capDRC/capPortPinMismatch.tcl:31,32,38
#   NewWiresIter / NextWire (page)       capDRCFramework/tcl/capProcessDRC.tcl:30
#   NewWiresIter (net) / NewAliasesIter  capDRC/capOverlapWires.tcl:172, ...
#                                        capFindAndReplace/tcl/capDesignUtil.tcl:339
#   WIRE_BUS / WIRE_BUNDLE object types  capAlignObject/capObjectAlignment.tcl:371-373
#
# Parts and nets are printed sorted (by reference / by net name) so the two
# dumps can be diffed line for line; wire endpoints inside a net are sorted for
# the same reason - database order would otherwise show up as a false change.
#
# Net names come from wire aliases, which is the only page-level route: a page
# net has no name of its own.  Pin-to-net mapping is NOT here - that needs the
# flattened occurrence walk (DboNetOccurrence GetNet, see
# capDRCFramework/tcl/capProcessDRC.tcl:255), not the page objects.
#-----------------------------------------------------------------------------

# DboPageNetsIter and friends are SWIG constructors: they create a Tcl command
# rather than returning a handle, so each one needs its own name or a second
# Compare click would collide with the first.
proc ::mUtilMenu::NextIterName { pTag } {
    variable mIterSeq
    return "mUtilIter${pTag}[incr mIterSeq]"
}

proc ::mUtilMenu::DropIter { pCmd } {
    catch { $pCmd -delete }
    catch { rename $pCmd {} }
}

# One property off a placed instance, "" when it is not set.
proc ::mUtilMenu::PropStr { pObj pPropName } {
    set lName  [DboTclHelper_sMakeCString $pPropName]
    set lValue [DboTclHelper_sMakeCString]
    if { [catch { $pObj GetEffectivePropStringValue $lName $lValue }] } {
        return ""
    }
    return [DboTclHelper_sGetConstCharPtr $lValue]
}

# Internal ("doc") units -> whatever mCoordMode asks for.  The user-unit
# formula is capCustomDRC's: divide by the page's physical granularity.
proc ::mUtilMenu::Coord { pPage pDoc } {
    variable mCoordMode

    if { $mCoordMode eq "doc" } {
        return $pDoc
    }
    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        return $pDoc
    }
    return [format "%.2f" [expr { double($pDoc) / $lGran }]]
}

# Empty values print as "-" so a missing property is visible in the dump rather
# than showing up as trailing whitespace.
proc ::mUtilMenu::OrDash { pValue } {
    if { [string trim $pValue] eq "" } {
        return "-"
    }
    return $pValue
}

proc ::mUtilMenu::PointStr { pPage pPoint } {
    set lX [::mUtilMenu::Coord $pPage [DboTclHelper_sGetCPointX $pPoint]]
    set lY [::mUtilMenu::Coord $pPage [DboTclHelper_sGetCPointY $pPoint]]
    return "($lX,$lY)"
}

# Where an object sits.  GetLocation is the placement origin - the value that
# moves when the object is dragged - so it is the one worth diffing; the bounding
# box is added when it is available because an object can keep its origin and
# still be mirrored or rotated.  Works for part instances, ports, globals and
# off-page connectors alike (orPrmDboStreamer.tcl:1755,1798 uses both calls on
# all four).
proc ::mUtilMenu::ObjLocStr { pPage pObj pStatus } {
    set lOut ""
    catch { set lOut [::mUtilMenu::PointStr $pPage [$pObj GetLocation $pStatus]] }

    catch {
        set lRect [$pObj GetBoundingBox]
        set lTL   [::mUtilMenu::PointStr $pPage [DboTclHelper_sGetCRectTopLeft     $lRect]]
        set lBR   [::mUtilMenu::PointStr $pPage [DboTclHelper_sGetCRectBottomRight $lRect]]
        append lOut " bbox $lTL-$lBR"
    }
    return [string trim $lOut]
}

# The same bounding box as raw doc integers, {left top right bottom}, or {} when
# it cannot be read.  What ObjLocStr prints has been through Coord and rounded to
# two decimals - fine to read, useless to draw from - so the marker rectangles are
# built off this instead.  Page coordinates run y downward, so top < bottom, which
# is the order CRect itself wants.
proc ::mUtilMenu::ObjBBoxDoc { pObj } {
    set lOut [list]
    catch {
        set lRect [$pObj GetBoundingBox]
        set lTL   [DboTclHelper_sGetCRectTopLeft     $lRect]
        set lBR   [DboTclHelper_sGetCRectBottomRight $lRect]
        set lOut  [list [DboTclHelper_sGetCPointX $lTL] [DboTclHelper_sGetCPointY $lTL] \
                        [DboTclHelper_sGetCPointX $lBR] [DboTclHelper_sGetCPointY $lBR]]
    }
    return $lOut
}

# The two endpoints of one wire, "(x1,y1)-(x2,y2)".
proc ::mUtilMenu::WireSegStr { pPage pWire pStatus } {
    set lSeg "?"
    catch {
        set lSeg "[::mUtilMenu::PointStr $pPage [$pWire GetStartPoint $pStatus]]-[::mUtilMenu::PointStr $pPage [$pWire GetEndPoint $pStatus]]"
    }
    return $lSeg
}

# The same two endpoints as raw doc integers, {x1 y1 x2 y2}, or {} when they
# cannot be read.  WireSegStr's output has been through Coord and is rounded to
# two decimals, which is fine to read and useless to draw from - the marker lines
# are placed off this instead.
proc ::mUtilMenu::WireSegDoc { pWire pStatus } {
    set lSeg [list]
    catch {
        set lS [$pWire GetStartPoint $pStatus]
        set lE [$pWire GetEndPoint   $pStatus]
        set lSeg [list [DboTclHelper_sGetCPointX $lS] [DboTclHelper_sGetCPointY $lS] \
                       [DboTclHelper_sGetCPointX $lE] [DboTclHelper_sGetCPointY $lE]]
    }
    return $lSeg
}

# Alias names carried by one wire.  Method form of the iterator, as used by
# capFindAndReplace/tcl/capDesignUtil.tcl:339 and orPrmDboStreamer.tcl:993 -
# no SWIG constructor name to juggle.
proc ::mUtilMenu::WireAliases { pWire pStatus } {
    set lNullObj NULL
    set lNames   [list]

    catch {
        set lIter  [$pWire NewAliasesIter $pStatus]
        set lAlias [$lIter NextAlias $pStatus]
        while { $lAlias != $lNullObj } {
            set lName [::mUtilMenu::CStr $lAlias GetName]
            if { $lName ne "" && [lsearch -exact $lNames $lName] == -1 } {
                lappend lNames $lName
            }
            set lAlias [$lIter NextAlias $pStatus]
        }
        catch { delete_DboWireAliasesIter $lIter }
    }
    return $lNames
}

# What to call a page net.  A page-level DboNet carries no name of its own, so
# this tries the wire aliases first, then the net's own GetName, then the
# "Net Name" / "Name" properties.  Whatever is still nameless after that is a net
# that gets its name from a power symbol or an off-page connector - those are
# listed with their coordinates in the symbol section, so they can be matched up
# by position.
proc ::mUtilMenu::NetLabel { pNet pNames } {
    if { [llength $pNames] > 0 } {
        return [join [lsort -dictionary $pNames] { = }]
    }

    set lName [::mUtilMenu::CStr $pNet GetName]
    if { $lName ne "" } {
        return $lName
    }

    set lName [::mUtilMenu::PropStrAny $pNet [list "Net Name" "Name"]]
    if { $lName ne "" } {
        return $lName
    }
    return "(unnamed)"
}

# First of several property names that actually carries a value.  Part_Number is
# what this project's designs use; "Part Number" is Cadence's own spelling (see
# capCustomSamples/capGenerateBOM.tcl:119), so both are tried.
proc ::mUtilMenu::PropStrAny { pObj pNames } {
    foreach lName $pNames {
        set lValue [::mUtilMenu::PropStr $pObj $lName]
        if { $lValue ne "" } {
            return $lValue
        }
    }
    return ""
}

proc ::mUtilMenu::CStr { pObj pGetter } {
    set lCStr [DboTclHelper_sMakeCString]
    if { [catch { $pObj $pGetter $lCStr }] } {
        return ""
    }
    return [DboTclHelper_sGetConstCharPtr $lCStr]
}

# Parts placed on one page.  Returns one row per placed instance:
#
#   0 Part Reference   3 source .olb   6 PCB Footprint   9 bounding box, doc units
#   1 Value            4 position      7 Part_Number
#   2 package name     5 pin names     8 Optional
#
# Element 9 is {left top right bottom} off ObjBBoxDoc - the same box element 4
# prints, unrounded.  Only the marker rectangles use it; printing and the
# signature stay on elements 0-8, so adding it did not change what the diff sees.
#
# Collecting and printing are separate because the reference compare needs the
# rows, not the printout.
proc ::mUtilMenu::CollectPageParts { pPage } {
    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    set lIter [$pPage NewPartInstsIter $lStatus]
    set lInst [$lIter NextPartInst $lStatus]

    while { $lInst != $lNullObj } {
        # Only placed instances are real components - drawn instances are
        # hierarchical blocks, which have no Part Reference to report.
        if { [$lInst GetObjectType] == $::DboBaseObject_PLACED_INSTANCE } {
            set lPart [DboPartInstToDboPlacedInst $lInst]

            set lRef [::mUtilMenu::PropStr $lPart "Part Reference"]
            set lVal [::mUtilMenu::PropStr $lPart "Value"]
            set lFp  [::mUtilMenu::PropStr $lPart "PCB Footprint"]
            set lPn  [::mUtilMenu::PropStrAny $lPart [list "Part_Number" "Part Number"]]
            set lOpt [::mUtilMenu::PropStr $lPart "Optional"]
            set lLib [file tail [::mUtilMenu::CStr $lPart GetSourceLibName]]
            set lLoc [::mUtilMenu::ObjLocStr $pPage $lPart $lStatus]

            set lPkg ""
            catch { set lPkg [::mUtilMenu::CStr [$lPart GetPackage $lStatus] GetName] }

            set lPins [list]
            catch {
                set lPinIter [$lPart NewPinsIter $lStatus]
                set lPin     [$lPinIter NextPin $lStatus]
                while { $lPin != $lNullObj } {
                    lappend lPins [::mUtilMenu::CStr $lPin GetPinName]
                    set lPin [$lPinIter NextPin $lStatus]
                }
                catch { delete_DboPartInstPinsIter $lPinIter }
            }

            lappend lRows [list $lRef $lVal $lPkg $lLib $lLoc $lPins $lFp $lPn $lOpt \
                                [::mUtilMenu::ObjBBoxDoc $lPart]]
        }
        set lInst [$lIter NextPartInst $lStatus]
    }

    catch { delete_DboPagePartInstsIter $lIter }
    catch { $lStatus -delete }
    return $lRows
}

# Print what CollectPageParts returned.  Returns the count.
# The property line is printed even when the properties are empty, so every part
# costs the same number of lines and the two dumps stay aligned.
proc ::mUtilMenu::PrintPartRows { pRows } {
    foreach lRow [lsort -dictionary -index 0 $pRows] {
        ::mUtilMenu::Out [format "    %-10s %-12s %-16s %s" \
                  [lindex $lRow 0] [lindex $lRow 2] [lindex $lRow 3] [lindex $lRow 4]]
        ::mUtilMenu::Out [format "               Value: %-16s PCB Footprint: %-16s Part_Number: %-16s Optional: %s" \
                  [::mUtilMenu::OrDash [lindex $lRow 1]] \
                  [::mUtilMenu::OrDash [lindex $lRow 6]] \
                  [::mUtilMenu::OrDash [lindex $lRow 7]] \
                  [::mUtilMenu::OrDash [lindex $lRow 8]]]
        set lPins [lindex $lRow 5]
        if { [llength $lPins] > 0 } {
            ::mUtilMenu::Out "               pins: [join $lPins { }]"
        }
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageParts { pPage } {
    return [::mUtilMenu::PrintPartRows [::mUtilMenu::CollectPageParts $pPage]]
}

#-----------------------------------------------------------------------------
# Reference compare - Refcompare's answer to "what changed between O and N".
#
# O = Design File 1 (old), N = Design File 2 (new), matching the dialog labels.
# Parts are matched by Part Reference; only Value / PCB Footprint / Part_Number /
# pins are compared.  Coordinates are deliberately NOT compared (the question is
# "same part, same data", not "same placement"), and neither are package, source
# library or Optional.
#-----------------------------------------------------------------------------

proc ::mUtilMenu::PartCmpFields { pRow } {
    return [list \
        [list "Value"         [lindex $pRow 1]] \
        [list "PCB Footprint" [lindex $pRow 6]] \
        [list "Part_Number"   [lindex $pRow 7]] \
        [list "pins"          [join [lsort -dictionary [lindex $pRow 5]] { }]]]
}

proc ::mUtilMenu::PartCmpStr { pRow } {
    set lOut [list]
    foreach lField [::mUtilMenu::PartCmpFields $pRow] {
        lappend lOut "[lindex $lField 0]: [::mUtilMenu::OrDash [lindex $lField 1]]"
    }
    return [join $lOut "  "]
}

# Index rows by Part Reference.  A repeated reference on one page is a design
# error, but say so rather than silently dropping one of them.
proc ::mUtilMenu::IndexPartRows { pArrName pRows pSide } {
    upvar 1 $pArrName lArr
    foreach lRow $pRows {
        set lRef [lindex $lRow 0]
        if { $lRef eq "" } {
            continue
        }
        if { [info exists lArr($lRef)] } {
            ::mUtilMenu::Trace "duplicate reference $lRef in $pSide - keeping the first"
            continue
        }
        set lArr($lRef) $lRow
    }
}

# Prints the compare and returns a one-line summary for the message box.
proc ::mUtilMenu::DumpRefCompare { pRowsO pRowsN } {
    variable mRefListMax

    array set lO {}
    array set lN {}
    ::mUtilMenu::IndexPartRows lO $pRowsO "O"
    ::mUtilMenu::IndexPartRows lN $pRowsN "N"

    set lAdd    [list]
    set lRemove [list]
    set lChange [list]

    foreach lRef [lsort -dictionary [array names lN]] {
        if { ![info exists lO($lRef)] } {
            lappend lAdd $lRef
            continue
        }

        set lFieldsO [::mUtilMenu::PartCmpFields $lO($lRef)]
        set lFieldsN [::mUtilMenu::PartCmpFields $lN($lRef)]
        set lDiffs   [list]
        for { set i 0 } { $i < [llength $lFieldsO] } { incr i } {
            set lFO [lindex $lFieldsO $i]
            set lFN [lindex $lFieldsN $i]
            if { [lindex $lFO 1] ne [lindex $lFN 1] } {
                lappend lDiffs [list [lindex $lFO 0] [lindex $lFO 1] [lindex $lFN 1]]
            }
        }
        if { [llength $lDiffs] > 0 } {
            lappend lChange [list $lRef $lDiffs]
        }
    }

    foreach lRef [lsort -dictionary [array names lO]] {
        if { ![info exists lN($lRef)] } {
            lappend lRemove $lRef
        }
    }

    if { [llength $lAdd] == 0 && [llength $lRemove] == 0 && [llength $lChange] == 0 } {
        ::mUtilMenu::Out "    all the same"
        return "all the same"
    }

    if { [llength $lAdd] > 0 } {
        ::mUtilMenu::Out "    Add components ([llength $lAdd]) - in N only"
        foreach lRef $lAdd {
            ::mUtilMenu::Out [format "        %-10s %s" $lRef [::mUtilMenu::PartCmpStr $lN($lRef)]]
        }
    }
    if { [llength $lRemove] > 0 } {
        ::mUtilMenu::Out "    Remove components ([llength $lRemove]) - in O only"
        foreach lRef $lRemove {
            ::mUtilMenu::Out [format "        %-10s %s" $lRef [::mUtilMenu::PartCmpStr $lO($lRef)]]
        }
    }
    # Same reference on both sides but different data - neither an add nor a
    # remove, and it has to be reported or "all the same" would be a lie.
    if { [llength $lChange] > 0 } {
        ::mUtilMenu::Out "    Changed components ([llength $lChange]) - same reference, different data"
        foreach lEntry $lChange {
            ::mUtilMenu::Out [format "        %-10s" [lindex $lEntry 0]]
            foreach lDiff [lindex $lEntry 1] {
                ::mUtilMenu::Out [format "                   %-14s %s -> %s" \
                          [lindex $lDiff 0] \
                          [::mUtilMenu::OrDash [lindex $lDiff 1]] \
                          [::mUtilMenu::OrDash [lindex $lDiff 2]]]
            }
        }
    }

    set lCounts "Add: [llength $lAdd]    Remove: [llength $lRemove]    Changed: [llength $lChange]"
    ::mUtilMenu::Out "    ($lCounts)"

    # The message box gets the counts plus the references themselves, capped so a
    # big delta cannot grow the box off the screen.
    set lChangeRefs [list]
    foreach lEntry $lChange {
        lappend lChangeRefs [lindex $lEntry 0]
    }

    set lSummary $lCounts
    foreach lPair [list [list "Add    " $lAdd] [list "Remove " $lRemove] \
                        [list "Changed" $lChangeRefs]] {
        if { [llength [lindex $lPair 1]] > 0 } {
            append lSummary "\n[lindex $lPair 0] : [::mUtilMenu::RefListStr [lindex $lPair 1] $mRefListMax]"
        }
    }
    return $lSummary
}

#-----------------------------------------------------------------------------
# Full compare - Compare's answer, across all four sections.
#
# Each item is reduced to a one-line signature that includes its position, and
# the two sides are diffed as multisets: a signature present in N but not in O is
# New, one present in O but not in N is Remove.  That is the literal "in B but
# not in A" reading, and it means an item that only moved shows up in both lists
# (the signatures differ).  Refcompare is the one that matches parts by reference
# and reports Changed instead - the two answer different questions.
#-----------------------------------------------------------------------------

# Every Sig proc returns {signature shortName} pairs: the signature drives the
# diff and the Command Window listing, the short name goes in the message box.
proc ::mUtilMenu::PartSig { pRow } {
    set lSig [format "%-10s Value: %-14s PCB Footprint: %-14s Part_Number: %-16s Optional: %-6s pkg: %-10s lib: %-16s %s" \
                  [lindex $pRow 0] \
                  [::mUtilMenu::OrDash [lindex $pRow 1]] \
                  [::mUtilMenu::OrDash [lindex $pRow 6]] \
                  [::mUtilMenu::OrDash [lindex $pRow 7]] \
                  [::mUtilMenu::OrDash [lindex $pRow 8]] \
                  [::mUtilMenu::OrDash [lindex $pRow 2]] \
                  [::mUtilMenu::OrDash [lindex $pRow 3]] \
                  [lindex $pRow 4]]
    set lSig "$lSig  pins: [join [lsort -dictionary [lindex $pRow 5]] { }]"
    return [list $lSig [lindex $pRow 0]]
}

proc ::mUtilMenu::PartSigs { pRows } {
    set lOut [list]
    foreach lRow $pRows {
        lappend lOut [::mUtilMenu::PartSig $lRow]
    }
    return $lOut
}

proc ::mUtilMenu::SymbolSigs { pRows } {
    set lOut [list]
    foreach lRow $pRows {
        lappend lOut [list \
            [format "%-8s %-26s %s" [lindex $lRow 0] \
                 [::mUtilMenu::OrDash [lindex $lRow 1]] [lindex $lRow 2]] \
            "[lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]]"]
    }
    return $lOut
}

# Parts, nets and buses are the categories whose findings get marked on the page,
# so their one-row form is split out (PartSig above, NetSig / BusSig here):
# MarkGeomIndex needs to rebuild the exact same {signature shortName} pair SigDiff
# keys on, and a second copy of the format string would be a silent way for the two
# to drift apart.
proc ::mUtilMenu::NetSig { pRow } {
    set lSegs [lindex $pRow 1]
    return [list \
        [format "%-28s wires: %-3d %s" [lindex $pRow 0] [llength $lSegs] \
             [join $lSegs { }]] \
        [lindex $pRow 0]]
}

proc ::mUtilMenu::NetSigs { pRows } {
    set lOut [list]
    foreach lRow $pRows {
        lappend lOut [::mUtilMenu::NetSig $lRow]
    }
    return $lOut
}

proc ::mUtilMenu::BusSig { pRow } {
    return [list \
        [format "%-26s %-7s %s" [lindex $pRow 0] [lindex $pRow 1] \
             [lindex $pRow 2]] \
        [lindex $pRow 0]]
}

proc ::mUtilMenu::BusSigs { pRows } {
    set lOut [list]
    foreach lRow $pRows {
        lappend lOut [::mUtilMenu::BusSig $lRow]
    }
    return $lOut
}

# {signature shortName} pair -> the doc-unit quads behind it, for one side of the
# compare.  A quad is {x1 y1 x2 y2} for a wire and {left top right bottom} for a
# part's bounding box.  Built off the rows rather than off the signature strings,
# so the coordinates the markers use are the objects' own integers and never the
# two-decimal text in the signature.
#
# Rows that share a signature share an entry.  That only happens when two objects
# print identically, in which case the diff already treats them as the same thing
# and marking either one is the same answer.
proc ::mUtilMenu::MarkGeomIndex { pArrName pRows pSigProc pGeomIndex } {
    upvar 1 $pArrName lArr

    foreach lRow $pRows {
        set lKey   [$pSigProc $lRow]
        set lGeoms [lindex $lRow $pGeomIndex]

        # Part and bus rows carry a single quad, net rows carry a list of them -
        # wrap the single one so both look the same to the caller.  A list of quads
        # has lists as its elements; a bare quad has scalars.
        if { [llength $lGeoms] == 4 && [llength [lindex $lGeoms 0]] == 1 } {
            set lGeoms [list $lGeoms]
        }
        if { [llength $lGeoms] > 0 && ![info exists lArr($lKey)] } {
            set lArr($lKey) $lGeoms
        }
    }
}

# Multiset difference, so two identical items on one page do not collapse into
# one.  Returns {onlyInN onlyInO}, each a list of {signature shortName} pairs.
proc ::mUtilMenu::SigDiff { pSigsO pSigsN } {
    array set lO {}
    array set lN {}
    foreach lPair $pSigsO {
        if { [info exists lO($lPair)] } { incr lO($lPair) } else { set lO($lPair) 1 }
    }
    foreach lPair $pSigsN {
        if { [info exists lN($lPair)] } { incr lN($lPair) } else { set lN($lPair) 1 }
    }

    set lNew [list]
    set lRem [list]
    foreach lPair [lsort -dictionary [array names lN]] {
        set lHad 0
        if { [info exists lO($lPair)] } { set lHad $lO($lPair) }
        for { set i $lHad } { $i < $lN($lPair) } { incr i } { lappend lNew $lPair }
    }
    foreach lPair [lsort -dictionary [array names lO]] {
        set lHas 0
        if { [info exists lN($lPair)] } { set lHas $lN($lPair) }
        for { set i $lHas } { $i < $lO($lPair) } { incr i } { lappend lRem $lPair }
    }
    return [list $lNew $lRem]
}

# Prints the compare and returns the message-box text.
#
# Nets and Buses are reported in full - they are the categories whose New entries
# get drawn on the page, so a "... (+n more, see Command Window)" in the report
# would not line up with what is on screen.  Parts and Symbols stay capped, at
# mRefListMax.
#
# The New entries of the marked categories also fill mMarkSegs (nets, buses -> a
# line per wire) and mMarkBoxes (parts -> a rectangle round the bounding box) on
# the way past, which is what DrawCompareMarkerLine draws.  Only New, not Remove:
# a Remove is something (O) has and (N) has not, so there is nothing on (N)'s page
# to mark.
proc ::mUtilMenu::DumpFullCompare { pDictO pDictN } {
    variable mMarkSegs
    variable mMarkBoxes
    variable mRefListMax

    # {name dictKey sigsProc oneSigProc geomIndex listMax markKind}
    # geomIndex -1 / markKind "" = this category is not marked on the page.
    set lCats [list \
        [list "Parts"   parts   ::mUtilMenu::PartSigs   ::mUtilMenu::PartSig  9 $mRefListMax box] \
        [list "Symbols" symbols ::mUtilMenu::SymbolSigs ""                   -1 $mRefListMax ""] \
        [list "Nets"    nets    ::mUtilMenu::NetSigs    ::mUtilMenu::NetSig   2 0            line] \
        [list "Buses"   buses   ::mUtilMenu::BusSigs    ::mUtilMenu::BusSig   3 0            line]]

    set lNewByCat [list]
    set lRemByCat [list]
    set lAny 0
    set mMarkSegs  [list]
    set mMarkBoxes [list]

    foreach lCat $lCats {
        set lName [lindex $lCat 0]
        set lKey  [lindex $lCat 1]
        set lSigs [lindex $lCat 2]

        set lDiff [::mUtilMenu::SigDiff \
                       [$lSigs [dict get $pDictO $lKey]] \
                       [$lSigs [dict get $pDictN $lKey]]]
        lappend lNewByCat [list $lName [lindex $lDiff 0] [lindex $lCat 5]]
        lappend lRemByCat [list $lName [lindex $lDiff 1] [lindex $lCat 5]]
        if { [llength [lindex $lDiff 0]] > 0 || [llength [lindex $lDiff 1]] > 0 } {
            set lAny 1
        }

        # New entries of a marked category -> markers, keyed on the same pair
        # SigDiff just handed back.
        if { [lindex $lCat 4] >= 0 && [llength [lindex $lDiff 0]] > 0 } {
            array unset lIdx
            array set   lIdx {}
            ::mUtilMenu::MarkGeomIndex lIdx [dict get $pDictN $lKey] \
                [lindex $lCat 3] [lindex $lCat 4]

            foreach lPair [lindex $lDiff 0] {
                if { ![info exists lIdx($lPair)] } {
                    ::mUtilMenu::Trace "no coordinates for new $lName [lindex $lPair 1] - not marked"
                    continue
                }
                foreach lGeom $lIdx($lPair) {
                    set lEntry [linsert $lGeom 0 "$lName [lindex $lPair 1]"]
                    if { [lindex $lCat 6] eq "box" } {
                        lappend mMarkBoxes $lEntry
                    } else {
                        lappend mMarkSegs  $lEntry
                    }
                }
            }
        }
    }

    if { !$lAny } {
        ::mUtilMenu::Out "    all the same"
        return "all the same"
    }

    set lMsg ""
    foreach lBucket [list [list "New" $lNewByCat] [list "Remove" $lRemByCat]] {
        set lHead  [lindex $lBucket 0]

        # Skip the whole heading when that side has nothing.
        set lCount 0
        foreach lEntry [lindex $lBucket 1] {
            incr lCount [llength [lindex $lEntry 1]]
        }
        if { $lCount == 0 } {
            continue
        }

        ::mUtilMenu::Out "    [string toupper $lHead]:"
        append lMsg "$lHead:\n"

        foreach lEntry [lindex $lBucket 1] {
            set lName  [lindex $lEntry 0]
            set lPairs [lindex $lEntry 1]
            set lMax   [lindex $lEntry 2]
            if { [llength $lPairs] == 0 } {
                continue
            }
            ::mUtilMenu::Out "      $lName ([llength $lPairs])"
            set lShort [list]
            foreach lPair $lPairs {
                ::mUtilMenu::Out "        [lindex $lPair 0]"
                lappend lShort [lindex $lPair 1]
            }
            append lMsg "  [format %-8s $lName] ([llength $lPairs]) : [::mUtilMenu::RefListStr $lShort $lMax]\n"
        }
    }
    return [string trimright $lMsg "\n"]
}

# Comma-separated, because a symbol's short name is "OFFPAGE ADDR[0..7]" - space
# separation would run two of them together.
#
# pMax 0 (or less) means no cap - list everything.  That is what Nets and Buses
# pass, because their New entries are also drawn on the page and the report has to
# name every line the user is looking at.
proc ::mUtilMenu::RefListStr { pRefs pMax } {
    if { $pMax <= 0 || [llength $pRefs] <= $pMax } {
        return [join $pRefs {, }]
    }
    return "[join [lrange $pRefs 0 [expr { $pMax - 1 }]] {, }], ... (+[expr { [llength $pRefs] - $pMax }] more, see Command Window)"
}

# Off-page connectors, power/ground symbols and hierarchical ports, with their
# names and positions.  Returns rows of {type name position}.
#
# Capture keeps power and ground in the same bucket - both are DBGLOBAL objects
# off NewGlobalsIter (orPrmDboStreamer.tcl:1721,1870) - so there is no flag to
# separate them; the name is what tells +3V3 from GND.  They are tagged GLOBAL
# here for that reason.
proc ::mUtilMenu::CollectPageSymbols { pPage } {
    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    # Off-page connectors.  capProcessDRC.tcl:81 and capDesignUtil.tcl:420 pass
    # IterDefs_ALL, orPrmDboStreamer.tcl:1900 passes nothing - try two args, then
    # one.
    set lIter ""
    if { [catch { set lIter [$pPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL] }] } {
        catch { set lIter [$pPage NewOffPageConnectorsIter $lStatus] }
    }
    if { $lIter ne "" } {
        set lObj [$lIter NextOffPageConnector $lStatus]
        while { $lObj != $lNullObj } {
            lappend lRows [list OFFPAGE [::mUtilMenu::CStr $lObj GetName] \
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus]]
            set lObj [$lIter NextOffPageConnector $lStatus]
        }
        catch { delete_DboPageOffPageConnectorsIter $lIter }
    }

    # Power / ground symbols.
    if { ![catch { set lIter [$pPage NewGlobalsIter $lStatus] }] } {
        set lObj [$lIter NextGlobal $lStatus]
        while { $lObj != $lNullObj } {
            set lName [::mUtilMenu::CStr $lObj GetName]
            if { $lName eq "" } {
                # A power symbol's net name also lives in its Value property.
                set lName [::mUtilMenu::PropStrAny $lObj [list "Value" "Name"]]
            }
            lappend lRows [list GLOBAL $lName \
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus]]
            set lObj [$lIter NextGlobal $lStatus]
        }
        catch { delete_DboPageGlobalsIter $lIter }
    }

    # Hierarchical ports.
    if { ![catch { set lIter [$pPage NewPortsIter $lStatus] }] } {
        set lObj [$lIter NextPort $lStatus]
        while { $lObj != $lNullObj } {
            lappend lRows [list PORT [::mUtilMenu::CStr $lObj GetName] \
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus]]
            set lObj [$lIter NextPort $lStatus]
        }
        catch { delete_DboPagePortsIter $lIter }
    }

    catch { $lStatus -delete }
    return $lRows
}

# Sort by name inside type: stable lsort, so the name pass runs first.
proc ::mUtilMenu::PrintSymbolRows { pRows } {
    foreach lRow [lsort -dictionary -index 0 [lsort -dictionary -index 1 $pRows]] {
        ::mUtilMenu::Out [format "    %-8s %-26s %s" \
                  [lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]] \
                  [lindex $lRow 2]]
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageSymbols { pPage } {
    return [::mUtilMenu::PrintSymbolRows [::mUtilMenu::CollectPageSymbols $pPage]]
}

# Bus and bundle wires.  Returns rows of {name type endpoints docSeg}.
#
# Element 3 is the same endpoints as one {x1 y1 x2 y2} doc-unit quad, for the
# marker lines; printing and the signature stay on elements 0-2.
#
# A bus is not a page object of its own - it is a wire whose object type is
# WIRE_BUS (WIRE_BUNDLE for bundles), the same test capObjectAlignment.tcl:371-373
# makes.  The constants are checked with "info exists" so a missing one degrades
# to "not a bus" instead of killing the whole loop.
proc ::mUtilMenu::CollectPageBuses { pPage } {
    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    set lIter [$pPage NewWiresIter $lStatus]
    set lWire [$lIter NextWire $lStatus]

    while { $lWire != $lNullObj } {
        set lOT ""
        catch { set lOT [$lWire GetObjectType] }

        set lType ""
        if { [info exists ::DboBaseObject_WIRE_BUS] \
             && $lOT eq $::DboBaseObject_WIRE_BUS } {
            set lType BUS
        } elseif { [info exists ::DboBaseObject_WIRE_BUNDLE] \
                   && $lOT eq $::DboBaseObject_WIRE_BUNDLE } {
            set lType BUNDLE
        }

        if { $lType ne "" } {
            set lNames [::mUtilMenu::WireAliases $lWire $lStatus]
            if { [llength $lNames] == 0 } {
                set lLabel "(unnamed)"
            } else {
                set lLabel [join [lsort -dictionary $lNames] { = }]
            }
            lappend lRows [list $lLabel $lType \
                                [::mUtilMenu::WireSegStr $pPage $lWire $lStatus] \
                                [::mUtilMenu::WireSegDoc $lWire $lStatus]]
        }
        set lWire [$lIter NextWire $lStatus]
    }

    catch { delete_DboPageWiresIter $lIter }
    catch { $lStatus -delete }
    return $lRows
}

# Name is the primary key, so it sorts last (stable lsort).
proc ::mUtilMenu::PrintBusRows { pRows } {
    foreach lRow [lsort -dictionary -index 0 [lsort -dictionary -index 2 $pRows]] {
        ::mUtilMenu::Out [format "    %-26s %-7s %s" \
                  [lindex $lRow 0] [lindex $lRow 1] [lindex $lRow 2]]
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageBuses { pPage } {
    return [::mUtilMenu::PrintBusRows [::mUtilMenu::CollectPageBuses $pPage]]
}

# Nets on one page.  Returns rows of {name {endpoints...} {docSegs...}}.
#
# Element 2 is the same wires again as {x1 y1 x2 y2} doc-unit quads, in the same
# order as element 1 before it was sorted for printing.  Only the marker lines use
# it; printing and the signatures stay on elements 0 and 1.
proc ::mUtilMenu::CollectPageNets { pPage } {
    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    set lNetsIter [::mUtilMenu::NextIterName Nets]
    DboPageNetsIter $lNetsIter $pPage $::IterDefs_ALL
    set lNet [$lNetsIter NextNet $lStatus]

    while { $lNet != $lNullObj } {
        set lNames [list]
        set lSegs  [list]
        set lDocs  [list]

        # Method form of the wires iterator, as in capDRC/capOverlapWires.tcl:172.
        set lWiresIter [$lNet NewWiresIter $lStatus]
        set lWire      [$lWiresIter NextWire $lStatus]
        while { $lWire != $lNullObj } {
            lappend lSegs [::mUtilMenu::WireSegStr $pPage $lWire $lStatus]
            set lDoc [::mUtilMenu::WireSegDoc $lWire $lStatus]
            if { [llength $lDoc] == 4 } {
                lappend lDocs $lDoc
            }
            foreach lName [::mUtilMenu::WireAliases $lWire $lStatus] {
                if { [lsearch -exact $lNames $lName] == -1 } {
                    lappend lNames $lName
                }
            }
            set lWire [$lWiresIter NextWire $lStatus]
        }
        catch { delete_DboNetWiresIter $lWiresIter }

        lappend lRows [list [::mUtilMenu::NetLabel $lNet $lNames] \
                            [lsort -dictionary $lSegs] \
                            $lDocs]

        set lNet [$lNetsIter NextNet $lStatus]
    }

    ::mUtilMenu::DropIter $lNetsIter
    catch { $lStatus -delete }
    return $lRows
}

proc ::mUtilMenu::PrintNetRows { pRows } {
    foreach lRow [lsort -dictionary -index 0 $pRows] {
        set lSegs [lindex $lRow 1]
        ::mUtilMenu::Out [format "    %-28s wires: %d" [lindex $lRow 0] [llength $lSegs]]
        foreach lSeg $lSegs {
            ::mUtilMenu::Out "        wire $lSeg"
        }
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageNets { pPage } {
    return [::mUtilMenu::PrintNetRows [::mUtilMenu::CollectPageNets $pPage]]
}

# Look one page up by {schematic page} name and return {schematicObj pageObj}.
# The walk is the same as GetDesignPages; both objects belong to the design, not
# to the iterators, so they stay valid after those are deleted.
#
# The schematic comes back as well because renaming a page is done through it -
# DboSchematic::Rename(pObj newName) - there being no SetName on DboPage itself
# (checked against orDb_Dll_Tcl64.dll: it has DboPage_GetName and
# DboPage_MarkModified but no DboPage_SetName).
proc ::mUtilMenu::FindPageObjs { pDsnPath pSchName pPageName } {
    set lNullObj NULL
    set lFound   $lNullObj
    set lFoundSch $lNullObj

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession

    set lStatus [DboState]
    set lPath   [DboTclHelper_sMakeCString [file normalize $pDsnPath]]
    set lDesign [$lSession GetDesignAndSchematics $lPath $lStatus]

    if { $lDesign == $lNullObj } {
        catch { $lStatus -delete }
        error "design not found in session"
    }

    set lSchIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
    set lView    [$lSchIter NextView $lStatus]

    while { $lView != $lNullObj && $lFound == $lNullObj } {
        set lSch [DboViewToDboSchematic $lView]
        if { [::mUtilMenu::CStr $lSch GetName] eq $pSchName } {
            set lPagesIter [$lSch NewPagesIter $lStatus]
            set lPage      [$lPagesIter NextPage $lStatus]
            while { $lPage != $lNullObj } {
                if { [::mUtilMenu::CStr $lPage GetName] eq $pPageName } {
                    set lFound    $lPage
                    set lFoundSch $lSch
                    break
                }
                set lPage [$lPagesIter NextPage $lStatus]
            }
            catch { delete_DboSchematicPagesIter $lPagesIter }
        }
        if { $lFound == $lNullObj } {
            set lView [$lSchIter NextView $lStatus]
        }
    }

    catch { delete_DboLibViewsIter $lSchIter }
    catch { $lStatus -delete }

    if { $lFound == $lNullObj } {
        error "page not found: $pSchName / $pPageName"
    }
    return [list $lFoundSch $lFound]
}

proc ::mUtilMenu::FindPage { pDsnPath pSchName pPageName } {
    return [lindex [::mUtilMenu::FindPageObjs $pDsnPath $pSchName $pPageName] 1]
}

# Dump one page.  pWhat selects the sections: any of parts / symbols / nets /
# buses - Refcompare passes just "parts".  Returns a dict of the collected rows
# (parts/symbols/nets/buses, empty list for a section that was not asked for) so
# the caller can compare them without walking the design a second time.
proc ::mUtilMenu::DumpPageInfo { pDsnPath pSchName pPageName \
                                 {pWhat {parts symbols nets buses}} } {
    set lPage   [::mUtilMenu::FindPage $pDsnPath $pSchName $pPageName]
    set lTotals [list]
    set lOut    [list parts [list] symbols [list] nets [list] buses [list]]

    if { [lsearch -exact $pWhat parts] != -1 } {
        ::mUtilMenu::Out "  Parts"
        set lRows [::mUtilMenu::CollectPageParts $lPage]
        set lOut  [dict replace $lOut parts $lRows]
        lappend lTotals "[::mUtilMenu::PrintPartRows $lRows] part(s)"
    }
    if { [lsearch -exact $pWhat symbols] != -1 } {
        ::mUtilMenu::Out "  Off-Page / Power / Ports"
        set lRows [::mUtilMenu::CollectPageSymbols $lPage]
        set lOut  [dict replace $lOut symbols $lRows]
        lappend lTotals "[::mUtilMenu::PrintSymbolRows $lRows] symbol(s)"
    }
    if { [lsearch -exact $pWhat nets] != -1 } {
        ::mUtilMenu::Out "  Nets"
        set lRows [::mUtilMenu::CollectPageNets $lPage]
        set lOut  [dict replace $lOut nets $lRows]
        lappend lTotals "[::mUtilMenu::PrintNetRows $lRows] net(s)"
    }
    if { [lsearch -exact $pWhat buses] != -1 } {
        ::mUtilMenu::Out "  Buses"
        set lRows [::mUtilMenu::CollectPageBuses $lPage]
        set lOut  [dict replace $lOut buses $lRows]
        lappend lTotals "[::mUtilMenu::PrintBusRows $lRows] bus wire(s)"
    }
    ::mUtilMenu::Out "  ([join $lTotals {, }])"

    return $lOut
}

# Put a {schematicName pageName} list into mPageSortMode order.
proc ::mUtilMenu::SortPages { pPages } {
    variable mPageSortMode

    # lsort is a stable merge sort, so sorting on the secondary key (page) first
    # and the primary key (schematic) second gives schematic-then-page order.
    switch -- $mPageSortMode {
        dictionary {
            return [lsort -dictionary -index 0 [lsort -dictionary -index 1 $pPages]]
        }
        ascii {
            return [lsort -ascii -index 0 [lsort -ascii -index 1 $pPages]]
        }
        dbreverse {
            return [lreverse $pPages]
        }
        default {
            return $pPages
        }
    }
}

# Diagnostic: dump one design's pages in all four orders so they can be held up
# against the PROJECT_MANAGER_VIEW tree.  Run in the Command Window, e.g.
#   ::mUtilMenu::DumpPages {G:/Project/.../board.dsn}
proc ::mUtilMenu::DumpPages { pDsnPath } {
    variable mPageSortMode

    set lRaw  [::mUtilMenu::GetDesignPages $pDsnPath]
    set lSave $mPageSortMode
    foreach lMode { dborder dbreverse dictionary ascii } {
        set mPageSortMode $lMode
        ::mUtilMenu::Out "--- $lMode ---"
        foreach lPair [::mUtilMenu::SortPages $lRaw] {
            ::mUtilMenu::Out "    [::mUtilMenu::PageLabel $lPair]"
        }
    }
    set mPageSortMode $lSave
}

#-----------------------------------------------------------------------------
# Page name mapping - which of column B's pages also exist in column A.
#
# Page names in these designs carry markers ("*PAGE1", "--PAGE1", "~PAGE1") that
# say something about the page's state, not about which page it is.  So the
# compare runs on the name with those leading characters removed; what is left
# has to match exactly (case included).
#-----------------------------------------------------------------------------

# Drop the leading marker characters off one page name.  Only the front is
# stripped - a marker inside a name is part of the name.
proc ::mUtilMenu::StripPageNamePrefix { pName } {
    variable mPageNamePrefixChars
    return [string trim [string trimleft $pName $mPageNamePrefixChars]]
}

# The key a page is matched on: its name with the leading markers removed.  The
# schematic a page sits in is deliberately not part of it, because the two
# designs are free to have their schematics named differently.
proc ::mUtilMenu::PageKey { pPair } {
    return [::mUtilMenu::StripPageNamePrefix [lindex $pPair 1]]
}

# The leading slice two keys have to share to count as similar.
proc ::mUtilMenu::PageKeyHead { pKey } {
    variable mPageSimilarChars
    return [string range $pKey 0 [expr { $mPageSimilarChars - 1 }]]
}

# Pair column A's pages up with column B's, in two passes:
#
#   exact    the stripped names are identical, case included
#   similar  they are not, but their first mPageSimilarChars characters are
#
# Both passes are greedy and first-come, and a page can only be claimed once - so
# two pages in A that strip down to the same name are matched by the two pages in
# B that do, one each, rather than both piling onto the first.
#
# Returns a dict:
#   marksA  one status per page of pPagesA - exact / similar / none
#   marksB  the same for pPagesB
#   links   the pairs themselves, {indexA indexB exact|similar}
#
# BuildPageColumn draws everything that is not "exact" in red; DrawPageLinks
# turns links into a solid (exact) or dashed (similar) line across the gap
# between the two columns.  Anything left "none" gets no line - there is nothing
# on the other side to draw to.
proc ::mUtilMenu::Page_name_mapping { pPagesA pPagesB } {
    set lKeysA [list]
    set lKeysB [list]
    set lMarksA [list]
    set lMarksB [list]

    foreach lPair $pPagesA {
        lappend lKeysA  [::mUtilMenu::PageKey $lPair]
        lappend lMarksA none
    }
    foreach lPair $pPagesB {
        lappend lKeysB  [::mUtilMenu::PageKey $lPair]
        lappend lMarksB none
    }

    set lLinks [list]

    # Pass 1 - exact.  lFreeA holds, per key, the A indices not yet claimed, in
    # column order; taking the first of them is what makes duplicates pair up one
    # for one instead of all landing on the same page.
    array set lFreeA {}
    for { set i 0 } { $i < [llength $lKeysA] } { incr i } {
        set lKey [lindex $lKeysA $i]
        if { $lKey ne "" } {
            lappend lFreeA($lKey) $i
        }
    }

    for { set j 0 } { $j < [llength $lKeysB] } { incr j } {
        set lKey [lindex $lKeysB $j]
        if { $lKey eq "" || ![info exists lFreeA($lKey)] \
             || [llength $lFreeA($lKey)] == 0 } {
            continue
        }
        set i           [lindex $lFreeA($lKey) 0]
        set lFreeA($lKey) [lrange $lFreeA($lKey) 1 end]

        lset lMarksA $i exact
        lset lMarksB $j exact
        lappend lLinks [list $i $j exact]
    }

    # Pass 2 - similar, over what pass 1 left alone on both sides.
    array set lHeadA {}
    for { set i 0 } { $i < [llength $lKeysA] } { incr i } {
        set lKey [lindex $lKeysA $i]
        if { $lKey ne "" && [lindex $lMarksA $i] eq "none" } {
            lappend lHeadA([::mUtilMenu::PageKeyHead $lKey]) $i
        }
    }

    for { set j 0 } { $j < [llength $lKeysB] } { incr j } {
        set lKey [lindex $lKeysB $j]
        if { $lKey eq "" || [lindex $lMarksB $j] ne "none" } {
            continue
        }
        set lHead [::mUtilMenu::PageKeyHead $lKey]
        if { ![info exists lHeadA($lHead)] || [llength $lHeadA($lHead)] == 0 } {
            continue
        }
        set i             [lindex $lHeadA($lHead) 0]
        set lHeadA($lHead) [lrange $lHeadA($lHead) 1 end]

        lset lMarksA $i similar
        lset lMarksB $j similar
        lappend lLinks [list $i $j similar]
    }

    return [dict create marksA $lMarksA marksB $lMarksB links $lLinks]
}

# Build one column of checkbuttons into pFrame - no header and no scrollbox of
# its own any more: both columns live in the one canvas ShowPageSelector builds,
# which is what makes it possible to draw the mapping in the gap between them.
#
# pArrName is the bare name of the checkbox array ("mPageSelA" / "mPageSelB").
# pMarks is this column's half of Page_name_mapping, or {} for a column that is
# not being mapped; anything other than "exact" is drawn in red.
#
# Returns the checkbutton widget paths, one per page and in page order, so
# DrawPageLinks can ask Tk where each of them ended up.
proc ::mUtilMenu::BuildPageColumn { pFrame pPages pArrName {pMarks {}} } {
    set lCbs [list]

    if { [llength $pPages] == 0 } {
        label $pFrame.empty -text "(no pages found)" -anchor w -foreground gray40
        pack $pFrame.empty -side top -fill x -padx 4 -pady 2
        return $lCbs
    }

    # Only label the schematic when there is more than one, otherwise the
    # heading is just noise.  Bare page names repeat across schematics, so
    # without this the two columns would be ambiguous on real designs.
    # (foreach rather than lmap - lmap needs Tcl 8.6.)
    set lSchNames [list]
    foreach lPair $pPages { lappend lSchNames [lindex $lPair 0] }
    set lSchCount [llength [lsort -unique $lSchNames]]

    set lPrevSch ""
    set i 0
    foreach lPair $pPages {
        set lSch  [lindex $lPair 0]
        set lPage [lindex $lPair 1]

        if { $lSchCount > 1 && $lSch ne $lPrevSch } {
            label $pFrame.sch$i -text $lSch -anchor w -foreground gray30
            pack $pFrame.sch$i -side top -fill x -padx 4 -pady {4 0}
            set lPrevSch $lSch
        }

        set ::mUtilMenu::${pArrName}($i) 0
        checkbutton $pFrame.cb$i -text $lPage -anchor w \
            -variable ::mUtilMenu::${pArrName}($i)

        # activeforeground as well, or the red would drop back to black while the
        # mouse is over the checkbutton.
        set lMark [lindex $pMarks $i]
        if { $lMark ne "" && $lMark ne "exact" } {
            $pFrame.cb$i configure -foreground red -activeforeground red
        }

        set lIndent [expr { $lSchCount > 1 ? 18 : 4 }]
        pack $pFrame.cb$i -side top -fill x -padx [list $lIndent 4]

        lappend lCbs $pFrame.cb$i
        incr i
    }
    return $lCbs
}

# Draw the mapping into the gap between the two columns: one line per link, from
# the right edge of column A at the vertical middle of its checkbutton to the
# left edge of column B at the middle of its own.  Solid for an exact name match,
# dashed for a similar one.
#
# The line ends are read off the widgets themselves rather than computed from a
# row height, so schematic headings, a wrapped page name or a different font all
# stay lined up for free.  "winfo y" is relative to the column frame, and each
# column frame sits at canvas y=0, so a widget's y is already a canvas y.
#
# Everything drawn is tagged pagelink and deleted first, which is what makes this
# safe to call again on every <Configure>.
proc ::mUtilMenu::DrawPageLinks { } {
    variable mPageCanvas
    variable mPageCbsA
    variable mPageCbsB
    variable mPageLinks
    variable mPageLinkX1
    variable mPageLinkX2
    variable mLinkColorExact
    variable mLinkColorSimilar
    variable mPageLinksReady

    if { $mPageCanvas eq "" || ![winfo exists $mPageCanvas] } {
        return 0
    }

    # Not ready yet: the columns can already be scrolled, they just have no lines
    # across them.  Keeping the scrollregion current is the one thing that still
    # has to happen, because the columns are what it is measured from.
    if { !$mPageLinksReady } {
        catch { $mPageCanvas configure -scrollregion [$mPageCanvas bbox all] }
        return 0
    }

    $mPageCanvas delete pagelink

    set lDrawn 0
    foreach lLink $mPageLinks {
        set lCbA [lindex $mPageCbsA [lindex $lLink 0]]
        set lCbB [lindex $mPageCbsB [lindex $lLink 1]]
        if { $lCbA eq "" || $lCbB eq "" \
             || ![winfo exists $lCbA] || ![winfo exists $lCbB] } {
            continue
        }

        set lY1 [expr { [winfo y $lCbA] + [winfo height $lCbA] / 2 }]
        set lY2 [expr { [winfo y $lCbB] + [winfo height $lCbB] / 2 }]

        if { [lindex $lLink 2] eq "exact" } {
            $mPageCanvas create line $mPageLinkX1 $lY1 $mPageLinkX2 $lY2 \
                -fill $mLinkColorExact -width 1 -tags pagelink
        } else {
            $mPageCanvas create line $mPageLinkX1 $lY1 $mPageLinkX2 $lY2 \
                -fill $mLinkColorSimilar -width 1 -dash {4 3} -tags pagelink
        }
        incr lDrawn
    }

    catch { $mPageCanvas configure -scrollregion [$mPageCanvas bbox all] }
    return $lDrawn
}

# DrawPageLinks with the geometry settled first, and the one place that opens the
# gate: everything before this draws no lines at all, so they all appear together
# once the window is finished rather than being drawn early and then shifting as
# Tk lays the rest of the window out.  This is what the end of ShowPageSelector
# and any later "the lines look wrong" call should use; DrawPageLinks itself
# deliberately does not update, because it also runs from <Configure>, where
# updating inside the handler would re-enter the layout.
proc ::mUtilMenu::RedrawPageLinks { } {
    variable mPageCanvas
    variable mPageLinksReady

    if { $mPageCanvas eq "" || ![winfo exists $mPageCanvas] } {
        return 0
    }
    update idletasks
    set mPageLinksReady 1
    return [::mUtilMenu::DrawPageLinks]
}

proc ::mUtilMenu::ClosePageSelector { } {
    variable mPagesWin
    variable mPageCanvas
    variable mPageLinksReady

    catch { destroy $mPagesWin }
    # The canvas went with the window - forget it, so a stray <Configure> or a
    # DrawPageLinks from the Command Window cannot address a dead widget.
    set mPageCanvas     ""
    set mPageLinksReady 0
}

# Returns the pages the user ticked, as {schematicName pageName} pairs.
# Nothing calls this yet - it is what a real compare would consume.
proc ::mUtilMenu::GetCheckedPages { pWhich } {
    variable mPagesA
    variable mPagesB

    if { $pWhich eq "A" } {
        set lPages $mPagesA ; set lArr mPageSelA
    } else {
        set lPages $mPagesB ; set lArr mPageSelB
    }

    set lOut [list]
    for { set i 0 } { $i < [llength $lPages] } { incr i } {
        if { [info exists ::mUtilMenu::${lArr}($i)] \
             && [set ::mUtilMenu::${lArr}($i)] } {
            lappend lOut [lindex $lPages $i]
        }
    }
    return $lOut
}

#-----------------------------------------------------------------------------
# Result window - where Compare / Refcompare put their report.
#
# capDisplayMessageBox is modal and its text cannot be selected, so there was no
# way to get the report out of it.  This is a read-only text widget: -state
# disabled blocks editing but leaves the usual selection bindings alone, so a
# mouse drag plus Ctrl-C works (checked against the Tk 8.6.5 that Capture ships).
# Select All / Copy buttons are there for the same job without the drag.
#-----------------------------------------------------------------------------

proc ::mUtilMenu::CloseResultWindow { } {
    variable mResultWin
    catch { destroy $mResultWin }
}

proc ::mUtilMenu::SelectAllResultText { } {
    variable mResultWin
    set lTxt $mResultWin.body.txt
    if { ![winfo exists $lTxt] } {
        return
    }
    $lTxt tag remove sel 1.0 end
    $lTxt tag add sel 1.0 end-1c
    focus $lTxt
}

# Copy the selection, or the whole report when nothing is selected - that is the
# common case ("give me all of it") and it saves a Select All click.
proc ::mUtilMenu::CopyResultText { } {
    variable mResultWin
    set lTxt $mResultWin.body.txt
    if { ![winfo exists $lTxt] } {
        return
    }
    if { [catch { set lStr [$lTxt get sel.first sel.last] }] } {
        set lStr [$lTxt get 1.0 end-1c]
    }
    clipboard clear  -displayof $mResultWin
    clipboard append -displayof $mResultWin $lStr
}

# pTitle is the window banner, pText the whole report.
proc ::mUtilMenu::ShowResultWindow { pTitle pText } {
    variable mResultWin

    # Should not happen - the page selector is a Tk window, so Tk is already up -
    # but fall back to the old message box rather than losing the report.
    if { [catch { package require Tk }] } {
        catch { capDisplayMessageBox $pText $pTitle }
        return
    }
    ::mUtilMenu::HideTkRoot

    # Rebuild every time, so a second Compare replaces the old report instead of
    # appending to it or hiding behind it.
    catch { destroy $mResultWin }
    toplevel $mResultWin
    wm title $mResultWin $pTitle
    wm protocol $mResultWin WM_DELETE_WINDOW "::mUtilMenu::CloseResultWindow"
    catch { SetAppWindowAsParent [expr { [winfo id $mResultWin] }] }

    set lBody $mResultWin.body
    frame $lBody -padx 8 -pady 8
    pack $lBody -side top -fill both -expand 1

    # Fixed-width font and -wrap none: every line in the report is column-aligned
    # with format, and either wrapping or a proportional font would break the
    # columns.  Hence the horizontal scrollbar as well.
    text $lBody.txt -wrap none -width 110 -height 30 -font TkFixedFont \
        -borderwidth 1 -relief sunken \
        -xscrollcommand "$lBody.sbx set" -yscrollcommand "$lBody.sby set"
    scrollbar $lBody.sby -orient vertical   -command "$lBody.txt yview"
    scrollbar $lBody.sbx -orient horizontal -command "$lBody.txt xview"

    grid $lBody.txt -row 0 -column 0 -sticky nsew
    grid $lBody.sby -row 0 -column 1 -sticky ns
    grid $lBody.sbx -row 1 -column 0 -sticky ew
    grid columnconfigure $lBody 0 -weight 1
    grid rowconfigure    $lBody 0 -weight 1

    $lBody.txt insert end $pText
    $lBody.txt mark set insert 1.0
    $lBody.txt configure -state disabled

    set lBtns $mResultWin.btns
    frame $lBtns -padx 8
    pack $lBtns -side bottom -fill x
    button $lBtns.close  -text "Close"      -width 12 \
        -command "::mUtilMenu::CloseResultWindow"
    button $lBtns.copy   -text "Copy"       -width 12 \
        -command "::mUtilMenu::CopyResultText"
    button $lBtns.selall -text "Select All" -width 12 \
        -command "::mUtilMenu::SelectAllResultText"
    # -side right packs right-to-left: Select All | Copy | Close on screen.
    pack $lBtns.close  -side right -padx {6 0} -pady {4 10}
    pack $lBtns.copy   -side right -padx {6 0} -pady {4 10}
    pack $lBtns.selall -side right          -pady {4 10}

    # break, so the widget's own class binding for the same key does not also run.
    bind $lBody.txt <Control-a> "::mUtilMenu::SelectAllResultText ; break"
    bind $lBody.txt <Control-c> "::mUtilMenu::CopyResultText ; break"
    bind $mResultWin <Escape>   "::mUtilMenu::CloseResultWindow"

    focus $lBody.txt
    return
}

#-----------------------------------------------------------------------------
# Drawing on a page - the one thing in this file that writes to a design.
#
# The call that puts a line into an OrCAD page is DboPage::NewGraphicLineInst:
#
#   $lPage NewGraphicLineInst $lStatus $ptStart $ptEnd $ptLocation $rotation ?nId?
#
# It returns a DboGraphicLineInst.  Colour comes off its DboGraphicInstance base
# (SetColor), width and style off the line itself (SetLineWidth / SetLineStyle).
# Verified against orDb_Dll_Tcl64.dll, which carries both the SWIG argument list
# above and Cadence's own "write a design back out as Tcl" template:
#
#   set mGraphicLineInst [$mPage NewGraphicLineInst $mStatus $pStart $pEnd $pLocation <rot>]
#   $mGraphicLineInst SetColor <n>
#   $mGraphicLineInst SetLineWidth <n>
#   $mGraphicLineInst SetLineStyle <n>
#
# This is NOT in Appendix A of OrCAD_Capture_TclTk_Extensions.pdf - chapter 3
# only covers reading the database.  The sibling constructors on DboPage have the
# same shape: NewGraphicBoxInst, NewGraphicEllipseInst, NewGraphicArcInst,
# NewGraphicPolylineInst, NewGraphicPolygonInst, NewGraphicBezierInst,
# NewGraphicCommentTextInst, NewGraphicBitMapInst, NewGraphicSymbolVectorInst.
#
# DboPage::NewCommentGraphic is the other candidate and is the wrong one here: it
# wants a DboGraphicObject out of a library, i.e. it *places* a named graphic
# rather than drawing a primitive.
#
# MarkModified + ZoomRedraw afterwards is the shipped pattern - see
# capFindAndReplace/tcl/capDesignUtil.tcl:301-304 and :396.  The design is left
# dirty on purpose; saving it is the user's call (File > Save).
#-----------------------------------------------------------------------------

# Resolve a $::DboValue_* constant by name.  A missing constant fails here with
# something readable instead of passing an empty string into a Dbo call.
proc ::mUtilMenu::DboEnum { pName } {
    if { ![info exists ::$pName] } {
        error "\$::$pName is not defined in this Capture session"
    }
    return [set ::$pName]
}

# Run one Dbo setter and free the DboState it hands back.  Every Set* returns a
# fresh state object (capDesignUtil.tcl:301-304 does the same two lines), so not
# deleting them leaks one SWIG object per call.  Returns 1 when the state said
# OK, 0 when the call itself failed.
proc ::mUtilMenu::DboSet { pObj pMethod args } {
    if { [catch { set lState [eval [list $pObj $pMethod] $args] } lErr] } {
        ::mUtilMenu::Trace "$pMethod failed -> $lErr"
        return 0
    }
    set lOK 1
    catch { set lOK [$lState OK] }
    catch { $lState -delete }
    return $lOK
}

# Draw one graphic line on an already-resolved DboPage.  pFrom / pTo are {x y}
# pairs in doc units; pColor / pWidth / pStyle are DboValue enum names and default
# to mMarkLineColor / mMarkLineWidth / mMarkLineStyle (see those for the style
# names).  A style of "" leaves the line at whatever Capture's default is.
# Returns the new DboGraphicLineInst.
#
# Neither MarkModified nor ZoomRedraw is done here - a caller drawing a whole
# net's worth of lines should do both once at the end, not once per line.
proc ::mUtilMenu::DrawPageLineOn { pPage pFrom pTo {pColor ""} {pWidth ""} \
                                  {pStyle "-"} } {
    variable mMarkLineColor
    variable mMarkLineWidth
    variable mMarkLineStyle

    if { $pColor eq "" } { set pColor $mMarkLineColor }
    if { $pWidth eq "" } { set pWidth $mMarkLineWidth }
    # "-" = argument not given, "" = given and meaning "leave the style alone",
    # which is why this one cannot use "" as its own default.
    if { $pStyle eq "-" } { set pStyle $mMarkLineStyle }

    set lNullObj NULL
    set lStatus  [DboState]

    set lStart [DboTclHelper_sMakeCPoint [lindex $pFrom 0] [lindex $pFrom 1]]
    set lEnd   [DboTclHelper_sMakeCPoint [lindex $pTo   0] [lindex $pTo   1]]
    # Placement origin (0,0), so ptStart/ptEnd are read as the page coordinates
    # they were given rather than as offsets from somewhere else.
    set lOrigin [DboTclHelper_sMakeCPoint 0 0]

    set lLine $lNullObj
    if { [catch { set lLine [$pPage NewGraphicLineInst $lStatus $lStart $lEnd \
                                 $lOrigin [::mUtilMenu::DboEnum DboValue_NOROTATION]] } lErr] } {
        catch { $lStatus -delete }
        error "NewGraphicLineInst failed: $lErr"
    }
    if { $lLine == $lNullObj } {
        catch { $lStatus -delete }
        error "NewGraphicLineInst returned NULL - is the design open and writable?"
    }

    ::mUtilMenu::DboSet $lLine SetLineWidth [::mUtilMenu::DboEnum $pWidth]
    ::mUtilMenu::DboSet $lLine SetColor     [::mUtilMenu::DboEnum $pColor]
    if { $pStyle ne "" } {
        ::mUtilMenu::DboSet $lLine SetLineStyle [::mUtilMenu::DboEnum $pStyle]
    }

    catch { $lStatus -delete }
    return $lLine
}

# Draw one graphic rectangle on an already-resolved DboPage.  pBBox is
# {left top right bottom} in doc units - the order CRect wants, and the order
# ObjBBoxDoc hands back.
#
# DboPage::NewGraphicBoxInst is the rectangle counterpart of NewGraphicLineInst,
# same SWIG shape (self status rect location rotation ?nId?) and the same "dump a
# design back out as Tcl" template in orDb_Dll_Tcl64.dll:
#
#   set mGraphicBoxInst [$mPage NewGraphicBoxInst $mStatus $lRect $pLocation <rot>]
#   $mGraphicBoxInst SetColor <n>
#   $mGraphicBoxInst SetLineWidth <n>
#   $mGraphicBoxInst SetFillStyle <n>
#
# The fill is set to HOLLOW_FILL explicitly rather than left alone: the page
# default is Fill Style=None today (Capture.ini, [Page]), but a filled rectangle
# would paint over the very part it is supposed to be pointing at, so this is not
# something to inherit from a preference the user can change.
proc ::mUtilMenu::DrawPageBoxOn { pPage pBBox {pColor ""} {pWidth ""} \
                                 {pStyle "-"} } {
    variable mMarkBoxColor
    variable mMarkBoxWidth
    variable mMarkBoxStyle

    if { $pColor eq "" } { set pColor $mMarkBoxColor }
    if { $pWidth eq "" } { set pWidth $mMarkBoxWidth }
    if { $pStyle eq "-" } { set pStyle $mMarkBoxStyle }

    set lNullObj NULL
    set lStatus  [DboState]

    set lRect [DboTclHelper_sMakeCRect [lindex $pBBox 0] [lindex $pBBox 1] \
                                       [lindex $pBBox 2] [lindex $pBBox 3]]
    set lOrigin [DboTclHelper_sMakeCPoint 0 0]

    set lBox $lNullObj
    if { [catch { set lBox [$pPage NewGraphicBoxInst $lStatus $lRect $lOrigin \
                                [::mUtilMenu::DboEnum DboValue_NOROTATION]] } lErr] } {
        catch { $lStatus -delete }
        error "NewGraphicBoxInst failed: $lErr"
    }
    if { $lBox == $lNullObj } {
        catch { $lStatus -delete }
        error "NewGraphicBoxInst returned NULL - is the design open and writable?"
    }

    ::mUtilMenu::DboSet $lBox SetFillStyle [::mUtilMenu::DboEnum DboValue_HOLLOW_FILL]
    ::mUtilMenu::DboSet $lBox SetLineWidth [::mUtilMenu::DboEnum $pWidth]
    ::mUtilMenu::DboSet $lBox SetColor     [::mUtilMenu::DboEnum $pColor]
    if { $pStyle ne "" } {
        ::mUtilMenu::DboSet $lBox SetLineStyle [::mUtilMenu::DboEnum $pStyle]
    }

    catch { $lStatus -delete }
    return $lBox
}

# Same thing addressed by {design schematic page} instead, for one-off use from
# the Command Window:
#   ::mUtilMenu::DrawPageLine {G:/.../board.dsn} SCHEMATIC1 PAGE1 {0 0} {200 200}
proc ::mUtilMenu::DrawPageLine { pDsnPath pSchName pPageName pFrom pTo \
                                 {pColor ""} {pWidth ""} {pStyle "-"} } {
    set lPage [::mUtilMenu::FindPage $pDsnPath $pSchName $pPageName]
    set lLine [::mUtilMenu::DrawPageLineOn $lPage $pFrom $pTo $pColor $pWidth $pStyle]

    ::mUtilMenu::DboSet $lPage MarkModified
    catch { ZoomRedraw }
    return $lLine
}

# mLineOffset in doc units.  It is quoted in user units by default, which is what
# the dump prints, so it has to go through the page's granularity to become the
# integers NewGraphicLineInst wants - the same conversion Coord does, backwards.
proc ::mUtilMenu::MarkOffsetDoc { pPage } {
    variable mLineOffset
    variable mLineOffsetUnits

    if { $mLineOffsetUnits eq "doc" } {
        return [expr { round($mLineOffset) }]
    }

    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        ::mUtilMenu::Trace "no physical granularity on this page - taking mLineOffset as doc units"
        return [expr { round($mLineOffset) }]
    }
    return [expr { round(double($mLineOffset) * $lGran) }]
}

# Move one marker off the wire it marks, so it does not simply cover it.
#
# Horizontal wire -> up by pOffset, vertical wire -> right by pOffset.  Page
# coordinates run x right and y *down* (CRect's top is the smaller y, which is why
# ObjLocStr can print TopLeft before BottomRight), so "up" is minus y.
#
# A diagonal wire is neither, and there is no obviously right direction to push it
# in, so it is marked where it is.
proc ::mUtilMenu::OffsetSeg { pSeg pOffset } {
    set lX1 [lindex $pSeg 0]
    set lY1 [lindex $pSeg 1]
    set lX2 [lindex $pSeg 2]
    set lY2 [lindex $pSeg 3]

    if { $lY1 == $lY2 } {
        return [list $lX1 [expr { $lY1 - $pOffset }] $lX2 [expr { $lY2 - $pOffset }]]
    }
    if { $lX1 == $lX2 } {
        return [list [expr { $lX1 + $pOffset }] $lY1 [expr { $lX2 + $pOffset }] $lY2]
    }
    return $pSeg
}

# Mark the (N) page of the compare that just ran, with everything (N) has and (O)
# has not:
#
#   nets / buses  a pink line per wire, over the wire's own coordinates, nudged
#                 clear of it by OffsetSeg
#   parts         a turquoise rectangle round the part's bounding box, drawn where
#                 the box actually is - no offset, the point of a box is that it
#                 surrounds the thing rather than sitting next to it
#
# Does nothing when the compare found nothing new to mark.
#
# pFile / pPair say which page to draw on - PageComp passes the one page column B
# has ticked (through DrawCompareMarkerLine below), AllPagesComp passes each mapped
# page in turn.
proc ::mUtilMenu::DrawMarkersOnPage { pFile pPair } {
    variable mMarkSegs
    variable mMarkBoxes

    set lWanted [expr { [llength $mMarkSegs] + [llength $mMarkBoxes] }]
    if { $lWanted == 0 } {
        ::mUtilMenu::Trace "nothing new in Parts/Nets/Buses - no markers"
        return 0
    }
    set lPair $pPair

    # One page lookup for the whole batch: FindPage walks every schematic and page
    # in the design, so calling it per marker would be quadratic on a real board.
    if { [catch { set lPage [::mUtilMenu::FindPage $pFile \
                                 [lindex $lPair 0] [lindex $lPair 1]] } lErr] } {
        ::mUtilMenu::Trace "markers failed on (N) [file tail $pFile] / [::mUtilMenu::PageLabel $lPair] -> $lErr"
        return 0
    }

    set lOffset [::mUtilMenu::MarkOffsetDoc $lPage]
    set lDrawn  0

    ::mUtilMenu::Out "----------------------------------------------------------------"
    ::mUtilMenu::Out "Markers on (N) [file tail $pFile] - [::mUtilMenu::PageLabel $lPair]"
    ::mUtilMenu::Out "  [llength $mMarkSegs] line(s), offset $lOffset doc units (mLineOffset $::mUtilMenu::mLineOffset $::mUtilMenu::mLineOffsetUnits)"
    ::mUtilMenu::Out "  [llength $mMarkBoxes] rectangle(s), on the bounding box as-is"
    ::mUtilMenu::Out "----------------------------------------------------------------"

    foreach lEntry $mMarkSegs {
        set lLabel [lindex $lEntry 0]
        set lSeg   [lrange $lEntry 1 4]
        set lAt    [::mUtilMenu::OffsetSeg $lSeg $lOffset]

        if { [catch { ::mUtilMenu::DrawPageLineOn $lPage \
                          [lrange $lAt 0 1] [lrange $lAt 2 3] } lErr] } {
            ::mUtilMenu::Trace "marker line for $lLabel at $lAt failed -> $lErr"
            continue
        }
        incr lDrawn
        ::mUtilMenu::Out [format "    line %-30s (%s,%s)-(%s,%s) -> (%s,%s)-(%s,%s)" $lLabel \
                  [lindex $lSeg 0] [lindex $lSeg 1] [lindex $lSeg 2] [lindex $lSeg 3] \
                  [lindex $lAt  0] [lindex $lAt  1] [lindex $lAt  2] [lindex $lAt  3]]
    }

    foreach lEntry $mMarkBoxes {
        set lLabel [lindex $lEntry 0]
        set lBox   [lrange $lEntry 1 4]

        if { [catch { ::mUtilMenu::DrawPageBoxOn $lPage $lBox } lErr] } {
            ::mUtilMenu::Trace "marker rectangle for $lLabel at $lBox failed -> $lErr"
            continue
        }
        incr lDrawn
        ::mUtilMenu::Out [format "    box  %-30s (%s,%s)-(%s,%s)" $lLabel \
                  [lindex $lBox 0] [lindex $lBox 1] [lindex $lBox 2] [lindex $lBox 3]]
    }

    if { $lDrawn > 0 } {
        ::mUtilMenu::DboSet $lPage MarkModified
        catch { ZoomRedraw }
    }
    ::mUtilMenu::Out "  ($lDrawn of $lWanted marker(s) drawn - File > Save to keep them)"
    return $lDrawn
}

# PageComp's entry point into the above: the page to mark is whichever one column
# B has ticked.  Does nothing unless that is exactly one page - the case
# RunPageCompare refuses to run on, and it has already said so in its own message
# box.
proc ::mUtilMenu::DrawCompareMarkerLine { } {
    variable mPagesFileB

    set lSelB [::mUtilMenu::GetCheckedPages B]
    if { [llength $lSelB] != 1 || $mPagesFileB eq "" } {
        return 0
    }
    return [::mUtilMenu::DrawMarkersOnPage $mPagesFileB [lindex $lSelB 0]]
}

# Put a '*' in front of a page's name, which is how this project flags a page as
# touched - the same marker StripPageNamePrefix takes back off before two page
# names are compared, so a page marked here still maps onto its counterpart the
# next time the selector is opened.
#
# Renaming goes through the schematic, not the page: orDb_Dll_Tcl64.dll has
# DboPage_GetName and DboPage_MarkModified but no DboPage_SetName, while
# DboSchematic::Rename takes (pObj newName) and is the call Capture's own rename
# path uses.  DboDesign::RenameObject has the same shape and is tried as a
# fallback, since neither is in Appendix A of the Tcl/Tk PDF and only the DLL
# says they are there.
#
# Returns 1 when the page came back with the new name, 0 otherwise - including
# when it was already marked, which is not a failure and not a second '*'.
proc ::mUtilMenu::MarkPageNameChanged { pFile pPair } {
    set lSchName  [lindex $pPair 0]
    set lPageName [lindex $pPair 1]

    if { [string index $lPageName 0] eq "*" } {
        ::mUtilMenu::Trace "page $lSchName / $lPageName is already marked - left alone"
        return 0
    }

    set lObjs [::mUtilMenu::FindPageObjs $pFile $lSchName $lPageName]
    set lSch  [lindex $lObjs 0]
    set lPage [lindex $lObjs 1]

    set lNew   "*$lPageName"
    set lCStr  [DboTclHelper_sMakeCString $lNew]
    set lOK    0

    if { [::mUtilMenu::DboSet $lSch Rename $lPage $lCStr] } {
        set lOK 1
    } else {
        # Fall back to the design-level rename, same (pObj newName) shape.
        set lSession $::DboSession_s_pDboSession
        DboSession -this $lSession
        set lStatus [DboState]
        set lPath   [DboTclHelper_sMakeCString [file normalize $pFile]]
        set lDesign [$lSession GetDesignAndSchematics $lPath $lStatus]
        catch { $lStatus -delete }
        if { $lDesign ne "NULL" \
             && [::mUtilMenu::DboSet $lDesign RenameObject $lPage $lCStr] } {
            set lOK 1
        }
    }

    # Believe the page, not the return code: whatever the DboState said, the name
    # either changed or it did not.
    if { [::mUtilMenu::CStr $lPage GetName] ne $lNew } {
        ::mUtilMenu::Trace "rename failed: $lSchName / $lPageName -> $lNew"
        return 0
    }

    ::mUtilMenu::DboSet $lPage MarkModified
    ::mUtilMenu::DboSet $lSch  MarkModified
    # The design as well, not just the page and its schematic.  MarkModified is on
    # DboBaseObject (Appendix A p.171), so every level has it, and the level the
    # save path actually asks about is the design.
    catch { ::mUtilMenu::DboSet [::mUtilMenu::FindDesign $pFile] MarkModified }
    return 1
}

# The DboDesign one .DSN path maps to, or NULL.  Same two lines as the walk in
# GetDesignPages, minus the iterators - the design belongs to the session, so it
# stays valid after the DboState is freed.
proc ::mUtilMenu::FindDesign { pDsnPath } {
    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession

    set lStatus [DboState]
    set lPath   [DboTclHelper_sMakeCString [file normalize $pDsnPath]]
    set lDesign [$lSession GetDesignAndSchematics $lPath $lStatus]
    catch { $lStatus -delete }
    return $lDesign
}

# Put the Project Manager back on one design and give it a selected item again.
#
# WHY THIS EXISTS.  After AllPagesComp, File > Save *and Save As* are both greyed
# out on the (N) design until the user clicks another design's PM tab and comes
# back.  Save As does not care whether anything is modified - a design that is
# open can always be written somewhere else - so the two of them going grey
# together is not the dirty flag.  It is that the Project Manager has no selected
# item, and the enabler for both commands is "what is selected in the PM".
#
# What loses the selection is the renaming, which is the one thing AllPagesComp
# does that PageComp does not: DboSchematic::Rename makes the PM rebuild its tree
# and the selection goes with it.  Clicking to the other design and back is what
# puts a selection back - this does the same thing without the two clicks.
#
# Cadence's own save path has the same dependency and solves it the same way:
#   capAdvancedSaveFramework/tcl/capAdvancedSave.tcl:380
#       catch {SelectPMItem "Design Resources"; Menu "File::Save"}
# SelectPMItem(pValue) is Appendix A p.130.
#
# Open(pPath) on a design that is already in the session activates its window
# rather than reading it again (Appendix A p.130) - that is how the (N) design's
# PM is brought forward first, so the selection lands on the right one and not on
# whichever PM the Tk dialogs left in front.
#
# Nothing here writes to the design; the worst a failure can do is leave the
# selection where it was, which is the behaviour without this proc at all.
proc ::mUtilMenu::RestorePMSelection { pFile } {
    variable mRestorePM
    variable mPMSelectItem

    if { !$mRestorePM || $pFile eq "" } {
        return 0
    }

    if { [catch { Open [file normalize $pFile] } lErr] } {
        ::mUtilMenu::Trace "could not activate the PM of [file tail $pFile] -> $lErr"
    }

    # The design's own root name, as a second candidate: a bare .DSN opened
    # without a project shows the design at the top of the tree instead of a
    # "Design Resources" folder.
    set lNames [list $mPMSelectItem]
    catch {
        set lDesign [::mUtilMenu::FindDesign $pFile]
        if { $lDesign ne "NULL" } {
            set lRoot [::mUtilMenu::CStr $lDesign GetRootName]
            if { $lRoot ne "" } {
                lappend lNames $lRoot
            }
        }
    }
    lappend lNames [file rootname [file tail $pFile]]

    set lDone 0
    foreach lName $lNames {
        if { [catch { SelectPMItem $lName } lErr] } {
            ::mUtilMenu::Trace "SelectPMItem \"$lName\" failed -> $lErr"
            continue
        }
        ::mUtilMenu::Trace "PM selection restored on [file tail $pFile] via \"$lName\""
        set lDone 1
        break
    }
    if { !$lDone } {
        ::mUtilMenu::Trace "PM selection NOT restored on [file tail $pFile] - File > Save may still be greyed out; click the design in the Project Manager once"
    }
    return $lDone
}

# PageComp / Refcompare - both need exactly one ticked page per column and differ
# only in which dump sections run.
proc ::mUtilMenu::DoPageCompare { } {
    ::mUtilMenu::RunPageCompare [list parts symbols nets buses] "PageComp" full

    # After the compare, not before: the compare is what decides which nets and
    # buses get marked, and drawing first would also put the marker lines into the
    # (N) dump, where they would show up as bogus differences of their own.
    ::mUtilMenu::DrawCompareMarkerLine
}

proc ::mUtilMenu::DoPageRefCompare { } {
    ::mUtilMenu::RunPageCompare [list parts] "Refcompare" ref
}

# One page pair, compared exactly the way PageComp compares its pair, and marked
# the same way - but with no report and no window.  Returns the number of markers
# drawn on (N)'s page, which is also the answer to "did this page change".
#
# The marker state is cleared first for the same reason RunPageCompare clears it:
# DumpFullCompare fills it, and a pair that finds nothing must not inherit the
# previous pair's findings and draw them a second time on the wrong page.
proc ::mUtilMenu::ComparePagePair { pFileA pPairA pFileB pPairB } {
    variable mMarkSegs
    variable mMarkBoxes

    set mMarkSegs  [list]
    set mMarkBoxes [list]

    set lWhat  [list parts symbols nets buses]
    set lDataO [::mUtilMenu::DumpPageInfo $pFileA [lindex $pPairA 0] [lindex $pPairA 1] $lWhat]
    set lDataN [::mUtilMenu::DumpPageInfo $pFileB [lindex $pPairB 0] [lindex $pPairB 1] $lWhat]

    ::mUtilMenu::DumpFullCompare $lDataO $lDataN

    # After the compare, never before - drawing first would put the marker lines
    # into (N)'s own dump, where they would come back as differences of their own.
    return [::mUtilMenu::DrawMarkersOnPage $pFileB $pPairB]
}

# AllPagesComp - PageComp over every mapped page pair at once, instead of the one
# pair the checkboxes point at.
#
# What it runs on is mPageLinks, Page_name_mapping's {indexA indexB kind} triples:
# every page that has a line drawn to it in the selector, solid or dashed.  A page
# with no counterpart has no line, is not compared, and is not renamed.
#
# A page of (N) that came out different is marked by putting '*' in front of its
# name, so the change is visible in PROJECT_MANAGER_VIEW without opening anything.
# The whole run is silent: one full page dump per pair would be thousands of lines
# in the Command Window for an answer that is a single count, so mQuiet is raised
# for the duration and put back afterwards - including on the way out of an error,
# or the Command Window would stay mute for the rest of the session.
# The proc keeps its old name - only the button label changed - so anything that
# already calls ::mUtilMenu::DoTotalPageCompare from the Command Window still
# works.
proc ::mUtilMenu::DoTotalPageCompare { } {
    variable mPageLinks
    variable mPagesA
    variable mPagesB
    variable mPagesFileA
    variable mPagesFileB
    variable mQuiet

    if { [llength $mPageLinks] == 0 } {
        catch { capDisplayMessageBox \
                    "No page of the two designs maps onto a page of the other, so there is nothing to compare.\n\nOnly pages joined by a line in the page selector are compared." \
                    "Schematic Compare - AllPagesComp" }
        return
    }

    set lSave  $mQuiet
    set mQuiet 1

    set lPairs   0
    set lChanged [list]
    set lFailed  [list]
    set lUnnamed [list]

    set lErr ""
    if { [catch {
        foreach lLink $mPageLinks {
            set lPairA [lindex $mPagesA [lindex $lLink 0]]
            set lPairB [lindex $mPagesB [lindex $lLink 1]]
            if { [llength $lPairA] == 0 || [llength $lPairB] == 0 } {
                continue
            }
            incr lPairs

            if { [catch { set lDrawn [::mUtilMenu::ComparePagePair \
                              $mPagesFileA $lPairA $mPagesFileB $lPairB] } lPairErr] } {
                lappend lFailed "[::mUtilMenu::PageLabel $lPairB] ($lPairErr)"
                continue
            }
            if { $lDrawn <= 0 } {
                continue
            }

            lappend lChanged [lindex $lPairB 1]
            if { [catch { set lRenamed \
                              [::mUtilMenu::MarkPageNameChanged $mPagesFileB $lPairB] } lPairErr] } {
                set lRenamed 0
                ::mUtilMenu::Trace "rename failed on [::mUtilMenu::PageLabel $lPairB] -> $lPairErr"
            }
            if { !$lRenamed } {
                lappend lUnnamed [lindex $lPairB 1]
            }
        }
    } lErr] } {
        set mQuiet $lSave
        ::mUtilMenu::Trace "AllPagesComp failed -> $lErr"
        catch { capDisplayMessageBox "AllPagesComp failed:\n\n$lErr" \
                                     "Schematic Compare - AllPagesComp" }
        return
    }
    set mQuiet $lSave

    catch { ZoomRedraw }

    # One line per page changed, so the box says which ones and not just how many.
    set lMsg "AllPagesComp - [file tail $mPagesFileB]\n\n"
    append lMsg "$lPairs page pair(s) compared.\n"
    append lMsg "[llength $lChanged] page(s) changed and renamed with a leading '*'."
    if { [llength $lChanged] > 0 } {
        append lMsg "\n\n[join $lChanged "\n"]"
    }
    if { [llength $lUnnamed] > 0 } {
        append lMsg "\n\nChanged but NOT renamed ([llength $lUnnamed]) - already marked, or the rename was refused:\n[join $lUnnamed "\n"]"
    }
    if { [llength $lFailed] > 0 } {
        append lMsg "\n\nCould not be compared ([llength $lFailed]):\n[join $lFailed "\n"]"
    }
    if { [llength $lChanged] > 0 } {
        append lMsg "\n\nFile > Save to keep the markers and the new page names."
    }

    ::mUtilMenu::Trace "AllPagesComp: $lPairs pair(s), [llength $lChanged] changed, [llength $lFailed] failed"

    # Modal - so the selector goes away once the count has been read, not before.
    catch { capDisplayMessageBox $lMsg "Schematic Compare - AllPagesComp" }
    ::mUtilMenu::ClosePageSelector

    # Last, once every Tk window of ours is gone: renaming the pages emptied the
    # Project Manager's selection, and File > Save / Save As are both greyed out
    # until it has one again.  See RestorePMSelection.
    if { [llength $lChanged] > 0 } {
        ::mUtilMenu::RestorePMSelection $mPagesFileB
    }
}

# pMode: none = dump only, ref = parts matched by reference (Add/Remove/Changed),
# full = every dumped section diffed as New/Remove.
proc ::mUtilMenu::RunPageCompare { pWhat pLabel {pMode none} } {
    variable mPagesFileA
    variable mPagesFileB
    variable mMarkSegs
    variable mMarkBoxes

    # Cleared here as well as in DumpFullCompare, so a Refcompare - or a compare
    # that bails out below - cannot leave the previous Compare's findings sitting
    # there for DrawCompareMarkerLine to draw a second time.
    set mMarkSegs  [list]
    set mMarkBoxes [list]

    set lSelA [::mUtilMenu::GetCheckedPages A]
    set lSelB [::mUtilMenu::GetCheckedPages B]

    ::mUtilMenu::Trace "$pLabel: colA=[llength $lSelA] ticked, colB=[llength $lSelB] ticked"

    if { [llength $lSelA] != 1 || [llength $lSelB] != 1 } {
        catch { capDisplayMessageBox "Please select each one Page to compare" \
                                     "Schematic Compare" }
        return
    }

    set lPairA [lindex $lSelA 0]
    set lPairB [lindex $lSelB 0]

    # Dump both pages to the Command Window before the message box, so the
    # detail is already there when the box is dismissed.  O first, then N.
    set lEmpty [list parts [list] symbols [list] nets [list] buses [list]]
    set lData  [list]
    foreach lSide [list [list $mPagesFileA $lPairA O] [list $mPagesFileB $lPairB N]] {
        set lFile [lindex $lSide 0]
        set lPair [lindex $lSide 1]
        set lRows $lEmpty
        ::mUtilMenu::Out "================================================================"
        ::mUtilMenu::Out "([lindex $lSide 2]) [file tail $lFile] - [::mUtilMenu::PageLabel $lPair]"
        ::mUtilMenu::Out "================================================================"
        if { [catch { set lRows [::mUtilMenu::DumpPageInfo $lFile \
                          [lindex $lPair 0] [lindex $lPair 1] $pWhat] } lErr] } {
            ::mUtilMenu::Trace "page dump failed for $lFile -> $lErr"
        }
        lappend lData $lRows
    }
    set lMsg "Will $pLabel\n\n(O) [file tail $mPagesFileA] : [::mUtilMenu::PageLabel $lPairA]\n(N) [file tail $mPagesFileB] : [::mUtilMenu::PageLabel $lPairB]"

    # One banner per compare flavour, so the report window says which compare
    # produced it.
    if { $pMode eq "ref" } {
        set lWinTitle "Schematic Page Reference Compare Result"
    } else {
        set lWinTitle "Schematic Page Compare Result"
    }

    # The compare runs before the report window is opened, so its result goes into
    # that one window - no OK-then-another-window.  Full detail stays in the
    # Command Window.
    if { $pMode ne "none" } {
        if { $pMode eq "ref" } {
            set lTitle "Reference compare (Parts by reference)"
        } else {
            set lTitle "Compare (Parts / Symbols / Nets / Buses)"
        }
        ::mUtilMenu::Out "================================================================"
        ::mUtilMenu::Out "$lTitle   O = [file tail $mPagesFileA]   N = [file tail $mPagesFileB]"
        ::mUtilMenu::Out "================================================================"

        if { $pMode eq "ref" } {
            set lResult [::mUtilMenu::DumpRefCompare \
                             [dict get [lindex $lData 0] parts] \
                             [dict get [lindex $lData 1] parts]]
        } else {
            set lResult [::mUtilMenu::DumpFullCompare \
                             [lindex $lData 0] [lindex $lData 1]]
        }
        append lMsg "\n\n$lResult"
    }

    catch { flush stdout }
    if { [catch { ::mUtilMenu::ShowResultWindow $lWinTitle $lMsg } lErr] } {
        ::mUtilMenu::Trace "result window failed -> $lErr"
        catch { capDisplayMessageBox $lMsg $lWinTitle }
    }
}

# "SCHEMATIC1 / PAGE1" for one {schematicName pageName} pair.
proc ::mUtilMenu::PageLabel { pPair } {
    return "[lindex $pPair 0] / [lindex $pPair 1]"
}

proc ::mUtilMenu::ShowPageSelector { pFileA pFileB } {
    variable mPagesWin
    variable mPagesA
    variable mPagesB
    variable mPagesFileA
    variable mPagesFileB
    variable mPageLinks
    variable mPageCanvas
    variable mPageCbsA
    variable mPageCbsB
    variable mPageLinkX1
    variable mPageLinkX2
    variable mPageColWidth
    variable mPageLinkGap
    variable mPageSimilarChars
    variable mPageLinksReady

    set mPagesFileA $pFileA
    set mPagesFileB $pFileB
    set mPageLinks  [list]
    set mPageCanvas ""
    set mPageCbsA   [list]
    set mPageCbsB   [list]
    # No lines until the very end - see RedrawPageLinks.
    set mPageLinksReady 0

    # Read both designs first - if this fails the column says so rather than
    # leaving an empty window with no explanation.  SortPages puts the list into
    # PROJECT_MANAGER_VIEW order; doing it here, before the columns are built,
    # keeps the checkbox indices lined up with mPagesA/mPagesB, which is what
    # GetCheckedPages relies on.
    set lErrA ""
    set lErrB ""
    if { [catch { set mPagesA [::mUtilMenu::SortPages \
                                  [::mUtilMenu::GetDesignPages $pFileA]] } lErrA] } {
        set mPagesA [list]
        ::mUtilMenu::Trace "page list failed for $pFileA -> $lErrA"
    }
    if { [catch { set mPagesB [::mUtilMenu::SortPages \
                                  [::mUtilMenu::GetDesignPages $pFileB]] } lErrB] } {
        set mPagesB [list]
        ::mUtilMenu::Trace "page list failed for $pFileB -> $lErrB"
    }

    array unset ::mUtilMenu::mPageSelA
    array unset ::mUtilMenu::mPageSelB

    catch { destroy $mPagesWin }
    toplevel $mPagesWin
    wm title $mPagesWin "Schematic Compare - Select Pages"
    wm protocol $mPagesWin WM_DELETE_WINDOW "::mUtilMenu::ClosePageSelector"
    catch { SetAppWindowAsParent [expr { [winfo id $mPagesWin] }] }

    set lBody $mPagesWin.body
    frame $lBody -padx 10 -pady 10
    pack $lBody -side top -fill both -expand 1

    # Pair the two columns up.  Skipped unless both sides came back with pages -
    # otherwise a design that failed to read would turn the whole other column
    # red, and the real problem is already spelled out as "(no pages found)".
    set lMarksA [list]
    set lMarksB [list]
    if { [llength $mPagesA] > 0 && [llength $mPagesB] > 0 } {
        set lMap    [::mUtilMenu::Page_name_mapping $mPagesA $mPagesB]
        set lMarksA [dict get $lMap marksA]
        set lMarksB [dict get $lMap marksB]
        set mPageLinks [dict get $lMap links]
    }

    # Headers stay outside the canvas, so they do not scroll away.  -minsize
    # lines the three grid columns up with the three bands inside the canvas:
    # column A, the link gap, column B.
    set lHdr $lBody.hdr
    frame $lHdr
    label $lHdr.a   -text "(O) [file tail $pFileA]" -anchor w -font {-weight bold}
    label $lHdr.gap -text ""
    label $lHdr.b   -text "(N) [file tail $pFileB]" -anchor w -font {-weight bold}
    grid $lHdr.a   -row 0 -column 0 -sticky w
    grid $lHdr.gap -row 0 -column 1 -sticky ew
    grid $lHdr.b   -row 0 -column 2 -sticky w
    grid columnconfigure $lHdr 0 -minsize $mPageColWidth
    grid columnconfigure $lHdr 1 -minsize $mPageLinkGap
    grid columnconfigure $lHdr 2 -minsize $mPageColWidth
    pack $lHdr -side top -fill x -padx 2 -pady {0 4}

    # One canvas for both columns.  Two separate scroll boxes could not carry a
    # line from one to the other - a canvas item belongs to its own canvas - and
    # they would scroll independently, so a link drawn across the gap would point
    # at the wrong page as soon as either side moved.
    set lArea $lBody.area
    frame $lArea -borderwidth 1 -relief sunken
    set lTotalW [expr { 2 * $mPageColWidth + $mPageLinkGap }]

    canvas $lArea.cv -width $lTotalW -height 320 -highlightthickness 0 \
        -yscrollcommand "$lArea.sby set" -xscrollcommand "$lArea.sbx set"
    scrollbar $lArea.sby -orient vertical   -command "$lArea.cv yview"
    scrollbar $lArea.sbx -orient horizontal -command "$lArea.cv xview"

    grid $lArea.cv  -row 0 -column 0 -sticky nsew
    grid $lArea.sby -row 0 -column 1 -sticky ns
    grid $lArea.sbx -row 1 -column 0 -sticky ew
    grid columnconfigure $lArea 0 -weight 1
    grid rowconfigure    $lArea 0 -weight 1
    pack $lArea -side top -fill both -expand 1

    # The columns are children of the canvas and are put on it as window items at
    # fixed x, which is what lets DrawPageLinks treat a widget's own y as a canvas
    # y and know where the two edges of the gap are.
    set lFrmA $lArea.cv.colA
    set lFrmB $lArea.cv.colB
    frame $lFrmA
    frame $lFrmB
    set mPageCbsA [::mUtilMenu::BuildPageColumn $lFrmA $mPagesA mPageSelA $lMarksA]
    set mPageCbsB [::mUtilMenu::BuildPageColumn $lFrmB $mPagesB mPageSelB $lMarksB]

    set mPageCanvas $lArea.cv
    set mPageLinkX1 $mPageColWidth
    set mPageLinkX2 [expr { $mPageColWidth + $mPageLinkGap }]

    $lArea.cv create window 0 0 -anchor nw -window $lFrmA -width $mPageColWidth
    $lArea.cv create window $mPageLinkX2 0 -anchor nw -window $lFrmB \
        -width $mPageColWidth

    # No lines drawn here on purpose.  Everything below still has to be packed and
    # laid out, so a line drawn now would be drawn against a layout that does not
    # hold yet and would visibly jump into place afterwards; mPageLinksReady keeps
    # DrawPageLinks off until the "after idle" at the bottom of this proc, and the
    # whole set then appears in one go.  These two bindings are what redraws them
    # after that - <Configure> fires on every resize, and redrawing is cheap
    # (delete a tag, re-create the lines).
    update idletasks
    bind $lFrmA <Configure> "::mUtilMenu::DrawPageLinks"
    bind $lFrmB <Configure> "::mUtilMenu::DrawPageLinks"

    # On the toplevel rather than on the canvas: the checkbuttons cover most of
    # the canvas, and a wheel event goes to the widget under the pointer.
    bind $mPagesWin <MouseWheel> \
        "$lArea.cv yview scroll \[expr { -(%D / 120) }\] units"

    set lLegend $lBody.legend
    frame $lLegend
    label $lLegend.same -anchor w -foreground $::mUtilMenu::mLinkColorExact \
        -text "- - same page name"
    label $lLegend.near -anchor w -foreground $::mUtilMenu::mLinkColorSimilar \
        -text "- - same first $mPageSimilarChars characters (similar)"
    label $lLegend.none -anchor w -foreground red \
        -text "red, no line: no counterpart"
    pack $lLegend.same -side left -padx {2 12}
    pack $lLegend.near -side left -padx {0 12}
    pack $lLegend.none -side left
    pack $lLegend -side top -fill x -pady {6 0}

    set lBtns $mPagesWin.btns
    frame $lBtns -padx 10
    pack $lBtns -side bottom -fill x
    button $lBtns.close    -text "Close"      -width 12 \
        -command "::mUtilMenu::ClosePageSelector"
    button $lBtns.pagecomp -text "PageComp"   -width 12 \
        -command "::mUtilMenu::DoPageCompare"
    # Refcompare is built but NOT packed, so it does not show up in the window.
    # Nothing else about it is removed: the button, DoPageRefCompare, DumpRefCompare
    # and RunPageCompare's "ref" mode are all still here and still work, and putting
    # it back on screen is one pack line (the commented-out one below).  It is also
    # still reachable from the Command Window with
    #   ::mUtilMenu::DoPageRefCompare
    # once two pages are ticked.
    button $lBtns.refcmp   -text "Refcompare" -width 12 \
        -command "::mUtilMenu::DoPageRefCompare"
    button $lBtns.allcmp   -text "AllPagesComp" -width 14 \
        -command "::mUtilMenu::DoTotalPageCompare"
    # AllPagesComp is packed to the LEFT edge and the rest to the right, so the
    # whole remaining width of the button bar sits between them: it is the one
    # button that walks every page and renames what it finds, and it should not be
    # a slip of the mouse away from PageComp.
    pack $lBtns.allcmp   -side left            -pady {4 10}
    pack $lBtns.close    -side right -padx {6 0} -pady {4 10}
    pack $lBtns.pagecomp -side right -padx {6 0} -pady {4 10}
    # pack $lBtns.refcmp   -side right -padx {6 0} -pady {4 10}

    bind $mPagesWin <Escape> "::mUtilMenu::ClosePageSelector"

    # The link lines, all of them, for the first time.  Everything above has been
    # packed by now but not yet laid out, and the button bar and the legend both
    # change how tall the canvas ends up - drawing earlier would mean drawing
    # against a layout that does not hold yet.  "after idle" fires once Tk has
    # settled all of it, and RedrawPageLinks is what lets the lines be drawn at
    # all, so they appear together instead of one shifting set at a time.
    after idle [list ::mUtilMenu::RedrawPageLinks]
    return true
}

proc ::mUtilMenu::DoSchematicCompareExecute { } {
    variable mCmpFileA
    variable mCmpFileB

    set lA [string trim $mCmpFileA]
    set lB [string trim $mCmpFileB]

    ::mUtilMenu::Trace "Schematic Compare Execute: A=$lA B=$lB"

    # Either field empty -> say so and leave the dialog up, so the missing file
    # can be picked without reopening from the menu.
    if { $lA eq "" || $lB eq "" } {
        catch { capDisplayMessageBox "Please select two DSN file..." "Schematic Compare" }
        return
    }

    ::mUtilMenu::CloseSchematicCompare

    # Open(pPath) - Application command, Appendix A p.130.  Feed it forward
    # slashes: that is the form used throughout the PDF's own examples, and it
    # sidesteps the backslash-escaping trap described in section 17 (p.112).
    foreach lFile [list $lA $lB] {
        if { [catch { Open [file normalize $lFile] } lErr] } {
            ::mUtilMenu::Trace "Open failed for $lFile -> $lErr"
            catch { capDisplayMessageBox "Failed to open:\n$lFile\n\n$lErr" \
                                         "Schematic Compare" }
        }
    }

    # Both designs are in the session now - let the user pick pages.
    if { [catch { ::mUtilMenu::ShowPageSelector $lA $lB } lErr] } {
        ::mUtilMenu::Trace "page selector failed -> $lErr"
        catch { capDisplayMessageBox "Could not build the page list:\n\n$lErr" \
                                     "Schematic Compare" }
    }
}

proc ::mUtilMenu::CloseSchematicCompare { } {
    variable mCmpWin
    catch { destroy $mCmpWin }
}

# "package require Tk" creates the Tk root window ".", which shows up as an
# empty stray window titled "tk" the first time Schematic Compare is opened.
# Hide it - but only if nothing has packed anything into it, so this never
# hides another Tcl/Tk app that legitimately uses "." as its own window.
proc ::mUtilMenu::HideTkRoot { } {
    catch {
        if { [winfo exists .] && [llength [winfo children .]] == 0 } {
            wm withdraw .
        }
    }
}

proc ::mUtilMenu::DoSchematicCompare { pVia } {
    variable mCmpWin
    ::mUtilMenu::Trace "Schematic Compare callback reached via $pVia"

    if { [catch { package require Tk } lErr] } {
        set lMsg "Tk is not available in this Capture session.\n\nSee section 1.4 \"Capture TCL/Tk Advanced Environment Setup\"\nof OrCAD_Capture_TclTk_Extensions.pdf (p.15-16), then verify\nwith:\n\n    package require Tk\n    toplevel .new\n\nTk reported: $lErr"
        ::mUtilMenu::Out "mUtil: $lMsg"
        catch { capDisplayMessageBox $lMsg "mUtil - Schematic Compare" }
        return true
    }

    ::mUtilMenu::HideTkRoot

    # Already open - just bring it forward instead of building a second copy.
    if { [winfo exists $mCmpWin] } {
        catch {
            wm deiconify $mCmpWin
            raise $mCmpWin
            focus $mCmpWin
        }
        return true
    }

    toplevel $mCmpWin
    wm title $mCmpWin "Schematic Compare"
    wm resizable $mCmpWin 1 0
    wm protocol $mCmpWin WM_DELETE_WINDOW "::mUtilMenu::CloseSchematicCompare"

    # Keep the dialog owned by the Capture main window so it does not get lost
    # behind it.  SetAppWindowAsParent is documented on p.134 of the PDF.
    catch { SetAppWindowAsParent [expr { [winfo id $mCmpWin] }] }

    set lBody $mCmpWin.body
    frame $lBody -padx 10 -pady 10
    pack $lBody -side top -fill both -expand 1

    # row 0: the folder Browse... starts in.  Its own Browse picks a directory.
    label $lBody.lblDir -text "Default Folder:" -anchor w
    entry $lBody.entDir -width 60 -textvariable ::mUtilMenu::mCmpInitDir
    button $lBody.btnDir -text "Browse..." -width 10 \
        -command "::mUtilMenu::BrowseInitDir"

    # row 1/2: the two design files.  (O) = old, (N) = new - Refcompare reports
    # what N adds, removes or changes relative to O.
    label $lBody.lblA -text "Design File 1(O):" -anchor w
    entry $lBody.entA -width 60 -textvariable ::mUtilMenu::mCmpFileA
    button $lBody.btnA -text "Browse..." -width 10 \
        -command "::mUtilMenu::BrowseDesign mCmpFileA"

    label $lBody.lblB -text "Design File 2(N):" -anchor w
    entry $lBody.entB -width 60 -textvariable ::mUtilMenu::mCmpFileB
    button $lBody.btnB -text "Browse..." -width 10 \
        -command "::mUtilMenu::BrowseDesign mCmpFileB"

    grid $lBody.lblDir -row 0 -column 0 -sticky w  -padx {0 6} -pady 4
    grid $lBody.entDir -row 0 -column 1 -sticky ew -padx {0 6} -pady 4
    grid $lBody.btnDir -row 0 -column 2 -sticky e            -pady 4

    grid $lBody.lblA -row 1 -column 0 -sticky w  -padx {0 6} -pady 4
    grid $lBody.entA -row 1 -column 1 -sticky ew -padx {0 6} -pady 4
    grid $lBody.btnA -row 1 -column 2 -sticky e            -pady 4

    grid $lBody.lblB -row 2 -column 0 -sticky w  -padx {0 6} -pady 4
    grid $lBody.entB -row 2 -column 1 -sticky ew -padx {0 6} -pady 4
    grid $lBody.btnB -row 2 -column 2 -sticky e            -pady 4

    grid columnconfigure $lBody 1 -weight 1

    # bottom: Execute / Cancel
    set lBtns $mCmpWin.btns
    frame $lBtns -padx 10
    pack $lBtns -side bottom -fill x

    button $lBtns.execute -text "Execute" -width 12 -default active \
        -command "::mUtilMenu::DoSchematicCompareExecute"
    button $lBtns.cancel  -text "Cancel"  -width 12 \
        -command "::mUtilMenu::CloseSchematicCompare"

    pack $lBtns.cancel  -side right -padx {6 0} -pady {4 10}
    pack $lBtns.execute -side right          -pady {4 10}

    bind $mCmpWin <Return> "::mUtilMenu::DoSchematicCompareExecute"
    bind $mCmpWin <Escape> "::mUtilMenu::CloseSchematicCompare"

    focus $lBody.entA
    return true
}

# capCloseChildViewsExceptCurrent() - documented on p.136 of the Tcl/Tk PDF.
proc ::mUtilMenu::DoClosePage { pVia } {
    ::mUtilMenu::Trace "Close Page callback reached via $pVia"

    if { [catch { capCloseChildViewsExceptCurrent } lErr] } {
        ::mUtilMenu::Trace "Close Page failed -> $lErr"
    }
    return true
}

#=============================================================================
# Path A - mUtil top-level menu, via InsertXMLMenu
#=============================================================================

proc ::mUtilMenu::XmlSchematicCompare { args } { return [DoSchematicCompare "mUtil menu"] }
proc ::mUtilMenu::XmlClosePage        { args } { return [DoClosePage        "mUtil menu"] }

proc ::mUtilMenu::initXmlMenu { } {
    catch {
        RegisterAction "mUtilMenuAction"  "::mUtilMenu::True" "" "::mUtilMenu::Action"  ""
        RegisterAction "mUtilMenuEnabler" "::mUtilMenu::True" "" "::mUtilMenu::Enabler" ""

        RegisterAction "mUtilSchCompareAction"  "::mUtilMenu::True" "" \
            "::mUtilMenu::XmlSchematicCompare" ""
        RegisterAction "mUtilSchCompareEnabler" "::mUtilMenu::True" "" \
            "::mUtilMenu::Enabler"             ""

        RegisterAction "mUtilClosePageAction"  "::mUtilMenu::True" "" \
            "::mUtilMenu::XmlClosePage" ""
        RegisterAction "mUtilClosePageEnabler" "::mUtilMenu::True" "" \
            "::mUtilMenu::Enabler"      ""

        InsertXMLMenu [list \
            [list $::mUtilMenu::mMenuId] \
            "0" "Accessories" \
            [list "popup" $::mUtilMenu::mMenuLabel "0" \
                  "mUtilMenuAction" "mUtilMenuEnabler" "" ""] \
            ""]

        # 7-element action spec, exactly as OrCloudULMenu.tcl:42 does it for a
        # child of a custom top-level popup.
        InsertXMLMenu [list \
            [list $::mUtilMenu::mMenuId "mUtilSchCompare"] "" "" \
            [list "action" "Schematic Compare" "0" \
                  "mUtilSchCompareAction" "mUtilSchCompareEnabler" "" ""] \
            ""]

        InsertXMLMenu [list \
            [list $::mUtilMenu::mMenuId "mUtilClosePage"] "" "" \
            [list "action" "Close Page" "0" \
                  "mUtilClosePageAction" "mUtilClosePageEnabler" "" ""] \
            ""]

        RefreshMenu
    }
}

#=============================================================================
# Path B - Accessories > mUtil, via AddAccessoryMenu (the documented way)
#
# Page-level callbacks get (pPage pOcc); design-level callbacks get (pLib).
#=============================================================================

proc ::mUtilMenu::PageSchematicCompare   { pPage pOcc } { DoSchematicCompare "Accessories (page)" }
proc ::mUtilMenu::PageClosePage          { pPage pOcc } { DoClosePage        "Accessories (page)" }
proc ::mUtilMenu::DesignSchematicCompare { pLib }       { DoSchematicCompare "Accessories (design)" }
proc ::mUtilMenu::DesignClosePage        { pLib }       { DoClosePage        "Accessories (design)" }

proc ::mUtilMenu::addPageAccessoryMenu { } {
    AddAccessoryMenu "mUtil" "Schematic Compare" "::mUtilMenu::PageSchematicCompare"
    AddAccessoryMenu "mUtil" "Close Page"        "::mUtilMenu::PageClosePage"
}

proc ::mUtilMenu::addDesignAccessoryMenu { } {
    AddAccessoryMenu "mUtil" "Schematic Compare" "::mUtilMenu::DesignSchematicCompare"
    AddAccessoryMenu "mUtil" "Close Page"        "::mUtilMenu::DesignClosePage"
}

proc ::mUtilMenu::initAccessoryMenu { } {
    catch {
        RegisterAction "_cdnCapTclAddPageCustomMenu"   "::mUtilMenu::True" "" \
            "::mUtilMenu::addPageAccessoryMenu"   ""
        RegisterAction "_cdnCapTclAddDesignCustomMenu" "::mUtilMenu::True" "" \
            "::mUtilMenu::addDesignAccessoryMenu" ""
    }
}

#=============================================================================
proc ::mUtilMenu::init { } {
    ::mUtilMenu::initXmlMenu
    ::mUtilMenu::initAccessoryMenu
}

proc ::mUtilMenu::remove { } {
    ::mUtilMenu::CloseSchematicCompare
    ::mUtilMenu::ClosePageSelector
    ::mUtilMenu::CloseResultWindow
    catch {
        DeleteXMLMenu [list $::mUtilMenu::mMenuId "mUtilSchCompare"]
        DeleteXMLMenu [list $::mUtilMenu::mMenuId "mUtilExpOut"]
        DeleteXMLMenu [list $::mUtilMenu::mMenuId "mUtilClosePage"]
        DeleteXMLMenu [list $::mUtilMenu::mMenuId]
        RefreshMenu
    }
}

#-----------------------------------------------------------------------------
# Diagnostics - run in the Command Window and paste the output back.
#-----------------------------------------------------------------------------
proc ::mUtilMenu::diag { } {
    ::mUtilMenu::Out "--- commands present ---"
    foreach c { capCloseChildViewsExceptCurrent capCloseChildViews \
                EnableAllButCurrentWindowCloseMenu AddAccessoryMenu \
                InsertXMLMenu FindXMLMenu RefreshMenu RegisterAction \
                svsDiffDesigns capDisplayMessageBox SetAppWindowAsParent } {
        ::mUtilMenu::Out [format "  %-36s %s" $c [expr {[info commands $c] eq "" ? "MISSING" : "ok"}]]
    }

    ::mUtilMenu::Out "--- Tk ---"
    if { [catch { package require Tk } lVer] } {
        ::mUtilMenu::Out "  package require Tk        FAILED: $lVer"
    } else {
        ::mUtilMenu::Out "  package require Tk        ok (Tk $lVer)"
    }

    ::mUtilMenu::Out "--- menu nodes ---"
    foreach p { {mUtil} {mUtil mUtilSchCompare} {mUtil mUtilClosePage} {Tools} {Accessories} } {
        if { [catch { set r [FindXMLMenu $p] } lErr] } { set r "ERROR: $lErr" }
        ::mUtilMenu::Out [format "  %-26s %s" $p $r]
    }

    ::mUtilMenu::Out "--- direct dialog test (no menu involved) ---"
    ::mUtilMenu::Out "  ::mUtilMenu::DoSchematicCompare manual"
}

# Why is File > Save greyed out?  Run this in the Command Window at the moment it
# is, and again after clicking the design in the Project Manager - the line that
# changes is the answer.
#
#   selected PM items  empty  -> the PM has no selection, which is what disables
#                               Save AND Save As.  RestorePMSelection is the fix.
#   IsDocModified      0      -> the UI-level document flag, which drives Save but
#                               not Save As.
#   design IsModified  0      -> the DBO write never landed at all; the marker and
#                               rename code is what to look at, not the menu.
#
# GetSelectedPMItems / IsDocModified / GetActivePMDesign / GetActiveOpjName are
# Appendix A p.129-132.
proc ::mUtilMenu::diagSaveState { } {
    variable mPagesFileA
    variable mPagesFileB

    foreach lPair [list [list "GetActiveOpjName" GetActiveOpjName] \
                        [list "IsDocModified"    IsDocModified] \
                        [list "selected PM items" GetSelectedPMItems]] {
        set lVal "ERROR / not available"
        catch { set lVal [[lindex $lPair 1]] }
        ::mUtilMenu::Out [format "  %-20s %s" [lindex $lPair 0] $lVal]
    }

    set lActive "?"
    catch { set lActive [::mUtilMenu::CStr [GetActivePMDesign] GetRootName] }
    ::mUtilMenu::Out [format "  %-20s %s" "active PM design" $lActive]

    foreach lSide [list [list O $mPagesFileA] [list N $mPagesFileB]] {
        set lFile [lindex $lSide 1]
        if { $lFile eq "" } {
            continue
        }
        set lMod "?"
        catch {
            set lStatus [DboState]
            set lMod [[::mUtilMenu::FindDesign $lFile] IsModified $lStatus]
            catch { $lStatus -delete }
        }
        ::mUtilMenu::Out [format "  (%s) %-16s IsModified = %s" \
                  [lindex $lSide 0] [file tail $lFile] $lMod]
    }
}

::mUtilMenu::init

#---------------------------------------------------------------------------------
# Reload without restarting Capture:
#   ::mUtilMenu::remove
#   source {G:/Cadence/SPB_17.4/tools/capture/tclscripts/capAutoLoad/mUtilMenu.tcl}
#---------------------------------------------------------------------------------
