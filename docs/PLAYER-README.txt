HOLLOWMERE — BRINEWICK INTEGRATED ENGINEERING BUILD

This is an engine-verified PLAYABLE WORKING BUILD, not a completed Windows game.
Production geometry, progression thresholds and asset quality are provisional.
No native Windows windowed gameplay session has yet been certified.

MOVEMENT
 W/A/S/D   Move         Mouse        Look
 Shift     Sprint       Space        Jump
 Esc       Pause/menu

MANUAL SALVAGE
 Left mouse (hold)  Work on the first visible component with selected tool
 R                  Release completed work safely
 G+R twice          Deliberately confirm a bounded unsafe removal
 F                  Inspect material/support details
 E                  Discover a physical tool or investigate a story clue
 Q / 1–5            Change among physically found tools

CARRYING, COMPANY YARD AND PROGRESSION
 C       Lift/put down first-hit physical salvage lot
 U       Unload carried lot at receiving pad
 N       Register unloaded lot at the pad
 M       Sell registered lot at nearby company counter
 H       Manually process a staged lot beside a sorting bench
 J/K     Browse / purchase utility upgrades at the company counter
 B       Manually submit the current requisition at company counter;
         on a later B press, advance to the next act if permitted
 I       Inventory
 Tab     Tool radial

You start at the boatyard with hands. Several small scrap objects are
available without tools; the hammer is at Tomas's workshop. Other tool
placements and later acts are working implementations, not final content.
Salvage is never passively recovered, carried or sold. Supported structures
must be removed in a safe order to preserve intact material.

The separate old engineering yard can be launched with
  godot --path game -- --engineering-yard
Brinewick uses a separate user://saves/brinewick_world.hmsave.json slot.

ENGINE CHECKS are not the same as a Windows windowed player-feel test.
Report input, navigation, clipping, visibility, save and visual issues.
