/**
 * DishSpot
 *
 * Represents a single dish spot on the light table.
 * Can display white, black, or a configurable symbol pattern.
 * Symbol properties: shape, color, and stroke width.
 */
class DishSpot {
  // State constants
  static final int STATE_WHITE = 0;
  static final int STATE_BLACK = 1;
  static final int STATE_SYMBOL = 2;

  // Shape constants
  static final int SHAPE_X = 0;
  static final int SHAPE_CIRCLE = 1;
  static final int SHAPE_BARS = 2;

  // Color constants
  static final int COLOR_MAGENTA = 0;
  static final int COLOR_CYAN = 1;
  static final int COLOR_YELLOW = 2;
  static final int COLOR_WHITE = 3;

  // Width constants
  static final int WIDTH_THIN = 0;
  static final int WIDTH_MEDIUM = 1;
  static final int WIDTH_LARGE = 2;

  // Position and size
  float x, y;
  float diameter;
  int number;  // 1-6 for display/control

  // Current state
  int state = STATE_WHITE;

  // Symbol properties
  int shape = SHAPE_X;
  int symbolColor = COLOR_MAGENTA;
  int strokeWidth = WIDTH_THIN;

  // Predefined colors
  color[] colors = {
    color(255, 0, 255),   // Magenta
    color(0, 255, 255),   // Cyan
    color(255, 255, 0),   // Yellow
    color(255, 255, 255)  // White
  };

  // Width multipliers (relative to diameter)
  float[] widthMultipliers = {0.025, 0.05, 0.075};

  DishSpot(float x, float y, float diameter, int number) {
    this.x = x;
    this.y = y;
    this.diameter = diameter;
    this.number = number;
  }

  void draw() {
    draw(false);
  }

  void draw(boolean selected) {
    pushMatrix();
    translate(x, y);

    // Draw background circle
    noStroke();

    switch (state) {
      case STATE_WHITE:
        fill(255);
        ellipse(0, 0, diameter, diameter);
        break;

      case STATE_BLACK:
        fill(0);
        ellipse(0, 0, diameter, diameter);
        // Draw border to show dish location
        stroke(80);
        strokeWeight(3);
        noFill();
        ellipse(0, 0, diameter, diameter);
        break;

      case STATE_SYMBOL:
        // Black background
        fill(0);
        ellipse(0, 0, diameter, diameter);
        // Draw the configured symbol
        drawSymbol();
        break;
    }

    // Draw selection highlight
    if (selected) {
      stroke(255, 150, 0);  // Orange highlight
      strokeWeight(4);
      noFill();
      ellipse(0, 0, diameter + 10, diameter + 10);
    }

    // Draw dish number (small, for reference) - hide when showing symbol
    if (state != STATE_SYMBOL) {
      fill(state == STATE_WHITE ? 180 : 60);
      textAlign(CENTER, CENTER);
      textSize(diameter * 0.1);
      text(number, 0, diameter * 0.35);
    }

    popMatrix();
  }

  void drawSymbol() {
    pushStyle();  // Save style so rectMode/stroke/fill changes don't leak out
    color c = colors[symbolColor];
    float strokeW = diameter * widthMultipliers[strokeWidth];

    fill(c);
    noStroke();

    switch (shape) {
      case SHAPE_X:
        drawX(strokeW);
        break;
      case SHAPE_CIRCLE:
        drawCircleShape(strokeW);
        break;
      case SHAPE_BARS:
        drawBars(strokeW);
        break;
    }

    // Redraw circular mask border to clean up edges
    float borderWeight = diameter * 0.1;
    stroke(0);
    strokeWeight(borderWeight);
    noFill();
    ellipse(0, 0, diameter + borderWeight * 0.5, diameter + borderWeight * 0.5);
    noStroke();
    popStyle();  // Restore style (rectMode, stroke, fill, etc.)
  }

