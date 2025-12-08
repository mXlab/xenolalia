class SceneManager extends ArrayList<Scene> {
  int currentSceneIdx = 0;
  
  void start() {
    currentScene().start();  
  }
  
  Scene currentScene() {
    return get(currentSceneIdx);
  }

  Scene nextScene() {
    currentScene().end();
    currentSceneIdx = (currentSceneIdx + 1) % size();
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
