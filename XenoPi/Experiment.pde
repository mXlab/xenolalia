class Experiment {
  
  // Experiment info.
  ExperimentInfo info;
  
  // Number of snapshots taken thus far.
  int nSnapshots;
  
  // Start time of experiment (in ms).
  int startTimeMs;

  String baseImageFilename;
  
  Experiment() {
  }
  
  void start(PImage baseImage) {
    info = new ExperimentInfo();
    startTimeMs = millis();
    info.saveInfoFile(savePath(experimentDir()+"/info.json"));

    // Preserve settings.json file.
    saveJSONObject(loadJSONObject(SETTINGS_FILE_NAME), savePath(experimentDir()+"/settings.json"));
    baseImageFilename = savePath(experimentDir()+"/base_image.png");
    baseImage.save(baseImageFilename);

    // Send message that a new experiment has started.
    OscMessage msg = new OscMessage("/xeno/euglenas/new");
    oscP5.send(msg, remoteLocation);
  }
  
  ExperimentInfo getInfo() {
    return info;
  }
  
  // Time elapsed since beginning of experiment.
  int elapsedTime() {
    return (millis() - startTimeMs);
  }

  String experimentDir() {
    return "snapshots/"+info.getUid();
  }

  // Saves snapshot to disk and sends OSC message to announce creation of new image.
  void recordSnapshot(PImage snapshot) {
    // Generate image paths.
    String basename = "snapshot_"+nSnapshots+"_"+nf(elapsedTime(), 8);
    String prefix = experimentDir()+"/"+basename;

    String rawImageFilename = savePath(prefix+"_raw.png");
    boolean firstSnapshotExternal = (nSnapshots == 0 && settings.seedImage() != "euglenas");
    
    if (!firstSnapshotExternal)
      snapshot.save(rawImageFilename);

    // Send an OSC message to announce creation of new image.
    OscMessage msg = new OscMessage("/xeno/euglenas/" + (firstSnapshotExternal ? "begin" : "step"));
    msg.add(rawImageFilename);
    msg.add(baseImageFilename);

    oscP5.send(msg, remoteLocation);

    // Update snapshot counter.
    nSnapshots++;
  }
  
}
