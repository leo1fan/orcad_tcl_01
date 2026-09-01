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
#     Schematic Check   -> message box naming the Design (.DSN) or Project (.OPJ)
#                          currently selected in PROJECT_MANAGER_VIEW
#     Close Page        -> tab RMB > Close All Tabs But This
#
#  Schematic Compare flow:
#     dialog        Default Folder + two .DSN fields, each with Browse.  Whichever
#                   folder a Browse ends up in becomes the Default Folder and is
#                   written to mUtilMenu.cfg beside this script, so the dialog
#                   reopens there next time and after the next Capture restart -
#                   see SaveConfig / LoadConfig / mCmpInitDir.
#     Execute       both fields filled?  no  -> "Please select two DSN file..."
#                                        yes -> Open(pPath) both designs
#                                               (Appendix A, p.130), then show
#                                               the page selector
#     page selector two columns, one per design, both drawn inside ONE canvas so
#                   the gap between them can be drawn in as well: filename header,
#                   then one checkbox per page, listed in PROJECT_MANAGER_VIEW
#                   order.  ::mUtilMenu::GetCheckedPages A|B returns the ticked
#                   {schematicName pageName} pairs.
#                   Columns are headed "(O) <file>" and "(N) <file>", with the
#                   ASRock logo between them - asrock_logo_s.png, 120x22, exactly
#                   the width of the gap.  It is the PNG and not the .jpg because
#                   Capture's Tk 8.6.5 has no JPEG reader; see mLogoFiles.
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
#                   OnePageCmp and Close.  Refcompare's button is built but not
#                   packed - the compare is still there, just not on screen; see
#                   ShowPageSelector for the two ways to run it and the one line to
#                   uncomment to bring the button back.
#     OnePageCmp    the one-page compare - "PageComp" everywhere in the code and in
#                   the reports, only the button says OnePageCmp.
#                   exactly one page ticked per column?
#                       no  -> "Please select each one Page to compare"
#                       yes -> dump both pages to the Command Window (parts,
#                              off-page/power/ports, nets, buses), diff every
#                              section O vs N, and report New / Remove (or
#                              "all the same") in one result window
#                   Both pages' NETLISTS are printed to the Command Window on the
#                   way past - one line per net: the name, 1 when the net leaves
#                   the page (it has an Off-Page / Power / Port symbol on it) or 0
#                   when it does not, then every part pin on it as
#                   Part_Reference.Pin_Number:
#
#                       +VCC1.8V     1  HC32.2 HC408.1
#
#                   and the two netlists are then COMPARED - that comparison is
#                   what the pink lines over (N)'s net wires come from, under four
#                   rules, tried in this order (NetlistCompare; grep the file for
#                   net_compare_rule to change one of them):
#
#                     net_compare_rule1  a net of (N) with no Part_Reference.Pin
#                                        on it at all and the global/local bit 0
#                                        (local) - a wire going nowhere.  (O) is
#                                        not consulted.  Marks every wire of it.
#                     net_compare_rule2  the net is in (N)'s netlist and not in
#                                        (O)'s.  Marks every wire of it.
#                     net_compare_rule3  both have it, global/local bit differs -
#                                        a different net.  Marks every wire of it.
#                     net_compare_rule4  both have it with the same bit, but the
#                                        pins on it differ.  Marks only the wire
#                                        at each changed pin, and only when the
#                                        PART behind that pin has more than
#                                        mRule4MinPins (5) pins: the pin's own
#                                        connection point is located, and the wire
#                                        of that net which touches it is the one
#                                        drawn over.  A changed pin on a part with
#                                        5 pins or fewer - a resistor, a capacitor,
#                                        a small header - is not processed at all:
#                                        it is listed as skipped in the Command
#                                        Window and never drawn or reported.
#                                        A pin only (O) had is reported and not
#                                        marked - (N) has no position for it - and
#                                        is held to the same pin count.
#
#                   The Nets section is still dumped and still diffed New/Remove
#                   for the report, but it no longer draws anything: it compares
#                   name plus wire coordinates, so a wire nudged half a grid
#                   square used to count as a new net and a net rewired between
#                   two parts that kept their wires used to count as no change.
#                   Nets and Buses are reported in full rather than capped.  The
#                   other two things marked on (N)'s page are unchanged: a pink
#                   line per bus wire (N) has and (O) has not, and a thick
#                   turquoise rectangle round each new part's bounding box.
#                   A part that only MOVED is not new: same Part Reference,
#                   Value, PCB Footprint, Part_Number, Optional and pins at a
#                   different position counts as the same part, and it is listed
#                   under "Moved" instead of being marked - see PartMoveFilter.
#                   Every marker line is broken rather than solid so it can never
#                   be read as a wire the compare added - see mMarkLineStyle for
#                   the five styles available - and nudged clear of the wire it
#                   marks by mLineOffset.
#                   DrawCompareMarkerLine / DrawPageLineOn / DrawPageBoxOn are the
#                   only part of this file that *writes* to a design.
#     Refcompare    the connection compare.  Two sections, no marker lines -
#                   PageComp is the one that marks:
#
#                     Parts    matched by Part Reference, as before:
#                              Add / Remove / Changed, or "all the same"
#                     Symbols  Off-Page / Power / Ports, matched by type + name:
#                              Add / Remove / Changed connection
#
#                   The Parts dump it prints to the Command Window carries one
#                   line per pin - pin number, pin name, the pin's connection
#                   point in doc units, and what the pin is joined to: the net's
#                   name, "NC" when the pin carries a no-connect marker, or
#                   "unconnected" when it is simply not wired to anything.  See
#                   CollectPinInfo / PinConnStr and mPinDetail.  The connection
#                   point is the number net_compare_rule4 works from, so a column
#                   of "-" there is why rule 4 marked nothing.
#                   The Off-Page / Power / Ports dump carries the same answer per
#                   symbol - SymbolConn / mSymConnDetail - except that a symbol
#                   has no no-connect marker to carry (GetIsNoConnect is a PIN
#                   call), so for one of those "NC" only ever means "attached to
#                   nothing".
#                   A symbol name is not unique the way a Part Reference is - a
#                   page can hold twenty GND symbols - so the symbol half
#                   compares the whole list of connections filed under one
#                   type + name, which is what DumpRefSymbolCompare does.
#                   PageComp's Parts and Symbols dumps print the same connection
#                   lines - they go through the same PrintPartRows /
#                   PrintSymbolRows - but PageComp's *result* did not change: its
#                   signatures still come off the pin NAMES and off elements 0-2
#                   of a symbol row, so a net rename does not turn into a
#                   "Changed" part there.
#     AllPagesComp  the same compare PageComp does - same page walk, same
#                   DumpFullCompare, same net_compare_rule1..4 markers - but over
#                   every mapped page pair at once: every pair the selector drew a
#                   line for, solid or dashed.  A page with no line is not
#                   compared and not touched.
#                   No page dump and no timing: both would be paid once per pair,
#                   which is thousands of Command Window lines and a measuring
#                   overhead for an answer that is a count (ComparePagePair turns
#                   mQuiet on and mTimeCompare off around each pair).  What the
#                   Command Window gets instead is ONE LINE PER PAIR as it
#                   finishes, so a long run shows where it is:
#
#                     AllPagesComp - (N) new.dsn   (O) old.dsn
#                       (N) PAGE1   (O) PAGE1   Page comparison finished - no difference
#                       (N) PAGE2   (O) PAGE2   Page comparison finished - 7 marker(s), '*' added
#
#                   Page names only - the schematic name is the same on every line
#                   of a run, so it is said once in the header and left off.
#
#                   Each (N) page that came out different keeps its markers AND
#                   gets a '*' put in front of its name, so PROJECT_MANAGER_VIEW
#                   shows which pages changed.  Ends in one message box with the
#                   count; OK
#                   closes it and the page selector with it, and then puts the
#                   Project Manager's selection back on the (N) design - the
#                   renaming rebuilds the PM tree and empties the selection, which
#                   is what leaves File > Save and Save As both greyed out until
#                   another design is clicked and clicked back.  See
#                   RestorePMSelection / mRestorePM, and ::mUtilMenu::diagSaveState
#                   if Save is ever greyed out again.
#     result window read-only Tk text widget, not a message box - the report can
#                   be selected with the mouse and copied out.  Its Close button
#                   (and its X, and Escape) closes the PAGE SELECTOR as well - the
#                   two windows are one job, so the answer and the question go away
#                   together.  See CloseResultAndSelector.  Banner is
#                   "Schematic Page Compare Result" / "Schematic Page Reference
#                   Compare Result".
#
#  TIMING is printed with the dump - mTimeCompare, which is ON.  Three things,
#  smallest scope first:
#
#    timing: CollectPageParts 1843 ms - 312 part(s), 2971 pin(s)
#              rule4 part pin count      14 ms over  312 call(s)
#              rule4 pin position       431 ms over 1204 call(s), 1767 pin(s) skipped
#              the rest of the walk    1398 ms
#    timing: NetlistCompare 31 ms - (O) 245 net(s), (N) 247 net(s) -> 12 finding(s), 8 skipped
#    timing - PageComp, one page pair, 8420 ms total
#      parts print            5900 ms   70%
#      parts collect          1843 ms   22%
#      ...
#
#  The first block says what net_compare_rule4 costs where it costs anything - the
#  part's pin count and each pin's connection point are the only two Dbo calls it
#  added.  The second says what the rules themselves cost (pure Tcl, no Dbo calls).
#  The last one is the whole compare, split into the database walk ("<section>
#  collect"), the Command Window printing ("<section> print"), the netlist work and
#  the section diff - four very different jobs with four different fixes.  On a real
#  page the printing is usually the largest single item, one puts per line and
#  thousands of lines per side; the two switches that cut it are mPinDetail 0 (drops
#  one line per pin) and mQuiet 1 (drops all of it).
#
#       set ::mUtilMenu::mTimeCompare 0     turns every timing line off again
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
    # row of the dialog and editable there (its own Browse picks a folder).
    #
    # This line is only the FIRST-EVER default now: every Browse - the folder one
    # and either Design File one - writes the folder it ended up in back here and
    # then out to mCfgFile, so the next dialog, and the next Capture session, start
    # where the last one left off.  See SaveConfig / LoadConfig.
    variable mCmpInitDir {G:\Project\MB\Rex6_Hsu\W980 WS}

    # The folder this script was sourced from, worked out at load time because
    # "info script" only means anything while the file is being sourced.  Everything
    # this file reads or writes beside itself is resolved against it: the logo, and
    # the one remembered setting below.
    variable mScriptDir [file dirname [file normalize [info script]]]

    # Where mCmpInitDir is remembered between sessions.  A two-line text file next
    # to the script rather than the registry: it is readable, it is deletable, and
    # losing it only costs the remembered folder.
    variable mCfgFile [file join $mScriptDir mUtilMenu.cfg]

    # Where LogoImage looks, in order: beside the script, one level up (the logo
    # lives in tclscripts/, the script in tclscripts/capAutoLoad/), and then the
    # install path this file documents at the bottom of it.
    #
    # The last one is a belt-and-braces entry for the case where mScriptDir came out
    # wrong: "info script" is only set while a file is being SOURCED, which is how
    # every capAutoLoad script including this one is loaded, but a reload done by
    # pasting the file into the Command Window would leave it empty and the logo
    # unfindable.
    variable mLogoDirs [list \
        $mScriptDir \
        [file dirname $mScriptDir] \
        {G:/Cadence/SPB_17.4/tools/capture/tclscripts}]

    # The ASRock logo in the page selector's header, tried in this order and
    # resolved against each of mLogoDirs.
    #
    # NOT the .jpg, and this is why: the Tk that Capture ships is 8.6.5 with no Img
    # package (checked - "can't find package Img"), and core Tk reads GIF, PNG and
    # PPM/PGM only.  Handing it asrock_logo_s.jpg gives
    #
    #     couldn't recognize data in image file ".../asrock_logo_s.jpg"
    #
    # so asrock_logo_s.png - the same 120x22 image, converted once - is what is
    # actually displayed.  The .jpg is kept as the source it came from.  120 px is
    # exactly mPageLinkGap, so the logo fills the gap column without changing the
    # layout the link lines are drawn against.
    variable mLogoFiles [list asrock_logo_s.png asrock_logo_s.gif]

    # The Tk photo, created on first use and kept afterwards.  A Tk image belongs to
    # the interpreter and not to the window that shows it, so it outlives the page
    # selector being closed and must not be created again every time it opens -
    # that would leak one image per open.
    variable mLogoImage ""

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
    #   mMarkSegs   one line per wire to mark, {label x1 y1 x2 y2}.  Two sources:
    #                 nets   whatever net_compare_rule1..4 hit - see
    #                        NetlistCompare.  The label is "rule<n> <netname>".
    #                 buses  one per bus wire (N) has and (O) has not
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

    # net_compare_rule4 only: how many pins the PART behind a changed pin has to
    # have before that pin is worth a line on the page.  A part with this many pins
    # or FEWER is left alone - the rule fires on the net, the pin is listed in the
    # Command Window as skipped, and nothing is drawn.
    #
    # 5 by default, so the parts that keep being re-wired without anything really
    # changing - resistors, capacitors, diodes, single gates, small headers - do not
    # each cost a pink line, while an IC losing or gaining a connection does.  The
    # count is the placed instance's OWN pins (element 10 of a part row), so one
    # section of a multi-part package counts its own section's pins, not the
    # package's.
    #
    # 0 turns the filter off - every changed pin gets marked, which is what rule4
    # did before the filter existed.
    variable mRule4MinPins 5

    # 1 = the Parts dump prints one line per pin - pin number, pin name, the pin's
    #     connection point in doc units, and what the pin is connected to
    #     (net name / NC / unconnected).
    # 0 = the old single "pins: A B C" line of pin names.
    # Only the printout changes either way: the pins the two compares diff on are
    # the pin NAMES in element 5 of a part row, which this does not touch.  The
    # netlist compare reads the connection point whatever this is set to - it goes
    # through CollectPinInfo, not through the printout.
    variable mPinDetail 1

    # 1 = every off-page connector / power symbol / port in the Off-Page / Power /
    #     Ports dump gets a second line saying what it is attached to (net name, or
    #     NC when it is attached to nothing).
    # 0 = the old one-line "type name position" row.
    # Same rule as mPinDetail: the printout is all that changes.  PageComp's
    # Symbols diff is built by SymbolSigs out of elements 0-2 of a symbol row and
    # never sees element 3.
    variable mSymConnDetail 1

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

    # 1 = time the compare and print what each phase cost.  ON by default: the
    #     numbers are a few lines at the end of a dump that is already thousands,
    #     and "why is this slow" is not answerable without them.
    #
    #       set ::mUtilMenu::mTimeCompare 0     turns every timing line off
    #
    # Three things get printed, smallest scope first:
    #
    #   CollectPageParts   one block per page, per side - see the proc.  Splits the
    #                      parts walk into the two Dbo calls net_compare_rule4 needs
    #                      (the part's pin count, and each pin's connection point)
    #                      and everything else, so the cost of rule4's positions is
    #                      a number rather than an opinion.
    #   NetlistCompare     one line per compare, start to end, with the sizes it
    #                      worked on.
    #   the phase report   TimeReport, at the end of the whole compare, which is
    #                      where the four jobs a slow compare could be in are told
    #                      apart:
    #
    #   collect   walking the database - one iterator per part / pin / net / wire.
    #             Dbo calls, and the only way to make it cheaper is to make fewer.
    #   print     pushing the dump into the Command Window.  One puts per line, and
    #             on a real page that is thousands of lines per side - each one a UI
    #             append, which is usually the most expensive thing here by a wide
    #             margin.  mPinDetail 0 removes the biggest block of it (one line
    #             per pin), mQuiet 1 removes all of it.
    #   netlist   CollectNetlist plus net_compare_rule1..4.  Pure Tcl over rows
    #             already collected - no Dbo calls at all.
    #   diff      the Parts / Symbols / Nets / Buses signature diff.  Also pure Tcl.
    #
    # NOTE on what the per-call numbers mean.  Timing something that costs a few
    # microseconds costs microseconds itself: the two [clock microseconds] calls
    # that measure one pin's position are counted INSIDE that pin's number.  So
    # "rule4 pin pos" is an upper bound - the real Dbo cost is somewhat lower, and
    # the totals shrink a little when mTimeCompare is 0.  It is measured this way
    # round on purpose: an upper bound that says "this is not where the time goes"
    # settles the question, a lower bound would not.
    variable mTimeCompare 1

    # Where TimeMark accumulates {label ms} pairs, and the phase order they are
    # reported in.  Reset per compare by TimeReset.
    variable mTimes [list]

    # Microseconds and call counts for the two Dbo calls that exist only for
    # net_compare_rule4.  Accumulated by PartPinCount / PinHotSpotDoc and reported
    # by CollectPageParts, which resets them at the top of every page.
    variable mStatCntUs    0
    variable mStatCntCalls 0
    variable mStatPosUs    0
    variable mStatPosCalls 0
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

