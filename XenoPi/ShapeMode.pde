// Displays simple shapes inside the image_rect for petri-dish calibration.
// Interface mirrors EuglenaLightTable symbol edit mode.
class ShapeMode extends AbstractMode {

  // Shape constants
  final int SHAPE_X      = 0;
  final int SHAPE_CIRCLE = 1;
  final int SHAPE_BARS   = 2;
  final int SHAPE_GLYPH  = 3;
  final int N_SHAPES     = 4;

  String[] shapeNames = {"X", "Circle", "Bars", "Glyph"};

  // Color constants (matching EuglenaLightTable)
  final int COLOR_RED     = 0;
  final int COLOR_MAGENTA = 1;
  final int COLOR_BLUE    = 2;
  final int COLOR_CYAN    = 3;
  final int COLOR_YELLOW  = 4;
  final int COLOR_WHITE   = 5;
  final int N_COLORS      = 6;

  color[] colors = {
    color(255,   0,   0),  // Red
    color(255,   0, 255),  // Magenta
    color(  0,   0, 255),  // Blue
    color(  0, 255, 255),  // Cyan
    color(255, 255,   0),  // Yellow
    color(255, 255, 255)   // White
  };
  String[] colorNames = {"Red", "Magenta", "Blue", "Cyan", "Yellow", "White"};

  // Thickness constants (matching EuglenaLightTable)
  final int WIDTH_THIN   = 0;
  final int WIDTH_MEDIUM = 1;
  final int WIDTH_LARGE  = 2;
  final int N_WIDTHS     = 3;

  float[] widthMultipliers = {0.025, 0.05, 0.075};
  String[] widthNames = {"Thin", "Medium", "Large"};

  // Lightness levels
  final int LIGHTNESS_25  = 0;
  final int LIGHTNESS_50  = 1;
  final int LIGHTNESS_75  = 2;
  final int LIGHTNESS_100 = 3;
  final int N_LIGHTNESS   = 4;
  float[] lightnessLevels  = {0.25, 0.5, 0.75, 1.0};
  String[] lightnessNames  = {"25%", "50%", "75%", "100%"};

  // Hue offset
  final int HUE_STEP = 5;
  final int HUE_MAX  = 60;

  // Saturation
  final int SAT_STEP = 10;

  int shapeType;
  int symbolColor;
  int strokeWidth;
  int lightnessLevel;
  int hueOffset;
  int saturationPct;
  boolean helpEnabled;
  boolean flashEnabled;
  boolean symbolEnabled;

  void setup() {
    shapeType      = SHAPE_X;
    symbolColor    = COLOR_WHITE;
    strokeWidth    = WIDTH_MEDIUM;
    lightnessLevel = LIGHTNESS_100;
    hueOffset      = 0;
    saturationPct  = 100;
    helpEnabled    = true;
    flashEnabled   = false;
    symbolEnabled  = true;
  }

  color currentColor() {
    float b = lightnessLevels[lightnessLevel];
    color c = colors[symbolColor];
    if (hueOffset == 0 && saturationPct == 100) {
      return color(red(c) * b, green(c) * b, blue(c) * b);
    }
    pushStyle();
    colorMode(HSB, 360, 100, 100);
    float h = (hue(c) + hueOffset + 360) % 360;
    float s = saturation(c) * saturationPct / 100.0;
    float v = brightness(c) * b;
    color result = color(h, s, v);
    popStyle();
    return result;
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
      case SHAPE_X:      drawX(strokeW, diameter);          break;
      case SHAPE_CIRCLE: drawCircleShape(strokeW, diameter); break;
      case SHAPE_BARS:   drawBars(strokeW, diameter);       break;
      case SHAPE_GLYPH:  drawGlyph(strokeW, diameter);      break;
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

  void drawGlyph(float strokeW, float diameter) {
    noFill();
    stroke(currentColor());
    strokeWeight(strokeW);
    strokeCap(ROUND);
    strokeJoin(ROUND);

    float r = diameter * 0.46;

    // Organic loop-with-tail path inspired by the xenolalia 'a' glyph.
    // The curve passes through the junction twice to enclose a loop,
    // then descends as a tail that curls left at the bottom.
    beginShape();
    curveVertex( r * 1.05,  r * 0.30);  // ghost control
    curveVertex( r * 0.85,  r * 0.00);  // junction (start)
    curveVertex( r * 0.95, -r * 0.65);  // right
    curveVertex( r * 0.30, -r * 1.05);  // top
    curveVertex(-r * 0.70, -r * 0.80);  // upper-left
    curveVertex(-r * 0.85, -r * 0.10);  // left
    curveVertex(-r * 0.55,  r * 0.45);  // lower-left
    curveVertex( r * 0.10,  r * 0.45);  // bottom of loop
    curveVertex( r * 0.85,  r * 0.00);  // junction (second pass — closes loop visually)
    curveVertex( r * 0.90,  r * 0.65);  // tail, down-right
    curveVertex( r * 0.30,  r * 1.00);  // tail, lower
    curveVertex(-r * 0.15,  r * 0.95);  // tail end
    curveVertex(-r * 0.35,  r * 0.75);  // ghost control
    endShape();

    noStroke();
  }

  void drawHelp() {
    fill(120);
    noStroke();
    textSize(14);
    textAlign(LEFT, TOP);
    String hueStr = (hueOffset == 0 ? "0" : (hueOffset > 0 ? "+" : "") + hueOffset) + "\u00b0";
    text("Symbol: " + (symbolEnabled ? "ON" : "off") + " (x)" +
         "  Shape: " + shapeNames[shapeType] + " (s)" +
         "  Color: " + colorNames[symbolColor] + " (c)" +
         "  Thickness: " + widthNames[strokeWidth] + " (t)" +
         "  Lightness: " + lightnessNames[lightnessLevel] + " (l)" +
         "  Hue: " + hueStr + " ([/])" +
         "  Sat: " + saturationPct + "% (,/.)" +
         "  Flash: " + (flashEnabled ? "ON" : "off") + " (f)" +
         "  h: hide",
         10, 10);
  }

  void keyPressed() {
    switch (key) {
      case 's': shapeType    = (shapeType   + 1) % N_SHAPES; break;
      case 'c': symbolColor  = (symbolColor + 1) % N_COLORS; break;
      case 't': strokeWidth     = (strokeWidth     + 1) % N_WIDTHS;     break;
      case 'l': lightnessLevel = (lightnessLevel + 1) % N_LIGHTNESS; break;
      case '[': hueOffset    = constrain(hueOffset - HUE_STEP, -HUE_MAX, HUE_MAX); break;
      case ']': hueOffset    = constrain(hueOffset + HUE_STEP, -HUE_MAX, HUE_MAX); break;
      case ',': saturationPct = constrain(saturationPct - SAT_STEP, 0, 100);        break;
      case '.': saturationPct = constrain(saturationPct + SAT_STEP, 0, 100);        break;
      case 'x': case 'X': symbolEnabled = !symbolEnabled;    break;
      case 'f': flashEnabled = !flashEnabled;                 break;
      case 'h': helpEnabled  = !helpEnabled;                  break;
    }
  }
}
