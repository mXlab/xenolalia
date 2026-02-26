// ============================================================
//  Erlenmeyer Flask Cap with Helical Spiral Vent
//  Xenolalia / Euglena Culture Transport Cap v3
// ============================================================
//
//  VENT: A helical spiral channel that starts at the center-bottom
//        (flask interior) and exits at the center-top (atmosphere).
//        The channel is swept along a helix, creating a long
//        tortuous path for contamination resistance.
//
//  MEASURE YOUR FLASK before printing:
//    neck_id    = inner diameter of neck opening (mm)
//    neck_od    = outer diameter of neck rim (mm)
//    neck_depth = how deep the plug should sit (mm)
//
//  PRINT SETTINGS (PLA FLEX or PETG recommended):
//    Layer height : 0.2 mm
//    Perimeters   : 4
//    Infill       : 25%
//    No supports needed
//
// ============================================================

/* [Flask Neck Dimensions] */
neck_id_fitting = 1.8;
neck_depth_total = 44.5;
neck_id    = 40.2 + neck_id_fitting;   // inner diameter of flask neck (mm)
neck_od    = 50.2;   // outer diameter of flask neck rim (mm)
neck_depth = neck_depth_total*0.6;   // depth plug inserts into neck (mm)
taper_angle = 1.5;   // friction-fit taper in degrees

/* [Flange] */
flange_dia       = neck_od + 8.0;  // flange diameter (mm)
flange_thickness = 4.0;             // flange thickness (mm)
grip_ridges      = 8;               // number of grip ridges (0 = none)
grip_ridge_height = grip_ridges > 0 ? 1.0 : 0.0;            // grip ridge height (mm)

/* [Helical Vent] */
// Radius of the helix centerline from plug axis
// Keep enough wall: should be < (plug_top_dia/2 - channel_r - 1.5)
helix_radius = 4.0;

// Number of full turns in the helix
// More turns = longer path = better barrier
helix_turns = 4;

// Cross-section radius of the channel (circular tube)
//channel_r = 0.7;   // gives ~1.4mm diameter channel
//channel_r = 0.9;   // gives ~1.4mm diameter channel
channel_r = 2.0;   // gives ~1.4mm diameter channel

// Resolution of the helix sweep (points per full turn)
// Higher = smoother helix but slower render
helix_pts_per_turn = 48;

/* [Resolution] */
$fn = 128;
eps = 0.01;

// ============================================================
//  DERIVED DIMENSIONS
// ============================================================

plug_base_dia = neck_id;// - 0.4;


plug_top_dia  = plug_base_dia - 2 * neck_depth * tan(taper_angle);
total_pts     = helix_turns * helix_pts_per_turn;

// Usable vertical space inside plug for the helix
// Leave a small margin at top and bottom for end connectors
helix_z_margin = 2.0;
helix_height   = neck_depth - 2 * helix_z_margin;

// ============================================================
//  MODULES
// ============================================================

// --- Tapered plug (frustum) ---
module plug() {
    if (grip_ridges > 0) {
        translate([0, 0, flange_thickness])
            cylinder(
                h = grip_ridge_height,
                d = plug_base_dia
            );
    }
    translate([0, 0, flange_thickness+grip_ridge_height])
        cylinder(
            h  = neck_depth+channel_r,
            d1 = plug_base_dia,
            d2 = plug_top_dia
        );
}

// --- Flange with grip ridges ---
module flange() {
    cylinder(h = flange_thickness, d = flange_dia);
    if (grip_ridges > 0) {
        for (i = [0 : grip_ridges - 1]) {
            rotate([0, 0, i * (360 / grip_ridges)])
                translate([neck_id * 0.5, 0, flange_thickness])
                    scale([1, 0.3, 1])
                        cylinder(h = grip_ridge_height, d = flange_dia * 0.15, $fn = 32);
        }
    }
}

// --- Helix as a polyhedron via sphere sweep ---
//
//  Strategy: generate a list of points along the helix, then
//  hull() adjacent sphere pairs to form a smooth tube.
//  Entry connects vertically from plug bottom center to helix start.
//  Exit connects vertically from helix end to plug top center.
//
//  The helix starts at angle 0 (pointing in +X direction) at the
//  bottom of the helix zone, and ends after helix_turns rotations
//  at the top of the helix zone — at the same angular position,
//  so entry and exit vertical connectors are both on the +X side.
//  Both connectors then bend to center (x=0, y=0).

// Generate helix points
function helix_pt(i) =
    let(
        t     = i / total_pts,
        angle = t * helix_turns * 360,
        z     = flange_thickness/2 + helix_z_margin + t * helix_height
    )
    [helix_radius * cos(angle), helix_radius * sin(angle), z];

// Bottom connector: vertical line from (0,0,flange_thickness)
// up to helix start, with intermediate points for smooth hull
function entry_pt(i, n=8) =
    let(
        t = i / n,
        // interpolate x,y from 0,0 to helix_radius,0
        x = helix_radius * t,
        y = 0,
        z = 0 + channel_r + helix_z_margin * t
    )
    [x, y, z];

// Top connector: from helix end down to (0,0,top of plug)
function exit_pt(i, n=8) =
    let(
        t     = i / n,
        end_a = helix_turns * 360,   // end angle of helix
        x_end = helix_radius * cos(end_a),
        y_end = helix_radius * sin(end_a),
        z_end = flange_thickness + helix_z_margin + helix_height,
        z_top = flange_thickness + neck_depth,
        // interpolate from helix end to center top
        x = x_end * (1 - t),
        y = y_end * (1 - t),
        z = z_end + (z_top - z_end) * t
    )
    [x, y, z];

// Draw a sphere-swept tube along a list of points
module tube_along_points(pts) {
    for (i = [0 : len(pts) - 2]) {
        hull() {
            translate(pts[i])   sphere(r = channel_r, $fn = 12);
            translate(pts[i+1]) sphere(r = channel_r, $fn = 12);
        }
    }
}

module vent_helix() {
    connector_pts = 8;

    // Build entry connector points
    entry_points = [for (i = [0 : connector_pts]) entry_pt(i, connector_pts)];

    // Build helix points
    helix_points  = [for (i = [0 : total_pts])    helix_pt(i)];

    // Build exit connector points
    exit_points   = [for (i = [0 : connector_pts]) exit_pt(i, connector_pts)];

    // Draw each segment
    tube_along_points(entry_points);
    tube_along_points(helix_points);
    tube_along_points(exit_points);

    // Join entry to helix start
    hull() {
        translate(entry_pt(connector_pts, connector_pts)) sphere(r = channel_r, $fn = 12);
        translate(helix_pt(0))                            sphere(r = channel_r, $fn = 12);
    }

    // Join helix end to exit start
    hull() {
        translate(helix_pt(total_pts))           sphere(r = channel_r, $fn = 12);
        translate(exit_pt(0, connector_pts))     sphere(r = channel_r, $fn = 12);
    }

    // Entry opening: cylinder flush with plug bottom face
    translate([0, 0, 0 - channel_r])
        cylinder(h = 2*channel_r + eps, r1 = 2*channel_r, r2=channel_r, $fn = 12);

    // Exit opening: cylinder flush with plug top face
    translate([0, 0, flange_thickness + neck_depth - eps])
        cylinder(h = 2*channel_r + eps, r = channel_r, $fn = 12);
}

// ============================================================
//  MAIN ASSEMBLY
// ============================================================

difference() {
    union() {
        flange();
        plug();
    }
    vent_helix();
}

// ============================================================
//  END OF FILE
// ============================================================
