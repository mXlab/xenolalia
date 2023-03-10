// Learning Processing
// Daniel Shiffman
// http://www.learningprocessing.com

// Example 18-7: Loading a URL asynchronously

// Timer Class from Chapter 10
class Timer {

  int savedTime;
  int totalTime;

  Timer(int tempTotalTime) {
    totalTime = tempTotalTime;
  }

  void start() {
    savedTime = millis();
  }

  // Total time passed.
  int passedTime() {
    return millis() - savedTime;
  }

  // Countdown.
  int countdownTime() {
    return max(totalTime - passedTime(), 0);
  }

  // Progress (%).
  float progress() {
    return min(passedTime() / float(totalTime), 1);
  }

  boolean isFinished() {
    return (countdownTime() == 0);
  }
}
