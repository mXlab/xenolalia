// Displayed instead of GenerativeMode when no camera is available.
class NoCameraMode extends AbstractMode {

  void setup() {}

  void draw() {
    background(0);
    noCursor();

    textAlign(CENTER, CENTER);

    fill(220, 60, 60);
    textSize(28);
    text("Generative mode requires a camera.", width / 2, height / 2 - 30);

    fill(150);
    textSize(16);
    text("Camera not initialized (GLVideo unavailable).", width / 2, height / 2 + 10);
    text("Press 'k' for calibration  |  's' for symbol mode", width / 2, height / 2 + 40);
  }

  void keyPressed() {}
}
