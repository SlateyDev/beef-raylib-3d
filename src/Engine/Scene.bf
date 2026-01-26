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

    List<Renderable> renderables = new List<Renderable>() ~ delete _;

    private void TraverseGameObjectRenderables(GameObject parent) {
        AddRenderables(parent);
        for (var gameObject in parent.[Friend]children) {
            if (!gameObject.IsActive) continue;
            TraverseGameObjectRenderables(gameObject);
        }
    }

    private void AddRenderables(GameObject parent) {
        for (var component in parent.[Friend]components) {
            if (!component.IsActive) continue;
            if (!(component is Renderable)) continue;
            renderables.Add((Renderable)component);
        }
    }

    public void RefreshRenderables() {
        renderables.Clear();

        for (var sceneObject in objectsInScene) {
            if (sceneObject.[Friend]parent != null) continue;
            if (!sceneObject.IsActive) continue;
            TraverseGameObjectRenderables(sceneObject);
        }
    }

    public void Render() {
        if (!IsActive) return;

        for (var renderable in renderables) {
            renderable.Render();
        }
    }
}