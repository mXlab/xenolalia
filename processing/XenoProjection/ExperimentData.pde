import java.io.*;
import java.util.*;


class ExperimentData {
  String uid;
  String directory;
  
  boolean startsWithArtificial = true;
  
  ArrayList<String> artificialImageFilenames;
  ArrayList<String> biologicalImageFilenames;
  
  ExperimentData(String uid) {
    this.uid = uid;
    this.directory = DATA_DIR + this.uid;
    refresh();
  }
  
  // Lists file names that correspond to specified type.
  ArrayList<String> listFiles(String type) {
    // Get files that correspond to type.
    File[] files = new File(this.directory).listFiles(new FilenameFilter() {
      public boolean accept(File dir, String name) { //<>//
        return name.matches(".*_" + type + "_[0-9]*.png");
      }
    });
  
    // Convert to filenames.
    ArrayList<String> filenames = new ArrayList<String>();
    for (File f : files) {
      filenames.add(f.getPath());
    }
    
    // Sort in alphanumerical order.
    Collections.sort(filenames);
    return filenames;
  }
  
  /// Rereads folder to see if there is any new images.
  void refresh() {
    artificialImageFilenames = listFiles("ann");
    biologicalImageFilenames = listFiles("bio");
    startsWithArtificial = nArtificial() > nBiological();
  }
  
  int nArtificial() { return artificialImageFilenames.size(); }
  int nBiological() { return biologicalImageFilenames.size(); }
  int nImages() { return nArtificial() + nBiological(); }
  int nImages(DataType type) {
    switch (type) {
      case ARTIFICIAL: return nArtificial();
      case BIOLOGICAL: return nBiological();
      case ALL:        return nImages();
    }
    return 0;
  }
   //<>//
  PImage getArtificial(int i, ArtificialPalette palette) {
    PImage img = _getImage(i, artificialImageFilenames);
    PGraphics pg = createGraphics(img.width, img.height);
    pg.beginDraw();
    if (palette == ArtificialPalette.MAGENTA)
      pg.tint(255, 0, 255);
    pg.image(img, 0, 0);
    if (palette == ArtificialPalette.BLACK)
      pg.filter(INVERT);
    pg.endDraw();
    return pg.get();
  }

  PImage getArtificial(int i) { return getArtificial(i, ArtificialPalette.WHITE); }
  
  PImage getBiological(int i) { return _getImage(i, biologicalImageFilenames); }
  
  PImage getImage(int i) {
    return getImage(i, ArtificialPalette.WHITE);
  }
  
  PImage getImage(int i, ArtificialPalette palette) {
    boolean indexIsEven = (i % 2 == 0);
    i = i/2;
    if (startsWithArtificial)
      return indexIsEven ? getArtificial(i, palette) : getBiological(i);
    else
      return indexIsEven ? getBiological(i) : getArtificial(i, palette);
  }
  
  PImage getImage(int i, DataType type) {
    return getImage(i, type, ArtificialPalette.WHITE);
  }
  
  PImage getImage(int i, DataType type, ArtificialPalette palette) {
    switch (type) {
      case ARTIFICIAL: return getArtificial(i, palette);
      case BIOLOGICAL: return getBiological(i);
      case ALL:        return getImage(i, palette);
    }
    return null;
  }
  
  PImage getLastArtificial() { return getArtificial(-1); }
  PImage getLastBiological() { return getBiological(-1); }

  PImage _getImage(int index, ArrayList<String> filenames) {
    if (index < 0)
      index = filenames.size() + index;
    
    return manager.getImage(filenames.get(index)); //<>//
  }
   
  
}
