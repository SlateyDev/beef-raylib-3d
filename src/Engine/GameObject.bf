using RaylibBeef;
using System;
using System.Collections;

class GameObject : BaseObject {
    String _name;

    public override bool IsActiveInHierarchy {
        get {
            if (!scene.IsActive) return false;

            var current = this;
            while (current != null) {
                if (!current.IsActive) return false;
                current = current.parent;
            }
            return true;
        }
    }

    public Transform transform;

    public Transform GetWorldTransform() {
        if (parent == null) return transform;
        return Transform.GetWorldTransform(parent.GetWorldTransform(), transform);
    }

    public void SetWorldPositionAndRotation(Vector3* position, Quaternion* rotation) {
        if (parent == null) {
            transform.translation = *position;
            transform.rotation = *rotation;
        } else {
            var parentTransform = parent.GetWorldTransform();
            Transform childTransform = transform;
            childTransform.translation = *position;
            childTransform.rotation = *rotation;

            transform = Transform.GetLocalTransform(parentTransform, childTransform);
        }
    }

    public Scene scene { get; private set; };
    List<GameObject> children = new List<GameObject>() ~ DeleteContainerAndDisposeItems!(_);
    List<Component> components = new List<Component>() ~ DeleteContainerAndDisposeItems!(_);

    protected override void WakeInternal() {
        if (!IsActiveInHierarchy) return;

        for (var child in children) {
            if (!child.IsActiveInHierarchy) continue;
            child.WakeInternal();
        }

        for (var component in components) {
            if (!component.IsActive) continue;
            if (component.[Friend]awakeCalled) continue;
            component.[Friend]awakeCalled = true;
            component.Awake();
        }
    }

    public static GameObject Instantiate(Vector3 vector, Quaternion rotation, GameObject parent = null) {
        var gameObject = new GameObject();
        gameObject.transform = .(vector, rotation, .(1,1,1));
        gameObject.parent = parent;
        if (parent != null) parent.[Friend]children.Add(gameObject);
        gameObject.scene = parent?.scene ?? Program.game.[Friend]scene;
        gameObject.scene.[Friend]objectsInScene.Add(gameObject);
        return gameObject;
    }

    public T AddComponent<T>() where T: Component {
        var component = new T();
        component.[Friend]parent = this;
        components.Add(component);

        if (scene != null && scene.IsActive && IsActive && component.IsActive && !component.[Friend]awakeCalled) {
            component.Awake();
            component.[Friend]awakeCalled = true;
        }
        return component;
    }

    public void RemoveComponent(Component component) {
        component.Dispose();
        components.Remove(component);
    }

    private void DestroyInternal() {
        OnDestroy();
    }

    public void Update(float frameTime) {
        for (var component in components) {
            if (!component.[Friend]startCalled && component.IsActive) {
                component.[Friend]startCalled = true;
                component.Start();
            }
            component.Update(frameTime);
        }

        for (var child in children) {
            child.Update(frameTime);
        }
    }

    public void OnDestroy() {
        components.ClearAndDisposeItems();
        children.ClearAndDisposeItems();
    }

    public new void Dispose() {
        OnDestroy();

        base.Dispose();
    }
}