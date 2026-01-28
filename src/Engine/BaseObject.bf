using System;
using System.Collections;

abstract class BaseObject : IDisposable {
    public GameObject parent { get; private set; }
    public GameObject gameObject {
        get {
            return (this is Component) ? parent : (GameObject)this;
        }
    }

    public T GetComponent<T>() where T: Component {
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                return component;
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
                return component;
            }
        }
        for (var child in gameObject.[Friend]children) {
            var component = child.GetComponentInChildren<T>();
            if (component != null) {
                return component;
            }
        }
        return null;
    }

    private void GetComponentsInChildrenInternal<T>(List<T> components) where T: Component {
        for (var component in gameObject.[Friend]components) {
            if (component is T) {
                components.Add(component);
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

    public bool IsActive {
        get;
        private set {
            IsActive = value;
            WakeInternal();
        }
    } = true;

    public abstract bool IsActiveInHierarchy { get; }

    protected abstract void WakeInternal();

    public void Destroy(BaseObject object) {
        if (object is Component) {
        } else if (var go = object as GameObject) {
            go.[Friend]DestroyInternal();
        }
    }

    public void Dispose() {
        Destroy(this);
        delete this;
    }
}