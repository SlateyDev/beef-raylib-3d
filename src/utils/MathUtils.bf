using System;
using RaylibBeef;

static class MathUtils {
    public static Vector3 Vector3Multiply(Vector3 a, float f) => .(a.x * f, a.y * f, a.z * f);
    public static Vector3 Vector3Multiply(float f, Vector3 a) => Vector3Multiply(a, f);
}