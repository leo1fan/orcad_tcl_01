#/////////////////////////////////////////////////////////////////////////////////
#  TCL file: mUtilMenu.tcl
#
#  mUtil - OrCAD Capture 17.4 schematic utilities
#
#  Version   1.01
#  Author    LEO
#  Company   ASROCK
#
#  Not a Cadence file.  Installing a Capture hotfix deletes everything under
#  capAutoLoad that the installer does not know about, this file included, so
#  keep a copy outside the tools tree and put it back after an upgrade.
#
#  The three fields above are also namespace variables - mVersion, mAuthor,
#  mCompany - so they can be read at run time:
#
#      puts [::mUtilMenu::About]        ->  mUtil 1.01 - LEO, ASROCK
#
#  mVersion is the only one of the three that anything prints on its own: it goes
#  on the banner line of every report (see VerStr and Banner).  The author and
#  company are carried, not announced - nothing in normal operation shows them,
#  and About / diag are where to look.
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
#     Schematic Check   -> Tk dialog: one CHECKBOX per check, both ticked by
#                          default, Start / Close.  Start runs every ticked check
#                          over whatever PROJECT_MANAGER_VIEW has selected (a
#                          page, a schematic, the .DSN or the .OPJ); Close does
#                          nothing.  Each box IS a global variable, so the state
#                          is readable and settable from the Command Window:
#                            SCH_CHECK_ITEM1  NETs not on Grid, cause connection
#                              missing - near misses found, marked on the page
#                              with a pink/grey line and a blue box.  A schematic
#                              / .DSN / .OPJ run also renames each marked page
#                              '*' and prints "... has finished" per page; ONE
#                              selected page does neither - nothing to find your
#                              way back to, and no wait to report on.
#                            SCH_CHECK_ITEM2  NETs have no global reference, but
#                              net name is the same - every net whose schematic
#                              name is the page label plus a serial number
#                              (+3.3VSB drawn, +3.3VSB_9631 in the netlist),
#                              listed under "Nets name may conflict:" and marked
#                              on the page with a pink line over every one of its
#                              wires.  The page is NOT renamed '*'.
#                          1 = ticked, 0 = not.  Both ticked is ONE pass over the
#                          pages, not two.  The report goes in a read-only text
#                          window, not a message box, so it can be selected and
#                          copied.  See the Schematic Check block.
#     Close Page        -> walks EVERY design the session has open, one at a
#                          time, and closes that project's pages while leaving
#                          its Project Manager standing.  The project that was
#                          active before is active again afterwards.
#                          mClosePageMode switches it to active-project-only,
#                          to Window > Close All, or back to the old "all tabs
#                          but this one".
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
#                     similar  red text, dashed line.  Any ONE of: the two names
#                              are identical once every
#                              mPageNameRedundantChars character is taken out of
#                              them ("096. BMC AST2600" = "096 - BMC  AST2600");
#                              or their first mPageSimilarChars (10) characters
#                              agree; or the first mPageCompactSimilarChars (7)
#                              characters of those compacted names agree.
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
#                   what the pink lines over (N)'s net wires come from, under the
#                   first four rules below, tried in this order (NetlistCompare;
#                   grep the file for net_compare_rule to change one of them).
#                   Rule 5 is the odd one out: it walks the PARTS, not the
#                   netlists, and it draws a stub rather than covering a wire.
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
#                                        PHYSICAL ENDPOINTS on it differ.  An
#                                        endpoint is a part pin ("U1D.E43") or an
#                                        Off-Page / Power / Port symbol
#                                        ("OFFPAGE:DDI2_TXP3"), compared by that
#                                        IDENTITY and never by where it sits - the
#                                        same pin wired at a new coordinate is the
#                                        same connection, and a swapped off-page
#                                        connector is a change even though the
#                                        global/local bit rule3 tests stays 1.
#                                        Marks every wire of (N)'s net whose own
#                                        two END coordinates include an endpoint
#                                        (N) has and (O) has not.  A wire with no
#                                        endpoint at either end, or with endpoints
#                                        both designs share, is left alone.
#                                        mRule4MarkMinPins (1) filters PART PINS
#                                        only: a changed pin on a part of that many
#                                        pins or fewer is listed as skipped in the
#                                        Command Window and never drawn or
#                                        reported.  A symbol has no pin count and
#                                        is never filtered.  At 1 the filter is all
#                                        but off - it used to be the same number as
#                                        mRule4MinPins (5), and hiding two-pin
#                                        passives hid real re-wiring; the two were
#                                        split so the cost knob could stay up while
#                                        the filter came down.  See the variables.
#                                        An endpoint only (O) had is reported and
#                                        not marked - (N) has no position for it -
#                                        and is held to the same pin count.
#                     net_compare_rule5  a pin that came loose.  For every part
#                                        BOTH designs have (matched on Part
#                                        Reference), every pin the two share is
#                                        asked whether it is unconnected on (N)
#                                        while it was on a net on (O).  If it is,
#                                        (N) gets a pink stub at that pin: one end
#                                        exactly on the pin's connection point,
#                                        the other mRule5StubLen (0.4in = four
#                                        0.1in grid steps) out through the nearest
#                                        edge of the part's bounding box, so it
#                                        points away from the part body and never
#                                        back through it.  Ties and anything that
#                                        cannot be worked out go right.
#                                        Rules 1-4 cannot see this: a net that
#                                        lost its last pin is not in (N)'s netlist
#                                        at all, so there is no (N)-side record to
#                                        walk and no wire left to draw over - but
#                                        the PIN is still there, which is what
#                                        rule5 points at.  No pin-count filter:
#                                        a two-pin part that came unwired is a
#                                        finding.  mRule5 0 turns it off.
#                                        It is the one thing that makes (N)'s dump
#                                        read differently from (O)'s: (N) is
#                                        dumped with mPinPosAll raised so its
#                                        unconnected pins report a position, which
#                                        is where the stub goes.
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
#                   marks by mLineOffset.  Rule5's stubs are the exception to the
#                   nudge: they are drawn exactly where they were worked out,
#                   because a stub says "this pin" and a nudged one would say the
#                   pin next door.
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
#                   DumpFullCompare, same net_compare_rule1..5 markers - but over
#                   every mapped page pair at once: every pair the selector drew a
#                   line for, solid or dashed.  A page with no line is not
#                   compared and not touched.
#                   BOTH WAYS by default - the "(N)(O)BOTH COMP" box on the
#                   selector's legend row, ::BOTH_N_O_COMP.  Ticked, each pair is
#                   compared once with (O) as the baseline and (N) marked, and
#                   again with the two swapped so (O) is the one that gets the
#                   pink lines and the turquoise rectangles.  That second pass is
#                   not a repeat: only the NEW side of a diff is ever drawn, so a
#                   part, a net or a wired pin that only (O) has draws nothing in
#                   the forward pass and is exactly what the backward one finds.
#                   ONLY (N) IS EVER RENAMED - the backward pass draws on (O) and
#                   leaves its page names alone, '*' and all.  Untick the box for
#                   the forward pass on its own, which is what the button did
#                   before the box existed.
#                   No page dump and no timing: both would be paid once per pair,
#                   which is thousands of Command Window lines and a measuring
#                   overhead for an answer that is a count (ComparePagePair turns
#                   mQuiet on and mTimeCompare off around each pair).  What the
#                   Command Window gets instead is ONE LINE PER PAIR as it
#                   finishes, so a long run shows where it is:
#
#                     AllPagesComp - (N) new.dsn   (O) old.dsn
#                       (N)(O)BOTH COMP is on - every pair is compared both ways; only (N) is renamed
#                       (N) PAGE1   (O) PAGE1   Page comparison finished - no difference
#                       (O) PAGE1   (N) PAGE1   Page comparison finished - no difference
#                       (N) PAGE2   (O) PAGE2   Page comparison finished - 7 marker(s), '*' added
#                       (O) PAGE2   (N) PAGE2   Page comparison finished - 2 marker(s), page name left alone
#
#                   Page names only - the schematic name is the same on every line
#                   of a run, so it is said once in the header and left off.  The
#                   MARKED page leads its line, which is what the "(N)"/"(O)" at
#                   the front says: it is the page to open next.
#
#                   Each (N) page that came out different keeps its markers AND
#                   gets a '*' put in front of its name, so PROJECT_MANAGER_VIEW
#                   shows which pages changed.  An (O) page the backward pass drew
#                   on keeps its markers and its name - it has to be saved too, and
#                   the message box says so.  Ends in one message box with the
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
    # Who this is and what it is.  See the file header.
    #
    # mVersion is printed - it is on the banner of every report, so a pasted-back
    # log always says which build produced it, which is the whole reason for
    # having a version at all.  Bump it here and every banner follows; nothing
    # else hard-codes the number.
    #
    # mAuthor and mCompany are NOT printed by anything that runs normally.  They
    # are here to be carried with the file and to be readable on request - About
    # returns them, diag prints them - and deliberately nowhere else: a dump is
    # for reading schematic data, not for reading a byline, and the column
    # alignment in those dumps is worked out to the character.
    variable mVersion "1.01"
    variable mAuthor  "LEO"
    variable mCompany "ASROCK"

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

    # The same threshold for the COMPACTED name - the name with every
    # mPageNameRedundantChars character taken out of it, wherever it sat.  Lower
    # than mPageSimilarChars on purpose: compacting has already thrown away the
    # separators, so seven characters of a compacted name carry more of the name
    # than ten characters of a name still padded with dots and spaces.
    #
    #   "*096. BMC AST2600 UART"  ->  "096BMCAST2600UART"
    #    ^^^^^^^^^^ 10 raw chars       ^^^^^^^ 7 compacted chars
    #
    # Set it to 0 to turn the compacted-head pass off and keep only the
    # compacted-exact pass.
    variable mPageCompactSimilarChars 7

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

    # The longest object name Capture's database will accept.  A page renamed past
    # it is taken in memory and rejected at save time, taking the whole design
    # down with it:
    #
    #   ERROR(ORCAP-1650): Unable to save '...DSN'.
    #   ERROR(ORDBDLL-1096): Invalid object name. Perhaps greater than 32 characters.
    #
    # 32 is the number the error message itself names.  StarPageObj is the only
    # thing here that lengthens a name - by exactly the one '*' - and it now
    # refuses rather than produce a design that cannot be written.  Lower this if
    # a build turns out to be stricter than its own error message.
    variable mPageNameMaxChars 32

    # Marker characters a page name may be prefixed with - "*PAGE1", "--PAGE1",
    # "~PAGE1" all mean PAGE1 as far as the A/B mapping is concerned, so they are
    # stripped off the front before the two names are compared.  Whitespace is in
    # the set too, otherwise "* PAGE1" would keep a leading space and never match.
    variable mPageNamePrefixChars "*-?~+%\$#@! \t"

    # Punctuation and whitespace that says nothing about WHICH page a page is, so
    # the "similar" passes are allowed to take it out of the middle of a name as
    # well as off the front:
    #
    #   "*096. BMC AST2600 UART,SPI,MAC"  ->  "096BMCAST2600UART,SPI,MAC"
    #
    # That makes two pages the same page across a renumbering that only moved the
    # separators about ("096.BMC AST2600" vs "096 - BMC  AST2600").  It is a
    # SUPERSET of mPageNamePrefixChars - the same characters plus "." - so
    # compacting a name that has already been through StripPageNamePrefix gives
    # the same answer as compacting the raw name, which is why PageKeyCompact can
    # take the stripped key and not the page name.
    #
    # The comma is deliberately NOT in here: "UART,SPI,MAC" is a list of what is
    # on the page, and dropping the separators out of it would run three distinct
    # names together.
    #
    # Only the similar passes use this.  "exact" still means exact after nothing
    # but the leading markers came off - see Page_name_mapping.
    variable mPageNameRedundantChars "*.-?~+%\$#@! \t"

    # Serial number for the SWIG iterator command names built in NextIterName.
    variable mIterSeq 0

    # Units the page dump prints coordinates in:
    #   user - the page's OWN user unit, as Capture's status bar shows it (default)
    #   doc  - raw internal integers, exact but granularity-dependent
    #
    # "user" is not necessarily inches.  GetPhysicalGranularity is doc units per
    # USER unit, and a metric page's user unit is the millimetre - which is why a
    # metric page dumps coordinates like (152.40,119.38) where an inch page of the
    # same size dumps (6.00,4.70).  DboPage::GetIsMetric is what tells the two
    # apart and CoordUnitLabel is what asks it, so every column heading says which
    # of the two it is printing.
    variable mCoordMode "user"

    # Decimal places every "user" coordinate is printed to - see Coord, which is
    # the single place the conversion happens, so this moves Parts, Symbols, Nets,
    # Buses, the pin connection points and the measured gaps together.
    #
    # 2, because that is the whole of the precision there is to print.  The
    # database holds positions as INTEGER doc units - every getter behind these
    # columns (DboWire GetStartPoint / GetEndPoint for net and bus ends,
    # GetOffsetHotSpot for a pin, GetLocation for a symbol) returns a CPoint whose
    # x and y are ints - so the printed value is doc/granularity and its resolution
    # is one part in the granularity.  At the usual granularity of 100 the smallest
    # step that can exist is 0.01 of a user unit (0.01 in, or 0.01 mm on a metric
    # page) and a third decimal can only ever print 0.  Cadence's own converter
    # truncates at the same place (capDRCFramework/tcl/capCustomDRC.tcl:159-161).
    #
    # Raise it to 3 only for a page whose grid block reports a granularity of 1000.
    variable mCoordDecimals 2

    # What Compare marks on the (N) page once it is done.  Both are filled by
    # DumpFullCompare, consumed by DrawCompareMarkerLine, and reset at the top of
    # every compare so a second Compare never redraws the first one's findings.
    # Coordinates are doc units, straight off the object - never re-parsed out of
    # the printed dump, which is rounded to mCoordDecimals places.
    #
    #   mMarkSegs   one line per wire to mark, {label x1 y1 x2 y2}.  Two sources:
    #                 nets   whatever net_compare_rule1..4 hit - see
    #                        NetlistCompare.  The label is "rule<n> <netname>".
    #                 buses  one per bus wire (N) has and (O) has not
    #   mMarkBoxes  one rectangle per part (N) has and (O) has not, around its
    #               bounding box, {label left top right bottom}
    #   mMarkPinSegs  net_compare_rule5's stubs, {label x y direction} - the pin's
    #               own connection point and which way to grow the line out of it.
    #               A THIRD list and not more mMarkSegs entries, for two reasons:
    #               the length is a setting in user units and only the page knows
    #               its granularity, so the far end cannot be worked out until
    #               draw time; and mMarkSegs is nudged clear of the wire it marks
    #               by OffsetSeg, which would pull a stub off the very pin it is
    #               pointing at.  See PartPinConnCompare and DrawMarkersOnPage.
    variable mMarkSegs    [list]
    variable mMarkBoxes   [list]
    variable mMarkPinSegs [list]

    # How far the marker is moved off the wire it marks, so it does not simply
    # cover it: a horizontal wire's marker goes up by this much, a vertical wire's
    # marker goes right by it.  Diagonal wires are marked in place.
    #
    # Given in the user units the dump prints - the 220.220 / 65.020 in
    # "(220.220,65.020)-(204.220,65.020)" - and multiplied by the page's physical
    # granularity to reach the doc units the Dbo call wants.  Set
    # mLineOffsetUnits to "doc" to give it in raw doc units instead.
    # 0 = no nudge at all: the marker sits exactly on top of the wire it marks.
    variable mLineOffset      0
    variable mLineOffsetUnits "user"

    # pMax for RefListStr on the categories that are still capped (Parts, Symbols,
    # and everything Refcompare reports).  Nets and Buses are listed in full.
    variable mRefListMax 200

    # TWO pin-count thresholds, because the one variable was doing two jobs that
    # want different answers.  Both are "a part with this many pins or FEWER",
    # counted as the placed instance's OWN pins (element 10 of a part row), so one
    # section of a multi-part package counts its own section's pins.
    #
    #   mRule4MinPins       how big a part has to be before the parts walk spends
    #                       three Dbo calls reading each of its pins' positions.
    #                       A COST knob, nothing else - see CollectPageParts.
    #   mRule4MarkMinPins   how big a part has to be before net_compare_rule4 will
    #                       draw a line at a changed pin on it.  The FILTER the
    #                       rule actually applies - see NetlistCompare.
    #
    # WHY THEY DIFFER.  The filter wants to be off: at 5 it swallowed a whole M.2
    # page's worth of real re-wiring on W980_WS, where the TX pairs had been
    # re-ordered between revisions by swapping which AC-coupling capacitor sat on
    # which net -
    #
    #     PCD_PCIE_A_TX_4_DN   M2SC80.2 only on (N) - part has 2 pins ... skipped
    #     PCD_PCIE_A_TX_4_DN   M2SC85.2 only on (O) - part has 2 pins ... skipped
    #
    # - eight nets and sixteen endpoints, every one a genuine connectivity change
    # and not one of them drawn.  The filter cannot tell "this resistor moved to
    # another net" from "a different capacitor is on this net now"; it only counts
    # pins, and missing a real change is the worse of the two failures.
    #
    # The cost knob wants to stay up: dropping it to 1 as well means reading a
    # position for very nearly every pin of every part, which on a 3000-pin page
    # is most of a second per side and, over AllPagesComp's 149 page pairs in both
    # directions, minutes.
    #
    # They can differ because rule4 only ever needs positions on the (N) side, and
    # (N) is already dumped with mPinPosAll raised - see NeedAllPinPos, which is
    # what keeps the two consistent no matter how they are set.
    #
    # Off-Page / Power / Port endpoints carry no pin count and are never filtered
    # by either, whatever they are set to.
    variable mRule4MinPins     5
    variable mRule4MarkMinPins 1

    # net_compare_rule5 - a pin that LOST its connection.
    #
    # For every part both designs have, matched on Part Reference, every pin the
    # two have in common is asked one question: is it unconnected on (N) while it
    # was on a net on (O)?  If it is, a pink stub is drawn at that pin on (N) -
    # one end ON the pin's own connection point, the other mRule5StubLen away,
    # pointing out of the part.  Nothing is drawn the other way round: a pin that
    # GAINED a net is already a rule2/rule3/rule4 finding on the net itself.
    #
    # Why a rule of its own rather than more rule4.  Rule4 compares two netlists,
    # and a net that lost its last pin is not in (N)'s netlist at all - there is
    # no (N)-side record left for rule4 to walk.  It sees the net vanish, not the
    # pin come loose, and a vanished net has nothing on (N) to draw on.  Rule5
    # walks the PARTS, which are still there on both sides, so the pin is still
    # there to point at.
    #
    # 0 turns it off, and with it the extra pin-position read on (N) - see
    # mPinPosAll and RunPageCompare.  That read is what rule5 costs: three Dbo
    # calls for every pin of every part on (N)'s page, where the compare
    # otherwise pays them only for pins that are on a net.
    variable mRule5 1

    # How long rule5's stub is, and in what.  4 SNAP GRID STEPS by default - the
    # "4個Grid" the rule was specified in - which is long enough to find by eye at
    # a whole-page zoom and short enough not to reach the next part along.
    #
    # mRule5StubLenUnits is GridTolDoc's three modes, not MarkOffsetDoc's two, and
    # the difference is the whole point:
    #
    #   grid  (DEFAULT) mRule5StubLen x mGridStepInch x GetDocUnitsPerInch.
    #   user  x GetPhysicalGranularity - the page's OWN unit.
    #   doc   raw integers.
    #
    # WHY NOT "user", WHICH IS WHAT THIS STARTED AS.  GetPhysicalGranularity is
    # doc units per USER unit, and on a metric page the user unit is the
    # millimetre.  W980_WS is such a page, and "0.4 user" there asked for 0.4 MM:
    #
    #   pin U1D.E43 at (128.02,19.30) mm = (504,76) doc
    #   0.4 x 3.937 doc/mm = 1.57 -> 2 doc units, a stub 0.5 mm long
    #
    # against the 40 doc units - 4 x 0.1in, 10.16 mm - the rule asks for.  A
    # twentieth of the intended length, on a page whose pin pitch is 10 doc units,
    # which is why the markers were there and invisible.  Grid steps are the only
    # unit that means the same thing on both kinds of page: Capture's schematic
    # grid is 0.1 in and the standard libraries are built on it whatever the page
    # displays in, so 4 steps is 4 steps either way.  Inch pages are unaffected -
    # 4 steps there is the same 0.4 in it always was.
    variable mRule5StubLen      4
    variable mRule5StubLenUnits "grid"

    # 1 = the Nets dump prints the schematic-wide net name in brackets after the
    #     page label whenever the two differ:
    #
    #       Nets    +3.3VSB (+3.3VSB_9631)       wires: 6
    #
    #     which says the label drawn on this page is +3.3VSB but what the netlist
    #     sees is +3.3VSB_9631, because another page has its own +3.3VSB and
    #     nothing joins the two.  Matching names print once, unbracketed, so a
    #     bracket in this column always means something.
    # 0 = page label only, the way it printed before.
    #
    # It costs one extra call per net (SchNetName) and nothing else: element 0 of
    # a net row is untouched, so the compare signatures, the netlist rules and
    # Schematic Check's net lists all see exactly what they saw before.
    variable mNetShowSchName 1

    # 1 = the Nets section leaves BUSES out.  Two separate skips, and the second
    #     is the one that matters:
    #
    #       IsBusNet    drops the bus's own net object.  DboPageNetsIter hands
    #                   back every net on the page and a bus IS a net, so without
    #                   this the bus appears as a row of its own as well as under
    #                   Buses.
    #       IsBusWire   drops the bus's wires out of a bus MEMBER's wire list.
    #                   DboNet::NewWiresIter on V_M_BMC_DDR4_DQ0 returns the bus
    #                   wires the member travels along, and so does every other
    #                   member - one real page had 482 of 835 wire lines being the
    #                   same bus repeated, and 400 false "two nets that did not
    #                   merge" findings out of it, because sixteen nets were all
    #                   claiming an endpoint at the same coordinate.
    #
    # 0 = the old behaviour: bus wires appear under Nets, once per member net,
    #     as well as under Buses.
    #
    # Bus MEMBERS themselves are unaffected either way.  D[0] is a scalar net that
    # belongs to a bus, not a bus; what it loses is only the bus's wires, and it
    # keeps its own - the piece of wire that runs from the pin to the bus, which
    # is the part a near-miss check has any business looking at.
    #
    # This changes what the Nets rows ARE, so unlike mNetShowSchName it is visible
    # to everything reading them - the compare's Nets signature diff, NetsByName
    # and the netlist rules, and Schematic Check's two checks.  That is the point:
    # a bus was never a signal any of them should have been reasoning about.
    # NetLabelOf applies the same wire skip, so the name a pin reports and the
    # name the Nets section prints cannot drift apart.
    variable mNetSkipBuses 1

    # 1 = a symbol's connection point is snapped to the nearest edge MIDPOINT of
    #     its bounding box.  See SymHotSpotDoc, which is also where the rotated
    #     GND symbol that made this necessary is written up.
    #
    #     The assumption, and it is worth stating because it is the whole basis of
    #     the snap: an off-page connector, a power/ground symbol and a port each
    #     have exactly ONE pin and it is centred on one edge of the symbol.  That
    #     is true of every stock symbol and of every custom one this project has,
    #     but a home-made symbol with an off-centre pin would be moved to the
    #     middle of its edge by this - by at most half an edge.
    # 0 = take the getter's answer as it stands.  Correct for such a symbol, and
    #     wrong by half a symbol for every rotated stock one, which is why it is
    #     not the default.
    #
    # Either way this is only reached when the symbol has NO wire on it: a symbol
    # that is connected gets its pin from the wire end, exactly, and neither this
    # nor the getters are consulted.
    variable mSymHotSpotSnap 1

    # 1 = the Parts dump prints one line per pin - pin number, pin name, the pin's
    #     connection point in doc units, and what the pin is connected to
    #     (net name / NC / unconnected).
    # 0 = the old single "pins: A B C" line of pin names.
    # Only the printout changes either way: the pins the two compares diff on are
    # the pin NAMES in element 5 of a part row, which this does not touch.  The
    # netlist compare reads the connection point whatever this is set to - it goes
    # through CollectPinInfo, not through the printout.
    variable mPinDetail 1

    # 1 = read EVERY pin's connection point, wired or not.
    # 0 = only the pins that sit on a net, which is what a compare can use.
    #
    # This is the one place Schematic Check and Schematic Compare deliberately walk
    # the database differently, and the difference is paid for in time:
    #
    #   Compare (0)  a pin on no net is in no netlist, so net_compare_rule4 can
    #                never reach it - reading its position would be three Dbo calls
    #                spent on a number nothing looks at.  The mRule4MinPins filter
    #                skips whole small parts on top of that.
    #   Check   (1)  the dump IS the answer, and "where is this NC pin" is exactly
    #                what is being asked.  So both skips are lifted: every pin of
    #                every part gets its position read, and an unwired or
    #                no-connect pin prints its coordinates like any other.
    #
    # It changes the PRINTOUT only.  CollectNetlist skips a pin with no net before
    # it ever looks at element 4, so no compare's answer moves either way - the
    # cost is the only thing that does, which is why CheckOnePage raises it around
    # its own dump and puts it straight back.
    variable mPinPosAll 0

    # Schematic Check's near-miss search - see Search_Missing_connection_onGrid.
    # Two endpoints closer together than this, and not already on the same net,
    # are reported as "meant to touch, does not touch".
    #
    # mGridMinDis is what CheckOnePage passes as the proc's min_dis; the proc's
    # own default is the same 0.5, so calling it by hand from the Command Window
    # with no tolerance behaves the same way as the menu does.
    #
    # mGridMinDisUnits says what the NUMBER means - GridTolDoc is the conversion:
    #
    #   grid  SNAP GRID STEPS (default).  0.5 = half a step, whatever the page's
    #         user unit happens to be, because the step is defined in inches
    #         (mGridStepInch) and converted with DboPage::GetDocUnitsPerInch.
    #         Half a step is the tolerance that answers the actual question: a
    #         wire that stopped less than one grid step short of what it was drawn
    #         towards.  Anything further away than that is geometry the RD placed
    #         deliberately.
    #   user  the units the dump prints.  Watch out: those are the PAGE's units,
    #         so on a metric page 0.05 means 0.05 MM - a fiftieth of a grid step,
    #         which is tight enough to find nothing at all.  This mode is for
    #         saying "anything within 0.3 mm" on purpose, not for grid work.
    #   doc   raw doc-unit integers, no conversion.
    #
    # The mode exists because "half a grid step" was the intent and "0.05" only
    # meant that on an inch page: the same 0.05 on a metric page came to 0.05 mm
    # and quietly missed a 0.25 mm near-miss.  Steps are unit-free, so grid mode
    # cannot be read wrong on either kind of page.
    variable mGridMinDis      0.5
    variable mGridMinDisUnits "grid"

    # One snap grid step, in INCHES.  Capture's schematic grid is 0.1 in and every
    # standard library part is built on it, metric page or not - which is why the
    # step is defined here in inches and converted per page rather than being
    # guessed from the coordinates.  Change it only for a design drawn on a
    # non-standard snap grid.
    variable mGridStepInch 0.1

    # How many near-miss pairs Search_Missing_connection_onGrid PRINTS, nearest
    # first.  It always returns and counts them all - this caps the listing only,
    # the same way mRefListMax caps the compare's.  A wide min_dis on a dense page
    # really can find thousands of pairs, and the first few hundred are the ones
    # worth reading.  0 or less = print everything.
    variable mGridListMax 200

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
    # 48-entry palette.  The table is in Capture.exe at FILE OFFSET 0xE33E40 (48
    # consecutive COLORREFs, 0x00BBGGRR), and it is the standard 8-wide by 6-tall
    # Windows colour grid.  Index 40 is black and 47 is white, which is exactly
    # what capDParts/capDynObjects.tcl:17-23 maps "black" and "white" onto - so
    # the COLORn number is that table's index, read straight off:
    #
    #     0 255,128,128    8 255,  0,  0   16 128, 64, 64   24 128,  0,  0
    #     1 255,255,128    9 255,255,  0   17 255,128, 64   25 255,128,  0
    #     2 128,255,128   10 128,255,  0   18   0,255,  0   26   0,128,  0
    #     3   0,255,128   11   0,255, 64   19   0,128,128   27   0,128, 64
    #     4 128,255,255   12   0,255,255   20   0, 64,128   28   0,  0,255
    #     5   0,128,255   13   0,128,192   21 128,128,255   29   0,  0,160
    #     6 255,128,192   14 128,128,192   22 128,  0, 64   30 128,  0,128
    #     7 255,128,255   15 255,  0,255   23 255,  0,128   31 128,  0,255
    #
    #    32  64,  0,  0   40   0,  0,  0  black
    #    33 128, 64,  0   41 128,128,  0
    #    34   0, 64,  0   42 128,128, 64
    #    35   0, 64, 64   43 128,128,128  the only mid grey
    #    36   0,  0,128   44  64,128,128
    #    37   0,  0, 64   45 192,192,192
    #    38  64,  0, 64   46  64,  0, 64
    #    39  64,  0,128   47 255,255,255  white
    #
    # The two compare markers were picked before that table was read and their
    # numbers were taken from a guessed ordering, so what they actually draw is
    # COLOR7 = RGB(255,128,255) light magenta (close enough to the pink that was
    # wanted) and COLOR9 = RGB(255,255,0) YELLOW rather than the turquoise the
    # comment used to claim.  Left as they are - the compare's colours are not
    # this change's business - but COLOR12 is the cyan, if the boxes should ever
    # actually be turquoise.
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

    # What Schematic Check draws on the page for each near miss it finds - see
    # MarkGridFindings.  Separate from the compare's mMark* set on purpose: the two
    # features mark for different reasons and should not have to share a palette.
    #
    #   mChkNetColor    the net the finding is ABOUT - "this net stops short"
    #                   COLOR6  RGB(255,128,192), the closest thing to pink in the
    #                   palette (COLOR7, the compare's, is a magenta)
    #   mChkOtherColor  the other net, when the near miss is net-against-net
    #                   COLOR43 RGB(128,128,128), the only mid grey there is - 40
    #                   is black and 45 is silver
    #   mChkBoxColor    the box round the pin's part, the symbol or the bus end
    #                   COLOR36 RGB(0,0,128) navy.  COLOR29 RGB(0,0,160) and
    #                   COLOR28 RGB(0,0,255) are the brighter blues if navy is too
    #                   dark against a dark page background.
    #
    # The lines are dash-dot for the same reason the compare's are: a solid pink
    # line lying along a net looks like schematic content and a dash-dot one
    # cannot be.  Boxes are solid.
    variable mChkNetColor   "DboValue_COLOR6"
    variable mChkOtherColor "DboValue_COLOR43"
    variable mChkBoxColor   "DboValue_COLOR36"
    variable mChkLineWidth  "DboValue_WIDE_WIDTH"
    variable mChkLineStyle  "DboValue_DASH_DOT_LINE"
    variable mChkBoxWidth   "DboValue_WIDE_WIDTH"
    variable mChkBoxStyle   ""

    # 1 = Schematic Check draws those markers on the page.  They are real graphic
    #     objects, so the page comes out MODIFIED and Capture will offer to save it
    #     - exactly like the compare's markers, and Undo takes them off again.
    # 0 = report in the Command Window and the message box only, touch nothing.
    variable mChkMark 1

    # 1 = a whole-schematic / whole-design / whole-project run also prints its
    #     per-page detail to the Command Window, the same as selecting each page
    #     on its own would.
    # 0 = only the final summary is printed (default).
    #
    # Nothing about WHAT gets checked changes either way - the pages are walked,
    # the rows collected and the markers drawn identically.  This is purely about
    # printing, and printing is the expensive part: a 100-page design's dumps are
    # a few hundred thousand lines through the Command Window, which takes far
    # longer than the search itself and buries the one summary anybody wanted.
    #
    # A single page selected in the Project Manager always prints everything -
    # for one page the dump IS the answer - and this setting does not apply to it.
    variable mChkBatchDetail 0

    # How many net names the message box lists under one page before it says
    # "+N more".  The Command Window listing is not capped by this; the dialog is
    # a fixed-size window and a page with sixty involved nets would push the
    # totals off the bottom of it.
    variable mChkNetListMax 12

    # The Schematic Check dialog - one CHECKBOX per check, Start / Close.  The
    # menu item does not check anything on its own: it asks which checks first,
    # because there is more than one thing that can be wrong with a net and they
    # cost very different amounts of time to look for.
    #
    # Checkboxes and not radio buttons, because the checks are not alternatives -
    # a design can have both faults at once and there is no reason to walk it
    # twice to be told so.  Both start ticked.
    #
    #   mChkWin   the toplevel, kept in a variable so a second menu click raises
    #             the dialog that is already open instead of building another one
    variable mChkWin ".mUtilSchCheck"

    # {value label globalVar} for every row of that dialog, in the order they are
    # shown, and the whole of what the dialog knows about the checks - adding a
    # third one means one entry here and one branch in RunSchematicCheckMode.
    #
    #   grid       NETs not on Grid, cause connection missing.  The near-miss
    #              geometry search - Search_Missing_connection_onGrid, and
    #              everything under RunSchematicCheckOnSelection.  The one that
    #              is written.
    #   globalref  NETs have no global reference, but net name is the same.  Two
    #              pages both carrying a net called +VCC1.8V with no Off-Page /
    #              Power / Port symbol on either of them: the two read as one net
    #              and are not joined, which is the same class of fault as the
    #              near miss but found by NAME across pages rather than by
    #              geometry within one page.  Capture makes the schematic-level
    #              names unique when that happens, and the serial number it hangs
    #              off one of them is the evidence - see NetNameConflictSuffix
    #              and PageNameConflicts.  Every wire of every net it finds is
    #              drawn over in pink (MarkNameConflicts), so the page shows which
    #              copper the report is talking about.  The page is not renamed
    #              '*' - that is the grid check's flag for "there is geometry to
    #              look at here", and the report already names the pages.
    #
    # Element 2 is the name of the checkbox's variable, and it is deliberately a
    # BARE GLOBAL rather than something under ::mUtilMenu.  These two are meant to
    # be read and written from the Command Window as SCH_CHECK_ITEM1 /
    # SCH_CHECK_ITEM2 with no namespace to spell, and the checkbutton is bound
    # straight to them, so ticking a box IS the assignment - there is no separate
    # copy that could disagree with what the dialog shows.
    variable mChkModes [list \
        [list grid      "NETs not on Grid, cause connection missing"              SCH_CHECK_ITEM1] \
        [list globalref "NETs have no global reference, but net name is the same." SCH_CHECK_ITEM2] ]

    # 1 = ticked.  Set here so they exist before the dialog is ever opened - the
    # Command Window, the no-Tk fallback and Start all read them whether or not a
    # window was built.  ChkItemsNormalize puts anything that is not 0 or 1 back
    # to a 0 or a 1 before they are used.
    set ::SCH_CHECK_ITEM1 1
    set ::SCH_CHECK_ITEM2 1

    # AllPagesComp's "(N)(O)BOTH COMP" box, in the page selector's legend row.
    #
    #   1 (default)  every mapped page pair is compared TWICE - once the way it
    #                always was, (O) as the baseline and the findings marked on
    #                (N), and then once with the two swapped, (N) as the baseline
    #                and the findings marked on (O).  Same rules both ways round,
    #                same pink lines, same turquoise rectangles, net_compare_rule5
    #                included.
    #   0            the forward pass only - exactly what AllPagesComp did before
    #                the box existed.
    #
    # ONLY (N) IS EVER RENAMED.  The '*' in front of a page name means "this page
    # came out different in the compare", and (N) is the side the run is about;
    # putting one on (O) as well would rewrite the reference design the user is
    # comparing AGAINST, and the next run would then have to strip its own marks
    # back off both sides to pair the pages up.  The backward pass draws and says
    # what it found, and leaves (O)'s page names alone.
    #
    # WHY BOTH DIRECTIONS ARE NOT THE SAME COMPARE.  The section diff is a
    # multiset difference and it is symmetric - forward New is backward Remove -
    # but only the NEW half is ever drawn, because a Remove is something the
    # marked page does not have and there is nowhere on it to put a marker.  So a
    # part that only (O) has gets a rectangle on (O) in the backward pass and
    # nothing at all in the forward one.  Same for net_compare_rule2 and rule5,
    # which are one-directional by construction.
    #
    # A bare global for the same reason SCH_CHECK_ITEM1/2 are: it is meant to be
    # read and set from the Command Window with no namespace to spell, and the
    # checkbutton is bound straight to it so ticking the box IS the assignment.
    set ::BOTH_N_O_COMP 1

    # What mUtil > Close Page closes.  See DoClosePage and the two procs above it
    # for the commands behind each one.
    #
    #   perdesign      THE DEFAULT.  Walks every design the session has open -
    #                  SessionDesigns - brings each one's Project Manager to the
    #                  front in turn, and closes that project's pages while
    #                  keeping its Project Manager.  Every page of every open
    #                  .DSN closed, every Project Manager still standing, and the
    #                  project that was active before is active again afterwards.
    #   allbutpm       the same thing for the ACTIVE project only, in one shot -
    #                  capCloseChildViews(GetActivePM()).  This was the default
    #                  until SessionDesigns existed; with two projects open it
    #                  protects one Project Manager and closes the other.
    #   all            Window > Close All: every child view, Project Manager
    #                  included.  capCloseChildViews().
    #   exceptcurrent  what this item did originally: every page BUT the one on
    #                  top - the tab RMB's "Close All Tabs But This".
    #                  capCloseChildViewsExceptCurrent().
    #
    # What none of them can do is close ONE named page: Appendix A has no
    # per-page close, only the three whole-frame ones above.  "Page by page" is
    # therefore per-DESIGN here, which is as fine-grained as the API goes.
    #
    # .OPJ files are not enumerated because they cannot be - see SessionDesigns.
    # A project's pages are its design's pages, so walking the designs covers the
    # projects; what is not covered is a .OPJ open with no design loaded, which
    # has no pages to close anyway.
    variable mClosePageMode "perdesign"

    # Which no-argument getter names the document Close Page must NOT close, in
    # the order they are tried.  Both return a CDocument, which is the type
    # capCloseChildViews declares for pExclude - GetActivePM does not, and that
    # is what made every call fail with "No matching function for overloaded
    # 'capCloseChildViews'".  The full story is at ClosePagesKeepingPM.
    #
    # Add a name here to try another one; drop one to stop trying it.  A getter
    # this Capture does not have is skipped, not an error.
    variable mClosePageDocGetters { capGetActivePMDoc capGetActiveDocument }

    # 1 = after closing, open every design again, so a project whose window went
    #     with its pages comes back.  This is what makes the no-argument
    #     capCloseChildViews safe to use - see ClosePagesOfActiveProject for why
    #     the exclude form is not available at all.  Open on a project that never
    #     closed simply activates it, so this costs nothing when it is not needed.
    # 0 = leave whatever the close did.  Only useful for finding out WHETHER the
    #     no-argument form takes the Project Manager with it: run Close Page once
    #     with this at 0 and look at what is left.
    variable mClosePageReopen 1

    # How many times Close Page will repeat the close on one project before it
    # gives up.  One call to capCloseChildViews does NOT empty the frame in this
    # Capture - the symptom that led here was "each project only lost a single
    # page" - so the close is repeated until EnableAllWindowCloseMenu() reports
    # nothing left.  See ClosePagesUntilDone.
    #
    # 200 is a backstop, not a budget: the loop normally ends because Capture
    # says there is nothing left, and the cap only matters if that never happens.
    # A design with more open pages than this would stop short and say so.
    variable mClosePageMaxRounds 200

    # The close commands Close Page will try, in order, and it moves on as soon
    # as one stops achieving anything - see ClosePagesUntilDone.
    #
    #   all            capCloseChildViews with NO argument.  Window > Close All,
    #                  which is what Cadence's own capCloseAllChildWindows.tcl:8
    #                  registers it as.  First because it is the only one that
    #                  can empty a project on its own.
    #   exceptcurrent  capCloseChildViewsExceptCurrent.  Known to work - it is
    #                  what closed pages on the very first run - but it can never
    #                  reach zero by itself, because the last page left is the
    #                  current one.  Useful as the follow-up, not as the answer.
    #
    # "exclude" - capCloseChildViews WITH a document - is deliberately NOT here.
    # It does not fail, it succeeds and closes nothing: a real run spent 200
    # rounds on it per project and shut no window at all.  Add it back only if a
    # Capture build turns up where the argument means something else, and put it
    # last if you do.
    variable mClosePageRoutes { all exceptcurrent }

    # How many rounds a route may change nothing before Close Page gives up on it
    # and tries the next.  2, because one round that changes nothing is already
    # suspicious and there is no cost to being wrong - the next route is tried,
    # not the whole thing abandoned.
    variable mClosePageStallRounds 2

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

    # How many times RestorePMSelection will go round its whole candidate list
    # before giving up, and how long it lets the UI run between rounds.
    #
    # WHY IT NEEDS TO RETRY AT ALL.  Renaming a page makes Capture rebuild the
    # Project Manager tree, and AllPagesComp renames once per changed page - a
    # hundred and fifty times on a real design.  Those rebuilds are not finished
    # when the loop is: they are still queued, and a rebuild that lands AFTER
    # SelectPMItem takes the selection with it.  The design is then sitting there
    # visibly modified with File > Save refusing it, which is exactly the
    # ERROR(ORCAP-1650) that took three sessions to corner.
    #
    # It is also why the (O) side never showed the problem: (O) is never renamed,
    # its tree is never rebuilt, and its selection stays put.
    #
    # mPMSettleMs 0 skips the settle entirely (update alone, no timed wait).
    variable mPMSelectTries 3
    variable mPMSettleMs    120

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

