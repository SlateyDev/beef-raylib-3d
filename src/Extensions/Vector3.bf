namespace RaylibBeef;

extension Vector3 {
    public this(Vector4 val) {
        x = val.x / val.w;
        y = val.y / val.w;
        z = val.z / val.w;
    }

    public static Vector3 operator+(Vector3 lhs, Vector3 rhs) {
        return Raymath.Vector3Add(lhs, rhs);
    }

    public static Vector3 operator-(Vector3 lhs, Vector3 rhs) {
        return Raymath.Vector3Subtract(lhs, rhs);
    }

    public static Vector3 operator*(Vector3 lhs, Vector3 rhs) {
        return Raymath.Vector3Multiply(lhs, rhs);
    }

    public static Vector3 operator*(Vector3 lhs, float rhs) {
        return Raymath.Vector3Scale(lhs, rhs);
    }

    public static Vector3 operator/(Vector3 lhs, Vector3 rhs) {
        return Raymath.Vector3Divide(lhs, rhs);
    }
}