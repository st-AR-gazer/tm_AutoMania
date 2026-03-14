auto mousecommandsinit_initializer = startnew(InitMouseCommands);
void InitMouseCommands() {
    @lib = GetLibraryFunctions();
    if (lib is null) { log("Failed to load library functions.", LogLevel::Error, 4, "InitMouseCommands"); return; }
    @mouse = MouseController(lib);
}

Import::Library@ lib = null;
MouseController@ mouse = null;

Import::Library@ GetLibraryFunctions() {
    const string relativeDllPath = "src/commands/lib/MouseControl.dll";
    const string baseFolder = IO::FromDataFolder('');
    const string localDllFile = baseFolder + relativeDllPath;

    if (!IO::FileExists(localDllFile)) {
        IO::CreateFolder(Path::GetDirectoryName(localDllFile));

        try {
            IO::FileSource zippedDll(relativeDllPath);
            IO::File toItem(localDllFile, IO::FileMode::Write);
            toItem.Write(zippedDll.Read(zippedDll.Size()));
            toItem.Close();
        } catch {
            return null;
        }
    }

    return Import::GetLibrary(localDllFile);
}

enum MouseDirection {
    none = 0,

    up = 1,
    down = 2,
    left = 3,
    right = 4,

    upLeft = 5,
    upRight = 6,
    downLeft = 7,
    downRight = 8
};

class MouseController {
    Import::Function@ get_position_x;
    Import::Function@ get_position_y;

    Import::Function@ click;
    Import::Function@ r_click;

    Import::Function@ mouse_down;
    Import::Function@ r_mouse_down;

    Import::Function@ move;
    Import::Function@ move_relative;

    MouseController(Import::Library@ lib) {
        if (lib !is null) {
            @get_position_x = lib.GetFunction("GetPositionX");
            @get_position_y = lib.GetFunction("GetPositionY");

            @r_click = lib.GetFunction("RClick");
            @click = lib.GetFunction("Click");

            @move = lib.GetFunction("Move");
            @move_relative = lib.GetFunction("MoveRelative");
        }
    }
    
    void Click() {
        if (click is null) return;
        click.Call();
    }

    void Click(int x, int y) {
        if (click is null) return;
        Move(x, y);
        Click();
    }

    void Click(int2 pos) {
        if (click is null) return;
        Move(pos);
        Click();
    }

    void Move(int x, int y) {
        if (move is null) return;
        log("Moving to: " + x + ", " + y, LogLevel::Debug, 91, "Move");
        move.Call(x, y);
    }

    void Move(int2 pos) {
        if (move is null) return;
        Move(pos.x, pos.y);
    }

    void MoveRelative(int x, int y) {
        if (move_relative is null) return;
        move_relative.Call(x, y);
    }

    int2 GetPosition() {
        return int2(GetPositionX(), GetPositionY());
    }

    private int GetPositionX() {
        if (get_position_x !is null) {
            return get_position_x.CallInt32();
        }
        log("Failed to get position x (get_position_x is null)", LogLevel::Warn, 113, "GetPositionX");
        return 0;
    }

    private int GetPositionY() {
        if (get_position_y !is null) {
            return get_position_y.CallInt32();
        }
        log("Failed to get position y (get_position_y is null)", LogLevel::Warn, 121, "GetPositionY");
        return 0;
    }

    void MoveOverTime(float startX, float startY, float endX, float endY, int frames) {
        float deltaX = (endX - startX) / frames;
        float deltaY = (endY - startY) / frames;

        for (int i = 0; i < frames; i++) {
            mouse.MoveRelative(int(deltaX), int(deltaY));
            yield(1);
        }
    }

    void Jiggle(int frames, int stepDistance, int radius, const string &in jiggleType) {
        for (int i = 0; i < frames; i++) {
            JiggleOverTime(i, frames, stepDistance, radius, jiggleType);
            yield();
        }
    }

