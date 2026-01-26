using System;
using System.Collections;

abstract class BaseObject : IDisposable {
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