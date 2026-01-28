using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class MeshRenderer : Renderable {
    private Model model;
    public Color modulate { get; set; } = Raylib.WHITE;

    public Model Model {
        get { return model; }
        set { model = value; }
    }

    public override void Render() {
        var worldTransform = parent.GetWorldTransform();

        var saveMatrix = model.transform;

        Vector3 axis = .(0, 1, 0);
        float angle = 0;

        Raymath.QuaternionToAxisAngle(worldTransform.rotation, &axis, &angle);
        Raylib.DrawModelEx(model, worldTransform.translation, axis, angle * Raymath.RAD2DEG, worldTransform.scale, modulate);
        model.transform = saveMatrix;
    }
}