# A held-back block of lines, printed in one go.  DoSchematicCheck builds its
# selection diagnostics before it knows whether this run is allowed to print at
# all, so the lines are collected in a list and handed here once that is decided.
proc ::mUtilMenu::OutLines { pLines } {
    foreach lLine $pLines {
        ::mUtilMenu::Out $lLine
    }
}

# "mUtil 1.01" - what goes on a banner line.
#
# One place, so bumping mVersion moves every banner at once and none of them can
# be left saying an old number.
proc ::mUtilMenu::VerStr { } {
    variable mVersion
    return "mUtil $mVersion"
}

# The full identification, on request only.  Nothing in normal operation calls
# this - it is for the Command Window:
#
#   puts [::mUtilMenu::About]     ->  mUtil 1.01 - LEO, ASROCK
proc ::mUtilMenu::About { } {
    variable mAuthor
    variable mCompany
    return "[::mUtilMenu::VerStr] - $mAuthor, $mCompany"
}

# A report's first line: what produced it, which build, and what it is about.
#
#   ================================================================
#   mUtil 1.01  Schematic Check - Design W980_WS.DSN
#   ================================================================
#
# The version sits at the FRONT of the banner and nowhere else.  Putting it on
# every Out line was the other option and it is the wrong one: the dumps are
# column-aligned with format to the character - "%-28s wires: %d" and the rest -
# and a prefix on every line would push every column out and make the coordinate
# tables unreadable.  A banner per report says which build wrote the log just as
# well, and a log is read from the top.
proc ::mUtilMenu::Banner { pWhat } {
    return "[::mUtilMenu::VerStr]  $pWhat"
}

