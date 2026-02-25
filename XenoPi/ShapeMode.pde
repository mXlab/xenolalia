// Displays simple shapes inside the image_rect for petri-dish calibration.
// Interface mirrors EuglenaLightTable symbol edit mode.
class ShapeMode extends AbstractMode {

  // Shape constants
  final int SHAPE_X      = 0;
  final int SHAPE_CIRCLE = 1;
  final int SHAPE_BARS   = 2;
  final int N_SHAPES     = 3;

  String[] shapeNames = {"X", "Circle", "Bars"};

  // Color constants (matching EuglenaLightTable)
  final int COLOR_MAGENTA = 0;
  final int COLOR_CYAN    = 1;
  final int COLOR_YELLOW  = 2;
  final int COLOR_WHITE   = 3;
  final int N_COLORS      = 4;

  color[] colors = {
    color(255,   0, 255),  // Magenta
    color(  0, 255, 255),  // Cyan
    color(255, 255,   0),  // Yellow
    color(255, 255, 255)   // White
  };
  String[] colorNames = {"Magenta", "Cyan", "Yellow", "White"};

  // Thickness constants (matching EuglenaLightTable)
  final int WIDTH_THIN   = 0;
  final int WIDTH_MEDIUM = 1;
  final int WIDTH_LARGE  = 2;
  final int N_WIDTHS     = 3;

  float[] widthMultipliers = {0.025, 0.05, 0.075};
  String[] widthNames = {"Thin", "Medium", "Large"};

  int shapeType;
  int symbolColor;
  int strokeWidth;
  boolean helpEnabled;

  void setup() {
    shapeType   = SHAPE_X;
    symbolColor = COLOR_WHITE;
    strokeWidth = WIDTH_MEDIUM;
    helpEnabled = true;
  }

  void draw() {
    background(0);
    noCursor();

    PVector topLeft     = settings.getImageRectPoint(0);
    PVector bottomRight = settings.getImageRectPoint(1);
    float w        = bottomRight.x - topLeft.x;
    float h        = bottomRight.y - topLeft.y;
    float cx       = topLeft.x + w / 2;
    float cy       = topLeft.y + h / 2;
    float diameter = min(w, h);

    pushMatrix();
    translate(cx, cy);
    scale(w / diameter, h / diameter);
    drawSymbol(diameter);
    popMatrix();

    if (helpEnabled)
      drawHelp();
  }

  void drawSymbol(float diameter) {
    float strokeW = diameter * widthMultipliers[strokeWidth];
    fill(colors[symbolColor]);
    noStroke();

    switch (shapeType) {
      case SHAPE_X:      drawX(strokeW, diameter);      break;
      case SHAPE_CIRCLE: drawCircleShape(strokeW, diameter); break;
      case SHAPE_BARS:   drawBars(strokeW, diameter);   break;
    }
  }

  void drawX(float strokeW, float diameter) {
    float halfStroke = strokeW * 0.5;
    float len = diameter * 0.7;

    pushMatrix();
    rotate(QUARTER_PI);
    beginShape();
    vertex(-halfStroke, -len/2);
    vertex( halfStroke, -len/2);
    vertex( halfStroke,  len/2);
    vertex(-halfStroke,  len/2);
    endShape(CLOSE);
    popMatrix();

    pushMatrix();
    rotate(-QUARTER_PI);
    beginShape();
    vertex(-halfStroke, -len/2);
    vertex( halfStroke, -len/2);
    vertex( halfStroke,  len/2);
    vertex(-halfStroke,  len/2);
    endShape(CLOSE);
    popMatrix();
  }

  void drawCircleShape(float strokeW, float diameter) {
    noFill();
    stroke(colors[symbolColor]);
    strokeWeight(strokeW);
    ellipse(0, 0, diameter * 0.55, diameter * 0.55);
    noStroke();
  }

  void drawBars(float strokeW, float diameter) {
    float len     = diameter * 0.7;
    float spacing = diameter * 0.2;
    float[] barWidths = {strokeW * 0.75, strokeW, strokeW * 1.25};

    rectMode(CENTER);
    for (int i = 0; i < 3; i++) {
      float xPos  = (i - 1) * spacing;
      float halfW = barWidths[i] * 0.5;
      beginShape();
      vertex(xPos - halfW, -len/2);
      vertex(xPos + halfW, -len/2);
      vertex(xPos + halfW,  len/2);
      vertex(xPos - halfW,  len/2);
      endShape(CLOSE);
    }
  }

  void drawHelp() {
    fill(120);
    noStroke();
    textSize(14);
    textAlign(LEFT, TOP);
    text("Shape: " + shapeNames[shapeType] + " (TAB)" +
         "  Color: " + colorNames[symbolColor] + " (c)" +
         "  Thickness: " + widthNames[strokeWidth] + " (t)" +
         "  s: calibration  h: hide",
         10, 10);
  }

  void keyPressed() {
    switch (key) {
      case TAB: shapeType   = (shapeType   + 1) % N_SHAPES; break;
      case 'c': symbolColor = (symbolColor + 1) % N_COLORS; break;
      case 't': strokeWidth = (strokeWidth + 1) % N_WIDTHS; break;
      case 'h': helpEnabled = !helpEnabled;                  break;
    }
  }
}