# Timing, for mTimeCompare.  Deliberately as cheap as it can be when it is off:
# TimeNow returns "" and every TimeMark with an empty start does nothing, so an
# instrumented proc costs one variable read per call when nobody is measuring.
#
#   set lT [::mUtilMenu::TimeNow]
#   ...work...
#   ::mUtilMenu::TimeMark "parts collect" $lT
#
# Marks with the same label add up, so a phase that runs once per side is reported
# as the total of both sides.
proc ::mUtilMenu::TimeNow { } {
    variable mTimeCompare
    if { !$mTimeCompare } {
        return ""
    }
    return [clock milliseconds]
}

proc ::mUtilMenu::TimeMark { pLabel pStart } {
    variable mTimeCompare
    variable mTimes

    if { !$mTimeCompare || $pStart eq "" } {
        return
    }
    set lMs [expr { [clock milliseconds] - $pStart }]

    for { set i 0 } { $i < [llength $mTimes] } { incr i } {
        if { [lindex $mTimes $i 0] eq $pLabel } {
            lset mTimes $i 1 [expr { [lindex $mTimes $i 1] + $lMs }]
            return
        }
    }
    lappend mTimes [list $pLabel $lMs]
}

proc ::mUtilMenu::TimeReset { } {
    variable mTimes
    set mTimes [list]
}

# The breakdown, longest phase first, with what is left over after the measured
# phases so an unmeasured cost cannot hide.  pTotalStart is the whole compare.
proc ::mUtilMenu::TimeReport { pWhat pTotalStart } {
    variable mTimeCompare
    variable mTimes

    if { !$mTimeCompare || $pTotalStart eq "" } {
        return
    }
    set lTotal [expr { [clock milliseconds] - $pTotalStart }]

    ::mUtilMenu::Out "    timing - $pWhat, $lTotal ms total"
    set lSum 0
    foreach lRec [lsort -integer -decreasing -index 1 $mTimes] {
        incr lSum [lindex $lRec 1]
        set lPct 0
        if { $lTotal > 0 } {
            set lPct [expr { round(100.0 * [lindex $lRec 1] / $lTotal) }]
        }
        ::mUtilMenu::Out [format "      %-22s %7d ms  %3d%%" \
                  [lindex $lRec 0] [lindex $lRec 1] $lPct]
    }
    ::mUtilMenu::Out [format "      %-22s %7d ms" "(everything else)" \
              [expr { $lTotal - $lSum }]]
}

proc ::mUtilMenu::Trace { pMsg } {
    variable mDebug
    ::mUtilMenu::Out "mUtil: $pMsg"
    if { $mDebug } {
        catch { capDisplayMessageBox $pMsg "mUtil" }
    }
}

#=============================================================================
# Remembered settings
#
# One setting so far - mCmpInitDir, the folder the Browse buttons start in.  It is
# written whenever a Browse changes it, so the dialog reopens where the user was
# last time, in this session and in the next one.
#
# The format is deliberately not Tcl: one "name value" line, name up to the first
# space, value the rest of the line verbatim.  A folder is free to contain spaces
# ("W980 WS" does), and sourcing a config file would mean a path with a bracket or
# a backslash in it could execute something.  Reading it back is a string
# comparison and nothing else.
#
# Unknown names are ignored rather than rejected, so an older Capture session
# reading a newer file still gets what it understands.
#=============================================================================

proc ::mUtilMenu::SaveConfig { } {
    variable mCfgFile
    variable mCmpInitDir

    if { [catch {
        set lFh [open $mCfgFile w]
        puts $lFh "# mUtilMenu remembered settings - safe to delete"
        puts $lFh "mCmpInitDir $mCmpInitDir"
        close $lFh
    } lErr] } {
        # Not fatal and not worth a message box: the folder is still remembered for
        # the rest of this session, it just will not survive a restart.  A read-only
        # install folder is the usual reason.
        ::mUtilMenu::Trace "could not write $mCfgFile -> $lErr"
        return 0
    }
    return 1
}

proc ::mUtilMenu::LoadConfig { } {
    variable mCfgFile
    variable mCmpInitDir

    if { ![file readable $mCfgFile] } {
        return 0
    }
    if { [catch {
        set lFh   [open $mCfgFile r]
        set lText [read $lFh]
        close $lFh
    } lErr] } {
        ::mUtilMenu::Trace "could not read $mCfgFile -> $lErr"
        return 0
    }

    foreach lLine [split $lText "\n"] {
        set lLine [string trimright $lLine "\r"]
        if { [string index [string trimleft $lLine] 0] eq "#" } {
            continue
        }
        set lSp [string first " " $lLine]
        if { $lSp <= 0 } {
            continue
        }
        set lName  [string range $lLine 0 [expr { $lSp - 1 }]]
        set lValue [string range $lLine [expr { $lSp + 1 }] end]

        switch -- $lName {
            mCmpInitDir {
                # Only if it is still there: a remembered folder on a network drive
                # that is not mounted today would otherwise make every Browse start
                # nowhere, which is worse than starting at the built-in default.
                if { [file isdirectory $lValue] } {
                    set mCmpInitDir $lValue
                }
            }
        }
    }
    return 1
}

# Remember one folder as the new starting point, if it is one.  Called from both
# Browse paths, which is what makes "wherever I browsed last" stick.
proc ::mUtilMenu::RememberInitDir { pDir } {
    variable mCmpInitDir

    if { $pDir eq "" || ![file isdirectory $pDir] } {
        return 0
    }
    set lNew [file nativename [file normalize $pDir]]
    if { $lNew eq $mCmpInitDir } {
        # Nothing changed - do not rewrite the file for every Browse in the same
        # folder.
        return 1
    }
    set mCmpInitDir $lNew
    ::mUtilMenu::SaveConfig
    return 1
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
        ::mUtilMenu::RememberInitDir $lDir
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
        # The folder the .DSN came out of becomes the new default - that is the
        # answer to "can it remember where I browsed to": picking a design in
        # another folder moves the Default Folder there, and it is written out, so
        # the next Browse and the next session start there.  The Default Folder
        # field on the dialog updates with it, since it is bound to the same
        # variable.
        ::mUtilMenu::RememberInitDir [file dirname $lFile]
    }
}

