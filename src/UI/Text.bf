using System;
using RaylibBeef;
namespace game.UI;

class Text : UIElement {
    public String text;
    float fontSize = 20;
    Rectangle rect;
    Color foreColour = Raylib.WHITE;

    public this(Rectangle rect, String text) {
        this.rect = rect;
        this.text = text;
    }

    public override void Render() {
        var font = Raylib.GetFontDefault();
        RenderHelper.RenderCenteredText(font, text, .(rect.x + rect.width / 2, rect.y + rect.height / 2), fontSize, foreColour);
    }
}