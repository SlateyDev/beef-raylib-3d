using System;
using RaylibBeef;

static class RenderHelper {
    public static void RenderCenteredText(Font font, String text, Vector2 pos, float fontSize, Color foreColour) {
    	var textSize = Raylib.MeasureTextEx(font, text, fontSize, 2);
    	Raylib.DrawTextEx(font, text, .(pos.x - textSize.x / 2, pos.y - textSize.y / 2), fontSize, 2, foreColour);
    }
}