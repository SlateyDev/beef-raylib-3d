using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class RigidBody : Component {
    public JPH_MotionType motionType = .Static;

    JPH_BodyCreationSettings* settings;
    JPH_BoxShape* shape;
    
    public override void Awake() {
        var colliders = GetComponents<Collider>();
        defer delete colliders;

        JPH_Shape* shape;

        if (colliders.Count == 1) {
            shape = colliders[0].CreateShape();
        } else {
            var settings = JPH_StaticCompoundShapeSettings_Create();
            for (var collider in colliders) {
                shape = collider.CreateShape();
                JPH_CompoundShapeSettings_AddShape2((JPH_CompoundShapeSettings*)settings, &collider.offset, (JPH_Quat*)&Quaternion(0, 0, 0, 1), shape, 0);
            }
            var compoundShape = JPH_StaticCompoundShape_Create(settings);
            shape = (JPH_Shape*)compoundShape;
        }

        var bodyCreationSettings = JPH_BodyCreationSettings_Create3(shape, &gameObject.GetWorldTransform().translation, (JPH_Quat*)&gameObject.GetWorldTransform().rotation, motionType, PhysicsServer.Layers.MOVING.Underlying);
        PhysicsServer.CreateAndAddBody(bodyCreationSettings, JPH_Activation.Activate);
        PhysicsServer.JPH_BodyCreationSettings_Destroy(bodyCreationSettings);
    }
}