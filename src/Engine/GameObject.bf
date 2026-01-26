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

    public Transform transform { get; set; }

    public Scene scene { get; private set; };
    GameObject parent;
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

    public static void Instantiate(GameObject original, Vector3 vector, Quaternion rotation, GameObject parent = null) {
    }

    public void AddComponent<T>() where T: Component {
        switch (typeof(T).CreateObject()) {
            case .Ok(let component):
                var castComponent = (T)component;
                castComponent.[Friend]parent = this;
                components.Add(castComponent);
    
                if (!IsActive || !castComponent.IsActive || castComponent.[Friend]awakeCalled) return;
                castComponent.Awake();
                castComponent.[Friend]awakeCalled = true;
            case .Err:
                Runtime.FatalError(scope $"Unable to create component of type {typeof(T).GetName(.. scope .())}");
        }
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