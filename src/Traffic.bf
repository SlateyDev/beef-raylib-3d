using System;
using System.Collections;
using RaylibBeef;

public class Car {
    public List<PathPoint> points;
}

public enum EntryExitSide : int {
    North = 0,
    East = 1,
    South = 2,
    West = 3
}

public struct GridPos : IHashable {
    public int x, y, z;

    public this(int x, int y, int z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public int GetHashCode() {
        return x + (y << 8) + (z << 16);
    }

    public override void ToString(String strBuffer) {
        strBuffer.Append(scope $"({x},{y},{z})");
    }

    public static GridPos operator+(GridPos lhs, GridPos rhs) => .(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z);
    public static GridPos operator-(GridPos lhs, GridPos rhs) => .(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z);

    //public static bool operator==(GridPos lhs, GridPos rhs)
    //{
    //	return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z;
    //}
}

public static class RoadConnections {
    public static EntryExitSide GetOppositeSide(EntryExitSide side) {
        var side;
        var valRef = ref side.UnderlyingRef;
        valRef = (valRef + 2) % 4;
        return side;
    }

    public static Vector3 Evaluate(RoadPath *roadPath, float t) {
        if (roadPath.numPoints < 2) {
            return .(0, 0, 0);
        }

        // Scale t across all segments
        float scaledT = t * (roadPath.numPoints - 1);
        int segIndex = (int)scaledT;
        if (segIndex >= roadPath.numPoints - 1)
            segIndex = roadPath.numPoints - 2;

        float localT = scaledT - segIndex;
        return EvaluateSegment(roadPath, segIndex, localT);
    }

    // Evaluate a single segment using cubic Bezier
    private static Vector3 EvaluateSegment(RoadPath *roadPath, int index, float t)
    {
        let p0 = roadPath.points[index];
        let p3 = roadPath.points[index + 1];

        Vector3 c0 = p0.position;
        Vector3 c1 = p0.outVector ?? p0.position; // fall back if null
        Vector3 c2 = p3.inVector ?? p3.position;
        Vector3 c3 = p3.position;

        float u = 1 - t;
        float tt = t * t;
        float uu = u * u;
        float uuu = uu * u;
        float ttt = tt * t;

        Vector3 p =
            Raymath.Vector3Add(
                Raymath.Vector3Add(
                    Raymath.Vector3Add(
                        MathUtils.Vector3Multiply(uuu, c0),
                        MathUtils.Vector3Multiply(3 * uu * t, c1)
                    ),
                    MathUtils.Vector3Multiply(3 * u * tt, c2)
                ),
                MathUtils.Vector3Multiply(ttt, c3)
            );

        return p;
    }
}

struct PathPoint {
    public Vector3 position;
    public Vector3? inVector;
    public Vector3? outVector;

    public this(Vector3 position, Vector3? inVector, Vector3? outVector) {
        this.position = position;
        this.inVector = inVector;
        this.outVector = outVector;
    }
}

struct RoadData {
    public int numPaths;
    public RoadPath* paths;
}
struct RoadPath {
    public StringView piece;
    public EntryExitSide sideA;
    public int numPoints;
    public PathPoint* points;
    public EntryExitSide sideB;
}

public abstract class Road : ModelInstance3D {
    public this(Model model) : base(model) {}

    public abstract RoadData* GetRoadData();
    public Road[4] connections;
}

//Entry/Exit at South and East
public class RoadCornerSE : Road {
    public this() : base(ModelManager.Get("assets/models/road_corner_curved.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }

    static PathPoint[?] points = .(
        .(.( 0.0f, 0, 0.9f), null, .(0, 0, 0)),
        .(.( 0.0f, 0, 0.5f), .(0, 0, 0), .(0, 0, -0.36f)),
        .(.( 0.5f, 0, 0.0f), .(-0.36f, 0, 0), .(0, 0, 0)),
        .(.( 0.9f, 0, 0.0f), .(0, 0, 0), null),
    );
    static RoadPath[?] roadPaths = .(
        .{
            sideA = .South,
            points = &points,
            numPoints = points.Count,
            sideB = .East,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}
//Entry/Exit at South and West
public class RoadCornerSW : Road {
    public this() : base(ModelManager.Get("assets/models/road_corner_curved.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
        Rotation = .(0, -90, 0);
    }

    static PathPoint[?] points = .(
        .(.( 0.0f, 0, 0.9f), null, .(0, 0, 0)),
        .(.( 0.0f, 0, 0.5f), .(0, 0, 0), .(0, 0, -0.36f)),
        .(.(-0.5f, 0, 0.0f), .(0.36f, 0, 0), .(0, 0, 0)),
        .(.(-0.9f, 0, 0.0f), .(0, 0, 0), null),
    );
    static RoadPath[?] roadPaths = .(
        .{
            sideA = .South,
            points = &points,
            numPoints = points.Count,
            sideB = .West,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}
//Entry/Exit at North and West
public class RoadCornerNW : Road {
    public this() : base(ModelManager.Get("assets/models/road_corner_curved.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
        Rotation = .(0, 180, 0);
    }

    static PathPoint[?] points = .(
        .(.( 0.0f, 0, -0.9f), null, .(0, 0, 0)),
        .(.( 0.0f, 0, -0.5f), .(0, 0, 0), .(0, 0, 0.36f)),
        .(.(-0.5f, 0, 0.0f), .(0.36f, 0, 0), .(0, 0, 0)),
        .(.(-0.9f, 0, 0.0f), .(0, 0, 0), null),
    );
    static RoadPath[?] roadPaths = .(
        .{
            sideA = .North,
            points = &points,
            numPoints = points.Count,
            sideB = .West,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}
//Entry/Exit at North and East
public class RoadCornerNE : Road {
    public this() : base(ModelManager.Get("assets/models/road_corner_curved.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
        Rotation = .(0, 90, 0);
    }

    static PathPoint[?] points = .(
        .(.( 0.0f, 0, -0.9f), null, .(0, 0, 0)),
        .(.( 0.0f, 0, -0.5f), .(0, 0, 0), .(0, 0, 0.36f)),
        .(.( 0.5f, 0, 0.0f), .(-0.36f, 0, 0), .(0, 0, 0)),
        .(.( 0.9f, 0, 0.0f), .(0, 0, 0), null),
    );
    static RoadPath[?] roadPaths = .(
        .{
            sideA = .North,
            points = &points,
            numPoints = points.Count,
            sideB = .East,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}

public class RoadStraightNS : Road {
    public this() : base(ModelManager.Get("assets/models/road_straight.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }

    static RoadPath[?] roadPaths = .(
        .{
            sideA = .South,
            points = null,
            numPoints = 0,
            sideB = .North,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}
public class RoadStraightEW : Road {
    public this() : base(ModelManager.Get("assets/models/road_straight.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
        Rotation = .(0, 90, 0);
    }

    static RoadPath[?] roadPaths = .(
        .{
            sideA = .East,
            points = null,
            numPoints = 0,
            sideB = .West,
        },
    );
    static RoadData data = .{
        numPaths = roadPaths.Count,
        paths = &roadPaths,
    };

    public override RoadData* GetRoadData() {
        return &data;
    }
}