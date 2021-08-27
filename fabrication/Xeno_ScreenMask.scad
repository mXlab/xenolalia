fit_gap=0.0;

base_screen_width=84.0;
base_screen_depth=55.0;
base_screen_height=6.0;
base_screen_glass_height=1.25;

mask_thickness=1.0;
tabs_thickness=1.0;
tabs_width=6.0;
tabs_height=3.0;
tabs_buldge_thickness=0.2;

screen_width=base_screen_width + 2*tabs_thickness + fit_gap;
screen_depth=base_screen_depth + 2*tabs_thickness + fit_gap;
screen_height=6.0;

hole_diameter=50.0;

difference() {
    union() {
        // Base screen.
        cube([screen_width, screen_depth, mask_thickness]);
        
        // Tabs.
        translate([0, 0, mask_thickness])
        union() {
            translate([screen_width*0.25, screen_depth, 0]) rotate([0,0, 180])
                screen_tab();
            translate([screen_width*0.75, screen_depth, 0]) rotate([0,0, 180])
                screen_tab();
            
            translate([screen_width*0.25, 0, 0])
                screen_tab();
            translate([screen_width*0.75, 0, 0])
                screen_tab();
            
            translate([0, screen_depth/2, 0]) rotate([0,0,-90])
                screen_tab();
            translate([screen_width, screen_depth/2, 0]) rotate([0,0,90])
                screen_tab();
        }
    }
    
    // Remove circle.
    translate([screen_width/2, screen_depth/2, 0])
        cylinder(h=screen_height, d=hole_diameter, $fn=512);
//    cube([screen_width, screen_depth, mask_thickness]);
    
}

module screen_tab() {
    translate([-tabs_width/2, 0, 0])
        union() {
            cube([tabs_width, tabs_thickness, tabs_height]);
            translate([0, 0, base_screen_glass_height])
            cube([tabs_width, tabs_thickness+tabs_buldge_thickness, tabs_height-base_screen_glass_height]);
        }
}