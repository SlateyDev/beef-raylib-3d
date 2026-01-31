using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

class BoxCollider : Collider {
    public Vector3 halfExtent;

    public override JPH_Shape* CreateShape() {
        var worldTransform = gameObject.GetWorldTransform();
        var scaledHalfExtent = halfExtent * worldTransform.scale;
        return (JPH_Shape*)JPH_BoxShape_Create(&scaledHalfExtent, JPH_DEFAULT_CONVEX_RADIUS);
    }
}