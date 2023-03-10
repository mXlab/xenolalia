class Scene {

  final int RUN_DURATION = 15000;
  final int END_DURATION =  5000;
  //final int RUN_DURATION = 1000;
  //final int END_DURATION = 500;

  final int TOTAL_DURATION = RUN_DURATION + END_DURATION;
  final float RUN_DURATION_PROPORTION = RUN_DURATION / (float)TOTAL_DURATION;

  color background;

  int nColumns;
  int nRows;

  Rect boundingRect;

  Vignette[] vignettes;

  PGraphics pg;
  float vignetteSide;

  Timer timer;

  boolean needsRefresh;

  String oscAddress = null;

  Scene(int nColumns, int nRows) {
    this(nColumns, nRows, new Rect());
  }

  Scene(int nColumns, int nRows, Rect boundingRect) {
    this.boundingRect = boundingRect;
    timer = new Timer(TOTAL_DURATION);
    background = 0;
    init(nColumns, nRows);
  }

  void setOscAddress(String addr) {
    oscAddress = addr;
  }

  boolean usesOsc() {
    return oscAddress != null;
  }

  void oscSendMessage(String path, int value) {
    if (usesOsc()) {
      OscMessage msg = new OscMessage(oscAddress + path);
      msg.add(value);
      oscP5.send(msg, sonoscope);
    }
  }

  void init(int nColumns, int nRows) {
    this.nColumns = nColumns;
    this.nRows = nRows;

    vignettes = new Vignette[nColumns*nRows];

    // Find best proportions for graphics.
    float fullWidthSide  = boundingRect.w / (float)nColumns;
    float fullHeightSide = boundingRect.h / (float)nRows;

    vignetteSide = (nRows * fullWidthSide <= boundingRect.h ? fullWidthSide : fullHeightSide);

    pg = createGraphics(round(vignetteSide*nColumns), round(vignetteSide*nRows));

    reset();
  }

  int nVignettes() {
    return vignettes.length;
  }

  int nColumns() {
    return nColumns;
  }

  int nRows() {
    return nRows;
  }

  void setBackground(color background) {
    this.background = background;
  }

  void putVignette(int c, int r, Vignette v) {
    putVignette(_getIndex(c, r), v);
  }

  void putVignette(int i, Vignette v) {
    vignettes[i] = v;
    v.setScene(this);
  }

  void insertVignette(int i, Vignette v) {
    Vignette[] newVignettes = new Vignette[vignettes.length];
    for (int j=0; j<i; j++)
    newVignettes[j] = vignettes[j];
    newVignettes[i] = v;
    for (int j=i+1; j<vignettes.length; j++)
    newVignettes[j] = vignettes[j-1];
    vignettes = newVignettes;
    v.setScene(this);
  }

  Vignette getVignette(int c, int r) {
    return getVignette(_getIndex(c, r));
  }

  Vignette getVignette(int i) {
    return vignettes[i];
  }

  void build() {
    for (Vignette v : vignettes) {
      if (v != null)
      v.build();
    }
    reset();
  }

  void reset() {
    timer.start();
    needsRefresh = false;
  }

  boolean needsRefresh() {
    return this.needsRefresh;
  }

  void requestRefresh() {
    this.needsRefresh = true;
  }

  void display() {
    pg.beginDraw();
    pg.smooth();

    // Call child class display function.
    pg.background(background);
    doDisplay();

    pg.endDraw();

    // Dislay graphics on main window.
    imageMode(CENTER);
    rectMode(CENTER);
    noStroke();
    fill(background);
    rect(boundingRect.x, boundingRect.y, boundingRect.w, boundingRect.h);

    // Display scene PGraphics.
    image(pg, boundingRect.x, boundingRect.y);

    // Displays the bounding rectangle, for adjustment purposes.
    if (keyPressed && key == ' ') {
      stroke(0, 0, 255);
      strokeWeight(2);
      fill(0, 0);
      ellipseMode(CENTER);
      rect(boundingRect.x, boundingRect.y, boundingRect.w, boundingRect.h);
      println(boundingRect.x, boundingRect.y, boundingRect.w, boundingRect.h);
      float crosshairRadius = min(height/20, 80);
      //circle(boundingRect.x, boundingRect.y, crosshairRadius*2);
      line(boundingRect.x-crosshairRadius, boundingRect.y, boundingRect.x+crosshairRadius, boundingRect.y);
      line(boundingRect.x, boundingRect.y-crosshairRadius, boundingRect.x, boundingRect.y+crosshairRadius);
    }
  }

  void doDisplay() {
    pg.imageMode(CORNER);
    int k=0;
    for (int r=0; r<nRows; r++) {
      for (int c=0; c<nColumns; c++, k++) {
        Vignette v = getVignette(c, r);
        if (v != null)
        v.display(c*vignetteSide, r*vignetteSide, vignetteSide, pg);
      }
    }
  }

  float progress() {
    return timer.progress();
  }
  float runProgress() {
    return min(timer.passedTime() / (float)RUN_DURATION, 1.0);
  }
  float endProgress() {
    return constrain((timer.passedTime() - RUN_DURATION) / END_DURATION, 0.0, 1.0);
  }

  boolean isFinished() {
    return timer.isFinished();
  }

  int _getIndex(int c, int r) {
    return c + r*nColumns;
  }
}
