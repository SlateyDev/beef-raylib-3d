using Jolt;
using RaylibBeef;
using static Jolt.Jolt;
using System;
using System.Collections;
using System.Interop;

public static class PhysicsServer
{
    static JPH_JobSystem* jobSystem;
    static JPH_PhysicsSystem* system;
    static JPH_BodyInterface* bodyInterface;
    static JPH_DebugRenderer* debugRenderer;
    static JPH_DrawSettings drawSettings;
    static float fixedTimestep = 1f / 60f;
    static float accumulator = 0f;
    static int32 maxUpdateSteps = 8;

    static bool DebugDrawing = false;

    public enum Layers : JPH_ObjectLayer
    {
    	STATIC,
    	MOVING,
        PLAYER,
        FRIENDLY,
        FRIENDLY_PROJECTILE,
        ENEMY,
        ENEMY_PROJECTILE,
    	NUM_LAYERS
    };

    public enum BroadPhaseLayers : JPH_BroadPhaseLayer
    {
    	NON_MOVING,
    	MOVING,
    	NUM_LAYERS
    };

    static List<uint32> bodies;

    static JPH_DebugRenderer_Procs procs = .{
        DrawLine = => DebugDrawLine,
        DrawTriangle = => DebugDrawTriangle,
        DrawText3D = => DebugDrawText3D
    };

    static void DebugDrawLine(void* userData, JPH_RVec3* point1, JPH_RVec3* point2, JPH_Color color) {
        if (!DebugDrawing) return;

        var color;
        Raylib.DrawLine3D(*point1, *point2, *(Color*)&color);// Raylib.GetColor((int32)color));
    }
    static void DebugDrawTriangle(void* userData, JPH_RVec3* point1, JPH_RVec3* point2, JPH_RVec3* point3, JPH_Color color, JPH_DebugRenderer_CastShadow shadow) {
        if (!DebugDrawing) return;

        var color;
        Raylib.DrawTriangle3D(*point1, *point2, *point3, *(Color*)&color);
    }
    static void DebugDrawText3D(void* userData, JPH_RVec3* pos, c_char* text, JPH_Color color, float size) {
        if (!DebugDrawing) return;
    }

