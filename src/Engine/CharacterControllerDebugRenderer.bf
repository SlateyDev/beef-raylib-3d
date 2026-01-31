using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

class CharacterControllerDebugRenderer : Renderable {
    public this() {
        hasShadow = false;
    }

    public override void Render() {
        var worldTransform = parent.GetWorldTransform();

        JPH_Mat4 matrixTR;
        worldTransform.translation.y += 0.9f + 0.3f;
        JPH_Mat4_RotationTranslation(&matrixTR, (JPH_Quat*)&worldTransform.rotation, &worldTransform.translation);
        var white = 0xffffffff;
        JPH_DebugRenderer_DrawCapsule(
            PhysicsServer.[Friend]debugRenderer,
            &matrixTR,
            0.9f,
            0.3f,
            *(JPH_Color*)&white,
            .Off,
            .Wireframe
        );

    }
}