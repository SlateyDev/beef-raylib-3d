using System;
using RaylibBeef;

namespace game;

class Player
{
    public Vector3 Position;
    public float RotationAngle;
    public float MoveSpeed = 0.2f;

    public Camera3D camera;

    public this(Vector3 startPosition) {
        Position = startPosition;
        RotationAngle = 0.0f;
    }

    public void Update() {
        // Calculate forward and right vectors based on rotation
        float radians = MathUtils.DegreesToRadians(RotationAngle);
        Vector3 forward = .(
            Math.Cos(radians),
            0,
            Math.Sin(radians)
        );
        Vector3 right = .(
            Math.Cos(radians + Math.PI_f/2),
            0,
            Math.Sin(radians + Math.PI_f/2)
        );

        // Handle movement relative to looking direction
        if (Raylib.IsKeyDown(.KEY_W)) {
            Position.x += forward.x * MoveSpeed;
            Position.z += forward.z * MoveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_S)) {
            Position.x -= forward.x * MoveSpeed;
            Position.z -= forward.z * MoveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_A)) {
            Position.x -= right.x * MoveSpeed;
            Position.z -= right.z * MoveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_D)) {
            Position.x += right.x * MoveSpeed;
            Position.z += right.z * MoveSpeed;
        }

        // Handle rotation
        if (Raylib.IsKeyDown(.KEY_LEFT))
            RotationAngle -= 2.0f;
        if (Raylib.IsKeyDown(.KEY_RIGHT))
            RotationAngle += 2.0f;

        // Update camera
        camera = .(
            Position,
            .(
                Position.x + forward.x,
                Position.y,
                Position.z + forward.z
            ),
            .(0.0f, 1.0f, 0.0f),
            70.0f,
            CameraProjection.CAMERA_PERSPECTIVE
        );

        Raylib.UpdateCamera(&camera, CameraMode.CAMERA_CUSTOM);
    }
}