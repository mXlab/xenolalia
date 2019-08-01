/** 
 * This program allows to run different image projection tests on the Euglena petri dish and
 * to capture results on camera.
 *
 * The program allows to use either of these two libraries. On RPi we recommend
 * using GL Video.
 *  
 * (c) TeZ & Sofian Audry
 *
 *  For use with the Raspberry Pi camera, make sure the camera is
 *  enabled in the Raspberry Pi Configuration tool and add the line
 *  "bcm2835_v4l2" (without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */

/////
// import hypermedia.video.*;
import gab.opencv.*;
OpenCV opencv;
float scalefactor = 1.0, scaleX = 1.0, scaleY = 1.0 ;
float contrast = 2.0;
int brightness = 0;
int threshold = 100;
boolean useAdaptiveThreshold = false; // use basic thresholding
boolean screenmode = true;
boolean testvideo = false;
//boolean blobSwitch = true;
boolean bSwitch = true;
boolean srcswitch = true;
int thresholdBlockSize = 489;
int thresholdConstant = 45;
int blurSize = 4;
IntList bAreas;
IntList bX;
IntList bY;
int xID=0;
int xArea=0;
/////
import gohai.glvideo.*;
GLCapture video;
PImage img;  // Declare variable "a" of type PImage
int imagenum = 1;
boolean captureflag = false;
int capturephase = 0;
int capwidth, capheight; 

enum CameraMode {
  None,
  Test,
  Processed,  
}

CameraMode mode = CameraMode.None;

PImage newImage; 

PImage src, preProcessedImage, processedImage, contoursImage;
//record time-lapse 
boolean record = false;
boolean invert = true;

// All image patterns.
String imagez[]={
  "xeno-pattern-white.jpg", // 0
  "xeno-pattern-01.jpg", // 1 (default)
  "xeno-pattern-02.jpg", // 2
  "xeno-pattern-03.jpg", // 3
  "xeno-pattern-04.jpg", // 4
  "xeno-pattern-05.jpg", // 5
  "xeno-pattern-06.jpg", // 6
};


///////////////////////////////////////
void setup() {


  background(0);
  //size(800, 600, P2D);
  //size(600, 600, P2D);
  fullScreen(P2D);

  capwidth = capheight = 200;

  newImage = createImage(width, height, RGB);
  processedImage = createImage(capwidth, capheight, RGB);

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  if (0 < devices.length) {
    String[] configs = GLCapture.configs(devices[0]);
    println("Configs:");
    printArray(configs);
  }

  // this will use the first recognized camera by default
  //  video = new GLCapture(this, devices[0], width, height);
  video = new GLCapture(this, devices[0], capwidth, capheight);

  // you could be more specific also, e.g.
  //video = new GLCapture(this, devices[0]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  video.start();

  // Load default image into the program.
  loadImage();

  // opencv = new OpenCV(this, width, height);
  opencv = new OpenCV(this, capwidth, capheight);
}



///////////////////////////////////////
void draw() {

  // Capture video.
  if (video.available() && mode != CameraMode.None) {
    // Update video frame.
    video.read();
    
    // Print video out if needed.
    if (mode == CameraMode.Test) {
      image(video, 0, 0); // for test only
    }
  }
  
  if (mode != CameraMode.Test) {
      if (captureflag) {
        processImage();
        captureLoop();
      } else {          
        background(0, 100, 0);
        int ww=(width - img.width) /2;
        int hh=(height - img.height)/2;    
        if (mode == CameraMode.Processed) {
          background(255, 255, 255);
          fill(255, 0, 0);
          text("VIDMODE", 0, 0);
          // video.read();
          processImage();
          image(processedImage, 0, 0);
        } else {
          background(0);
          image(img, ww, hh);
        }
      }
    }

}

