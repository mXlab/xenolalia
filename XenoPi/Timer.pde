// Learning Processing
// Daniel Shiffman
// http://www.learningprocessing.com

// Example 18-7: Loading a URL asynchronously

// Timer Class from Chapter 10
class Timer {

  int savedTime;
  boolean running = false;
  int totalTime;

  Timer(int tempTotalTime) {
    totalTime = tempTotalTime;
  }

  void start() {
    running = true;
    savedTime = millis();
  }

  int passedTime() { return millis() - savedTime; }
  int countdownTime() { return max(totalTime - passedTime(), 0); }
  
  boolean isFinished() {
   if (running && countdownTime() == 0) {
      running = false;
      return true;
    } else {
      return false;
    }
  }

}
