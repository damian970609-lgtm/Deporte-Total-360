package com.damian.shadowkeys.input;

interface IInputService {
    int sendKeyCodes(in int[] keyCodes, int delayMs) = 2;
    void exit() = 1;
    void destroy() = 16777114;
}
