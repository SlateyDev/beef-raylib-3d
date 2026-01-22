using System;
using RaylibBeef;

namespace game.UI;

class Button : UIElement {
    public String text;
    float fontSize = 20;
    Rectangle rect;
    Color normalBackColour = Raylib.BLUE;
    Color normalForeColour = Raylib.WHITE;
    Color hoverBackColour = Raylib.GREEN;
    Color hoverForeColour = Raylib.WHITE;
    Color activatedBackColour = Raylib.DARKGREEN;
    Color activatedForeColour = Raylib.WHITE;
    Color backColour = normalBackColour;
    Color foreColour = normalForeColour;

    bool pressed;

    public delegate void OnClick(Button button);

    public Event<OnClick> onClick = default ~ onClick.Dispose();

    public this(Rectangle rect, String text) {
        this.rect = rect;
        this.text = text;
    }

    public override void Update(ref bool hoverFound) {
        backColour = normalBackColour;
        foreColour = normalForeColour;

        if (hoverFound) return;

        var mousePos = Raylib.GetMousePosition();
        if (Raylib.CheckCollisionPointRec(mousePos, rect)) {
            backColour = hoverBackColour;
            foreColour = hoverForeColour;

            if (Raylib.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT)) {
                pressed = true;
            }
            if (pressed && Raylib.IsMouseButtonReleased(.MOUSE_BUTTON_LEFT)) {
                pressed = false;
                onClick(this);
            }

            if (pressed && Raylib.IsMouseButtonDown(.MOUSE_BUTTON_LEFT)) {
                backColour = activatedBackColour;
                foreColour = activatedForeColour;
            } else {
                pressed = false;
            }
            hoverFound = true;
        } else {
            pressed = pressed && Raylib.IsMouseButtonDown(.MOUSE_BUTTON_LEFT);
        }
    }

    public override void Render() {
        var font = Raylib.GetFontDefault();
        Raylib.DrawRectangle(int32(rect.x), int32(rect.y), int32(rect.width), int32(rect.height), backColour);
        RenderHelper.RenderCenteredText(font, text, .(rect.x + rect.width / 2, rect.y + rect.height / 2), fontSize, foreColour);
    }
}