# The ASRock logo, as a Tk photo, or "" when there is no image to show - see
# mLogoFiles for why the .jpg is not the file being loaded.
#
# Created once and cached in mLogoImage.  The cache is rechecked against
# [image names] rather than trusted: an "image delete" from the Command Window, or
# a reload of this file, can leave the variable pointing at an image that no longer
# exists, and a label built on a stale image name is an error dialog rather than a
# missing logo.
proc ::mUtilMenu::LogoImage { } {
    variable mLogoFiles
    variable mLogoDirs
    variable mLogoImage

    if { $mLogoImage ne "" } {
        if { [lsearch -exact [image names] $mLogoImage] != -1 } {
            return $mLogoImage
        }
        set mLogoImage ""
    }
    if { [catch { package require Tk }] } {
        return ""
    }

    foreach lName $mLogoFiles {
        # An absolute name in mLogoFiles wins over every folder - file join keeps
        # the second path when it is already absolute.
        foreach lDir $mLogoDirs {
            set lPath [file join $lDir $lName]
            if { ![file readable $lPath] } {
                continue
            }
            if { [catch { set lImg [image create photo -file $lPath] } lErr] } {
                ::mUtilMenu::Trace "logo $lPath could not be loaded -> $lErr"
                continue
            }
            ::mUtilMenu::Trace "logo loaded: $lPath ([image width $lImg]x[image height $lImg])"
            set mLogoImage $lImg
            return $lImg
        }
    }
    ::mUtilMenu::Trace "no logo image found - looked for [join $mLogoFiles {, }] in [join $mLogoDirs {, }]"
    return ""
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
# net has no name of its own.
#
# Pin-to-net IS here, page-level, and it does not need the flattened occurrence
# walk (DboNetOccurrence GetNet, capDRCFramework/tcl/capProcessDRC.tcl:255) that
# an occurrence-level answer would: what NextPin hands back is a DboPortInst, and
# that object carries the connection itself.  No shipped script calls these three,
# so they are checked straight against the SWIG wrappers in
# tools/bin/orDb_Dll_Tcl64.dll instead - the argument names below are the ones its
# own "Wrong # args" strings print:
#
#   DboPortInst_GetPinNumber     self number     number is a CString&
#   DboPortInst_GetIsNoConnect   self status     the no-connect (X) marker
#   DboPortInst_GetNet           self status     the page DboNet, NULL if none
#
# so an unwired pin and a pin with an X on it are two different answers, and
# CollectPinInfo reports them as two different answers.
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

# What one page net is called, worked out from the net object alone.  Same answer
# CollectPageNets puts in element 0 of a net row and by the same route - the wire
# aliases, then NetLabel's fallbacks - but reachable from a pin, which is what
# CollectPinInfo needs and what the nets walk cannot give it.
proc ::mUtilMenu::NetLabelOf { pNet pStatus } {
    set lNullObj NULL
    set lNames   [list]

    catch {
        set lIter [$pNet NewWiresIter $pStatus]
        set lWire [$lIter NextWire $pStatus]
        while { $lWire != $lNullObj } {
            foreach lName [::mUtilMenu::WireAliases $lWire $pStatus] {
                if { [lsearch -exact $lNames $lName] == -1 } {
                    lappend lNames $lName
                }
            }
            set lWire [$lIter NextWire $pStatus]
        }
        catch { delete_DboNetWiresIter $lIter }
    }
    return [::mUtilMenu::NetLabel $pNet $lNames]
}

# Where one pin's connection point is, as doc-unit integers {x y}.
#
# A pin is a line with two ends and only one of them is the connection point:
#
#   GetOffsetStartPoint   where the pin leaves the part body
#   GetOffsetHotSpot      the free end, which is where a net wire lands
#
# The Offset* pair is the page-level one - the instance's own placement, rotation
# and mirroring are already in the numbers - which is what makes them directly
# comparable with the wire endpoints WireSegDoc returns.  Both calls are the ones
# capPDFExport/tcl/capPdfUtil.tcl:1203-1209 uses to place a pin on the exported
# page, so they are page coordinates there too.
#
# {} when the call does not work, so a caller can say "no position for this pin"
# instead of marking (0,0).  net_compare_rule4 is the one that needs it.
# Timed into mStatPosUs / mStatPosCalls when mTimeCompare is on, because this is
# the call that got blamed for the compare being slow and a number settles it.  Off,
# it costs one variable read.
proc ::mUtilMenu::PinHotSpotDoc { pPin pStatus } {
    variable mTimeCompare
    variable mStatPosUs
    variable mStatPosCalls

    set lT0 0
    if { $mTimeCompare } {
        set lT0 [clock microseconds]
    }

    set lOut [list]
    catch {
        set lPt  [$pPin GetOffsetHotSpot $pStatus]
        set lOut [list [DboTclHelper_sGetCPointX $lPt] [DboTclHelper_sGetCPointY $lPt]]
    }

    if { $mTimeCompare } {
        incr mStatPosUs [expr { [clock microseconds] - $lT0 }]
        incr mStatPosCalls
    }
    return $lOut
}

# How many pins a placed instance has, WITHOUT walking its pins - one call instead
# of an iterator, so it can be asked before the pin loop and used to decide whether
# that loop needs to read pin positions at all.
#
# DboPartInst_GetPinCount and DboPartInst_sGetPinCount are both in
# orDb_Dll_Tcl64.dll and neither is in Appendix A of the Tcl/Tk PDF; no shipped
# script calls either, so both spellings are tried and anything that does not come
# back as a plain integer counts as "could not tell".
#
# -1 = could not tell.  Every caller has to treat that as "assume it is a big part"
# - guessing small would silently switch net_compare_rule4 off.
# Timed into mStatCntUs / mStatCntCalls, same as PinHotSpotDoc: the two of them are
# the whole Dbo cost net_compare_rule4 adds to the parts walk, and they are reported
# side by side so it is obvious which one is worth anything.
proc ::mUtilMenu::PartPinCount { pPart } {
    variable mTimeCompare
    variable mStatCntUs
    variable mStatCntCalls

    set lT0 0
    if { $mTimeCompare } {
        set lT0 [clock microseconds]
    }

    set lCnt ""
    catch { set lCnt [DboPartInst_sGetPinCount $pPart] }
    if { ![string is integer -strict $lCnt] } {
        set lCnt ""
        catch { set lCnt [$pPart GetPinCount] }
    }
    if { ![string is integer -strict $lCnt] } {
        set lCnt -1
    }

    if { $mTimeCompare } {
        incr mStatCntUs [expr { [clock microseconds] - $lT0 }]
        incr mStatCntCalls
    }
    return $lCnt
}

# One pin of one placed instance, as {name number noConnect netLabel position}:
#
#   name       GetPinName      - "VCC", "GND", "A0"
#   number     GetPinNumber    - the physical pin number, "" when the part has none
#   noConnect  GetIsNoConnect  - 1 when the pin carries a no-connect (X) marker
#   netLabel   GetNet          - the net's name, "" when the pin is on no net
#   position   GetOffsetHotSpot- {x y} doc units, where a wire meets this pin, or
#                                {} - see PinHotSpotDoc
#
# Element 4 is only read by the netlist compare (CollectNetlist -> element 3 ->
# net_compare_rule4).  Printing and both part signatures stay on elements 0-3, so
# adding it changed no compare's answer.
#
# pWantPos 0 leaves element 4 empty without asking the database for it.  Reading it
# costs three Dbo calls per pin - GetOffsetHotSpot plus the two CPoint getters - on
# top of the four this proc already makes, and on a page with a few thousand pins
# that is the difference worth not paying for a pin nothing will ever look at.  The
# position is also skipped for a pin on no net, whatever pWantPos says: a pin that
# is on no net is in no netlist, so rule4 can never reach it.  CollectPageParts is
# where the decision is made - see mRule4MinPins.
#
# noConnect and netLabel are independent: a pin can be flagged NC and still sit on
# a net (which is a design error worth seeing), and a pin can be on no net without
# anyone having marked it NC (which is just an unwired pin).  PinConnStr is what
# turns the pair into the one phrase the dump prints.
#
# pCacheName is the name of an array in the CALLER used to remember one net label
# per net object, because every pin of every part on the page asks about the same
# handful of nets and each answer costs a walk over that net's wires.  SWIG names
# a pointer's Tcl handle after the address, so the same DboNet is the same key
# whether it came from a pin or from the page's nets iterator.
proc ::mUtilMenu::CollectPinInfo { pPin pStatus pCacheName {pWantPos 1} } {
    upvar 1 $pCacheName lCache
    set lNullObj NULL

    set lName [::mUtilMenu::CStr $pPin GetPinName]
    set lNum  [::mUtilMenu::CStr $pPin GetPinNumber]

    set lNC 0
    catch {
        if { [$pPin GetIsNoConnect $pStatus] } {
            set lNC 1
        }
    }

    set lNet    ""
    set lNetObj ""
    catch { set lNetObj [$pPin GetNet $pStatus] }
    if { $lNetObj ne "" && $lNetObj != $lNullObj } {
        if { [info exists lCache($lNetObj)] } {
            set lNet $lCache($lNetObj)
        } else {
            set lNet [::mUtilMenu::NetLabelOf $lNetObj $pStatus]
            set lCache($lNetObj) $lNet
        }
    }

    # A pin on no net is in no netlist, so its position can never be used - the
    # $lNet test is not an optimisation for its own sake, it is the same "nothing
    # will look at this" rule pWantPos carries.
    set lPos [list]
    if { $pWantPos && $lNet ne "" } {
        set lPos [::mUtilMenu::PinHotSpotDoc $pPin $pStatus]
    }

    return [list $lName $lNum $lNC $lNet $lPos]
}

# "what is this thing joined to", in the one wording both dumps use.  Pins and
# symbols share it so that "NC (unconnected)" cannot come to mean two slightly
# different things in two places.
#
#   pNoConnect  1 when the object carries an explicit no-connect (X) marker.
#               Only pins can - see SymbolConn.
#   pNetLabel   the net's name, "" when the object is on no net at all
proc ::mUtilMenu::ConnStr { pNoConnect pNetLabel } {
    if { $pNetLabel ne "" } {
        # Flagged NC and wired anyway - say both, rather than picking one and
        # hiding a contradiction the schematic really does contain.
        if { $pNoConnect } {
            return "net: $pNetLabel   (but flagged NC)"
        }
        return "net: $pNetLabel"
    }
    if { $pNoConnect } {
        return "NC (no-connect marker)"
    }
    return "NC (unconnected)"
}

# The connection half of one CollectPinInfo record, as the dump prints it.
proc ::mUtilMenu::PinConnStr { pPin } {
    return [::mUtilMenu::ConnStr [lindex $pPin 2] [lindex $pPin 3]]
}

# What one off-page connector / power symbol / port is joined to - the same
# question CollectPinInfo asks of a pin, but these are not pins and the route is
# not the same one:
#
#   All three are DboNetSymbolInstance underneath - the class that carries
#   GetNet, GetWire and IsBus (checked against tools/bin/orDb_Dll_Tcl64.dll;
#   DboOffPageConnector / DboGlobal / DboPort add almost nothing of their own,
#   which is why the existing GetName / GetLocation calls work on all three).
#   No shipped script calls GetNet on one, so it is tried and then fallen back
#   from rather than trusted:
#
#     1  GetNet   the page DboNet -> NetLabelOf, the same name the Nets section
#                 prints
#     2  GetWire  the wire the symbol sits on, when GetNet gave nothing - its
#                 aliases are where a net name comes from anyway (see NetLabel)
#     3  ""       nothing is attached
#
# There is deliberately no NC flag here.  GetIsNoConnect exists on DboPortInst /
# DboSymbolPin only - a no-connect marker is something you put on a PIN.  A symbol
# is either on a net or on nothing, so ConnStr is called with pNoConnect 0 and
# "not attached to anything" prints as "NC (unconnected)".
#
# pCacheName is a net-label cache in the caller, exactly as CollectPinInfo uses.
proc ::mUtilMenu::SymbolConn { pObj pStatus pCacheName } {
    upvar 1 $pCacheName lCache
    set lNullObj NULL

    set lNetObj ""
    catch { set lNetObj [$pObj GetNet $pStatus] }
    if { $lNetObj ne "" && $lNetObj != $lNullObj } {
        if { ![info exists lCache($lNetObj)] } {
            set lCache($lNetObj) [::mUtilMenu::NetLabelOf $lNetObj $pStatus]
        }
        return $lCache($lNetObj)
    }

    # No net object - try the wire the symbol is attached to.  A wire that is not
    # part of a named net still carries its own aliases, and DboWire has GetNet of
    # its own to try first.
    set lWire ""
    catch { set lWire [$pObj GetWire $pStatus] }
    if { $lWire eq "" || $lWire == $lNullObj } {
        return ""
    }

    set lNetObj ""
    catch { set lNetObj [$lWire GetNet $pStatus] }
    if { $lNetObj ne "" && $lNetObj != $lNullObj } {
        if { ![info exists lCache($lNetObj)] } {
            set lCache($lNetObj) [::mUtilMenu::NetLabelOf $lNetObj $pStatus]
        }
        return $lCache($lNetObj)
    }

    set lNames [::mUtilMenu::WireAliases $lWire $pStatus]
    if { [llength $lNames] > 0 } {
        return [join [lsort -dictionary $lNames] { = }]
    }
    return ""
}

# Parts placed on one page.  Returns one row per placed instance:
#
#   0 Part Reference   3 source .olb   6 PCB Footprint   9 bounding box, doc units
#   1 Value            4 position      7 Part_Number    10 per-pin detail
#   2 package name     5 pin names     8 Optional
#
# Element 9 is {left top right bottom} off ObjBBoxDoc - the same box element 4
# prints, unrounded.  Only the marker rectangles use it.
#
# Element 10 is one CollectPinInfo record per pin, in the same order as the pin
# names in element 5.  PrintPartRows prints it, and CollectNetlist builds the
# netlist out of it - the pin's net label and the pin's own position both live
# there, which is what net_compare_rule4 needs.
#
# Printing and both signatures stay on elements 0-8, which is why neither 9 nor 10
# changed what the diff sees: the pins PartSig and PartCmpFields compare are still
# element 5's plain names.
#
# Collecting and printing are separate because the reference compare needs the
# rows, not the printout.
#
# TIMING (mTimeCompare).  This is the expensive walk - one iterator per part and
# another per pin - and it is the one net_compare_rule4 added Dbo calls to, so it
# reports its own breakdown when it is done:
#
#     timing: CollectPageParts 1843 ms - 312 part(s), 2971 pin(s)
#               rule4 part pin count      14 ms over  312 call(s)
#               rule4 pin position       431 ms over 1204 call(s), 1767 pin(s) skipped
#               the rest of the walk    1398 ms
#
# The first two lines are everything rule4 costs here; the third is what the parts
# walk cost before rule4 existed.  "skipped" is the pins that never got asked for a
# position - a part of mRule4MinPins pins or fewer, or a pin on no net.
proc ::mUtilMenu::CollectPageParts { pPage } {
    variable mRule4MinPins
    variable mTimeCompare
    variable mStatCntUs
    variable mStatCntCalls
    variable mStatPosUs
    variable mStatPosCalls

    # Per page, not per session: PartPinCount and PinHotSpotDoc add to these from
    # wherever they are called, so the block below only means anything if the
    # counters start at zero here.
    set mStatCntUs    0
    set mStatCntCalls 0
    set mStatPosUs    0
    set mStatPosCalls 0
    set lPinTotal     0
    set lT0           [::mUtilMenu::TimeNow]

    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    # net object -> net label, for the whole page: see CollectPinInfo.
    array set lNetCache {}

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

            # Ask how many pins the part has BEFORE walking them, and skip the pin
            # position read entirely on a part net_compare_rule4 would throw away
            # anyway: three Dbo calls per pin, and the passives are most of the
            # parts on a page.  A part whose count cannot be read counts as big, so
            # a missing GetPinCount costs speed and never correctness.
            set lWantPos 1
            set lFastCnt [::mUtilMenu::PartPinCount $lPart]
            if { $lFastCnt >= 0 && $lFastCnt <= $mRule4MinPins } {
                set lWantPos 0
            }

            set lPins [list]
            set lPinInfo [list]
            catch {
                set lPinIter [$lPart NewPinsIter $lStatus]
                set lPin     [$lPinIter NextPin $lStatus]
                while { $lPin != $lNullObj } {
                    set lRec [::mUtilMenu::CollectPinInfo $lPin $lStatus lNetCache \
                                  $lWantPos]
                    lappend lPins    [lindex $lRec 0]
                    lappend lPinInfo $lRec
                    set lPin [$lPinIter NextPin $lStatus]
                }
                catch { delete_DboPartInstPinsIter $lPinIter }
            }

            incr lPinTotal [llength $lPinInfo]
            lappend lRows [list $lRef $lVal $lPkg $lLib $lLoc $lPins $lFp $lPn $lOpt \
                                [::mUtilMenu::ObjBBoxDoc $lPart] $lPinInfo]
        }
        set lInst [$lIter NextPartInst $lStatus]
    }

    catch { delete_DboPagePartInstsIter $lIter }
    catch { $lStatus -delete }

    if { $mTimeCompare } {
        set lMs   [expr { [clock milliseconds] - $lT0 }]
        set lCntM [expr { $mStatCntUs / 1000 }]
        set lPosM [expr { $mStatPosUs / 1000 }]
        ::mUtilMenu::Out [format \
            "    timing: CollectPageParts %d ms - %d part(s), %d pin(s)" \
            $lMs [llength $lRows] $lPinTotal]
        ::mUtilMenu::Out [format \
            "              rule4 part pin count %6d ms over %5d call(s)" \
            $lCntM $mStatCntCalls]
        ::mUtilMenu::Out [format \
            "              rule4 pin position   %6d ms over %5d call(s), %d pin(s) skipped" \
            $lPosM $mStatPosCalls [expr { $lPinTotal - $mStatPosCalls }]]
        ::mUtilMenu::Out [format \
            "              the rest of the walk %6d ms" \
            [expr { $lMs - $lCntM - $lPosM }]]
    }
    return $lRows
}

