using Jolt;
using static Jolt.Jolt;
using RaylibBeef;

abstract class Collider : Component {
    public abstract JPH_Shape* CreateShape();

    public Vector3 offset;
}