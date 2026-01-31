using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

class CharacterControllerDebugRenderer : Renderable {
    float halfHeight = 0;
    float radius = 0;

    public this() {
        hasShadow = false;
    }

    public override void Awake() {
        var characterController = GetComponent<CharacterController>();
        halfHeight = characterController.[Friend]halfHeight;
        radius = characterController.[Friend]radius;
    }

    public override void Render() {
        var worldTransform = parent.GetWorldTransform();

        JPH_Mat4 matrixTR;
        worldTransform.translation.y += halfHeight + radius;
        JPH_Mat4_RotationTranslation(&matrixTR, (JPH_Quat*)&worldTransform.rotation, &worldTransform.translation);
        var white = 0xffffffff;
        JPH_DebugRenderer_DrawCapsule(
            PhysicsServer.[Friend]debugRenderer,
            &matrixTR,
            halfHeight,
            radius,
            *(JPH_Color*)&white,
            .Off,
            .Wireframe
        );

    }
}