class Scene {

  final int RUN_DURATION = 15000;
  final int END_DURATION =  5000;
  final int TOTAL_DURATION = RUN_DURATION + END_DURATION;
  final float RUN_DURATION_PROPORTION = RUN_DURATION / (float)TOTAL_DURATION;
  
  int nColumns;
  int nRows;

  Vignette[] vignettes;

  PGraphics pg;
  float vignetteSide;

  Timer timer;
  DisplayMode displayMode;

  Scene(int nColumns, int nRows) {
    this.nColumns = nColumns;
    this.nRows = nRows;

    vignettes = new Vignette[nColumns*nRows];

    // Find best proportions for graphics.
    float fullWidthSide  = WIDTH  / (float)nColumns;
    float fullHeightSide = HEIGHT / (float)nRows;

    vignetteSide = (nRows * fullWidthSide <= HEIGHT ? fullWidthSide : fullHeightSide);

    displayMode = DisplayMode.DEFAULT;
    timer = new Timer(TOTAL_DURATION);

    pg = createGraphics(round(vignetteSide*nColumns), round(vignetteSide*nRows));

    reset();
  }

  void setDisplayMode(DisplayMode displayMode) {
    this.displayMode = displayMode;
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

  void putVignette(int c, int r, Vignette v) {
    vignettes[_getIndex(c, r)] = v;
  }

  void putVignette(int i, Vignette v) {
    vignettes[i] = v;
  }

  Vignette getVignette(int c, int r) {
    return vignettes[_getIndex(c, r)];
  }

  void build() {
  }

  void reset() {
    timer.start();
  }

  void display() {
    pg.beginDraw();

    // Call child class display function.
    doDisplay();

    pg.endDraw();

    // Dislay graphics.
    imageMode(CENTER);
    rectMode(CENTER);
    noStroke();
    fill(255);
    rect(width/2, height/2, WIDTH, HEIGHT);
    image(pg, width/2, height/2);
  }

  void doDisplay() {
    imageMode(CORNER);
    int k=0;
    for (int r=0; r<nRows; r++) {
      for (int c=0; c<nColumns; c++, k++) {
        Vignette v = getVignette(c, r);
        v.display(c*vignetteSide, r*vignetteSide, vignetteSide, pg);
      }
    }
  }

  boolean isFinished() {
    return timer.isFinished();
  }

  int _getIndex(int c, int r) {
    return c + r*nColumns;
  }
}
