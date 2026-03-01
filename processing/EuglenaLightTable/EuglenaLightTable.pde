/**
 * EuglenaLightTable
 *
 * A multi-dish light table for euglena phototaxis experiments.
 * Displays 12 circular spots in a 4+4+4 hex grid arrangement.
 *
 * Modes:
 *   Experiment Mode - Display dishes with current settings
 *   Symbol Edit Mode - Edit symbol properties (shape, color, width)
 *   Color Reference Mode - Match euglena medium color
 *
 * Controls:
 *   e - Switch to Symbol Edit mode
 *   m - Switch to Color Reference mode
 *   h - Toggle help overlay
 *   s - Save settings (in Experiment mode)
 */

// Mode constants
final int MODE_EXPERIMENT    = 0;
final int MODE_SYMBOL_EDIT   = 1;
final int MODE_COLOR_REFERENCE = 2;

// Global state
int currentMode = MODE_EXPERIMENT;
boolean showHelp = false;
DishSpot[] dishes;
ColorReference colorRef;
Settings settings;

// Symbol edit state
boolean[] dishSelected;  // per-dish selection flags

// Hex layout parameters — set in initializeDishes(), used for overlay positioning
float hexX0, hexY0, hexS, hexDiam;

// Modifier key tracking for mouse multi-select
boolean shiftHeld = false;
boolean ctrlHeld  = false;

// Flash state (temporary white with auto-return to symbol)
boolean flashActive = false;
int flashEndTime = 0;
final int FLASH_DURATION = 15000;  // 15 seconds per press

// Timer / overlay state
boolean timerRunning = false;
boolean timerPaused = false;
boolean timerPausedByFlash = false;
int timerStartMillis = 0;    // millis() when current run segment started
int timerElapsedMs = 0;      // accumulated ms before current segment
boolean showOverlay = false;       // manually toggled with 'T'
boolean flashShowsOverlay = false; // auto-shown during flash, cleared when flash ends

void setup() {
  fullScreen();
  // size(1920, 1080);  // Uncomment for windowed testing

  // Initialize settings
  settings = new Settings(sketchPath("settings.json"));
  settings.load();

  // Initialize dish spots (3 rows x 4 columns hex grid)
  dishes = new DishSpot[12];
  dishSelected = new boolean[12];
  for (int i = 0; i < 12; i++) dishSelected[i] = true;
  initializeDishes();

  // Initialize color reference grid
  colorRef = new ColorReference();

  // Apply saved settings
  settings.applyToAllDishes(dishes);

  noCursor();
}

void initializeDishes() {
  int N_ROWS = 3;
  int N_COLS = 4;
  float fill = 0.9;  // diameter / spacing ratio (0.9 = half the gap vs 0.8)

  float marginX = width  * 0.05;
  float marginY = height * 0.04;
  float availW  = width  - 2 * marginX;
  float availH  = height - 2 * marginY;

  // Solve for spacing S so the hex arrangement fits within available area.
  // Horizontal span of all centers: (N_COLS - 0.5) * S  (odd row extends S/2 right)
  // Vertical span of all centers:   (N_ROWS - 1) * S * sqrt(3)/2
  // Adding one dish diameter (fill*S) gives total edge-to-edge span.
  float S = min(
    availW / (N_COLS - 0.5 + fill),
    availH / ((N_ROWS - 1) * sqrt(3) / 2.0 + fill)
  );
  float diameter = S * fill;

  // Center the full arrangement on screen
  float x0 = width  / 2.0 - (N_COLS - 0.5) * S / 2.0;
  float y0 = height / 2.0 - (N_ROWS - 1) * S * sqrt(3) / 4.0;

  // Store layout params for overlay positioning
  hexX0   = x0;
  hexY0   = y0;
  hexS    = S;
  hexDiam = diameter;

  int index = 0;
  for (int row = 0; row < N_ROWS; row++) {
    float y       = y0 + row * S * sqrt(3) / 2.0;
    float xOffset = (row % 2 == 1) ? S / 2.0 : 0;
    for (int col = 0; col < N_COLS; col++) {
      float x = x0 + xOffset + col * S;
      dishes[index] = new DishSpot(x, y, diameter, index + 1);
      index++;
    }
  }
}

