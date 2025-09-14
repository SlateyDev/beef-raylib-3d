using System;
using System.Collections;
using RaylibBeef;

public class Car {
    public List<PathPoint> points;
}

public enum EntryExitSideOrLane : int {
    Bottom = 0,
    Right = 1,
    Top = 2,
    Left = 3
}

public static class RoadConnections {
    public static EntryExitSideOrLane GetOppositeSide(EntryExitSideOrLane side) {
        var side;
        var valRef = ref side.UnderlyingRef;
        valRef = (valRef + 2) % 4;
        return side;
    }

    public static Vector3 Evaluate(RoadData *roadData, float t) {
        if (roadData.numPoints < 2) {
            return .(0, 0, 0);
        }

        // Scale t across all segments
        float scaledT = t * (roadData.numPoints - 1);
        int segIndex = (int)scaledT;
        if (segIndex >= roadData.numPoints - 1)
            segIndex = roadData.numPoints - 2;

        float localT = scaledT - segIndex;
        return EvaluateSegment(roadData, segIndex, localT);
    }

    // Evaluate a single segment using cubic Bezier
    private static Vector3 EvaluateSegment(RoadData *roadData, int index, float t)
    {
        let p0 = roadData.points[index];
        let p3 = roadData.points[index + 1];

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
    public StringView piece;
    public EntryExitSideOrLane sideA;
    public int numPoints;
    public PathPoint* points;
    public EntryExitSideOrLane sideB;
}

public abstract class Road {
    public abstract RoadData* GetRoadData();
    public Road*[4] connections;
}

//Entry/Exit at Bottom and Right
public class RoadCornerBR : Road {
    static PathPoint[?] points = .(
        .(.( 0.0f, 0, 0.9f), null, .(0, 0, 0)),
        .(.( 0.0f, 0, 0.5f), .(0, 0, 0), .(0, 0, -0.36f)),
        .(.( 0.5f, 0, 0.0f), .(-0.36f, 0, 0), .(0, 0, 0)),
        .(.( 0.9f, 0, 0.0f), .(0, 0, 0), null),
    );
    static RoadData[?] data = .(
        .{
            sideA = EntryExitSideOrLane.Bottom,
            points = &points,
            numPoints = points.Count,
            sideB = EntryExitSideOrLane.Right,
        },
    );

    public override RoadData* GetRoadData() {
        return &data;
    }
}
//Entry/Exit at Bottom and Left
public class RoadCornerBL : Road {
    public override RoadData* GetRoadData() {
        return null;
    }
}
//Entry/Exit at Top and Left
public class RoadCornerTL : Road {
    public override RoadData* GetRoadData() {
        return null;
    }
}
//Entry/Exit at Top and Right
public class RoadCornerTR : Road {
    public override RoadData* GetRoadData() {
        return null;
    }
}

public class RoadStraightNS : Road {
    static RoadData[?] data = .(
        .{
            sideA = EntryExitSideOrLane.Bottom,
            points = null,
            numPoints = 0,
            sideB = EntryExitSideOrLane.Top,
        },
    );

    public override RoadData* GetRoadData() {
        return &data;
    }
}
public class RoadStraightEW : Road {
    static RoadData[?] data = .(
        .{
            sideA = EntryExitSideOrLane.Bottom,
            points = null,
            numPoints = 0,
            sideB = EntryExitSideOrLane.Top,
        },
    );

    public override RoadData* GetRoadData() {
        return &data;
    }
}