/**
 * EuglenaLightTable
 *
 * A multi-dish light table for euglena phototaxis experiments.
 * Displays 6 circular spots in a 2x3 grid arrangement.
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
final int MODE_EXPERIMENT = 0;
final int MODE_SYMBOL_EDIT = 1;
final int MODE_COLOR_REFERENCE = 2;

// Global state
int currentMode = MODE_EXPERIMENT;
boolean showHelp = false;
DishSpot[] dishes;
ColorReference colorRef;
Settings settings;

// Symbol edit state
int selectedDish = -1;  // -1 = all dishes, 0-5 = individual dish

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
boolean showOverlay = false;      // manually toggled with 'T'
boolean flashShowsOverlay = false; // auto-shown during flash, cleared when flash ends

void setup() {
  fullScreen();
  // size(1200, 800);  // Uncomment for windowed testing

  // Initialize settings
  settings = new Settings(sketchPath("settings.json"));
  settings.load();

  // Initialize dish spots (2 rows x 3 columns)
  dishes = new DishSpot[6];
  initializeDishes();

  // Initialize color reference grid
  colorRef = new ColorReference();

  // Apply saved settings
  settings.applyToAllDishes(dishes);

  noCursor();
}

void initializeDishes() {
  // Calculate dish layout for 2 rows x 3 columns
  float marginX = width * 0.1;
  float marginY = height * 0.15;
  float availableWidth = width - 2 * marginX;
  float availableHeight = height - 2 * marginY;

  // Calculate spacing
  float spacingX = availableWidth / 3;
  float spacingY = availableHeight / 2;

  // Calculate dish diameter (fit within spacing with padding)
  float diameter = min(spacingX, spacingY) * 0.8;

  int index = 0;
  for (int row = 0; row < 2; row++) {
    for (int col = 0; col < 3; col++) {
      float x = marginX + spacingX * (col + 0.5);
      float y = marginY + spacingY * (row + 0.5);
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
  rectMode(CORNER);  // Reset in case drawSymbol() left rectMode as CENTER

  // --- Top bar: date and time ---
  float barH = 60;
  fill(0, 210);
  noStroke();
  rect(0, 0, width, barH);

  String dateStr = String.format("%04d-%02d-%02d", year(), month(), day());
  String timeStr = String.format("%02d:%02d:%02d", hour(), minute(), second());

  // Date on the left, time on the right, both large
  textAlign(LEFT, CENTER);
  textSize(30);
  fill(180);
  text(dateStr, 30, barH / 2);

  textAlign(RIGHT, CENTER);
  fill(255);
  text(timeStr, width - 30, barH / 2);

  // --- Bottom-right panel: experiment timer ---
  float panelW = 330;
  float panelH = 110;
  float panelX = width - panelW - 20;
  float panelY = height - panelH - 40;

  fill(0, 210);
  noStroke();
  rect(panelX, panelY, panelW, panelH, 8);

  fill(120);
  textAlign(LEFT, TOP);
  textSize(13);
  text("EXPERIMENT TIMER", panelX + 14, panelY + 10);

  String timerStr;
  if (!timerRunning) {
    timerStr = "--:--";
    fill(90);
  } else {
    int elapsed = getTimerElapsedMs();
    int totalSec = elapsed / 1000;
    int mins = totalSec / 60;
    int secs = totalSec % 60;
    if (mins >= 60) {
      int hours = mins / 60;
      mins = mins % 60;
      timerStr = String.format("%02d:%02d:%02d", hours, mins, secs);
    } else {
      timerStr = String.format("%02d:%02d", mins, secs);
    }
    fill(timerPaused ? color(255, 200, 60) : color(255));
  }
  textSize(52);
  textAlign(LEFT, TOP);
  text(timerStr, panelX + 14, panelY + 28);

  if (timerPaused) {
    fill(255, 200, 60);
    textSize(13);
    textAlign(RIGHT, TOP);
    text("PAUSED", panelX + panelW - 14, panelY + 10);
  }
}

void drawSymbolEditMode() {
  // Draw all dish spots with selection highlight
  for (int i = 0; i < dishes.length; i++) {
    boolean isSelected = (selectedDish == -1) || (selectedDish == i);
    dishes[i].draw(isSelected);
  }

  // Draw editing info panel at top
  fill(40);
  noStroke();
  rect(0, 0, width, 80);

  fill(255);
  textAlign(CENTER, TOP);
  textSize(20);
  text("SYMBOL EDIT MODE", width/2, 10);

  textSize(14);
  String selectionText = (selectedDish == -1) ? "ALL DISHES" : "Dish " + (selectedDish + 1);
  text("Selected: " + selectionText, width/2, 38);

  // Show current properties of selected dish(es)
  DishSpot refDish = (selectedDish == -1) ? dishes[0] : dishes[selectedDish];
  textSize(12);
  text("Shape: " + refDish.getShapeName() + "  |  Color: " + refDish.getColorName() + "  |  Width: " + refDish.getWidthName(), width/2, 58);

  // Draw controls reminder at bottom
  fill(50);
  textAlign(LEFT, BOTTOM);
  textSize(12);
  text("0/a=All  1-6=Select dish  s=Shape  c=Color  t=Thickness  w=White  b=Black  ESC/e=Done  h=Help", 10, height - 10);
}

void drawHelp() {
  // Semi-transparent overlay
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
        "  1-6 - Cycle individual dish state",
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
        "  0 or a - Select ALL dishes",
        "  1-6 - Select individual dish",
        "",
        "EDIT PROPERTIES:",
        "  s - Cycle shape (X → Circle → Bars)",
        "  c - Cycle color (Magenta → Cyan → Yellow → White)",
        "  t - Cycle thickness (Thin → Medium → Large)",
        "",
        "QUICK SET:",
        "  w - Set to white (no symbol)",
        "  b - Set to black (no symbol)",
        "",
        "EXIT:",
        "  e or ESC - Return to Experiment mode",
        "  h - Toggle this help"
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
  // Global keys
  switch (key) {
    case 'h':
    case 'H':
      showHelp = !showHelp;
      return;
  }

  // Mode-specific keys
  switch (currentMode) {
    case MODE_EXPERIMENT:
      handleExperimentKeys();
      break;
    case MODE_SYMBOL_EDIT:
      handleSymbolEditKeys();
      break;
    case MODE_COLOR_REFERENCE:
      handleColorReferenceKeys();
      break;
  }
}

void handleExperimentKeys() {
  switch (key) {
    case 'w':
    case 'W':
      flashActive = false;
      setAllDishesState(DishSpot.STATE_WHITE);
      break;

    case 'b':
    case 'B':
      flashActive = false;
      setAllDishesState(DishSpot.STATE_BLACK);
      break;

    case 'x':
    case 'X':
      flashActive = false;
      flashShowsOverlay = false;
      setAllDishesState(DishSpot.STATE_SYMBOL);
      if (timerPausedByFlash) {
        timerPausedByFlash = false;
        resumeTimer();
      }
      break;

    case 'r':
    case 'R':
      timerRunning = true;
      timerPaused = false;
      timerPausedByFlash = false;
      timerElapsedMs = 0;
      timerStartMillis = millis();
      setAllDishesState(DishSpot.STATE_SYMBOL);
      break;

    case 'p':
    case 'P':
      if (timerRunning) {
        if (timerPaused) {
          timerPausedByFlash = false;
          resumeTimer();
        } else {
          pauseTimer();
        }
      }
      break;

    case 't':
    case 'T':
      showOverlay = !showOverlay;
      break;

    case 'f':
    case 'F':
      if (flashActive) {
        flashEndTime += FLASH_DURATION;
      } else {
        flashActive = true;
        flashEndTime = millis() + FLASH_DURATION;
        setAllDishesState(DishSpot.STATE_WHITE);
        if (timerRunning && !timerPaused) {
          pauseTimer();
          timerPausedByFlash = true;
        }
      }
      flashShowsOverlay = true;
      break;

    case 'e':
    case 'E':
      currentMode = MODE_SYMBOL_EDIT;
      selectedDish = -1;  // Start with all selected
      // Show symbols on all dishes when entering edit mode
      setAllDishesState(DishSpot.STATE_SYMBOL);
      break;

    case 'm':
    case 'M':
      currentMode = MODE_COLOR_REFERENCE;
      cursor();
      break;

    case 's':
    case 'S':
      settings.saveFromDishes(dishes);
      break;

    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
      int dishIndex = key - '1';
      dishes[dishIndex].cycleState();
      break;
  }
}

void handleSymbolEditKeys() {
  switch (key) {
    // Selection keys
    case '0':
    case 'a':
    case 'A':
      selectedDish = -1;  // All dishes
      break;

    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
      selectedDish = key - '1';
      break;

    // Shape
    case 's':
    case 'S':
      applyToSelected(d -> d.cycleShape());
      break;

    // Color
    case 'c':
    case 'C':
      applyToSelected(d -> d.cycleColor());
      break;

    // Thickness
    case 't':
    case 'T':
      applyToSelected(d -> d.cycleWidth());
      break;

    // Quick set to white
    case 'w':
    case 'W':
      applyToSelected(d -> d.setState(DishSpot.STATE_WHITE));
      break;

    // Quick set to black
    case 'b':
    case 'B':
      applyToSelected(d -> d.setState(DishSpot.STATE_BLACK));
      break;

    // Exit symbol edit mode
    case 'e':
    case 'E':
      currentMode = MODE_EXPERIMENT;
      settings.saveFromDishes(dishes);
      break;
  }

  // ESC to exit
  if (keyCode == ESC) {
    key = 0;  // Prevent Processing from exiting
    currentMode = MODE_EXPERIMENT;
    settings.saveFromDishes(dishes);
  }
}

void handleColorReferenceKeys() {
  switch (key) {
    case 'm':
    case 'M':
      currentMode = MODE_EXPERIMENT;
      noCursor();
      break;
  }
}

// Functional interface for applying operations to dishes
interface DishOperation {
  void apply(DishSpot dish);
}

void applyToSelected(DishOperation op) {
  if (selectedDish == -1) {
    // Apply to all dishes
    for (DishSpot dish : dishes) {
      op.apply(dish);
    }
  } else {
    // Apply to selected dish only
    op.apply(dishes[selectedDish]);
  }
}

void setAllDishesState(int state) {
  for (DishSpot dish : dishes) {
    dish.setState(state);
  }
}

int getTimerElapsedMs() {
  if (!timerRunning) return 0;
  if (timerPaused) return timerElapsedMs;
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

void mousePressed() {
  if (currentMode == MODE_COLOR_REFERENCE && !showHelp) {
    colorRef.handleClick(mouseX, mouseY);
  }
}
