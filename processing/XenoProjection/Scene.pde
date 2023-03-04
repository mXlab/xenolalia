class Scene {

  //final int RUN_DURATION = 15000;
  //final int END_DURATION =  5000;
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

  Scene(int nColumns, int nRows) {
    this.nColumns = nColumns;
    this.nRows = nRows;

    vignettes = new Vignette[nColumns*nRows];

    // Find best proportions for graphics.
    float fullWidthSide  = WIDTH  / (float)nColumns;
    float fullHeightSide = HEIGHT / (float)nRows;

    vignetteSide = (nRows * fullWidthSide <= HEIGHT ? fullWidthSide : fullHeightSide);

    timer = new Timer(TOTAL_DURATION);

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

  void putVignette(int c, int r, Vignette v) {
    putVignette(_getIndex(c, r), v);
  }

  void putVignette(int i, Vignette v) {
    vignettes[i] = v;
    v.setScene(this);
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
    pg.background(255);
    pg.imageMode(CORNER);
    int k=0;
    for (int r=0; r<nRows; r++) {
      for (int c=0; c<nColumns; c++, k++) {
        Vignette v = getVignette(c, r);
        v.display(c*vignetteSide, r*vignetteSide, vignetteSide, pg);
      }
    }
  }
  
  float progress() { return timer.progress(); }
  float runProgress() { return min(timer.passedTime() / (float)RUN_DURATION, 1.0); }
  float endProgress() { return constrain((timer.passedTime() - RUN_DURATION) / END_DURATION, 0.0, 1.0); }

  boolean isFinished() {
    return timer.isFinished();
  }

  int _getIndex(int c, int r) {
    return c + r*nColumns;
  }
}
