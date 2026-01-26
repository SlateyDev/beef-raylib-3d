namespace RaylibBeef;

extension Vector4 {
    public this(Vector3 val) {
        x = val.x;
        y = val.y;
        z = val.z;
        w = 1;
    }

    public static Vector4 operator+(Vector4 lhs, Vector4 rhs) {
        return Raymath.Vector4Add(lhs, rhs);
    }

    public static Vector4 operator-(Vector4 lhs, Vector4 rhs) {
        return Raymath.Vector4Subtract(lhs, rhs);
    }

    public static Quaternion operator*(Quaternion lhs, Quaternion rhs) {
        return Raymath.Vector4Multiply(lhs, rhs);
    }
}