# Print what CollectPageParts returned.  Returns the count.
# The property line is printed even when the properties are empty, so every part
# costs the same number of lines and the two dumps stay aligned.
#
# Pins are printed one per line - number, name, connection point and what the pin
# is joined to - whenever the row carries the element-10 detail and mPinDetail is
# on.  The pins are listed in pin-number order rather than in the database order
# they were read in, so the (O) and (N) dumps of the same part line up when read
# side by side.  mPinDetail 0 brings back the one-line "pins: A B C" list of names.
#
# The connection point is printed in RAW DOC UNITS whatever mCoordMode says, with
# no rounding, because it is the number net_compare_rule4 matches against a wire
# endpoint.  Set mCoordMode to "doc" to have the rest of the dump print in the same
# units and the two line up by eye.
#
# "-" means there is no position on the record, which is one of three things, in
# order of how often it happens:
#
#   the part has mRule4MinPins pins or fewer, or the pin is on no net - rule4 would
#     never look at the position, so CollectPageParts does not spend the Dbo calls
#     reading it.  Normal, and the reason most passives show "-".
#   GetOffsetHotSpot did not work on this pin - the only case that would stop rule4
#     marking something it should have marked.  Tell the two apart by the part: a
#     "-" on a big IC's connected pin is the one worth chasing.
proc ::mUtilMenu::PrintPartRows { pRows } {
    variable mPinDetail

    foreach lRow [lsort -dictionary -index 0 $pRows] {
        ::mUtilMenu::Out [format "    %-10s %-12s %-16s %s" \
                  [lindex $lRow 0] [lindex $lRow 2] [lindex $lRow 3] [lindex $lRow 4]]
        ::mUtilMenu::Out [format "               Value: %-16s PCB Footprint: %-16s Part_Number: %-16s Optional: %s" \
                  [::mUtilMenu::OrDash [lindex $lRow 1]] \
                  [::mUtilMenu::OrDash [lindex $lRow 6]] \
                  [::mUtilMenu::OrDash [lindex $lRow 7]] \
                  [::mUtilMenu::OrDash [lindex $lRow 8]]]

        set lPins [lindex $lRow 5]
        set lInfo [lindex $lRow 10]

        if { $mPinDetail && [llength $lInfo] > 0 } {
            ::mUtilMenu::Out [format "               pins (%d):   Pin Number  Pin Name             Pin Pos (doc)     Connection" \
                      [llength $lInfo]]
            foreach lPin [lsort -dictionary -index 1 $lInfo] {
                set lAt "-"
                if { [llength [lindex $lPin 4]] == 2 } {
                    set lAt "([lindex [lindex $lPin 4] 0],[lindex [lindex $lPin 4] 1])"
                }
                ::mUtilMenu::Out [format "                           %-11s %-20s %-17s %s" \
                          [::mUtilMenu::OrDash [lindex $lPin 1]] \
                          [::mUtilMenu::OrDash [lindex $lPin 0]] \
                          $lAt \
                          [::mUtilMenu::PinConnStr $lPin]]
            }
        } elseif { [llength $lPins] > 0 } {
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

# Refcompare, both halves.  Parts first, exactly as before; then Off-Page / Power
# / Ports, when the caller collected them.  Returns the text for the report
# window.
#
# The symbol rows are optional so that anything already calling DumpRefCompare
# with two arguments keeps working and keeps getting a Parts-only answer.
proc ::mUtilMenu::DumpRefCompare { pRowsO pRowsN {pSymsO {}} {pSymsN {}} } {
    set lSummary [::mUtilMenu::DumpRefPartCompare $pRowsO $pRowsN]

    if { [llength $pSymsO] > 0 || [llength $pSymsN] > 0 } {
        ::mUtilMenu::Out "  Off-Page / Power / Ports - by type + name"
        append lSummary "\n\nOff-Page / Power / Ports:\n" \
                        [::mUtilMenu::DumpRefSymbolCompare $pSymsO $pSymsN]
    }
    return $lSummary
}

# Prints the compare and returns a one-line summary for the message box.
proc ::mUtilMenu::DumpRefPartCompare { pRowsO pRowsN } {
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
# Reference compare, symbols half - Off-Page / Power / Ports matched by type and
# name, with the connection as the thing being compared.
#
# Parts can be matched one for one because a Part Reference is unique on a page.
# A symbol name is NOT: a page can carry twenty GND symbols and eight OFFPAGE
# ADDR0 connectors, all legitimately.  So a key here is "type + name" and what
# hangs off it is the whole LIST of connections under that name, one per instance,
# sorted.  Two sides differ when those lists differ, which catches a connection
# that changed AND a symbol that was added or deleted under an existing name.
#
# Position is deliberately not part of any of it, the same way Refcompare ignores
# where a part sits: the question is "is this still wired the same", not "is it
# still in the same place".  PageComp is the compare that looks at position.
#-----------------------------------------------------------------------------

# "GLOBAL GND" -> {"net: GND" "net: GND" "NC (unconnected)"}, sorted so two sides
# can be compared with a plain string compare.
proc ::mUtilMenu::IndexSymbolRows { pArrName pRows } {
    upvar 1 $pArrName lArr

    foreach lRow $pRows {
        set lKey [list [lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]]]
        lappend lArr($lKey) [::mUtilMenu::ConnStr 0 [lindex $lRow 3]]
    }
    foreach lKey [array names lArr] {
        set lArr($lKey) [lsort -dictionary $lArr($lKey)]
    }
}

# The two halves of a key back as one printable string.
proc ::mUtilMenu::SymKeyStr { pKey } {
    return [format "%-8s %s" [lindex $pKey 0] [lindex $pKey 1]]
}

# A list of connections as "net: GND x19, NC (unconnected) x2" - twenty GND
# symbols would otherwise print the same phrase twenty times.
proc ::mUtilMenu::ConnCountStr { pConns } {
    array set lN {}
    foreach lConn $pConns {
        if { [info exists lN($lConn)] } {
            incr lN($lConn)
        } else {
            set lN($lConn) 1
        }
    }

    set lOut [list]
    foreach lConn [lsort -dictionary [array names lN]] {
        if { $lN($lConn) > 1 } {
            lappend lOut "$lConn x$lN($lConn)"
        } else {
            lappend lOut $lConn
        }
    }
    return [join $lOut {, }]
}

# Prints the symbol compare and returns its summary for the report window.
proc ::mUtilMenu::DumpRefSymbolCompare { pSymsO pSymsN } {
    variable mRefListMax

    array set lO {}
    array set lN {}
    ::mUtilMenu::IndexSymbolRows lO $pSymsO
    ::mUtilMenu::IndexSymbolRows lN $pSymsN

    set lAdd    [list]
    set lRemove [list]
    set lChange [list]

    foreach lKey [lsort -dictionary [array names lN]] {
        if { ![info exists lO($lKey)] } {
            lappend lAdd $lKey
        } elseif { $lO($lKey) ne $lN($lKey) } {
            lappend lChange $lKey
        }
    }
    foreach lKey [lsort -dictionary [array names lO]] {
        if { ![info exists lN($lKey)] } {
            lappend lRemove $lKey
        }
    }

    if { [llength $lAdd] == 0 && [llength $lRemove] == 0 && [llength $lChange] == 0 } {
        ::mUtilMenu::Out "    all the same"
        return "all the same"
    }

    if { [llength $lAdd] > 0 } {
        ::mUtilMenu::Out "    Add symbols ([llength $lAdd]) - in N only"
        foreach lKey $lAdd {
            ::mUtilMenu::Out [format "        %-26s %s" [::mUtilMenu::SymKeyStr $lKey] \
                      [::mUtilMenu::ConnCountStr $lN($lKey)]]
        }
    }
    if { [llength $lRemove] > 0 } {
        ::mUtilMenu::Out "    Remove symbols ([llength $lRemove]) - in O only"
        foreach lKey $lRemove {
            ::mUtilMenu::Out [format "        %-26s %s" [::mUtilMenu::SymKeyStr $lKey] \
                      [::mUtilMenu::ConnCountStr $lO($lKey)]]
        }
    }

    # Same type and name on both sides, wired differently - a net rename, a symbol
    # that came off its wire, or one more / one fewer symbol under that name.
    if { [llength $lChange] > 0 } {
        ::mUtilMenu::Out "    Changed symbols ([llength $lChange]) - same type + name, different connection"
        foreach lKey $lChange {
            ::mUtilMenu::Out "        [::mUtilMenu::SymKeyStr $lKey]"
            ::mUtilMenu::Out "                   O: [::mUtilMenu::ConnCountStr $lO($lKey)]"
            ::mUtilMenu::Out "                   N: [::mUtilMenu::ConnCountStr $lN($lKey)]"
        }
    }

    set lCounts "Add: [llength $lAdd]    Remove: [llength $lRemove]    Changed: [llength $lChange]"
    ::mUtilMenu::Out "    ($lCounts)"

    set lSummary $lCounts
    foreach lPair [list [list "Add    " $lAdd] [list "Remove " $lRemove] \
                        [list "Changed" $lChange]] {
        if { [llength [lindex $lPair 1]] == 0 } {
            continue
        }
        # join, not SymKeyStr: the report window is proportional text, so the
        # column padding SymKeyStr adds for the Command Window would only show up
        # here as a double space in the middle of "OFFPAGE  ADDR2".
        set lNames [list]
        foreach lKey [lindex $lPair 1] {
            lappend lNames [join $lKey { }]
        }
        append lSummary "\n[lindex $lPair 0] : [::mUtilMenu::RefListStr $lNames $mRefListMax]"
    }
    return $lSummary
}

#-----------------------------------------------------------------------------
# Netlist - one line per net, "<net> <global> <ref>.<pin> <ref>.<pin> ...":
#
#     +VCC1.8V     1  HC32.2 HC408.1
#     SDA          0  U7.14 R21.1
#
# The flag is 1 when the net leaves the page and 0 when it does not.  Nothing
# here is compared yet - PageComp prints both sides and stops.
#
# Built entirely out of the rows the dump already collected, so listing the
# netlist costs no second walk over the database.
#-----------------------------------------------------------------------------

# The net names the Off-Page / Power / Ports section put on this page.  A net
# named here has a symbol on it that carries it off the page, which is what makes
# it Global (1); every other net is Local to the page (0).
#
# Both halves of a symbol row are indexed - the symbol's own name (element 1) and
# the net it is actually attached to (element 3).  For a power symbol those are
# the same string, but an off-page connector is free to be named something other
# than the net it sits on, and either spelling should still say "this net leaves
# the page".
proc ::mUtilMenu::GlobalNetIndex { pArrName pSymRows } {
    upvar 1 $pArrName lArr

    foreach lRow $pSymRows {
        foreach lIdx { 1 3 } {
            set lName [lindex $lRow $lIdx]
            if { $lName ne "" } {
                set lArr($lName) 1
            }
        }
    }
}

# One page's netlist, as records of {netName global pins pinDetail}.
#
# Element 3 is the same pins again, each with the doc-unit position of its
# connection point and the number of pins the part it belongs to has:
#
#     {{HC32.2 1200 800 20} {R15.1 2400 800 2} ...}
#      pin      x    y   pins-on-that-part
#
# sorted the same way element 2 is.  A pin whose position could not be read
# (PinHotSpotDoc gave {}) is still in the list, with an empty position, so the two
# elements always hold the same pins - net_compare_rule4 says "no position" about
# it rather than quietly losing the pin.
#
# The pin count is the placed instance's own pin count, and it is here rather than
# worked out later because "R15.1" cannot be taken apart again reliably - a Part
# Reference is free to contain a dot.  net_compare_rule4 is what reads it, against
# mRule4MinPins.
#
# Every pin of every part already carries the name of the net it sits on -
# element 3 of a CollectPinInfo record - so grouping the part pins by that name IS
# the netlist.  A pin on no net (unwired, or carrying only a no-connect marker)
# joins nothing and is left out.
#
# The nets rows seed the table first, so a net the Nets section found but no part
# pin sits on - a stub wire, a net running only between two off-page connectors -
# is listed with an empty pin list instead of quietly disappearing.
#
# Pins are named "<Part Reference>.<Pin Number>" and both the nets and the pins
# within a net are sorted, so two dumps of the same page always read the same way
# round.  That is dictionary order, so HC32.2 comes before HC408.1.
proc ::mUtilMenu::CollectNetlist { pDict } {
    array set lGlobal {}
    ::mUtilMenu::GlobalNetIndex lGlobal [dict get $pDict symbols]

    array set lPins {}
    array set lPos  {}
    foreach lRow [dict get $pDict nets] {
        set lName [lindex $lRow 0]
        if { $lName ne "" && ![info exists lPins($lName)] } {
            set lPins($lName) [list]
            set lPos($lName)  [list]
        }
    }

    foreach lRow [dict get $pDict parts] {
        set lRef [lindex $lRow 0]
        if { $lRef eq "" } {
            set lRef "?"
        }
        # How many pins this part has, counted once per part rather than per pin.
        set lPinCount [llength [lindex $lRow 10]]
        foreach lPin [lindex $lRow 10] {
            set lNet [lindex $lPin 3]
            if { $lNet eq "" } {
                continue
            }
            # A netlist names a pin by its number; parts that have no pin numbers
            # fall back to the pin name, so the entry still says which pin it was
            # rather than ending in a bare dot.
            set lNum [lindex $lPin 1]
            if { $lNum eq "" } {
                set lNum [::mUtilMenu::OrDash [lindex $lPin 0]]
            }
            lappend lPins($lNet) "$lRef.$lNum"
            lappend lPos($lNet)  [list "$lRef.$lNum" \
                                       [lindex [lindex $lPin 4] 0] \
                                       [lindex [lindex $lPin 4] 1] \
                                       $lPinCount]
        }
    }

    set lOut [list]
    foreach lNet [lsort -dictionary [array names lPins]] {
        set lFlag 0
        if { [info exists lGlobal($lNet)] } {
            set lFlag 1
        }
        set lThisPos [list]
        if { [info exists lPos($lNet)] } {
            set lThisPos [lsort -dictionary -index 0 $lPos($lNet)]
        }
        lappend lOut [list $lNet $lFlag [lsort -dictionary $lPins($lNet)] $lThisPos]
    }
    return $lOut
}

# Print what CollectNetlist returned.  Returns the count.
proc ::mUtilMenu::PrintNetlist { pRecs } {
    foreach lRec $pRecs {
        # trimright: a net that no part pin sits on would otherwise print its flag
        # and then a trailing space.
        ::mUtilMenu::Out [string trimright [format "        %-28s %d %s" \
                  [lindex $lRec 0] [lindex $lRec 1] [join [lindex $lRec 2] { }]]]
    }
    return [llength $pRecs]
}

# Both sides' netlists, side by side in the Command Window.  A listing, printed
# before the compare that reads the same two netlists - see NetlistCompare, which
# is what the pink DASH lines now come from.
#
# Takes what CollectNetlist returned rather than the page dicts, so the caller can
# build each netlist once and use it twice.
proc ::mUtilMenu::DumpNetlists { pRecsO pRecsN } {
    foreach lSide [list [list O $pRecsO] [list N $pRecsN]] {
        set lRecs [lindex $lSide 1]
        set lGlob 0
        foreach lRec $lRecs {
            incr lGlob [lindex $lRec 1]
        }
        ::mUtilMenu::Out "    Netlist ([lindex $lSide 0]) - net, 1 = global / 0 = local, then Part_Reference.Pin_Number"
        ::mUtilMenu::PrintNetlist $lRecs
        ::mUtilMenu::Out "      ([llength $lRecs] net(s), $lGlob global)"
    }
}

#-----------------------------------------------------------------------------
# Netlist compare - the four rules that decide which pink DASH lines PageComp
# draws on (N)'s page.
#
# This REPLACED the old rule, which was the Nets signature diff: a net of (N)
# whose name-plus-wire-coordinates line did not appear in (O) got a line over
# every one of its wires, so a wire nudged half a grid square counted as a
# difference and a net rewired between two parts that kept their wires did not.
# The Nets section is still dumped and still diffed for the report, but it no
# longer marks anything - the netlist does, and the netlist is connectivity:
# which parts' pins sit on a net, and whether the net leaves the page.
#
# The rules are tried in order and the first one that fits a net is the one that
# reports it - they are numbered here exactly as the requirement numbers them, so
# a rule can be changed on its own:
#
#   net_compare_rule1  (N) has a net that no part pin sits on AND the net is
#                      local (the netlist's 1 = global / 0 = local bit is 0).
#                      A wire going nowhere.  (O) is not consulted at all - the
#                      net is marked whether (O) had it or not.
#                      -> a line over every wire of the net
#   net_compare_rule2  (N) has the net, (O)'s netlist has no net of that name.
#                      -> a line over every wire of the net
#   net_compare_rule3  both have the net, and the global/local bit differs.  A
#                      net that used to leave the page and now does not (or the
#                      other way round) is a different net.
#                      -> a line over every wire of the net
#   net_compare_rule4  both have the net with the same global/local bit, but the
#                      pins on it are not the same.  Only the part that changed
#                      is marked, and only when it is a part worth marking:
#
#                        pins on the part > mRule4MinPins (5)
#                            the pin is located by its own connection point, and
#                            the wire of that net which touches that point is the
#                            one that gets the line
#                        pins on the part <= mRule4MinPins
#                            not processed at all.  The pin is listed as skipped in
#                            the Command Window, gets no line, and does not appear
#                            in the report - a resistor or a capacitor moved from
#                            one net to another is noise at this level, and the
#                            Parts diff is where it belongs.
#
#                      The count is the part's own pin count, taken from the
#                      netlist record (CollectNetlist element 3), not worked out
#                      from the pin's name.
#                      A pin (O) had and (N) has not is reported and NOT marked -
#                      there is no position on (N)'s page for it (the part or the
#                      pin is gone), and the Parts diff is what catches it.  It is
#                      held to the same pin count, out of (O)'s netlist, so a
#                      rewired 2-pin part is not skipped at one end of the change
#                      and reported at the other.
#
# A net is matched between the two sides BY NAME, which is the only key a netlist
# has, and CollectNetlist files one record per name - so two nets that end up with
# the same label are one net here.  Nets with no name of their own all come back as
# "(unnamed)" (see NetLabel), which means a page carrying several of those has them
# merged into one entry, and rule1 only fires on that entry when NONE of them
# carries a part pin.  Naming the nets is the fix; there is nothing else to key on.
#
# Returns {found gone skipped}:
#   found    one {rule net detail segs short} record per finding
#              rule    1..4, which rule reported it
#              net     the net's name
#              detail  the one-line reason, for the Command Window
#              segs    the doc-unit {x1 y1 x2 y2} quads to draw - EMPTY when the
#                      finding has no wire to draw on, which is reported rather
#                      than dropped
#              short   what the report window calls it: the net name, plus the pin
#                      in brackets for rule 4, which is per-pin and not per-net
#   gone     the names of nets in (O)'s netlist and not in (N)'s, for the report
#            only: there is nothing on (N)'s page to mark.
#   skipped  one line per rule4 pin the mRule4MinPins filter dropped.  Command
#            Window only - it is deliberately not a finding, so it neither marks
#            anything nor stops the compare saying "all the same".
#-----------------------------------------------------------------------------

# Net name -> every wire of that net, as doc-unit quads.  Element 2 of a
# CollectPageNets row, gathered per name because that is the key the netlist uses.
# Two net objects that end up with the same label contribute to the same entry,
# which is the same answer either way: a rule that fires on the name marks all the
# wires that name covers.
proc ::mUtilMenu::NetGeomIndex { pArrName pNetRows } {
    upvar 1 $pArrName lArr

    foreach lRow $pNetRows {
        set lName [lindex $lRow 0]
        if { $lName eq "" } {
            continue
        }
        if { ![info exists lArr($lName)] } {
            set lArr($lName) [list]
        }
        foreach lQuad [lindex $lRow 2] {
            lappend lArr($lName) $lQuad
        }
    }
}

# Pins in pPinsN that are not in pPinsO, as a multiset - two pins of the same name
# on one net (which a schematic should not have, but can) do not collapse into one.
# Both lists come out of CollectNetlist element 2 and are already sorted.
proc ::mUtilMenu::PinMultisetDiff { pPinsO pPinsN } {
    array set lHave {}
    foreach lPin $pPinsO {
        if { [info exists lHave($lPin)] } { incr lHave($lPin) } else { set lHave($lPin) 1 }
    }

    set lOut [list]
    foreach lPin $pPinsN {
        if { [info exists lHave($lPin)] && $lHave($lPin) > 0 } {
            incr lHave($lPin) -1
            continue
        }
        lappend lOut $lPin
    }
    return $lOut
}

# "HC32.2" -> every position filed under it in one netlist record's element 3.
# A list, not a single point: the same pin name can legitimately appear twice when
# two instances share a Part Reference, and marking both is the safe answer.
# A pin whose position could not be read contributes nothing, so the caller sees an
# empty list and says so.
proc ::mUtilMenu::PinPosIndex { pArrName pRec } {
    upvar 1 $pArrName lArr

    foreach lEntry [lindex $pRec 3] {
        set lKey [lindex $lEntry 0]
        set lX   [lindex $lEntry 1]
        set lY   [lindex $lEntry 2]
        if { $lX eq "" || $lY eq "" } {
            continue
        }
        if { ![info exists lArr($lKey)] } {
            set lArr($lKey) [list]
        }
        if { [lsearch -exact $lArr($lKey) [list $lX $lY]] == -1 } {
            lappend lArr($lKey) [list $lX $lY]
        }
    }
}

# "HC32.2" -> how many pins the part behind it has, out of the same element 3.
# net_compare_rule4 weighs that against mRule4MinPins.
#
# The LARGEST count wins when one pin name is filed twice, which only happens when
# two placed instances carry the same Part Reference: the bigger part is the one
# worth marking, and taking the smaller one would silence rule4 on a real IC
# because a stray 2-pin part shares its reference.
#
# A pin with no count - which should not happen, every pin comes off a part row -
# is simply absent, and rule4 treats absent as "cannot tell, do not mark".
proc ::mUtilMenu::PinCountIndex { pArrName pRec } {
    upvar 1 $pArrName lArr

    foreach lEntry [lindex $pRec 3] {
        set lKey [lindex $lEntry 0]
        set lCnt [lindex $lEntry 3]
        if { $lCnt eq "" } {
            continue
        }
        if { ![info exists lArr($lKey)] || $lCnt > $lArr($lKey) } {
            set lArr($lKey) $lCnt
        }
    }
}

# Which wires of one net touch a point, comparing the raw doc-unit integers:
#
#   endpoint  one of the wire's two ends IS the point.  The normal case - a wire
#             drawn to a pin ends on that pin's connection point.
#   on-wire   the point lies between the two ends of a horizontal or vertical
#             wire.  A pin tapped in the middle of a run, which Capture allows;
#             a diagonal wire is not tested, there being no exact integer test
#             for "on the slope" worth trusting.
#
# Endpoint matches win outright: at a T junction the wire that arrives at the pin
# is marked and the run it arrives on is not.  Returns the quads in input order,
# or {} when no wire of the net reaches the point at all.
proc ::mUtilMenu::SegsAtPoint { pSegs pPoint } {
    set lX [lindex $pPoint 0]
    set lY [lindex $pPoint 1]
    if { $lX eq "" || $lY eq "" } {
        return [list]
    }

    set lEnds [list]
    set lOn   [list]

    foreach lSeg $pSegs {
        set lX1 [lindex $lSeg 0]
        set lY1 [lindex $lSeg 1]
        set lX2 [lindex $lSeg 2]
        set lY2 [lindex $lSeg 3]

        if { ($lX1 == $lX && $lY1 == $lY) || ($lX2 == $lX && $lY2 == $lY) } {
            lappend lEnds $lSeg
            continue
        }
        if { $lY1 == $lY2 && $lY == $lY1 } {
            if { ($lX > $lX1 && $lX < $lX2) || ($lX > $lX2 && $lX < $lX1) } {
                lappend lOn $lSeg
            }
            continue
        }
        if { $lX1 == $lX2 && $lX == $lX1 } {
            if { ($lY > $lY1 && $lY < $lY2) || ($lY > $lY2 && $lY < $lY1) } {
                lappend lOn $lSeg
            }
        }
    }

    if { [llength $lEnds] > 0 } {
        return $lEnds
    }
    return $lOn
}

# "20 pins" / "2 pins" / "no pin count", for the skipped list and the rule4 detail.
proc ::mUtilMenu::PinCountStr { pCount } {
    if { $pCount < 0 } {
        return "no pin count"
    }
    if { $pCount == 1 } {
        return "1 pin"
    }
    return "$pCount pins"
}

# The four rules, in order.  See the block comment above.
#
# Takes the two netlists CollectNetlist built and (N)'s net rows - the wires, which
# are the one thing a netlist does not carry.  It used to take the page dicts and
# build the netlists itself, which meant building them twice per compare.
#
# TIMING (mTimeCompare): one line at the end, start of the proc to end of it, with
# what it worked on -
#
#     timing: NetlistCompare 31 ms - (O) 245 net(s), (N) 247 net(s) -> 12 finding(s), 8 skipped
#
# There is not a single Dbo call in here, so this number is pure Tcl over rows the
# parts and nets walks already collected.  If it is small - and it should be - then
# the rules themselves are not what makes a compare slow, whatever the walk that
# fed them costs.
proc ::mUtilMenu::NetlistCompare { pRecsO pRecsN pNetRowsN } {
    variable mRule4MinPins
    variable mTimeCompare

    set lT0 [::mUtilMenu::TimeNow]

    set lRecsO $pRecsO
    set lRecsN $pRecsN

    # CollectNetlist keys its nets in an array, so one record per name per side.
    array set lO {}
    foreach lRec $lRecsO {
        set lO([lindex $lRec 0]) $lRec
    }

    # Where (N)'s wires are.  A net the netlist knows about because a pin says it
    # is on it, but the Nets section never listed, has no wires here - the finding
    # is still reported, with nothing to draw.
    array set lGeom {}
    ::mUtilMenu::NetGeomIndex lGeom $pNetRowsN

    set lFound   [list]
    set lSkipped [list]
    array set lSeen {}

    foreach lRec $lRecsN {
        set lNet  [lindex $lRec 0]
        set lFlag [lindex $lRec 1]
        set lPins [lindex $lRec 2]
        set lSeen($lNet) 1

        set lSegs [list]
        if { [info exists lGeom($lNet)] } {
            set lSegs $lGeom($lNet)
        }

        # ---- net_compare_rule1 -------------------------------------------------
        # No part pin on it and local: a net that connects nothing.  Deliberately
        # ahead of every other rule and deliberately not looking at (O) - the net
        # is wrong on (N) whether (O) had it or not.
        if { [llength $lPins] == 0 && $lFlag == 0 } {
            lappend lFound [list 1 $lNet \
                "no Part_Reference.Pin on it, and local (0)" $lSegs $lNet]
            continue
        }

        # ---- net_compare_rule2 -------------------------------------------------
        # In (N)'s netlist, not in (O)'s.
        if { ![info exists lO($lNet)] } {
            lappend lFound [list 2 $lNet "not in (O)'s netlist" $lSegs $lNet]
            continue
        }

        set lRecO  [set lO($lNet)]
        set lFlagO [lindex $lRecO 1]

        # ---- net_compare_rule3 -------------------------------------------------
        # Same name, different global/local bit - not the same net.
        if { $lFlag != $lFlagO } {
            lappend lFound [list 3 $lNet \
                "1 = global / 0 = local differs: (O) $lFlagO -> (N) $lFlag" $lSegs $lNet]
            continue
        }

        # ---- net_compare_rule4 -------------------------------------------------
        # Same name, same bit, different pins.  Only the wire at each changed pin
        # is marked, not the whole net - and only when the part behind that pin has
        # more than mRule4MinPins pins.  A changed pin on a small part (a resistor,
        # a capacitor, a single gate, a small header) is not processed at all: it is
        # listed as skipped in the Command Window and gets no line and no entry in
        # the report.
        set lAdd  [::mUtilMenu::PinMultisetDiff [lindex $lRecO 2] $lPins]
        set lDrop [::mUtilMenu::PinMultisetDiff $lPins [lindex $lRecO 2]]
        if { [llength $lAdd] == 0 && [llength $lDrop] == 0 } {
            continue
        }

        array unset lPos
        array set   lPos {}
        ::mUtilMenu::PinPosIndex lPos $lRec

        # Pin counts from both sides: an added pin's part is on (N), a dropped
        # pin's part is on (O) and may not be on (N) at all.
        array unset lCntN
        array set   lCntN {}
        ::mUtilMenu::PinCountIndex lCntN $lRec
        array unset lCntO
        array set   lCntO {}
        ::mUtilMenu::PinCountIndex lCntO $lRecO

        foreach lPin $lAdd {
            set lCnt -1
            if { [info exists lCntN($lPin)] } {
                set lCnt $lCntN($lPin)
            }
            if { $lCnt <= $mRule4MinPins } {
                lappend lSkipped \
                    "$lNet   pin $lPin only on (N) - part has [::mUtilMenu::PinCountStr $lCnt], not more than $mRule4MinPins"
                continue
            }

            if { ![info exists lPos($lPin)] } {
                lappend lFound [list 4 $lNet \
                    "pin $lPin ($lCnt-pin part) only on (N) - no position for it, not marked" [list] \
                    "$lNet ($lPin, no position)"]
                continue
            }
            foreach lPt $lPos($lPin) {
                set lHit [::mUtilMenu::SegsAtPoint $lSegs $lPt]
                if { [llength $lHit] == 0 } {
                    lappend lFound [list 4 $lNet \
                        "pin $lPin ($lCnt-pin part) only on (N), at ([lindex $lPt 0],[lindex $lPt 1]) - no wire of the net reaches it, not marked" \
                        [list] "$lNet ($lPin, no wire there)"]
                    continue
                }
                lappend lFound [list 4 $lNet \
                    "pin $lPin ($lCnt-pin part) only on (N), at ([lindex $lPt 0],[lindex $lPt 1])" $lHit \
                    "$lNet ($lPin)"]
            }
        }

        # Reported, never marked: the pin is on (O) and not on (N), so (N)'s page
        # has no connection point to put a line at.  Held to the same pin count, out
        # of (O)'s netlist - a rewired resistor should not be reported at one end and
        # skipped at the other.
        foreach lPin $lDrop {
            set lCnt -1
            if { [info exists lCntO($lPin)] } {
                set lCnt $lCntO($lPin)
            }
            if { $lCnt <= $mRule4MinPins } {
                lappend lSkipped \
                    "$lNet   pin $lPin only on (O) - part has [::mUtilMenu::PinCountStr $lCnt], not more than $mRule4MinPins"
                continue
            }
            lappend lFound [list 4 $lNet \
                "pin $lPin ($lCnt-pin part) only on (O) - nothing on (N) to mark" [list] \
                "$lNet ($lPin, only (O))"]
        }
    }

    set lGone [list]
    foreach lRec $lRecsO {
        if { ![info exists lSeen([lindex $lRec 0])] } {
            lappend lGone [lindex $lRec 0]
        }
    }

    if { $mTimeCompare } {
        ::mUtilMenu::Out [format \
            "    timing: NetlistCompare %d ms - (O) %d net(s), (N) %d net(s) -> %d finding(s), %d skipped" \
            [expr { [clock milliseconds] - $lT0 }] \
            [llength $lRecsO] [llength $lRecsN] [llength $lFound] [llength $lSkipped]]
    }

    return [list $lFound $lGone $lSkipped]
}

# Print what NetlistCompare found and return the report-window text for it, "" when
# it found nothing.  Grouped by rule, so the report says WHICH rule fired - that is
# the whole point of numbering them.
#
# pSkipped is the rule4 pin-count filter's list.  It is printed and then left out
# of the returned text on purpose: a skipped pin is not a finding, so it must not
# appear in the report window or count towards "something changed".
proc ::mUtilMenu::PrintNetlistCompare { pFound pGone {pSkipped {}} } {
    variable mRule4MinPins

    set lRuleText [list \
        1 "net with no Part_Reference.Pin on it and local (0)" \
        2 "in (N)'s netlist, not in (O)'s" \
        3 "1 = global / 0 = local differs" \
        4 "same net, different pins - marked at the changed pin"]

    ::mUtilMenu::Out "    Netlist compare - net_compare_rule1..4; every hit gets a pink DASH line on (N)"

    # First, so it is read as "these were left out" rather than as part of the
    # findings below it.
    if { [llength $pSkipped] > 0 } {
        ::mUtilMenu::Out "      net_compare_rule4 skipped - part has $mRule4MinPins pin(s) or fewer ([llength $pSkipped])"
        foreach lLine $pSkipped {
            ::mUtilMenu::Out "        $lLine"
        }
    }

    if { [llength $pFound] == 0 && [llength $pGone] == 0 } {
        # Not "both netlists agree" when something was skipped - they do not agree,
        # the difference was ruled out by the pin count.
        if { [llength $pSkipped] > 0 } {
            ::mUtilMenu::Out "      nothing left to mark - every difference was skipped above"
        } else {
            ::mUtilMenu::Out "      both netlists agree"
        }
        return ""
    }

    set lMsg ""
    foreach lRule { 1 2 3 4 } {
        set lHits [list]
        foreach lRec $pFound {
            if { [lindex $lRec 0] == $lRule } {
                lappend lHits $lRec
            }
        }
        if { [llength $lHits] == 0 } {
            continue
        }

        ::mUtilMenu::Out "      net_compare_rule$lRule - [dict get $lRuleText $lRule] ([llength $lHits])"
        set lShort [list]
        foreach lRec $lHits {
            ::mUtilMenu::Out [format "        %-28s %d line(s)   %s" \
                      [lindex $lRec 1] [llength [lindex $lRec 3]] [lindex $lRec 2]]
            if { [lsearch -exact $lShort [lindex $lRec 4]] == -1 } {
                lappend lShort [lindex $lRec 4]
            }
        }
        append lMsg "  [format %-8s rule$lRule] ([llength $lHits]) : [::mUtilMenu::RefListStr $lShort 0]\n"
    }

    # Nets (O) has and (N) has not.  Listed for symmetry with the Remove half of
    # the section diff; there is no wire on (N) to draw a line on.
    if { [llength $pGone] > 0 } {
        ::mUtilMenu::Out "      only in (O)'s netlist - nothing on (N) to mark ([llength $pGone])"
        foreach lNet $pGone {
            ::mUtilMenu::Out "        $lNet"
        }
        append lMsg "  [format %-8s {only(O)}] ([llength $pGone]) : [::mUtilMenu::RefListStr $pGone 0]\n"
    }

    if { $lMsg eq "" } {
        return ""
    }
    return "Netlist (net_compare_rule1..4):\n$lMsg"
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
#
# Parts are the one exception, and PartMoveFilter is where it happens: a part
# whose Part Reference, Value, PCB Footprint, Part_Number, Optional and pins are
# all identical on both sides is the same part in a new place, so its New and its
# Remove cancel each other out and it is listed as Moved instead - no rectangle
# on (N)'s page.
# Nets and buses are not filtered that way: a wire IS its coordinates, so a wire
# that moved is a different wire.  For nets that is exactly why this section no
# longer marks anything - the netlist rules above do the marking, and they compare
# connectivity instead of coordinates.  The Nets diff stays as a listing, because
# "these wires moved" is still worth reading even when it is not worth drawing.
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

# The fields that decide "this is the same part, only somewhere else":
#
#   Part Reference   Value   PCB Footprint   Part_Number   Optional   pins
#
# Position is left out on purpose - a differing position is the whole point.  So
# are package name and source library: a part re-placed from a copy of the
# library is still the same part.  Everything else PartSig prints is here, so a
# move is allowed to change the placement and nothing else.
#
# The pins are sorted, exactly as PartSig sorts them, so the database read order
# never decides whether two parts look alike.
proc ::mUtilMenu::PartMoveKey { pRow } {
    return [list \
        [lindex $pRow 0] \
        [lindex $pRow 1] \
        [lindex $pRow 6] \
        [lindex $pRow 7] \
        [lindex $pRow 8] \
        [lsort -dictionary [lindex $pRow 5]]]
}

# {signature shortName} pair -> {moveKey position} for the row behind it.
#
# Keyed on the pair SigDiff hands back, the same way MarkGeomIndex is, so the two
# sides can be matched up without carrying the rows through the diff.  Rows that
# share a signature share an entry: they are identical in every printed field,
# move key included, so the first one answers for all of them.
proc ::mUtilMenu::PartMoveIndex { pArrName pRows } {
    upvar 1 $pArrName lArr

    foreach lRow $pRows {
        set lPair [::mUtilMenu::PartSig $lRow]
        if { ![info exists lArr($lPair)] } {
            set lArr($lPair) [list [::mUtilMenu::PartMoveKey $lRow] [lindex $lRow 4]]
        }
    }
}

# Cancel out the New/Remove pairs that are one and the same part in two places.
#
# A part that only moved has a different position, so its signature differs and
# the plain multiset diff reports it twice - once as New (and a turquoise
# rectangle on (N)'s page), once as Remove.  Here every New part is matched
# against the Removes that carry the same move key; a match takes both entries
# out of the diff and files the part as Moved instead, so nothing gets drawn.
#
# Cancelling is a multiset operation and pops one Remove per New, so three copies
# of a part in (O) against two in (N) still leaves one genuine Remove.
#
# Returns {newPairs remPairs movedRecords}, a moved record being
# {shortName oldPosition newPosition}.
proc ::mUtilMenu::PartMoveFilter { pNew pRem pRowsO pRowsN } {
    array set lIdxO {}
    array set lIdxN {}
    ::mUtilMenu::PartMoveIndex lIdxO $pRowsO
    ::mUtilMenu::PartMoveIndex lIdxN $pRowsN

    # Removed pairs queued under their move key - the New side pops from these.
    array set lQueue {}
    foreach lPair $pRem {
        if { [info exists lIdxO($lPair)] } {
            lappend lQueue([lindex $lIdxO($lPair) 0]) $lPair
        }
    }

    set lNewOut [list]
    set lMoved  [list]
    array set lDrop {}

    foreach lPair $pNew {
        set lKey ""
        if { [info exists lIdxN($lPair)] } {
            set lKey [lindex $lIdxN($lPair) 0]
        }
        if { $lKey eq "" || ![info exists lQueue($lKey)] \
             || [llength $lQueue($lKey)] == 0 } {
            lappend lNewOut $lPair
            continue
        }

        set lOld          [lindex $lQueue($lKey) 0]
        set lQueue($lKey) [lrange $lQueue($lKey) 1 end]
        if { [info exists lDrop($lOld)] } {
            incr lDrop($lOld)
        } else {
            set lDrop($lOld) 1
        }
        lappend lMoved [list [lindex $lPair 1] [lindex $lIdxO($lOld) 1] \
                             [lindex $lIdxN($lPair) 1]]
    }

    # Same multiset bookkeeping on the way out: drop as many copies of a Remove
    # as were consumed, never the whole run of them.
    set lRemOut [list]
    foreach lPair $pRem {
        if { [info exists lDrop($lPair)] && $lDrop($lPair) > 0 } {
            incr lDrop($lPair) -1
            continue
        }
        lappend lRemOut $lPair
    }

    return [list $lNewOut $lRemOut $lMoved]
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

# Parts and buses are the categories whose findings get marked on the page, so
# their one-row form is split out (PartSig above, BusSig below): MarkGeomIndex
# needs to rebuild the exact same {signature shortName} pair SigDiff keys on, and a
# second copy of the format string would be a silent way for the two to drift
# apart.  NetSig is in the same shape although the Nets section no longer marks -
# it costs nothing and the netlist rules could be given a coordinate fallback.
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
# Nets and Buses are reported in full rather than capped at mRefListMax, the way
# Parts and Symbols are - a net or a bus wire is one line of report either way, and
# the Buses list has to name every line drawn on the page.
#
# What ends up on (N)'s page:
#
#   mMarkSegs   a pink DASH line per wire.  Buses come from this compare's New
#               entries; NETS DO NOT - they come from NetlistCompare's
#               net_compare_rule1..4, which is the whole point of that block.  The
#               Nets section below is still dumped and still diffed, but only for
#               the report: a wire moved by half a grid square used to count as a
#               new net and get a line, and a net rewired between two parts that
#               kept their wires used to get none.
#   mMarkBoxes  a turquoise rectangle per new part, round its bounding box.
#
# Only New, not Remove: a Remove is something (O) has and (N) has not, so there is
# nothing on (N)'s page to mark.
proc ::mUtilMenu::DumpFullCompare { pDictO pDictN } {
    variable mMarkSegs
    variable mMarkBoxes
    variable mRefListMax

    # {name dictKey sigsProc oneSigProc geomIndex listMax markKind}
    # geomIndex -1 / markKind "" = this category is not marked on the page.
    # Nets are -1 / "" on purpose - see the netlist block above.
    set lCats [list \
        [list "Parts"   parts   ::mUtilMenu::PartSigs   ::mUtilMenu::PartSig  9 $mRefListMax box] \
        [list "Symbols" symbols ::mUtilMenu::SymbolSigs ""                   -1 $mRefListMax ""] \
        [list "Nets"    nets    ::mUtilMenu::NetSigs    ::mUtilMenu::NetSig  -1 0            ""] \
        [list "Buses"   buses   ::mUtilMenu::BusSigs    ::mUtilMenu::BusSig   3 0            line]]

    set mMarkSegs  [list]
    set mMarkBoxes [list]

    # Both netlists, listed and then compared, before the section diff: the netlist
    # is what the net markers come from now, so it runs first and the Command Window
    # reads in the order the work happens.
    #
    # Built ONCE per side here and handed to both the listing and the compare.  They
    # used to take the page dicts and call CollectNetlist themselves, which built
    # every netlist twice - the same answer for twice the work, on the one part of
    # the compare that touches every pin of every part.
    set lT     [::mUtilMenu::TimeNow]
    set lRecsO [::mUtilMenu::CollectNetlist $pDictO]
    set lRecsN [::mUtilMenu::CollectNetlist $pDictN]
    ::mUtilMenu::TimeMark "netlist collect" $lT

    set lT [::mUtilMenu::TimeNow]
    ::mUtilMenu::DumpNetlists $lRecsO $lRecsN
    ::mUtilMenu::TimeMark "netlist print" $lT

    set lT        [::mUtilMenu::TimeNow]
    set lNetCmp   [::mUtilMenu::NetlistCompare $lRecsO $lRecsN [dict get $pDictN nets]]
    set lNetFound [lindex $lNetCmp 0]
    ::mUtilMenu::TimeMark "netlist rule1..4" $lT

    set lT      [::mUtilMenu::TimeNow]
    set lNetMsg [::mUtilMenu::PrintNetlistCompare $lNetFound \
                     [lindex $lNetCmp 1] [lindex $lNetCmp 2]]
    ::mUtilMenu::TimeMark "netlist print" $lT

    # One marker line per wire each rule hit brings back.  A finding with no wire -
    # rule4 with no matching wire, a netlist net the Nets section never listed - is
    # in the report and traced, but there is nothing to draw.
    # One wire, one line: rule4 can find the same wire from two pins at its two
    # ends, and two lines on top of each other are two objects to delete later for
    # no extra information.  First finding to reach a wire names it.
    array set lSegSeen {}
    foreach lRec $lNetFound {
        if { [llength [lindex $lRec 3]] == 0 } {
            ::mUtilMenu::Trace "net_compare_rule[lindex $lRec 0] [lindex $lRec 1]: [lindex $lRec 2]"
            continue
        }
        foreach lSeg [lindex $lRec 3] {
            if { [info exists lSegSeen($lSeg)] } {
                continue
            }
            set lSegSeen($lSeg) 1
            lappend mMarkSegs [linsert $lSeg 0 "rule[lindex $lRec 0] [lindex $lRec 4]"]
        }
    }

    set lNewByCat  [list]
    set lRemByCat  [list]
    set lMovedPart [list]
    set lAny 0
    set lTDiff [::mUtilMenu::TimeNow]

    foreach lCat $lCats {
        set lName [lindex $lCat 0]
        set lKey  [lindex $lCat 1]
        set lSigs [lindex $lCat 2]

        set lDiff [::mUtilMenu::SigDiff \
                       [$lSigs [dict get $pDictO $lKey]] \
                       [$lSigs [dict get $pDictN $lKey]]]

        # Parts only: a part that kept its data and changed its place is not a
        # difference.  Filtered here, before lAny and before the marker block, so
        # it counts neither as a finding nor as a rectangle.
        if { $lKey eq "parts" } {
            set lFilt [::mUtilMenu::PartMoveFilter \
                           [lindex $lDiff 0] [lindex $lDiff 1] \
                           [dict get $pDictO $lKey] [dict get $pDictN $lKey]]
            set lDiff      [lrange $lFilt 0 1]
            set lMovedPart [lindex $lFilt 2]
        }

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
    ::mUtilMenu::TimeMark "section diff" $lTDiff

    if { !$lAny && [llength $lMovedPart] == 0 && $lNetMsg eq "" } {
        ::mUtilMenu::Out "    all the same"
        return "all the same"
    }

    # The netlist rules first, because they are what is drawn on the page.
    set lMsg $lNetMsg
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

    # Reported, not marked: silently dropping a part that moved right across the
    # page would leave no way to tell it apart from one that never moved at all.
    if { [llength $lMovedPart] > 0 } {
        ::mUtilMenu::Out "    MOVED - same data, different position, not marked:"
        ::mUtilMenu::Out "      Parts ([llength $lMovedPart])"
        set lShort [list]
        foreach lRec $lMovedPart {
            ::mUtilMenu::Out [format "        %-10s O: %s" [lindex $lRec 0] [lindex $lRec 1]]
            ::mUtilMenu::Out [format "        %-10s N: %s" "" [lindex $lRec 2]]
            lappend lShort [lindex $lRec 0]
        }
        append lMsg "Moved (not marked):\n"
        append lMsg "  [format %-8s Parts] ([llength $lMovedPart]) : [::mUtilMenu::RefListStr $lShort $mRefListMax]\n"
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
# names, positions and connections.  Returns rows of:
#
#   0 type        OFFPAGE / GLOBAL / PORT
#   1 name        the symbol's name - the net name for a power symbol
#   2 position    GetLocation + bounding box, as ObjLocStr prints it
#   3 connection  the net the symbol is attached to, "" when it is attached to
#                 nothing - SymbolConn
#
# Element 3 is the one added for the connection listing.  SymbolSigs still builds
# its signature out of elements 0-2 only, so PageComp's Symbols diff is exactly
# what it was; the connection is a listing, not a new difference.  Refcompare is
# the compare that does look at it - see DumpRefSymbolCompare.
#
# Capture keeps power and ground in the same bucket - both are DBGLOBAL objects
# off NewGlobalsIter (orPrmDboStreamer.tcl:1721,1870) - so there is no flag to
# separate them; the name is what tells +3V3 from GND.  They are tagged GLOBAL
# here for that reason.
proc ::mUtilMenu::CollectPageSymbols { pPage } {
    set lStatus  [DboState]
    set lNullObj NULL
    set lRows    [list]

    # net object -> net label, for the whole page: see CollectPinInfo.  Every GND
    # symbol on the page asks about the same net, and each answer costs a walk
    # over that net's wires.
    array set lNetCache {}

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
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus] \
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache]]
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
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus] \
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache]]
            set lObj [$lIter NextGlobal $lStatus]
        }
        catch { delete_DboPageGlobalsIter $lIter }
    }

    # Hierarchical ports.
    if { ![catch { set lIter [$pPage NewPortsIter $lStatus] }] } {
        set lObj [$lIter NextPort $lStatus]
        while { $lObj != $lNullObj } {
            lappend lRows [list PORT [::mUtilMenu::CStr $lObj GetName] \
                                [::mUtilMenu::ObjLocStr $pPage $lObj $lStatus] \
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache]]
            set lObj [$lIter NextPort $lStatus]
        }
        catch { delete_DboPagePortsIter $lIter }
    }

    catch { $lStatus -delete }
    return $lRows
}

