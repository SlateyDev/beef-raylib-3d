using System;
using System.Collections;
using RaylibBeef;

public abstract class Car : ModelInstance3D {
    public this(Model model) : base(model) {}

    //public List<PathPoint> points;
    public Road currentRoadSegment;
    private Road nextRoadSegment;
    private int currentSegmentDirection = 1; //Use this instead for current segment? This is so it knows what way to follow the path?
    private int currentPathIndex = 0;
    private int currentPointIndex = 0;

    private EntryExitSide exitSide;

    private PathPoint pointA;
    private PathPoint pointB;
    private float pointLerpAmount = 0;

    private bool initialized = false;

    public void Start() {
        Random rand = new Random();
        defer delete rand;

        if (currentRoadSegment == null)
            return;

        // Pick a random path, point to start at and direction on the current road segment
        var roadData = currentRoadSegment.GetRoadData();
        currentPathIndex = rand.Next(0, roadData.numPaths);
        currentPointIndex = 0;//rand.Next(0, roadData.paths[currentPathIndex].numPoints);
        currentSegmentDirection = rand.Next(0, 2) == 0 ? 1 : -1;
        exitSide = currentSegmentDirection > 0 ? roadData.paths[currentPathIndex].sideB : roadData.paths[currentPathIndex].sideA;
        pointA = roadData.paths[currentPathIndex].points[currentPointIndex];
        GetNextPoint();
        Position = Raymath.Vector3Add(currentRoadSegment.Position, Raymath.Vector3Multiply(pointA.position, currentRoadSegment.Scale));

        initialized = true;
    }

    // Find a position on a curved path
    // Currently doesn't return anything useful, was converted from my odin project
    private Vector3 GetPositionOnPath(PathPoint pointA, PathPoint pointB, int curveSegments, float pointDistance, float lerpAmount) {
        if (pointA.position == pointB.position) {
            return pointA.position;
        }

        float step = 1 / curveSegments;
        float currentLength = 0;
        float nextPointLength = 0;
        Vector3 currentSegmentPoint = pointA.position;
        Vector3 lastSegmentPoint = .{};

        for (int i = 1; i <= curveSegments; i++) {
            float t = step * i;

            float a = Math.Pow(1 - t, 3);
            float b = 3 * Math.Pow(1 - t, 2) * t;
            float c = 3 * (1 - t) * Math.Pow(t, 2);
            float d = Math.Pow(t, 3);

            lastSegmentPoint = currentSegmentPoint;
            Vector3 outVec = pointA.outVector ?? pointA.position; // fall back if null
            Vector3 inVec = pointB.inVector ?? pointB.position;   // fall back if null
            currentSegmentPoint = Raymath.Vector3Add(
                Raymath.Vector3Add(
                    Raymath.Vector3Add(
                        MathUtils.Vector3Multiply(a, pointA.position),
                        MathUtils.Vector3Multiply(b, outVec)
                    ),
                    MathUtils.Vector3Multiply(c, inVec)
                ),
                MathUtils.Vector3Multiply(d, pointB.position)
            );
            float segmentLength = Raymath.Vector3Length(Raymath.Vector3Subtract(currentSegmentPoint, lastSegmentPoint));

            while (currentLength + segmentLength >= nextPointLength) {
                Vector3 point = Raymath.Vector3Lerp(lastSegmentPoint, currentSegmentPoint, (nextPointLength - currentLength) / segmentLength);
                //rl.DrawCircleV(point, 20, rl.BLUE)

                nextPointLength += pointDistance;
            }

            currentLength += segmentLength;
        }

        return currentSegmentPoint;
    }


