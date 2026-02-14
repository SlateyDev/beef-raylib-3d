using System;
using System.Collections;

abstract class BaseObject : IDisposable {
    private bool isActive = true;
    private bool isDisposed = false;

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
            return !isDisposed && isActive;
        }

        protected set {
            if (isDisposed) return;

            isActive = value;
            WakeInternal();
        }
    }

    public abstract bool IsActiveInHierarchy { get; }

    protected abstract void WakeInternal();

    public virtual void OnDestroy() {}

    public void Destroy() {
        if (isDisposed) return;

        OnDestroy();

        if (var component = this as Component) {
            Program.game.[Friend]scene.[Friend]objectsToCleanup.Add(component);
        } else if (var go = this as GameObject) {
            Program.game.[Friend]scene.[Friend]objectsToCleanup.Add(go);
            for (var child in go.[Friend]children) {
                child.Destroy();
            }
            for (var component in go.[Friend]components) {
                component.Destroy();
            }
        }
        Dispose();
    }

    public static void Destroy(BaseObject object) {
        object.Destroy();
    }

    public void Dispose() {
        if (isDisposed) return;
        isDisposed = true;
        isActive = false;
    }
}