////////////////////////////////
void captureLoop() {

  if (capturephase==0)
  {
    capturephase = 1;
    background(255, 255, 255);
    video.read();
    processImage();
    // delay(1000);
  } else if (capturephase==1) {    
    background(255, 255, 255);
    capturephase = 2;
    delay(1000);
  } else if (capturephase==2) {   
    //newImage = processedImage.copy();
    // newImage.save("/home/pi/sketchbook/tezzy/xenopi/vid-cap.jpg");
    processedImage.save("vid-cap.jpg");
    delay(1000);
    capturephase = 0;
    captureflag = false;
    loadImage();
  }
}

/////////////////////////
void keyPressed() {

  // println("key = " + key);
  // Processed mode.
  if (key == 'v' || key == 'p') {
    mode = (mode == CameraMode.Processed ? CameraMode.None : CameraMode.Processed);
  }
  
  // Test mode.
  else if (key == 't') {
    mode = (mode == CameraMode.Test ? CameraMode.None : CameraMode.Test);
  }
  
  // Directly change to image number.
  else if ('0' <= key && key <= '9') {
    captureflag = false;
    imagenum = constrain((int)(key - '0'), 0, imagez.length-1);
    loadImage();
  }
  
  // Other keys.
  else if (key == CODED) {
    // Image caroussel: ->
    if (keyCode == RIGHT) {
      captureflag = false;
      if (imagenum <(imagez.length -1))
        imagenum++;
      else {
        imagenum = 0;
      }
      loadImage();
    // Image caroussel: <-
    } else if (keyCode == LEFT) {
      captureflag = false;
      if (imagenum > 0)
        imagenum--;
      else {
        imagenum = imagez.length -1;
      }
      loadImage();
    // Start capture.
    } else if (keyCode == UP) {
      print("UP");
      captureflag = true;
      // Captureimage();
    // Stop capture.
    } else if (keyCode == DOWN) {
      print("DOWN");
      captureflag = false;
    }
  }
}  

void setImageNum(int n) {
  imagenum = constrain(n, 0, imagez.length-1);
}

/////////////////////////
void loadImage() {
  pushMatrix();
  img = loadImage(imagez[imagenum]);
  popMatrix();
}

//////////////////////
void processImage() {

  // Load the new frame of our camera in to OpenCV
  // opencv.useColor();
  opencv.loadImage(video);
  //opencv.copy(video); 


  // Flips the image horizontally 
  //  opencv.flip(OpenCV.HORIZONTAL); 
  // opencv.flip(OpenCV.VERTICAL); 
  //  src = opencv.getSnapshot();



  ///////////////////////////////
  // <1> PRE-PROCESS IMAGE
  // - Grey channel 
  // - Brightness / Contrast
  ///////////////////////////////

  // Gray channel
  // opencv.gray();
  //opencv.brightness(brightness);
  // opencv.contrast(contrast);
  opencv.contrast(1.5);

  ///////////////////////////////
  // <2> PROCESS IMAGE
  // - Threshold
  // - Noise Supression
  ///////////////////////////////

  //  // Adaptive threshold - Good when non-uniform illumination
  //  if (useAdaptiveThreshold) {

  //    // Block size must be odd and greater than 3
  //    if (thresholdBlockSize%2 == 0) thresholdBlockSize++;
  //    if (thresholdBlockSize < 3) thresholdBlockSize = 3;

  //    opencv.adaptiveThreshold(thresholdBlockSize, thresholdConstant);

  //    // Basic threshold - range [0, 255]
  //  } else {
  //    opencv.threshold(threshold);
  //  }

  //  if(invert){
  //  // Invert (black bg, white blobs)
  //  opencv.invert();
  //  }

  //  // Reduce noise - Dilate and erode to close holes
  //  opencv.dilate();
  //  opencv.erode();

  //  // Blur
  //  opencv.blur(blurSize);


  // Save snapshot for display
  //   processedImage = opencv.getSnapshot();

  ///////////////////////////////
  // <3> FIND CONTOURS  
  ///////////////////////////////

  //detectBlobs();
  //// Passing 'true' sorts them by descending area.
  ////contours = opencv.findContours(true, true);
  //// Save snapshot for display
  //contoursImage = opencv.getSnapshot();

  processedImage = opencv.getSnapshot();
}
