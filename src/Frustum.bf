using System;
using RaylibBeef;

#define FRUSTUM_CULLING

public struct Frustum {
    public enum FrustumPlanes
    {
        Far = 0,
        Near = 1,
        Bottom = 2,
        Top = 3,
        Right = 4,
        Left = 5,
        MAX = 6
    };

    private Vector4[FrustumPlanes.MAX.Underlying] planes;

    void NormalizePlane(Vector4* plane) {
        float magnitude = Math.Sqrt(plane.x * plane.x + plane.y * plane.y + plane.z * plane.z);

        plane.x /= magnitude;
        plane.y /= magnitude;
        plane.z /= magnitude;
        plane.w /= magnitude;
    }

    public void Extract() mut {
#if FRUSTUM_CULLING
        var projection = Rlgl.rlGetMatrixProjection();
        var modelView = Rlgl.rlGetMatrixModelview();
        var viewProjMatrix = Raymath.MatrixMultiply(modelView, projection);

        Vector4 r1 = .(viewProjMatrix.m0, viewProjMatrix.m4, viewProjMatrix.m8, viewProjMatrix.m12);
        Vector4 r2 = .(viewProjMatrix.m1, viewProjMatrix.m5, viewProjMatrix.m9, viewProjMatrix.m13);
        Vector4 r3 = .(viewProjMatrix.m2, viewProjMatrix.m6, viewProjMatrix.m10, viewProjMatrix.m14);
        Vector4 r4 = .(viewProjMatrix.m3, viewProjMatrix.m7, viewProjMatrix.m11, viewProjMatrix.m15);

        planes[FrustumPlanes.Left.Underlying] = .(r4.x + r1.x, r4.y + r1.y, r4.z + r1.z, r4.w + r1.w);
        planes[FrustumPlanes.Right.Underlying] = .(r4.x - r1.x, r4.y - r1.y, r4.z - r1.z, r4.w - r1.w);
        planes[FrustumPlanes.Bottom.Underlying] = .(r4.x + r2.x, r4.y + r2.y, r4.z + r2.z, r4.w + r2.w);
        planes[FrustumPlanes.Top.Underlying] = .(r4.x - r2.x, r4.y - r2.y, r4.z - r2.z, r4.w - r2.w);
        planes[FrustumPlanes.Near.Underlying] = .(r4.x + r3.x, r4.y + r3.y, r4.z + r3.z, r4.w + r3.w);
        planes[FrustumPlanes.Far.Underlying] = .(r4.x - r3.x, r4.y - r3.y, r4.z - r3.z, r4.w - r3.w);

        for(var plane in mut planes) {
            NormalizePlane(&plane);
        }
#endif
    }

    float DistanceToPlane(Vector4 *plane, Vector3 *position) {
        return plane.x * position.x + plane.y * position.y + plane.z * position.z + plane.w;
    }

    float DistanceToPlane(Vector4 *plane, float x, float y, float z) {
        return plane.x * x + plane.y * y + plane.z * z + plane.w;
    }

    public bool PointIn(Vector3 *position) {
#if FRUSTUM_CULLING
        for(var plane in planes) {
            if (DistanceToPlane(&plane, position) <= 0) return false;
        }
#endif

        return true;
    }

    public bool PointIn(float x, float y, float z) {
#if FRUSTUM_CULLING
        for(var plane in planes) {
            if (DistanceToPlane(&plane, x, y, z) <= 0) return false;
        }
#endif

        return true;
    }

    public bool SphereIn(Vector3 *position, float radius) {
#if FRUSTUM_CULLING
        for(var plane in planes) {
            if (DistanceToPlane(&plane, position) < -radius) return false;
        }
#endif

        return true;
    }

    public bool AABBoxIn(Vector3 *min, Vector3 *max) {
#if FRUSTUM_CULLING
        // if any point is in and we are good
        if (PointIn(min.x, min.y, min.z))
            return true;

        if (PointIn(min.x, max.y, min.z))
            return true;

        if (PointIn(max.x, max.y, min.z))
            return true;

        if (PointIn(max.x, min.y, min.z))
            return true;

        if (PointIn(min.x, min.y, max.z))
            return true;

        if (PointIn(min.x, max.y, max.z))
            return true;

        if (PointIn(max.x, max.y, max.z))
            return true;

        if (PointIn(max.x, min.y, max.z))
            return true;

        // check to see if all points are outside of any one plane, if so the entire box is outside
        for (var plane in planes)
        {
            bool oneInside = false;

            if (DistanceToPlane(&plane, min.x, min.y, min.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, max.x, min.y, min.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, max.x, max.y, min.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, min.x, max.y, min.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, min.x, min.y, max.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, max.x, min.y, max.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, max.x, max.y, max.z) >= 0)
                oneInside = true;

            if (DistanceToPlane(&plane, min.x, max.y, max.z) >= 0)
                oneInside = true;

            if (!oneInside)
                return false;
        }
#endif

        // the box extends outside the frustum but crosses it
        return true;
    }
}