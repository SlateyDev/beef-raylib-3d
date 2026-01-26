namespace RaylibBeef;

extension Transform {
    public Transform GetWorldTransform(Transform parentWorld, Transform childLocal) {
        return .(
            // 1. Rotate and scale the local translation by the parent, then add parent's position
            parentWorld.translation + .(parentWorld.rotation * .(childLocal.translation * parentWorld.scale)),
            
            // 2. Combine rotations (Parent * Child)
            parentWorld.rotation * childLocal.rotation,
            
            // 3. Combine scales
            parentWorld.scale * childLocal.scale
        );
    }

    public Transform GetLocalTransform(Transform parentWorld, Transform childWorld)
    {
        Quaternion invParentRot = Raymath.QuaternionInvert(parentWorld.rotation);

        // 1. Subtract translation, then "un-rotate" and "un-scale"
        Vector3 localTranslation = .(invParentRot * .(childWorld.translation - parentWorld.translation));
        localTranslation /= parentWorld.scale; // Component-wise division

        return .(
            localTranslation,
            
            // 2. Un-rotate: (Inverse Parent * Child)
            invParentRot * childWorld.rotation,
            
            // 3. Un-scale
            childWorld.scale / parentWorld.scale
        );
    }
}