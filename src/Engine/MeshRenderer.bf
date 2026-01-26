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
        var transform = parent.GetWorldTransform();

        var saveMatrix = model.transform;
        Vector3 axis = ?;
        float angle = ?;
        Raymath.QuaternionToAxisAngle(transform.rotation, &axis, &angle);
        Raylib.DrawModelEx(model, transform.translation, axis, angle, transform.scale, modulate);
        model.transform = saveMatrix;
    }
}