    private void GetNextPoint() {
        if (currentRoadSegment == null)
            return;
        
        var roadData = currentRoadSegment.GetRoadData();
        if (currentPathIndex < 0 || currentPathIndex >= roadData.numPaths) {
            return;
        }

        var path = roadData.paths[currentPathIndex];
        currentPointIndex += currentSegmentDirection;
        if (currentPointIndex < 0 || currentPointIndex >= path.numPoints) {
            // Reached the end of the path
            // Get point of next road segment
            nextRoadSegment = currentRoadSegment.connections[(int)exitSide];
            if (nextRoadSegment == null) {
                // No connected road, stop here
                return;
            }

            var nextRoadData = nextRoadSegment.GetRoadData();
            for (int pathIndex = 0; pathIndex < nextRoadData.numPaths; pathIndex++) {
                var nextPath = nextRoadData.paths[pathIndex];
                if ((nextPath.sideA == RoadConnections.GetOppositeSide(exitSide)) ||
                    (nextPath.sideB == RoadConnections.GetOppositeSide(exitSide))) {
                    currentPathIndex = pathIndex;

                    if (nextPath.sideA == RoadConnections.GetOppositeSide(exitSide)) {
                        currentPointIndex = 0;
                        currentSegmentDirection = 1;     //If moving from one road segment to another, this may not make sense, might need something else
                        exitSide = nextPath.sideB;
                    } else {
                        currentPointIndex = nextPath.numPoints - 1;
                        currentSegmentDirection = -1;    //If moving from one road segment to another, this may not make sense, might need something else
                        exitSide = nextPath.sideA;
                    }
                    if (nextPath.numPoints == 0) {
                        // Straight road segment without defined path points, just continue in the same direction
                        pointB = .{};
                    } else {
                        pointB = nextPath.points[currentPointIndex];
                    }
                    break;
                }
            }
        } else {
            nextRoadSegment = currentRoadSegment;
            pointB = path.points[currentPointIndex];
        }
    }

    public override void Update(float deltaTime) {
        if (!initialized) {
            Start();
            return;
        }

        pointLerpAmount += deltaTime;
        if (pointLerpAmount >= 1) {
            currentRoadSegment = nextRoadSegment;
            pointA = pointB;
            GetNextPoint();
            pointLerpAmount = 0;

            // Set rotation to face direction of pointA to pointB
            Vector3 direction = Raymath.Vector3Subtract(Raymath.Vector3Add(nextRoadSegment.Position, pointB.position), Raymath.Vector3Add(currentRoadSegment.Position, pointA.position));
            if (Raymath.Vector3Length(direction) > 0.001f) {
                direction = Raymath.Vector3Normalize(direction);
                float angleY = Math.Atan2(direction.x, direction.z) * Raymath.RAD2DEG;
                Rotation = .(0, angleY, 0);
            }
        }
    }

    public override void Draw() {
        if (!initialized) {
            return;
        }
        var posA = Raymath.Vector3Add(currentRoadSegment.Position, Raymath.Vector3Multiply(pointA.position, currentRoadSegment.Scale));
        var posB = Raymath.Vector3Add(nextRoadSegment.Position, Raymath.Vector3Multiply(pointB.position, nextRoadSegment.Scale));
        Matrix saveMatrix = mModel.transform;
        Raylib.DrawModelEx(mModel, Raymath.Vector3Add(Raymath.Vector3Lerp(posA, posB, pointLerpAmount), .(0.15f,0.06f,0)), Raymath.Vector3Normalize(Rotation), Raymath.Vector3Length(Rotation), Scale, Raylib.WHITE);
        mModel.transform = saveMatrix;
    }
}

public class CarHatchBack : Car {
    public this() : base(ModelManager.Get("assets/models/car_hatchback.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }
}

public class CarPolice : Car {
    public this() : base(ModelManager.Get("assets/models/car_police.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }
}

public class CarSedan : Car {
    public this() : base(ModelManager.Get("assets/models/car_sedan.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }
}

public class CarStationWagon : Car {
    public this() : base(ModelManager.Get("assets/models/car_stationwagon.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }
}

public class CarTaxi : Car {
    public this() : base(ModelManager.Get("assets/models/car_taxi.gltf")) {
        Scale = .(0.5f, 0.5f, 0.5f);
    }
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

    public static Vector3 Evaluate(RoadPath roadPath, float t) {
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
    private static Vector3 EvaluateSegment(RoadPath roadPath, int index, float t)
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