  void drawX(float strokeW) {
    float halfStroke = strokeW * 0.5;
    float len = diameter * 0.7;

    // First diagonal (top-left to bottom-right)
    pushMatrix();
    rotate(QUARTER_PI);
    rectMode(CENTER);
    beginShape();
    vertex(-halfStroke, -len/2);
    vertex(halfStroke, -len/2);
    vertex(halfStroke, len/2);
    vertex(-halfStroke, len/2);
    endShape(CLOSE);
    popMatrix();

    // Second diagonal (top-right to bottom-left)
    pushMatrix();
    rotate(-QUARTER_PI);
    rectMode(CENTER);
    beginShape();
    vertex(-halfStroke, -len/2);
    vertex(halfStroke, -len/2);
    vertex(halfStroke, len/2);
    vertex(-halfStroke, len/2);
    endShape(CLOSE);
    popMatrix();
  }

  void drawCircleShape(float strokeW) {
    // Draw a ring/circle outline
    noFill();
    stroke(colors[symbolColor]);
    strokeWeight(strokeW);
    float ringDiameter = diameter * 0.55;
    ellipse(0, 0, ringDiameter, ringDiameter);
    noStroke();
  }

  void drawBars(float strokeW) {
    float len = diameter * 0.7;
    float spacing = diameter * 0.2;

    // Three vertical bars with varying thickness: thin, medium, wide
    float[] barWidths = {strokeW * 0.75, strokeW, strokeW * 1.25};

    rectMode(CENTER);

    for (int i = 0; i < 3; i++) {
      float xPos = (i - 1) * spacing;
      float halfW = barWidths[i] * 0.5;
      beginShape();
      vertex(xPos - halfW, -len/2);
      vertex(xPos + halfW, -len/2);
      vertex(xPos + halfW, len/2);
      vertex(xPos - halfW, len/2);
      endShape(CLOSE);
    }
  }

  // State methods
  void setState(int newState) {
    state = constrain(newState, STATE_WHITE, STATE_SYMBOL);
  }

  int getState() {
    return state;
  }

  void cycleState() {
    state = (state + 1) % 3;
  }

  // Shape methods
  void setShape(int newShape) {
    shape = constrain(newShape, SHAPE_X, SHAPE_BARS);
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  int getShape() {
    return shape;
  }

  void cycleShape() {
    shape = (shape + 1) % 3;
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  String getShapeName() {
    switch (shape) {
      case SHAPE_X: return "X";
      case SHAPE_CIRCLE: return "Circle";
      case SHAPE_BARS: return "Bars";
      default: return "?";
    }
  }

  // Color methods
  void setSymbolColor(int newColor) {
    symbolColor = constrain(newColor, COLOR_MAGENTA, COLOR_WHITE);
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  int getSymbolColor() {
    return symbolColor;
  }

  void cycleColor() {
    symbolColor = (symbolColor + 1) % 4;
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  String getColorName() {
    switch (symbolColor) {
      case COLOR_MAGENTA: return "Magenta";
      case COLOR_CYAN: return "Cyan";
      case COLOR_YELLOW: return "Yellow";
      case COLOR_WHITE: return "White";
      default: return "?";
    }
  }

  // Width methods
  void setStrokeWidth(int newWidth) {
    strokeWidth = constrain(newWidth, WIDTH_THIN, WIDTH_LARGE);
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  int getStrokeWidth() {
    return strokeWidth;
  }

  void cycleWidth() {
    strokeWidth = (strokeWidth + 1) % 3;
    if (state != STATE_SYMBOL) state = STATE_SYMBOL;
  }

  String getWidthName() {
    switch (strokeWidth) {
      case WIDTH_THIN: return "Thin";
      case WIDTH_MEDIUM: return "Medium";
      case WIDTH_LARGE: return "Large";
      default: return "?";
    }
  }

  String getStateName() {
    switch (state) {
      case STATE_WHITE: return "WHITE";
      case STATE_BLACK: return "BLACK";
      case STATE_SYMBOL: return getShapeName() + "/" + getColorName() + "/" + getWidthName();
      default: return "UNKNOWN";
    }
  }
}