void draw() {
  background(0);

  switch (currentMode) {
    case MODE_EXPERIMENT:
      drawExperimentMode();
      break;
    case MODE_SYMBOL_EDIT:
      drawSymbolEditMode();
      break;
    case MODE_COLOR_REFERENCE:
      background(255);
      colorRef.draw();
      break;
  }

  if (showHelp) {
    drawHelp();
  }
}

void drawExperimentMode() {
  // Check flash timer
  if (flashActive && millis() >= flashEndTime) {
    flashActive = false;
    flashShowsOverlay = false;
    setAllDishesState(DishSpot.STATE_SYMBOL);
    if (timerPausedByFlash) {
      timerPausedByFlash = false;
      resumeTimer();
    }
  }

  for (DishSpot dish : dishes) {
    dish.draw();
  }

  if (showOverlay || flashShowsOverlay) {
    drawTimerOverlay();
  }

  fill(50);
  textAlign(LEFT, BOTTOM);
  textSize(12);
  if (flashActive) {
    int remaining = ceil((flashEndTime - millis()) / 1000.0);
    text("FLASH - returning to symbol in " + remaining + "s", 10, height - 10);
  } else {
    text("EXPERIMENT MODE - 'r'=Start timer  'p'=Pause/Resume  't'=Toggle display  'e'=Edit  'm'=Color Ref  'h'=Help", 10, height - 10);
  }
}

void drawTimerOverlay() {
  rectMode(CORNER);

  java.time.LocalDateTime _now = java.time.LocalDateTime.now();
  String dateStr = String.format("%04d-%02d-%02d", _now.getYear(), _now.getMonthValue(), _now.getDayOfMonth());
  String timeStr = String.format("%02d:%02d:%02d", _now.getHour(), _now.getMinute(), _now.getSecond());

  // Right edge of even rows (rows 0 and 2) — left boundary of the right-side empty areas
  float rightEdge  = hexX0 + 3 * hexS + hexDiam / 2;  // (N_COLS-1)*S + D/2
  float row1CenterY = hexY0 + hexS * sqrt(3) / 2;

  // Top-right empty area: right of even rows, above row 1 level
  float trTop    = hexY0 - hexDiam / 2;          // top edge of row 0 dishes
  float trBottom = row1CenterY - hexDiam / 2;    // top edge of row 1 dishes

  // Bottom-right empty area: right of even rows, below row 1 level
  float brTop    = row1CenterY + hexDiam / 2;    // bottom edge of row 1 dishes
  float brBottom = hexY0 + hexS * sqrt(3) + hexDiam / 2;  // bottom edge of row 2

  float textRightX = width - 30;
  float panelLeft  = rightEdge + 10;
  float panelRight = width - 10;

  noStroke();

  // --- Top-right: date (above) then time (below) ---
  float trCenterY = (trTop + trBottom) / 2;
  float dateSize  = hexDiam * 0.11;
  float timeSize  = hexDiam * 0.16;
  float gap       = hexDiam * 0.10;

  textAlign(RIGHT, BOTTOM);
  textSize(dateSize);
  fill(150);
  text(dateStr, textRightX, trCenterY - gap / 2);

  textAlign(RIGHT, TOP);
  textSize(timeSize);
  fill(255);
  text(timeStr, textRightX, trCenterY + gap / 2);

  // --- Bottom-right: experiment timer (clears all dishes) ---
  float panelW = panelRight - panelLeft;
  float panelH = hexDiam * 0.35;
  float panelY = (brTop + brBottom) / 2 - panelH / 2;

  fill(0, 210);
  rect(panelLeft, panelY, panelW, panelH, 8);

  fill(120);
  textAlign(LEFT, TOP);
  textSize(hexDiam * 0.07);
  text("EXPERIMENT TIMER", panelLeft + 10, panelY + 8);

  String timerStr;
  if (!timerRunning) {
    timerStr = "--:--";
    fill(90);
  } else {
    int elapsed  = getTimerElapsedMs();
    int totalSec = elapsed / 1000;
    int mins     = totalSec / 60;
    int secs     = totalSec % 60;
    if (mins >= 60) {
      int hours = mins / 60;
      mins = mins % 60;
      timerStr = String.format("%02d:%02d:%02d", hours, mins, secs);
    } else {
      timerStr = String.format("%02d:%02d", mins, secs);
    }
    fill(timerPaused ? color(255, 200, 60) : color(255));
  }
  textSize(hexDiam * 0.20);
  textAlign(LEFT, TOP);
  text(timerStr, panelLeft + 10, panelY + panelH * 0.35);
}

