#include <Windows.h>
#include "pch.h"

struct vec2 {
    int x;
    int y;

    vec2(int _x, int _y) : x(_x), y(_y) {}
};

const int SAFE_KEY = VK_NUMPAD3;

bool IsSafeKeyPressed() {
    return (GetAsyncKeyState(SAFE_KEY) & 0x8000) != 0;
}

extern "C" __declspec(dllexport) void Move(int x, int y) {
    if (IsSafeKeyPressed()) {
        SetCursorPos(x, y);
    }
}

extern "C" __declspec(dllexport) void MoveRelative(int dx, int dy) {
    if (IsSafeKeyPressed()) {
        POINT p;
        if (GetCursorPos(&p)) {
            SetCursorPos(p.x + dx, p.y + dy);
        }
    }
}

void ClickInternal(DWORD buttonDown, DWORD buttonUp) {
    if (IsSafeKeyPressed()) {
        INPUT inputs[2] = {};

        inputs[0].type = INPUT_MOUSE;
        inputs[0].mi.dwFlags = buttonDown;

        inputs[1].type = INPUT_MOUSE;
        inputs[1].mi.dwFlags = buttonUp;

        SendInput(2, inputs, sizeof(INPUT));
    }
}

extern "C" __declspec(dllexport) void Click() {
    ClickInternal(MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP);
}

extern "C" __declspec(dllexport) void RClick() {
    ClickInternal(MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP);
}

extern "C" __declspec(dllexport) void MouseDown(bool hold) {
    if (IsSafeKeyPressed()) {
        INPUT input = {};
        input.type = INPUT_MOUSE;
        input.mi.dwFlags = hold ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
        SendInput(1, &input, sizeof(INPUT));
    }
}

extern "C" __declspec(dllexport) void RMouseDown(bool hold) {
    if (IsSafeKeyPressed()) {
        INPUT input = {};
        input.type = INPUT_MOUSE;
        input.mi.dwFlags = hold ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP;
        SendInput(1, &input, sizeof(INPUT));
    }
}

extern "C" __declspec(dllexport) int GetPositionX() {
    POINT p;
    if (GetCursorPos(&p)) {
        return p.x;
    }
    return 0;
}

extern "C" __declspec(dllexport) int GetPositionY() {
    POINT p;
    if (GetCursorPos(&p)) {
        return p.y;
    }
    return 0;
}
