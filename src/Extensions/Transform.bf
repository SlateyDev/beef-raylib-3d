using System;
namespace RaylibBeef;

extension Transform {
    public static Transform GetWorldTransform(Transform parentWorld, Transform childLocal) {
        var result = Transform(
            // 1. Rotate and scale the local translation by the parent, then add parent's position
            parentWorld.translation + Raymath.Vector3RotateByQuaternion(childLocal.translation * parentWorld.scale, parentWorld.rotation),
            
            // 2. Combine rotations (Parent * Child)
            Raymath.QuaternionMultiply(parentWorld.rotation, childLocal.rotation),
            
            // 3. Combine scales
            parentWorld.scale * childLocal.scale
        );
        return result;
    }

    public static Transform GetLocalTransform(Transform parentWorld, Transform childWorld)
    {
        Quaternion invParentRot = Raymath.QuaternionInvert(parentWorld.rotation);

        // 1. Subtract translation, then "un-rotate" and "un-scale"
        Vector3 localTranslation = Raymath.Vector3RotateByQuaternion(childWorld.translation - parentWorld.translation, invParentRot);
        localTranslation /= parentWorld.scale; // Component-wise division

        return .(
            localTranslation,
            
            // 2. Un-rotate: (Inverse Parent * Child)
            Raymath.QuaternionMultiply(invParentRot, childWorld.rotation),
            
            // 3. Un-scale
            childWorld.scale / parentWorld.scale
        );
    }
}