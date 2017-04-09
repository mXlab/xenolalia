/**
 * Simple drawing tool for a LED matrix. Needs to be run in conjunction with 
 * python script rgb_matrix_drawing_tool.py
 *
 * Author: Sofian Audry -- info A sofianaudry D com
 */

 // Constants.
final int SIDE = 32;

final int SIZE = SIDE*SIDE;
final String MATRIX_SEND_FILE   = "matrix.png";
final String MATRIX_FILE_PREFIX = "matrix";
final String MATRIX_FILE_EXT    = "png";
final color DEFAULT_COLOR = #000000;

final int N_MATRICES = 10;

float CELL_SIDE;

// Globals.
RgbMatrix[] matrices = new RgbMatrix[N_MATRICES];
color currentColor;
int currentMatrixId;
RgbMatrix currentMatrix;

void setup() {
  // Init.
  size(960, 960);
  
  stroke(255, 255, 255, 127);
  strokeWeight(0.5);
  CELL_SIDE = float(width) / SIDE;
  currentColor = #ffffff;
  currentMatrixId = 0;
  
  // Create matrices.
  for (int i=0; i<N_MATRICES; i++)
    matrices[i] = new RgbMatrix(MATRIX_FILE_PREFIX + i + "." + MATRIX_FILE_EXT);
  setCurrentMatrix(0);
  
  // Repaint.
  paint();
}

void draw() {
  paint();
}

void paint() {
  background(0);
  
  // Draw matrix.
  for (int x=0; x<SIDE; x++) {
    for (int y=0; y<SIDE; y++) {
      fill(currentMatrix.getPixel(x, y));
      rect(gridToScreen(x), gridToScreen(y), CELL_SIDE, CELL_SIDE);
    }
  }
  
  // Draw gridlines.
  for (int k=0; k<SIDE; k++) {
    line(gridToScreen(k), 0, gridToScreen(k), height);
    line(0, gridToScreen(k), width, gridToScreen(k));
  }
  
  // Draw screen number.
  textAlign(RIGHT);
  final float TEXT_SIZE = CELL_SIDE*5;
  textSize(TEXT_SIZE);
  fill(255, 255, 255, 64);
  text(currentMatrixId, width-CELL_SIDE, TEXT_SIZE);
}

void setCurrentMatrix(int i) {
  currentMatrixId = constrain(i, 0, N_MATRICES-1);
  currentMatrix = matrices[currentMatrixId];
}

void saveAll() {
  for (RgbMatrix m : matrices) m.save(false);
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
  currentMatrix.setPixel(x, y, currentColor);
}

void mouseClicked() {
  int x = int(screenToGrid(mouseX));
  int y = int(screenToGrid(mouseY));
  // Click on same color => erase.
  currentMatrix.setPixel(x, y, currentMatrix.getPixel(x, y) == currentColor ? DEFAULT_COLOR : currentColor);
}

void keyPressed() {
  switch (key) {
    // Actions.
    case ENTER: currentMatrix.send(); break;
    case 's':   currentMatrix.save(false); break;
    case 'S':   saveAll(); break;
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
    
    default:
      if ('0' <= key && key <= '9') {
        setCurrentMatrix(key-'0');
      }
  }
}

// Confirmation pop-up on exit.
import javax.swing.JOptionPane;
void exit() {
  int reply = JOptionPane.showConfirmDialog(null, "Save before exit?", "Exit", JOptionPane.YES_NO_CANCEL_OPTION, JOptionPane.INFORMATION_MESSAGE);
  if (reply != JOptionPane.CANCEL_OPTION) {
    if (reply == JOptionPane.YES_OPTION)
      saveAll();
    super.exit();
  }
}