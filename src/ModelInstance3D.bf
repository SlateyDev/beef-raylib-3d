using RaylibBeef;

class ModelInstance3D {
    public Model mModel;
    public Vector3 Position;
    public Vector3 Scale;
    public Vector3 Rotation;

    public this(Model model) {
        mModel = model;

        Position = .(0, 0, 0);
        Scale = .(1f, 1f, 1f);
        Rotation = .(0, 0, 0);
    }

    public virtual void Update(float deltaTime) {}

    public virtual void Draw() {
        Matrix saveMatrix = mModel.transform;
        Raylib.DrawModelEx(mModel, Position, Raymath.Vector3Normalize(Rotation), Raymath.Vector3Length(Rotation), Scale, Raylib.WHITE);
        mModel.transform = saveMatrix;
    }
}