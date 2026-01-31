using RaylibBeef;
using System;

class CameraPitchController : Component {
    public float MouseSensitivity = 0.2f;
    public float clampMin = 5f;
    public float clampMax = 89f;

    private bool mMouseLocked = false;
    private bool mFirstMouse = false;

    private float pitch = 0;

    public override void Awake() {
        var currentRotationEuler = Raymath.QuaternionToEuler(gameObject.transform.rotation);

        pitch = currentRotationEuler.x * Raylib.RAD2DEG; // rotation around local X
    }

    public override void Update(float frameTime) {
        HandleMouseInput();

        var currentRotationEuler = Raymath.QuaternionToEuler(gameObject.transform.rotation);
        currentRotationEuler.x = pitch * Raylib.DEG2RAD;
        gameObject.transform.rotation = Raymath.QuaternionFromEuler(currentRotationEuler.x, currentRotationEuler.y, currentRotationEuler.z);
    }

    private void HandleMouseInput() {
        if (mMouseLocked) {
            Vector2 mouseDelta = Raylib.GetMouseDelta();
            if (mFirstMouse) {
                //Ignore first delta when mouse is clicked to stop jumping
                mFirstMouse = false;
                return;
            }

            // Update rotation angles based on mouse movement
            pitch -= mouseDelta.y * MouseSensitivity;

            // Clamp pitch to prevent camera flipping
            pitch = Math.Clamp(pitch, clampMin, clampMax);
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