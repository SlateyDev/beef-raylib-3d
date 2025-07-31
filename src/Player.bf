using System;
using System.Collections;
using RaylibBeef;

class Player
{
    public Vector3 Position;
    public float RotationAngle; // Yaw (horizontal rotation)
    public float PitchAngle; // Vertical rotation
    public float MoveSpeed = 20f;
    public float RotateSpeed = 200f;
    public float MouseSensitivity = 0.2f;

    public const float PLAYER_RADIUS = 0.5f; // Collision radius for the player

    private bool mMouseLocked = false;
    private bool mFirstMouse = false;

    public Camera3D camera;

    public this(Vector3 startPosition) {
        Position = startPosition;
        RotationAngle = 0.0f;
        PitchAngle = 0.0f;
    }

    // Update method signature
    public void Update(float frameTime) {
        HandleMouseInput();
        HandleMovement(frameTime, Program.game.mWorld.mObstacles);
        UpdateCamera();
    }

    private void HandleMouseInput() {
        // Toggle mouse lock with Escape key

        if (mMouseLocked) {
            Vector2 mouseDelta = Raylib.GetMouseDelta();
            if (mFirstMouse) {
                mFirstMouse = false;
                return;
            }

            // Update rotation angles based on mouse movement
            RotationAngle += mouseDelta.x * MouseSensitivity;
            PitchAngle -= mouseDelta.y * MouseSensitivity;

            // Clamp pitch to prevent camera flipping
            PitchAngle = Math.Clamp(PitchAngle, -89.0f, 89.0f);
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

    private bool CheckCollision(Vector3 newPosition, List<BoundingBox> obstacles) {
        // Check collision with each obstacle
        for (let obstacle in obstacles) {
            if (Raylib.CheckCollisionBoxSphere(obstacle, newPosition, PLAYER_RADIUS))
                return true;
        }
        return false;
    }

    private void HandleMovement(float frameTime, List<BoundingBox> obstacles) {
        // Calculate forward and right vectors based on rotation
        float yawRadians = MathUtils.DegreesToRadians(RotationAngle);
        Vector3 forward = .(
            Math.Cos(yawRadians),
            0,
            Math.Sin(yawRadians)
        );
        Vector3 right = .(
            Math.Cos(yawRadians + Math.PI_f/2),
            0,
            Math.Sin(yawRadians + Math.PI_f/2)
        );

        var moveSpeed = MoveSpeed * frameTime;
        Vector3 newPosition = Position;

        // Handle movement relative to looking direction
        if (Raylib.IsKeyDown(.KEY_W)) {
            newPosition.x += forward.x * moveSpeed;
            newPosition.z += forward.z * moveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_S)) {
            newPosition.x -= forward.x * moveSpeed;
            newPosition.z -= forward.z * moveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_A)) {
            newPosition.x -= right.x * moveSpeed;
            newPosition.z -= right.z * moveSpeed;
        }
        if (Raylib.IsKeyDown(.KEY_D)) {
            newPosition.x += right.x * moveSpeed;
            newPosition.z += right.z * moveSpeed;
        }

        // Only update position if there's no collision
        if (!CheckCollision(newPosition, obstacles)) {
            Position = newPosition;
        }
    }

    private void UpdateCamera() {
        float yawRadians = MathUtils.DegreesToRadians(RotationAngle);
        float pitchRadians = MathUtils.DegreesToRadians(PitchAngle);

        // Calculate the target position using both yaw and pitch
        Vector3 target = .(
            Math.Cos(pitchRadians) * Math.Cos(yawRadians),
            Math.Sin(pitchRadians),
            Math.Cos(pitchRadians) * Math.Sin(yawRadians)
        );

        // Update camera
        camera = .(
            Position,
            Raymath.Vector3Add(Position, target),
            .(0.0f, 1.0f, 0.0f),
            70.0f,
            CameraProjection.CAMERA_PERSPECTIVE
        );

        Raylib.UpdateCamera(&camera, CameraMode.CAMERA_CUSTOM);
    }
}