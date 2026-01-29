using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class MeshBoundingBoxCollider : Collider {
    public Vector3 halfExtent;

    public override JPH_Shape* CreateShape() {
        var worldTransform = gameObject.GetWorldTransform();
        var meshRenderer = GetComponent<MeshRenderer>();
        var boundingBox = meshRenderer.boundingBox;
        halfExtent = (boundingBox.max - boundingBox.min) * worldTransform.scale * 0.5f;
        offset = (boundingBox.max + boundingBox.min) * worldTransform.scale * 0.5f;
        return (JPH_Shape*)JPH_BoxShape_Create(&halfExtent, JPH_DEFAULT_CONVEX_RADIUS);
    }
}