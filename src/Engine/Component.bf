using System;

abstract class Component : BaseObject {
    public GameObject parent { get; private set; }
    bool awakeCalled;
    bool startCalled;

    protected override void WakeInternal() {
        if (awakeCalled) return;
        if (!IsActiveInHierarchy) return;

        awakeCalled = true;
        Awake();
    }

    public override bool IsActiveInHierarchy {
        get {
            if (!IsActive) return false;
            if (parent == null) return false;
            if (!parent.IsActiveInHierarchy) return false;
            return true;
        }
    }

    public virtual void Awake() {}
    public virtual void OnEnable() {}
    public virtual void Start() {}

    public virtual void Update(float frameTime) {}
    //public virtual void FixedUpdate(float frameTime) {}
    //public virtual void LateUpdate(float frameTime) {}

    public virtual void OnDisable() {}
    public virtual void OnDestroy() {}

    public new void Dispose() {
        OnDestroy();

        base.Dispose();
    }
}