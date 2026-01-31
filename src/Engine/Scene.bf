using RaylibBeef;
using System;
using System.Collections;

class Scene {
    public bool IsActive { get; private set; }

    //TODO: bad this is public, but hack for jam
    public List<GameObject> objectsInScene = new List<GameObject>() ~ {
        List<GameObject> objectsToDispose = scope List<GameObject>();
        for (var sceneObject in _) {
            if (sceneObject.[Friend]parent != null) continue;
            objectsToDispose.Add(sceneObject);
        }
        for (var sceneObject in objectsToDispose) {
            sceneObject.Dispose();
        }
        delete _;
    }

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