void drawSymbolEditMode() {
  // Draw all dish spots with selection highlight
  for (int i = 0; i < dishes.length; i++) {
    dishes[i].draw(dishSelected[i]);
  }

  // Count selected dishes and find first selected
  int numSelected   = 0;
  int firstSelected = -1;
  for (int i = 0; i < dishes.length; i++) {
    if (dishSelected[i]) {
      numSelected++;
      if (firstSelected == -1) firstSelected = i;
    }
  }

  // Draw editing info panel at top
  rectMode(CORNER);
  fill(40);
  noStroke();
  rect(0, 0, width, 80);

  fill(255);
  textAlign(CENTER, TOP);
  textSize(20);
  text("SYMBOL EDIT MODE", width/2, 10);

  textSize(14);
  String selectionText;
  if (numSelected == dishes.length) {
    selectionText = "ALL DISHES";
  } else if (numSelected == 0) {
    selectionText = "NONE";
  } else if (numSelected == 1) {
    selectionText = "Dish " + (firstSelected + 1);
  } else {
    selectionText = numSelected + " dishes";
  }
  text("Selected: " + selectionText, width/2, 38);

  // Show current properties of first selected dish
  if (firstSelected >= 0) {
    DishSpot ref = dishes[firstSelected];
    textSize(12);
    text("Shape: " + ref.getShapeName() +
         "  |  Color: " + ref.getColorName() +
         "  |  Width: " + ref.getWidthName() +
         "  |  Lightness: " + ref.getLightnessName(),
         width/2, 58);
  }

  // Draw controls reminder at bottom
  fill(50);
  textAlign(LEFT, BOTTOM);
  textSize(12);
  text("Click=Select  Shift+Click=Add  Ctrl+Click=Toggle  a=All  " +
       "s=Shape  c=Color  t=Thickness  l=Lightness  d=Default  " +
       "w=White  b=Black  ESC/e=Done  h=Help",
       10, height - 10);
}

