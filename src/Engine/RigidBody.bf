using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;
using System.Interop;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class RigidBody : Component {
    public JPH_MotionType motionType = .Dynamic;

    JPH_BodyID bodyId;
    Vector3 offset = .(0, 0, 0);

    public override void Awake() {
        var colliders = GetComponents<Collider>();
        defer delete colliders;

        JPH_Shape* shape;
        Vector3 shapePos = gameObject.GetWorldTransform().translation;

        if (colliders.Count == 1) {
            shape = colliders[0].CreateShape();
            offset = colliders[0].offset;
            shapePos += offset;
        } else {
            var settings = JPH_StaticCompoundShapeSettings_Create();
            for (var collider in colliders) {
                shape = collider.CreateShape();
                JPH_CompoundShapeSettings_AddShape2((JPH_CompoundShapeSettings*)settings, &Vector3(0, 0, 0), (JPH_Quat*)&Quaternion(0, 0, 0, 1), shape, 0);
            }
            var compoundShape = JPH_StaticCompoundShape_Create(settings);
            shape = (JPH_Shape*)compoundShape;
        }

        uint32 layer = motionType == .Static ? PhysicsServer.Layers.NON_MOVING.Underlying : PhysicsServer.Layers.MOVING.Underlying;
        var bodyCreationSettings = JPH_BodyCreationSettings_Create3(shape, &shapePos, (JPH_Quat*)&gameObject.GetWorldTransform().rotation, motionType, layer);
        JPH_BodyCreationSettings_SetUserData(bodyCreationSettings, (uint64)(uint)Internal.UnsafeCastToPtr(this));
        bodyId = PhysicsServer.CreateAndAddBody(bodyCreationSettings, JPH_Activation.Activate);
        PhysicsServer.JPH_BodyCreationSettings_Destroy(bodyCreationSettings);
    }

    public void ApplyAngularImpulse(Vector3 impulse) {
        var impulse;
        JPH_BodyInterface_AddAngularImpulse(PhysicsServer.[Friend]bodyInterface, bodyId, &impulse);
    }

    public void AddForce(Vector3 force) {
        JPH_BodyInterface_AddForce(PhysicsServer.[Friend]bodyInterface, bodyId, &force);
    }

    public void AddForce(Vector3 force, Vector3 point) {
        var force, point;
        JPH_BodyInterface_AddForce2(PhysicsServer.[Friend]bodyInterface, bodyId, &force, &point);
    }

    public void AddTorque(Vector3 torque) {
        var torque;
        JPH_BodyInterface_AddTorque(PhysicsServer.[Friend]bodyInterface, bodyId, &torque);
    }

    public void AddForceAndTorque(Vector3 force, Vector3 torque) {
        var force, torque;
        JPH_BodyInterface_AddForceAndTorque(PhysicsServer.[Friend]bodyInterface, bodyId, &force, &torque);
    }

    public void AddImpulse(Vector3 impulse) {
        var impulse;
        JPH_BodyInterface_AddImpulse(PhysicsServer.[Friend]bodyInterface, bodyId, &impulse);
    }

    public void AddImpulse(Vector3 impulse, Vector3 point) {
        var impulse, point;
        JPH_BodyInterface_AddImpulse2(PhysicsServer.[Friend]bodyInterface, bodyId, &impulse, &point);
    }
}