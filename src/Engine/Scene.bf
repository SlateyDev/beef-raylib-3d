using RaylibBeef;
using System;
using System.Collections;

class Scene {
    public bool IsActive { get; private set; }

    List<GameObject> objectsInScene = new List<GameObject>(1024) ~ {
        List<GameObject> objectsToDispose = scope List<GameObject>();
        for (var sceneObject in _) {
            if (sceneObject.[Friend]parent != null) continue;
            objectsToDispose.Add(sceneObject);
        }
        for (var sceneObject in objectsToDispose) {
            sceneObject.Dispose();
        }
        ClearAndDeleteItems!(objectsToDispose);
        delete _;
    }

    List<BaseObject> objectsToCleanup = new List<BaseObject>(32) ~ delete _;

    public void WakeScene() {
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

        while (!objectsToCleanup.IsEmpty) {
            var obj = objectsToCleanup.PopBack();
            if (var component = obj as Component) {
                component.parent.[Friend]components.Remove(component);
                delete component;
            } else if (var go = obj as GameObject) {
                if (go.parent != null) go.parent.[Friend]children.Remove(go);
                objectsInScene.Remove(go);
                delete go;
            }
        }
    }

    List<Renderable> renderables = new List<Renderable>(1024) ~ delete _;

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

    public void Render(Frustum* cameraFrustum, bool shadowRender = false) {
        if (!IsActive) return;

        List<Renderable> renderablesToDraw = scope List<Renderable>();

        for (var renderable in renderables) {
            if (shadowRender && !renderable.hasShadow) continue;
            var sphere = renderable.GetBoundingSphere();
            if (cameraFrustum.SphereIn(&sphere.Center, sphere.Radius)) {
                renderablesToDraw.Add(renderable);

                /*//Ray Picking Example
                var raySphereCollision = Raylib.GetRayCollisionSphere(ray, sphere.Center, sphere.Radius);
                if (raySphereCollision.hit) {
                    for (var meshIndex < model.mModel.meshCount) {
                        var rayMeshCollision = Raylib.GetRayCollisionMesh(ray, model.mModel.meshes[meshIndex], Raymath.MatrixMultiply(model.mModel.transform, model.Transform()));
                        if (rayMeshCollision.hit) {
                            if (rayMeshCollision.distance < closestCollision.distance) {
                                closestCollision = rayMeshCollision;
                                closestModelIndex = modelsToDraw.Count - 1;
                            }
                        }
                    }
                }*/
            }
        }

        for (let renderable in renderablesToDraw) {
            renderable.Render();
        }
    }
}