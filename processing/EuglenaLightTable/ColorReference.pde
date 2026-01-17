/**
 * ColorReference
 *
 * Displays a grid of color swatches for matching euglena medium color.
 * Shows greens and browns at varying saturation and brightness levels.
 * Includes a fine-tuning panel for iterative color matching.
 */
class ColorReference {
  // Grid of color swatches
  ArrayList<ColorSwatch> swatches;

  // Layout for main grid
  int cols = 8;
  int rows = 8;
  float swatchSize;
  float marginX, marginY;
  float spacing = 10;

  // Fine-tuning panel
  color selectedColor;
  boolean hasSelection = false;
  float fineTuneX, fineTuneY;
  float fineTuneSize;
  float variationSize;
  ColorSwatch[] variations;  // 3x3 grid: center is selected, surrounding are variations

  // Variation step sizes (how much to change per iteration)
  float hueStep = 5;
  float satStep = 8;
  float briStep = 8;

  ColorReference() {
    swatches = new ArrayList<ColorSwatch>();
    variations = new ColorSwatch[9];
    generateColors();
  }

  void generateColors() {
    swatches.clear();

    // Generate greens and browns/olive tones typical of euglena cultures
    int[][] hueRanges = {
      {100, 130},  // Pure green
      {85, 100},   // Yellow-green
      {60, 85},    // Olive green
      {30, 60}     // Brown/olive
    };

    for (int rangeIdx = 0; rangeIdx < hueRanges.length; rangeIdx++) {
      int hueMin = hueRanges[rangeIdx][0];
      int hueMax = hueRanges[rangeIdx][1];

      // Two rows per hue range - pale colors for dilute euglena medium
      for (int rowOffset = 0; rowOffset < 2; rowOffset++) {
        for (int col = 0; col < cols; col++) {
          float hue = map(col, 0, cols - 1, hueMin, hueMax);

          float sat, bri;
          if (rowOffset == 0) {
            // Very pale row
            sat = map(col, 0, cols - 1, 8, 25);
            bri = map(col, 0, cols - 1, 98, 88);
          } else {
            // Slightly more saturated row
            sat = map(col, 0, cols - 1, 20, 45);
            bri = map(col, 0, cols - 1, 95, 80);
          }

          colorMode(HSB, 360, 100, 100);
          color c = color(hue, sat, bri);
          colorMode(RGB, 255);

          swatches.add(new ColorSwatch(c));
        }
      }
    }
  }

