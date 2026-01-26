using System;
using System.Collections;

class Scene {
    public bool IsActive { get; private set; }

    List<GameObject> objectsInScene = new List<GameObject>() ~ DeleteContainerAndDisposeItems!(_);

    public void WakeScene() {
        for (var sceneObject in objectsInScene) {
            sceneObject.[Friend]scene = this;
        }

        IsActive = true;
        for (var sceneObject in objectsInScene) {
            sceneObject.[Friend]WakeInternal();
        }
    }

    public void Update(float frameTime) {
        if (!IsActive) return;

        for (var sceneObject in objectsInScene) {
            if (sceneObject.[Friend]parent != null) continue;
            if (!sceneObject.IsActive) continue;
            sceneObject.Update(frameTime);
        }
    }
}