# Sort by name inside type: stable lsort, so the name pass runs first.
#
# The connection column is appended when the row carries element 3 and
# mSymConnDetail is on; a row without it prints exactly as it always did.
proc ::mUtilMenu::PrintSymbolRows { pRows } {
    variable mSymConnDetail

    foreach lRow [lsort -dictionary -index 0 [lsort -dictionary -index 1 $pRows]] {
        set lLine [format "    %-8s %-26s %s" \
                       [lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]] \
                       [lindex $lRow 2]]
        if { $mSymConnDetail && [llength $lRow] > 3 } {
            append lLine "\n                 -> [::mUtilMenu::ConnStr 0 [lindex $lRow 3]]"
        }
        ::mUtilMenu::Out $lLine
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
#
# Every section is timed twice - the database walk and the printing - because they
# are the two halves a slow compare could be in and they are fixed in completely
# different ways.  See mTimeCompare.
proc ::mUtilMenu::DumpPageInfo { pDsnPath pSchName pPageName \
                                 {pWhat {parts symbols nets buses}} } {
    set lT      [::mUtilMenu::TimeNow]
    set lPage   [::mUtilMenu::FindPage $pDsnPath $pSchName $pPageName]
    ::mUtilMenu::TimeMark "page lookup" $lT

    set lTotals [list]
    set lOut    [list parts [list] symbols [list] nets [list] buses [list]]

    # {section dictKey heading collectProc printProc unit}
    set lSecs [list \
        [list parts   parts   "  Parts" \
             ::mUtilMenu::CollectPageParts   ::mUtilMenu::PrintPartRows   "part(s)"] \
        [list symbols symbols "  Off-Page / Power / Ports" \
             ::mUtilMenu::CollectPageSymbols ::mUtilMenu::PrintSymbolRows "symbol(s)"] \
        [list nets    nets    "  Nets" \
             ::mUtilMenu::CollectPageNets    ::mUtilMenu::PrintNetRows    "net(s)"] \
        [list buses   buses   "  Buses" \
             ::mUtilMenu::CollectPageBuses   ::mUtilMenu::PrintBusRows    "bus wire(s)"]]

    foreach lSec $lSecs {
        set lWhich [lindex $lSec 0]
        if { [lsearch -exact $pWhat $lWhich] == -1 } {
            continue
        }
        ::mUtilMenu::Out [lindex $lSec 2]

        set lT    [::mUtilMenu::TimeNow]
        set lRows [[lindex $lSec 3] $lPage]
        ::mUtilMenu::TimeMark "$lWhich collect" $lT

        set lOut [dict replace $lOut [lindex $lSec 1] $lRows]

        set lT [::mUtilMenu::TimeNow]
        set lN [[lindex $lSec 4] $lRows]
        ::mUtilMenu::TimeMark "$lWhich print" $lT

        lappend lTotals "$lN [lindex $lSec 5]"
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

# What the result window's own Close does: the report AND the page selector behind
# it.  The two windows are one job - PageComp / Refcompare are started from the
# selector and answer in the report - so dismissing the answer dismisses the
# question with it, in one click, instead of leaving the selector sitting over the
# schematic the markers were just drawn on.  mUtil > Schematic Compare reopens it.
#
# The window's X and its Escape key are wired to this too: all three mean "close
# this report", and having them do different things would be a bug, not a feature.
#
# CloseResultWindow itself is deliberately left as it was - AllPagesComp and
# ::mUtilMenu::remove both close the two windows in their own order, and neither
# wants the selector's teardown hidden inside the report's.
proc ::mUtilMenu::CloseResultAndSelector { } {
    ::mUtilMenu::CloseResultWindow
    ::mUtilMenu::ClosePageSelector
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
    wm protocol $mResultWin WM_DELETE_WINDOW "::mUtilMenu::CloseResultAndSelector"
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
    # Closes the page selector as well - see CloseResultAndSelector.
    button $lBtns.close  -text "Close"      -width 12 \
        -command "::mUtilMenu::CloseResultAndSelector"
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
    bind $mResultWin <Escape>   "::mUtilMenu::CloseResultAndSelector"

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

# "This object changed."  Its own proc because MarkModified is NOT one call: every
# Dbo class declares its own, with its own arity, and a bare "$obj MarkModified"
# only fits the ones that take nothing:
#
#   DboPage::MarkModified()                    nothing
#   DboSchematic::MarkModified(DboPage*)       the page inside it
#   DboDesign::MarkModified(DboOccurrence*)    an occurrence, NULL for none
#   DboLib::MarkModified(DboCell* / ...)       several overloads of its own
#
# Read off the SWIG argument strings in orDb_Dll_Tcl64.dll - "oo:DboDesign_
# MarkModified self pOccurrence" is the two-argument one, which is why calling it
# with none used to print
#
#   mUtil: MarkModified failed -> Wrong number of arguments
#          :DboDesign_MarkModified self pOccurrence  argument 2
#
# once per renamed page.  Appendix A p.171 only documents the no-argument
# DboBaseObject::MarkModified() that these derived versions hide, so the DLL is the
# only place the real shapes are written down.  Cadence's own
# capReplacePathCacheUtil/tcl/capReplacePathInCache.tcl:736 calls the design one as
#
#   $lDesign MarkModified NULL
#
# so NULL is the sanctioned "no particular occurrence".
#
# Tries the arguments it was given, then the no-argument form, and only says
# anything when neither shape is accepted: some of these classes carry both (SWIG
# keeps the inherited no-argument wrapper alongside the derived one), and a guessed
# arity should not cost a line of complaint per page for a call that is belt and
# braces to begin with.
#
# Returns 1 when the call went through.  Several of these return void rather than a
# DboState, so "went through" is all there is to know: there is no status to read.
proc ::mUtilMenu::MarkObjModified { pObj args } {
    if { $pObj eq "" || $pObj eq "NULL" } {
        return 0
    }

    foreach lArgs [list $args [list]] {
        if { [catch { set lState [eval [list $pObj MarkModified] $lArgs] }] } {
            continue
        }
        set lOK 1
        catch { set lOK [$lState OK] }
        catch { $lState -delete }
        return $lOK
    }

    ::mUtilMenu::Trace "MarkModified refused both shapes on $pObj (args {$args}) - the object may not be markable from Tcl"
    return 0
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

    ::mUtilMenu::MarkObjModified $lPage
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

# Mark the (N) page of the compare that just ran:
#
#   nets          a pink line per wire net_compare_rule1..4 hit - the whole net
#                 for rules 1-3, only the wire at the changed pin for rule 4.
#                 See NetlistCompare.
#   buses         a pink line per bus wire (N) has and (O) has not
#                 Both are drawn over the wire's own coordinates, nudged clear of
#                 it by OffsetSeg
#   parts         a turquoise rectangle round the part's bounding box, drawn where
#                 the box actually is - no offset, the point of a box is that it
#                 surrounds the thing rather than sitting next to it.  Parts that
#                 only moved never reach here: DumpFullCompare takes them out of
#                 the diff before the boxes are built (PartMoveFilter).
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
        ::mUtilMenu::MarkObjModified $lPage
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

    # All three levels, each with the arguments ITS OWN MarkModified takes - see
    # MarkObjModified, which is where the three different shapes are written down.
    # The design one is the reason that proc exists: it wants an occurrence, so the
    # bare call this used to make never reached the database at all.
    ::mUtilMenu::MarkObjModified $lPage
    ::mUtilMenu::MarkObjModified $lSch $lPage
    catch { ::mUtilMenu::MarkObjModified [::mUtilMenu::FindDesign $pFile] NULL }
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

# Parts AND symbols now: the Off-Page / Power / Ports section is dumped with each
# symbol's connection, and DumpRefCompare compares those connections.  Nets and
# Buses are still left to PageComp - a net is not something with a reference to
# match on, and its wires are what PageComp draws its markers from.
proc ::mUtilMenu::DoPageRefCompare { } {
    ::mUtilMenu::RunPageCompare [list parts symbols] "Refcompare" ref
}

# One page pair, compared exactly the way PageComp compares its pair - the same
# DumpPageInfo walk, the same DumpFullCompare, the same net_compare_rule1..4 markers
# - but with nothing printed, no timing, no report and no window.  Returns the
# number of markers drawn on (N)'s page, which is also the answer to "did this page
# change".
#
# SILENT BY DESIGN, and that is the point of the proc rather than a side effect.
# AllPagesComp runs one of these per mapped page pair, so what the two page dumps
# would push into the Command Window is thousands of lines per pair - each one a UI
# append - for an answer that is a single number.  Two switches are turned off
# around the work and put back afterwards:
#
#   mQuiet 1         nothing the compare would print reaches the Command Window:
#                    neither page dump, neither netlist, no rule listing, no
#                    marker block.  AllPagesComp prints its own one line per pair
#                    instead - see DoTotalPageCompare.
#   mTimeCompare 0   no timing.  Measuring costs time of its own (two clock calls
#                    per pin position, and one accumulate per phase), and a
#                    per-pair breakdown is not what a whole-design run is for.
#                    Use PageComp on one pair when you want the numbers.
#
# Both are restored on the way out of an error as well, or the first pair that
# failed would leave the Command Window mute for the rest of the session.
#
# pQuiet 0 turns the suppression off, for running one pair from the Command Window
# and watching what it does:
#     ::mUtilMenu::ComparePagePair $fileA {SCH PAGE1} $fileB {SCH PAGE1} 0
#
# The marker state is cleared first for the same reason RunPageCompare clears it:
# DumpFullCompare fills it, and a pair that finds nothing must not inherit the
# previous pair's findings and draw them a second time on the wrong page.
proc ::mUtilMenu::ComparePagePair { pFileA pPairA pFileB pPairB {pQuiet 1} } {
    variable mMarkSegs
    variable mMarkBoxes
    variable mQuiet
    variable mTimeCompare

    set mMarkSegs  [list]
    set mMarkBoxes [list]

    set lSaveQuiet $mQuiet
    set lSaveTime  $mTimeCompare
    if { $pQuiet } {
        set mQuiet       1
        set mTimeCompare 0
    }

    set lDrawn 0
    set lErr   ""
    set lFail  [catch {
        set lWhat  [list parts symbols nets buses]
        set lDataO [::mUtilMenu::DumpPageInfo $pFileA \
                        [lindex $pPairA 0] [lindex $pPairA 1] $lWhat]
        set lDataN [::mUtilMenu::DumpPageInfo $pFileB \
                        [lindex $pPairB 0] [lindex $pPairB 1] $lWhat]

        ::mUtilMenu::DumpFullCompare $lDataO $lDataN

        # After the compare, never before - drawing first would put the marker lines
        # into (N)'s own dump, where they would come back as differences of their own.
        set lDrawn [::mUtilMenu::DrawMarkersOnPage $pFileB $pPairB]
    } lErr]

    set mQuiet       $lSaveQuiet
    set mTimeCompare $lSaveTime

    if { $lFail } {
        error $lErr
    }
    return $lDrawn
}

# The one line AllPagesComp prints when a page pair is done: which two pages, and
# what came of it.
#
# (N) first, then (O), then the result - the marked side leads, because that is the
# page the user opens next.
#
# The PAGE NAME only, not PageLabel's "schematic / page": the schematic is the same
# string on every line of a run ("W980_WS / " in front of all 148 of them), so it
# pushed the part that differs off to the right and made the lines too wide to scan.
# The page names in this project are long enough on their own.
#
# %-32s on each name so the result reads as a column down the run; a name longer
# than that pushes its own line out rather than being cut - a truncated page name
# cannot be looked up in the selector, a ragged column can still be read.
proc ::mUtilMenu::PairDoneLine { pPairB pPairA pResult } {
    ::mUtilMenu::Out [format "  (N) %-32s (O) %-32s Page comparison finished - %s" \
              [lindex $pPairB 1] \
              [lindex $pPairA 1] \
              $pResult]
}

# AllPagesComp - the SAME compare PageComp does, over every mapped page pair at
# once instead of the one pair the checkboxes point at.  Same DumpPageInfo walk,
# same DumpFullCompare, same net_compare_rule1..4 pink DASH lines, same turquoise
# rectangles: ComparePagePair is PageComp's own path with the report window and the
# printing taken off it.
#
# What it runs on is mPageLinks, Page_name_mapping's {indexA indexB kind} triples:
# every page that has a line drawn to it in the selector, solid or dashed.  A page
# with no counterpart has no line, is not compared, and is not renamed - unchanged,
# and the reason the run is over the LINKS and not over the page list.
#
# A page of (N) that came out different is marked by putting '*' in front of its
# name, so the change is visible in PROJECT_MANAGER_VIEW without opening anything -
# also unchanged.
#
# WHAT THE COMMAND WINDOW GETS.  Not the page dumps and not the timing: those are
# what made a whole-design run take minutes and thousands of lines for a one-number
# answer, and ComparePagePair now turns both off around each pair (mQuiet,
# mTimeCompare - see there).  What it prints instead is one line per pair, as each
# pair finishes, so a long run shows progress and says which pages it has been
# through:
#
#     AllPagesComp - (N) new.dsn   (O) old.dsn
#       (N) SCHEMATIC1 / PAGE1   (O) SCHEMATIC1 / PAGE1   Page comparison finished - no difference
#       (N) SCHEMATIC1 / PAGE2   (O) SCHEMATIC1 / PAGE2   Page comparison finished - 7 marker(s), '*' added
#       (N) SCHEMATIC1 / PAGE3   (O) SCHEMATIC1 / PAGE3   Page comparison finished - 2 marker(s), NOT renamed
#       ...
#
# (N) first because (N) is the side being marked and renamed - the page the user is
# going to open.  The page name is the one the selector showed, prefix and all, so
# it can be found in the list; the '*' the run adds is reported in the result half
# of the line rather than by reprinting the new name.
#
# The proc keeps its old name - only the button label changed - so anything that
# already calls ::mUtilMenu::DoTotalPageCompare from the Command Window still
# works.
proc ::mUtilMenu::DoTotalPageCompare { } {
    variable mPageLinks
    variable mPagesA
    variable mPagesB
    variable mPagesFileA
    variable mPagesFileB

    if { [llength $mPageLinks] == 0 } {
        catch { capDisplayMessageBox \
                    "No page of the two designs maps onto a page of the other, so there is nothing to compare.\n\nOnly pages joined by a line in the page selector are compared." \
                    "Schematic Compare - AllPagesComp" }
        return
    }

    set lPairs   0
    set lChanged [list]
    set lFailed  [list]
    set lUnnamed [list]

    # One header, then one line per pair - the two file names are said once here
    # rather than on every line, which is what keeps the per-pair line short enough
    # to read down.
    ::mUtilMenu::Out "AllPagesComp - (N) [file tail $mPagesFileB]   (O) [file tail $mPagesFileA]"

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
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "FAILED - $lPairErr"
                continue
            }
            if { $lDrawn <= 0 } {
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "no difference"
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
                ::mUtilMenu::PairDoneLine $lPairB $lPairA \
                    "$lDrawn marker(s), NOT renamed - already marked, or the rename was refused"
            } else {
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "$lDrawn marker(s), '*' added"
            }
        }
    } lErr] } {
        ::mUtilMenu::Trace "AllPagesComp failed -> $lErr"
        catch { capDisplayMessageBox "AllPagesComp failed:\n\n$lErr" \
                                     "Schematic Compare - AllPagesComp" }
        return
    }

    ::mUtilMenu::Out "AllPagesComp - $lPairs page pair(s) compared, [llength $lChanged] changed"

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

    ::mUtilMenu::TimeReset
    set lTAll [::mUtilMenu::TimeNow]

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
            set lTitle "Reference compare (Parts by reference, Off-Page / Power / Ports by type + name)"
        } else {
            set lTitle "Compare (Parts / Symbols / Nets / Buses)"
        }
        ::mUtilMenu::Out "================================================================"
        ::mUtilMenu::Out "$lTitle   O = [file tail $mPagesFileA]   N = [file tail $mPagesFileB]"
        ::mUtilMenu::Out "================================================================"

        if { $pMode eq "ref" } {
            set lResult [::mUtilMenu::DumpRefCompare \
                             [dict get [lindex $lData 0] parts] \
                             [dict get [lindex $lData 1] parts] \
                             [dict get [lindex $lData 0] symbols] \
                             [dict get [lindex $lData 1] symbols]]
        } else {
            set lResult [::mUtilMenu::DumpFullCompare \
                             [lindex $lData 0] [lindex $lData 1]]
        }
        append lMsg "\n\n$lResult"
    }

    # Before the window, so the breakdown is the last thing in the Command Window
    # for the run it belongs to.  Prints nothing unless mTimeCompare is on.
    ::mUtilMenu::TimeReport "$pLabel, one page pair" $lTAll

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
    # The gap between the two columns is where the mapping lines are drawn further
    # down, so at header height it was an empty spacer label.  The logo goes there
    # instead: it is 120x22, the gap is mPageLinkGap (120) wide, so it fits without
    # moving either column.  Still a label and still the same width when the image
    # cannot be loaded - see LogoImage - so a missing logo file costs the logo and
    # nothing else.
    #
    # -borderwidth/-padx/-pady/-highlightthickness 0 are not cosmetic: a label's
    # default 2px border made the cell 124 wide against the gap's 120, which pushed
    # the (N) heading 4px right of the (N) column it names.  Zeroed, the label asks
    # for exactly the image's 120 and the two rows line up again.
    set lLogo [::mUtilMenu::LogoImage]
    if { $lLogo ne "" } {
        label $lHdr.gap -image $lLogo -anchor center \
            -borderwidth 0 -padx 0 -pady 0 -highlightthickness 0
    } else {
        label $lHdr.gap -text ""
    }
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
    # "OnePageCmp" rather than "PageComp", so the button says what distinguishes it
    # from AllPagesComp: this one compares the ONE pair of ticked pages.  The label
    # is all that changed - the proc, and the "PageComp" the report window and the
    # Command Window banners call it, are the same.
    button $lBtns.pagecomp -text "OnePageCmp" -width 12 \
        -command "::mUtilMenu::DoPageCompare"
    # Refcompare: BUILT BUT NOT PACKED - deliberately no button on screen.
    #
    # Kept whole rather than deleted, because the compare behind it is not going
    # anywhere: it is the Parts-only compare matched by Part Reference (Add /
    # Remove / Changed, no marker lines), and the Parts dump it prints on the way
    # there carries one line per pin - pin number, pin name, the pin's connection
    # point and the net the pin is on / NC.  See PrintPartRows.
    #
    # Both ways in still work with no button:
    #   ::mUtilMenu::DoPageRefCompare        from the Command Window, two pages ticked
    #   $lBtns.refcmp invoke                 the widget exists, it is just not shown
    #
    # To put it back on screen, uncomment its pack line below - nothing else.
    button $lBtns.refcmp   -text "Refcompare" -width 12 \
        -command "::mUtilMenu::DoPageRefCompare"
    button $lBtns.allcmp   -text "AllPagesComp" -width 14 \
        -command "::mUtilMenu::DoTotalPageCompare"
    # AllPagesComp is packed to the LEFT edge and the rest to the right, so the
    # whole remaining width of the button bar sits between them: it is the one
    # button that walks every page and renames what it finds, and it should not be
    # a slip of the mouse away from OnePageCmp.
    # Packed right to left, so the bar reads OnePageCmp, Close.
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

    # A Default Folder TYPED into the field rather than browsed to is remembered
    # here - Browse writes it as it goes, this catches the other way of setting it.
    catch { ::mUtilMenu::RememberInitDir [string trim $::mUtilMenu::mCmpInitDir] }

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
# Schematic Check
#
# One question: is what the Project Manager has selected right now a Design
# (.DSN) or the Project (.OPJ)?  If it is, the message box names the file.
#
# The commands are Appendix A p.129-132:
#
#   GetSelectedPMItems() : Tcl_Obj    the selected PM tree item(s)
#   GetPMItemName()                   \ return type NOT documented - the PDF
#   GetPMItemType()                   / gives the signature and nothing else
#   GetActivePMDesign()  : DboDesign  the active PM's design, NULL when none
#   GetActiveOpjName()   : char       the active .opj path
#
# WHAT DECIDES THE ANSWER.  GetSelectedPMItems hands back the tree LABELS and
# nothing else - no type, no path - so a label is matched against the two files
# the PM is already known to hold rather than trusted to describe itself:
#
#   ends in .dsn, or names the active design's file / root    -> Design
#   ends in .opj, or names the active project's file          -> Project
#   anything else ("Design Resources", "SCHEMATIC1", "PAGE1") -> neither
#
# The extension test carries most selections on its own: the PM shows a design
# as ".\board.dsn", extension and all.  It is the project's root node, which is
# shown by name only, that needs the name comparison.
#
# GetPMItemName / GetPMItemType ARE called - but only printed.  Nothing says what
# GetPMItemType's value means: it is not in Appendix A beyond its name, no shipped
# script calls it, and Capture.exe exports no $::-constant for it (checked - the
# only PM_* strings in the binary are PM_MODIFIED_STATUS_INDICATOR and
# PM_SORT_CACHE_PKGS_BY_LIB, neither an item type).  So its number goes to the
# Command Window next to the label it belongs to, to be identified against real
# selections.  Once the values are known this can switch onto it and drop the
# name matching - see ClassifyPMItem, which is the only proc that would change.
#=============================================================================

