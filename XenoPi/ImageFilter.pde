// Allows the filtering of a sequence of images according to either
// average or median of images.
class ImageFilter {
  // List of images.
  ArrayList<PImage> images;
  
  // True iff use average - otherwise use median.
  boolean useAverage;

  // Number of iterations for the geometric median computation.
  final int MEDIAN_N_ITERATIONS = 20;
  
  ImageFilter() {
    this(false);
  }

  ImageFilter(boolean useAverage) {
    images = new ArrayList<PImage>();
    this.useAverage = useAverage;
  }

  // Resets filter.
  void reset() {
    images.clear();
  }

  // Current number of images in filter.
  int nImages() {
    return images.size();
  }

  // Adds an image.
  void addImage(PImage img) {
    images.add(img);
  }

  // Returns median image (geometric median).
  // Based on: https://github.com/ialhashim/geometric-median/blob/master/geometric-median.h
  PImage getMedian() {
    if (nImages() < 2)
      return null;

    // Initialize.
    PImage firstImage = images.get(0);
    PImage secondImage = images.get(1);
    PImage medianImg = createImage(firstImage.width, firstImage.height, RGB);
    medianImg.loadPixels();
    for (PImage img : images)
      img.loadPixels();


    int nPixels = medianImg.pixels.length;
    // Iterate over pixels.
    for (int p = 0; p < nPixels; p++) {
      color pix1 = firstImage.pixels[p];
      color pix2 = secondImage.pixels[p];

      // Initial guess.
      color pixMix = lerpColor(pix1, pix2, 0.5);
      double[][] A = { { red(pixMix), green(pixMix), blue(pixMix) }, 
                       { red(pixMix), green(pixMix), blue(pixMix) } };

      // Geometric median approximation algorithm.
      for (int it=0; it<MEDIAN_N_ITERATIONS; it++) {
        double[] numerator = new double[3];
        double denominator = 0;

        int t = it%2;

        // Iterate over images.
        for (PImage img : images) {
          color pix = img.pixels[p];
          double dist = distColor(pix, A[t]);

          if (dist > 0) {
            numerator[0] += red(pix)   / dist;
            numerator[1] += green(pix) / dist;
            numerator[2] += blue(pix)  / dist;
            denominator += 1.0 / dist;
          }
        }
        
        if (denominator > 0) {
          A[1-t][0] = numerator[0] / denominator;
          A[1-t][1] = numerator[1] / denominator;
          A[1-t][2] = numerator[2] / denominator;
        }
     }

      // Assign pixel.
      double[] geometricMedian = A[MEDIAN_N_ITERATIONS % 2];
      medianImg.pixels[p] = color( round((float)geometricMedian[0]), round((float)geometricMedian[1]), round((float)geometricMedian[2]) );
    }
    
    // Update pixels.
    medianImg.updatePixels();
    return medianImg;
  }

  // Returns average image. (Code by Pamela Coulombe.)
  PImage getAverage() {
    if (images.isEmpty())
      return null;

    // Initialize.
    PImage firstImage = images.get(0);
    PImage averageImg = createImage(firstImage.width, firstImage.height, RGB);
    averageImg.loadPixels();
    for (PImage img : images)
      img.loadPixels();

    int nPixels = averageImg.pixels.length;
    // Iterate over each pixel.
    for (int p = 0; p < nPixels; p++) {

      // Channel sums.
      int sumRed = 0;
      int sumGreen = 0;
      int sumBlue = 0;

      // Iterate over all images.
      for (PImage img : images) {
        // Increment sums.
        color pix = img.pixels[p];
        sumRed   += red(pix);
        sumGreen += green(pix);
        sumBlue  += blue(pix);
      }

      // Channel averages.
      sumRed   /= nImages();
      sumGreen /= nImages();
      sumBlue  /= nImages();

      // Assign average value.
      averageImg.pixels[p] = color(sumRed, sumGreen, sumBlue);
    }

    // Update.
    averageImg.updatePixels();
    return averageImg;
  }
  
  // Returns filtered image.
  PImage getImage() {
    return useAverage ? getAverage() : getMedian();
  }
  
  // Internal use (for median approximation).
  double distColor(color c1, double[] c2) {
    float diffR = red(c1)   - (float)c2[0];
    float diffG = green(c1) - (float)c2[1];
    float diffB = blue(c1)  - (float)c2[2];
    return sqrt( sq(diffR) + sq(diffG) + sq(diffB) );
  }

}
