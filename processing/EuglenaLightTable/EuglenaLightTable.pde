/**
 * EuglenaLightTable
 *
 * A multi-dish light table for euglena phototaxis experiments.
 * Displays 6 circular spots in a 2x3 grid arrangement.
 *
 * Controls:
 *   w - Set ALL dishes to white
 *   b - Set ALL dishes to black
 *   x - Set ALL dishes to magenta X pattern
 *   m - Toggle Experiment / Color Reference mode
 *   h - Toggle help overlay
 *   f - Toggle fullscreen
 *   s - Save settings
 *   1-6 - Cycle individual dish state
 *   Shift+1-6 - Set dish directly to X pattern
 */

// Mode constants
final int MODE_EXPERIMENT = 0;
final int MODE_COLOR_REFERENCE = 1;

// Global state
int currentMode = MODE_EXPERIMENT;
boolean showHelp = false;
DishSpot[] dishes;
ColorReference colorRef;
Settings settings;

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

  // Apply saved states
  for (int i = 0; i < 6; i++) {
    dishes[i].setState(settings.dishStates[i]);
  }

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
  if (currentMode == MODE_EXPERIMENT) {
    background(0);
    drawExperimentMode();
  } else {
    background(255);  // White background for color matching
    colorRef.draw();
  }

  if (showHelp) {
    drawHelp();
  }
}

void drawExperimentMode() {
  // Draw all dish spots
  for (DishSpot dish : dishes) {
    dish.draw();
  }

  // Draw mode indicator (small text in corner)
  fill(50);
  textAlign(LEFT, BOTTOM);
  textSize(12);
  text("EXPERIMENT MODE - Press 'h' for help", 10, height - 10);
}

void drawHelp() {
  // Semi-transparent overlay
  fill(0, 200);
  rect(0, 0, width, height);

  // Help text
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("EuglenaLightTable Controls", width/2, 60);

  textSize(16);
  textAlign(LEFT, TOP);

  String[] helpLines;
  if (currentMode == MODE_EXPERIMENT) {
    helpLines = new String[] {
      "GLOBAL CONTROLS:",
      "  w - Set ALL dishes to WHITE",
      "  b - Set ALL dishes to BLACK",
      "  x - Set ALL dishes to MAGENTA X",
      "",
      "INDIVIDUAL DISH CONTROLS:",
      "  1-6 - Cycle dish state (white → black → X)",
      "  Shift + 1-6 - Set dish directly to X pattern",
      "",
      "OTHER:",
      "  m - Switch to Color Reference mode",
      "  f - Toggle fullscreen",
      "  s - Save settings",
      "  h - Toggle this help",
      "  ESC - Exit"
    };
  } else {
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
      "  m - Switch to Experiment mode",
      "  f - Toggle fullscreen",
      "  h - Toggle this help",
      "  ESC - Exit"
    };
  }

  float y = 120;
  for (String line : helpLines) {
    text(line, 100, y);
    y += 24;
  }
}

void keyPressed() {
  // Handle Shift+number for direct X pattern
  if (key >= '!' && key <= '&') {  // Shift+1 through Shift+6
    int dishIndex = "!@#$%^&".indexOf(key);
    if (dishIndex >= 0 && dishIndex < 6 && currentMode == MODE_EXPERIMENT) {
      dishes[dishIndex].setState(DishSpot.STATE_X);
      settings.dishStates[dishIndex] = DishSpot.STATE_X;
    }
    return;
  }

  switch (key) {
    case 'w':
    case 'W':
      if (currentMode == MODE_EXPERIMENT) {
        setAllDishes(DishSpot.STATE_WHITE);
      }
      break;

    case 'b':
    case 'B':
      if (currentMode == MODE_EXPERIMENT) {
        setAllDishes(DishSpot.STATE_BLACK);
      }
      break;

    case 'x':
    case 'X':
      if (currentMode == MODE_EXPERIMENT) {
        setAllDishes(DishSpot.STATE_X);
      }
      break;

    case 'm':
    case 'M':
      currentMode = (currentMode == MODE_EXPERIMENT) ? MODE_COLOR_REFERENCE : MODE_EXPERIMENT;
      // Show cursor in Color Reference mode for clicking, hide in Experiment mode
      if (currentMode == MODE_COLOR_REFERENCE) {
        cursor();
      } else {
        noCursor();
      }
      break;

    case 'h':
    case 'H':
      showHelp = !showHelp;
      break;

    case 'f':
    case 'F':
      // Toggle fullscreen (Processing handles this via surface)
      break;

    case 's':
    case 'S':
      settings.save();
      break;

    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
      if (currentMode == MODE_EXPERIMENT) {
        int dishIndex = key - '1';
        dishes[dishIndex].cycleState();
        settings.dishStates[dishIndex] = dishes[dishIndex].getState();
      }
      break;
  }
}

void setAllDishes(int state) {
  for (int i = 0; i < dishes.length; i++) {
    dishes[i].setState(state);
    settings.dishStates[i] = state;
  }
}

void mousePressed() {
  // Handle mouse clicks in Color Reference mode
  if (currentMode == MODE_COLOR_REFERENCE && !showHelp) {
    colorRef.handleClick(mouseX, mouseY);
  }
}
