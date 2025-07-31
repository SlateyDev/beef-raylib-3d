using System;
using RaylibBeef;

static class MathUtils {
    public static Vector2 Vector2Add(Vector2 v1, Vector2 v2) {
        return .(v1.x + v2.x, v1.y + v2.y);
    }

    public static Vector2 Vector2Subtract(Vector2 v1, Vector2 v2) {
        return .(v1.x - v2.x, v1.y - v2.y);
    }

    public static float Vector2Length(Vector2 v) {
        return Math.Sqrt(v.x * v.x + v.y * v.y);
    }

    public static Vector2 Vector2Normalize(Vector2 v) {
        float length = Vector2Length(v);
        if (length > 0) {
            return .(v.x / length, v.y / length);
        }
        return .(0, 0);
    }

    public static float DegreesToRadians(float degrees) {
        return degrees * (Math.PI_f / 180.0f);
    }

    public static float RadiansToDegrees(float radians) {
        return radians * (180.0f / Math.PI_f);
    }
}