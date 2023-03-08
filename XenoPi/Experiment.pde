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
    // Generate info.
    info = new ExperimentInfo();
    
    // Start time.
    startTimeMs = millis();

    // Save info file.
    info.saveInfoFile(savePath(experimentDir()+"/info.json"));
    
    // Preserve settings.json file.
    saveJSONObject(loadJSONObject(SETTINGS_FILE_NAME), savePath(experimentDir()+"/settings.json"));
    
    // Save base image.
    baseImageFilename = savePath(experimentDir()+"/base_image.png");
    baseImage.save(baseImageFilename);

    // Send messages that a new experiment has started.
    oscP5.send(new OscMessage("/xeno/euglenas/new"), remoteLocation);
    updateServer("new");
  }
  
  
  ExperimentInfo getInfo() {
    return info;
  }
  
  // Time elapsed since beginning of experiment.
  int elapsedTime() {
    return (millis() - startTimeMs);
  }

  String experimentDir() {
    return "snapshots/"+(info != null ? info.getUid() : "default_exp");
  }
  
  int nSnapshots() {
    return nSnapshots;
  }

  // Saves snapshot to disk and sends OSC message to announce creation of new image.
  void recordSnapshot(PImage snapshot) {
    // Generate image paths.
    String basename = "snapshot_"+nf(nSnapshots, 2)+"_"+nf(elapsedTime(), 8);
    String prefix = experimentDir()+"/"+basename;

    String rawImageFilename = savePath(prefix+"_raw.png");
    boolean firstSnapshotExternal = (nSnapshots == 0 && settings.seedImage() != "euglenas");
    
    if (!firstSnapshotExternal)
      snapshot.save(rawImageFilename);

    // Send an OSC message to announce creation of new image.
    String msgType = (firstSnapshotExternal ? "begin" : "step");
    OscMessage msg = new OscMessage("/xeno/euglenas/" + msgType);
    msg.add(rawImageFilename);
    msg.add(baseImageFilename);

    oscP5.send(msg, remoteLocation);

    // Update snapshot counter.
    nSnapshots++;
  }
  
  void updateServer(String addr) {
    OscMessage msg = new OscMessage("/xeno/exp/" + addr);
    msg.add(info.getUid());
    oscP5.send(msg, remoteLocationServer);
  }
}
