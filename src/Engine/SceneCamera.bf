using RaylibBeef;

class SceneCamera : Component {
    private Camera3D camera;

    public void SetActive(bool active) {
        Program.game.currentCamera = this;
        IsActive = active;
    }

    public override bool IsActive {
        get {
            return Program.game.currentCamera == this;
        }
    }

    public override void Update(float frameTime) {
        var worldTransform = gameObject.GetWorldTransform();
        var target = worldTransform.translation + Raymath.Vector3RotateByQuaternion(.(0, 0, 1), worldTransform.rotation);

        // Update camera
        camera = Camera3D(
            worldTransform.translation,
            target,
            .(0.0f, 1.0f, 0.0f),
            70.0f,
            CameraProjection.CAMERA_PERSPECTIVE
        );

        Raylib.UpdateCamera(&camera, CameraMode.CAMERA_CUSTOM);
    }
}