    void JiggleOverTime(int frame, int totalFrames, int stepDistance, int radius, const string &in jiggleType) {
        if (jiggleType == "left right") {
            if (frame % 2 == 0) {
                mouse.MoveRelative(stepDistance, 0);
            } else {
                mouse.MoveRelative(-stepDistance, 0);
            }
        } else if (jiggleType == "up down") {
            if (frame % 2 == 0) {
                mouse.MoveRelative(0, -stepDistance);
            } else {
                mouse.MoveRelative(0, stepDistance);
            }
        } else if (jiggleType == "circle") {
            float theta = (frame * ((2 * Math::PI) / totalFrames)) - (Math::PI / 2);
            int x = int(radius * Math::Cos(theta));
            int y = int(radius * Math::Sin(theta));

            mouse.MoveRelative(x, y);
        } else if (jiggleType == "square") {
            int sideLength = totalFrames / 4;
            int x = 0;
            int y = 0;

            if (frame < sideLength) {
                x = stepDistance * (frame % sideLength);
                y = 0;
            } else if (frame < 2 * sideLength) {
                x = radius;
                y = stepDistance * ((frame - sideLength) % sideLength);
            } else if (frame < 3 * sideLength) {
                x = radius - stepDistance * ((frame - 2 * sideLength) % sideLength);
                y = radius;
            } else {
                x = 0;
                y = radius - stepDistance * ((frame - 3 * sideLength) % sideLength);
            }

            mouse.MoveRelative(x, y);
        } else if (jiggleType == "archimedean spiral") {
            float theta = frame * ((2 * Math::PI) / totalFrames);
            float spiralRadius = stepDistance * theta;
            int x = int(spiralRadius * Math::Cos(theta));
            int y = int(spiralRadius * Math::Sin(theta));

            mouse.MoveRelative(x, y);
        } else if (jiggleType == "zig-zag") {
            int segmentLength = totalFrames / 10;
            if ((frame / segmentLength) % 2 == 0) {
                mouse.MoveRelative(stepDistance, 0);
            } else {
                mouse.MoveRelative(-stepDistance, 0);
            }
        } else if (jiggleType == "triangle") {
            int segmentLength = totalFrames / 3;
            int x = 0;
            int y = 0;

            if (frame < segmentLength) {
                x = stepDistance * (frame % segmentLength);
                y = -stepDistance * (frame % segmentLength);
            } else if (frame < 2 * segmentLength) {
                x = stepDistance * ((frame - segmentLength) % segmentLength);
                y = stepDistance * ((frame - segmentLength) % segmentLength);
            } else {
                x = -stepDistance * ((frame - 2 * segmentLength) % segmentLength);
                y = 0;
            }

            mouse.MoveRelative(x, y);
        }
    }

    void MoveDirection(MouseDirection dir, int frames, int step = 1) {
        for (int i = 0; i < frames; i++) {
            mouse.MoveDirectionOverTime(dir, step);
            yield(1);
        }
    }

    void MoveDirectionOverTime(MouseDirection dir, int step) {
        if (move_relative is null) return;
        
        switch (dir) {
            case MouseDirection::up:
                MoveRelative(0, -step);
                break;
            case MouseDirection::down:
                MoveRelative(0, step);
                break;
            case MouseDirection::left:
                MoveRelative(-step, 0);
                break;
            case MouseDirection::right:
                MoveRelative(step, 0);
                break;
            case MouseDirection::upLeft:
                MoveRelative(-step, -step);
                break;
            case MouseDirection::upRight:
                MoveRelative(step, -step);
                break;
            case MouseDirection::downLeft:
                MoveRelative(-step, step);
                break;
            case MouseDirection::downRight:
                MoveRelative(step, step);
                break;
        }
    }

    float GetScaleFactorForRadius() {
        return MeasureScalingFactor(10);
    }

    float MeasureScalingFactor(int testRadiusUnits) {
        int2 startPosition = GetPosition();
        MoveRelative(testRadiusUnits, 0);
        int2 endPosition = GetPosition();

        int pixelDistance = endPosition.x - startPosition.x;
        if (testRadiusUnits == 0) return 0;
        return float(pixelDistance) / float(testRadiusUnits);
    }
}