# The design the active Project Manager is showing, as {filePath rootName}, or
# {"" ""} when there is no active PM - which is what GetActivePMDesign returning
# NULL means, and the same NULL test the shipped scripts make on it
# (capAutoPcbEco.tcl:53, capAutoDRCConfigInit.tcl:22).
#
# GetName is DboLib's (DboDesign inherits it) and gives the design's file name -
# the same string GetDesignAndSchematics is keyed on.  GetRootName is the design
# root ("W980_WS"), which is what the PM shows for a bare .DSN opened without a
# project.
proc ::mUtilMenu::ActivePMDesignInfo { } {
    set lDesign ""
    catch { set lDesign [GetActivePMDesign] }
    if { $lDesign eq "" || $lDesign eq "NULL" } {
        return [list "" ""]
    }
    return [list [::mUtilMenu::CStr $lDesign GetName] \
                 [::mUtilMenu::CStr $lDesign GetRootName]]
}

# Which of the two things one PM tree label is, if either.  Returns
# {design|project|other <fullPath>}; the path is "" for "other".
#
# Everything is compared lowercased: Windows paths are case-insensitive and the
# PM does not necessarily show a file in the case it is stored in.
proc ::mUtilMenu::ClassifyPMItem { pLabel pDsn pDsnRoot pOpj } {
    set lLabel [string trim $pLabel]
    if { $lLabel eq "" } {
        return [list other ""]
    }
    set lLow  [string tolower $lLabel]
    set lRoot [string tolower [file rootname [file tail $lLabel]]]

    # The extension is the strongest evidence there is.
    if { [string match "*.dsn" $lLow] } { return [list design  $pDsn] }
    if { [string match "*.opj" $lLow] } { return [list project $pOpj] }

    # No extension - the project's root node is shown by name only, so fall back
    # to comparing that name with the two files the PM already knows about.
    if { $pOpj ne "" && $lRoot eq [string tolower [file rootname [file tail $pOpj]]] } {
        return [list project $pOpj]
    }
    if { $pDsn ne "" && $lRoot eq [string tolower [file rootname [file tail $pDsn]]] } {
        return [list design $pDsn]
    }
    if { $pDsnRoot ne "" && $lLow eq [string tolower $pDsnRoot] } {
        return [list design $pDsn]
    }
    return [list other ""]
}

