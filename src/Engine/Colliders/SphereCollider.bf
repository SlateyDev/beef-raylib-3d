using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

class SphereCollider : Collider {
    public float radius;

    public override JPH_Shape* CreateShape() {
        var worldTransform = gameObject.GetWorldTransform();
        return (JPH_Shape*)JPH_SphereShape_Create(radius * Math.Max(Math.Max(worldTransform.scale.x, worldTransform.scale.y), worldTransform.scale.z));
    }
}