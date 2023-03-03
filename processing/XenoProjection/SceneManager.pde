class SceneManager extends ArrayList<Scene> {
  int currentSceneIdx = 0;
  
  Scene currentScene() { return get(currentSceneIdx); }
  
  Scene nextScene() {
    currentSceneIdx = (currentSceneIdx + 1) % size();
    currentScene().reset();
    return currentScene();
  }
}
