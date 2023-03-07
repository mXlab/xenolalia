// Learning Processing
// Daniel Shiffman
// http://www.learningprocessing.com

// Example 18-7: Loading a URL asynchronously

// Timer Class from Chapter 10
class Timer {

  int savedTime;
  boolean running = false;
  int totalTime;

  Timer(int totalTime) {
    this.totalTime = totalTime;
  }

  void setTotalTime(int tempTotalTime) {
    this.totalTime = totalTime;
  }

  void start() {
    running = true;
    savedTime = millis();
  }

  // Total time passed.
  int passedTime() { return millis() - savedTime; }

  // Countdown.
  int countdownTime() { return max(totalTime - passedTime(), 0); }

  // Progress (%).
  float progress() { return min(passedTime() / float(totalTime), 1); }

  boolean isFinished() {
   if (running && countdownTime() == 0) {
      running = false;
      return true;
    } else {
      return false;
    }
  }

}