  void generateVariations() {
    if (!hasSelection) return;

    colorMode(HSB, 360, 100, 100);
    float h = hue(selectedColor);
    float s = saturation(selectedColor);
    float b = brightness(selectedColor);

    // 3x3 grid of variations
    // Layout:
    //   [H-,B+]  [B+]     [H+,B+]
    //   [H-]     [CENTER] [H+]
    //   [H-,B-]  [B-]     [H+,B-]
    //
    // Where H = hue, S = saturation, B = brightness

    int idx = 0;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        float newH = h;
        float newS = s;
        float newB = b;

        // Adjust hue based on column
        if (col == 0) newH = (h - hueStep + 360) % 360;
        else if (col == 2) newH = (h + hueStep) % 360;

        // Adjust brightness based on row
        if (row == 0) newB = constrain(b + briStep, 0, 100);
        else if (row == 2) newB = constrain(b - briStep, 0, 100);

        // Center position (1,1) keeps original color
        if (row == 1 && col == 1) {
          newH = h;
          newS = s;
          newB = b;
        }

        color varColor = color(newH, newS, newB);
        variations[idx] = new ColorSwatch(varColor);
        idx++;
      }
    }
    colorMode(RGB, 255);
  }

  void draw() {
    // Calculate layout - leave room on right for fine-tuning panel
    float mainAreaWidth = width * 0.65;
    float totalSpacingX = (cols - 1) * spacing;
    float totalSpacingY = (rows - 1) * spacing;
    float availableWidth = mainAreaWidth * 0.9;
    float availableHeight = height * 0.70;

    swatchSize = min(
      (availableWidth - totalSpacingX) / cols,
      (availableHeight - totalSpacingY) / rows
    );

    float gridWidth = cols * swatchSize + totalSpacingX;
    float gridHeight = rows * swatchSize + totalSpacingY;

    marginX = (mainAreaWidth - gridWidth) / 2;
    marginY = (height - gridHeight) / 2 + 20;

    // Draw title
    fill(40);
    textAlign(CENTER, TOP);
    textSize(24);
    text("Euglena Medium Color Reference", mainAreaWidth / 2, 20);

    textSize(13);
    fill(80);
    text("Click a swatch to select, then fine-tune on the right", mainAreaWidth / 2, 50);

    // Draw section labels
    textAlign(RIGHT, CENTER);
    textSize(12);
    fill(80);

    String[] labels = {"Green", "Yellow-Green", "Olive", "Brown"};
    for (int i = 0; i < 4; i++) {
      float y = marginY + (i * 2 + 0.5) * (swatchSize + spacing);
      text(labels[i], marginX - 15, y);
    }

    // Draw main swatches
    int idx = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (idx < swatches.size()) {
          float x = marginX + col * (swatchSize + spacing);
          float y = marginY + row * (swatchSize + spacing);
          swatches.get(idx).draw(x, y, swatchSize);
          idx++;
        }
      }
    }

    // Draw fine-tuning panel
    drawFineTuningPanel();

    // Draw mode indicator
    fill(150);
    textAlign(LEFT, BOTTOM);
    textSize(12);
    text("COLOR REFERENCE MODE - Press 'm' for Experiment mode, 'h' for help", 10, height - 10);
  }

  void drawFineTuningPanel() {
    float panelX = width * 0.68;
    float panelWidth = width * 0.30;
    float panelY = 80;

    // Panel title
    fill(40);
    textAlign(CENTER, TOP);
    textSize(18);
    text("Fine Tuning", panelX + panelWidth / 2, panelY);

    if (!hasSelection) {
      // No selection yet
      fill(100);
      textSize(14);
      text("Click a color swatch", panelX + panelWidth / 2, panelY + 40);
      text("to start fine-tuning", panelX + panelWidth / 2, panelY + 60);
      return;
    }

    // Calculate variation grid layout
    // Wide spacing to allow placing tube in gap for comparison
    variationSize = min(panelWidth * 0.22, height * 0.11);
    float varSpacing = 35;
    float gridSize = 3 * variationSize + 2 * varSpacing;

    fineTuneX = panelX + (panelWidth - gridSize) / 2;
    fineTuneY = panelY + 50;

    // Draw the 3x3 variation grid
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        int idx = row * 3 + col;
        float x = fineTuneX + col * (variationSize + varSpacing);
        float y = fineTuneY + row * (variationSize + varSpacing);

        if (variations[idx] != null) {
          variations[idx].draw(x, y, variationSize);
        }
      }
    }

    // Draw labels for the grid
    fill(100);
    textSize(10);
    textAlign(CENTER, TOP);

    float labelY = fineTuneY + gridSize + 15;
    text("< Hue -     Selected     Hue + >", fineTuneX + gridSize / 2, labelY);

    textAlign(RIGHT, CENTER);
    float labelX = fineTuneX - 10;
    text("Bright", labelX, fineTuneY + variationSize / 2);
    text("Mid", labelX, fineTuneY + variationSize + varSpacing + variationSize / 2);
    text("Dark", labelX, fineTuneY + 2 * (variationSize + varSpacing) + variationSize / 2);

    // Instructions
    fill(100);
    textSize(12);
    textAlign(CENTER, TOP);
    float instrY = labelY + 30;
    text("Click a variation to refine further", fineTuneX + gridSize / 2, instrY);

    // Show current hex code prominently
    fill(0);
    textSize(20);
    text(colorToHex(selectedColor), fineTuneX + gridSize / 2, instrY + 35);

    // Saturation adjustment buttons
    float satBtnY = instrY + 80;
    float btnWidth = 80;
    float btnHeight = 30;
    float satCenterX = fineTuneX + gridSize / 2;

    // Sat - button
    if (mouseX > satCenterX - btnWidth - 10 && mouseX < satCenterX - 10 &&
        mouseY > satBtnY && mouseY < satBtnY + btnHeight) {
      fill(80);
    } else {
      fill(60);
    }
    stroke(100);
    strokeWeight(1);
    rect(satCenterX - btnWidth - 10, satBtnY, btnWidth, btnHeight, 4);
    fill(200);
    textSize(12);
    textAlign(CENTER, CENTER);
    text("Sat -", satCenterX - btnWidth/2 - 10, satBtnY + btnHeight/2);

    // Sat + button
    if (mouseX > satCenterX + 10 && mouseX < satCenterX + btnWidth + 10 &&
        mouseY > satBtnY && mouseY < satBtnY + btnHeight) {
      fill(80);
    } else {
      fill(60);
    }
    rect(satCenterX + 10, satBtnY, btnWidth, btnHeight, 4);
    fill(200);
    text("Sat +", satCenterX + btnWidth/2 + 10, satBtnY + btnHeight/2);

    // Show current HSB values
    colorMode(HSB, 360, 100, 100);
    fill(120);
    textSize(11);
    textAlign(CENTER, TOP);
    text(String.format("H: %.0f  S: %.0f  B: %.0f",
      hue(selectedColor), saturation(selectedColor), brightness(selectedColor)),
      satCenterX, satBtnY + btnHeight + 10);
    colorMode(RGB, 255);
  }

  void selectColor(color c) {
    selectedColor = c;
    hasSelection = true;
    generateVariations();
  }

  boolean handleClick(float mx, float my) {
    // Check main grid clicks
    int idx = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (idx < swatches.size()) {
          float x = marginX + col * (swatchSize + spacing);
          float y = marginY + row * (swatchSize + spacing);

          if (mx >= x && mx <= x + swatchSize && my >= y && my <= y + swatchSize) {
            selectColor(swatches.get(idx).c);
            return true;
          }
          idx++;
        }
      }
    }

    // Check fine-tuning grid clicks
    if (hasSelection) {
      float varSpacing = 35;  // Must match drawFineTuningPanel
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          float x = fineTuneX + col * (variationSize + varSpacing);
          float y = fineTuneY + row * (variationSize + varSpacing);

          if (mx >= x && mx <= x + variationSize && my >= y && my <= y + variationSize) {
            int varIdx = row * 3 + col;
            if (variations[varIdx] != null) {
              selectColor(variations[varIdx].c);
              return true;
            }
          }
        }
      }

      // Check saturation buttons
      float instrY = fineTuneY + 3 * variationSize + 2 * varSpacing + 15 + 30;
      float satBtnY = instrY + 80;
      float btnWidth = 80;
      float btnHeight = 30;
      float gridSize = 3 * variationSize + 2 * varSpacing;
      float satCenterX = fineTuneX + gridSize / 2;

      // Sat - button
      if (mx > satCenterX - btnWidth - 10 && mx < satCenterX - 10 &&
          my > satBtnY && my < satBtnY + btnHeight) {
        adjustSaturation(-satStep);
        return true;
      }

      // Sat + button
      if (mx > satCenterX + 10 && mx < satCenterX + btnWidth + 10 &&
          my > satBtnY && my < satBtnY + btnHeight) {
        adjustSaturation(satStep);
        return true;
      }
    }

    return false;
  }

  void adjustSaturation(float delta) {
    colorMode(HSB, 360, 100, 100);
    float h = hue(selectedColor);
    float s = constrain(saturation(selectedColor) + delta, 0, 100);
    float b = brightness(selectedColor);
    selectedColor = color(h, s, b);
    colorMode(RGB, 255);
    generateVariations();
  }

  String colorToHex(color c) {
    // Use bit shifting to extract RGB - colorMode independent
    int r = (c >> 16) & 0xFF;
    int g = (c >> 8) & 0xFF;
    int b = c & 0xFF;
    return String.format("#%02X%02X%02X", r, g, b);
  }
}

/**
 * ColorSwatch
 *
 * A single color swatch with hex code display.
 */
class ColorSwatch {
  color c;
  String hexCode;

  ColorSwatch(color c) {
    this.c = c;
    this.hexCode = colorToHex(c);
  }

  void draw(float x, float y, float size) {
    // Draw swatch
    rectMode(CORNER);
    fill(c);
    stroke(80);
    strokeWeight(1);
    rect(x, y, size, size, 4);

    // Draw hex code
    // Calculate perceived brightness using bit shifting (colorMode independent)
    int r = (c >> 16) & 0xFF;
    int g = (c >> 8) & 0xFF;
    int b = c & 0xFF;
    float perceivedBrightness = (r * 0.299 + g * 0.587 + b * 0.114);
    if (perceivedBrightness > 128) {
      fill(0);
    } else {
      fill(255);
    }

    textAlign(CENTER, CENTER);
    textSize(size * 0.14);
    text(hexCode, x + size/2, y + size/2);
  }

  String colorToHex(color c) {
    // Use bit shifting to extract RGB - colorMode independent
    int r = (c >> 16) & 0xFF;
    int g = (c >> 8) & 0xFF;
    int b = c & 0xFF;
    return String.format("#%02X%02X%02X", r, g, b);
  }
}
