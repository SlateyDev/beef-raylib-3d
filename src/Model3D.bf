using System;
using System.Diagnostics;
using RaylibBeef;

class Model3D {
    public Model mModel;
    public Vector3 Position;
    public Vector3 Scale;
    public Vector3 Rotation;

    public this(String modelPath) {
        mModel = Raylib.LoadModel(modelPath);
        Position = .(0, 0, 0);
        Scale = .(1f, 1f, 1f);
        Rotation = .(0, 0, 0);
    }

    public ~this() {
        Raylib.UnloadModel(mModel);
    }

    public void Draw() {
        Matrix saveMatrix = mModel.transform;
        Raylib.DrawModelEx(mModel, Position, Raymath.Vector3Normalize(Rotation), Raymath.Vector3Length(Rotation), Scale, Raylib.WHITE);
        mModel.transform = saveMatrix;
    }
}