# Out, but mQuiet cannot silence it.
#
# For the handful of lines whose whole job is to be seen WHILE a long run is in
# progress.  A schematic, a design or a project is checked with mQuiet raised for
# the length of the loop - that is what stops forty pages of dump reaching the
# Command Window - and a progress line put through Out would be swallowed by the
# very thing it is there to report on.
#
# Deliberately rare.  Anything that can wait until the run is over belongs in the
# report, and the report is printed after mQuiet has been put back.
proc ::mUtilMenu::OutAlways { args } {
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
#
# MOVING THE FOLDER EMPTIES THE TWO DESIGN FIELDS.  A path under the old folder is
# not a sensible starting point for work in a new one - it is nearly always the
# previous comparison left over - and leaving it there is how the wrong pair gets
# compared: the user changes folder, fills in one field, and Executes against a
# design from the job before.  Clearing both says plainly that the pair has to be
# chosen again.
#
# Only when the folder ACTUALLY MOVES.  Cancelling the directory dialog changes
# nothing, and neither does picking the folder that was already set - both leave
# the fields alone.  RememberInitDir is what decides that (it normalises the path
# and returns early when it matches), so the test here is what mCmpInitDir held
# before against what it holds after, rather than a string compare of its own that
# could disagree with it over a trailing slash.
proc ::mUtilMenu::BrowseInitDir { } {
    variable mCmpWin
    variable mCmpInitDir
    variable mCmpFileA
    variable mCmpFileB

    set lOpts [list -parent $mCmpWin -title "Select Default Folder" -mustexist 1]
    if { [file isdirectory $mCmpInitDir] } {
        lappend lOpts -initialdir $mCmpInitDir
    }

    set lDir [eval tk_chooseDirectory $lOpts]
    if { $lDir eq "" } {
        return 0
    }

    set lOld $mCmpInitDir
    ::mUtilMenu::RememberInitDir $lDir
    if { $mCmpInitDir eq $lOld } {
        return 0
    }

    set mCmpFileA ""
    set mCmpFileB ""
    ::mUtilMenu::Trace "Default Folder moved to $mCmpInitDir - both design fields cleared"
    return 1
}

# Browse for one .DSN and drop it into the given namespace variable.
#
# ALWAYS STARTS AT mCmpInitDir - the Default Folder on the dialog's first row,
# whatever BrowseInitDir last put there.  One anchor, set in one place, and the
# user navigates away from it inside the file dialog if the design is somewhere
# else.
#
# It used to start at the folder of whatever was already in the field and fall
# back to mCmpInitDir, and picking a design used to move the Default Folder to
# wherever that design came from.  Both are gone, and they went together: a Browse
# that silently rewrote the anchor meant choosing (O) in one folder moved where
# (N) would start looking, and once the anchor is the user's to set there is no
# reason to second-guess it from a field's contents either.  The Default Folder is
# set in one place, on its own row, with its own button.
#
# Which is also why this does NOT clear anything.  Filling in one design field is
# not a statement about the other; moving the Default Folder is, and that is where
# the clearing lives - see BrowseInitDir.
proc ::mUtilMenu::BrowseDesign { pVarName } {
    variable mCmpWin
    variable mCmpInitDir

    set lOpts [list \
        -parent $mCmpWin \
        -title "Select Design File" \
        -defaultextension ".dsn" \
        -filetypes { {"OrCAD Design Files" {.dsn}} {"All Files" *} }]
    if { [file isdirectory $mCmpInitDir] } {
        lappend lOpts -initialdir $mCmpInitDir
    }

    set lFile [eval tk_getOpenFile $lOpts]

    if { $lFile ne "" } {
        set ::mUtilMenu::$pVarName [file nativename $lFile]
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
        error "design not found in session: [file tail $pDsnPath]"
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
#
# The page net -> schematic net step behind SchNetName is checked the same way,
# and note that the first of the three takes NO status argument where nearly
# every other getter in this file does:
#
#   DboNet_GetSchematicNet       self            the DboSchematicNet, or NULL
#   DboSchematicNet_GetName      self name       name is a CString&
#   DboSchematicNet_GetLocalNetName self name    the name before Capture made it
#                                                unique - not used, but it is the
#                                                other half of the pair and worth
#                                                knowing is there
#
# capDRCFramework/tcl/capProcessDRC.tcl:255-258 walks that link the other way
# round (net occurrence -> DboSchematicNet -> NewNetsIter -> the page DboNets),
# which is the same edge and confirms the two objects are related as assumed.
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
#
# Granularity is doc units per USER unit, not per inch - GetDocUnitsPerInch is the
# per-inch one - so on a metric page this returns millimetres.  CoordUnitLabel is
# what names the result.
#
# Every printed coordinate in this file comes through here - part locations and
# bounding boxes, pin connection points, symbol positions, net and bus wire
# endpoints, and the gaps Search_Missing_connection_onGrid measures between them -
# so mCoordDecimals is the one place the printed precision is decided and the
# columns cannot drift apart from one another.
proc ::mUtilMenu::Coord { pPage pDoc } {
    variable mCoordMode
    variable mCoordDecimals

    if { $mCoordMode eq "doc" } {
        return $pDoc
    }
    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        return $pDoc
    }
    return [format "%.${mCoordDecimals}f" [expr { double($pDoc) / $lGran }]]
}

# What Coord is really going to hand back for this page, as the word a column
# heading can be labelled with:
#
#   mm    the page is metric - DboPage::GetIsMetric says 1, so its user unit is
#         the millimetre and that is what dividing by the granularity produced
#   in    an inch page
#   doc   the doc integers came through unconverted - either because mCoordMode
#         asked for raw units, or because the page would not give a granularity
#         and Coord fell back to the doc value
#
# It repeats Coord's two tests rather than trusting mCoordMode on its own, so a
# heading can never claim a unit over a column Coord left in doc units.  A page
# that will not answer GetIsMetric is called inches, which is Capture's default
# (DboLib::GetDefaultIsMetric is the design-wide version of the same flag).
proc ::mUtilMenu::CoordUnitLabel { pPage } {
    variable mCoordMode

    if { $mCoordMode eq "doc" || $pPage eq "" } {
        return "doc"
    }
    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        return "doc"
    }
    set lMetric 0
    catch { set lMetric [$pPage GetIsMetric] }
    if { $lMetric } {
        return "mm"
    }
    return "in"
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

# The placement origin as raw doc integers, {x y}, or {} when it cannot be read -
# the same GetLocation ObjLocStr prints, before Coord rounded it for printing.
# For an off-page connector, a power symbol or a port that origin IS the point a
# wire has to land on, which is what Search_Missing_connection_onGrid measures
# from.
proc ::mUtilMenu::ObjLocDoc { pObj pStatus } {
    set lOut [list]
    catch {
        set lPt  [$pObj GetLocation $pStatus]
        set lOut [list [DboTclHelper_sGetCPointX $lPt] [DboTclHelper_sGetCPointY $lPt]]
    }
    return $lOut
}

# The same bounding box as raw doc integers, {left top right bottom}, or {} when
# it cannot be read.  What ObjLocStr prints has been through Coord and rounded -
# fine to read, useless to draw from - so the marker rectangles are
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

# Manhattan distance from a {x y} doc point to a {left top right bottom} doc box,
# 0 when the point is inside it or on its edge.
#
# min/max rather than trusting the corner order: CRect's top is the SMALLER y on a
# page (y grows downward) and that is what ObjBBoxDoc hands back, but a rectangle
# that came out the other way round would silently make every test fail.
proc ::mUtilMenu::PtBoxDistDoc { pPt pBox } {
    if { [llength $pPt] != 2 || [llength $pBox] != 4 } {
        return -1
    }

    set lX1 [expr { min([lindex $pBox 0], [lindex $pBox 2]) }]
    set lX2 [expr { max([lindex $pBox 0], [lindex $pBox 2]) }]
    set lY1 [expr { min([lindex $pBox 1], [lindex $pBox 3]) }]
    set lY2 [expr { max([lindex $pBox 1], [lindex $pBox 3]) }]

    set lX [lindex $pPt 0]
    set lY [lindex $pPt 1]

    set lDx 0
    if { $lX < $lX1 } { set lDx [expr { $lX1 - $lX }] }
    if { $lX > $lX2 } { set lDx [expr { $lX - $lX2 }] }
    set lDy 0
    if { $lY < $lY1 } { set lDy [expr { $lY1 - $lY }] }
    if { $lY > $lY2 } { set lDy [expr { $lY - $lY2 }] }

    return [expr { $lDx + $lDy }]
}

#-----------------------------------------------------------------------------
# Where an off-page connector / power symbol / port actually CONNECTS
#
# GetLocation is the wrong point and always was.  It comes from
# DboGraphicInstance (?GetLocation@DboGraphicInstance@@) and it is the PLACEMENT
# ORIGIN - Cadence's own graphics streamer takes it as exactly that
# (orPrmDboStreamer.tcl:1755 uses it as lInstOrigin, with the rotation, mirror and
# master bbox applied separately).  For a left-pointing off-page connector it
# lands on the top-left corner of the bounding box:
#
#   OFFPAGE  SMB_CLK_SIO   (19.95,12.40) bbox (19.95,12.40)-(21.78,12.60)
#                           ^^^^^^^^^^^^ the corner, not the pin
#
# The wire lands half a symbol height lower, at (19.95,12.50).  Every distance
# Search_Missing_connection_onGrid measured against a symbol was therefore out by
# that much, which at min_dis = half a grid step is enough to turn a real near
# miss into "nothing found".
#
# DboNetSymbolInstance - the class off-page connectors, power symbols and ports
# all are - carries the right pair, the same naming part pins use (see
# PinHotSpotDoc for that half):
#
#   DboNetSymbolInstance_GetHotSpot            self status
#   DboNetSymbolInstance_GetOffsetHotSpot      self status
#   DboNetSymbolInstance_ComputeOffsetHotSpot  self status
#
# checked against the SWIG wrappers in tools/bin/orDb_Dll_Tcl64.dll, and against
# ?GetHotSpot@DboNetSymbolInstance@@QEAA?AVCPoint@@AEAVDboState@@@Z for the return
# type.  NO shipped script calls either of them on a net symbol instance, so which
# of the two is a page coordinate and which is an offset from the placement origin
# is NOT established by anything - and the file's own convention is no guide,
# because on DboPortInst it is the Offset* one that is page-level.
#
# So this does not guess.  It builds every candidate the getters can produce, each
# read both ways - as a page coordinate, and as an offset to be added to
# GetLocation - and then asks the geometry which one is real.
#
# WHAT THE FIRST VERSION OF THIS GOT WRONG, because it is the whole point of the
# code below.  It took "the candidate landed inside the bounding box" as proof and
# returned on the first one that did.  Both halves of that were wrong:
#
#   A rotated GND symbol.  loc (2.24,4.00), bbox (2.03,4.00)-(2.34,4.20), pin
#   pointing right, so the wire lands at (2.34,4.10) - the middle of the right
#   edge.  GetHotSpot returned (0.10,0.00), which is the top-middle of the symbol
#   as DRAWN IN THE LIBRARY, 0.20 wide and unrotated: the instance's rotation is
#   NOT in that number.  Added to loc it gives (2.34,4.00) - the top-right CORNER
#   of the bbox.  Distance to the bbox: zero.  Accepted, and the loop stopped
#   there, so GetOffsetHotSpot and ComputeOffsetHotSpot were never even tried.
#
#   The error is half a symbol, and it made Schematic Check report net endpoints
#   as "0.02 from GND" on wiring that is perfectly correct.
#
# Two fixes, and the second is the one that matters:
#
#   score every candidate, then choose.  First-past-the-post over an ordered list
#   is choosing by the order they happen to be written in.
#
#   SNAP to the nearest edge MIDPOINT of the bounding box.  An off-page connector,
#   a power/ground symbol and a port all have exactly one pin and it is centred on
#   one edge - never on a corner.  So the four edge midpoints are the only places
#   the answer can be, and the getter's job is reduced from "give me the exact
#   point" to "tell me which edge", which is a question it can still answer
#   correctly with its rotation missing: (2.34,4.00) is 0.10 from the right-edge
#   midpoint and 0.155 from the top-edge one, so it snaps to the right edge and
#   comes out at (2.34,4.10).
#
# Snapping also means this never had to work out Capture's rotation convention -
# which of rotation 0/1/2/3 is clockwise, and what mirror does to it - and so
# cannot get it wrong.  DboGraphicInstance::GetRotation / GetMirror are there
# (they are what orPrmDboStreamer.tcl:1769 feeds to getOffsetFromTransform) if a
# symbol ever turns up that needs the real transform.
#
# Tiers, best first:
#
#   1  wire      the symbol is attached to a wire - DboNetSymbolInstance::GetWire
#                - and a wire END is where the pin is, exactly, with no geometry
#                assumed at all.  Ground truth, and free.
#   2  snapped   the best getter candidate, snapped to the nearest edge midpoint.
#   3  raw       the best getter candidate as it stands (mSymHotSpotSnap 0, or a
#                symbol with no bounding box to snap against).
#   4  location  nothing usable - the old behaviour, and a Trace line saying so.
#
# Returns {x y route}.  route names the tier and the reading that won, so the dump
# says what it did instead of leaving it to be inferred.
#-----------------------------------------------------------------------------

# The four points a single centred pin can sit on.  Returned in the order
# left, right, top, bottom - only ever consumed as a set, so the order is for
# reading the code, not for choosing.
proc ::mUtilMenu::BoxEdgeMidsDoc { pBox } {
    if { [llength $pBox] != 4 } {
        return [list]
    }
    set lX1 [expr { min([lindex $pBox 0], [lindex $pBox 2]) }]
    set lX2 [expr { max([lindex $pBox 0], [lindex $pBox 2]) }]
    set lY1 [expr { min([lindex $pBox 1], [lindex $pBox 3]) }]
    set lY2 [expr { max([lindex $pBox 1], [lindex $pBox 3]) }]

    set lMx [expr { round(($lX1 + $lX2) / 2.0) }]
    set lMy [expr { round(($lY1 + $lY2) / 2.0) }]

    return [list [list $lX1 $lMy] [list $lX2 $lMy] \
                 [list $lMx $lY1] [list $lMx $lY2]]
}

# Manhattan distance between two {x y} doc points, -1 if either is not a point.
proc ::mUtilMenu::PtDistDoc { pA pB } {
    if { [llength $pA] != 2 || [llength $pB] != 2 } {
        return -1
    }
    return [expr { abs([lindex $pA 0] - [lindex $pB 0])
                 + abs([lindex $pA 1] - [lindex $pB 1]) }]
}

proc ::mUtilMenu::SymHotSpotDoc { pObj pStatus } {
    variable mSymHotSpotSnap

    set lLoc  [::mUtilMenu::ObjLocDoc  $pObj $pStatus]
    set lBBox [::mUtilMenu::ObjBBoxDoc $pObj]

    # Tier 1 - the wire it is attached to.  Whichever end of it is nearer the
    # symbol is the end that is ON the symbol, and that is the pin.  Guarded by
    # the bbox so a wire that is somehow miles away cannot hijack the answer.
    if { [llength $lBBox] == 4 } {
        set lWire NULL
        catch { set lWire [$pObj GetWire $pStatus] }
        if { $lWire ne "NULL" && $lWire ne "" } {
            set lSeg [::mUtilMenu::WireSegDoc $lWire $pStatus]
            if { [llength $lSeg] == 4 } {
                set lBest ""
                set lBestD -1
                foreach lEnd [list [lrange $lSeg 0 1] [lrange $lSeg 2 3]] {
                    set lD [::mUtilMenu::PtBoxDistDoc $lEnd $lBBox]
                    if { $lD >= 0 && ($lBestD < 0 || $lD < $lBestD) } {
                        set lBestD $lD
                        set lBest  $lEnd
                    }
                }
                if { $lBest ne "" && $lBestD == 0 } {
                    return [list [lindex $lBest 0] [lindex $lBest 1] "wire"]
                }
            }
        }
    }

    # Every reading of every getter.  ComputeOffsetHotSpot is in the list because
    # the name says it recomputes rather than reads back, and it may well be the
    # one that already has the transform in it - the scoring below will say so.
    set lCand [list]
    foreach lGetter { GetHotSpot GetOffsetHotSpot ComputeOffsetHotSpot } {
        set lPt [list]
        catch {
            set lC  [$pObj $lGetter $pStatus]
            set lPt [list [DboTclHelper_sGetCPointX $lC] [DboTclHelper_sGetCPointY $lC]]
        }
        if { [llength $lPt] != 2 } {
            continue
        }
        lappend lCand [list $lGetter $lPt]
        if { [llength $lLoc] == 2 } {
            lappend lCand [list "$lGetter+loc" \
                [list [expr { [lindex $lLoc 0] + [lindex $lPt 0] }] \
                      [expr { [lindex $lLoc 1] + [lindex $lPt 1] }]]]
        }
    }

    if { [llength $lBBox] == 4 } {
        # Score them ALL, then choose - no returning from inside the loop.
        set lSpan [expr { abs([lindex $lBBox 2] - [lindex $lBBox 0])
                        + abs([lindex $lBBox 3] - [lindex $lBBox 1]) }]
        set lBest  ""
        set lBestD -1
        foreach lC $lCand {
            set lD [::mUtilMenu::PtBoxDistDoc [lindex $lC 1] $lBBox]
            if { $lD < 0 } {
                continue
            }
            if { $lBestD < 0 || $lD < $lBestD } {
                set lBestD $lD
                set lBest  $lC
            }
        }

        # Within the symbol's own size of it, or it is not this symbol's pin.
        if { $lBest ne "" && $lBestD <= $lSpan } {
            set lPt [lindex $lBest 1]

            if { $mSymHotSpotSnap } {
                set lMid   ""
                set lMidD  -1
                foreach lM [::mUtilMenu::BoxEdgeMidsDoc $lBBox] {
                    set lD [::mUtilMenu::PtDistDoc $lPt $lM]
                    if { $lD >= 0 && ($lMidD < 0 || $lD < $lMidD) } {
                        set lMidD $lD
                        set lMid  $lM
                    }
                }
                if { $lMid ne "" } {
                    set lTag "[lindex $lBest 0]->edge"
                    if { $lMidD == 0 } {
                        # It was already on the midpoint - the getter had the
                        # rotation in it, and the snap changed nothing.
                        set lTag [lindex $lBest 0]
                    }
                    return [list [lindex $lMid 0] [lindex $lMid 1] $lTag]
                }
            }

            return [list [lindex $lPt 0] [lindex $lPt 1] "[lindex $lBest 0]~"]
        }
    }

    # Nothing usable.  Not an error - a symbol with no bounding box to check
    # against ends up here too - but it IS the case where the old
    # off-by-half-a-symbol behaviour comes back, so it says so.
    ::mUtilMenu::Trace "no usable hot spot on this symbol ([llength $lCand] candidate(s), bbox {$lBBox}) - falling back to GetLocation"
    if { [llength $lLoc] == 2 } {
        return [list [lindex $lLoc 0] [lindex $lLoc 1] "location"]
    }
    return [list]
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
# cannot be read.  WireSegStr's output has been through Coord and is rounded,
# which is fine to read and useless to draw from - the marker lines
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
    variable mNetSkipBuses

    set lNullObj NULL
    set lNames   [list]

    catch {
        set lIter [$pNet NewWiresIter $pStatus]
        set lWire [$lIter NextWire $pStatus]
        while { $lWire != $lNullObj } {
            # Bus wires skipped for the same reason CollectPageNets skips them,
            # and it has to be the same rule in both places: this proc promises
            # the answer element 0 of a net row would give, and a pin reporting
            # "V_M_BMC_DDR4_DQ0 = D[0..7]" against a Nets section that says
            # "V_M_BMC_DDR4_DQ0" is the two having drifted apart.  See IsBusWire.
            if { $mNetSkipBuses && [::mUtilMenu::IsBusWire $lWire] } {
                set lWire [$lIter NextWire $pStatus]
                continue
            }
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

# What the WHOLE SCHEMATIC calls this page net, or "" if it will not say.
#
# A page DboNet and the schematic net it belongs to are two different objects and
# they do not have to agree on a name.  Two pages can each carry a piece of wire
# labelled +3.3VSB with nothing joining them - no Off-Page Connector, no Power
# symbol, no Port - and Capture will not silently weld them into one net just
# because the labels match.  It keeps them apart and makes the names unique, so
# one of them stays +3.3VSB and the other becomes something like +3.3VSB_9631.
#
# The page label is what is drawn on the page; this is what the netlist, the DRC
# and PCB Editor will actually see.  When they differ, the difference IS the
# finding - it is exactly the fault SCH_CHECK_ITEM2 is meant to look for - so the
# Nets dump prints both rather than picking one.  See PrintNetRows.
#
# GetSchematicNet takes no status argument (see the block above) and returns NULL
# for a net that has not been given a schematic net, which is not an error: an
# unnamed scrap of wire is entitled to no answer, and "" is that answer.
#
# DboSchematicNet has a GetName and a GetLocalNetName and this takes GetName,
# which is the resolved one - the one carrying the _9631 that
# DboSchematicNet::ResolveComputedNameConflict put there.  If a real design ever
# shows the two the other way round, SchNetNames prints both side by side for
# every net on a page and settles it in one line.
proc ::mUtilMenu::SchNetName { pNet } {
    set lSchNet NULL
    if { [catch { set lSchNet [$pNet GetSchematicNet] }] } {
        return ""
    }
    if { $lSchNet eq "NULL" || $lSchNet eq "" } {
        return ""
    }
    return [::mUtilMenu::CStr $lSchNet GetName]
}

# Diagnostic: every net on one page with BOTH schematic-net names beside the page
# label, plus whether the schematic net is global and whether it is shared with
# another page.  Run in the Command Window against a page that is known to have a
# duplicated net name on it, e.g.
#   ::mUtilMenu::SchNetNames {G:/Project/.../board.dsn} SCHEMATIC1 PAGE1
#
# This is what says which of GetName / GetLocalNetName carries the _9631 suffix,
# and it is here rather than in the dump because the dump only needs one of them.
proc ::mUtilMenu::SchNetNames { pDsnPath pSchName pPageName } {
    set lPage   [::mUtilMenu::FindPage $pDsnPath $pSchName $pPageName]
    set lStatus [DboState]

    ::mUtilMenu::Out [format "    %-28s %-28s %-28s %-6s %s" \
                          "page label" "GetName" "GetLocalNetName" "global" "shared"]

    set lIter [::mUtilMenu::NextIterName SchNetNames]
    DboPageNetsIter $lIter $lPage $::IterDefs_ALL
    set lNet [$lIter NextNet $lStatus]
    set lN   0

    while { $lNet != "NULL" } {
        incr lN

        set lSchNet NULL
        catch { set lSchNet [$lNet GetSchematicNet] }

        set lName   "-"
        set lLocal  "-"
        set lGlobal "-"
        set lShared "-"
        if { $lSchNet ne "NULL" && $lSchNet ne "" } {
            set lName  [::mUtilMenu::OrDash [::mUtilMenu::CStr $lSchNet GetName]]
            set lLocal [::mUtilMenu::OrDash [::mUtilMenu::CStr $lSchNet GetLocalNetName]]
            catch { set lGlobal [$lSchNet IsGlobal $lStatus] }
            catch { set lShared [$lSchNet IsSchematicNetSharedWithOtherPages $lPage] }
        }

        ::mUtilMenu::Out [format "    %-28s %-28s %-28s %-6s %s" \
                              [::mUtilMenu::NetLabelOf $lNet $lStatus] \
                              $lName $lLocal $lGlobal $lShared]

        set lNet [$lIter NextNet $lStatus]
    }

    ::mUtilMenu::DropIter $lIter
    catch { $lStatus -delete }
    ::mUtilMenu::Out "  ($lN net(s))"
    return $lN
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
    variable mPinPosAll
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

    # A pin on no net is in no netlist, so its position can never be used by a
    # compare - the $lNet test is not an optimisation for its own sake, it is the
    # same "nothing will look at this" rule pWantPos carries.
    #
    # mPinPosAll lifts it, which is what makes an NC or unwired pin print its
    # coordinates instead of a "-" under Schematic Check.  See the variable.
    set lPos [list]
    if { $pWantPos && ( $lNet ne "" || $mPinPosAll ) } {
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

# The position half of one CollectPinInfo record, as the dump prints it, or "-"
# when the record carries no position (see PrintPartRows for the three reasons).
#
# Element 4 is raw doc integers and stays that way - net_compare_rule4 matches it
# against wire endpoints, which are raw too - so the conversion happens HERE, at
# the printout, and only there.  It goes through the same Coord the Parts
# location, the Symbols, the Nets and the Buses columns go through, which is what
# makes a pin at (680,750) doc print as (6.80,7.50) next to a net wire that ends
# at (6.80,7.50) instead of a hundred times away from it.
#
# The divisor is the page's own GetPhysicalGranularity - 100 doc units per inch
# on a normal page, which is where "divide by 100" comes from, but it is read
# from the page rather than assumed, and CheckOnePage prints it in the grid block.
# pPage "" leaves the doc integers alone, so a caller with no page in hand still
# gets a number rather than an error.
proc ::mUtilMenu::PinPosStr { pPage pPin } {
    set lPos [lindex $pPin 4]
    if { [llength $lPos] != 2 } {
        return "-"
    }
    if { $pPage eq "" } {
        return "([lindex $lPos 0],[lindex $lPos 1])"
    }
    return "([::mUtilMenu::Coord $pPage [lindex $lPos 0]],[::mUtilMenu::Coord $pPage [lindex $lPos 1]])"
}

# What a netlist calls one pin - the "A35" half of "U1.A35".
#
# The physical pin NUMBER, because that is what a netlist is keyed on, falling
# back to the pin NAME for a part that has no numbers so the entry still says
# which pin it was rather than ending in a bare dot.  OrDash keeps a pin with
# neither from collapsing to the empty string, which would make every such pin
# on a part look like the same pin.
#
# One proc and not the same three lines in each caller: CollectNetlist builds
# "$lRef.$lNum" out of it and net_compare_rule5 matches (O) pins against (N)
# pins with it, and if the two ever disagreed about what a pin is called then
# rule5 would silently stop finding the pins rule4 reports.
proc ::mUtilMenu::PinKey { pPin } {
    set lNum [lindex $pPin 1]
    if { $lNum eq "" } {
        set lNum [::mUtilMenu::OrDash [lindex $pPin 0]]
    }
    return $lNum
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
    variable mPinPosAll
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
            # mPinPosAll wants every pin's position, so the filter is not
            # consulted at all - and PartPinCount is not even called, since its
            # only purpose is to answer a question already decided.
            set lWantPos 1
            if { !$mPinPosAll } {
                set lFastCnt [::mUtilMenu::PartPinCount $lPart]
                if { $lFastCnt >= 0 && $lFastCnt <= $mRule4MinPins } {
                    set lWantPos 0
                }
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
        # The label has to follow mPinPosAll: with the filter off these are not
        # rule4's numbers any more, they are every pin on the page.
        if { $mPinPosAll } {
            ::mUtilMenu::Out [format \
                "              part pin count       %6d ms over %5d call(s)  (filter off)" \
                $lCntM $mStatCntCalls]
            ::mUtilMenu::Out [format \
                "              all pin positions    %6d ms over %5d call(s), %d pin(s) skipped" \
                $lPosM $mStatPosCalls [expr { $lPinTotal - $mStatPosCalls }]]
        } else {
            ::mUtilMenu::Out [format \
                "              rule4 part pin count %6d ms over %5d call(s)" \
                $lCntM $mStatCntCalls]
            ::mUtilMenu::Out [format \
                "              rule4 pin position   %6d ms over %5d call(s), %d pin(s) skipped" \
                $lPosM $mStatPosCalls [expr { $lPinTotal - $mStatPosCalls }]]
        }
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
# The connection point is printed in the SAME units as every other coordinate in
# the dump - it goes through Coord, like the part's own location, the symbols, the
# nets and the buses - and the column heading says which units those are:
#
#   (in)   mCoordMode "user", the default: doc integers divided by the page's
#          physical granularity, mCoordDecimals places.  A pin the database holds
#          at (680,750) prints as (6.800,7.500), which is the same point the Nets
#          section prints for the wire that lands on it.
#   (doc)  mCoordMode "doc", or a page that would not give a granularity: raw
#          internal integers, which is what net_compare_rule4 matches against a
#          wire endpoint.  Set mCoordMode to "doc" to read the dump in rule4's
#          units.
#
# Only the PRINTOUT converts.  Element 4 of the pin record stays raw doc, so the
# netlist compare and the markers it draws are untouched either way - see
# PinPosStr.
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
#
# pPage is the page the rows came off, and is only used to convert those pin
# positions; "" prints them raw.  It comes first so the proc name and the page
# can be handed to DumpPageInfoOn's section table as one command prefix.
proc ::mUtilMenu::PrintPartRows { pPage pRows } {
    variable mPinDetail

    set lUnits "([::mUtilMenu::CoordUnitLabel $pPage])"

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
            # The position column is 20 wide rather than the old 17, so that it
            # still holds the widest thing it can be asked to print: four digits
            # of inches either side of the comma, or mCoordDecimals raised to 3 on
            # a granularity-1000 page.
            ::mUtilMenu::Out [format "               pins (%d):   Pin Number  Pin Name             Pin Pos %-13s Connection" \
                      [llength $lInfo] $lUnits]
            foreach lPin [lsort -dictionary -index 1 $lInfo] {
                ::mUtilMenu::Out [format "                           %-11s %-20s %-20s %s" \
                          [::mUtilMenu::OrDash [lindex $lPin 1]] \
                          [::mUtilMenu::OrDash [lindex $lPin 0]] \
                          [::mUtilMenu::PinPosStr $pPage $lPin] \
                          [::mUtilMenu::PinConnStr $lPin]]
            }
        } elseif { [llength $lPins] > 0 } {
            ::mUtilMenu::Out "               pins: [join $lPins { }]"
        }
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageParts { pPage } {
    return [::mUtilMenu::PrintPartRows $pPage [::mUtilMenu::CollectPageParts $pPage]]
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

# One page's netlist, as records of {netName global pins pinDetail symDetail}.
#
# Element 4 is the Off-Page / Power / Port symbols sitting on the net, each with
# the doc-unit point a wire has to land on:
#
#     {{OFFPAGE:DDI2_TXP3 1200 800} {GLOBAL:GND 2400 900} ...}
#      type:name          x    y
#
# A symbol is on the net when its NAME or its CONNECTION is the net's name, which
# is the same test GlobalNetIndex makes for element 1 - so the bit that says "this
# net leaves the page" and the list that says "by which symbol" can never
# disagree about what is on it.  The identity is type AND name, because an
# off-page connector called GND and a power symbol called GND are two different
# things to connect to.
#
# ON THE END, and not folded into element 2, on purpose.  Element 2 is
# "Part_Reference.Pin" and nothing else - net_compare_rule1 fires on it being
# EMPTY, DumpNetlists prints it, and both would change meaning if symbols joined
# it.  net_compare_rule4 is the only reader; it wants every physical thing the net
# is attached to, which is elements 3 and 4 together.
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

    array set lSym {}
    ::mUtilMenu::SymEndpointIndex lSym [dict get $pDict symbols]

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
            # fall back to the pin name - see PinKey, which net_compare_rule5
            # matches its pins with as well.
            set lNum [::mUtilMenu::PinKey $lPin]
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
        set lThisSym [list]
        if { [info exists lSym($lNet)] } {
            set lThisSym [lsort -dictionary -index 0 $lSym($lNet)]
        }
        lappend lOut [list $lNet $lFlag [lsort -dictionary $lPins($lNet)] \
                           $lThisPos $lThisSym]
    }
    return $lOut
}

# net name -> the Off-Page / Power / Port symbols on it, as {type:name x y}.
#
# Same two row elements GlobalNetIndex looks at - 1 (the symbol's own name) and 3
# (the net it reports being attached to) - so a symbol reaches the net under
# either, and the two procs cannot disagree about what sits on a net.  A symbol
# whose name and connection are both the net's name is filed once, not twice.
#
# Element 4 is the symbol's GetLocation as raw doc integers, which for all three
# kinds IS the point a wire has to land on.  A symbol that would not give one is
# filed with an empty position rather than dropped: it is still an endpoint that
# can differ between the two designs, and net_compare_rule4 reports it as
# unmarkable instead of losing it.
proc ::mUtilMenu::SymEndpointIndex { pArrName pSymRows } {
    upvar 1 $pArrName lArr

    foreach lRow $pSymRows {
        set lId "[lindex $lRow 0]:[lindex $lRow 1]"
        set lPt [lindex $lRow 4]
        set lX  [lindex $lPt 0]
        set lY  [lindex $lPt 1]

        set lSeen [list]
        foreach lIdx { 1 3 } {
            set lNet [lindex $lRow $lIdx]
            if { $lNet eq "" || [lsearch -exact $lSeen $lNet] != -1 } {
                continue
            }
            lappend lSeen $lNet
            lappend lArr($lNet) [list $lId $lX $lY]
        }
    }
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
#   net_compare_rule4  both have the net with the same global/local bit, but it is
#                      not attached to the same PHYSICAL ENDPOINTS.
#
#                      An endpoint is either a part pin, identified as
#                      "<Part Reference>.<Pin>" ("U1D.E43"), or an Off-Page /
#                      Power / Port symbol, identified as "<TYPE>:<name>"
#                      ("OFFPAGE:DDI2_TXP3").  The symbols are endpoints in their
#                      own right and not just the global/local bit rule3 tests:
#                      that bit only says whether the net has ANY such symbol, so
#                      a net that swapped one off-page connector for another keeps
#                      the bit and is a different net all the same.
#
#                      COMPARED BY IDENTITY, NEVER BY POSITION.  The same pin
#                      wired at a different coordinate is the same connection and
#                      rule4 says nothing about it - a moved wire is the Nets
#                      section's business.  Endpoints are diffed as a multiset, so
#                      the same id twice is not one id.
#
#                      WHAT GETS DRAWN.  Every wire of (N)'s net whose own two END
#                      coordinates include the position of an endpoint that (N)
#                      has and (O) does not.  A wire with no endpoint at either
#                      end, or with endpoints both designs share, is left alone -
#                      so a net that grew one new connection gets a line on the
#                      wire that arrives there and not over the whole net.
#
#                      THE mRule4MarkMinPins (1) FILTER applies to part pins only.
#                      A changed pin on a part of that many pins or fewer is listed
#                      as skipped in the Command Window and gets no line and no
#                      entry in the report.  A symbol has no pin count and is never
#                      filtered: an off-page connector coming or going is not that
#                      kind of noise.
#                      At 1 the filter is effectively off, and deliberately so - at
#                      5 it swallowed a whole M.2 page's worth of real re-wiring
#                      done by swapping AC-coupling capacitors between nets.  It is
#                      NOT mRule4MinPins, which stays at 5 and only decides how
#                      many pin positions the parts walk bothers to read; see both
#                      variables, and NeedAllPinPos for what keeps them consistent.
#                      The count is the part's own, out of the netlist record, not
#                      worked out from the pin's name.
#                      An endpoint (O) had and (N) has not is reported and NOT
#                      marked - there is nothing on (N)'s page to put a line at -
#                      and is held to the same pin count out of (O)'s side, so a
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

# Every PHYSICAL ENDPOINT of one net, out of one netlist record: the part pins of
# element 3 and the Off-Page / Power / Port symbols of element 4, in one list of
#
#     {id x y pinCount}
#
#   id         "U1D.E43" for a pin, "OFFPAGE:DDI2_TXP3" for a symbol.  This is
#              what net_compare_rule4 compares - the thing the net is attached to,
#              NOT where it is attached.  Two designs that wire the same pin at
#              two different coordinates are the same connection and rule4 says
#              nothing; the Nets section is where a moved wire shows up.
#   x y        doc units, "" when the position could not be read
#   pinCount   pins on the part behind it, for the mRule4MinPins filter.  EMPTY
#              for a symbol, which is not a part and has no count to be filtered
#              on - an off-page connector appearing or disappearing is never
#              noise, however few pins the things around it have.
#
# Sorted, so the two sides are compared in the same order whatever order the
# database handed the objects over in.
proc ::mUtilMenu::NetEndpoints { pRec } {
    set lOut [list]
    foreach lEntry [lindex $pRec 3] {
        lappend lOut [list [lindex $lEntry 0] [lindex $lEntry 1] \
                           [lindex $lEntry 2] [lindex $lEntry 3]]
    }
    foreach lEntry [lindex $pRec 4] {
        lappend lOut [list [lindex $lEntry 0] [lindex $lEntry 1] \
                           [lindex $lEntry 2] ""]
    }
    return [lsort -dictionary -index 0 $lOut]
}

# Does the (N) side of a compare have to be dumped with EVERY pin's position -
# mPinPosAll - rather than only the pins the parts walk would read on its own?
#
# Two reasons, and either is enough:
#
#   rule5   marks pins that are on NO net, and those are exactly the pins the
#           walk leaves without a position whatever the thresholds say.
#   rule4   marks changed pins on parts of more than mRule4MarkMinPins pins, while
#           the walk only reads positions for parts of more than mRule4MinPins.
#           Set the filter lower than the cost knob - which is the point of having
#           two - and the pins in between are ones rule4 wants to mark and the
#           walk would not have located.  Without this they would come back as
#           "no position for it, not marked", which looks like a database problem
#           and is really just two numbers out of step.
#
# Asked per side and not once per run: (O) needs neither.  rule5 only reads
# whether (O)'s pin had a net, and rule4 only reads (O)'s pin COUNT - a number the
# part row carries whether or not any position was read - so raising it for (O)
# would double a pin walk for a column nothing looks at.
proc ::mUtilMenu::NeedAllPinPos { } {
    variable mRule5
    variable mRule4MinPins
    variable mRule4MarkMinPins

    if { $mRule5 } {
        return 1
    }
    if { $mRule4MarkMinPins < $mRule4MinPins } {
        return 1
    }
    return 0
}

# Is this endpoint id a part pin rather than an Off-Page / Power / Port symbol?
#
# Tested against the three type prefixes SymEndpointIndex builds ids with, and NOT
# by looking for a colon: a Part Reference is free to contain one, and "is there a
# colon in it" would then quietly exempt such a part from the mRule4MinPins
# filter.  Anything that is not one of the three known symbol kinds is a pin,
# which is the safe way round - a pin wrongly called a symbol would skip the
# filter and mark a resistor.
proc ::mUtilMenu::IsPartPinId { pId } {
    foreach lType { OFFPAGE GLOBAL PORT } {
        if { [string match "$lType:*" $pId] } {
            return 0
        }
    }
    return 1
}

# Just the ids, for the multiset difference.
proc ::mUtilMenu::NetEndpointIds { pRec } {
    set lOut [list]
    foreach lEnt [::mUtilMenu::NetEndpoints $pRec] {
        lappend lOut [lindex $lEnt 0]
    }
    return $lOut
}

# id -> {positions counts}, out of NetEndpoints: every doc-unit point filed under
# that id, and the pin counts seen with it.
#
# A list of points and not one point, because the same id can legitimately appear
# twice - two placed instances sharing a Part Reference - and both are worth
# marking.  The LARGEST count wins: the bigger part is the one worth marking, and
# taking the smaller would silence rule4 on a real IC because a stray 2-pin part
# happens to share its reference.
proc ::mUtilMenu::EndpointIndex { pPosName pCntName pRec } {
    upvar 1 $pPosName lPos
    upvar 1 $pCntName lCnt

    foreach lEnt [::mUtilMenu::NetEndpoints $pRec] {
        set lId [lindex $lEnt 0]
        set lX  [lindex $lEnt 1]
        set lY  [lindex $lEnt 2]
        set lC  [lindex $lEnt 3]

        if { $lX ne "" && $lY ne "" } {
            if { ![info exists lPos($lId)] } {
                set lPos($lId) [list]
            }
            if { [lsearch -exact $lPos($lId) [list $lX $lY]] == -1 } {
                lappend lPos($lId) [list $lX $lY]
            }
        }
        if { $lC ne "" } {
            if { ![info exists lCnt($lId)] || $lC > $lCnt($lId) } {
                set lCnt($lId) $lC
            }
        }
    }
}

# Which of a net's wires have one of pPoints at an END of them.
#
# pPoints is a list of {x y} doc-unit pairs - the places rule4 decided the two
# designs differ.  A quad is returned when EITHER of its two ends is one of them;
# a quad with neither is not returned at all, which is the rule's "a segment whose
# two ends carry no differing endpoint is not drawn".
#
# ENDS ONLY, and exact integer equality on the raw doc units.  The rule is stated
# over the wire's two endpoint coordinates, so a point lying part-way ALONG a
# horizontal or vertical run does not count, even though Capture allows a pin to
# be tapped there: a wire that merely passes a differing pin on its way somewhere
# else is not the wire that changed.  A mid-run tap therefore marks nothing and is
# reported as unmarkable, which is honest - there is no one segment it belongs to.
#
# The doc integers are compared and never the printed coordinates, which are
# rounded to mCoordDecimals and would make two distinct points look like one.
#
# Returned in input order, at most once each, so a segment with a differing
# endpoint at both ends is still one line.
proc ::mUtilMenu::SegsEndingAt { pSegs pPoints } {
    set lOut [list]
    foreach lSeg $pSegs {
        set lA [list [lindex $lSeg 0] [lindex $lSeg 1]]
        set lB [list [lindex $lSeg 2] [lindex $lSeg 3]]
        foreach lPt $pPoints {
            if { $lPt eq $lA || $lPt eq $lB } {
                lappend lOut $lSeg
                break
            }
        }
    }
    return $lOut
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
    variable mRule4MarkMinPins
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
        # Same name, same bit: are the two nets attached to the SAME PHYSICAL
        # THINGS?
        #
        # The endpoints are compared by IDENTITY and never by position - a part pin
        # is "U1D.E43", an off-page connector is "OFFPAGE:DDI2_TXP3" - so a net
        # rewired between two parts is a difference and a net whose wires merely
        # moved is not.  Off-page connectors, power symbols and ports count as
        # endpoints alongside the pins: a net that stopped leaving the page by one
        # of them is attached to something different even when every pin on it is
        # the same, and the global/local bit rule3 tests only says whether there is
        # ANY such symbol, not which.
        set lIdsN [::mUtilMenu::NetEndpointIds $lRec]
        set lIdsO [::mUtilMenu::NetEndpointIds $lRecO]
        set lAdd  [::mUtilMenu::PinMultisetDiff $lIdsO $lIdsN]
        set lDrop [::mUtilMenu::PinMultisetDiff $lIdsN $lIdsO]
        if { [llength $lAdd] == 0 && [llength $lDrop] == 0 } {
            continue
        }

        # Positions and pin counts, one index per side.  An added endpoint is on
        # (N); a dropped one is on (O) and may not be on (N) at all.
        array unset lPosN  ; array set lPosN  {}
        array unset lCntN  ; array set lCntN  {}
        array unset lPosO  ; array set lPosO  {}
        array unset lCntO  ; array set lCntO  {}
        ::mUtilMenu::EndpointIndex lPosN lCntN $lRec
        ::mUtilMenu::EndpointIndex lPosO lCntO $lRecO

        # WHICH POINTS ON (N) DIFFER.  Collected first and drawn afterwards,
        # because the rule is stated over the SEGMENTS, not over the endpoints: a
        # segment is drawn when one of its two ends carries a differing endpoint,
        # and a segment with a differing endpoint at each end is still one line.
        set lHotPts [list]
        set lHotIds [list]

        foreach lId $lAdd {
            set lCnt ""
            if { [info exists lCntN($lId)] } {
                set lCnt $lCntN($lId)
            }

            # The marking filter - mRule4MarkMinPins, NOT the mRule4MinPins cost
            # knob the parts walk uses.  Part pins only: a symbol carries no pin
            # count ("") and is never filtered, because an off-page connector
            # coming or going is not the kind of noise the filter exists for.  A
            # part pin whose count could not be read counts as -1 and is filtered,
            # as it always was.
            if { [::mUtilMenu::IsPartPinId $lId] } {
                if { $lCnt eq "" } {
                    set lCnt -1
                }
                if { $lCnt <= $mRule4MarkMinPins } {
                    lappend lSkipped \
                        "$lNet   $lId only on (N) - part has [::mUtilMenu::PinCountStr $lCnt], not more than $mRule4MarkMinPins"
                    continue
                }
            }

            if { ![info exists lPosN($lId)] } {
                lappend lFound [list 4 $lNet \
                    "$lId only on (N) - no position for it, not marked" [list] \
                    "$lNet ($lId, no position)"]
                continue
            }
            foreach lPt $lPosN($lId) {
                if { [lsearch -exact $lHotPts $lPt] == -1 } {
                    lappend lHotPts $lPt
                }
            }
            lappend lHotIds $lId
        }

        # Reported, never marked: the endpoint is on (O) and not on (N), so (N)'s
        # page has no point to put a line at.  Held to the same pin count, out of
        # (O)'s side - a rewired resistor must not be reported at one end and
        # skipped at the other.
        foreach lId $lDrop {
            if { [::mUtilMenu::IsPartPinId $lId] } {
                set lCnt -1
                if { [info exists lCntO($lId)] } {
                    set lCnt $lCntO($lId)
                }
                if { $lCnt <= $mRule4MarkMinPins } {
                    lappend lSkipped \
                        "$lNet   $lId only on (O) - part has [::mUtilMenu::PinCountStr $lCnt], not more than $mRule4MarkMinPins"
                    continue
                }
            }
            lappend lFound [list 4 $lNet \
                "$lId only on (O) - nothing on (N) to mark" [list] \
                "$lNet ($lId, only (O))"]
        }

        if { [llength $lHotIds] == 0 } {
            continue
        }

        # The segments themselves.  A net whose differing endpoints are all
        # mid-run taps, or which the Nets section never listed a wire for, has
        # nothing to draw - said once for the net rather than once per endpoint.
        set lHit [::mUtilMenu::SegsEndingAt $lSegs $lHotPts]
        if { [llength $lHit] == 0 } {
            lappend lFound [list 4 $lNet \
                "endpoints differ ([join $lHotIds {, }]) - no wire of the net ENDS at any of them, not marked" \
                [list] "$lNet ([join $lHotIds {, }], no wire there)"]
            continue
        }
        lappend lFound [list 4 $lNet \
            "endpoints differ ([join $lHotIds {, }]) - [llength $lHit] of [llength $lSegs] wire(s) end at one of them" \
            $lHit "$lNet ([join $lHotIds {, }])"]
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
    variable mRule4MarkMinPins

    set lRuleText [list \
        1 "net with no Part_Reference.Pin on it and local (0)" \
        2 "in (N)'s netlist, not in (O)'s" \
        3 "1 = global / 0 = local differs" \
        4 "same net, different physical endpoints (pins and Off-Page / Power / Ports) - marked on the wires that end at them"]

    ::mUtilMenu::Out "    Netlist compare - net_compare_rule1..4; every hit gets a pink DASH line on (N)"

    # First, so it is read as "these were left out" rather than as part of the
    # findings below it.
    if { [llength $pSkipped] > 0 } {
        ::mUtilMenu::Out "      net_compare_rule4 skipped - part has $mRule4MarkMinPins pin(s) or fewer ([llength $pSkipped])"
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
# net_compare_rule5 - a pin that came loose.
#
# Walks the PARTS both designs have rather than the two netlists, and asks one
# question of every pin the two sides share:
#
#     unconnected on (N), and on a net on (O)?
#
# If it is, (N)'s page gets a pink stub at that pin - one end exactly on the
# pin's own connection point, the other mRule5StubLen out and away from the
# part.  The stub is the marker: there is no wire left at that pin to draw over,
# which is the whole reason the net rules cannot report this.
#
# NOT the other way round.  A pin that GAINED a net on (N) is already a finding:
# the net it joined is either new (rule2) or has a pin (O) did not give it
# (rule4), and both of those already draw on the wire that arrives at it.
#
# Parts are matched on Part Reference and pins on PinKey - the same key the
# netlist names a pin with, so a rule5 line and a rule4 line about the same pin
# call it the same thing.  A reference or a pin key that is not unique on its own
# side is skipped and traced: with two U12s on a page there is no honest answer
# to "which U12 is this one", and guessing would put a stub on the wrong part.
#-----------------------------------------------------------------------------

# Which way rule5's stub points: out of the part, through whichever edge of its
# bounding box the pin is closest to.  Decided in the two steps the rule is
# stated in - WHICH AXIS first, then WHICH SIDE of that axis:
#
#   1  dX = how far the pin is from the nearer of the two VERTICAL edges
#      dY = how far the pin is from the nearer of the two HORIZONTAL edges
#
#   2  dX < dY   a horizontal stub.  Same Y as the pin; X + len when the right
#                edge is the nearer one, X - len when it is the left.
#      dY < dX   a vertical stub.  Same X as the pin; Y - len when the top edge
#                is the nearer one, Y + len when it is the bottom.
#      dX = dY   neither axis is nearer, so there is nothing to decide it on -
#                the default, right.
#
# Page coordinates run x right and y DOWN - CRect's top is the smaller y - so
# "up" is minus y, which is why the top edge is the one with the smaller number.
#
# Worked example, the one in the spec:
#
#   pin (12.86,3.80)   bbox (5.21,0.79)-(12.91,5.35)
#     dL |12.86 -  5.21| = 7.65     dT | 3.80 -  0.79| = 3.01
#     dR |12.91 - 12.86| = 0.05     dB | 5.35 -  3.80| = 1.55
#     dX = 0.05                     dY = 1.55
#     dX < dY -> horizontal, and dR < dL -> right: (12.86,3.80)-(13.26,3.80)
#
# Note that this is the same answer "nearest of the four edges" gives, because
# the nearest edge's axis IS the axis with the smaller of the two minima.  The
# two-step form is written out anyway: it is the rule as stated, and it puts the
# dX = dY case somewhere obvious instead of leaving it to the order four
# candidates happen to be tested in.
#
# RIGHT is the answer to everything that cannot be worked out - no bbox, no
# position, a degenerate box, or the axis tie above.  That is the spec's default.
# One honest caveat: for a pin at an exact diagonal tie near the top-left of a
# part, "right" points back through the part body.  It is a corner case of a
# corner case - a pin is normally hard against the edge its wire leaves by, which
# is what makes dX and dY differ by orders of magnitude in real data - and a
# stub over the body is still on the right pin and still visible.
#
# A tie WITHIN the chosen axis (a pin exactly mid-way between the top and bottom
# edges of a part wide enough for dY to still win) has no good answer either -
# every direction goes through the body - so it is resolved the same way each
# time rather than left to chance: up for the Y axis, right for the X axis.
proc ::mUtilMenu::Rule5StubDir { pPoint pBBox } {
    if { [llength $pPoint] != 2 || [llength $pBBox] != 4 } {
        return "right"
    }

    set lX [lindex $pPoint 0]
    set lY [lindex $pPoint 1]
    set lL [lindex $pBBox 0]
    set lT [lindex $pBBox 1]
    set lR [lindex $pBBox 2]
    set lB [lindex $pBBox 3]

    set lDL [expr { abs($lX - $lL) }]
    set lDR [expr { abs($lR - $lX) }]
    set lDT [expr { abs($lY - $lT) }]
    set lDB [expr { abs($lB - $lY) }]

    set lDX [expr { $lDL < $lDR ? $lDL : $lDR }]
    set lDY [expr { $lDT < $lDB ? $lDT : $lDB }]

    # Step 1 - the axis.  Strictly nearer either way round, so dX == dY falls
    # through both tests to the default at the bottom.
    if { $lDX < $lDY } {
        # Step 2 - the side.  <= so a pin mid-way between the two vertical edges
        # keeps the default direction rather than picking left by accident.
        if { $lDR <= $lDL } {
            return "right"
        }
        return "left"
    }
    if { $lDY < $lDX } {
        if { $lDT <= $lDB } {
            return "up"
        }
        return "down"
    }
    return "right"
}

# One rule5 stub as a {x1 y1 x2 y2} quad: from the pin, pLen doc units in
# pDir.  Anything other than the four directions grows to the right, which is the
# same default Rule5StubDir falls back to.
proc ::mUtilMenu::Rule5StubSeg { pPoint pDir pLen } {
    set lX [lindex $pPoint 0]
    set lY [lindex $pPoint 1]

    switch -exact -- $pDir {
        left    { return [list $lX $lY [expr { $lX - $pLen }] $lY] }
        up      { return [list $lX $lY $lX [expr { $lY - $pLen }]] }
        down    { return [list $lX $lY $lX [expr { $lY + $pLen }]] }
        default { return [list $lX $lY [expr { $lX + $pLen }] $lY] }
    }
}

# mRule5StubLen in doc units - GridTolDoc's conversion, not MarkOffsetDoc's.
#
# Same three modes and the same one-at-a-time degrading (grid falls back to user,
# user falls back to doc, each saying so), because this is the same question
# Search_Missing_connection_onGrid asks: how long is a thing quoted in grid steps
# on THIS page.  See mRule5StubLenUnits for why a stub must not be measured in
# the page's own user unit.
#
# The one thing it does that GridTolDoc does not is refuse to return 0.  A
# tolerance of zero is a legitimate setting - it just matches nothing - but a stub
# of zero is a zero-length line: an object on the page that draws nothing and can
# still be selected and deleted afterwards, which is worse than no marker at all.
proc ::mUtilMenu::Rule5StubDoc { pPage } {
    variable mRule5StubLen

    set lLen [::mUtilMenu::Rule5StubLenDoc $pPage]
    if { $lLen < 1 } {
        ::mUtilMenu::Trace "mRule5StubLen $mRule5StubLen converts to less than one doc unit on this page - drawing 1"
        set lLen 1
    }
    return $lLen
}

# The conversion proper, split out so the three modes read as three modes.
proc ::mUtilMenu::Rule5StubLenDoc { pPage } {
    variable mRule5StubLen
    variable mRule5StubLenUnits
    variable mGridStepInch

    if { $mRule5StubLenUnits eq "doc" || $pPage eq "" } {
        return [expr { round($mRule5StubLen) }]
    }

    if { $mRule5StubLenUnits eq "grid" } {
        set lDpi 0
        catch { set lDpi [$pPage GetDocUnitsPerInch] }
        if { $lDpi > 0 } {
            return [expr { round(double($mRule5StubLen) * $mGridStepInch * $lDpi) }]
        }
        ::mUtilMenu::Trace "GetDocUnitsPerInch gave nothing on this page - taking mRule5StubLen as user units"
    }

    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        ::mUtilMenu::Trace "no physical granularity on this page - taking mRule5StubLen as doc units"
        return [expr { round($mRule5StubLen) }]
    }
    return [expr { round(double($mRule5StubLen) * $lGran) }]
}

# Part rows -> array of reference to row, with every reference that appears more
# than once left OUT rather than resolved to one of them.  pDupName collects
# those references so the caller can say what it skipped.
proc ::mUtilMenu::PartsByRefUnique { pArrName pDupName pRows } {
    upvar 1 $pArrName lArr
    upvar 1 $pDupName lDup

    array set lSeen {}
    foreach lRow $pRows {
        set lRef [lindex $lRow 0]
        if { $lRef eq "" } {
            continue
        }
        if { [info exists lSeen($lRef)] } {
            incr lSeen($lRef)
            continue
        }
        set lSeen($lRef) 1
        set lArr($lRef)  $lRow
    }

    foreach lRef [lsort -dictionary [array names lSeen]] {
        if { $lSeen($lRef) > 1 } {
            unset -nocomplain lArr($lRef)
            lappend lDup "$lRef (x$lSeen($lRef))"
        }
    }
}

# The pins of one part row, keyed on PinKey, duplicates dropped the same way and
# for the same reason PartsByRefUnique drops duplicate references.
proc ::mUtilMenu::PinsByKeyUnique { pArrName pRow } {
    upvar 1 $pArrName lArr

    array set lSeen {}
    foreach lPin [lindex $pRow 10] {
        set lKey [::mUtilMenu::PinKey $lPin]
        if { $lKey eq "" } {
            continue
        }
        if { [info exists lSeen($lKey)] } {
            incr lSeen($lKey)
            continue
        }
        set lSeen($lKey) 1
        set lArr($lKey)  $lPin
    }

    foreach lKey [array names lSeen] {
        if { $lSeen($lKey) > 1 } {
            unset -nocomplain lArr($lKey)
        }
    }
}

# The rule itself.  Takes the two parts sections and fills mMarkPinSegs; returns
# {findings skipped duplicates}:
#
#   findings   {ref pinKey pinName oNet nConn dir point} per loose pin, where
#              point is {x y} doc units or {} when (N) would not give one
#   skipped    the findings with no position - reported, never drawn
#   duplicates the references that were ambiguous on one side or the other
proc ::mUtilMenu::PartPinConnCompare { pRowsO pRowsN } {
    variable mMarkPinSegs

    array set lPartsO {}
    array set lPartsN {}
    set lDup [list]
    ::mUtilMenu::PartsByRefUnique lPartsO lDup $pRowsO
    ::mUtilMenu::PartsByRefUnique lPartsN lDup $pRowsN

    set lFound   [list]
    set lSkipped [list]

    # (N)'s order, so the report reads in the order the parts walk found them
    # rather than in whatever order an array hands its names back.
    foreach lRowN $pRowsN {
        set lRef [lindex $lRowN 0]
        if { $lRef eq "" || ![info exists lPartsN($lRef)] \
             || ![info exists lPartsO($lRef)] } {
            continue
        }
        # The row out of the array and not the loop variable: a duplicate
        # reference was taken out of lPartsN, and the test above is what drops it.
        set lRowO [set lPartsO($lRef)]

        array unset lPinsO
        array unset lPinsN
        array set   lPinsO {}
        array set   lPinsN {}
        ::mUtilMenu::PinsByKeyUnique lPinsO $lRowO
        ::mUtilMenu::PinsByKeyUnique lPinsN $lRowN

        foreach lPinN [lindex $lRowN 10] {
            set lKey [::mUtilMenu::PinKey $lPinN]
            if { $lKey eq "" || ![info exists lPinsN($lKey)] \
                 || ![info exists lPinsO($lKey)] } {
                continue
            }

            # Element 3 is the net label, "" for a pin on no net at all.  That is
            # the test, and the no-connect MARKER (element 2) is deliberately not
            # part of it: a pin the designer has crossed out is still a pin that
            # used to carry a net, so it is still a change worth seeing.  Which of
            # the two it is goes in the report - ConnStr words it - so a marked NC
            # can be told from a bare unwired pin at a glance.
            set lNetO [lindex [set lPinsO($lKey)] 3]
            set lNetN [lindex $lPinN 3]
            if { $lNetN ne "" || $lNetO eq "" } {
                continue
            }

            set lPt  [lindex $lPinN 4]
            set lRec [list $lRef $lKey [lindex $lPinN 0] $lNetO \
                           [::mUtilMenu::PinConnStr $lPinN] "" $lPt]

            if { [llength $lPt] != 2 } {
                # No connection point on (N) - mPinPosAll off, or GetOffsetHotSpot
                # would not answer.  Reported, not drawn: there is nowhere to put
                # the stub, and a stub in the wrong place is worse than none.
                lappend lSkipped $lRec
                continue
            }

            set lDir [::mUtilMenu::Rule5StubDir $lPt [lindex $lRowN 9]]
            lset lRec 5 $lDir
            lappend lFound $lRec
            lappend mMarkPinSegs [list "rule5 $lRef.$lKey" \
                                       [lindex $lPt 0] [lindex $lPt 1] $lDir]
        }
    }

    return [list $lFound $lSkipped [lsort -dictionary -unique $lDup]]
}

# Print what rule5 found and return the report-window text for it, "" when it
# found nothing.  Same shape as PrintNetlistCompare, and for the same reason: the
# Command Window gets every pin, the report window gets the roll-up.
proc ::mUtilMenu::PrintPinConnCompare { pFound pSkipped pDup } {
    variable mRule5StubLen
    variable mRule5StubLenUnits

    if { [llength $pFound] == 0 && [llength $pSkipped] == 0 \
         && [llength $pDup] == 0 } {
        return ""
    }

    ::mUtilMenu::Out "    net_compare_rule5 - pin unconnected on (N), on a net on (O); pink stub $mRule5StubLen $mRule5StubLenUnits out of the pin"

    if { [llength $pDup] > 0 } {
        ::mUtilMenu::Out "      reference not unique on one side - not compared ([llength $pDup])"
        ::mUtilMenu::Out "        [join $pDup {, }]"
    }

    set lMsg ""

    if { [llength $pFound] > 0 } {
        ::mUtilMenu::Out "      loose pins ([llength $pFound])"
        set lShort [list]
        foreach lRec $pFound {
            ::mUtilMenu::Out [format "        %-14s %-22s (O) net: %-24s (N) %s   stub %s" \
                      "[lindex $lRec 0].[lindex $lRec 1]" [lindex $lRec 2] \
                      [lindex $lRec 3] [lindex $lRec 4] [lindex $lRec 5]]
            lappend lShort "[lindex $lRec 0].[lindex $lRec 1]"
        }
        append lMsg "  [format %-8s rule5] ([llength $pFound]) : [::mUtilMenu::RefListStr $lShort 0]\n"
    }

    # Listed apart from the findings above, never counted with them: a pin with no
    # position is a difference nobody can be pointed at.
    if { [llength $pSkipped] > 0 } {
        ::mUtilMenu::Out "      no connection point on (N) - not marked ([llength $pSkipped])"
        set lShort [list]
        foreach lRec $pSkipped {
            ::mUtilMenu::Out [format "        %-14s %-22s (O) net: %s" \
                      "[lindex $lRec 0].[lindex $lRec 1]" [lindex $lRec 2] \
                      [lindex $lRec 3]]
            lappend lShort "[lindex $lRec 0].[lindex $lRec 1]"
        }
        append lMsg "  [format %-8s {rule5?}] ([llength $pSkipped]) : [::mUtilMenu::RefListStr $lShort 0]\n"
    }

    if { $lMsg eq "" } {
        return ""
    }
    return "Pins (net_compare_rule5):\n$lMsg"
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
#   mMarkPinSegs  a pink stub per pin net_compare_rule5 found loose - see
#               PartPinConnCompare.  Not a wire marker at all: the pin it points
#               at has no wire left on (N), which is what rule5 is about.
#
# Only New, not Remove: a Remove is something (O) has and (N) has not, so there is
# nothing on (N)'s page to mark.  Rule5 is the one finding that reads (O) for what
# is MISSING on (N) and still has somewhere to draw it, because the pin survives
# even when the net does not.
proc ::mUtilMenu::DumpFullCompare { pDictO pDictN } {
    variable mMarkSegs
    variable mMarkBoxes
    variable mMarkPinSegs
    variable mRefListMax
    variable mRule5

    # {name dictKey sigsProc oneSigProc geomIndex listMax markKind}
    # geomIndex -1 / markKind "" = this category is not marked on the page.
    # Nets are -1 / "" on purpose - see the netlist block above.
    set lCats [list \
        [list "Parts"   parts   ::mUtilMenu::PartSigs   ::mUtilMenu::PartSig  9 $mRefListMax box] \
        [list "Symbols" symbols ::mUtilMenu::SymbolSigs ""                   -1 $mRefListMax ""] \
        [list "Nets"    nets    ::mUtilMenu::NetSigs    ::mUtilMenu::NetSig  -1 0            ""] \
        [list "Buses"   buses   ::mUtilMenu::BusSigs    ::mUtilMenu::BusSig   3 0            line]]

    set mMarkSegs    [list]
    set mMarkBoxes   [list]
    set mMarkPinSegs [list]

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

    # net_compare_rule5, straight after the netlist rules it belongs with and
    # before the section diff, so the Command Window still reads in the order the
    # work happens.  It fills mMarkPinSegs itself - the stubs are built off the
    # pin records, not off anything the section diff produces.
    set lPinMsg ""
    if { $mRule5 } {
        set lT     [::mUtilMenu::TimeNow]
        set lPinCmp [::mUtilMenu::PartPinConnCompare \
                         [dict get $pDictO parts] [dict get $pDictN parts]]
        ::mUtilMenu::TimeMark "pin rule5" $lT

        set lPinMsg [::mUtilMenu::PrintPinConnCompare \
                         [lindex $lPinCmp 0] [lindex $lPinCmp 1] [lindex $lPinCmp 2]]
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

    if { !$lAny && [llength $lMovedPart] == 0 && $lNetMsg eq "" \
         && $lPinMsg eq "" } {
        ::mUtilMenu::Out "    all the same"
        return "all the same"
    }

    # The netlist rules first, because they are what is drawn on the page, and
    # rule5 immediately after them - it is drawn too, and it is a net rule in
    # everything but which walk it runs on.
    set lMsg $lNetMsg
    if { $lPinMsg ne "" } {
        if { $lMsg ne "" } {
            append lMsg "\n"
        }
        append lMsg $lPinMsg
    }
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
#   4 docLoc      the same GetLocation as raw doc integers {x y}, or {}
#   5 docBBox     the symbol's bounding box as raw doc integers, or {} - what
#                 MarkGridFindings draws its box on
#
# Element 3 is the one added for the connection listing.  SymbolSigs still builds
# its signature out of elements 0-2 only, so PageComp's Symbols diff is exactly
# what it was; the connection is a listing, not a new difference.  Refcompare is
# the compare that does look at it - see DumpRefSymbolCompare.
#
# Elements 4 and 5 are the same relationship elements 9 and 10 have on a part row
# and element 3 on a bus row: the printed column has been through Coord and is
# rounded, so anything that has to MEASURE or DRAW with it reads the unrounded
# integers instead.  Search_Missing_connection_onGrid and MarkGridFindings are the
# two that do.
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
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache] \
                                [::mUtilMenu::ObjLocDoc $lObj $lStatus] \
                                [::mUtilMenu::ObjBBoxDoc $lObj]                                 [::mUtilMenu::SymHotSpotDoc $lObj $lStatus]]
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
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache] \
                                [::mUtilMenu::ObjLocDoc $lObj $lStatus] \
                                [::mUtilMenu::ObjBBoxDoc $lObj]                                 [::mUtilMenu::SymHotSpotDoc $lObj $lStatus]]
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
                                [::mUtilMenu::SymbolConn $lObj $lStatus lNetCache] \
                                [::mUtilMenu::ObjLocDoc $lObj $lStatus] \
                                [::mUtilMenu::ObjBBoxDoc $lObj]                                 [::mUtilMenu::SymHotSpotDoc $lObj $lStatus]]
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
# pPage first, and before pRows, because DumpPageInfoOn invokes this as a command
# PREFIX with the page already bound - the same shape PrintPartRows has, for the
# same reason.  It is optional so a bare "PrintSymbolRows $rows" from the Command
# Window still works; without a page there is nothing to convert doc units with,
# so the connection point is simply not printed.
proc ::mUtilMenu::PrintSymbolRows { args } {
    set pPage ""
    set pRows [lindex $args end]
    if { [llength $args] > 1 } {
        set pPage [lindex $args 0]
    }

    variable mSymConnDetail

    foreach lRow [lsort -dictionary -index 0 [lsort -dictionary -index 1 $pRows]] {
        set lLine [format "    %-8s %-26s %s" \
                       [lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]] \
                       [lindex $lRow 2]]

        # The connection point, in the same units the rest of the line is in, and
        # named with the reading SymHotSpotDoc settled on - "conn (19.95,12.50)
        # via GetHotSpot" says both where the wire lands and how that was worked
        # out.  Only printed when it is NOT the placement origin, because when
        # the two coincide the line already has the number once.
        set lHot [lindex $lRow 6]
        if { [llength $lHot] >= 2 && $pPage ne "" } {
            set lLoc [lindex $lRow 4]
            if { [llength $lLoc] != 2
                 || [lindex $lHot 0] != [lindex $lLoc 0]
                 || [lindex $lHot 1] != [lindex $lLoc 1] } {
                append lLine [format "  conn (%s,%s)" \
                    [::mUtilMenu::Coord $pPage [lindex $lHot 0]] \
                    [::mUtilMenu::Coord $pPage [lindex $lHot 1]]]
                if { [lindex $lHot 2] ne "" } {
                    append lLine " via [lindex $lHot 2]"
                }
            }
        }

        if { $mSymConnDetail && [llength $lRow] > 3 } {
            append lLine "\n                 -> [::mUtilMenu::ConnStr 0 [lindex $lRow 3]]"
        }
        ::mUtilMenu::Out $lLine
    }
    return [llength $pRows]
}

proc ::mUtilMenu::DumpPageSymbols { pPage } {
    return [::mUtilMenu::PrintSymbolRows $pPage [::mUtilMenu::CollectPageSymbols $pPage]]
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

# Is this page DboNet a BUS (or a bundle) rather than an ordinary scalar net?
#
# DboPageNetsIter with IterDefs_ALL hands back every net on the page, and a bus is
# a net - so a bus's wires were being listed twice, once under Nets from this walk
# and again under Buses from the page-wires walk that CollectPageBuses does.  Same
# coordinates, two sections, and Nets is the one that has no business printing
# them: everything downstream of it treats a row as a signal.
#
# The test is the object's own type, the same way CollectPageBuses tests a wire -
# just at the net level and the other way round:
#
#   DboBaseObject_NET_BUS      D[0..7] and friends
#   DboBaseObject_NET_BUNDLE   a bundle
#
# Bus MEMBERS are not caught by this and must not be: D[0] is a scalar net that
# happens to belong to a bus, it carries real connectivity, and the Nets section
# is where it belongs.
#
# Two things are deliberately NOT done here:
#
#   IterDefs_SCALARS   there is a mode argument on DboPageNetsIter that would skip
#                      bus nets without visiting them (new_DboPageNetsIter source
#                      mode), and Cadence uses its sibling IterDefs_BUSES that way
#                      in capISCFExport/tcl/capDesignPhysicalViewReader.tcl:1071.
#                      But no shipped script calls IterDefs_SCALARS, so what it
#                      selects is unverified - and a mode that turned out to mean
#                      something slightly different would silently DROP nets.
#                      Testing the type costs one call per net and cannot.
#   trusting the constants  a missing DboBaseObject_NET_BUS makes this answer "not
#                      a bus", so the net is KEPT.  Printing a bus twice is a
#                      cosmetic fault; dropping a signal net is a real one, and an
#                      unreadable constant must not be able to cause the second.
proc ::mUtilMenu::IsBusNet { pNet } {
    set lOT ""
    if { [catch { set lOT [$pNet GetObjectType] }] || $lOT eq "" } {
        return 0
    }

    foreach lVar { ::DboBaseObject_NET_BUS ::DboBaseObject_NET_BUNDLE } {
        if { [info exists $lVar] && $lOT eq [set $lVar] } {
            return 1
        }
    }
    return 0
}

# Is this DboWire a BUS wire rather than an ordinary signal wire?  Same test
# CollectPageBuses uses to FIND buses, so the two are exact complements: a wire
# this says yes to is a wire that section is already printing.
#
# This is the one that matters, and IsBusNet on its own was not enough.  Skipping
# bus NET objects only removes the bus's own entry from the list; it does nothing
# about the far bigger problem, which is that a bus MEMBER carries the bus's wires
# in its own wire list.  DboNet::NewWiresIter on V_M_BMC_DDR4_DQ0 returns the one
# scalar wire that runs from the pin to the bus AND all seventeen wires of the bus
# it then travels along - and so does DQ1, and DQ2, and every other member.  On a
# real DDR page that came to 482 of 835 wire lines being the same bus repeated,
# one segment claimed by sixteen different nets.
#
# The damage was not just a long dump.  Sixteen nets all reporting an endpoint at
# the same coordinate, all tagged NET and each in its own group, is sixteen nets
# that "should have been one net" as far as Search_Missing_connection_onGrid is
# concerned - see the distance-0 rule, which keeps a zero gap as a finding when
# both sides are NET.  That page produced 400 "two nets that did not merge"
# findings, every one of them a bus doing exactly what a bus is supposed to do.
#
# Fail-safe the same way as IsBusNet: anything unreadable answers "not a bus", so
# a wire is kept.  A bus wire listed under Nets is noise; a signal wire dropped
# from Nets is a missing connection nobody will ever be told about.
proc ::mUtilMenu::IsBusWire { pWire } {
    set lOT ""
    if { [catch { set lOT [$pWire GetObjectType] }] || $lOT eq "" } {
        return 0
    }

    foreach lVar { ::DboBaseObject_WIRE_BUS ::DboBaseObject_WIRE_BUNDLE } {
        if { [info exists $lVar] && $lOT eq [set $lVar] } {
            return 1
        }
    }
    return 0
}

# Nets on one page.  Returns rows of
# {name {endpoints...} {docSegs...} schematicName}.
#
# Element 2 is the same wires again as {x1 y1 x2 y2} doc-unit quads, in the same
# order as element 1 before it was sorted for printing.  Only the marker lines use
# it; printing and the signatures stay on elements 0 and 1.
#
# Element 3 is what the whole schematic calls this net - see SchNetName - and is
# "" when the net has no schematic net or mNetShowSchName is off.  It is on the
# END of the row on purpose: element 0 is still the page label, so every existing
# reader (NetSig, NetsByName, GridNetGroup, the netlist rules) keeps indexing the
# same elements and sees the same values.  Only PrintNetRows looks at element 3.
#
# Buses are skipped - see IsBusNet and mNetSkipBuses.  IterDefs_ALL is still what
# the iterator is asked for, so bus MEMBERS keep coming through; it is the bus
# object itself that is dropped, because CollectPageBuses already lists its wires.
proc ::mUtilMenu::CollectPageNets { pPage } {
    variable mNetShowSchName
    variable mNetSkipBuses

    set lStatus   [DboState]
    set lNullObj  NULL
    set lRows     [list]
    set lSkipped  0
    set lBusWires 0

    set lNetsIter [::mUtilMenu::NextIterName Nets]
    DboPageNetsIter $lNetsIter $pPage $::IterDefs_ALL
    set lNet [$lNetsIter NextNet $lStatus]

    while { $lNet != $lNullObj } {
        if { $mNetSkipBuses && [::mUtilMenu::IsBusNet $lNet] } {
            incr lSkipped
            set lNet [$lNetsIter NextNet $lStatus]
            continue
        }

        set lNames [list]
        set lSegs  [list]
        set lDocs  [list]

        # Method form of the wires iterator, as in capDRC/capOverlapWires.tcl:172.
        set lWiresIter [$lNet NewWiresIter $lStatus]
        set lWire      [$lWiresIter NextWire $lStatus]
        while { $lWire != $lNullObj } {
            # The bus wires a member net travels along belong to the Buses
            # section, not to this net - see IsBusWire.  Skipped before the
            # aliases as well, so a member cannot be named after its bus.
            if { $mNetSkipBuses && [::mUtilMenu::IsBusWire $lWire] } {
                incr lBusWires
                set lWire [$lWiresIter NextWire $lStatus]
                continue
            }
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

        set lSchName ""
        if { $mNetShowSchName } {
            set lSchName [::mUtilMenu::SchNetName $lNet]
        }

        lappend lRows [list [::mUtilMenu::NetLabel $lNet $lNames] \
                            [lsort -dictionary $lSegs] \
                            $lDocs \
                            $lSchName]

        set lNet [$lNetsIter NextNet $lStatus]
    }

    ::mUtilMenu::DropIter $lNetsIter
    catch { $lStatus -delete }

    # Said out loud, and only when it happened.  A section that quietly drops rows
    # is a section nobody can tell apart from a page that has no buses on it, and
    # the count is also the one number that says whether the skip is doing
    # anything at all on this design.
    if { $lSkipped > 0 || $lBusWires > 0 } {
        ::mUtilMenu::Out [format \
            "    (%d bus/bundle net(s) and %d bus wire(s) carried by member nets not listed here - see the Buses section)" \
            $lSkipped $lBusWires]
    }
    return $lRows
}

# The name column of one net row: the page label, plus the schematic-wide name in
# brackets when the two are not the same.  "" and an identical name both print as
# the bare label, so a bracket always carries information - see mNetShowSchName.
proc ::mUtilMenu::NetLabelWithSch { pRow } {
    set lLabel [lindex $pRow 0]
    set lSch   [lindex $pRow 3]

    if { $lSch eq "" || $lSch eq $lLabel } {
        return $lLabel
    }
    return "$lLabel ($lSch)"
}

# The name column is 28 wide as it has always been, but a bracketed schematic name
# overflows that and would push "wires:" out of line on that one row alone.  So
# the width is the widest name actually being printed, floored at 28: a dump with
# no renamed nets in it comes out byte for byte as before, and one with renamed
# nets stays in a column instead of ragging.
proc ::mUtilMenu::PrintNetRows { pRows } {
    set lWide 28
    foreach lRow $pRows {
        set lLen [string length [::mUtilMenu::NetLabelWithSch $lRow]]
        if { $lLen > $lWide } {
            set lWide $lLen
        }
    }

    foreach lRow [lsort -dictionary -index 0 $pRows] {
        set lSegs [lindex $lRow 1]
        ::mUtilMenu::Out [format "    %-${lWide}s wires: %d" \
                              [::mUtilMenu::NetLabelWithSch $lRow] [llength $lSegs]]
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
        error "design not found in session: [file tail $pDsnPath]"
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

    # The DESIGN is named as well as the page.  Both sides of a compare usually
    # have the same schematic name and the same page names - that is what makes
    # them a pair - so "page not found: W980_WS / P02. VCORE" on its own does not
    # say which of the two .DSN files was being looked in, and that is exactly the
    # thing worth knowing when a page goes missing mid-run.
    if { $lFound == $lNullObj } {
        error "page not found in [file tail $pDsnPath]: $pSchName / $pPageName"
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

    return [::mUtilMenu::DumpPageInfoOn $lPage $pWhat]
}

# The same dump against a DboPage that is already in hand, skipping the lookup.
# DumpPageInfo is the {design schematic page} front door onto this; Schematic
# Check comes in here instead, because the Project Manager hands it the page
# object itself and walking the whole design to find a page it already has would
# be silly.
proc ::mUtilMenu::DumpPageInfoOn { pPage {pWhat {parts symbols nets buses}} } {
    set lTotals [list]
    set lOut    [list parts [list] symbols [list] nets [list] buses [list]]

    # {section dictKey heading collectProc printPrefix unit}
    #
    # Element 4 is a command PREFIX, not a bare proc name, and is invoked with
    # {*} below: the nets and buses rows already carry their coordinates as
    # finished text (WireSegStr converted them at collect time), but a part row
    # keeps its pin positions as raw doc integers for net_compare_rule4 and a
    # symbol row keeps its connection point as raw doc integers for GridEndpoints,
    # so those two printers need the page to convert them - and the prefix is
    # where they get it.
    set lSecs [list \
        [list parts   parts   "  Parts" \
             ::mUtilMenu::CollectPageParts \
             [list ::mUtilMenu::PrintPartRows $pPage] "part(s)"] \
        [list symbols symbols "  Off-Page / Power / Ports" \
             ::mUtilMenu::CollectPageSymbols \
             [list ::mUtilMenu::PrintSymbolRows $pPage] "symbol(s)"] \
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
        set lRows [[lindex $lSec 3] $pPage]
        ::mUtilMenu::TimeMark "$lWhich collect" $lT

        set lOut [dict replace $lOut [lindex $lSec 1] $lRows]

        set lT [::mUtilMenu::TimeNow]
        set lN [{*}[lindex $lSec 4] $lRows]
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
# has to match exactly (case included) for the solid black "exact" line.
#
# Anything short of that is the red dashed "similar" line, and there are three
# ways to earn it - see Page_name_mapping for the order they run in and why.
# Two of them work on the COMPACTED name, which is the name with every
# mPageNameRedundantChars character taken out of it wherever it sat, not just off
# the front: that is what lets a page survive a renumbering that only moved the
# separators about.
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

# Take every mPageNameRedundantChars character OUT of a name, wherever it sits -
# the front, the middle, the end.
#
#   "*096. BMC AST2600 UART,SPI,MAC"  ->  "096BMCAST2600UART,SPI,MAC"
#
# string map and not string trim: trim and trimleft only reach the ends, and the
# whole point here is the dots and the spaces in the MIDDLE of the name.  The map
# is built one character to the empty string, which is also why the character set
# needs no regexp escaping - "$" and "-" are plain data to string map, and a
# bracket expression would have to escape both.
proc ::mUtilMenu::StripPageNameRedundant { pName } {
    variable mPageNameRedundantChars

    set lMap [list]
    foreach lChar [split $mPageNameRedundantChars ""] {
        lappend lMap $lChar ""
    }
    return [string map $lMap $pName]
}

# The compacted form of a key, for the two similar passes that use it.  Takes a
# KEY and not a {schematic page} pair, so it has the same signature as
# PageKeyHead and PairSimilarPass can be handed any of the three.
#
# Safe to feed the already-prefix-stripped key because mPageNameRedundantChars is
# a superset of mPageNamePrefixChars - see the variable's comment.
proc ::mUtilMenu::PageKeyCompact { pKey } {
    return [::mUtilMenu::StripPageNameRedundant $pKey]
}

# The leading slice of the compacted key - the loosest of the three similar
# tests.  Returns "" when mPageCompactSimilarChars is 0, and PairSimilarPass
# skips a page whose key comes back empty, which is how that turns the pass off.
proc ::mUtilMenu::PageKeyCompactHead { pKey } {
    variable mPageCompactSimilarChars

    if { $mPageCompactSimilarChars <= 0 } {
        return ""
    }
    return [string range [::mUtilMenu::PageKeyCompact $pKey] 0 \
                [expr { $mPageCompactSimilarChars - 1 }]]
}

# One greedy pass of the "similar" matching, over whatever pass 1 and the earlier
# similar passes left alone on BOTH sides.
#
# pKeyProc is what turns a page's key into the string this pass matches on -
# PageKeyHead, PageKeyCompact or PageKeyCompactHead.  A page whose key comes back
# empty is skipped, which is how mPageCompactSimilarChars 0 switches the
# compacted-head pass off without a second flag.
#
# The three name arguments are the caller's variables, written in place: two
# marks lists and the links list.  Passing them by name rather than returning
# three new lists is what keeps the passes composable - each one sees the marks
# the pass before it set, so a page already claimed cannot be claimed again.
#
# Returns how many pairs it made, for the trace line in Page_name_mapping.
proc ::mUtilMenu::PairSimilarPass { pKeysA pKeysB pMarksAName pMarksBName \
                                   pLinksName pKeyProc } {
    upvar 1 $pMarksAName lMarksA
    upvar 1 $pMarksBName lMarksB
    upvar 1 $pLinksName  lLinks

    # Per match string, the A indices still free, in column order.  Taking the
    # first of them is what makes duplicates pair up one for one instead of all
    # landing on the same page.
    array set lFreeA {}
    for { set i 0 } { $i < [llength $pKeysA] } { incr i } {
        set lKey [lindex $pKeysA $i]
        if { $lKey eq "" || [lindex $lMarksA $i] ne "none" } {
            continue
        }
        set lMatch [$pKeyProc $lKey]
        if { $lMatch eq "" } {
            continue
        }
        lappend lFreeA($lMatch) $i
    }

    set lMade 0
    for { set j 0 } { $j < [llength $pKeysB] } { incr j } {
        set lKey [lindex $pKeysB $j]
        if { $lKey eq "" || [lindex $lMarksB $j] ne "none" } {
            continue
        }
        set lMatch [$pKeyProc $lKey]
        if { $lMatch eq "" || ![info exists lFreeA($lMatch)] \
             || [llength $lFreeA($lMatch)] == 0 } {
            continue
        }
        set i              [lindex $lFreeA($lMatch) 0]
        set lFreeA($lMatch) [lrange $lFreeA($lMatch) 1 end]

        lset lMarksA $i similar
        lset lMarksB $j similar
        lappend lLinks [list $i $j similar]
        incr lMade
    }
    return $lMade
}

# Pair column A's pages up with column B's.  One exact pass, then three similar
# ones over what it left alone:
#
#   exact     the stripped names are identical, case included - black, solid line
#   similar   any one of, tried in this order:
#               1  the COMPACTED names are identical - both names with every
#                  mPageNameRedundantChars character taken out, so "096. BMC
#                  AST2600" and "096 - BMC  AST2600" are the same page
#               2  the first mPageSimilarChars (10) characters of the stripped
#                  names agree - the original rule
#               3  the first mPageCompactSimilarChars (7) characters of the
#                  COMPACTED names agree
#             all three draw the same red dashed line; only which page gets
#             paired with which can differ.
#
# WHY THAT ORDER.  Strictest first, because the passes are greedy and a page can
# only be claimed once: a compacted-exact match is all but an exact match and has
# to get first refusal on its counterpart, or a 10-character prefix agreement
# with some other page could claim it away and leave the better pair unmade.
# Pass 3 is the loosest and runs last for the same reason - 7 compacted
# characters is roughly "the number and the start of the block name", which is
# enough to be worth a dashed line and not enough to outrank the two above it.
#
# Every pass is greedy and first-come, and a page can only be claimed once - so
# two pages in A that reduce to the same string are matched by the two pages in
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

    # Passes 2a/2b/2c - similar, strictest first.  Each one only looks at pages
    # every pass before it left "none", so the marks lists are the state that
    # makes the three of them one rule with three ways to satisfy it.
    foreach lPass [list \
        [list "compacted names identical"      ::mUtilMenu::PageKeyCompact] \
        [list "first 10 chars identical"       ::mUtilMenu::PageKeyHead] \
        [list "first 7 compacted chars identical" ::mUtilMenu::PageKeyCompactHead]] {

        set lMade [::mUtilMenu::PairSimilarPass $lKeysA $lKeysB \
                       lMarksA lMarksB lLinks [lindex $lPass 1]]
        if { $lMade > 0 } {
            ::mUtilMenu::Trace "page mapping: $lMade similar pair(s) - [lindex $lPass 0]"
        }
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
# Result window - where Compare / Refcompare / Schematic Check put their report.
#
# capDisplayMessageBox is modal and its text cannot be selected, so there was no
# way to get the report out of it.  This is a read-only text widget: -state
# disabled blocks editing but leaves the usual selection bindings alone, so a
# mouse drag plus Ctrl-C works (checked against the Tk 8.6.5 that Capture ships).
# Select All / Copy buttons are there for the same job without the drag, and Copy
# with nothing selected takes the whole report.
#
# One window, rebuilt per run, shared by all three: they are three answers to the
# same kind of question and nobody wants two of them stacked up.  What differs is
# only what Close means, which is ShowResultWindow's pOnClose.
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
#
# pOnClose is what Close, the window's X and Escape all call.  It defaults to
# CloseResultAndSelector, which is Schematic Compare's answer - the report and the
# page selector that started it are one job there.  Schematic Check has no
# selector behind it and passes CloseResultWindow instead, so its Close closes the
# report and nothing else.  All three routes get the same command whichever it is:
# having X and Escape mean different things would be a bug, not a feature.
proc ::mUtilMenu::ShowResultWindow { pTitle pText {pOnClose ""} } {
    variable mResultWin

    if { $pOnClose eq "" } {
        set pOnClose "::mUtilMenu::CloseResultAndSelector"
    }

    # Should not happen - the page selector is a Tk window, so Tk is already up -
    # but fall back to the old message box rather than losing the report.  It is a
    # real possibility for Schematic Check, which can be started from the menu
    # with no Tk window having been built yet.
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
    wm protocol $mResultWin WM_DELETE_WINDOW $pOnClose
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
        -command $pOnClose
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
    bind $mResultWin <Escape>   $pOnClose

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

    # A literal NULL argument is safe on exactly ONE of these classes.
    # DboDesign::MarkModified(DboOccurrence*) documents NULL as "no particular
    # occurrence" and Cadence's own capReplacePathInCache.tcl:736 passes it; every
    # other class here has overloads that dereference their argument, and
    # DboLib alone has nine of them.  Handing NULL to one of those is an access
    # violation inside the DLL - Capture disappears, and the catch below never
    # runs, because there is no Tcl error to catch.
    #
    # SWIG names a pointer's Tcl handle after the DECLARED type, so the handle
    # itself says which class this call will land in - the same "_p_Dbo<Class>"
    # suffix PMItemDboClass reads off the Project Manager's labels.  Anything that
    # is not plainly a DboDesign gets the no-argument form instead.
    if { [lsearch -exact $args NULL] != -1 } {
        if { [::mUtilMenu::PMItemDboClass $pObj] ne "DboDesign" } {
            ::mUtilMenu::Trace "MarkModified NULL is only safe on DboDesign, not on $pObj - using the no-argument form"
            set args [list]
        }
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

# "Something on this page changed" - told to ALL THREE levels that need to hear
# it, each with the arguments its own MarkModified takes.
#
# WHY THREE AND NOT ONE.  Marking the page alone is what every drawing path used
# to do, and it is not enough: File > Save operates on the DESIGN, and a design
# whose IsModified never went true is a design Capture may refuse to write -
# ERROR(ORCAP-1650): Unable to save '...DSN', with Save As working because Save As
# writes to a new path instead of updating a design it does not believe is dirty.
# The rename path (StarPageObj) always marked all three and never saw the problem;
# the marker path marked only the page, and that asymmetry is what this proc is
# here to remove.  One place, so the next drawing path cannot get it half right.
#
# The design is reached the same way StarPageObj reaches it and for the same
# reason: GetContainingLib is DECLARED as DboLib*, SWIG types the handle by the
# declared type, and DboLib::MarkModified has nine overloads none of which accepts
# NULL - so the lib handle must never be given NULL.  DboLib::GetName on a design
# is its .DSN path, which is the key GetDesignAndSchematics wants, and FindDesign
# turns that back into a real DboDesign whose MarkModified(NULL) is the sanctioned
# call.  If that round trip fails, the lib gets the no-argument form instead,
# which is the only shape that is safe on it.
#
# pSch is optional because not every caller has one - Schematic Check is handed a
# DboPage by the Project Manager and never sees its schematic.  The DESIGN level
# does not depend on it, and that is the level that matters for saving.
#
# Returns 1 when the design (or, failing that, the lib) was reached.
# Re-evaluate one page after its contents were changed.
#
# THE STEP THIS FILE WAS MISSING.  Every drawing path here writes objects straight
# into the database with the Dbo API and then does MarkModified + ZoomRedraw.
# Cadence's own code does one more thing between those two, five times over in
# capFindAndReplace/tcl/capDesignUtil.tcl (:395, :474, :550, :626, :926), and
# always in the same shape:
#
#     set lIsPageModified [$pPage IsModified $lStatus]
#     if { $lIsPageModified == 1 } {
#         catch {DboTclHelper_sEvalPage $pPage}
#         catch {ZoomRedraw}
#     }
#
# Writing objects with the Dbo API bypasses the command path Capture would
# normally put a page change through, and that path is what evaluates the page
# afterwards.  Leave it out and the page is flagged modified but never settled -
# which on ONE page nobody notices, and on the ninety-five pages AllPagesComp
# touches showed up as File > Save failing on the first press with
# ERROR(ORCAP-1650) and working on the second.
#
# The call is declared in orDb_Dll_Tcl64.dll as
#   o:DboTclHelper_sEvalPage pPage          (?sEvalPage@DboTclHelper@@SAXPEAVDboPage@@@Z)
# - static, one DboPage*, returns void, so there is no status to read and nothing
# to delete.  Appendix A does not document it; the DLL and Cadence's own use are
# the whole of the evidence, which is why it is caught rather than trusted.
#
# Guarded on IsModified the way Cadence guards it: a page nothing changed does not
# need evaluating, and on a whole-design run that is most of them.
proc ::mUtilMenu::EvalPageIfModified { pPage } {
    if { $pPage eq "" || $pPage eq "NULL" } {
        return 0
    }
    if { [info commands DboTclHelper_sEvalPage] eq "" } {
        ::mUtilMenu::Trace "DboTclHelper_sEvalPage is not in this Capture build - page not re-evaluated"
        return 0
    }

    set lMod 0
    catch {
        set lStatus [DboState]
        set lMod [$pPage IsModified $lStatus]
        catch { $lStatus -delete }
    }
    if { $lMod != 1 } {
        return 0
    }

    if { [catch { DboTclHelper_sEvalPage $pPage } lErr] } {
        ::mUtilMenu::Trace "DboTclHelper_sEvalPage failed -> $lErr"
        return 0
    }
    return 1
}

# pDsnPath is the .DSN the page belongs to, when the caller knows it - and the
# Schematic Compare callers all do, because it is what they were asked to compare.
# GIVE IT WHENEVER YOU HAVE IT.  Deriving the design from the page instead means
# page -> GetContainingLib -> DboLib::GetName -> FindDesign, and that round trip
# is only as good as the string GetName hands back: it has to come out in a form
# "file normalize" and then GetDesignAndSchematics both accept.  On a .DSN opened
# WITHOUT its .opj - which Schematic Compare does routinely, since it opens the
# two .DSN files by path - that is not something to rely on, and when it fails
# the design is never marked and File > Save has nothing to write.
#
# Returns 1 only when the DESIGN itself was marked.  0 means the page (and maybe
# the schematic and the lib) were marked and the design was not - which is the
# state that makes a visibly-changed page refuse to save, so callers should SAY
# SO rather than swallow it.  That is the whole reason this returns anything: the
# first version only wrote a Trace line, nobody saw it, and the symptom surfaced
# as ERROR(ORCAP-1650) two machines later.
proc ::mUtilMenu::MarkPageDirty { pPage {pSch ""} {pDsnPath ""} } {
    if { $pPage eq "" || $pPage eq "NULL" } {
        return 0
    }

    ::mUtilMenu::MarkObjModified $pPage

    # Straight after the page is flagged and before anything else - this is where
    # Cadence's own code puts it, and the flag is what it keys off.  See
    # EvalPageIfModified for why leaving it out cost a failed first Save.
    ::mUtilMenu::EvalPageIfModified $pPage

    if { $pSch ne "" && $pSch ne "NULL" } {
        ::mUtilMenu::MarkObjModified $pSch $pPage
    }

    # The caller's path first - FindDesign normalises it the same way every other
    # lookup in this file does, so it is the same key the design went in under.
    set lDesign ""
    if { $pDsnPath ne "" } {
        catch { set lDesign [::mUtilMenu::FindDesign $pDsnPath] }
        if { $lDesign eq "" || $lDesign eq "NULL" } {
            ::mUtilMenu::Trace "FindDesign found nothing for [file tail $pDsnPath] - falling back to the page's own lib"
        }
    }

    set lLib ""
    catch { set lLib [$pPage GetContainingLib] }

    # Derive it only when the caller had nothing to give, or gave something that
    # did not resolve.
    set lPath $pDsnPath
    if { ($lDesign eq "" || $lDesign eq "NULL") \
         && $lLib ne "" && $lLib ne "NULL" } {
        set lPath [::mUtilMenu::CStr $lLib GetName]
        if { $lPath ne "" } {
            catch { set lDesign [::mUtilMenu::FindDesign $lPath] }
        }
    }

    if { $lDesign ne "" && $lDesign ne "NULL" } {
        catch { ::mUtilMenu::MarkObjModified $lDesign NULL }
        return 1
    }

    # No DboDesign to be had.  The lib is marked with the ONLY shape that is safe
    # on it - the inherited no-argument one - but that is not the same thing and
    # the caller is told so.
    if { $lLib ne "" && $lLib ne "NULL" } {
        catch { ::mUtilMenu::MarkObjModified $lLib }
    }
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

    ::mUtilMenu::MarkPageDirty $lPage "" $pDsnPath
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

# One {x1 y1 x2 y2} doc-unit quad as the marker block prints it: the page's own
# user unit first, so it can be read against the dump above, then the raw doc
# integers in brackets, which are what actually went to Capture.
#
# Works for a bounding box as well as a segment - a CRect is the same four numbers
# in the same order - so the line, the box and the stub all print alike.
#
# Coord is the same converter every other printed coordinate goes through, so a
# stub at a pin prints the identical number the Parts dump printed for that pin.
# With mCoordMode "doc" it returns the doc value and both halves say the same
# thing, which is honest rather than clever.
proc ::mUtilMenu::SegStr { pPage pQuad } {
    return [format "(%s,%s)-(%s,%s) doc (%s,%s)-(%s,%s)" \
        [::mUtilMenu::Coord $pPage [lindex $pQuad 0]] \
        [::mUtilMenu::Coord $pPage [lindex $pQuad 1]] \
        [::mUtilMenu::Coord $pPage [lindex $pQuad 2]] \
        [::mUtilMenu::Coord $pPage [lindex $pQuad 3]] \
        [lindex $pQuad 0] [lindex $pQuad 1] [lindex $pQuad 2] [lindex $pQuad 3]]
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
#   pins          net_compare_rule5's stubs: a pink line whose FIRST end is the
#                 pin's own connection point and whose second is
#                 mRule5StubLen out of the part.  No offset either, and for a
#                 stronger reason than the boxes - the stub means "this pin",
#                 and a nudged stub means the pin next to it.  The length is
#                 turned into doc units here rather than at compare time
#                 because it is quoted in grid steps and only the page knows
#                 how many doc units a step is.
#
# WHAT THE COORDINATES ARE PRINTED IN.  The page's own user unit, through the
# same Coord every other coordinate in the dump goes through, with the raw doc
# integers after it in brackets.  They used to be doc-only, which on a metric page
# made the block impossible to check: the Parts dump says a pin is at
# (128.02,19.30) mm and the marker block said the stub was at (504,76), and
# nothing on the page said those were the same point.  Both are printed because
# both are wanted - the user unit to match against the dump above, the doc
# integers because those are what was actually handed to Capture.
#
# Does nothing when the compare found nothing new to mark.
#
# pFile / pPair say which page to draw on - PageComp passes the one page column B
# has ticked (through DrawCompareMarkerLine below), AllPagesComp passes each mapped
# page in turn.
proc ::mUtilMenu::DrawMarkersOnPage { pFile pPair } {
    variable mMarkSegs
    variable mMarkBoxes
    variable mMarkPinSegs

    set lWanted [expr { [llength $mMarkSegs] + [llength $mMarkBoxes] \
                        + [llength $mMarkPinSegs] }]
    if { $lWanted == 0 } {
        ::mUtilMenu::Trace "nothing new in Parts/Nets/Buses and no loose pins - no markers"
        return 0
    }
    set lPair $pPair

    # One page lookup for the whole batch: FindPageObjs walks every schematic and
    # page in the design, so calling it per marker would be quadratic on a real
    # board.
    #
    # FindPageObjs and not FindPage - the same walk, and it hands back the
    # SCHEMATIC alongside the page for nothing extra (FindPage is a one-line
    # wrapper that throws the schematic away).  MarkPageDirty wants it.
    if { [catch { set lObjs [::mUtilMenu::FindPageObjs $pFile \
                                 [lindex $lPair 0] [lindex $lPair 1]] } lErr] } {
        ::mUtilMenu::Trace "markers failed on (N) [file tail $pFile] / [::mUtilMenu::PageLabel $lPair] -> $lErr"
        return 0
    }
    set lSch  [lindex $lObjs 0]
    set lPage [lindex $lObjs 1]

    set lOffset  [::mUtilMenu::MarkOffsetDoc $lPage]
    set lStubLen [::mUtilMenu::Rule5StubDoc  $lPage]
    set lDrawn   0

    ::mUtilMenu::Out "----------------------------------------------------------------"
    ::mUtilMenu::Out "Markers on (N) [file tail $pFile] - [::mUtilMenu::PageLabel $lPair]"
    ::mUtilMenu::Out "  [llength $mMarkSegs] line(s), offset $lOffset doc units (mLineOffset $::mUtilMenu::mLineOffset $::mUtilMenu::mLineOffsetUnits)"
    ::mUtilMenu::Out "  [llength $mMarkBoxes] rectangle(s), on the bounding box as-is"
    ::mUtilMenu::Out "  [llength $mMarkPinSegs] rule5 stub(s), $lStubLen doc units out of the pin = [::mUtilMenu::Coord $lPage $lStubLen] [::mUtilMenu::CoordUnitLabel $lPage] (mRule5StubLen $::mUtilMenu::mRule5StubLen $::mUtilMenu::mRule5StubLenUnits)"
    ::mUtilMenu::Out "  coordinates below are [::mUtilMenu::CoordUnitLabel $lPage], raw doc units in brackets"
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
        ::mUtilMenu::Out [format "    line %-30s %s -> %s" $lLabel \
                  [::mUtilMenu::SegStr $lPage $lSeg] [::mUtilMenu::SegStr $lPage $lAt]]
    }

    foreach lEntry $mMarkBoxes {
        set lLabel [lindex $lEntry 0]
        set lBox   [lrange $lEntry 1 4]

        if { [catch { ::mUtilMenu::DrawPageBoxOn $lPage $lBox } lErr] } {
            ::mUtilMenu::Trace "marker rectangle for $lLabel at $lBox failed -> $lErr"
            continue
        }
        incr lDrawn
        ::mUtilMenu::Out [format "    box  %-30s %s" $lLabel \
                  [::mUtilMenu::SegStr $lPage $lBox]]
    }

    foreach lEntry $mMarkPinSegs {
        set lLabel [lindex $lEntry 0]
        set lSeg   [::mUtilMenu::Rule5StubSeg [lrange $lEntry 1 2] \
                        [lindex $lEntry 3] $lStubLen]

        if { [catch { ::mUtilMenu::DrawPageLineOn $lPage \
                          [lrange $lSeg 0 1] [lrange $lSeg 2 3] } lErr] } {
            ::mUtilMenu::Trace "rule5 stub for $lLabel at $lSeg failed -> $lErr"
            continue
        }
        incr lDrawn
        ::mUtilMenu::Out [format "    stub %-30s %s  %s" $lLabel \
                  [::mUtilMenu::SegStr $lPage $lSeg] [lindex $lEntry 3]]
    }

    # Page, schematic AND design - see MarkPageDirty.  The design level is the one
    # File > Save reads, and marking only the page is what left a drawn-on design
    # refusing to save.  $pFile is handed over because this proc knows it and the
    # page does not reliably.
    if { $lDrawn > 0 } {
        if { ![::mUtilMenu::MarkPageDirty $lPage $lSch $pFile] } {
            # Out and not Trace: a design that was drawn on but never marked
            # modified is one File > Save will refuse, and that has to be visible
            # in the same log the markers were just listed in.
            ::mUtilMenu::Out "  *** [file tail $pFile] could NOT be marked modified - File > Save will refuse it (use Save As, and check the .opj is there)"
        }
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
    return [::mUtilMenu::StarPageObj [lindex $lObjs 0] [lindex $lObjs 1] $pFile]
}

# The rename itself, from the objects rather than from {file schematic page}.
#
# Schematic Check already holds the DboPage it just checked - the Project Manager
# handed it over, or the walk over the design produced it - so re-finding it by
# name would be a second walk of the design per page, and on a 100-page design
# that is 100 walks.  MarkPageNameChanged keeps the by-name door open for the
# compare, which only ever has names.
#
# WHERE THE DESIGN COMES FROM, AND WHY IT IS NOT GetContainingLib.
#
# DboPage::GetContainingLib is declared to return DboLib* (checked in
# orDb_Dll_Tcl64.dll: ?GetContainingLib@DboBaseObject@@UEAAPEAVDboLib@@XZ), and
# SWIG types the Tcl handle by the DECLARED type, not by the object behind it.  So
# a handle from GetContainingLib dispatches into DboLib's methods even though the
# object really is a DboDesign - and DboLib::MarkModified has NINE overloads, none
# of which takes a null pointer:
#
#   DboLib::MarkModified(DboCell* / DboView* / DboLibPart* / DboSymbol* /
#                        DboPackage* / DboGraphicObject* / DboLibObject* /
#                        DboExportBlock* / CString&, DboDirectory*)
#   DboDesign::MarkModified(DboOccurrence*)      <- the one that accepts NULL
#
# "MarkModified NULL" on that handle therefore hands a null pointer to one of the
# nine, which dereferences it inside the DLL and takes Capture down with it - an
# access violation, not a Tcl error, so catch cannot save it.  That is exactly what
# this proc did when it first passed the lib straight to MarkObjModified.
#
# So the design is resolved the way MarkPageNameChanged always resolved it - by
# name, through the session, which returns a properly typed DboDesign* - and only
# that handle is ever given a NULL.  The lib is still used for the fallback rename,
# where a real page pointer is the argument and DboLib::RenameObject(DboBaseObject*,
# CString&) is a genuine overload.
#
# Returns 1 when the page came back with the new name, 0 otherwise - including
# when it was already marked, which is not a failure and not a second '*'.
proc ::mUtilMenu::StarPageObj { pSch pPage {pDsnPath ""} } {
    variable mPageNameMaxChars

    set lPageName [::mUtilMenu::CStr $pPage GetName]
    if { [string index $lPageName 0] eq "*" } {
        ::mUtilMenu::Trace "page $lPageName is already marked - left alone"
        return 0
    }

    set lNew "*$lPageName"

    # THE 32-CHARACTER LIMIT.  Capture's database refuses an object name longer
    # than this, and the refusal does not happen at Rename time - DboSchematic::
    # Rename takes the long name, the '*' appears in the Project Manager, and
    # everything looks fine until the design is written, where it comes back as
    #
    #   ERROR(ORCAP-1650): Unable to save '...DSN'.
    #   ERROR(ORDBDLL-1096): Invalid object name. Perhaps greater than 32 characters.
    #
    # One page over the limit makes the WHOLE DESIGN unsaveable, which is how this
    # presented: a compare that ran perfectly and then would not save, with
    # nothing in the compare's own output to say why.
    #
    # So the star is not added when it would not fit.  The page keeps its markers
    # - those are what the run is for - and is reported as changed-but-not-renamed,
    # which is the bucket that already exists for a page that could not be starred.
    # Renaming it to something shorter is not on: the name is the user's, and a
    # marker tool has no business truncating it.
    if { [string length $lNew] > $mPageNameMaxChars } {
        ::mUtilMenu::Trace "page \"$lPageName\" is [string length $lPageName] characters - starring it would make [string length $lNew], over the $mPageNameMaxChars limit; left unrenamed so the design stays saveable"
        return 0
    }

    set lCStr [DboTclHelper_sMakeCString $lNew]

    # The containing lib, as a DboLib handle - fine for RenameObject, never for
    # MarkModified NULL.  See above.
    set lLib ""
    catch { set lLib [$pPage GetContainingLib] }

    # The same lib as a DboDesign, via the session.  DboLib::GetName is the
    # design's file name, which is the string GetDesignAndSchematics is keyed on.
    set lDesign ""
    if { $lLib ne "" && $lLib ne "NULL" } {
        set lPath [::mUtilMenu::CStr $lLib GetName]
        if { $lPath ne "" } {
            catch { set lDesign [::mUtilMenu::FindDesign $lPath] }
        }
    }

    set lDone 0
    if { $pSch ne "" && $pSch ne "NULL" } {
        set lDone [::mUtilMenu::DboSet $pSch Rename $pPage $lCStr]
    }
    if { !$lDone && $lLib ne "" && $lLib ne "NULL" } {
        # Fall back to the design-level rename, same (pObj newName) shape.
        ::mUtilMenu::DboSet $lLib RenameObject $pPage $lCStr
    }

    # Believe the page, not the return code: whatever the DboState said, the name
    # either changed or it did not.
    if { [::mUtilMenu::CStr $pPage GetName] ne $lNew } {
        ::mUtilMenu::Trace "rename failed: $lPageName -> $lNew"
        return 0
    }

    # All three levels - page, schematic, design.  This used to be written out
    # here and nowhere else, which is exactly how the marker path came to mark
    # only the page and leave designs that would not save; it is one shared proc
    # now.  MarkPageDirty repeats the lib -> design lookup this proc already did
    # above for the rename, which is one cheap call against the two of them
    # never drifting apart again.
    ::mUtilMenu::MarkPageDirty $pPage $pSch $pDsnPath
    return 1
}

#-----------------------------------------------------------------------------
# Every design the session is holding - i.e. what is open
#
# DboSession::NewDesignsIter, which is how both of Cadence's own "do this to all
# the open designs" procs do it:
#
#   capDemoBrowser/tcl/OrHandlerCapDemoBrowser.tcl:288   GetOpenDesigns
#   capFindAndReplace/tcl/capDesignUtil.tcl:961          reevaluateAllPagesOfOpenDesigns
#
#   DboSession_NewDesignsIter        self status   -> DboSessionDesignsIter
#   DboSessionDesignsIter_NextDesign self status   -> DboDesign
#   delete_DboSessionDesignsIter
#
# Returns rows of {path rootName modified}.  path is DboLib::GetName, which for a
# design is its .DSN file - the same getter DesignPathOf uses.
#
# Two things this is NOT:
#
#   It is not a list of .OPJ files.  A .OPJ is Capture's project wrapper and not a
#   DBO object at all, so nothing in the database can be asked about it - Appendix
#   A has GetActiveOpjName() (the active one only) and CloseProject(), and that is
#   the whole of it.  capDemoBrowser guesses the .OPJ by string-replacing .DSN,
#   which is right for most projects and wrong for any that does not keep the two
#   side by side under the same name.  This does not guess; callers that want to
#   can, and DumpSessionDesigns shows the guess next to the real answer for the
#   active project so it can be checked.
#
#   It is not exactly "what PROJECT_MANAGER_VIEW has open" either.  A design put
#   into the session by Tcl - which is what Open(pPath) does, and what Schematic
#   Compare does to both of its .DSNs - is in here whether or not it has a Project
#   Manager window.  There is no way to ask the database about windows.
#
# Deliberately does NOT reuse lStatus for GetName's return value.  The shipped
# capDesignUtil.tcl:965 does (set lStatus [$lDesign GetName $lName]) and thereby
# overwrites the DboState the iterator is being driven with; it works by luck.
# CStr keeps the two apart.
#-----------------------------------------------------------------------------
proc ::mUtilMenu::SessionDesigns { } {
    set lOut [list]

    if { [catch {
        set lSession $::DboSession_s_pDboSession
        DboSession -this $lSession
        set lStatus [DboState]

        set lIter   [$lSession NewDesignsIter $lStatus]
        set lDesign [$lIter NextDesign $lStatus]
        while { $lDesign != "NULL" } {
            set lPath [::mUtilMenu::CStr $lDesign GetName]
            set lRoot [::mUtilMenu::CStr $lDesign GetRootName]
            set lMod  "?"
            catch { set lMod [$lDesign IsModified $lStatus] }
            if { $lPath ne "" } {
                lappend lOut [list $lPath $lRoot $lMod]
            }
            set lDesign [$lIter NextDesign $lStatus]
        }
        catch { delete_DboSessionDesignsIter $lIter }
        catch { $lStatus -delete }
    } lErr] } {
        ::mUtilMenu::Trace "SessionDesigns failed -> $lErr"
    }
    return $lOut
}

# The same list, printed.  Run in the Command Window:
#   ::mUtilMenu::DumpSessionDesigns
proc ::mUtilMenu::DumpSessionDesigns { } {
    set lRows [::mUtilMenu::SessionDesigns]

    ::mUtilMenu::Out [::mUtilMenu::Banner "--- designs in the session ---"]
    set lN 0
    foreach lRow $lRows {
        incr lN
        set lPath [lindex $lRow 0]
        ::mUtilMenu::Out [format "  %d  %s" $lN $lPath]
        ::mUtilMenu::Out [format "     root=%s  modified=%s  opj(guessed)=%s" \
            [::mUtilMenu::OrDash [lindex $lRow 1]] [lindex $lRow 2] \
            "[file rootname $lPath].opj"]
    }
    ::mUtilMenu::Out "  ($lN design(s))"

    set lOpj "ERROR / not available"
    catch { set lOpj [GetActiveOpjName] }
    ::mUtilMenu::Out "  GetActiveOpjName -> [::mUtilMenu::OrDash $lOpj]"
    set lInfo [::mUtilMenu::ActivePMDesignInfo]
    ::mUtilMenu::Out "  active PM design -> [::mUtilMenu::OrDash [lindex $lInfo 0]]"
    return $lN
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
# Let Capture's own UI run for a moment.
#
# "update" drains what is already queued; the timed wait after it is for work
# Capture posts to ITSELF - a Project Manager tree rebuild is not finished when
# the call that triggered it returns, and nothing in Tcl can be asked to wait for
# it.  vwait on an "after" is the only portable way to let the application have
# the processor without returning to the caller.
#
# Everything is caught.  This is a courtesy to the UI, never a dependency: a
# Capture build where Tk is not loaded, or where "update" is unhappy, must still
# run the compare.
proc ::mUtilMenu::SettleUI { {pMs -1} } {
    variable mPMSettleMs

    if { $pMs < 0 } {
        set pMs $mPMSettleMs
    }
    catch { update }
    if { $pMs > 0 } {
        catch {
            set lTok "::mUtilMenu::settle[clock clicks]"
            after $pMs [list set $lTok 1]
            vwait $lTok
            unset -nocomplain $lTok
        }
    }
    catch { update }
    return 1
}

# What the Project Manager currently has selected, "" when nothing.
#
# The point of having this separate is that SelectPMItem NOT THROWING is not the
# same as the selection having taken.  RestorePMSelection believed the return
# code for three versions and reported success on runs where the tree rebuild
# afterwards had wiped the selection straight back out again.
proc ::mUtilMenu::PMSelection { } {
    set lItems ""
    catch { set lItems [GetSelectedPMItems] }
    return [string trim $lItems]
}

# Put the Project Manager back on one design and give it a selected item again.
#
# See the block comment above for why the selection disappears in the first
# place.  Two things this does that the first version did not:
#
#   VERIFY   after each SelectPMItem, ask GetSelectedPMItems what is actually
#            selected.  Empty means it did not take, whatever SelectPMItem
#            returned.
#   RETRY    the whole candidate list, up to mPMSelectTries times, with the UI
#            allowed to run in between.  A selection wiped by a rebuild that was
#            still queued is put back by the next round, once that rebuild has
#            landed.
#
# Ordered so the cheapest and most likely candidate goes first.  All three are
# tried every round rather than remembering which one worked: the tree the round
# before last was selecting in may have been rebuilt since.
proc ::mUtilMenu::RestorePMSelection { pFile } {
    variable mRestorePM
    variable mPMSelectItem
    variable mPMSelectTries

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

    for { set lTry 1 } { $lTry <= $mPMSelectTries } { incr lTry } {
        # Before the first attempt as well as between rounds: the renames that
        # made this necessary were the last thing to happen.
        ::mUtilMenu::SettleUI

        foreach lName $lNames {
            if { [catch { SelectPMItem $lName } lErr] } {
                ::mUtilMenu::Trace "SelectPMItem \"$lName\" failed -> $lErr"
                continue
            }
            set lSel [::mUtilMenu::PMSelection]
            if { $lSel eq "" } {
                ::mUtilMenu::Trace "SelectPMItem \"$lName\" returned without error but nothing is selected (try $lTry)"
                continue
            }
            ::mUtilMenu::Trace "PM selection restored on [file tail $pFile] via \"$lName\" -> $lSel (try $lTry)"
            return 1
        }
    }

    # Said out loud, not just traced: a design nobody can save is worth a line in
    # the same window the run just finished printing to.
    ::mUtilMenu::Out "  *** could not give [file tail $pFile] a Project Manager selection after $mPMSelectTries tries"
    ::mUtilMenu::Out "      File > Save will refuse it - click the design once in the Project Manager, then Save"
    return 0
}

# PageComp / Refcompare - both need exactly one ticked page per column and differ
# only in which dump sections run.
#
# PageComp is the full compare: the four sections diffed as New/Remove, the two
# netlists put through net_compare_rule1..4, and the two parts lists put through
# net_compare_rule5 (a pin unconnected on (N) that was on a net on (O)).  Rule5
# rides on the same dump - it needs no section of its own, only the pin detail
# element 10 of a part row already carries.
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
# A third is turned ON for the (N) dump only, when mRule5 is on: mPinPosAll, so
# every pin of that page reports its connection point and not only the pins that
# are on a net.  Rule5 marks pins that are on NO net, so without it every finding
# would come back with nowhere to put its stub.  (O) does not need it - all rule5
# asks of that side is whether the pin had a net, which the dump always carries -
# and that is why it is raised per side rather than round the pair: on a whole
# design AllPagesComp would otherwise pay the extra pin walk twice per page.
#
# All three are restored on the way out of an error as well, or the first pair
# that failed would leave the Command Window mute for the rest of the session.
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
    variable mMarkPinSegs
    variable mQuiet
    variable mTimeCompare
    variable mPinPosAll
    variable mRule5

    set mMarkSegs    [list]
    set mMarkBoxes   [list]
    set mMarkPinSegs [list]

    set lSaveQuiet  $mQuiet
    set lSaveTime   $mTimeCompare
    set lSavePinPos $mPinPosAll
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

        # The extra pin-position read, (N) only - see the block comment.
        if { [::mUtilMenu::NeedAllPinPos] } {
            set mPinPosAll 1
        }
        set lDataN [::mUtilMenu::DumpPageInfo $pFileB \
                        [lindex $pPairB 0] [lindex $pPairB 1] $lWhat]
        set mPinPosAll $lSavePinPos

        ::mUtilMenu::DumpFullCompare $lDataO $lDataN

        # After the compare, never before - drawing first would put the marker lines
        # into (N)'s own dump, where they would come back as differences of their own.
        set lDrawn [::mUtilMenu::DrawMarkersOnPage $pFileB $pPairB]
    } lErr]

    set mQuiet       $lSaveQuiet
    set mTimeCompare $lSaveTime
    set mPinPosAll   $lSavePinPos

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
#
# The two side labels are parameters and not literals so the backward pass of
# (N)(O)BOTH COMP can print "(O) ... (N) ..." and keep the same rule: the page
# that was MARKED leads the line, whichever side that was this time.
proc ::mUtilMenu::PairDoneLine { pPairMarked pPairOther pResult \
                                 {pMarked "(N)"} {pOther "(O)"} } {
    ::mUtilMenu::Out [format "  %s %-32s %s %-32s Page comparison finished - %s" \
              $pMarked [lindex $pPairMarked 1] \
              $pOther  [lindex $pPairOther 1] \
              $pResult]
}

# ::BOTH_N_O_COMP back to a plain 0 or 1, the way ChkItemsNormalize does it for
# the Schematic Check boxes: it is a bare global anyone can set from the Command
# Window, and Tk's checkbutton wants a value it can compare against onvalue.
# Anything unset counts as ticked - that is the default the variable is created
# with, and a run that quietly did half the work would be worse than one that did
# all of it.
proc ::mUtilMenu::BothCompNormalize { } {
    set lOn 1
    if { [info exists ::BOTH_N_O_COMP] } {
        if { [catch { set lOn [expr { $::BOTH_N_O_COMP ? 1 : 0 }] }] } {
            set lOn 1
        }
    }
    set ::BOTH_N_O_COMP $lOn
    return $lOn
}

# AllPagesComp - the SAME compare PageComp does, over every mapped page pair at
# once instead of the one pair the checkboxes point at.  Same DumpPageInfo walk,
# same DumpFullCompare, same net_compare_rule1..5 - the four netlist rules' pink
# DASH lines, rule5's pink stubs at pins that came loose, and the turquoise
# rectangles: ComparePagePair is PageComp's own path with the report window and the
# printing taken off it, so a rule added there is a rule added here.
#
# BOTH DIRECTIONS.  With the selector's "(N)(O)BOTH COMP" box ticked - the
# default, ::BOTH_N_O_COMP - every pair is run through ComparePagePair twice:
#
#   forward   (O) is the baseline, (N) is marked and renamed '*'.  What
#             AllPagesComp has always done.
#   backward  the two arguments swapped, so (N) is the baseline and (O) is the
#             page that gets the pink lines and the turquoise rectangles.  (O) is
#             NOT renamed - see ::BOTH_N_O_COMP for why the '*' stays on one side.
#
# The backward pass is not a repeat of the forward one.  Only the NEW side of a
# diff is ever drawn, because a Remove has nowhere on the marked page to go - so
# a part only (O) has, a net only (O) has, a pin (O) wired and (N) did not, all
# of them draw nothing at all in the forward pass and are exactly what the
# backward pass puts on (O)'s page.
#
# Markers drawn by the first pass cannot leak into the second one's dump: they
# are DboGraphicLineInst and DboGraphicBoxInst, and all four collectors walk
# nets, wires, part instances and net symbols - none of them looks at graphics.
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

    set lPairs    0
    set lChanged  [list]
    set lFailed   [list]
    set lUnnamed  [list]
    set lChangedO [list]
    set lFailedO  [list]

    set lBoth [::mUtilMenu::BothCompNormalize]

    # One header, then one line per pair - the two file names are said once here
    # rather than on every line, which is what keeps the per-pair line short enough
    # to read down.
    ::mUtilMenu::Out "AllPagesComp - (N) [file tail $mPagesFileB]   (O) [file tail $mPagesFileA]"
    if { $lBoth } {
        ::mUtilMenu::Out "  (N)(O)BOTH COMP is on - every pair is compared both ways; only (N) is renamed"
    }

    set lErr ""
    if { [catch {
        foreach lLink $mPageLinks {
            set lPairA [lindex $mPagesA [lindex $lLink 0]]
            set lPairB [lindex $mPagesB [lindex $lLink 1]]
            if { [llength $lPairA] == 0 || [llength $lPairB] == 0 } {
                continue
            }
            incr lPairs

            # BOTH COMPARES FIRST, THE RENAME AFTER THEM, THE PRINTING LAST.
            #
            # The rename cannot sit where it reads most naturally - at the end of
            # the forward pass - because it invalidates the very name the backward
            # pass is about to look (N)'s page up by.  MarkPageNameChanged turns
            # "P02. VCORE" into "*P02. VCORE" in the database, while mPagesB still
            # holds the name the selector was built with, so the backward pass
            # went looking for a page that no longer answered to it:
            #
            #   (N) P02. VCORE  (O) P02. VCORE  ... 6 marker(s), '*' added
            #   (O) P02. VCORE  (N) P02. VCORE  ... FAILED - page not found: W980_WS / P02. VCORE
            #
            # and every pair the forward pass found a difference on - exactly the
            # pairs worth comparing the other way - failed backwards.  Renaming
            # after both compares fixes it at the source rather than patching the
            # stale name up afterwards: the '*' is a flag put on at the END of a
            # pair's work, and nothing should be looked up by name after it.
            #
            # -1 is the failure sentinel throughout; ComparePagePair returns a
            # marker count, which is never negative.
            set lDrawn  -1
            set lErrFwd ""
            if { [catch { set lDrawn [::mUtilMenu::ComparePagePair \
                              $mPagesFileA $lPairA $mPagesFileB $lPairB] } lErrFwd] } {
                set lDrawn -1
            }

            # Backward - the same call with the two designs the other way round,
            # so (N) is the baseline and (O) is what gets drawn on.  No rename:
            # the '*' belongs to (N) alone, see ::BOTH_N_O_COMP.
            #
            # Run even when the forward pass failed.  The two are separate
            # compares and a forward failure is often one-sided - a page that
            # would not open for marking still compares perfectly well as a
            # baseline - so skipping it here would lose findings for no reason.
            set lDrawnO -1
            set lErrBwd ""
            if { $lBoth } {
                if { [catch { set lDrawnO [::mUtilMenu::ComparePagePair \
                                  $mPagesFileB $lPairB $mPagesFileA $lPairA] } lErrBwd] } {
                    set lDrawnO -1
                }
            }

            set lRenamed 0
            if { $lDrawn > 0 } {
                lappend lChanged [lindex $lPairB 1]
                if { [catch { set lRenamed [::mUtilMenu::MarkPageNameChanged \
                                  $mPagesFileB $lPairB] } lPairErr] } {
                    set lRenamed 0
                    ::mUtilMenu::Trace "rename failed on [::mUtilMenu::PageLabel $lPairB] -> $lPairErr"
                }
                if { !$lRenamed } {
                    lappend lUnnamed [lindex $lPairB 1]
                }
            }

            # (N)'s line first and (O)'s under it, whatever order the work
            # happened in - the run is read as a column and the two lines of a
            # pair belong together.
            if { $lDrawn < 0 } {
                lappend lFailed "[::mUtilMenu::PageLabel $lPairB] ($lErrFwd)"
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "FAILED - $lErrFwd"
            } elseif { $lDrawn == 0 } {
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "no difference"
            } elseif { !$lRenamed } {
                ::mUtilMenu::PairDoneLine $lPairB $lPairA \
                    "$lDrawn marker(s), NOT renamed - already marked, or starring the name would pass the $::mUtilMenu::mPageNameMaxChars-character limit"
            } else {
                ::mUtilMenu::PairDoneLine $lPairB $lPairA "$lDrawn marker(s), '*' added"
            }

            if { !$lBoth } {
                continue
            }
            if { $lDrawnO < 0 } {
                lappend lFailedO "[::mUtilMenu::PageLabel $lPairA] ($lErrBwd)"
                ::mUtilMenu::PairDoneLine $lPairA $lPairB "FAILED - $lErrBwd" "(O)" "(N)"
            } elseif { $lDrawnO == 0 } {
                ::mUtilMenu::PairDoneLine $lPairA $lPairB "no difference" "(O)" "(N)"
            } else {
                lappend lChangedO [lindex $lPairA 1]
                ::mUtilMenu::PairDoneLine $lPairA $lPairB \
                    "$lDrawnO marker(s), page name left alone" "(O)" "(N)"
            }
        }
    } lErr] } {
        ::mUtilMenu::Trace "AllPagesComp failed -> $lErr"
        catch { capDisplayMessageBox "AllPagesComp failed:\n\n$lErr" \
                                     "Schematic Compare - AllPagesComp" }
        return
    }

    ::mUtilMenu::Out "AllPagesComp - $lPairs page pair(s) compared, [llength $lChanged] (N) page(s) marked"
    if { $lBoth } {
        ::mUtilMenu::Out "AllPagesComp - backward pass: [llength $lChangedO] (O) page(s) marked, none renamed"
    }

    catch { ZoomRedraw }

    # One line per page changed, so the box says which ones and not just how many.
    set lMsg "AllPagesComp - [file tail $mPagesFileB]\n\n"
    append lMsg "$lPairs page pair(s) compared.\n"
    append lMsg "[llength $lChanged] page(s) changed and renamed with a leading '*'."
    if { [llength $lChanged] > 0 } {
        append lMsg "\n\n[join $lChanged "\n"]"
    }
    if { [llength $lUnnamed] > 0 } {
        append lMsg "\n\nChanged but NOT renamed ([llength $lUnnamed]) - already marked, or starring the name would pass Capture's $::mUtilMenu::mPageNameMaxChars-character object-name limit:\n[join $lUnnamed "\n"]"
    }
    if { [llength $lFailed] > 0 } {
        append lMsg "\n\nCould not be compared ([llength $lFailed]):\n[join $lFailed "\n"]"
    }

    # The backward pass gets its own block, headed by the other design's name:
    # everything above this point is about (N), and running the two lists together
    # would leave no way to tell which file a page name belongs to.
    if { $lBoth } {
        append lMsg "\n\n(N)(O)BOTH COMP - marked on (O) [file tail $mPagesFileA],"
        append lMsg " page names left alone:\n"
        append lMsg "[llength $lChangedO] page(s) marked."
        if { [llength $lChangedO] > 0 } {
            append lMsg "\n\n[join $lChangedO "\n"]"
        }
        if { [llength $lFailedO] > 0 } {
            append lMsg "\n\nCould not be compared ([llength $lFailedO]):\n[join $lFailedO "\n"]"
        }
    }

    if { [llength $lChanged] > 0 || [llength $lChangedO] > 0 } {
        append lMsg "\n\nFile > Save to keep the markers and the new page names"
        if { [llength $lChangedO] > 0 } {
            append lMsg " - BOTH designs were drawn on, so save both"
        }
        append lMsg "."
    }

    ::mUtilMenu::Trace "AllPagesComp: $lPairs pair(s), [llength $lChanged] (N) changed, [llength $lFailed] failed; backward [llength $lChangedO] (O) changed, [llength $lFailedO] failed"

    # Modal - so the selector goes away once the count has been read, not before.
    catch { capDisplayMessageBox $lMsg "Schematic Compare - AllPagesComp" }
    ::mUtilMenu::ClosePageSelector

    # Last, once every Tk window of ours is gone: renaming the pages emptied the
    # Project Manager's selection, and File > Save / Save As are both greyed out
    # until it has one again.  See RestorePMSelection.
    #
    # BOTH DESIGNS, each on its own count.  This used to run for (N) only and to
    # test (N)'s list, which was right while (N) was the only side ever written
    # to.  Since (N)(O)BOTH COMP the backward pass draws on (O) as well, so (O)
    # needs the same treatment - and a run where only the backward pass found
    # anything used to restore nothing at all, because the test was on $lChanged.
    #
    # (O) first so that (N) ends up the active Project Manager when both were
    # touched: RestorePMSelection brings the design it is given to the front, and
    # (N) is the side that was renamed and the one to look at next.
    #
    # SettleUI between them, and once before either: every rename in the loop
    # above queued a Project Manager tree rebuild, and a rebuild landing after a
    # SelectPMItem takes the selection away again.  RestorePMSelection settles and
    # retries on its own as well - this is the coarse one, so the two designs do
    # not restore into the middle of each other's rebuilds.
    ::mUtilMenu::SettleUI
    if { [llength $lChangedO] > 0 } {
        ::mUtilMenu::RestorePMSelection $mPagesFileA
        ::mUtilMenu::SettleUI
    }
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
    variable mMarkPinSegs
    variable mPinPosAll
    variable mRule5

    # Cleared here as well as in DumpFullCompare, so a Refcompare - or a compare
    # that bails out below - cannot leave the previous Compare's findings sitting
    # there for DrawCompareMarkerLine to draw a second time.
    set mMarkSegs    [list]
    set mMarkBoxes   [list]
    set mMarkPinSegs [list]

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
    #
    # (N) is dumped with mPinPosAll raised when net_compare_rule5 is on and this
    # is the full compare: rule5 marks pins that are on NO net, and without it
    # those are exactly the pins the dump leaves without a position.  It shows in
    # the printout too - (N)'s pin table gives coordinates for its NC pins where
    # (O)'s prints "-" - and that asymmetry is the cheaper half of the trade:
    # rule5 never asks (O) for a position, so making the two dumps look alike
    # would double a pin walk for a column nothing reads.
    set lEmpty [list parts [list] symbols [list] nets [list] buses [list]]
    set lData  [list]
    set lSavePinPos $mPinPosAll
    foreach lSide [list [list $mPagesFileA $lPairA O] [list $mPagesFileB $lPairB N]] {
        set lFile [lindex $lSide 0]
        set lPair [lindex $lSide 1]
        set lRows $lEmpty
        ::mUtilMenu::Out "================================================================"
        ::mUtilMenu::Out "([lindex $lSide 2]) [file tail $lFile] - [::mUtilMenu::PageLabel $lPair]"
        ::mUtilMenu::Out "================================================================"

        set mPinPosAll $lSavePinPos
        if { $pMode eq "full" && [lindex $lSide 2] eq "N" \
             && [::mUtilMenu::NeedAllPinPos] } {
            set mPinPosAll 1
        }
        if { [catch { set lRows [::mUtilMenu::DumpPageInfo $lFile \
                          [lindex $lPair 0] [lindex $lPair 1] $pWhat] } lErr] } {
            ::mUtilMenu::Trace "page dump failed for $lFile -> $lErr"
        }
        set mPinPosAll $lSavePinPos

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
            set lTitle "Compare (Parts / Symbols / Nets / Buses, net_compare_rule1..5)"
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

    # Not a legend entry - a setting, sitting on the legend row because that is
    # the only strip of window between the columns and the buttons and the row is
    # otherwise half empty.  It belongs to AllPagesComp; see ::BOTH_N_O_COMP for
    # what it does and why only (N) is ever renamed either way.
    #
    # Bound straight to the bare global, so the box and the variable cannot
    # disagree and the Command Window can set it before the selector is opened.
    ::mUtilMenu::BothCompNormalize
    checkbutton $lLegend.both -anchor w -text "(N)(O)BOTH COMP" \
        -variable ::BOTH_N_O_COMP -onvalue 1 -offvalue 0
    pack $lLegend.same -side left -padx {2 12}
    pack $lLegend.near -side left -padx {0 12}
    pack $lLegend.none -side left
    pack $lLegend.both -side left -padx {16 0}
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
    ::mUtilMenu::WarnMissingOpj [list $lA $lB]

    # Both designs are in the session now - let the user pick pages.
    if { [catch { ::mUtilMenu::ShowPageSelector $lA $lB } lErr] } {
        ::mUtilMenu::Trace "page selector failed -> $lErr"
        catch { capDisplayMessageBox "Could not build the page list:\n\n$lErr" \
                                     "Schematic Compare" }
    }
}

# Say so, up front, when a .DSN about to be compared has no .opj beside it.
#
# Schematic Compare is given .DSN paths and opens them with Open(pPath), so a
# design whose project file is missing still opens, still compares and still gets
# drawn on - and then File > Save fails with
#
#   ERROR(ORCAP-1650): Unable to save '...DSN'
#
# because Save goes through the project and there is no project.  Save As works,
# which is what makes it look like a tool bug rather than a missing file.  It cost
# two machines and a morning to find; one line at the start is cheaper.
#
# Only the .opj sitting beside the .DSN under the same root name is looked for.
# That is Capture's own convention and the one GetActiveOpjName reports back -
# and when it is absent, the name GetActiveOpjName gives is a path to a file that
# does not exist, which is the tell.  A project genuinely kept somewhere else
# would be a false alarm here; it says "check", not "this is broken".
#
# A warning and not a refusal: the compare itself is perfectly valid without a
# project, the dumps and the report are worth having, and Save As keeps the
# markers.  Returns the list of .DSN files that had no .opj.
proc ::mUtilMenu::WarnMissingOpj { pFiles } {
    set lBad [list]
    foreach lFile $pFiles {
        if { $lFile eq "" } {
            continue
        }
        set lOpj "[file rootname [file normalize $lFile]].opj"
        if { ![file exists $lOpj] } {
            lappend lBad $lFile
        }
    }
    if { [llength $lBad] == 0 } {
        return $lBad
    }

    ::mUtilMenu::Out "----------------------------------------------------------------"
    ::mUtilMenu::Out "Schematic Compare - NO .opj FOUND for [llength $lBad] of the two designs"
    foreach lFile $lBad {
        ::mUtilMenu::Out "    [file tail $lFile]   (expected [file tail [file rootname $lFile]].opj beside it)"
    }
    ::mUtilMenu::Out "  The compare will run and the markers will be drawn, but File > Save"
    ::mUtilMenu::Out "  on that design will fail with ERROR(ORCAP-1650) - Save goes through the"
    ::mUtilMenu::Out "  project and there is none.  Use File > Save As, or open the design from"
    ::mUtilMenu::Out "  its .opj instead of its .DSN."
    ::mUtilMenu::Out "----------------------------------------------------------------"
    ::mUtilMenu::Trace "no .opj for: [join $lBad {, }]"
    return $lBad
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

    # The two design fields are NOT cleared here.  They are namespace variables and
    # keep whatever the last compare of this session used, which is what makes
    # "compare the same pair again, one page further on" a matter of reopening the
    # dialog and pressing Execute.
    #
    # The one thing that does empty them is moving the Default Folder - see
    # BrowseInitDir.  A leftover path only goes stale when the work moves
    # somewhere else, so that is where it is thrown away, rather than on every
    # open.
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

#-----------------------------------------------------------------------------
# Close Page - shut every open schematic page, across every open design
#
# This used to be capCloseChildViewsExceptCurrent(): "Close All Tabs But This",
# which leaves whichever page happens to be on top open.  What is wanted is every
# page of every .DSN / .OPJ the Project Manager has open, and Appendix A has the
# command for it - p.141, right next to the one that was already being used:
#
#   capCloseChildViews(pExclude = None)     pExclude: CDocument *
#   capCloseChildViews()
#
# and both forms are real: Cadence's own capAutoLoad/capCloseAllChildWindows.tcl:8
# registers the no-argument form as the handler for OnCloseChildWindows, which is
# Window > Close All.
#
# The catch is what "child view" covers.  The Project Manager is itself an MDI
# child of the Capture frame, so "close all child views" may well take the project
# tree down with the pages - and closing the Project Manager closes the project.
# That is not what "close the pages" is supposed to mean, so it is excluded:
# GetActivePM() (p.130) returns the COrCapturePMDoc, and that is what pExclude
# wants.  If it turns out the Project Manager was never in scope, the argument
# names a document that was not going to be closed anyway and nothing changes -
# so this is the safe move whichever way the command actually behaves.
#
# But pExclude protects ONE document, and GetActivePM only ever names the ACTIVE
# project's.  With two projects open that closed the other one's Project Manager
# along with the pages.  The answer is to do it a project at a time -
# ClosePagesPerDesign, over what SessionDesigns reports - which is also the
# closest this API gets to "close the pages one by one": Appendix A has no
# per-page close at all, only whole-frame ones.
#
# mClosePageMode picks between the four - see the variable.
#
# EnableAllWindowCloseMenu() (p.136) is Capture's own "is there anything to close"
# test, the same one the shipped script wires to OnUpdateCloseChildWindows.  It is
# only used for the Command Window line here - the close is attempted either way,
# because a getter that will not answer is not a reason to refuse to do the work.
#-----------------------------------------------------------------------------
# Which no-argument getter to ask for the document to EXCLUDE, in order.
#
# The first version of this passed GetActivePM() and every single call failed with
#
#   No matching function for overloaded 'capCloseChildViews'
#
# which is SWIG saying the argument is the wrong type, not that the command is
# missing.  capCloseChildViews declares
#
#   in method 'capCloseChildViews', argument 1 of type 'CDocument *'
#
# and Capture.exe registers _p_CDocument, _p_COrCapturePMDoc and _p_COrSchematicDoc
# as three SEPARATE swig types with no conversion between them.  GetActivePM
# returns a COrCapturePMDoc, so it can never be that argument - the pointer is
# right, the type tag on it is not.  Every design therefore fell through to
# capCloseChildViewsExceptCurrent, which is why one page stayed open on each.
#
# The two below return a CDocument, which is the declared type:
#
#   capGetActivePMDoc      no arguments - the Project Manager's document
#   capGetActiveDocument   no arguments - whatever document is on top (p.136)
#
# WHAT DumpCloseApi ACTUALLY REPORTED, on a real 17.4 with a project open:
#
#   capGetActiveDocument          _c01b5536..._p_COrCapturePMDoc
#   capGetActivePMDoc             _e0395536..._p_COrCapturePMDoc
#   capGetActiveView              _c00b9a56..._p_CView
#   capGetActiveWindow            _10b06f9a..._p_CWnd
#   capGetActiveDocumentPathName  (empty)
#   capGetActiveDocumentTitle     W980_WS : P05. SA PHASE 1-2 80A*a1
#   GetActivePM                   _e0395536..._p_COrCapturePMDoc
#
# Three things fall out of that, and together they kill the exclude approach:
#
#   BOTH getters hand back a COrCapturePMDoc.  capGetActivePMDoc is not a
#   differently-typed wrapper - it is literally the same pointer as GetActivePM.
#   Nothing reachable from Tcl produces the _p_CDocument that pExclude wants, so
#   capCloseChildViews' one-argument form cannot be called from Tcl at all.
#
#   The active DOCUMENT is the project while the active VIEW is a page - the
#   title is "W980_WS : P05...", a page, and capGetActiveView is a separate CView.
#   So Capture keeps ONE COrCapturePMDoc per project and every page window is a
#   view of it.
#
#   Which means the exclude form was the wrong idea even if it had compiled:
#   "close all child views except this document's" applied to the project's own
#   document would have closed nothing.  The pages ARE that document's views.
#
# So the pages are closed with the NO-ARGUMENT capCloseChildViews - Cadence's own
# capCloseAllChildWindows.tcl:8 registers exactly that as Window > Close All - and
# the Project Manager is protected the other way round: if closing the views takes
# the project tree with it, ClosePagesPerDesign opens the project again
# afterwards.  Restoring something is safe in a way that guessing a pointer type
# is not, and Open on a project that never closed just activates it.
#
# The exclude getters are still tried first, from mClosePageDocGetters, because
# they cost one failed call and a different Capture build may register the cast.
#
# One close call, by name.  Returns 1 if the command ran, 0 if it refused.
#
# "exclude" is NOT in the default route list any more, and the reason is worth
# keeping: it does not throw, it succeeds and does nothing.  A real run reported
#
#   1/3  W890D8-2L2T.DSN - 200 round(s), pages MAY REMAIN (exclude)
#
# 200 rounds of a call that returned success and closed not one window, on all
# three projects.  That is the document model doing exactly what was written down
# two procs up and then not acted on: every page window is a VIEW of the
# project's own COrCapturePMDoc, so "close all child views except this
# document's" excludes the very views it was supposed to close.  Trying it first
# meant the working routes were never reached.
#
# It is left reachable through mClosePageRoutes because a Capture that maps the
# argument to something else would want it - but it has to be last, and it is not
# in the default.
proc ::mUtilMenu::ClosePagesVia { pRoute } {
    variable mClosePageDocGetters

    switch -- $pRoute {
        all {
            return [expr { ![catch { capCloseChildViews }] }]
        }
        exceptcurrent {
            return [expr { ![catch { capCloseChildViewsExceptCurrent }] }]
        }
        exclude {
            foreach lGetter $mClosePageDocGetters {
                if { [info commands $lGetter] eq "" } {
                    continue
                }
                set lDoc ""
                if { [catch { set lDoc [$lGetter] }] || $lDoc eq "" || $lDoc eq "NULL" } {
                    continue
                }
                if { ![catch { capCloseChildViews $lDoc }] } {
                    return 1
                }
            }
            return 0
        }
    }
    return 0
}

# Something that changes when a window actually closes.
#
# EnableAllWindowCloseMenu is a BOOLEAN - it says "something is still open", not
# how much - so it cannot tell "closing one page per call" apart from "doing
# nothing at all".  That is what let the exclude route spin 200 times.
#
# capGetActiveDocumentTitle moves whenever the active view does, and closing a
# window always changes which view is active, so a title that has not moved after
# a close means nothing closed.  On the real machine it reads
# "W980_WS : P05. SA PHASE 1-2 80A*a1" - the design and the page - which is
# exactly the granularity needed.
proc ::mUtilMenu::CloseProgressToken { } {
    set lT ""
    catch { set lT [capGetActiveDocumentTitle] }
    if { $lT eq "" } {
        catch { set lT [capGetActiveDocumentPathName] }
    }
    return $lT
}

# Capture's own "is there still a window that Window > Close All would close?" -
# EnableAllWindowCloseMenu(), PDF p.136, the same test the shipped
# capCloseAllChildWindows.tcl wires to OnUpdateCloseChildWindows.
#
# 1 = something left, 0 = nothing left, -1 = the command would not answer, which
# is not the same as "nothing left" and must not be treated as it.
proc ::mUtilMenu::AnythingLeftToClose { } {
    if { [info commands EnableAllWindowCloseMenu] eq "" } {
        return -1
    }
    set lR ""
    if { [catch { set lR [EnableAllWindowCloseMenu] }] } {
        return -1
    }
    if { $lR eq "" } {
        return -1
    }
    if { [catch { set lR [expr { $lR ? 1 : 0 }] }] } {
        return -1
    }
    return $lR
}

# Close this project's pages: keep calling, and when a route stops achieving
# anything, move to the next route rather than repeating it.
#
# Two things had to be true before this worked, and the first run only had one of
# them:
#
#   repeat.  One close call does not empty the frame - the first symptom was
#            "each project only lost a single page".
#   NOTICE WHEN NOTHING IS HAPPENING.  Repeating alone turned that into 200
#            rounds of a no-op, because the route being repeated was the exclude
#            one, which reports success and closes nothing.
#
# So every round is measured.  Progress is the active-document title moving (see
# CloseProgressToken) or the enabler dropping to 0; mClosePageStallRounds rounds
# with neither means this route is not working here, and the next one is tried.
# Routes come from mClosePageRoutes.
#
# Ways out, all reported:
#
#   the enabler says nothing is left   -> done, the normal exit
#   every route stalled                -> stop, pages may remain, and the trace
#                                         names which routes were tried
#   the enabler will not answer (-1)   -> one pass per route, because without it
#                                         "done" cannot be established at all
#   mClosePageMaxRounds reached        -> stop rather than hang Capture
#
# Returns {rounds route done}: done is 1 only when Capture itself said there was
# nothing left.  A run that stalled or hit the cap is NOT done.
proc ::mUtilMenu::ClosePagesUntilDone { } {
    variable mClosePageMaxRounds
    variable mClosePageStallRounds
    variable mClosePageRoutes

    set lRounds 0
    set lRoute  ""
    set lDone   0
    set lTried  [list]

    foreach lR $mClosePageRoutes {
        set lStall 0

        while { $lRounds < $mClosePageMaxRounds } {
            set lLeft [::mUtilMenu::AnythingLeftToClose]
            if { $lLeft == 0 } {
                set lDone 1
                break
            }

            set lBefore [::mUtilMenu::CloseProgressToken]

            incr lRounds
            if { ![::mUtilMenu::ClosePagesVia $lR] } {
                # The command refused outright - no point repeating it.
                break
            }
            set lRoute $lR
            if { [lsearch -exact $lTried $lR] == -1 } {
                lappend lTried $lR
            }

            set lAfter [::mUtilMenu::AnythingLeftToClose]
            if { $lAfter == 0 } {
                set lDone 1
                break
            }
            if { $lAfter == -1 } {
                ::mUtilMenu::Trace "  EnableAllWindowCloseMenu will not answer - one pass of '$lR' only"
                break
            }

            # Still something open.  Did this round actually shut anything?
            if { [::mUtilMenu::CloseProgressToken] eq $lBefore } {
                incr lStall
                if { $lStall >= $mClosePageStallRounds } {
                    ::mUtilMenu::Trace "  '$lR' changed nothing in $lStall round(s) - trying the next route"
                    break
                }
            } else {
                set lStall 0
            }
        }

        if { $lDone || $lRounds >= $mClosePageMaxRounds } {
            break
        }
    }

    if { !$lDone } {
        if { $lRounds >= $mClosePageMaxRounds } {
            ::mUtilMenu::Trace "  stopped after $mClosePageMaxRounds round(s) - something is still reported as open"
        } else {
            ::mUtilMenu::Trace "  no route emptied this project - tried: [join $lTried {, }]"
        }
    }
    return [list $lRounds $lRoute $lDone]
}

# Kept as the name the allbutpm mode is written in terms of.
proc ::mUtilMenu::ClosePagesKeepingPM { } {
    return [lindex [::mUtilMenu::ClosePagesUntilDone] 2]
}

# What the window/document half of the API actually offers in THIS Capture, and
# what the no-argument getters hand back right now.  Run it in the Command Window
# with a project open:
#
#   ::mUtilMenu::DumpCloseApi
#
# It only reads - nothing here closes anything - and it is the quickest way to
# settle the two questions the documentation does not answer: which getters exist,
# and whether the document they return is the Project Manager or a page.
proc ::mUtilMenu::DumpCloseApi { } {
    ::mUtilMenu::Out [::mUtilMenu::Banner "--- close/window commands present ---"]
    foreach c { capCloseChildViews capCloseChildViewsExceptCurrent \
                capCloseAllTabs capCloseDocument capClosePM \
                capGetActiveDocument capGetActivePMDoc capGetActiveSchematicDoc \
                capGetPMDocList capGetActiveView capGetActiveWindow \
                capGetActiveDocumentPathName capGetActiveDocumentTitle \
                GetActivePM EnableAllWindowCloseMenu Open } {
        ::mUtilMenu::Out [format "  %-32s %s" $c \
            [expr { [info commands $c] eq "" ? "MISSING" : "ok" }]]
    }

    ::mUtilMenu::Out "--- what the no-argument getters return now ---"
    foreach c { capGetActiveDocument capGetActivePMDoc capGetActiveSchematicDoc \
                capGetPMDocList capGetActiveView capGetActiveWindow \
                capGetActiveDocumentPathName capGetActiveDocumentTitle \
                GetActivePM } {
        if { [info commands $c] eq "" } {
            continue
        }
        set lR "ERROR"
        catch { set lR [$c] }
        ::mUtilMenu::Out [format "  %-32s %s" $c $lR]
    }
    return
}

# One design at a time: bring its Project Manager to the front, then close that
# project's pages, keeping its Project Manager.  Then put the original project
# back in front.
#
# Why a loop at all, when capCloseChildViews sounds like it closes everything.
# Because nothing says whether "child views" means the whole MDI frame or the
# views of the ACTIVE document, and pExclude taking a single CDocument leans
# towards the second.  The loop is correct either way: if it is frame-wide the
# first pass does the job and the rest find nothing left to close, and if it is
# per-document the loop is the only thing that would ever reach the second
# project.  Doing it this way also fixes what the single-shot version could not -
# with two projects open, GetActivePM only ever protected one of them, and the
# other project's Project Manager was closed along with the pages.
#
# Open(pPath) on a design already in the session is what activates it - the same
# call, for the same reason, as RestorePMSelection.
proc ::mUtilMenu::ClosePagesPerDesign { } {
    variable mClosePageReopen

    set lRows [::mUtilMenu::SessionDesigns]
    if { [llength $lRows] == 0 } {
        ::mUtilMenu::Out "  no design in the session - closing the active project's pages only"
        ::mUtilMenu::ClosePagesOfActiveProject
        return 1
    }

    # Where to come back to.  Taken before anything is activated, because after
    # the loop the active project is whichever one happened to be last.
    set lBack [lindex [::mUtilMenu::ActivePMDesignInfo] 0]

    # A modified design whose project window gets closed is a design Capture will
    # ask about.  Said up front, because an unexpected "save changes?" in the
    # middle of a batch is the sort of thing that gets answered wrongly.
    set lDirty [list]
    foreach lRow $lRows {
        if { [lindex $lRow 2] eq "1" } {
            lappend lDirty [file tail [lindex $lRow 0]]
        }
    }
    if { [llength $lDirty] > 0 } {
        ::mUtilMenu::Out "  unsaved: [join $lDirty {, }] - Capture may ask about these"
    }

    # The ACTIVE project goes first, and without an Open in front of it.  Two
    # reasons, and the first is the one that matters:
    #
    #   Its pages are the ones on screen right now.  Whatever "current" means to
    #   capCloseChildViewsExceptCurrent - the one route that is not guesswork -
    #   it means them.  Closing them before anything is activated is the one pass
    #   that cannot be got wrong.
    #
    #   Open on the already-active project would be a no-op with a chance of a
    #   side effect, and no chance of a benefit.
    #
    # GetActiveOpjName is printed alongside, because it is the only thing that
    # names the .OPJ rather than the .DSN, and seeing it move down the list is
    # how the loop is checked from outside.
    set lOrder [list]
    foreach lRow $lRows {
        if { $lBack ne "" && [file normalize [lindex $lRow 0]] eq [file normalize $lBack] } {
            set lOrder [linsert $lOrder 0 $lRow]
        } else {
            lappend lOrder $lRow
        }
    }

    ::mUtilMenu::Out "  [llength $lOrder] design(s) open:"
    set lN     0
    set lOK    0
    foreach lRow $lOrder {
        incr lN
        set lPath [lindex $lRow 0]

        # Everything after the first has to be brought to the front before its
        # pages are its pages.
        if { $lN > 1 } {
            if { [catch { Open [file normalize $lPath] } lErr] } {
                ::mUtilMenu::Out [format "    %d/%d  %s - could not activate (%s), skipped" \
                    $lN [llength $lOrder] [file tail $lPath] $lErr]
                continue
            }
        }

        set lOpj ""
        catch { set lOpj [GetActiveOpjName] }

        set lRes    [::mUtilMenu::ClosePagesUntilDone]
        set lRounds [lindex $lRes 0]
        set lRoute  [lindex $lRes 1]
        set lDone   [lindex $lRes 2]

        set lNote ""
        if { $lOpj ne "" } {
            set lNote "   opj: [file tail $lOpj]"
        }

        if { $lDone && $lRounds == 0 } {
            incr lOK
            ::mUtilMenu::Out [format "    %d/%d  %s - nothing was open%s" \
                $lN [llength $lOrder] [file tail $lPath] $lNote]
        } elseif { $lDone } {
            incr lOK
            ::mUtilMenu::Out [format "    %d/%d  %s - closed in %d round(s) (%s)%s" \
                $lN [llength $lOrder] [file tail $lPath] $lRounds $lRoute $lNote]
        } else {
            ::mUtilMenu::Out [format "    %d/%d  %s - %d round(s), pages MAY REMAIN (%s)%s" \
                $lN [llength $lOrder] [file tail $lPath] $lRounds \
                [::mUtilMenu::OrDash $lRoute] $lNote]
        }
    }

    # Put every project back.  This is what makes the no-argument close safe to
    # use: whether or not it took the project tree down with the pages, opening
    # the design again restores it, and on a project that never closed Open just
    # activates it.  The one that was active before goes LAST so it ends up in
    # front, which is also why it is not skipped here.
    if { $mClosePageReopen } {
        foreach lRow $lRows {
            if { [catch { Open [file normalize [lindex $lRow 0]] } lErr] } {
                ::mUtilMenu::Trace "  could not reopen [file tail [lindex $lRow 0]] -> $lErr"
            }
        }
    }
    if { $lBack ne "" } {
        if { [catch { Open [file normalize $lBack] } lErr] } {
            ::mUtilMenu::Trace "  could not reactivate [file tail $lBack] -> $lErr"
        }
    }

    # The last word, from Capture rather than from this loop's own bookkeeping:
    # after everything, is anything still reported as open?  If the reopen pass
    # just put the project windows back this will say 1, which is correct and
    # expected - those are the Project Managers, not pages.
    set lLeft [::mUtilMenu::AnythingLeftToClose]
    ::mUtilMenu::Out [format "  (%d of %d design(s) closed cleanly; EnableAllWindowCloseMenu now %s)" \
        $lOK $lN [expr { $lLeft < 0 ? "unknown" : $lLeft }]]
    return 1
}

proc ::mUtilMenu::DoClosePage { pVia } {
    variable mClosePageMode

    ::mUtilMenu::Trace "Close Page callback reached via $pVia - mode '$mClosePageMode'"

    set lAny "?"
    catch { set lAny [EnableAllWindowCloseMenu] }
    ::mUtilMenu::Trace "  EnableAllWindowCloseMenu -> $lAny"

    switch -- $mClosePageMode {
        exceptcurrent {
            if { [catch { capCloseChildViewsExceptCurrent } lErr] } {
                ::mUtilMenu::Trace "Close Page failed -> $lErr"
            }
            return true
        }
        all {
            if { [catch { capCloseChildViews } lErr] } {
                ::mUtilMenu::Trace "Close Page failed -> $lErr"
            }
            return true
        }
        allbutpm {
            ::mUtilMenu::ClosePagesKeepingPM
            return true
        }
    }

    # perdesign, and anything unrecognised - the one that covers every open
    # project is the right default for a typo as well.
    ::mUtilMenu::ClosePagesPerDesign
    return true
}

#=============================================================================
# Schematic Check
#
# What the Project Manager has selected decides the SCOPE, and the check itself is
# the same whatever the scope is:
#
#   a page              that page
#   a schematic         every page in it
#   the Design (.DSN)   every page of every schematic in it
#   the Project (.OPJ)  the design the PM has open, then as above
#
# Per page: the grid block, the full page dump, then
# Search_Missing_connection_onGrid over what the dump collected.  Anything it
# finds is drawn on the page (MarkGridFindings) and the page name gets a '*' in
# front of it (StarPageObj), so the PM tree shows which pages need opening.
#
# The narrowest selected kind wins, so clicking a page inside a selected design
# means that page.  The message box is one table, one line per page - the grid
# blocks and the dumps stay in the Command Window where there is room for them.
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

# The Dbo class a Project Manager item is, when the item came back as a SWIG
# pointer rather than as a label - "DboPage", "DboDesign", "DboSchematic" - or ""
# when it is a plain label like "Design Resources".
#
# GetSelectedPMItems mixes the two: a folder node has nothing behind it but its
# name, while a node that IS a database object comes back as that object's SWIG
# handle, which looks like
#
#     _30f4a1b200000000_p_DboPage
#
# The trailing class name is the whole point - it says what was selected without
# any guessing at labels.  Both the _p_ form and a bare _<Class> tail are matched,
# since only the first is guaranteed by SWIG's own naming.
proc ::mUtilMenu::PMItemDboClass { pLabel } {
    if { [regexp {_p_(Dbo[A-Za-z0-9]+)$} $pLabel -> lClass] } {
        return $lClass
    }
    if { [regexp {_(Dbo[A-Za-z0-9]+)$} $pLabel -> lClass] } {
        return $lClass
    }
    return ""
}

# Make a SWIG handle callable as a Tcl command.  "<Class> -this <ptr>" is the
# same two-line idiom GetDesignPages uses on $::DboSession_s_pDboSession - it
# registers the pointer string as a command, it does not construct anything.
# Returns 1 when $pHandle can be sent methods afterwards.
proc ::mUtilMenu::BindDboHandle { pHandle pClass } {
    if { [llength [info commands $pHandle]] } {
        return 1
    }
    if { [catch { $pClass -this $pHandle } lErr] } {
        ::mUtilMenu::Trace "$pClass -this $pHandle failed -> $lErr"
        return 0
    }
    return 1
}

# One int-returning DboPage getter that takes a DboState, as "" when it will not
# answer.  Every property in the grid block is optional as far as this report is
# concerned - a page that cannot say whether its border is printed is still worth
# reporting the rest of.
proc ::mUtilMenu::PageIntProp { pPage pGetter pStatus } {
    set lVal ""
    if { [catch { set lVal [$pPage $pGetter $pStatus] }] } {
        return ""
    }
    return $lVal
}

proc ::mUtilMenu::YesNo { pVal } {
    if { $pVal eq "" }  { return "-"   }
    if { $pVal }        { return "Yes" }
    return "No"
}

# What Capture's Schematic Page Properties > Grid Reference tab holds for one
# page, as a dict.  Every one of these is a documented DboPage getter taking a
# DboState (Appendix A, the DboPage class):
#
#   GetHorizontalLabelCount / Width / IsChar / IsVisible / IsAscending
#   GetVerticalLabelCount   / Width / IsChar / IsVisible / IsAscending
#   GetGridRefDisplayed / GetGridRefPrinted / GetANSIGridRefs
#   GetBorderDisplayed  / GetBorderPrinted
#   GetTitleBlockDisplayed / GetTitleBlockPrinted
#
# IsChar 1 = the labels are letters (A, B, C), 0 = numbers.  Width is the label
# band, in doc units.
#
# The page's size and granularity are collected with it.  They are not on the
# Grid Reference tab, but "what is this page's grid" has a second reading - the
# coordinate grid the dump prints in - and GetPhysicalGranularity is the answer
# to that one.  Both are cheap, so both are reported rather than picking a
# reading of the question.
#
# GetIsMetric and GetDocUnitsPerInch come along for the same reason: granularity
# alone does not say what it is granularity OF.  Both are DboPage's own and both
# take no arguments (GetIsMetric is used exactly this way in the shipped
# capCustomSamples/capCustomizePage.tcl:61).
proc ::mUtilMenu::CollectPageGrid { pPage } {
    set lStatus [DboState]
    set lOut    [dict create]

    foreach lAxis { Horizontal Vertical } {
        foreach lProp { Count Width IsChar IsVisible IsAscending } {
            dict set lOut "$lAxis$lProp" \
                [::mUtilMenu::PageIntProp $pPage "Get${lAxis}Label${lProp}" $lStatus]
        }
    }
    foreach lProp { GridRefDisplayed GridRefPrinted ANSIGridRefs \
                    BorderDisplayed BorderPrinted \
                    TitleBlockDisplayed TitleBlockPrinted } {
        dict set lOut $lProp [::mUtilMenu::PageIntProp $pPage "Get$lProp" $lStatus]
    }

    # Page size: a name ("A", "B", "C") plus the drawable extent as a CSize.
    dict set lOut SizeName [::mUtilMenu::CStr $pPage GetSizeName]
    dict set lOut SizeX ""
    dict set lOut SizeY ""
    catch {
        set lSize [$pPage GetSize $lStatus]
        dict set lOut SizeX [DboTclHelper_sGetCSizeX $lSize]
        dict set lOut SizeY [DboTclHelper_sGetCSizeY $lSize]
    }

    dict set lOut Granularity ""
    catch { dict set lOut Granularity [$pPage GetPhysicalGranularity] }

    # Which unit the granularity above is PER.  GetPhysicalGranularity is doc
    # units per user unit and the user unit is the millimetre on a metric page, so
    # without these two the same "100" means two different physical sizes and
    # every coordinate below it reads wrong by a factor of 25.4.
    dict set lOut IsMetric ""
    catch { dict set lOut IsMetric [$pPage GetIsMetric] }
    dict set lOut DocPerInch ""
    catch { dict set lOut DocPerInch [$pPage GetDocUnitsPerInch] }

    catch { $lStatus -delete }
    return $lOut
}

# "5  (alphabetic, ascending, shown, width 100)" for one axis of the grid.
proc ::mUtilMenu::GridAxisStr { pGrid pAxis } {
    set lCount [dict get $pGrid "${pAxis}Count"]
    set lBits  [list]
    lappend lBits [expr { [dict get $pGrid "${pAxis}IsChar"] eq ""   ? "-" :
                          [dict get $pGrid "${pAxis}IsChar"]         ? "alphabetic" : "numeric" }]
    lappend lBits [expr { [dict get $pGrid "${pAxis}IsAscending"] eq "" ? "-" :
                          [dict get $pGrid "${pAxis}IsAscending"]       ? "ascending" : "descending" }]
    lappend lBits [expr { [dict get $pGrid "${pAxis}IsVisible"] eq ""   ? "-" :
                          [dict get $pGrid "${pAxis}IsVisible"]         ? "shown" : "hidden" }]
    lappend lBits "width [::mUtilMenu::OrDash [dict get $pGrid "${pAxis}Width"]]"
    return "[::mUtilMenu::OrDash $lCount]  ([join $lBits {, }])"
}

# The grid block, printed to the Command Window and returned as the same text so
# the message box can show it too - one source, so the two can never disagree.
proc ::mUtilMenu::FormatPageGrid { pGrid } {
    variable mCoordMode
    variable mCoordDecimals

    set lTxt ""
    append lTxt "Grid Reference:\n"
    append lTxt "  Horizontal:  [::mUtilMenu::GridAxisStr $pGrid Horizontal]\n"
    append lTxt "  Vertical:    [::mUtilMenu::GridAxisStr $pGrid Vertical]\n"
    append lTxt "  Displayed:   [::mUtilMenu::YesNo [dict get $pGrid GridRefDisplayed]]"
    append lTxt "      Printed:  [::mUtilMenu::YesNo [dict get $pGrid GridRefPrinted]]\n"
    append lTxt "  ANSI refs:   [::mUtilMenu::YesNo [dict get $pGrid ANSIGridRefs]]\n"
    append lTxt "\n"
    append lTxt "Border:        [::mUtilMenu::YesNo [dict get $pGrid BorderDisplayed]]"
    append lTxt "      Printed:  [::mUtilMenu::YesNo [dict get $pGrid BorderPrinted]]\n"
    append lTxt "Title block:   [::mUtilMenu::YesNo [dict get $pGrid TitleBlockDisplayed]]"
    append lTxt "      Printed:  [::mUtilMenu::YesNo [dict get $pGrid TitleBlockPrinted]]\n"
    append lTxt "\n"

    set lSize [::mUtilMenu::OrDash [dict get $pGrid SizeName]]
    if { [dict get $pGrid SizeX] ne "" } {
        append lSize "  ([dict get $pGrid SizeX] x [dict get $pGrid SizeY] doc units)"
    }
    append lTxt "Page size:     $lSize\n"

    # Which unit system the page is in, before the granularity that is measured in
    # it: a bare "Granularity: 100" is ambiguous, and the ambiguity is a factor of
    # 25.4 wide.
    set lMetric [dict get $pGrid IsMetric]
    set lUnit   "in"
    if { $lMetric eq "" } {
        append lTxt "Page units:    inches (GetIsMetric would not answer - Capture's default)\n"
    } elseif { $lMetric } {
        set lUnit "mm"
        append lTxt "Page units:    mm (metric page)\n"
    } else {
        append lTxt "Page units:    inches\n"
    }

    append lTxt "Granularity:   [::mUtilMenu::OrDash [dict get $pGrid Granularity]] doc units per $lUnit"
    if { [dict get $pGrid DocPerInch] ne "" } {
        append lTxt "   ([dict get $pGrid DocPerInch] per inch)"
    }
    append lTxt "\n"

    # The one line that says how to read every coordinate below it.  The database
    # holds doc integers; the dump divides them by the granularity above unless
    # mCoordMode says "doc", and saying so here means nobody has to work out from
    # the numbers whether a 15240 is 15240 or 152.40.  The worked example is built
    # with the same Coord the columns use, so it shows the real precision rather
    # than a second opinion about it.
    set lGran [dict get $pGrid Granularity]
    if { $mCoordMode ne "doc" && $lGran ne "" && $lGran > 0 } {
        # The example is 6 inches in whatever the page's unit is, so it lands on a
        # round 6.00 on an inch page and on 152.40 on a metric one.
        set lPerUnit 1
        if { $lUnit eq "mm" } {
            set lPerUnit 25.4
        }
        set lEg [expr { round(6.0 * $lPerUnit * $lGran) }]
        append lTxt "Dump units:    $lUnit - doc units / $lGran"
        append lTxt "  (e.g. $lEg doc = [format "%.${mCoordDecimals}f" [expr { double($lEg) / $lGran }]] $lUnit)\n"
    } else {
        append lTxt "Dump units:    raw doc units\n"
    }
    return [string trimright $lTxt "\n"]
}

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
# {design|project|page|schematic|other <value>}.
#
# The second element is a full PATH for the label-matched kinds, and the SWIG
# HANDLE for the ones recognised by class - the caller tells them apart by the
# kind, and PagesForPMItem / DesignPathOf are what turn a handle back into
# something to print.
#
# Everything is compared lowercased: Windows paths are case-insensitive and the
# PM does not necessarily show a file in the case it is stored in.
proc ::mUtilMenu::ClassifyPMItem { pLabel pDsn pDsnRoot pOpj } {
    set lLabel [string trim $pLabel]
    if { $lLabel eq "" } {
        return [list other ""]
    }

    # A SWIG handle says what it is outright - no label guessing needed.  The
    # second element is the handle itself rather than a path: the object is what
    # the caller wants for these, and a page has no path of its own anyway.
    set lClass [::mUtilMenu::PMItemDboClass $lLabel]
    if { $lClass ne "" } {
        switch -- $lClass {
            DboPage      { return [list page      $lLabel] }
            DboSchematic { return [list schematic $lLabel] }
            DboDesign    { return [list design    $lLabel] }
        }
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

# The .DSN path behind a DboDesign / DboLib handle, or "" - DboLib::GetName is
# the design's file name, the same string GetDesignAndSchematics is keyed on.
proc ::mUtilMenu::DesignPathOf { pHandle } {
    if { ![::mUtilMenu::BindDboHandle $pHandle DboDesign] } {
        return ""
    }
    return [::mUtilMenu::CStr $pHandle GetName]
}

#-----------------------------------------------------------------------------
# Search_Missing_connection_onGrid - the wires that nearly touch
#
# The question: a net ends half a grid step away from a pin.  On screen at 50%
# zoom the two look joined, the schematic reads as connected, and it is not - the
# wire was drawn with the snap grid off, so it stopped just short.  Capture
# reports nothing, because as far as the database is concerned nothing is wrong:
# the pin is simply on no net.
#
# So the geometry has to be measured, and this is what measures it.  Every net
# endpoint is checked against every OTHER endpoint on the page - part pins,
# off-page / power / port symbols, bus wire ends, and other nets' wire ends - and
# a pair is reported when it is not already on the same net and the gap between
# the two is smaller than min_dis.  A gap of exactly nothing is a finding against
# another net and not against anything else; see DISTANCE below.
#
# WHAT COUNTS AS A PAIR
#
#   driver      one endpoint of one net wire.  Nets drive the search because a
#               missing connection is always a net that failed to reach something
#               - two pins half a step apart are just two pins.
#   candidate   any endpoint on the page, the driver's own net excluded.
#
#   The exclusion is by NET, not by object: a pin sitting on net A and a wire end
#   of net A are the same electrical point, and reporting the pair would report
#   every correctly wired pin on the page.  A pin on no net gets a group of its
#   own, so an unwired pin near a net is always a candidate - that is the case
#   this whole proc exists for.
#
# DISTANCE
#
#   Manhattan, |dx| + |dy|, in doc units, no square root and no floating point in
#   the inner loop.  It is never smaller than the true distance, so nothing real
#   is missed; it is up to twice as large on a diagonal, which at these
#   tolerances means a diagonal near-miss is reported slightly less eagerly than
#   an orthogonal one.  Schematic wires are orthogonal.
#
#   Whether a zero gap counts depends on what the net endpoint is near, because
#   "two things in the same place" means two different things:
#
#     vs a pin, a symbol or a bus end   0 < distance < min_dis.  A zero gap here
#         is the endpoint TOUCHING the pin or the bus, which is exactly what a
#         made connection looks like - so it is tallied and passed over, not
#         reported.
#     vs another net's endpoint         0 <= distance < min_dis.  A zero gap here
#         is two SEPARATE net objects at one point.  Capture merges wires that
#         meet into a single net, so two nets that did not merge while sharing a
#         point is an anomaly worth seeing - reported, and flagged in the listing.
#
# SPEED
#
#   A page with 3000 pins and 1000 net endpoints is 3 million pair tests done the
#   obvious way, which in Tcl is minutes.  So the endpoints go into a hash of
#   min_dis-sized square buckets first, and each driver only looks in its own
#   bucket and the eight around it: with a bucket exactly min_dis across, any
#   point within |dx|+|dy| < min_dis is also within min_dis on each axis on its
#   own, so it cannot be further away than one bucket.  Nothing is missed and the
#   work goes from N x M to roughly N.
#
#-----------------------------------------------------------------------------

# min_dis -> the doc-unit integer the search compares against.  Three modes, see
# mGridMinDisUnits:
#
#   grid  min_dis x mGridStepInch x GetDocUnitsPerInch.  Grid steps are the only
#         unit that means the same thing on an inch page and a metric one, which
#         is the whole reason this mode is the default: 0.5 is half a step at
#         0.05 in on one page and 1.27 mm on the other, and both of those are
#         "half a step".  GetDocUnitsPerInch is DboPage's per-INCH scale, not
#         GetPhysicalGranularity, which is per USER unit and would hand back
#         millimetres on a metric page.
#   user  min_dis x GetPhysicalGranularity, the same conversion and the same
#         fallback as MarkOffsetDoc.  The units are the page's own.
#   doc   min_dis as it stands.
#
# A getter that will not answer degrades one mode at a time - grid falls back to
# user, user falls back to doc - and says so in the Command Window rather than
# silently searching at the wrong scale.
proc ::mUtilMenu::GridTolDoc { pPage pMinDis } {
    variable mGridMinDisUnits
    variable mGridStepInch

    if { $mGridMinDisUnits eq "doc" || $pPage eq "" } {
        return [expr { round($pMinDis) }]
    }

    if { $mGridMinDisUnits eq "grid" } {
        set lDpi 0
        catch { set lDpi [$pPage GetDocUnitsPerInch] }
        if { $lDpi > 0 } {
            return [expr { round(double($pMinDis) * $mGridStepInch * $lDpi) }]
        }
        ::mUtilMenu::Trace "GetDocUnitsPerInch gave nothing on this page - taking min_dis as user units"
    }

    set lGran 0
    catch { set lGran [$pPage GetPhysicalGranularity] }
    if { $lGran <= 0 } {
        ::mUtilMenu::Trace "no physical granularity on this page - taking min_dis as doc units"
        return [expr { round($pMinDis) }]
    }
    return [expr { round(double($pMinDis) * $lGran) }]
}

# Every endpoint on the page that a net could have been meant to reach, out of
# the dict DumpPageInfoOn returned - no second walk of the database, the dump
# already read all of it.  One record per endpoint:
#
#   0 kind    NET / PIN / OFFPAGE / GLOBAL / PORT / BUS / BUNDLE
#   1 label   what to call it in the report - net name, "U12.A10", "GND"
#   2 group   the electrical identity two endpoints have to DIFFER in to be worth
#             reporting: "net:<name>" for anything sitting on a net, and a key of
#             its own ("pin:U12.A10", "sym#7", "net#3") for anything that is not.
#             Unnamed nets get an index rather than a shared "net:", so two of
#             them are not silently treated as the same net.
#   3 x
#   4 y       doc units, straight off the object - the printed columns are rounded
#             for printing and cannot be measured with.
#   5 note    the connection phrase the dump prints for it, "" for a wire end
#   6 box     the bounding box, in doc units, of the OBJECT this endpoint belongs
#             to - the pin's whole part, the symbol, or {} for a wire end (a wire
#             has no area, so MarkGridFindings pads a square round the point
#             instead).  Only the marker drawing reads it.
#
# Everything here is an ENDPOINT, never a mid-wire point: Capture joins a wire to
# a pin at the pin's hot spot and to another wire at a wire end, so those are the
# only places a connection was supposed to happen.
proc ::mUtilMenu::GridEndpoints { pDict } {
    set lOut [list]

    set lIdx 0
    foreach lRow [dict get $pDict nets] {
        incr lIdx
        set lGrp [::mUtilMenu::GridNetGroup $lIdx [lindex $lRow 0]]
        set lLbl [::mUtilMenu::OrDash [lindex $lRow 0]]
        # Element 2 is the wires as {x1 y1 x2 y2} doc quads - see CollectPageNets.
        foreach lSeg [lindex $lRow 2] {
            if { [llength $lSeg] != 4 } {
                continue
            }
            lappend lOut [list NET $lLbl $lGrp [lindex $lSeg 0] [lindex $lSeg 1] "" ""]
            lappend lOut [list NET $lLbl $lGrp [lindex $lSeg 2] [lindex $lSeg 3] "" ""]
        }
    }

    # Part pins.  Element 4 of a pin record is the hot spot, which is only filled
    # in when the position was asked for - Schematic Check raises mPinPosAll so
    # that every pin has one, wired or not.  See CheckOnePage.
    foreach lRow [dict get $pDict parts] {
        set lRef [::mUtilMenu::OrDash [lindex $lRow 0]]
        foreach lPin [lindex $lRow 10] {
            set lPos [lindex $lPin 4]
            if { [llength $lPos] != 2 } {
                continue
            }
            set lNum [lindex $lPin 1]
            if { $lNum eq "" } {
                set lNum [::mUtilMenu::OrDash [lindex $lPin 0]]
            }
            set lNet [lindex $lPin 3]
            set lGrp "pin:$lRef.$lNum"
            if { $lNet ne "" } {
                set lGrp "net:$lNet"
            }
            # Element 9 of the part row is the PART's bounding box, which is what
            # gets boxed on the page: a box round one pin would be a few doc units
            # across and invisible at any zoom that shows a whole page.
            lappend lOut [list PIN "$lRef.$lNum" $lGrp \
                               [lindex $lPos 0] [lindex $lPos 1] \
                               [::mUtilMenu::PinConnStr $lPin] \
                               [lindex $lRow 9]]
        }
    }

    # Off-page connectors, power symbols and ports.
    #
    # Element 6 is the CONNECTION POINT - SymHotSpotDoc, {x y route} - and it is
    # what a distance to a net endpoint has to be measured from.  Element 4 is
    # GetLocation, the placement origin, which for a left-pointing off-page
    # connector is the top-left corner of its bounding box: measuring from there
    # was out by half a symbol, and at min_dis = half a grid step that is enough
    # to lose a real near miss.  Element 4 stays as the fallback for a symbol
    # SymHotSpotDoc could not answer for, and for a dict collected before element
    # 6 existed.
    set lIdx 0
    foreach lRow [dict get $pDict symbols] {
        incr lIdx
        set lPos [lindex $lRow 6]
        if { [llength $lPos] < 2 } {
            set lPos [lindex $lRow 4]
        }
        if { [llength $lPos] < 2 } {
            continue
        }
        set lNet [lindex $lRow 3]
        set lGrp "sym#$lIdx"
        if { $lNet ne "" } {
            set lGrp "net:$lNet"
        }
        lappend lOut [list [lindex $lRow 0] [::mUtilMenu::OrDash [lindex $lRow 1]] $lGrp \
                           [lindex $lPos 0] [lindex $lPos 1] \
                           [::mUtilMenu::ConnStr 0 $lNet] \
                           [lindex $lRow 5]]
    }

    # Bus and bundle wires.  A bus is not a net, so both its ends share a group of
    # their own and a net wire that stops short of the bus is a reportable pair.
    foreach lRow [dict get $pDict buses] {
        set lSeg [lindex $lRow 3]
        if { [llength $lSeg] != 4 } {
            continue
        }
        set lKind [lindex $lRow 1]
        set lLbl  [lindex $lRow 0]
        set lGrp  "bus:$lKind $lLbl"
        lappend lOut [list $lKind $lLbl $lGrp [lindex $lSeg 0] [lindex $lSeg 1] "" ""]
        lappend lOut [list $lKind $lLbl $lGrp [lindex $lSeg 2] [lindex $lSeg 3] "" ""]
    }

    return $lOut
}

# One net's group key.  Two callers derive it - GridEndpoints for the search and
# GridNetSegIndex for the drawing - and they have to agree exactly or the drawing
# would look up a net the search never named, so the rule lives here rather than
# twice.
#
# An unnamed net is keyed by its position in the rows instead of by a shared
# "net:", so two nameless nets are not taken for one net.  Both callers walk the
# same list in the same order, so the same net gets the same index in both.
proc ::mUtilMenu::GridNetGroup { pIdx pName } {
    if { $pName ne "" } {
        return "net:$pName"
    }
    return "net#$pIdx"
}

# group key -> that net's wires, as {x1 y1 x2 y2} doc quads.  This is what turns
# "net VCCM_EN_A1 is 0.25 mm from N44011769" into a set of lines to draw: a
# finding names the two nets, and every wire of each has to be marked, not just
# the one wire whose end was measured.
proc ::mUtilMenu::GridNetSegIndex { pDict pArrName } {
    upvar 1 $pArrName lArr

    set lIdx 0
    foreach lRow [dict get $pDict nets] {
        incr lIdx
        set lArr([::mUtilMenu::GridNetGroup $lIdx [lindex $lRow 0]]) [lindex $lRow 2]
    }
}

# "若端點重覆記得排除" - the same endpoint really is read many times over: every
# wire of a net ends where the next one starts, so a net with 12 wires hands in
# the same junction up to a dozen times, and each copy would be a pair test and a
# duplicate line in the report.
#
# Identity is kind + label + group + position, NOT position alone: two pins of the
# same net can legitimately sit on one point (a pin landing exactly on another
# part's pin), and those are two different objects worth naming separately.
proc ::mUtilMenu::GridDedupPoints { pPts } {
    set lOut [list]
    array set lSeen {}
    foreach lP $pPts {
        set lKey [join [lrange $lP 0 4] "|"]
        if { [info exists lSeen($lKey)] } {
            continue
        }
        set lSeen($lKey) 1
        lappend lOut $lP
    }
    return $lOut
}

# One endpoint, as the string that identifies it in a pair key: what it is, what
# it is called and where it is.  The GROUP is deliberately left out - a pair is
# the same pair however the two sides were grouped.
proc ::mUtilMenu::GridPtKey { pPt } {
    return "[lindex $pPt 0]|[lindex $pPt 1]|[lindex $pPt 3],[lindex $pPt 4]"
}

# One endpoint's position in the units the rest of the dump prints - the doc
# integers are what the search measures with, the report is what a human reads.
proc ::mUtilMenu::GridPtStr { pPage pPt } {
    return "([::mUtilMenu::Coord $pPage [lindex $pPt 3]],[::mUtilMenu::Coord $pPage [lindex $pPt 4]])"
}

# The search itself.  Prints its findings and returns them as a list of
# {distDoc driverPoint otherPoint}, nearest pair first.
#
# pPage is only used to convert units - min_dis into doc units on the way in, doc
# distances back into inches on the way out.  pDict is what DumpPageInfoOn
# returned for that same page.
#
# min_dis is in the units mGridMinDisUnits names, "user" (inches) by default, so
# 0.05 means half of Capture's 0.1 in snap grid, and on a granularity-100 page
# that is 5 doc units.  The default is mGridMinDis's value - see the variable for
# why half a grid step is the tolerance worth checking at.
proc ::mUtilMenu::Search_Missing_connection_onGrid { pPage pDict {min_dis 0.05} } {
    variable mGridMinDisUnits
    variable mGridListMax

    # Two clocks: lT0 always runs, so the section can print its own cost even
    # with mTimeCompare off, and TimeNow/TimeMark feed the phase breakdown
    # CheckOnePage prints under "timing - Schematic Check".
    set lT0   [clock milliseconds]
    set lTAll [::mUtilMenu::TimeNow]

    set lThr [::mUtilMenu::GridTolDoc $pPage $min_dis]

    ::mUtilMenu::Out "  Missing connections - net endpoints nearly touching something they are not on"
    ::mUtilMenu::Out "    vs pin / symbol / bus end:  0 <  gap < min_dis   (gap 0 = touching = connected)"
    ::mUtilMenu::Out "    vs another net's endpoint:  0 <= gap < min_dis   (gap 0 = two nets that did not merge)"
    if { $lThr <= 0 } {
        ::mUtilMenu::Out "    min_dis $min_dis $mGridMinDisUnits came to $lThr doc units - nothing can be closer than that, skipped"
        return [list]
    }

    set lT   [::mUtilMenu::TimeNow]
    set lPts [::mUtilMenu::GridDedupPoints [::mUtilMenu::GridEndpoints $pDict]]
    ::mUtilMenu::TimeMark "gridcheck endpoints" $lT

    # Bucket index, one bucket per min_dis square.  Tcl's integer / floors toward
    # negative infinity, so a negative coordinate buckets the same way a positive
    # one does and the 3x3 neighbourhood below stays correct either side of zero.
    set lT [::mUtilMenu::TimeNow]
    array set lBkt {}
    foreach lP $lPts {
        set lKey "[expr { [lindex $lP 3] / $lThr }],[expr { [lindex $lP 4] / $lThr }]"
        lappend lBkt($lKey) $lP
    }
    ::mUtilMenu::TimeMark "gridcheck index" $lT

    set lT        [::mUtilMenu::TimeNow]
    set lFinds    [list]
    set lDrivers  0
    set lTests    0
    set lTouching 0
    array set lPairSeen {}
    array set lDrvSeen  {}

    foreach lP $lPts {
        if { [lindex $lP 0] ne "NET" } {
            continue
        }
        # One net's endpoint, once - a junction shared by three wires of the same
        # net is one place on the page, not three.
        set lDKey "[lindex $lP 2]|[lindex $lP 3]|[lindex $lP 4]"
        if { [info exists lDrvSeen($lDKey)] } {
            continue
        }
        set lDrvSeen($lDKey) 1
        incr lDrivers

        set lBx [expr { [lindex $lP 3] / $lThr }]
        set lBy [expr { [lindex $lP 4] / $lThr }]

        for { set lDx -1 } { $lDx <= 1 } { incr lDx } {
            for { set lDy -1 } { $lDy <= 1 } { incr lDy } {
                set lKey "[expr { $lBx + $lDx }],[expr { $lBy + $lDy }]"
                if { ![info exists lBkt($lKey)] } {
                    continue
                }
                foreach lQ $lBkt($lKey) {
                    # Same net - the two are the same electrical point and being
                    # in the same place is what they are supposed to be.
                    if { [lindex $lQ 2] eq [lindex $lP 2] } {
                        continue
                    }
                    incr lTests
                    set lD [expr { abs([lindex $lP 3] - [lindex $lQ 3])
                                 + abs([lindex $lP 4] - [lindex $lQ 4]) }]
                    if { $lD >= $lThr } {
                        continue
                    }
                    # Two nets near each other are found twice, once from each
                    # end; sorting the two sides makes the key the same both
                    # times, so the pair is counted once.  Done before the
                    # distance-0 test so the coincidence tally counts pairs, not
                    # visits.
                    set lPK [join [lsort [list [::mUtilMenu::GridPtKey $lP] \
                                               [::mUtilMenu::GridPtKey $lQ]]] " <> "]
                    if { [info exists lPairSeen($lPK)] } {
                        continue
                    }
                    set lPairSeen($lPK) 1

                    # A zero gap against a pin, a symbol or a bus end is the two
                    # touching, which is a made connection rather than a missing
                    # one - tallied and passed over.  Against another NET it stays
                    # a finding: two net objects sharing a point should have been
                    # one net.  See DISTANCE in the block comment.
                    if { $lD == 0 && [lindex $lQ 0] ne "NET" } {
                        incr lTouching
                        continue
                    }
                    lappend lFinds [list $lD $lP $lQ]
                }
            }
        }
    }
    ::mUtilMenu::TimeMark "gridcheck search" $lT

    # Nearest first: the smaller the gap, the more certainly it was meant to be a
    # connection.
    set lFinds [lsort -integer -index 0 $lFinds]

    # The resolved tolerance is spelled out in all three scales, because
    # "min_dis 0.5" on its own does not say whether the search just looked half a
    # grid step away or half a millimetre - and on a metric page those differ by
    # a factor of fifty.
    ::mUtilMenu::Out [format \
        "    min_dis %s %s = %d doc units = %s %s    %d net endpoint(s) vs %d endpoint(s), %d distance test(s)" \
        $min_dis $mGridMinDisUnits $lThr \
        [::mUtilMenu::Coord $pPage $lThr] [::mUtilMenu::CoordUnitLabel $pPage] \
        $lDrivers [llength $lPts] $lTests]

    if { [llength $lFinds] == 0 } {
        ::mUtilMenu::Out "    none - every net endpoint is either connected, touching what it should touch, or more than min_dis from anything else"
    } else {
        # Printed nearest-first and capped; the count below is of everything
        # found, so a cut-off listing can never read as the whole answer.
        set lShow $lFinds
        if { $mGridListMax > 0 && [llength $lFinds] > $mGridListMax } {
            set lShow [lrange $lFinds 0 [expr { $mGridListMax - 1 }]]
        }
        foreach lF $lShow {
            set lD [lindex $lF 0]
            set lA [lindex $lF 1]
            set lB [lindex $lF 2]
            ::mUtilMenu::Out [format "    %-8s %-28s %s" \
                      [lindex $lA 0] [lindex $lA 1] [::mUtilMenu::GridPtStr $pPage $lA]]
            # A zero gap only reaches the listing net-against-net, so it is worth
            # saying which of the two kinds of hit this line is.
            set lTail ""
            if { $lD == 0 } {
                set lTail "   (same point - two nets that did not merge)"
            }
            ::mUtilMenu::Out [format "      -> %-8s %-25s %-20s gap %s (%d doc)%s" \
                      [lindex $lB 0] [lindex $lB 1] [::mUtilMenu::GridPtStr $pPage $lB] \
                      [::mUtilMenu::Coord $pPage $lD] $lD $lTail]
            if { [lindex $lB 5] ne "" } {
                ::mUtilMenu::Out [format "         %-8s %s" "" [lindex $lB 5]]
            }
        }
        if { [llength $lShow] < [llength $lFinds] } {
            ::mUtilMenu::Out [format \
                "    ... (+%d more, not listed - mGridListMax is %d; tighten min_dis instead)" \
                [expr { [llength $lFinds] - [llength $lShow] }] $mGridListMax]
        }
    }
    # The touching pairs are not findings, but they are not nothing either - they
    # are the connections that WERE made, and a page reporting none of them at all
    # is a page where nothing is joined to anything, which would say the endpoint
    # data is wrong rather than the schematic.
    ::mUtilMenu::Out [format \
        "    (%d pair(s) found;  %d touching a pin / symbol / bus end, i.e. connected, not reported)" \
        [llength $lFinds] $lTouching]
    ::mUtilMenu::Out [format \
        "    timing: Search_Missing_connection_onGrid %d ms" \
        [expr { [clock milliseconds] - $lT0 }]]

    ::mUtilMenu::TimeMark "gridcheck total" $lTAll
    return $lFinds
}

#-----------------------------------------------------------------------------
# MarkGridFindings - put the search's answer on the page
#
# The Command Window says where the near misses are in coordinates; this says it
# in the only language a schematic review actually reads, which is the drawing.
# Per finding:
#
#   the net the finding is about        every one of its wires, in PINK
#   the far side, when it is a NET      every one of ITS wires, in DARK GREY
#   the far side, when it is a pin,     a DEEP BLUE box round the object - the
#     a symbol or a bus end             pin's whole part, the symbol, or a small
#                                       square at the bus end
#
# So a pink net with a blue box on it reads "this net stops short of that part",
# and pink against grey reads "these two nets nearly met".  Colours are
# mChkNetColor / mChkOtherColor / mChkBoxColor - see those for why each palette
# index was picked.
#
# Everything is collected before anything is drawn, because a net that turns up in
# five findings is still one net and should be one set of pink lines - and because
# a net that is the subject of one finding and the far side of another has to come
# out pink, not grey, whichever order the findings happened to arrive in.
#
# The pin's PART is boxed rather than the pin: a box round one pin is a few doc
# units across and invisible at the zoom that shows a whole page, and the part is
# what the reviewer has to go and look at anyway.  A bus wire has no area at all,
# so its end gets a square padded by the search tolerance.
#
# These are real DboGraphicLineInst / DboGraphicBoxInst objects on the page, the
# same as the compare's markers: the page comes out modified, File > Save keeps
# them and Undo takes them off.  mChkMark 0 turns the whole thing off.
#
# Returns the number of objects drawn.  Never lets a failed draw stop the rest -
# one net whose coordinates Capture refuses should not cost the other findings
# their markers.
#-----------------------------------------------------------------------------

# A square round one point, {left top right bottom}, for the things that have no
# area to box.  Page y runs downward, so top is the smaller number - the order
# CRect wants and the order DrawPageBoxOn passes straight through.
proc ::mUtilMenu::PadBoxDoc { pX pY pPad } {
    if { $pPad < 1 } {
        set pPad 1
    }
    return [list [expr { $pX - $pPad }] [expr { $pY - $pPad }] \
                 [expr { $pX + $pPad }] [expr { $pY + $pPad }]]
}

proc ::mUtilMenu::MarkGridFindings { pPage pDict pFinds pThr } {
    variable mChkNetColor
    variable mChkOtherColor
    variable mChkBoxColor
    variable mChkLineWidth
    variable mChkLineStyle
    variable mChkBoxWidth
    variable mChkBoxStyle

    if { [llength $pFinds] == 0 } {
        return 0
    }

    array set lSegs {}
    ::mUtilMenu::GridNetSegIndex $pDict lSegs

    # Plan first, draw second - see the block comment.
    array set lPink {}
    array set lGrey {}
    array set lBoxSeen {}
    set lBoxes [list]

    foreach lF $pFinds {
        set lP [lindex $lF 1]
        set lQ [lindex $lF 2]

        set lPink([lindex $lP 2]) [lindex $lP 1]

        if { [lindex $lQ 0] eq "NET" } {
            set lGrey([lindex $lQ 2]) [lindex $lQ 1]
            continue
        }

        set lBox [lindex $lQ 6]
        if { [llength $lBox] != 4 } {
            set lBox [::mUtilMenu::PadBoxDoc [lindex $lQ 3] [lindex $lQ 4] $pThr]
        }

        # Keyed on the RECTANGLE, not on the endpoint: two pins of the same part
        # both stopping a net short are two findings but one part, and the box is
        # the part's - keying on the pin would stack two identical rectangles on
        # top of each other.
        if { [info exists lBoxSeen($lBox)] } {
            continue
        }
        set lBoxSeen($lBox) 1
        lappend lBoxes [list "[lindex $lQ 0] [lindex $lQ 1]" $lBox]
    }

    # Pink wins over grey: being the subject of a finding says more about a net
    # than being somebody else's neighbour.
    foreach lGrp [array names lPink] {
        catch { unset lGrey($lGrp) }
    }

    set lOffset [::mUtilMenu::MarkOffsetDoc $pPage]
    set lDrawn  0
    set lFailed 0

    # Arrays -> {group label} lists, so the two sides can be walked by one loop
    # without aliasing an array name at runtime.
    set lSides [list]
    foreach lSide [list [list lPink $mChkNetColor   "pink"] \
                        [list lGrey $mChkOtherColor "grey"] ] {
        set lList [list]
        foreach lGrp [lsort [array names [lindex $lSide 0]]] {
            if { [lindex $lSide 0] eq "lPink" } {
                lappend lList [list $lGrp $lPink($lGrp)]
            } else {
                lappend lList [list $lGrp $lGrey($lGrp)]
            }
        }
        lappend lSides [list $lList [lindex $lSide 1] [lindex $lSide 2]]
    }

    ::mUtilMenu::Out "  Markers - [array size lPink] net(s) pink, [array size lGrey] net(s) grey, [llength $lBoxes] box(es) deep blue"

    foreach lSide $lSides {
        set lColor [lindex $lSide 1]
        set lWord  [lindex $lSide 2]

        foreach lRec [lindex $lSide 0] {
            set lGrp [lindex $lRec 0]
            if { ![info exists lSegs($lGrp)] } {
                ::mUtilMenu::Trace "no wires on record for $lGrp - nothing to draw"
                continue
            }
            set lN 0
            foreach lSeg $lSegs($lGrp) {
                if { [llength $lSeg] != 4 } {
                    continue
                }
                set lAt [::mUtilMenu::OffsetSeg $lSeg $lOffset]
                if { [catch { ::mUtilMenu::DrawPageLineOn $pPage \
                                  [lrange $lAt 0 1] [lrange $lAt 2 3] \
                                  $lColor $mChkLineWidth $mChkLineStyle } lErr] } {
                    ::mUtilMenu::Trace "$lWord line for $lGrp at $lAt failed -> $lErr"
                    incr lFailed
                    continue
                }
                incr lN
                incr lDrawn
            }
            ::mUtilMenu::Out [format "    %-4s net %-28s %d wire(s)" \
                      $lWord [lindex $lRec 1] $lN]
        }
    }

    foreach lEntry $lBoxes {
        set lLabel [lindex $lEntry 0]
        set lBox   [lindex $lEntry 1]
        if { [catch { ::mUtilMenu::DrawPageBoxOn $pPage $lBox \
                          $mChkBoxColor $mChkBoxWidth $mChkBoxStyle } lErr] } {
            ::mUtilMenu::Trace "box for $lLabel at $lBox failed -> $lErr"
            incr lFailed
            continue
        }
        incr lDrawn
        ::mUtilMenu::Out [format "    blue box %-28s (%s,%s)-(%s,%s)" $lLabel \
                  [lindex $lBox 0] [lindex $lBox 1] [lindex $lBox 2] [lindex $lBox 3]]
    }

    # Once for the batch, not once per object - see DrawPageLineOn.
    if { $lDrawn > 0 } {
        ::mUtilMenu::MarkPageDirty $pPage
        catch { ZoomRedraw }
    }
    set lNote ""
    if { $lFailed } {
        set lNote ", $lFailed failed"
    }
    ::mUtilMenu::Out "    ($lDrawn object(s) drawn$lNote - File > Save to keep them, Undo to remove)"
    return $lDrawn
}

# SCH_CHECK_ITEM2's markers: every wire of every net whose schematic-level name
# was made unique, in PINK.
#
# Pink and nothing else - no grey and no box - because this finding has only one
# side to it.  A near miss is a relationship between two things and needs two
# colours to say which is which; a name conflict is one net being quietly renamed,
# so there is exactly one thing to point at.  The other page's net of the same
# name is the other half of the story, but it is on another page and cannot be
# drawn on this one.
#
# pConf is what PageNameConflicts returned, and it is used for the early-out and
# the count only.  The rows are re-tested here with the same predicate rather than
# looked up by name, because a page label is NOT a unique key: two separate net
# objects on one page can both carry the label +3.3VSB and be renamed to
# +3.3VSB_9631 and +3.3VSB_9632: keying an array on the label collapses them to
# one entry, and every line printed would then name whichever schematic net came
# last.  Testing the row itself gives each net its own answer, and both of them
# their wires - they are both the fault.
#
# Same colour, width, style and nudge as the grid check's pink, and the same
# once-at-the-end MarkModified / ZoomRedraw.  Returns the number of lines drawn.
proc ::mUtilMenu::MarkNameConflicts { pPage pDict pConf } {
    variable mChkNetColor
    variable mChkLineWidth
    variable mChkLineStyle

    if { [llength $pConf] == 0 } {
        return 0
    }

    set lOffset [::mUtilMenu::MarkOffsetDoc $pPage]
    set lDrawn  0
    set lFailed 0

    ::mUtilMenu::Out "  Markers - [llength $pConf] net(s) pink"

    foreach lRow [dict get $pDict nets] {
        set lLabel [lindex $lRow 0]
        set lSch   [lindex $lRow 3]
        if { [::mUtilMenu::NetNameConflictSuffix $lLabel $lSch] eq "" } {
            continue
        }

        set lN 0
        # Element 2 is the wires as {x1 y1 x2 y2} doc quads - see CollectPageNets.
        foreach lSeg [lindex $lRow 2] {
            if { [llength $lSeg] != 4 } {
                continue
            }
            set lAt [::mUtilMenu::OffsetSeg $lSeg $lOffset]
            if { [catch { ::mUtilMenu::DrawPageLineOn $pPage \
                              [lrange $lAt 0 1] [lrange $lAt 2 3] \
                              $mChkNetColor $mChkLineWidth $mChkLineStyle } lErr] } {
                ::mUtilMenu::Trace "conflict line for $lLabel at $lAt failed -> $lErr"
                incr lFailed
                continue
            }
            incr lN
            incr lDrawn
        }
        ::mUtilMenu::Out [format "    pink net %-28s %d wire(s)   (netlist: %s)" \
                  $lLabel $lN $lSch]
    }

    if { $lDrawn > 0 } {
        ::mUtilMenu::MarkPageDirty $pPage
        catch { ZoomRedraw }
    }
    set lNote ""
    if { $lFailed } {
        set lNote ", $lFailed failed"
    }
    ::mUtilMenu::Out "    ($lDrawn object(s) drawn$lNote - File > Save to keep them, Undo to remove)"
    return $lDrawn
}

#-----------------------------------------------------------------------------
# Running the check - one page, or every page under what the PM has selected
#
# Everything below is about scope.  The work on a single page has not changed:
# grid block, page dump, near-miss search, markers.  What is new is that a
# schematic, a .DSN or a .OPJ selected in the Project Manager means "do that to
# every page under this", and that a page which came out marked gets a '*' in
# front of its name so the Project Manager tree shows at a glance which pages
# need looking at.
#
# The Command Window still gets everything.  The message box gets ONE table -
# one line per page - and no longer repeats the page's Grid Reference settings:
# on a 100-page design that would be 1200 lines of dialog, and even for one page
# the grid block is reference material rather than a result.  It is still printed
# to the Command Window for every page.
#-----------------------------------------------------------------------------

# {schematicObj pageObj} for every page of one DboSchematic, in database order.
proc ::mUtilMenu::SchematicPageObjs { pSch } {
    set lOut     [list]
    set lNullObj NULL
    set lStatus  [DboState]

    catch {
        set lIter [$pSch NewPagesIter $lStatus]
        set lPage [$lIter NextPage $lStatus]
        while { $lPage != $lNullObj } {
            lappend lOut [list $pSch $lPage]
            set lPage [$lIter NextPage $lStatus]
        }
        catch { delete_DboSchematicPagesIter $lIter }
    }

    catch { $lStatus -delete }
    return $lOut
}

# The same for every schematic of one DboDesign - the OBJECT walk behind
# GetDesignPages, which returns names.  Names would have to be looked up again
# one page at a time, and each lookup is another walk of the whole design.
proc ::mUtilMenu::DesignPageObjs { pDesign } {
    set lOut     [list]
    set lNullObj NULL
    set lStatus  [DboState]

    catch {
        set lIter [$pDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
        set lView [$lIter NextView $lStatus]
        while { $lView != $lNullObj } {
            # dynamic cast DboView -> DboSchematic, per PDF 3.2.7
            foreach lPair [::mUtilMenu::SchematicPageObjs [DboViewToDboSchematic $lView]] {
                lappend lOut $lPair
            }
            set lView [$lIter NextView $lStatus]
        }
        catch { delete_DboLibViewsIter $lIter }
    }

    catch { $lStatus -delete }
    return $lOut
}

# Turn one classified PM selection into the pages to check, as {schObj pageObj}
# pairs.  pKind / pWhat are what ClassifyPMItem returned; pDsn is the active
# design's file, which is the only way in for a .OPJ - a project node names no
# design of its own, so the design the PM has open is the design it means.
#
# Returns {} for anything that resolves to no pages, which the caller reports as
# itself rather than as an empty run.
proc ::mUtilMenu::PagesForPMItem { pKind pWhat pDsn } {
    switch -- $pKind {
        page {
            if { ![::mUtilMenu::BindDboHandle $pWhat DboPage] } {
                return [list]
            }
            # The schematic comes off the page, so a single page needs no context
            # passed in either (DboPage::GetOwner, Appendix A).
            set lSch ""
            catch { set lSch [$pWhat GetOwner] }
            return [list [list $lSch $pWhat]]
        }
        schematic {
            if { ![::mUtilMenu::BindDboHandle $pWhat DboSchematic] } {
                return [list]
            }
            return [::mUtilMenu::SchematicPageObjs $pWhat]
        }
        design {
            # Either a SWIG handle or a path, depending on what the PM label was.
            set lDesign ""
            if { [::mUtilMenu::PMItemDboClass $pWhat] ne "" } {
                if { [::mUtilMenu::BindDboHandle $pWhat DboDesign] } {
                    set lDesign $pWhat
                }
            } else {
                catch { set lDesign [::mUtilMenu::FindDesign $pWhat] }
            }
            if { $lDesign eq "" || $lDesign eq "NULL" } {
                return [list]
            }
            return [::mUtilMenu::DesignPageObjs $lDesign]
        }
        project {
            if { $pDsn eq "" } {
                return [list]
            }
            set lDesign ""
            catch { set lDesign [::mUtilMenu::FindDesign $pDsn] }
            if { $lDesign eq "" || $lDesign eq "NULL" } {
                return [list]
            }
            return [::mUtilMenu::DesignPageObjs $lDesign]
        }
    }
    return [list]
}

# SCH_CHECK_ITEM2's test, on ONE net.  Returns the serial-number suffix Capture
# added - "_9631" - or "" when this net is not that case.
#
# The fault it names: two pages each carry a wire labelled +3.3VSB, and nothing
# joins them - no Off-Page Connector, no Power symbol, no Port.  Capture will not
# weld two nets together just because their labels match, so it keeps them apart
# and makes the schematic-level names unique by hanging a serial number off one of
# them.  The page still says +3.3VSB; the netlist says +3.3VSB_9631.  Almost
# always that means somebody meant the two to be one net and left the connector
# off, which is why the report says "may conflict" and not "is wrong": a genuinely
# local net that happens to share a name is legal, just rare.
#
# The test is exactly "schematic name is the page label, an underscore, and then
# nothing but digits".  It is deliberately spelled with string commands rather
# than a regexp: a net label is user text and routinely contains regexp
# metacharacters - +3.3VSB starts with one, and bus members like D[0] are all
# brackets - so building a pattern out of one would need escaping that is easy to
# get subtly wrong and hard to notice.
#
#   +3.3VSB   +3.3VSB_9631   -> _9631   the finding
#   +3.3VSB   +3.3VSB        -> ""      one net, nothing renamed
#   +3.3VSB   VCC_CORE       -> ""      not a rename at all, some other naming
#   +3.3VSB   +3.3VSB_A      -> ""      not a serial number
#   +3.3VSB   ""             -> ""      no schematic net to compare against
proc ::mUtilMenu::NetNameConflictSuffix { pLabel pSchName } {
    if { $pLabel eq "" || $pSchName eq "" || $pSchName eq $pLabel } {
        return ""
    }

    set lPrefix "${pLabel}_"
    if { [string first $lPrefix $pSchName] != 0 } {
        return ""
    }

    set lTail [string range $pSchName [string length $lPrefix] end]
    if { $lTail eq "" || ![string is digit -strict $lTail] } {
        return ""
    }
    return "_$lTail"
}

# Every net on one page whose schematic-level name was made unique that way, as
# rows of {pageLabel schematicName suffix}, in page-label order.
#
# pDict is the dump DumpPageInfoOn just returned, so this costs no database calls
# at all: element 3 of a net row is already the schematic name - CollectPageNets
# read it while it was walking the nets anyway.  That is the whole reason both
# checks share one dump when both boxes are ticked.
proc ::mUtilMenu::PageNameConflicts { pDict } {
    set lRows [list]

    foreach lRow [dict get $pDict nets] {
        set lLabel [lindex $lRow 0]
        set lSch   [lindex $lRow 3]
        set lSfx   [::mUtilMenu::NetNameConflictSuffix $lLabel $lSch]
        if { $lSfx ne "" } {
            lappend lRows [list $lLabel $lSch $lSfx]
        }
    }
    return [lsort -dictionary -index 0 $lRows]
}

# Check ONE page.  Returns
# {schName pageName pairs drawn starred status nets conflicts confDrawn}:
#
#   pairs    how many near misses the grid search found
#   drawn    how many GRID marker objects went onto the page
#   starred  1 when this run put the '*' on the page name
#   status   "" when all went well, else what went wrong, for the table
#   nets     the names of the nets involved in the near misses, sorted and
#            deduplicated - what the report lists under the page, so the reviewer
#            knows which nets to look at before opening it
#   conflicts  PageNameConflicts' rows - the SCH_CHECK_ITEM2 findings
#   confDrawn  how many pink lines those findings put on the page
#
# The two drawn counts are kept apart rather than added up because they are
# reported under their own checks, and a run with only one check ticked must not
# be handed a total that includes the other one's markers.
#
# pModes is which checks were asked for, as mChkModes values:
#
#   grid       the near-miss search, the markers and the '*'.  Needs the FULL
#              dump, and every pin's position with it (mPinPosAll), because the
#              thing a net can stop short of is usually a pin.
#   globalref  the net-name check, and a pink line over every wire of every net it
#              finds.  Needs the nets and nothing else, so on its own it dumps
#              only the nets section and leaves mPinPosAll alone - which is most
#              of the cost of a page, not a small saving.  It does NOT rename the
#              page: the '*' is the grid check's marker for "this page has
#              geometry to look at", and the report already names the pages.
#
# pStar 0 draws the markers but leaves the page NAME alone.  That is what a single
# page picked in the Project Manager gets, and the reason is what the '*' is for:
# it is a way of finding the marked pages again in a tree of forty.  Someone who
# selected one page is already looking at the page they asked about, so the '*'
# tells them nothing - and it costs a rename of their design, on every run, for
# nothing.  A schematic, a .DSN or a .OPJ still stars, because there the tree IS
# the answer.  RunSchematicCheck decides which from the scope it was given.
#
# Both together are ONE dump and one walk, not two: the grid check's dump already
# carries the schematic net names the name check reads.
#
# Nothing here decides whether the Command Window hears about it: the caller sets
# mQuiet around the whole call.  A single page selected in the Project Manager is
# run loud (the dump IS the answer for one page); a schematic, a design or a
# project is run silent, because forty pages of dump is minutes of printing for
# an answer the message box already carries.  See RunSchematicCheck.
proc ::mUtilMenu::CheckOnePage { pSch pPage {pModes {grid}} {pStar 1} } {
    variable mPinPosAll
    variable mGridMinDis
    variable mChkMark

    set lDoGrid [expr { [lsearch -exact $pModes grid]      != -1 }]
    set lDoName [expr { [lsearch -exact $pModes globalref] != -1 }]

    set lPageName [::mUtilMenu::CStr $pPage GetName]
    set lSchName  ""
    set lDsn      ""
    if { $pSch ne "" && $pSch ne "NULL" } {
        set lSchName [::mUtilMenu::CStr $pSch GetName]
    } else {
        catch { set lSchName [::mUtilMenu::CStr [$pPage GetOwner] GetName] }
    }
    catch { set lDsn [::mUtilMenu::CStr [$pPage GetContainingLib] GetName] }

    # The grid block first: it is cheap, and if the dump then dies on a page this
    # file has not seen before, what the page IS has already been said.  Every
    # Out below is a no-op when the caller has asked for silence.  It is the grid
    # check's material, so a name-only run does not print it.
    ::mUtilMenu::Out "================================================================"
    ::mUtilMenu::Out [::mUtilMenu::Banner "Schematic Check - [file tail $lDsn] - [::mUtilMenu::OrDash $lSchName] / [::mUtilMenu::OrDash $lPageName]"]
    ::mUtilMenu::Out "================================================================"
    if { $lDoGrid } {
        foreach lLine [split [::mUtilMenu::FormatPageGrid \
                                  [::mUtilMenu::CollectPageGrid $pPage]] "\n"] {
            ::mUtilMenu::Out "  $lLine"
        }
        ::mUtilMenu::Out "----------------------------------------------------------------"
    }

    ::mUtilMenu::TimeReset
    set lT [::mUtilMenu::TimeNow]

    # Every pin's position, wired or not - this is the one thing Schematic Check
    # asks the database for that Schematic Compare does not.  Restored on the way
    # out whatever happens, so a dump that dies cannot leave Compare paying for a
    # walk it never asked for.  See mPinPosAll.
    set lWhat [list parts symbols nets buses]
    if { !$lDoGrid } {
        set lWhat [list nets]
    }
    set lSavePos $mPinPosAll
    if { $lDoGrid } {
        set mPinPosAll 1
    }
    set lDict   [list]
    set lFailed [catch { set lDict [::mUtilMenu::DumpPageInfoOn $pPage $lWhat] } lErr]
    set mPinPosAll $lSavePos

    if { $lFailed } {
        ::mUtilMenu::Trace "page dump failed on [::mUtilMenu::OrDash $lPageName] -> $lErr"
        return [list $lSchName $lPageName 0 0 0 "dump failed" [list] [list] 0]
    }

    # SCH_CHECK_ITEM2, off the dump that is already in hand - no second walk, and
    # it runs BEFORE the grid search so that a search that falls over still leaves
    # the name findings to report.  The test itself cannot fail (it is string work
    # over a list); the drawing can, and is caught the same way the grid check's
    # markers are - a page that refuses a graphic object still gets reported.
    set lConf   [list]
    set lConfDr 0
    if { $lDoName } {
        set lConf [::mUtilMenu::PageNameConflicts $lDict]
        if { [llength $lConf] > 0 } {
            ::mUtilMenu::Out "----------------------------------------------------------------"
            ::mUtilMenu::Out "  Nets name may conflict:"
            foreach lC $lConf {
                ::mUtilMenu::Out "    Page name: [lindex $lC 0] ([lindex $lC 1])"
            }
            if { $mChkMark } {
                if { [catch { set lConfDr [::mUtilMenu::MarkNameConflicts \
                                  $pPage $lDict $lConf] } lErrC] } {
                    ::mUtilMenu::Trace "MarkNameConflicts failed on [::mUtilMenu::OrDash $lPageName] -> $lErrC"
                    set lConfDr 0
                }
            }
        }
    }

    if { !$lDoGrid } {
        ::mUtilMenu::TimeReport "Schematic Check, one page" $lT
        return [list $lSchName $lPageName 0 0 0 "" [list] $lConf $lConfDr]
    }

    # The main event, and it runs on the dump's own rows - see the proc.  Its own
    # failure is caught separately from the dump's: the dump is the material, and
    # a dump that came out is worth keeping on screen even if the search over it
    # then falls over.
    ::mUtilMenu::Out "----------------------------------------------------------------"
    set lFinds [list]
    if { [catch { set lFinds [::mUtilMenu::Search_Missing_connection_onGrid \
                                  $pPage $lDict $mGridMinDis] } lErr2] } {
        ::mUtilMenu::Trace "Search_Missing_connection_onGrid failed -> $lErr2"
        return [list $lSchName $lPageName 0 0 0 "search failed" [list] $lConf $lConfDr]
    }

    # Which nets the findings are about.  Element 1 of a finding is always a net
    # endpoint; element 2 is one too when two nets nearly met, and then both names
    # belong in the list - "VCCM_EN_A1 nearly touches N44011769" is one problem
    # naming two nets, and a reviewer wants to find either of them.
    set lNets [list]
    foreach lF $lFinds {
        foreach lSide [list [lindex $lF 1] [lindex $lF 2]] {
            if { [lindex $lSide 0] ne "NET" } {
                continue
            }
            set lName [lindex $lSide 1]
            if { $lName ne "" && [lsearch -exact $lNets $lName] == -1 } {
                lappend lNets $lName
            }
        }
    }
    set lNets [lsort -dictionary $lNets]

    # Draw them, then star the page.  Both are caught on their own: the search's
    # answer is already printed by the time either runs, and a page that refuses
    # a graphic object or a rename should not take the report down with it.  The
    # tolerance is re-resolved rather than threaded out of the search - one Dbo
    # call, and it keeps the search's return value about findings only.
    set lDrawn   0
    set lStarred 0
    set lStatus  ""
    if { $mChkMark && [llength $lFinds] > 0 } {
        if { [catch { set lDrawn [::mUtilMenu::MarkGridFindings $pPage \
                          $lDict $lFinds \
                          [::mUtilMenu::GridTolDoc $pPage $mGridMinDis]] } lErr3] } {
            ::mUtilMenu::Trace "MarkGridFindings failed on [::mUtilMenu::OrDash $lPageName] -> $lErr3"
            set lStatus "not marked"
        }
        if { $lDrawn > 0 && !$pStar } {
            # One page picked in the Project Manager - see pStar.  The markers go
            # on, the name does not change.
            ::mUtilMenu::Trace "  single page - markers drawn, page name left alone"
        } elseif { $lDrawn > 0 } {
            # '*' on the page name, so the PM tree says which pages to open.
            # A page checked twice keeps its one '*' - StarPageObj refuses to add
            # a second, and that is not a failure to report as one.
            if { [string index $lPageName 0] eq "*" } {
                set lStatus "already '*'"
            } elseif { [catch { set lStarred \
                            [::mUtilMenu::StarPageObj $pSch $pPage] } lErr4] } {
                ::mUtilMenu::Trace "StarPageObj failed -> $lErr4"
                set lStatus "'*' not added"
            } elseif { $lStarred } {
                set lPageName [::mUtilMenu::CStr $pPage GetName]
            } else {
                set lStatus "'*' not added"
            }
        }
    }

    ::mUtilMenu::TimeReport "Schematic Check, one page" $lT
    return [list $lSchName $lPageName [llength $lFinds] $lDrawn $lStarred $lStatus \
                 $lNets $lConf $lConfDr]
}

# The net names of one page's findings, as one line for the message box, capped
# so a page with sixty involved nets does not push the totals off the screen.
proc ::mUtilMenu::NetListStr { pNets pMax } {
    if { [llength $pNets] == 0 } {
        return ""
    }
    if { $pMax <= 0 || [llength $pNets] <= $pMax } {
        return [join $pNets {, }]
    }
    return "[join [lrange $pNets 0 [expr { $pMax - 1 }]] {, }], ... (+[expr { [llength $pNets] - $pMax }] more)"
}

# Check every page in pPairs and put up ONE message box for the lot.
#
# pWhat is what the user picked, for the dialog's first line ("Design W980_WS.DSN"),
# so the report says what it covered as well as what it found.
#
# pLoud 1 lets the per-page detail through to the Command Window, which is what a
# single selected page wants: for one page the dump and the search listing ARE the
# answer.  pLoud 0 silences the whole loop - a schematic, a design or a project is
# tens of thousands of lines of dump for a result the message box already carries,
# and printing them costs far more time than the search does.  Only this summary
# is printed either way.
#
# pModes is which checks are ticked - see CheckOnePage.  It goes through to every
# page, and it also decides what the report says: a run that was never asked to
# look for near misses must not end on "no page has a near miss", and one that was
# never asked about names must not claim the names are clean.  Each section is
# printed only by the check that produced it.
#
# pKind is what the Project Manager had selected - page / schematic / design /
# project - and it decides the two things that are about the SHAPE of the run
# rather than about the checks:
#
#   the '*'     only a multi-page scope stars.  See CheckOnePage's pStar.
#   progress    only a multi-page scope prints "... has finished".  For one page
#               there is nothing to make progress through, and the dump is already
#               going past on screen.
#
# It is passed rather than inferred from pLoud, which would be wrong: pLoud is 1
# for a single page but ALSO for a whole design when mChkBatchDetail is on, and
# that design must still star its pages.
proc ::mUtilMenu::RunSchematicCheck { pPairs pWhat {pLoud 1} {pModes {grid}} \
                                      {pKind "page"} } {
    variable mGridMinDis
    variable mGridMinDisUnits
    variable mChkMark
    variable mGridListMax
    variable mChkNetListMax
    variable mQuiet

    set lDoGrid [expr { [lsearch -exact $pModes grid]      != -1 }]
    set lDoName [expr { [lsearch -exact $pModes globalref] != -1 }]

    # One page = leave the name alone and say nothing per page; anything wider =
    # star the pages and report progress.  Both fall out of the same test, because
    # both answer the same question: is there a tree of pages to find your way
    # around afterwards, and a wait to sit through while it is built?
    set lMulti [expr { $pKind ne "page" }]

    set lRows  [list]
    set lTotP  0
    set lTotD  0
    set lTotS  0
    set lTotC  0
    set lTotCD 0
    set lT0    [clock milliseconds]

    # One switch around the whole loop rather than a flag threaded through every
    # proc under it: Out is the single door to the Command Window, and mQuiet is
    # its lock.  Restored whatever happens, so a page that throws cannot leave the
    # rest of the session silent.
    set lSaveQuiet $mQuiet
    if { !$pLoud } {
        set mQuiet 1
    }
    set lErr ""
    if { [catch {
        set lNth 0
        foreach lPair $pPairs {
            incr lNth
            set lRec [::mUtilMenu::CheckOnePage [lindex $lPair 0] [lindex $lPair 1] \
                                                $pModes $lMulti]
            lappend lRows $lRec
            incr lTotP [lindex $lRec 2]
            incr lTotD [lindex $lRec 3]
            incr lTotS [lindex $lRec 4]
            incr lTotC  [llength [lindex $lRec 7]]
            incr lTotCD [lindex $lRec 8]

            # Progress, through mQuiet - see OutAlways.  The counter is on the
            # line because "PAGE7 has finished" on its own does not say whether
            # there are two more of these or ninety.  The page name is taken from
            # the record rather than from the pair, so a page that was just
            # renamed '*' is reported under the name it now has.
            if { $lMulti } {
                ::mUtilMenu::OutAlways [format "%s / %s has finished... (%d/%d)" \
                    [::mUtilMenu::OrDash [lindex $lRec 0]] \
                    [::mUtilMenu::OrDash [lindex $lRec 1]] \
                    $lNth [llength $pPairs]]
            }
        }
    } lErr] } {
        set mQuiet $lSaveQuiet
        ::mUtilMenu::Trace "Schematic Check stopped after [llength $lRows] page(s) -> $lErr"
    }
    set mQuiet $lSaveQuiet
    set lMs [expr { [clock milliseconds] - $lT0 }]

    # The same report twice, Command Window and message box, built once.
    set lTxt ""
    append lTxt "[::mUtilMenu::Banner {Schematic Check}] - $pWhat\n"
    if { $lDoGrid } {
        append lTxt "min_dis $mGridMinDis $mGridMinDisUnits"
        if { !$mChkMark } {
            append lTxt "   (mChkMark 0 - reporting only, nothing drawn)"
        }
        append lTxt "\n"
    }
    append lTxt "\n"

    # SCH_CHECK_ITEM1 - one block per page that has something to say: the page
    # name, then the nets involved.  Those two are the whole point of the dialog -
    # which page to open, and what to look for once it is open.
    set lShown  0
    set lHidden 0
    if { $lDoGrid } {
        append lTxt "NETs not on Grid:\n"
        foreach lRec $lRows {
            # Pages with nothing to say are counted, not listed.
            if { [lindex $lRec 2] == 0 && [lindex $lRec 5] eq "" } {
                incr lHidden
                continue
            }
            if { $mGridListMax > 0 && $lShown >= $mGridListMax } {
                incr lHidden
                continue
            }
            incr lShown

            set lNote [lindex $lRec 5]
            if { $lNote ne "" } {
                set lNote "   ($lNote)"
            }
            append lTxt [format "  %s / %s   -   %d pair(s), %d marked%s\n" \
                             [::mUtilMenu::OrDash [lindex $lRec 0]] \
                             [::mUtilMenu::OrDash [lindex $lRec 1]] \
                             [lindex $lRec 2] [lindex $lRec 3] $lNote]

            set lNets [lindex $lRec 6]
            if { [llength $lNets] > 0 } {
                append lTxt "      nets:  [::mUtilMenu::NetListStr $lNets $mChkNetListMax]\n"
            }
        }
        if { $lShown == 0 } {
            # Nothing to list at all - "no page has a near miss" says it, and a
            # second line counting the pages that are not listed would be counting
            # every page that was just checked.
            append lTxt "  (no page has a near miss)\n"
        } elseif { $lHidden > 0 } {
            append lTxt "  ... [expr { [llength $lRows] - $lShown }] page(s) not listed - nothing found on them\n"
        }
        append lTxt "\n"
    }

    # SCH_CHECK_ITEM2 - the net names Capture had to make unique.  Same two-level
    # shape as the block above and capped the same two ways: mGridListMax pages,
    # mChkNetListMax nets under any one of them, so a design where every page has
    # the fault cannot push the totals off the bottom of the box.
    if { $lDoName } {
        append lTxt "Nets name may conflict:\n"
        set lCShown  0
        set lCPages  0
        foreach lRec $lRows {
            set lConf [lindex $lRec 7]
            if { [llength $lConf] == 0 } {
                continue
            }
            incr lCPages
            if { $mGridListMax > 0 && $lCShown >= $mGridListMax } {
                continue
            }
            incr lCShown

            append lTxt [format "  %s / %s   -   %d net name(s), %d marked\n" \
                             [::mUtilMenu::OrDash [lindex $lRec 0]] \
                             [::mUtilMenu::OrDash [lindex $lRec 1]] \
                             [llength $lConf] [lindex $lRec 8]]

            set lN 0
            foreach lC $lConf {
                incr lN
                if { $mChkNetListMax > 0 && $lN > $mChkNetListMax } {
                    append lTxt "      ... (+[expr { [llength $lConf] - $mChkNetListMax }] more)\n"
                    break
                }
                append lTxt "      Page name: [lindex $lC 0] ([lindex $lC 1])\n"
            }
        }
        if { $lCPages == 0 } {
            append lTxt "  (no net name was made unique - nothing to look at)\n"
        } elseif { $lCPages > $lCShown } {
            append lTxt "  ... [expr { $lCPages - $lCShown }] more page(s) not listed\n"
        }
        append lTxt "\n"
    }

    append lTxt [format "%d page(s) checked in %d ms:" [llength $lRows] $lMs]
    if { $lDoGrid } {
        append lTxt [format "  %d pair(s), %d object(s) drawn" $lTotP $lTotD]
        # Only where starring was on the table.  A single page never stars, and
        # "0 page(s) renamed '*'" would read as a rename that failed.
        if { $lMulti } {
            append lTxt [format ", %d page(s) renamed '*'" $lTotS]
        }
    }
    if { $lDoName } {
        append lTxt [format "  %d net name(s) may conflict, %d object(s) drawn" \
                         $lTotC $lTotCD]
    }
    append lTxt "\n"
    if { $lErr ne "" } {
        append lTxt "STOPPED after [llength $lRows] page(s): $lErr\n"
    }
    if { $lDoGrid && $lTotD > 0 } {
        append lTxt "\npink = the net that stops short   grey = the other net\n"
        append lTxt "blue = box round the part / symbol / bus end it misses\n"
    }
    if { $lDoName && $lTotC > 0 } {
        append lTxt "\n\"Page name: A (B)\" = the page draws A, the netlist sees B.\n"
        append lTxt "Another page has its own A and nothing joins the two - add an\n"
        append lTxt "Off-Page Connector, a Power symbol or a Port if they are one net.\n"
        if { $lTotCD > 0 } {
            append lTxt "pink = every wire of a net whose name was made unique.\n"
        }
    }
    if { $lTotD > 0 || $lTotCD > 0 } {
        append lTxt "\nFile > Save to keep the markers"
        if { $lDoGrid && $lTotS > 0 } {
            append lTxt " and the '*' names"
        }
        append lTxt ", Undo to remove them.\n"
    }
    if { $pLoud } {
        append lTxt "\n(per-page detail in the Command Window)"
    } else {
        append lTxt "\n(select a single page for the full dump in the Command Window)"
    }

    ::mUtilMenu::Out "================================================================"
    foreach lLine [split $lTxt "\n"] {
        ::mUtilMenu::Out $lLine
    }
    ::mUtilMenu::Out "================================================================"

    # The report goes in the read-only text window, not capDisplayMessageBox: the
    # message box is modal and its text cannot be selected, so a list of thirty
    # net names was something you could only read and retype.  This one is a text
    # widget - drag and Ctrl-C, or the Copy button with nothing selected to take
    # the whole report at once.  Same window Schematic Compare answers in; it is
    # rebuilt per run, so a second Check replaces the first report rather than
    # hiding behind it.  Its Close closes the report only - Schematic Check has no
    # page selector standing behind it.  See ShowResultWindow.
    ::mUtilMenu::ShowResultWindow "Schematic Check - [::mUtilMenu::VerStr]" $lTxt \
        "::mUtilMenu::CloseResultWindow"
    return true
}

#-----------------------------------------------------------------------------
# The check dialog - which checks, before any checking happens
#
# The menu item used to start work the moment it was clicked.  It now asks which
# checks first, because "check this schematic" is not one question: a net that
# stopped half a grid step short of a pin and a net that shares its name with
# another page's net without an off-page connector between them are two different
# faults, found two different ways, at two very different costs.
#
# The boxes are CHECKBOXES, not radio buttons: the faults are not alternatives, a
# design can have both, and being made to run the tool twice to find that out
# would be worse than the one extra walk.  Both are ticked by default.
#
# Every box is bound straight to its own global - SCH_CHECK_ITEM1 for the grid
# check, SCH_CHECK_ITEM2 for the global-reference check - so the tick IS the
# variable.  1 = ticked, 0 = not.  Both directions work: ticking a box sets the
# global, and setting the global from the Command Window moves the tick on an
# open dialog.  mChkModes element 2 is what names them.
#
#   ChkItemsNormalize              force the two globals to a clean 0 or 1
#   ChkItemsSelected               the ticked modes, in mChkModes order
#   RunSchematicCheckSelected      run all of them in one pass over the pages
#   RunSchematicCheckMode          one named check, for the Command Window
#   RunSchematicCheckOnSelection   resolve the PM selection, then run the modes
#   DoSchematicCheck               the menu callback: build/raise the dialog
#   DoSchematicCheckStart          Start: close the dialog, then run the ticks
#   CloseSchematicCheck            Close / X / Escape: destroy, run nothing
#
# Ticking both is ONE pass, not two.  The list of ticked modes goes all the way
# down to CheckOnePage, so a page is dumped once and asked both questions off the
# one dump - the schematic net names the name check reads are already in the net
# rows the grid check's dump produced.  Ticking only the name check dumps just the
# nets section and skips the pin walk, which is most of the cost of a page.
#
# The dialog is closed BEFORE the checks run, not after: a check ends in a
# message box, and a Tk toplevel left standing sits in front of it.  Same order
# DoSchematicCompareExecute uses.
#-----------------------------------------------------------------------------

# The two globals, forced to a clean 0 or 1.  They are public and writable from
# the Command Window, which is the point of them, so "1", "yes", "" and unset are
# all things they can be found holding; -onvalue/-offvalue only ever produce 0/1
# once a box has been clicked, and before that nothing has.
#
#   unset, 0, "", "no", "false"   -> 0
#   1, "yes", "true", any number  -> 1
#   anything expr cannot read     -> 1
#
# A string expr will not take as a boolean ticks the box rather than silently
# turning the check off: someone who typed it meant to ask for the check.
proc ::mUtilMenu::ChkItemsNormalize { } {
    variable mChkModes

    foreach lRow $mChkModes {
        set lVar ::[lindex $lRow 2]
        set lOn  0
        if { [info exists $lVar] } {
            if { [catch { set lOn [expr { [set $lVar] ? 1 : 0 }] }] } {
                set lOn 1
            }
        }
        set $lVar $lOn
    }
}

# Which checks are ticked, as mChkModes values in the order the dialog shows
# them, so a run is always grid-then-globalref no matter which box was clicked
# first.
proc ::mUtilMenu::ChkItemsSelected { } {
    variable mChkModes

    ::mUtilMenu::ChkItemsNormalize

    set lModes [list]
    foreach lRow $mChkModes {
        if { [set ::[lindex $lRow 2]] } {
            lappend lModes [lindex $lRow 0]
        }
    }
    return $lModes
}

# One named check on its own, against whatever the Project Manager has selected.
# Nothing in the menu path uses this - Start goes through the ticked boxes - but
# it is the one-liner for running a single check from the Command Window:
#
#   ::mUtilMenu::RunSchematicCheckMode globalref
#
# and it is what keeps "a mode" a thing this file has a name for, rather than
# something only the dialog can express.
proc ::mUtilMenu::RunSchematicCheckMode { pMode } {
    variable mChkModes

    set lLabel ""
    foreach lRow $mChkModes {
        if { [lindex $lRow 0] eq $pMode } {
            set lLabel [lindex $lRow 1]
        }
    }
    if { $lLabel eq "" } {
        ::mUtilMenu::Trace "unknown Schematic Check mode '$pMode'"
        catch { capDisplayMessageBox "Unknown Schematic Check mode:  $pMode" \
                                     "Schematic Check" }
        return true
    }

    ::mUtilMenu::Trace "Schematic Check mode '$pMode' - $lLabel"
    return [::mUtilMenu::RunSchematicCheckOnSelection [list $pMode]]
}

# Every ticked check, in dialog order, in ONE pass over the pages.
#
# Not a loop calling RunSchematicCheckMode per tick, which is what this was while
# only one check existed: two ticks would then mean reading the Project Manager
# selection twice, walking every page twice, and answering in two message boxes
# that each knew half of it.  The list of ticked modes goes down to CheckOnePage
# instead, and one page is dumped once and asked both questions.
#
# Nothing ticked is not an error worth a box of its own here - DoSchematicCheckStart
# catches that case before the dialog is taken down, which is the only place a
# user can cause it.
proc ::mUtilMenu::RunSchematicCheckSelected { } {
    set lModes [::mUtilMenu::ChkItemsSelected]

    ::mUtilMenu::Trace "Schematic Check - running [llength $lModes] check(s): $lModes"
    if { [llength $lModes] == 0 } {
        ::mUtilMenu::Out "Schematic Check - no check is ticked (SCH_CHECK_ITEM1 and SCH_CHECK_ITEM2 are both 0)"
        return true
    }

    return [::mUtilMenu::RunSchematicCheckOnSelection $lModes]
}

proc ::mUtilMenu::CloseSchematicCheck { } {
    variable mChkWin
    catch { destroy $mChkWin }
}

# Start: take the dialog down, then run every ticked check.  With nothing ticked
# there is nothing to take it down for, so it stays up and says so - the box is
# the only thing that could have got the user here.
proc ::mUtilMenu::DoSchematicCheckStart { } {
    if { [llength [::mUtilMenu::ChkItemsSelected]] == 0 } {
        catch { capDisplayMessageBox \
            "Please tick at least one check." "Schematic Check" }
        return true
    }

    ::mUtilMenu::CloseSchematicCheck
    return [::mUtilMenu::RunSchematicCheckSelected]
}

proc ::mUtilMenu::DoSchematicCheck { pVia } {
    variable mChkWin
    variable mChkModes

    ::mUtilMenu::Trace "Schematic Check callback reached via $pVia"
    ::mUtilMenu::ChkItemsNormalize

    # No Tk, no dialog.  A menu item that does nothing at all would be worse than
    # one that runs whatever the two globals already say, so this falls through to
    # them and says so in the Command Window - the same fallback shape
    # ShowResultWindow takes when it cannot build its window.
    if { [catch { package require Tk } lErr] } {
        ::mUtilMenu::Out "mUtil: Tk is not available ($lErr) - running Schematic Check from SCH_CHECK_ITEM1=$::SCH_CHECK_ITEM1 SCH_CHECK_ITEM2=$::SCH_CHECK_ITEM2 without the dialog"
        return [::mUtilMenu::RunSchematicCheckSelected]
    }

    ::mUtilMenu::HideTkRoot

    # Already open - bring it forward rather than building a second copy.
    if { [winfo exists $mChkWin] } {
        catch {
            wm deiconify $mChkWin
            raise $mChkWin
            focus $mChkWin
        }
        return true
    }

    toplevel $mChkWin
    wm title $mChkWin "Schematic Check"
    wm resizable $mChkWin 1 0
    wm protocol $mChkWin WM_DELETE_WINDOW "::mUtilMenu::CloseSchematicCheck"

    # Owned by the Capture main window so it cannot get lost behind it -
    # SetAppWindowAsParent, PDF p.134, same as the Schematic Compare dialog.
    catch { SetAppWindowAsParent [expr { [winfo id $mChkWin] }] }

    set lBody $mChkWin.body
    frame $lBody -padx 10 -pady 10
    pack $lBody -side top -fill both -expand 1

    label $lBody.hdr -anchor w -justify left \
        -text "Check what the Project Manager has selected for:"
    pack $lBody.hdr -side top -fill x -pady {0 6}

    # One checkbutton per mChkModes row, each on its own global, so the tick and
    # the variable are the same thing and Start reads the answer straight out of
    # them.  -onvalue/-offvalue are spelled out because Tk's defaults are 1 and 0
    # only by convention and this file is what promises they are 1 and 0.
    set lN 0
    foreach lRow $mChkModes {
        incr lN
        checkbutton $lBody.mode$lN -anchor w -justify left \
            -text [lindex $lRow 1] \
            -onvalue 1 -offvalue 0 \
            -variable ::[lindex $lRow 2]
        pack $lBody.mode$lN -side top -fill x -pady 2
    }

    # bottom: Start / Close
    set lBtns $mChkWin.btns
    frame $lBtns -padx 10
    pack $lBtns -side bottom -fill x

    button $lBtns.start -text "Start" -width 12 -default active \
        -command "::mUtilMenu::DoSchematicCheckStart"
    button $lBtns.close -text "Close" -width 12 \
        -command "::mUtilMenu::CloseSchematicCheck"

    pack $lBtns.close -side right -padx {6 0} -pady {4 10}
    pack $lBtns.start -side right          -pady {4 10}

    bind $mChkWin <Return> "::mUtilMenu::DoSchematicCheckStart"
    bind $mChkWin <Escape> "::mUtilMenu::CloseSchematicCheck"

    focus $lBtns.start
    return true
}

# Work out WHAT the Project Manager has selected, then run pModes over every page
# under it.  This is the whole of the scope resolution, and it is shared: which
# checks are running changes what CheckOnePage does with a page, never which pages
# there are.
#
# pModes defaults to the grid check alone, which is what this proc was before
# there was more than one check to run.
proc ::mUtilMenu::RunSchematicCheckOnSelection { {pModes {grid}} } {
    variable mChkBatchDetail

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

    # This block is the raw material for working out what the PM commands return,
    # so it is BUILT always - but held rather than printed, because the scope it
    # belongs to is not known yet and a wide scope prints nothing.  Flushed below
    # for a single page, for mChkBatchDetail, and on every way out that failed:
    # the failures are exactly when somebody needs to see it.
    set lDiag [list]
    lappend lDiag "================================================================"
    lappend lDiag [::mUtilMenu::Banner "Schematic Check - Project Manager selection"]
    lappend lDiag "================================================================"
    lappend lDiag [format "  %-22s %s" "GetSelectedPMItems" \
              [expr { $lAsked ? $lItems : "ERROR / not available" }]]
    lappend lDiag [format "  %-22s %s" "GetPMItemName"      [::mUtilMenu::OrDash $lItemName]]
    lappend lDiag [format "  %-22s %s" "GetPMItemType"      [::mUtilMenu::OrDash $lItemType]]
    lappend lDiag [format "  %-22s %s" "GetActiveOpjName"   [::mUtilMenu::OrDash $lOpj]]
    lappend lDiag [format "  %-22s %s" "active design file" [::mUtilMenu::OrDash $lDsn]]
    lappend lDiag [format "  %-22s %s" "active design root" [::mUtilMenu::OrDash $lDsnRoot]]

    set lHits [list]
    foreach lLabel $lItems {
        set lCls  [::mUtilMenu::ClassifyPMItem $lLabel $lDsn $lDsnRoot $lOpj]
        set lKind [lindex $lCls 0]
        lappend lDiag [format "    %-34s -> %s" $lLabel $lKind]
        if { $lKind ne "other" } {
            lappend lHits [list $lKind $lLabel [lindex $lCls 1]]
        }
    }

    if { [llength $lHits] == 0 } {
        ::mUtilMenu::OutLines $lDiag
        if { !$lAsked } {
            set lMsg "Could not read the Project Manager selection.\n\nIs a project open, and is PROJECT_MANAGER_VIEW the active window?"
        } elseif { [llength $lItems] == 0 } {
            set lMsg "Nothing is selected in the Project Manager.\n\nClick a page, a schematic, the Design (.DSN) or the Project (.OPJ) and try again."
        } else {
            set lMsg "The Project Manager selection is not a page, a schematic, a Design or a Project.\n\nSelected:  [join $lItems {, }]\n\nClick a page, a schematic, the Design (.DSN) or the Project (.OPJ) and try again."
        }
        ::mUtilMenu::Out "  -> not a page, schematic, Design or Project"
        catch { capDisplayMessageBox $lMsg "Schematic Check" }
        return true
    }

    # ONE hit decides the scope, and the narrowest one wins: clicking a page in a
    # tree whose Design node is also selected means that page.  Ordered narrow to
    # wide, and the whole selection is scanned for each kind in turn rather than
    # taking the first hit in tree order.
    set lPick ""
    foreach lKind { page schematic design project } {
        foreach lHit $lHits {
            if { [lindex $lHit 0] eq $lKind } {
                set lPick $lHit
                break
            }
        }
        if { $lPick ne "" } {
            break
        }
    }

    set lKind  [lindex $lPick 0]
    set lLabel [lindex $lPick 1]
    set lWhat  [lindex $lPick 2]

    # What to call the scope in the report.  A handle is no use to a reader, so a
    # design handle is resolved back to its file and a schematic to its name.
    set lScope "[string totitle $lKind] [::mUtilMenu::OrDash $lLabel]"
    if { [::mUtilMenu::PMItemDboClass $lLabel] ne "" } {
        switch -- $lKind {
            design {
                set lPath [::mUtilMenu::DesignPathOf $lWhat]
                if { $lPath ne "" } {
                    set lScope "Design [file tail $lPath]"
                }
            }
            schematic {
                if { [::mUtilMenu::BindDboHandle $lWhat DboSchematic] } {
                    set lScope "Schematic [::mUtilMenu::CStr $lWhat GetName]"
                }
            }
            page {
                if { [::mUtilMenu::BindDboHandle $lWhat DboPage] } {
                    set lScope "Page [::mUtilMenu::CStr $lWhat GetName]"
                }
            }
        }
    } elseif { $lKind eq "design" || $lKind eq "project" } {
        set lScope "[string totitle $lKind] [file tail $lWhat]"
    }

    # A single selected page is the only scope that talks to the Command Window.
    # Everything wider is silent unless mChkBatchDetail says otherwise - see the
    # variable, and RunSchematicCheck's pLoud.
    set lLoud [expr { $lKind eq "page" || $mChkBatchDetail }]

    # Everything under it, as objects.  A schematic / design / project is "every
    # page below this one"; a page is a one-page list, so the run below is the
    # same code either way.
    set lPairs [::mUtilMenu::PagesForPMItem $lKind $lWhat $lDsn]
    lappend lDiag "  -> $lScope: [llength $lPairs] page(s) to check"
    if { $lLoud || [llength $lPairs] == 0 } {
        ::mUtilMenu::OutLines $lDiag
    }

    if { [llength $lPairs] == 0 } {
        set lMsg "$lScope\n\nNo pages could be read under it."
        if { $lKind eq "project" && $lDsn eq "" } {
            append lMsg "\n\nA .OPJ names no design of its own, so the design the\nProject Manager has open is the one that would be used -\nand it did not report one.  Click the .DSN instead."
        }
        catch { capDisplayMessageBox $lMsg "Schematic Check" }
        return true
    }

    return [::mUtilMenu::RunSchematicCheck $lPairs $lScope $lLoud $pModes $lKind]
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

    # One line at load, so the Command Window says which build is in place before
    # anything is run with it.  Through Out, so mQuiet still governs it.
    ::mUtilMenu::Out "[::mUtilMenu::VerStr] loaded"
}

proc ::mUtilMenu::remove { } {
    ::mUtilMenu::CloseSchematicCompare
    ::mUtilMenu::CloseSchematicCheck
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
    # diag is the one place the full identification is printed - see mAuthor.
    ::mUtilMenu::Out [::mUtilMenu::Banner "diagnostics"]
    ::mUtilMenu::Out "  [::mUtilMenu::About]"
    ::mUtilMenu::Out "--- commands present ---"
    foreach c { capCloseChildViewsExceptCurrent capCloseChildViews \
                EnableAllButCurrentWindowCloseMenu EnableAllWindowCloseMenu \
                GetActivePM Open AddAccessoryMenu \
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
