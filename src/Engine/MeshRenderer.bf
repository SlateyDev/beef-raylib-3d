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
        var x = worldTransform.rotation.x;
        var y = worldTransform.rotation.y;
        var z = worldTransform.rotation.z;
        var w = worldTransform.rotation.w;
        var length = Math.Sqrt(w*w + x*x + y*y + z*z);
        x /= length;
        y /= length;
        z /= length;
        w /= length;
        angle = 2*Math.Acos(w);
        var s = Math.Sqrt(1 - w*w);
        if (s < 0.001f) {
            axis = .(1, 0, 0);
        } else {
            axis = .(x/s, y/s, z/s);
        }

        //Raymath.QuaternionToAxisAngle(worldTransform.rotation, &axis, &angle);
        Raylib.DrawModelEx(model, worldTransform.translation, axis, angle * Raymath.RAD2DEG, worldTransform.scale, modulate);
        model.transform = saveMatrix;
    }
}