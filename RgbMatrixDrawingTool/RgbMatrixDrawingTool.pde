/**
 * Simple drawing tool for a LED matrix. Needs to be run in conjunction with 
 * python script rgb_matrix_drawing_tool.py
 *
 * Author: Sofian Audry -- info A sofianaudry D com
 */

 // Constants.
final int SIDE = 32;

final int SIZE = SIDE*SIDE;
final String MATRIX_IMAGE_FILE = "matrix.png";
final color DEFAULT_COLOR = #000000;

// Globals.
float CELL_SIDE;

color[] matrix = new color[SIZE];
PGraphics matrixGraphics;

color currentColor;

void setup() {
  // Init.
  size(960, 960);
  
  stroke(255, 255, 255, 127);
  strokeWeight(0.5);
  CELL_SIDE = float(width) / SIDE;
  currentColor = #ffffff;
  matrixGraphics = createGraphics(SIDE, SIDE);
  
  // Ready.
  clear();
  readMatrix();

  // Repaint.
  paint();
}

void draw() {
  paint();
}

void updateMatrix() {
  matrixGraphics.beginDraw();
  matrixGraphics.loadPixels();
  for (int x=0; x<SIDE; x++) {
    for (int y=0; y<SIDE; y++) {
      matrixGraphics.pixels[x+y*SIDE] = getPixel(x, y);
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
      fill(getPixel(x, y));
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

color getPixel(int x, int y) {
  return matrix[x+y*SIDE];
}

void clear() {
  for (int i=0; i<SIZE; i++)
    matrix[i] = DEFAULT_COLOR;
}

void sendMatrix() {
  updateMatrix();
  matrixGraphics.save("matrix.png");
}

void readMatrix() {
  PImage img = loadImage(MATRIX_IMAGE_FILE);
  matrixGraphics.beginDraw();
  matrixGraphics.image(img, 0, 0);
  matrixGraphics.loadPixels();
  for (int i=0; i<SIZE; i++)
    matrix[i] = matrixGraphics.pixels[i];
  matrixGraphics.endDraw();
}

float screenToGrid(float pos) {
  return pos / CELL_SIDE;
}

float gridToScreen(float pos) {
  return pos * CELL_SIDE;
}

void mouseDragged() {
  int x = int(screenToGrid(mouseX));
  int y = int(screenToGrid(mouseY));
  setPixel(x, y, currentColor);
}

void mouseClicked() {
  int x = int(screenToGrid(mouseX));
  int y = int(screenToGrid(mouseY));
  // Click on same color => erase.
  setPixel(x, y, getPixel(x, y) == currentColor ? DEFAULT_COLOR : currentColor);
}

void keyPressed() {
  switch (key) {
    // Actions.
    case ENTER: sendMatrix(); break;
    case ' ':   clear();
    
    // Color change.
    case 'd':   currentColor = #000000; break;
    case 'w':   currentColor = #ffffff; break;
    case 'r':   currentColor = #ff0000; break;
    case 'g':   currentColor = #00ff00; break;
    case 'b':   currentColor = #0000ff; break;
    case 'y':   currentColor = #ffff00; break;
    case 'c':   currentColor = #00ffff; break;
    case 'm':   currentColor = #ff00ff; break;
    
    default:;
  }
}