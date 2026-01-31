using System;
using System.Collections;

abstract class BaseObject : IDisposable {
    private bool isActive = true;

    public GameObject parent { get; private set; }
    public GameObject gameObject {
        get {
            return (this is Component) ? parent : (GameObject)this;
        }
    }

    public T GetComponent<T>() where T: Component {
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                return (T)component;
            }
        }
        return null;
    }

    public List<T> GetComponents<T>() where T: Component {
        List<T> components = new List<T>();
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                components.Add((T)component);
            }
        }
        return components;
    }

    public T GetComponentInChildren<T>() where T: Component {
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                return (T)component;
            }
        }
        for (var child in gameObject.[Friend]children) {
            var component = child.GetComponentInChildren<T>();
            if (component != null) {
                return (T)component;
            }
        }
        return null;
    }

    private void GetComponentsInChildrenInternal<T>(List<T> components) where T: Component {
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                components.Add((T)component);
            }
        }
        for (var child in gameObject.[Friend]children) {
            child.GetComponentsInChildrenInternal<T>(components);
        }
    }

    public List<T> GetComponentsInChildren<T>() where T: Component {
        List<T> components = new List<T>();
        GetComponentsInChildrenInternal(components);
        return components;
    }

    public virtual bool IsActive {
        get {
            return isActive;
        }

        protected set {
            isActive = value;
            WakeInternal();
        }
    }

    public abstract bool IsActiveInHierarchy { get; }

    protected abstract void WakeInternal();

    public void Destroy(BaseObject object) {
        if (var component = object as Component) {
            object.gameObject.RemoveComponent(component);
        } else if (var go = object as GameObject) {
            go.[Friend]DestroyInternal();
            Program.game.[Friend]scene.objectsInScene.Remove(go);
        }
    }

    bool disposed = false;
    public void Dispose() {
        if (disposed) return;
        disposed = true;

        Destroy(this);
        delete this;
    }
}