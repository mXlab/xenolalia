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

  // Brightness levels
  final int N_BRIGHTNESS   = 4;
  float[] brightnessLevels = {0.25, 0.5, 0.75, 1.0};
  String[] brightnessNames = {"25%", "50%", "75%", "100%"};

  int shapeType;
  int symbolColor;
  int strokeWidth;
  int brightnessLevel;
  boolean helpEnabled;
  boolean flashEnabled;
  boolean symbolEnabled;

  void setup() {
    shapeType      = SHAPE_X;
    symbolColor    = COLOR_WHITE;
    strokeWidth    = WIDTH_MEDIUM;
    brightnessLevel = N_BRIGHTNESS - 1;  // 100%
    helpEnabled    = true;
    flashEnabled   = false;
    symbolEnabled  = true;
  }

  color currentColor() {
    float b = brightnessLevels[brightnessLevel];
    color c = colors[symbolColor];
    return color(red(c) * b, green(c) * b, blue(c) * b);
  }

  void draw() {
    background(flashEnabled ? 255 : 0);
    noCursor();

    PVector topLeft     = settings.getImageRectPoint(0);
    PVector bottomRight = settings.getImageRectPoint(1);
    float w        = bottomRight.x - topLeft.x;
    float h        = bottomRight.y - topLeft.y;
    float cx       = topLeft.x + w / 2;
    float cy       = topLeft.y + h / 2;
    float diameter = min(w, h);

    if (!flashEnabled && symbolEnabled) {
      pushMatrix();
      translate(cx, cy);
      scale(w / diameter, h / diameter);
      drawSymbol(diameter);
      popMatrix();
    }

    if (helpEnabled)
      drawHelp();
  }

  void drawSymbol(float diameter) {
    float strokeW = diameter * widthMultipliers[strokeWidth];
    fill(currentColor());
    noStroke();

    switch (shapeType) {
      case SHAPE_X:      drawX(strokeW, diameter);      break;
      case SHAPE_CIRCLE: drawCircleShape(strokeW, diameter); break;
      case SHAPE_BARS:   drawBars(strokeW, diameter);   break;
    }
  }

  void drawX(float strokeW, float diameter) {
    float halfStroke = strokeW * 0.5;
    float len = diameter * sqrt(2);

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
    stroke(currentColor());
    strokeWeight(strokeW);
    ellipse(0, 0, diameter, diameter);
    noStroke();
  }

  void drawBars(float strokeW, float diameter) {
    float len     = diameter;
    float spacing = diameter / 3.0;
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
    text("Symbol: " + (symbolEnabled ? "ON" : "off") + " (x)" +
         "  Shape: " + shapeNames[shapeType] + " (s)" +
         "  Color: " + colorNames[symbolColor] + " (c)" +
         "  Thickness: " + widthNames[strokeWidth] + " (t)" +
         "  Brightness: " + brightnessNames[brightnessLevel] + " (b)" +
         "  Flash: " + (flashEnabled ? "ON" : "off") + " (f)" +
         "  h: hide",
         10, 10);
  }

  void keyPressed() {
    switch (key) {
      case 's': shapeType    = (shapeType   + 1) % N_SHAPES; break;
      case 'c': symbolColor  = (symbolColor + 1) % N_COLORS; break;
      case 't': strokeWidth     = (strokeWidth     + 1) % N_WIDTHS;     break;
      case 'b': brightnessLevel = (brightnessLevel + 1) % N_BRIGHTNESS; break;
      case 'x': case 'X': symbolEnabled = !symbolEnabled;    break;
      case 'f': flashEnabled = !flashEnabled;                 break;
      case 'h': helpEnabled  = !helpEnabled;                  break;
    }
  }
}
