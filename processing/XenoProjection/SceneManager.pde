class SceneManager extends ArrayList<Scene> {
  int currentSceneIdx = 0;
  
  void start() {
    currentScene().start();  
  }
  
  Scene currentScene() {
    return get(currentSceneIdx);
  }

  boolean hasEnabledScene() {
    for (Scene s : this) if (s.isEnabled()) return true;
    return false;
  }

  Scene nextScene() {
    currentScene().end();
    int startIdx = currentSceneIdx;
    do {
      currentSceneIdx = (currentSceneIdx + 1) % size();
    } while (!currentScene().isEnabled() && currentSceneIdx != startIdx);
    currentScene().reset();
    currentScene().start();
    return currentScene();
  }

  void replaceCurrentScene(Scene scene) {
    currentScene().end();
    set(currentSceneIdx, scene);
    scene.reset();
  }
  
  void setCurrentScene(int idx) {
    currentScene().end();
    currentSceneIdx = idx;
    currentScene().reset();
    currentScene().start();
  }
}
