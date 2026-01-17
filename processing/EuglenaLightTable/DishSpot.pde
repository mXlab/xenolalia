/**
 * DishSpot
 *
 * Represents a single dish spot on the light table.
 * Can display white, black, or magenta X pattern.
 */
class DishSpot {
  // State constants
  static final int STATE_WHITE = 0;
  static final int STATE_BLACK = 1;
  static final int STATE_X = 2;

  // Position and size
  float x, y;
  float diameter;
  int number;  // 1-6 for display/control

  // Current state
  int state = STATE_WHITE;

  // Colors
  color colorWhite = color(255);
  color colorBlack = color(0);
  color colorMagenta = color(255, 0, 255);

  DishSpot(float x, float y, float diameter, int number) {
    this.x = x;
    this.y = y;
    this.diameter = diameter;
    this.number = number;
  }

  void draw() {
    pushMatrix();
    translate(x, y);

    // Draw background circle (always needed for clipping)
    noStroke();

    switch (state) {
      case STATE_WHITE:
        fill(colorWhite);
        ellipse(0, 0, diameter, diameter);
        break;

      case STATE_BLACK:
        fill(colorBlack);
        ellipse(0, 0, diameter, diameter);
        // Draw subtle border to show dish location
        stroke(30);
        strokeWeight(2);
        noFill();
        ellipse(0, 0, diameter, diameter);
        break;

      case STATE_X:
        // Black background
        fill(colorBlack);
        ellipse(0, 0, diameter, diameter);
        // Draw magenta X pattern using masking
        drawXPattern();
        break;
    }

    // Draw dish number (small, for reference)
    fill(state == STATE_BLACK ? 40 : 200);
    textAlign(CENTER, CENTER);
    textSize(diameter * 0.1);
    text(number, 0, diameter * 0.35);

    popMatrix();
  }

  void drawXPattern() {
    // Create X pattern with magenta on black background
    // Use a graphics buffer for proper circular clipping

    float strokeW = diameter * 0.075;  // X stroke width (thinner)

    // Draw X using quads for proper thickness
    fill(colorMagenta);
    noStroke();

    // Calculate X dimensions
    float halfDiag = diameter * 0.5;
    float halfStroke = strokeW * 0.5;

    // First diagonal (top-left to bottom-right)
    pushMatrix();
    rotate(QUARTER_PI);
    rectMode(CENTER);
    // Clip to circle by drawing only within bounds
    beginShape();
    float len = diameter * 0.7;
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

    // Redraw circular mask border to clean up edges
    float borderWeight = diameter * 0.1;
    stroke(0);
    strokeWeight(borderWeight);
    noFill();
    ellipse(0, 0, diameter + borderWeight * 0.5, diameter + borderWeight * 0.5);
    noStroke();
  }

  void setState(int newState) {
    state = constrain(newState, STATE_WHITE, STATE_X);
  }

  int getState() {
    return state;
  }

  void cycleState() {
    state = (state + 1) % 3;
  }

  String getStateName() {
    switch (state) {
      case STATE_WHITE: return "WHITE";
      case STATE_BLACK: return "BLACK";
      case STATE_X: return "X-PATTERN";
      default: return "UNKNOWN";
    }
  }
}
