using System;
using RaylibBeef;

class ModelInstance3D {
    public Model mModel;
    public Vector3 Position;
    public Vector3 Scale;
    public Vector3 Rotation;

    public BoundingBox boundingBox;
    public BoundingSphere boundingSphere;

    public struct BoundingSphere {
        public Vector3 Center;
        public float Radius;
    }

    public this(Model model) {
        mModel = model;
        boundingBox = Raylib.GetModelBoundingBox(mModel);
        Vector3 center = .((boundingBox.min.x + boundingBox.max.x) * 0.5f,
                (boundingBox.min.y + boundingBox.max.y) * 0.5f,
                (boundingBox.min.z + boundingBox.max.z) * 0.5f);
        Vector3 extent = .(boundingBox.max.x - center.x,
            boundingBox.max.y - center.y,
            boundingBox.max.z - center.z);
        float radius = Math.Sqrt(extent.x * extent.x + extent.y * extent.y + extent.z * extent.z);
        boundingSphere = .{
            Center = center,
            Radius = radius};

        Position = .(0, 0, 0);
        Scale = .(1f, 1f, 1f);
        Rotation = .(0, 0, 0);
    }

    public Matrix Transform() {
        Matrix scale = Raymath.MatrixScale(Scale.x, Scale.y, Scale.z);
        Matrix rotation = Raymath.MatrixRotate(Raymath.Vector3Normalize(Rotation), Raymath.Vector3Length(Rotation) * Raymath.DEG2RAD);
        Matrix translation = Raymath.MatrixTranslate(Position.x, Position.y, Position.z);
        Matrix transform = Raymath.MatrixMultiply(Raymath.MatrixMultiply(scale, rotation), translation);
        return transform;
    }

    public BoundingSphere GetBoundingSphere() {
        Matrix transform = Transform();

        Vector3 center = Raymath.Vector3Transform(boundingSphere.Center, mModel.transform);
        center = Raymath.Vector3Transform(center, transform);
        return BoundingSphere() { Center = center, Radius = boundingSphere.Radius * Math.Max(Math.Max(Scale.x, Scale.y), Scale.z) };
    }

    public virtual void Update(float deltaTime) {}

    public virtual void Draw(Color modulate = Raylib.WHITE) {
        Matrix saveMatrix = mModel.transform;
        Raylib.DrawModelEx(mModel, Position, Raymath.Vector3Normalize(Rotation), Raymath.Vector3Length(Rotation), Scale, modulate);
        mModel.transform = saveMatrix;
    }
}