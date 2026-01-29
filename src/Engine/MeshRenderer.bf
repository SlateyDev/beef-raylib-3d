using RaylibBeef;
using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class MeshRenderer : Renderable {
    private Model model;
    public Color modulate { get; set; } = Raylib.WHITE;

    public BoundingBox boundingBox;

    public Model Model {
        get { return model; }
        set {
            model = value;

            boundingBox = Raylib.GetModelBoundingBox(model);
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
        }
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