final int SIDE = 32;
final int SIZE = SIDE*SIDE;

final String MATRIX_IMAGE_FILE = "matrix.png";
final String MATRIX_DATA_FILE  = "matrix.dat";

float CELL_SIDE;

int[] matrix = new int[SIZE];
PGraphics matrixGraphics;

int currentPaletteColor;
final color[] PALETTE = new color[] {
  #000000,
  #ffffff,
  #ff0000,
  #00ff00,
  #0000ff
};

void setup() {
  size(640, 640);
  
  stroke(255, 255, 255, 127);
  strokeWeight(0.5);
  CELL_SIDE = float(width) / SIDE;
  currentPaletteColor = 0;
  
  matrixGraphics = createGraphics(SIDE, SIDE);
  println(matrixGraphics);
  
  clear();
//  readMatrix();

  paint();
//  sendMatrix();
}

void draw() {
  paint();
}

void paintMatrix() {
  matrixGraphics.beginDraw();
  matrixGraphics.loadPixels();
  for (int x=0; x<SIDE; x++) {
    for (int y=0; y<SIDE; y++) {
      matrixGraphics.pixels[x+y*SIDE] = getPixelColor(x, y);
    }
  }
  matrixGraphics.updatePixels();
  matrixGraphics.endDraw();
}

void paint() {
  background(0);
  
  // Draw matrix.
  for (int x=0; x<SIDE; x++) {
    for (int y=0; y<SIDE; y++) {
      fill(getPixelColor(x, y));
      rect(gridToScreen(x), gridToScreen(y), CELL_SIDE, CELL_SIDE);
    }
  }
  
  // Draw gridlines.
  for (int k=0; k<SIDE; k++) {
    line(gridToScreen(k), 0, gridToScreen(k), height);
    line(0, gridToScreen(k), width, gridToScreen(k));
  }
}

void setPixel(int x, int y, int c) {
  matrix[x+y*SIDE] = c;
}

void setPixelNext(int x, int y) {
  setPixel(x, y, (getPixel(x, y) + 1) % PALETTE.length);
}

color getPixelColor(int x, int y) {
  return PALETTE[getPixel(x, y)];
}

int getPixel(int x, int y) {
  return matrix[x+y*SIDE];
}

void clear() {
  for (int i=0; i<SIZE; i++)
    matrix[i] = 0;
}

void sendMatrix() {
  paintMatrix();
  matrixGraphics.save("matrix.png");
  //String[] values = new String[SIZE];
  //for (int i=0; i<SIZE; i++) {
  //  values[i] = new String(matrix[i]);
  //}
}

void readMatrix() {
  PImage img = loadImage(MATRIX_IMAGE_FILE);
  matrixGraphics.beginDraw();
  matrixGraphics.image(img, 0, 0);
  matrixGraphics.endDraw();
}

float screenToGrid(float pos) {
  return pos / CELL_SIDE;
}

float gridToScreen(float pos) {
  return pos * CELL_SIDE;
}

void mouseClicked() {
  int x = int(screenToGrid(mouseX));
  int y = int(screenToGrid(mouseY));
  setPixelNext(x, y);
  paint();
}

void keyPressed() {
  switch (key) {
    case ENTER: sendMatrix(); break;
  }
}