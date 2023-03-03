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
    println(this.directory);
    refresh();
  }
  
  // Lists file names that correspond to specified type.
  ArrayList<String> listFiles(String type) {
    // Get files that correspond to type.
    File[] files = new File(this.directory).listFiles(new FilenameFilter() { //<>// //<>//
      public boolean accept(File dir, String name) {
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

  PImage getArtificial(int i) { return _getImage(i, artificialImageFilenames); }
  
  PImage getBiological(int i) { return _getImage(i, biologicalImageFilenames); }
  
  PImage getImage(int i) {
    boolean indexIsEven = (i % 2 == 0);
    if (startsWithArtificial)
      return indexIsEven ? getArtificial(i / 2) : getBiological((i+1) / 2);
    else
      return indexIsEven ? getBiological(i / 2) : getArtificial((i+1) / 2);
  }
  
  PImage getLastArtificial() { return getArtificial(-1); }
  PImage getLastBiological() { return getBiological(-1); }

  PImage _getImage(int index, ArrayList<String> filenames) {
    if (index < 0)
      index = filenames.size() + index;
    
    return manager.getImage(filenames.get(index));
  }
   
  
}