proc ::mUtilMenu::DoSchematicCheck { pVia } {
    ::mUtilMenu::Trace "Schematic Check callback reached via $pVia"

    # A missing command or an inactive PM both land here as an error rather than
    # an empty list, and "could not ask" is not the same answer as "nothing is
    # selected" - so it is reported as itself.
    set lItems  [list]
    set lAsked  1
    if { [catch { set lItems [GetSelectedPMItems] } lErr] } {
        set lAsked 0
        ::mUtilMenu::Trace "GetSelectedPMItems failed -> $lErr"
    }

    set lOpj ""
    catch { set lOpj [GetActiveOpjName] }

    set lInfo    [::mUtilMenu::ActivePMDesignInfo]
    set lDsn     [lindex $lInfo 0]
    set lDsnRoot [lindex $lInfo 1]

    set lItemName ""
    set lItemType ""
    catch { set lItemName [GetPMItemName] }
    catch { set lItemType [GetPMItemType] }

    # Always dumped, whatever the answer turns out to be: this block is the raw
    # material for working out what GetPMItemType returns.
    ::mUtilMenu::Out "================================================================"
    ::mUtilMenu::Out "Schematic Check - Project Manager selection"
    ::mUtilMenu::Out "================================================================"
    ::mUtilMenu::Out [format "  %-22s %s" "GetSelectedPMItems" \
              [expr { $lAsked ? $lItems : "ERROR / not available" }]]
    ::mUtilMenu::Out [format "  %-22s %s" "GetPMItemName"      [::mUtilMenu::OrDash $lItemName]]
    ::mUtilMenu::Out [format "  %-22s %s" "GetPMItemType"      [::mUtilMenu::OrDash $lItemType]]
    ::mUtilMenu::Out [format "  %-22s %s" "GetActiveOpjName"   [::mUtilMenu::OrDash $lOpj]]
    ::mUtilMenu::Out [format "  %-22s %s" "active design file" [::mUtilMenu::OrDash $lDsn]]
    ::mUtilMenu::Out [format "  %-22s %s" "active design root" [::mUtilMenu::OrDash $lDsnRoot]]

    set lHits [list]
    foreach lLabel $lItems {
        set lCls  [::mUtilMenu::ClassifyPMItem $lLabel $lDsn $lDsnRoot $lOpj]
        set lKind [lindex $lCls 0]
        ::mUtilMenu::Out [format "    %-34s -> %s" $lLabel $lKind]
        if { $lKind ne "other" } {
            lappend lHits [list $lKind $lLabel [lindex $lCls 1]]
        }
    }

    if { [llength $lHits] == 0 } {
        if { !$lAsked } {
            set lMsg "Could not read the Project Manager selection.\n\nIs a project open, and is PROJECT_MANAGER_VIEW the active window?"
        } elseif { [llength $lItems] == 0 } {
            set lMsg "Nothing is selected in the Project Manager.\n\nClick a Design (.DSN) or the Project (.OPJ) and try again."
        } else {
            set lMsg "The Project Manager selection is not a Design or a Project.\n\nSelected:  [join $lItems {, }]\n\nClick a Design (.DSN) or the Project (.OPJ) and try again."
        }
        ::mUtilMenu::Out "  -> not a Design or Project"
        catch { capDisplayMessageBox $lMsg "Schematic Check" }
        return true
    }

    set lMsg "Project Manager selection:\n"
    foreach lHit $lHits {
        set lKind [string totitle [lindex $lHit 0]]
        set lPath [lindex $lHit 2]
        if { $lPath eq "" } {
            # Classified by its own extension, but the PM could not say where the
            # file is - name it anyway rather than dropping the answer.
            append lMsg "\n$lKind:  [lindex $lHit 1]\nPath:    (not available from the Project Manager)\n"
        } else {
            append lMsg "\n$lKind:  [file tail $lPath]\nPath:    [file nativename $lPath]\n"
        }
        ::mUtilMenu::Out "  -> $lKind [lindex $lHit 1]"
    }
    catch { capDisplayMessageBox [string trimright $lMsg "\n"] "Schematic Check" }
    return true
}

