import java.io.*;
import java.util.*;

ExperimentData[] loadExperiments(String filename) {
  String[] experimentUids = loadStrings(filename);
  ExperimentData[] experiments = new ExperimentData[experimentUids.length];
  for (int i=0; i<experiments.length; i++)
    experiments[i] = new ExperimentData(experimentUids[i]);
  return experiments;
}

/// Data from a single experiment.
class ExperimentData {
  String uid;
  String directory;
  
  boolean startsWithArtificial = true;
  
  ArrayList<String> artificialImageFilenames;
  ArrayList<String> biologicalImageFilenames;
  
  ExperimentData(String uid) {
    reload(uid);
  }
  
  ExperimentData copy() {
    return new ExperimentData(this.uid);
  }
  
  void reload(String uid) {
    this.uid = uid;
    this.directory = DATA_DIR + this.uid;
    refresh();
  }
  
  String getUid() { return uid; }
  
  // Returns file paths for a specific pipeline stage (e.g. "0trn", "1fil", "2res", "3ann").
  ArrayList<String> listPipelineFiles(String stage) {
    File[] files = new File(this.directory).listFiles(new FilenameFilter() {
      public boolean accept(File dir, String name) {
        return name.matches(".*_raw_" + stage + "\\.png");
      }
    });
    if (files == null) return new ArrayList<String>();
    ArrayList<String> filenames = new ArrayList<String>();
    for (File f : files)
      filenames.add(f.getPath());
    Collections.sort(filenames);
    return filenames;
  }

  // Lists code signature JSON files for this experiment.
  ArrayList<String> listCodeSignatureFiles() {
    File[] files = new File(this.directory).listFiles(new FilenameFilter() {
      public boolean accept(File dir, String name) {
        return name.matches(".*_raw_code_signature\\.json");
      }
    });
    if (files == null) return new ArrayList<String>();
    ArrayList<String> filenames = new ArrayList<String>();
    for (File f : files)
      filenames.add(f.getPath());
    Collections.sort(filenames);
    return filenames;
  }

  // Returns the code signature from the most recent step as a flat float array
  // [min[0..n-1], max[0..n-1], avg[0..n-1]], or null if unavailable.
  float[] getLatestActivations() {
    ArrayList<String> files = listCodeSignatureFiles();
    if (files.isEmpty()) return null;
    String path = files.get(files.size() - 1);
    try {
      JSONObject obj = loadJSONObject(path);
      JSONArray minArr = obj.getJSONArray("min");
      JSONArray maxArr = obj.getJSONArray("max");
      JSONArray avgArr = obj.getJSONArray("avg");
      int n = minArr.size();
      float[] values = new float[n * 3];
      for (int i = 0; i < n; i++) {
        values[i]       = minArr.getFloat(i);
        values[i + n]   = maxArr.getFloat(i);
        values[i + 2*n] = avgArr.getFloat(i);
      }
      return values;
    } catch (Exception e) {
      println("Warning: could not load code signature from " + path + ": " + e.getMessage());
      return null;
    }
  }

  PImage getLastPipelineImage(String stage) {
    // "col" = color perspective-corrected source; fall back to _bio_N.png for older experiments.
    if (stage.equals("col")) {
      ArrayList<String> files = listPipelineFiles("col");
      if (!files.isEmpty()) return manager.getImage(files.get(files.size() - 1));
      return getLastBiological();
    }
    ArrayList<String> files = listPipelineFiles(stage);
    if (files.isEmpty()) return null;
    return manager.getImage(files.get(files.size() - 1));
  }

  // Lists file names that correspond to specified type.
  ArrayList<String> listFiles(String type) {
    // Get files that correspond to type.
    File[] files = new File(this.directory).listFiles(new FilenameFilter() {
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
    // Prefer per-snapshot _4prj.png (live, postprocessed) over pre-generated _ann_N.png.
    artificialImageFilenames = listPipelineFiles("4prj");
    if (artificialImageFilenames.isEmpty())
      artificialImageFilenames = listFiles("ann");
    biologicalImageFilenames = listFiles("bio");
    startsWithArtificial = nArtificial() > nBiological();
  }
  
  // Returns whether image i (in DataType.ALL ordering) is ARTIFICIAL or BIOLOGICAL.
  DataType getDataType(int i) {
    boolean isEven = (i % 2 == 0);
    if (startsWithArtificial)
      return isEven ? DataType.ARTIFICIAL : DataType.BIOLOGICAL;
    else
      return isEven ? DataType.BIOLOGICAL  : DataType.ARTIFICIAL;
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
  
  PImage getArtificial(int i, ArtificialPalette palette) {
    PImage img = _getImage(i, artificialImageFilenames);
    if (img == null) return null;
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
    if (filenames.size() == 0)
      return null;
      
    if (index < 0)
      index = filenames.size() + index;

    if (index < 0 || index >= filenames.size())
      return null;

    return manager.getImage(filenames.get(index));
  }
    
}
