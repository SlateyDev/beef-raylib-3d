using Jolt;
using static Jolt.Jolt;
using RaylibBeef;
using SDL2;
using System;

class CharacterRotator : Component {
    JPH_BodyID bodyId;
    JPH_CharacterVirtual* characterVirtual;
    JPH_CharacterContactListener* characterContactListener;
    JPH_Shape* capsuleShape;

    float moveSpeed = 400;
    float halfHeight = 0.9f;
    float radius = 0.3f;

    public float RotateSpeed = 200f;
    public float MouseSensitivity = 0.2f;

    private bool mMouseLocked = false;
    private bool mFirstMouse = false;

    private float deltaYaw = 0;

    public override void Update(float frameTime) {
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

        var gameController = Program.[Friend]gameController;
        if (gameController != null) {
            var gamepadX = -GamepadHelper.normalizeGamepadAxis(SDL.GameControllerGetAxis(gameController, .RightX));
            var gamepadY = -GamepadHelper.normalizeGamepadAxis(SDL.GameControllerGetAxis(gameController, .RightY));

            if (Math.Abs(gamepadX) > 0 || Math.Abs(gamepadY) > 0) {
                inputX = gamepadX;
                inputZ = gamepadY;
            }
        }

        if (!(Math.Abs(inputX) > 0 || Math.Abs(inputZ) > 0)) return;

        Vector3 moveDir = .(inputX, 0, inputZ);
        if (moveDir.x * moveDir.x + moveDir.z * moveDir.z > 0.0f) {
            moveDir = Raymath.Vector3Normalize(moveDir);

            float yaw = Math.Atan2(moveDir.x, moveDir.z);
            var rotation = Raymath.QuaternionFromAxisAngle(.(0,1,0), yaw);
            gameObject.transform.rotation = rotation;
        }
    }
}