using RaylibBeef;
using System;

abstract class Renderable : Component {
    public BoundingSphere boundingSphere;

    public struct BoundingSphere {
        public Vector3 Center;
        public float Radius;
    }

    public abstract void Render();

    public Matrix Transform() {
        var go = gameObject;
        var worldTransform = go.GetWorldTransform();
        Matrix scale = Raymath.MatrixScale(worldTransform.scale.x, worldTransform.scale.y, worldTransform.scale.z);
        Matrix rotation = Raymath.QuaternionToMatrix(worldTransform.rotation);
        Matrix translation = Raymath.MatrixTranslate(worldTransform.translation.x, worldTransform.translation.y, worldTransform.translation.z);
        Matrix transform = Raymath.MatrixMultiply(Raymath.MatrixMultiply(scale, rotation), translation);
        return transform;
    }

    public BoundingSphere GetBoundingSphere() {
        var go = gameObject;
        var worldTransform = go.GetWorldTransform();
        Matrix transform = Transform();

        Vector3 center = boundingSphere.Center;
        center = Raymath.Vector3Transform(center, transform);
        return BoundingSphere() { Center = center, Radius = boundingSphere.Radius * Math.Max(Math.Max(worldTransform.scale.x, worldTransform.scale.y), worldTransform.scale.z) };
    }

}