#=============================================================================
# Path A - mUtil top-level menu, via InsertXMLMenu
#=============================================================================

proc ::mUtilMenu::XmlSchematicCompare { args } { return [DoSchematicCompare "mUtil menu"] }
proc ::mUtilMenu::XmlSchematicCheck   { args } { return [DoSchematicCheck   "mUtil menu"] }
proc ::mUtilMenu::XmlClosePage        { args } { return [DoClosePage        "mUtil menu"] }

proc ::mUtilMenu::initXmlMenu { } {
    catch {
        RegisterAction "mUtilMenuAction"  "::mUtilMenu::True" "" "::mUtilMenu::Action"  ""
        RegisterAction "mUtilMenuEnabler" "::mUtilMenu::True" "" "::mUtilMenu::Enabler" ""

        RegisterAction "mUtilSchCompareAction"  "::mUtilMenu::True" "" \
            "::mUtilMenu::XmlSchematicCompare" ""
        RegisterAction "mUtilSchCompareEnabler" "::mUtilMenu::True" "" \
            "::mUtilMenu::Enabler"             ""

        RegisterAction "mUtilSchCheckAction"  "::mUtilMenu::True" "" \
            "::mUtilMenu::XmlSchematicCheck" ""
        RegisterAction "mUtilSchCheckEnabler" "::mUtilMenu::True" "" \
            "::mUtilMenu::Enabler"           ""

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

        # "1" <refId> = insert AFTER that sibling, the anchored form
        # orEagleImportInit.tcl:11-12 uses under File > Import Design.  The call
        # also sits physically between the other two, so the order comes out
        # Schematic Compare / Schematic Check / Close Page either way - by the
        # anchor, or by plain insertion order if the anchor were ignored.
        InsertXMLMenu [list \
            [list $::mUtilMenu::mMenuId "mUtilSchCheck"] "1" "mUtilSchCompare" \
            [list "action" "Schematic Check" "0" \
                  "mUtilSchCheckAction" "mUtilSchCheckEnabler" "" ""] \
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
proc ::mUtilMenu::PageSchematicCheck     { pPage pOcc } { DoSchematicCheck   "Accessories (page)" }
proc ::mUtilMenu::PageClosePage          { pPage pOcc } { DoClosePage        "Accessories (page)" }
proc ::mUtilMenu::DesignSchematicCompare { pLib }       { DoSchematicCompare "Accessories (design)" }
proc ::mUtilMenu::DesignSchematicCheck   { pLib }       { DoSchematicCheck   "Accessories (design)" }
proc ::mUtilMenu::DesignClosePage        { pLib }       { DoClosePage        "Accessories (design)" }

proc ::mUtilMenu::addPageAccessoryMenu { } {
    AddAccessoryMenu "mUtil" "Schematic Compare" "::mUtilMenu::PageSchematicCompare"
    AddAccessoryMenu "mUtil" "Schematic Check"   "::mUtilMenu::PageSchematicCheck"
    AddAccessoryMenu "mUtil" "Close Page"        "::mUtilMenu::PageClosePage"
}

proc ::mUtilMenu::addDesignAccessoryMenu { } {
    AddAccessoryMenu "mUtil" "Schematic Compare" "::mUtilMenu::DesignSchematicCompare"
    AddAccessoryMenu "mUtil" "Schematic Check"   "::mUtilMenu::DesignSchematicCheck"
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
    # Before the menus: LoadConfig only sets variables, and having the remembered
    # folder in place before anything can open the dialog is one less order to
    # think about.
    catch { ::mUtilMenu::LoadConfig }
    ::mUtilMenu::initXmlMenu
    ::mUtilMenu::initAccessoryMenu
}

proc ::mUtilMenu::remove { } {
    ::mUtilMenu::CloseSchematicCompare
    ::mUtilMenu::ClosePageSelector
    ::mUtilMenu::CloseResultWindow
    catch {
        DeleteXMLMenu [list $::mUtilMenu::mMenuId "mUtilSchCompare"]
        DeleteXMLMenu [list $::mUtilMenu::mMenuId "mUtilSchCheck"]
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
                svsDiffDesigns capDisplayMessageBox SetAppWindowAsParent \
                GetSelectedPMItems GetPMItemName GetPMItemType \
                GetActivePMDesign GetActiveOpjName } {
        ::mUtilMenu::Out [format "  %-36s %s" $c [expr {[info commands $c] eq "" ? "MISSING" : "ok"}]]
    }

    ::mUtilMenu::Out "--- Tk ---"
    if { [catch { package require Tk } lVer] } {
        ::mUtilMenu::Out "  package require Tk        FAILED: $lVer"
    } else {
        ::mUtilMenu::Out "  package require Tk        ok (Tk $lVer)"
    }

    ::mUtilMenu::Out "--- menu nodes ---"
    foreach p { {mUtil} {mUtil mUtilSchCompare} {mUtil mUtilSchCheck} \
                {mUtil mUtilClosePage} {Tools} {Accessories} } {
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