void drawHelp() {
  rectMode(CORNER);
  fill(0, 200);
  rect(0, 0, width, height);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("EuglenaLightTable Controls", width/2, 60);

  textSize(16);
  textAlign(LEFT, TOP);

  String[] helpLines;

  switch (currentMode) {
    case MODE_EXPERIMENT:
      helpLines = new String[] {
        "EXPERIMENT MODE:",
        "  Displays the configured dish patterns",
        "",
        "QUICK CONTROLS:",
        "  w - Set ALL dishes to WHITE",
        "  b - Set ALL dishes to BLACK",
        "  x - Set ALL dishes to SYMBOL",
        "  r - Start/restart experiment timer + set dishes to SYMBOL",
        "  p - Pause / resume timer",
        "  f - Flash WHITE (auto-return to SYMBOL in 15s, stacks)",
        "  t - Toggle timer/clock display",
        "",
        "NOTE: Timer pauses automatically during flash, resumes on return",
        "",
        "MODE SWITCHING:",
        "  e - Symbol Edit mode (configure patterns)",
        "  m - Color Reference mode (match medium color)",
        "",
        "OTHER:",
        "  s - Save settings",
        "  h - Toggle this help",
        "  ESC - Exit"
      };
      break;

    case MODE_SYMBOL_EDIT:
      helpLines = new String[] {
        "SYMBOL EDIT MODE:",
        "  Configure the symbol shown in each dish",
        "",
        "SELECTION:",
        "  Click          - Select one dish (deselects others)",
        "  Shift+Click    - Add dish to selection",
        "  Ctrl+Click     - Toggle dish selection",
        "  a              - Select ALL dishes",
        "",
        "EDIT PROPERTIES (apply to all selected):",
        "  s - Cycle shape (X -> Circle -> Bars)",
        "  c - Cycle color (Red -> Magenta -> Blue -> Cyan -> Yellow -> White)",
        "  t - Cycle thickness (Thin -> Medium -> Large)",
        "  l - Cycle lightness (25% -> 50% -> 75% -> 100%)",
        "  d - Reset to default (X / Medium / Magenta / 100%)",
        "",
        "QUICK SET:",
        "  w - Set selected to white (no symbol)",
        "  b - Set selected to black (no symbol)",
        "",
        "EXIT:",
        "  e or ESC - Return to Experiment mode",
        "  h        - Toggle this help"
      };
      break;

    case MODE_COLOR_REFERENCE:
      helpLines = new String[] {
        "COLOR REFERENCE MODE:",
        "  1. Click a swatch in the main grid to select it",
        "  2. The color appears in the Fine Tuning panel (right)",
        "  3. Click surrounding variations to refine",
        "  4. Use Sat +/- buttons to adjust saturation",
        "  5. Repeat until you match your euglena medium",
        "",
        "CONTROLS:",
        "  Click - Select color / variation",
        "  m - Return to Experiment mode",
        "  h - Toggle this help",
        "  ESC - Exit"
      };
      break;

    default:
      helpLines = new String[] {};
  }

  float y = 120;
  for (String line : helpLines) {
    text(line, 100, y);
    y += 24;
  }
}

void keyPressed() {
  // Track modifier keys
  if (keyCode == SHIFT)   shiftHeld = true;
  if (keyCode == CONTROL) ctrlHeld  = true;

  // Global keys
  switch (key) {
    case 'h':
    case 'H':
      showHelp = !showHelp;
      return;
  }

  // Mode-specific keys
  switch (currentMode) {
    case MODE_EXPERIMENT:      handleExperimentKeys();    break;
    case MODE_SYMBOL_EDIT:     handleSymbolEditKeys();    break;
    case MODE_COLOR_REFERENCE: handleColorReferenceKeys(); break;
  }
}

void keyReleased() {
  if (keyCode == SHIFT)   shiftHeld = false;
  if (keyCode == CONTROL) ctrlHeld  = false;
}

void handleExperimentKeys() {
  switch (key) {
    case 'w': case 'W':
      flashActive = false;
      setAllDishesState(DishSpot.STATE_WHITE);
      break;

    case 'b': case 'B':
      flashActive = false;
      setAllDishesState(DishSpot.STATE_BLACK);
      break;

    case 'x': case 'X':
      flashActive = false;
      flashShowsOverlay = false;
      setAllDishesState(DishSpot.STATE_SYMBOL);
      if (timerPausedByFlash) {
        timerPausedByFlash = false;
        resumeTimer();
      }
      break;

    case 'r': case 'R':
      timerRunning      = true;
      timerPaused       = false;
      timerPausedByFlash = false;
      timerElapsedMs    = 0;
      timerStartMillis  = millis();
      setAllDishesState(DishSpot.STATE_SYMBOL);
      break;

    case 'p': case 'P':
      if (timerRunning) {
        if (timerPaused) {
          timerPausedByFlash = false;
          resumeTimer();
        } else {
          pauseTimer();
        }
      }
      break;

    case 't': case 'T':
      showOverlay = !showOverlay;
      break;

    case 'f': case 'F':
      if (flashActive) {
        flashEndTime += FLASH_DURATION;
      } else {
        flashActive  = true;
        flashEndTime = millis() + FLASH_DURATION;
        setAllDishesState(DishSpot.STATE_WHITE);
        if (timerRunning && !timerPaused) {
          pauseTimer();
          timerPausedByFlash = true;
        }
      }
      flashShowsOverlay = true;
      break;

    case 'e': case 'E':
      currentMode = MODE_SYMBOL_EDIT;
      cursor();
      for (int i = 0; i < dishes.length; i++) dishSelected[i] = true;
      setAllDishesState(DishSpot.STATE_SYMBOL);
      break;

    case 'm': case 'M':
      currentMode = MODE_COLOR_REFERENCE;
      cursor();
      break;

    case 's': case 'S':
      settings.saveFromDishes(dishes);
      break;
  }
}

