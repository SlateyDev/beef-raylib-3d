using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using System;

class CharacterController : Component {
    JPH_BodyID bodyId;
    JPH_CharacterVirtual* characterVirtual;
    JPH_Shape* capsuleShape;

    float moveSpeed = 400;
    float halfHeight = 0.9f;
    float radius = 0.3f;

    public float RotateSpeed = 200f;
    public float MouseSensitivity = 0.2f;

    private bool mMouseLocked = false;
    private bool mFirstMouse = false;

    private float deltaYaw = 0;

    public override void Awake() {
        capsuleShape = (JPH_Shape*)JPH_CapsuleShape_Create(halfHeight, radius);

        var characterVirtualSettings = new JPH_CharacterVirtualSettings();
        JPH_CharacterVirtualSettings_Init(characterVirtualSettings);
        var worldTransform = gameObject.GetWorldTransform();
        var position = worldTransform.translation;
        var rotation = worldTransform.rotation;

        characterVirtual = JPH_CharacterVirtual_Create(characterVirtualSettings, &position, (JPH_Quat*)&rotation, (uint64)(uint)Internal.UnsafeCastToPtr(this), PhysicsServer.[Friend]system);
        JPH_CharacterVirtual_SetShape(characterVirtual, capsuleShape, 0.05f, PhysicsServer.Layers.MOVING.Underlying, PhysicsServer.[Friend]system, null, null);
    }

    public override void Update(float frameTime) {
        HandleMouseInput();

        float inputX = 0;
        float inputZ = 0;

        if (Raylib.IsKeyDown(.KEY_A)) {
            inputX += 1;
        }
        if (Raylib.IsKeyDown(.KEY_D)) {
            inputX -= 1;
        }
        if (Raylib.IsKeyDown(.KEY_W)) {
            inputZ += 1;
        }
        if (Raylib.IsKeyDown(.KEY_S)) {
            inputZ -= 1;
        }

        Quaternion characterRotation = .(0,0,0,1);
        JPH_CharacterVirtual_GetRotation(characterVirtual, (JPH_Quat*)&characterRotation);
        Quaternion qYaw = Raymath.QuaternionFromAxisAngle(.(0,1,0), deltaYaw);
        deltaYaw = 0;
        characterRotation = Raymath.QuaternionMultiply(qYaw, characterRotation);
        JPH_CharacterVirtual_SetRotation(characterVirtual, (JPH_Quat*)&characterRotation);

        Vector3 desiredVelocity = .(0,0,0);
        JPH_CharacterVirtual_GetLinearVelocity(characterVirtual, &desiredVelocity);
        desiredVelocity.x = inputX * moveSpeed * frameTime;
        desiredVelocity.z = inputZ * moveSpeed * frameTime;
        desiredVelocity = Raymath.Vector3RotateByQuaternion(desiredVelocity, characterRotation);

        // Apply gravity if not grounded
        if (!JPH_CharacterBase_IsSupported((JPH_CharacterBase*)characterVirtual)) {
            desiredVelocity.y += -9.8f * frameTime;
        } else {
            if (Raylib.IsKeyPressed(.KEY_SPACE)) {
                desiredVelocity.y = 5;
            }
        }

        JPH_CharacterVirtual_SetLinearVelocity(characterVirtual, &desiredVelocity);

        JPH_CharacterVirtual_Update(characterVirtual,
            frameTime,
            PhysicsServer.Layers.MOVING.Underlying,
            PhysicsServer.[Friend]system,
            null,
            null
        );

        Vector3 position = .(0,0,0);
        Quaternion rotation = .(0,0,0,1);
        JPH_CharacterVirtual_GetPosition(characterVirtual, &position);
        JPH_CharacterVirtual_GetRotation(characterVirtual, (JPH_Quat*)&rotation);
        position.y -= halfHeight + radius;

        gameObject.SetWorldPositionAndRotation(&position, &rotation);
    }

    private void HandleMouseInput() {
        if (mMouseLocked) {
            Vector2 mouseDelta = Raylib.GetMouseDelta();
            if (mFirstMouse) {
                //Ignore first delta when mouse is clicked to stop jumping
                mFirstMouse = false;
                return;
            }

            deltaYaw -= mouseDelta.x * MouseSensitivity * Raymath.DEG2RAD;
        }

        if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT)) {
            mMouseLocked = true;
            mFirstMouse = true;
            Raylib.DisableCursor();
        } else if (Raylib.IsMouseButtonReleased(.MOUSE_BUTTON_RIGHT)) {
            mMouseLocked = false;
            Raylib.EnableCursor();
        }
    }
}