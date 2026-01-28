using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class BoxCollider : Collider {
    public Vector3 halfExtent;

    public override JPH_Shape* CreateShape() {
        return (JPH_Shape*)JPH_BoxShape_Create(&halfExtent, JPH_DEFAULT_CONVEX_RADIUS);
    }
}