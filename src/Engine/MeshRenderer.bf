using System;

[Reflect(.DefaultConstructor), AlwaysInclude(AssumeInstantiated=true)]
class MeshRenderer : Renderable {
    public override void Render() {
    }
}