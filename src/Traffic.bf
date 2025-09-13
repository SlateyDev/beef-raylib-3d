using System;
using System.Collections;
using RaylibBeef;

public class Car {
    public Road* currentRoadPiece;
}

public enum EntryExitSideOrLane : int {
    Bottom = 0,
    Right = 1,
    Top = 2,
    Left = 3
}

public static class RoadConnections {
    public static EntryExitSideOrLane GetEntryLane(EntryExitSideOrLane exitSide) {
        var exitSide;
        var valRef = ref exitSide.UnderlyingRef;
        valRef = (valRef - 1) % 4;
        return exitSide;
    }

    public static EntryExitSideOrLane GetExitLane(EntryExitSideOrLane exitSide) {
        var exitSide;
        var valRef = ref exitSide.UnderlyingRef;
        valRef = (valRef + 1) % 4;
        return exitSide;
    }

    public static EntryExitSideOrLane GetOppositeSide(EntryExitSideOrLane side) {
        var side;
        var valRef = ref side.UnderlyingRef;
        valRef = (valRef + 2) % 4;
        return side;
    }
}

struct RoadData {
    public StringView piece;
    public EntryExitSideOrLane entrySide;
    public Transform* waypoints; //Waypoints to follow from entry to exit
    public EntryExitSideOrLane exitSide;
}

public abstract class Road {
    public abstract RoadData* GetRoadData();
    public Road*[4] connections;
}

//Entry/Exit at Bottom and Right
public class RoadCornerBR : Road {
    static RoadData[?] data = .(
        .{
            entrySide = EntryExitSideOrLane.Bottom,
            waypoints = &Transform[](
                Transform(Vector3(-0.15f, 0,  0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3(-0.15f, 0,  0.00f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3( 0.00f, 0, -0.15f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3( 0.80f, 0, -0.15f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
            ),
            exitSide = EntryExitSideOrLane.Right,
        },
        .{
            entrySide = EntryExitSideOrLane.Bottom,
            waypoints = &Transform[](
                Transform(Vector3( 0.80f, 0, 0.15f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3( 0.15f, 0, 0.15f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3( 0.15f, 0, 0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
            ),
            exitSide = EntryExitSideOrLane.Right,
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
            entrySide = EntryExitSideOrLane.Bottom,
            waypoints = &Transform[](
                Transform(Vector3(-0.15f, 0, -0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3(-0.15f, 0,  0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
            ),
            exitSide = EntryExitSideOrLane.Top,
        },
        .{
            entrySide = EntryExitSideOrLane.Top,
            waypoints = &Transform[](
                Transform(Vector3( 0.15f, 0,  0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
                Transform(Vector3( 0.15f, 0, -0.80f), Vector4(0, 0, 0, 1), Vector3(1, 1, 1)),
            ),
            exitSide = EntryExitSideOrLane.Bottom,
        },
    );

    public override RoadData* GetRoadData() {
        return &data;
    }
}
public class RoadStraightEW : Road {
    public override RoadData* GetRoadData() {
        return null;
    }
}