using System.Collections;

namespace game.UI;

class UIScene {
    public List<UIElement> elements = new List<UIElement>() ~ DeleteContainerAndItems!(_);

    public void Update() {
        var hoverFound = false;
        for (var element in elements.Reversed) {
            element.Update(ref hoverFound);
        }
    }

    public void Render() {
        for (var element in elements) {
            element.Render();
        }
    }
}