using Jolt;
using RaylibBeef;
using static Jolt.Jolt;
using System;
using System.Collections;

public static class PhysicsServer
{
    static JPH_JobSystem* jobSystem;
    static JPH_PhysicsSystem* system;
    static JPH_BodyInterface* bodyInterface;

    public enum Layers : JPH_ObjectLayer
    {
    	NON_MOVING,
    	MOVING,
    	NUM_LAYERS
    };

    public enum BroadPhaseLayers : JPH_BroadPhaseLayer
    {
    	NON_MOVING,
    	MOVING,
    	NUM_LAYERS
    };

    static List<uint32> bodies;

    static this() {
        //JPH_SetTraceHandler((message) => { Console.WriteLine(message); });
        //JPH_SetAssertFailureHandler((expression, message, file, line) => { Console.WriteLine(message); return false; });

        if (JPH_Init()) {
            Console.WriteLine("Jolt Initialized!");
        } else {
            Console.WriteLine("Jolt failed to initialize!");
        }

        jobSystem = JPH_JobSystemThreadPool_Create(null);
        if (jobSystem == null) {
            Console.WriteLine("Failed to create Jolt job system!");
        }

        // We use only 2 layers: one for non-moving objects and one for moving objects
        JPH_ObjectLayerPairFilter* objectLayerPairFilterTable = JPH_ObjectLayerPairFilterTable_Create(Layers.NUM_LAYERS.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.NON_MOVING.Underlying, Layers.MOVING.Underlying);
        JPH_ObjectLayerPairFilterTable_EnableCollision(objectLayerPairFilterTable, Layers.MOVING.Underlying, Layers.NON_MOVING.Underlying);

        // We use a 1-to-1 mapping between object layers and broadphase layers
        JPH_BroadPhaseLayerInterface* broadPhaseLayerInterfaceTable = JPH_BroadPhaseLayerInterfaceTable_Create(Layers.NUM_LAYERS.Underlying, BroadPhaseLayers.NUM_LAYERS.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.NON_MOVING.Underlying, BroadPhaseLayers.NON_MOVING.Underlying);
        JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(broadPhaseLayerInterfaceTable, Layers.MOVING.Underlying, BroadPhaseLayers.MOVING.Underlying);

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
        JPH_JobSystem_Destroy(jobSystem);
        JPH_PhysicsSystem_Destroy(system);
        JPH_Shutdown();
    }

    public static JPH_BodyID CreateAndAddBody(JPH_BodyCreationSettings* settings, JPH_Activation activationMode) {
        return JPH_BodyInterface_CreateAndAddBody(bodyInterface, settings, activationMode);
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

    public static void Update() {
        JPH_PhysicsSystem_Update(system, 1f / 60f, 1, jobSystem);
    }

    public static void GetCenterOfMassPosition(uint32 bodyId, JPH_RVec3* position) {
        JPH_BodyInterface_GetCenterOfMassPosition(bodyInterface, bodyId, position);
    }

    public static bool BodyIsActive(uint32 bodyId) {
        return JPH_BodyInterface_IsActive(bodyInterface, bodyId);
    }
}