void handleSymbolEditKeys() {
  switch (key) {
    // Select all
    case 'a': case 'A':
      for (int i = 0; i < dishes.length; i++) dishSelected[i] = true;
      break;

    // Reset selected to default
    case 'd': case 'D':
      applyToSelected(d -> d.resetToDefault());
      break;

    // Shape
    case 's': case 'S':
      applyToSelected(d -> d.cycleShape());
      break;

    // Color
    case 'c': case 'C':
      applyToSelected(d -> d.cycleColor());
      break;

    // Thickness
    case 't': case 'T':
      applyToSelected(d -> d.cycleWidth());
      break;

    // Lightness
    case 'l': case 'L':
      applyToSelected(d -> d.cycleLightness());
      break;

    // Quick set to white
    case 'w': case 'W':
      applyToSelected(d -> d.setState(DishSpot.STATE_WHITE));
      break;

    // Quick set to black
    case 'b': case 'B':
      applyToSelected(d -> d.setState(DishSpot.STATE_BLACK));
      break;

    // Exit symbol edit mode
    case 'e': case 'E':
      currentMode = MODE_EXPERIMENT;
      noCursor();
      settings.saveFromDishes(dishes);
      break;
  }

  // ESC to exit
  if (keyCode == ESC) {
    key = 0;  // Prevent Processing from exiting
    currentMode = MODE_EXPERIMENT;
    noCursor();
    settings.saveFromDishes(dishes);
  }
}

void handleColorReferenceKeys() {
  switch (key) {
    case 'm': case 'M':
      currentMode = MODE_EXPERIMENT;
      noCursor();
      break;
  }
}

// --- Functional interface for applying operations to dishes ---

interface DishOperation {
  void apply(DishSpot dish);
}

void applyToSelected(DishOperation op) {
  for (int i = 0; i < dishes.length; i++) {
    if (dishSelected[i]) op.apply(dishes[i]);
  }
}

void setAllDishesState(int state) {
  for (DishSpot dish : dishes) dish.setState(state);
}

// --- Mouse ---

int getDishAtPoint(float mx, float my) {
  for (int i = 0; i < dishes.length; i++) {
    float dx = mx - dishes[i].x;
    float dy = my - dishes[i].y;
    float r  = dishes[i].diameter / 2.0;
    if (dx*dx + dy*dy <= r*r) return i;
  }
  return -1;
}

void mousePressed() {
  if (currentMode == MODE_SYMBOL_EDIT && !showHelp) {
    int clicked = getDishAtPoint(mouseX, mouseY);
    if (clicked >= 0) {
      if (shiftHeld) {
        // Add to existing selection
        dishSelected[clicked] = true;
      } else if (ctrlHeld) {
        // Toggle individual dish
        dishSelected[clicked] = !dishSelected[clicked];
      } else {
        // Exclusive select
        for (int i = 0; i < dishes.length; i++) dishSelected[i] = false;
        dishSelected[clicked] = true;
      }
    }
  } else if (currentMode == MODE_COLOR_REFERENCE && !showHelp) {
    colorRef.handleClick(mouseX, mouseY);
  }
}

// --- Timer helpers ---

int getTimerElapsedMs() {
  if (!timerRunning) return 0;
  if (timerPaused)   return timerElapsedMs;
  return timerElapsedMs + (millis() - timerStartMillis);
}

void pauseTimer() {
  if (timerRunning && !timerPaused) {
    timerElapsedMs += millis() - timerStartMillis;
    timerPaused = true;
  }
}

void resumeTimer() {
  if (timerRunning && timerPaused) {
    timerStartMillis = millis();
    timerPaused = false;
  }
}