    static this() {
        //JPH_SetTraceHandler((message) => { Console.WriteLine(message); });
        //JPH_SetAssertFailureHandler((expression, message, file, line) => { Console.WriteLine(message); return false; });

        if (JPH_Init()) {
            Console.WriteLine("Jolt Initialized!");
        } else {
            Console.WriteLine("Jolt failed to initialize!");
        }

        JPH_DebugRenderer_SetProcs(&procs);
        debugRenderer = JPH_DebugRenderer_Create(null);
        JPH_DrawSettings_InitDefault(&drawSettings);
        drawSettings.drawShape = true;
        drawSettings.drawShapeWireframe = true; // Wireframe for debug
        drawSettings.drawBoundingBox = false;

        jobSystem = JPH_JobSystemThreadPool_Create(null);
        if (jobSystem == null) {
            Console.WriteLine("Failed to create Jolt job system!");
        }

        // We use only 2 layers: one for non-moving objects and one for moving objects
        JPH_ObjectLayerPairFilter* objectLayerPairFilterTable = JPH_ObjectLayerPairFilterTable_Create(Layers.NUM_LAYERS.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.PLAYER.Underlying, Layers.STATIC.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.PLAYER.Underlying, Layers.MOVING.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.PLAYER.Underlying, Layers.FRIENDLY.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.PLAYER.Underlying, Layers.ENEMY.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.PLAYER.Underlying, Layers.ENEMY_PROJECTILE.Underlying);

        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.ENEMY.Underlying, Layers.FRIENDLY_PROJECTILE.Underlying);

        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.MOVING.Underlying, Layers.STATIC.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.MOVING.Underlying, Layers.PLAYER.Underlying);

        // We use a 1-to-1 mapping between object layers and broadphase layers
        JPH_BroadPhaseLayerInterface* broadPhaseLayerInterfaceTable = JPH_BroadPhaseLayerInterfaceTable_Create(Layers.NUM_LAYERS.Underlying, BroadPhaseLayers.NUM_LAYERS.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.STATIC.Underlying, BroadPhaseLayers.NON_MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.MOVING.Underlying, BroadPhaseLayers.MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.PLAYER.Underlying, BroadPhaseLayers.MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.FRIENDLY.Underlying, BroadPhaseLayers.MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.FRIENDLY_PROJECTILE.Underlying, BroadPhaseLayers.MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.ENEMY.Underlying, BroadPhaseLayers.MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.ENEMY_PROJECTILE.Underlying, BroadPhaseLayers.MOVING.Underlying);

        JPH_ObjectVsBroadPhaseLayerFilter* objectVsBroadPhaseLayerFilter = JPH_ObjectVsBroadPhaseLayerFilterTable_Create(broadPhaseLayerInterfaceTable, BroadPhaseLayers.NUM_LAYERS.Underlying, objectLayerPairFilterTable, Layers.NUM_LAYERS.Underlying);

        JPH_PhysicsSystemSettings settings = .();
        settings.maxBodies = 65536;
        settings.numBodyMutexes = 0;
        settings.maxBodyPairs = 65536;
        settings.maxContactConstraints = 65536;
        settings.broadPhaseLayerInterface = broadPhaseLayerInterfaceTable;
        settings.objectLayerPairFilter = objectLayerPairFilterTable;
        settings.objectVsBroadPhaseLayerFilter = objectVsBroadPhaseLayerFilter;
        system = JPH_PhysicsSystem_Create(&settings);
        bodyInterface = JPH_PhysicsSystem_GetBodyInterface(system);

        bodies = new List<uint32>();
    }

    static ~this() {
        for(var bodyId in bodies) {
            JPH_BodyInterface_DestroyBody(bodyInterface, bodyId);
        }
        delete bodies;
        JPH_DebugRenderer_Destroy(debugRenderer);
        JPH_JobSystem_Destroy(jobSystem);
        JPH_PhysicsSystem_Destroy(system);
        JPH_Shutdown();
    }

    public static JPH_BodyID CreateAndAddBody(JPH_BodyCreationSettings* settings, JPH_Activation activationMode) {
        var bodyId = JPH_BodyInterface_CreateAndAddBody(bodyInterface, settings, activationMode);
        bodies.Add(bodyId);
        return bodyId;
    }

    public static void RemoveBody(JPH_BodyID bodyId) {
        JPH_BodyInterface_RemoveAndDestroyBody(bodyInterface, bodyId);
        bodies.Remove(bodyId);
    }

    public static void GetLinearVelocity(uint32 bodyId, JPH_Vec3* velocity) {
        JPH_BodyInterface_GetLinearVelocity(bodyInterface, bodyId, velocity);
    }
    public static void SetLinearVelocity(uint32 bodyId, JPH_Vec3* velocity) {
        JPH_BodyInterface_SetLinearVelocity(bodyInterface, bodyId, velocity);
    }

    public static void Optimise() {
        JPH_PhysicsSystem_OptimizeBroadPhase(system);
    }

    public static void Update(float frameTime) {
        if (Raylib.IsKeyPressed(.KEY_EQUAL)) DebugDrawing = !DebugDrawing;
        // Sync kinematic bodies from game objects
        for (var bodyId in bodies) {
            var rigidBody = Internal.UnsafeCastToObject((void*)(uint)JPH_BodyInterface_GetUserData(bodyInterface, bodyId)) as RigidBody;
            if (rigidBody == null) continue;
            if (rigidBody.motionType == .Kinematic) {
                Transform objectWorldTransform = rigidBody.gameObject.GetWorldTransform();
                Vector3 position = objectWorldTransform.translation + rigidBody.[Friend]offset;
                Quaternion rotation = objectWorldTransform.rotation;
                JPH_BodyInterface_SetPositionAndRotation(bodyInterface, bodyId, &position, (JPH_Quat*)&rotation, JPH_Activation.Activate);
            }
        }

        int32 steps = 0;
        accumulator += frameTime;
        while (accumulator >= fixedTimestep && steps < maxUpdateSteps) {
            JPH_PhysicsSystem_Update(system, fixedTimestep, 1, jobSystem);
            accumulator -= fixedTimestep;
            steps++;
        }
        accumulator = Math.Min(accumulator, fixedTimestep * 2);

        // Sync dynamic bodies back to game objects
        for (var bodyId in bodies) {
            var rigidBody = Internal.UnsafeCastToObject((void*)(uint)JPH_BodyInterface_GetUserData(bodyInterface, bodyId)) as RigidBody;
            if (rigidBody == null) continue;
            if (rigidBody.motionType == .Dynamic) {
                Vector3 position = .(0, 0, 0);
                Quaternion rotation = .(0, 0, 0, 1);
                JPH_BodyInterface_GetPositionAndRotation(bodyInterface, bodyId, &position, (JPH_Quat*)&rotation);

                Vector3 rotatedOffset = Raymath.Vector3RotateByQuaternion(rigidBody.[Friend]offset, rotation);
                position -= rotatedOffset;

                rigidBody.gameObject.SetWorldPositionAndRotation(&position, &rotation);
            }
        }
    }

    public static void GetCenterOfMassPosition(uint32 bodyId, JPH_RVec3* position) {
        JPH_BodyInterface_GetCenterOfMassPosition(bodyInterface, bodyId, position);
    }

    public static bool BodyIsActive(uint32 bodyId) {
        return JPH_BodyInterface_IsActive(bodyInterface, bodyId);
    }

    public static void DebugDrawBodies() {
        if (!DebugDrawing) return;

        JPH_PhysicsSystem_DrawBodies(system, &drawSettings, debugRenderer, null);
    }
}