using System;
using RaylibBeef;

static class MathUtils {
    public static Vector3 Vector3Multiply(Vector3 a, float f) => .(a.x * f, a.y * f, a.z * f);
    public static Vector3 Vector3Multiply(float f, Vector3 a) => Vector3Multiply(a, f);

        // Find a position on a curved path
    public static Vector3 GetPositionOnPath(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, float t) {
        var u = 1.0f - t;
        var uu = u * u;
        var uuu = uu * u;
        var tt = t * t;
        var ttt = tt * t;

        Vector3 p;

        p.x = uuu * p0.x;
        p.y = uuu * p0.y;
        p.z = uuu * p0.z;

        p.x += 3 * uu * t * p1.x;
        p.y += 3 * uu * t * p1.y;
        p.z += 3 * uu * t * p1.z;

        p.x += 3 * u * tt * p2.x;
        p.y += 3 * u * tt * p2.y;
        p.z += 3 * u * tt * p2.z;

        p.x += ttt * p3.x;
        p.y += ttt * p3.y;
        p.z += ttt * p3.z;

        return p;
    }
}