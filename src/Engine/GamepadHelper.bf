using System;

static class GamepadHelper {
    public static float normalizeGamepadAxis(int16 rawValue) {
        const int deadzone = 8000;
        const int maxVal = 32767;

        if (Math.Abs(rawValue) < deadzone) {
            return 0;
        }

        float normalized = (float)(Math.Abs(rawValue) - deadzone) / (float)(maxVal - deadzone);
        return rawValue > 0 ? normalized : -normalized;
    }
}