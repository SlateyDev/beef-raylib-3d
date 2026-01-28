using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class SphereCollider : Collider {
    public float radius;

    public override JPH_Shape* CreateShape() {
        return (JPH_Shape*)JPH_SphereShape_Create(radius);
    }
}