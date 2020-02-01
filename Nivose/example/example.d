module nivose_example;

import nivose;
import std.conv;
import std.stdio;
import std.algorithm.searching;
import core.sys.windows.winbase;
import core.sys.windows.tlhelp32;
import core.sys.windows.windef;

int main()
{
    version (Windows) {} else static assert(0, "The demo is expected only being runned under Windows system");

    auto ni = new Kernel32; // Kernel32 class is a shortcut provided in Nivose.
    scope (exit) ni.dispose(); // Release resources after use. If you want to call DLL `dispose` function, you can write `dispose_` to call it

    writeln("Nivose GetTickCount() Got: ", ni.GetTickCount!(int)()); // Use template parameter to specify return type
    writeln("core.sys.windows GetTickCount() Got: ", GetTickCount());

    writeln();
    writeln("First 10 modules of explorer.exe:");
    complexDemo();

    readln();
    return 0;
}

/// list first ten modules of windows explorer.exe
void complexDemo()
{
    PROCESSENTRY32 entry; // Type definitions are from core.sys.windows
    HMODULE[1024] hMods;
    DWORD cbNeeded;

    entry.dwSize = PROCESSENTRY32.sizeof;

    auto kernel32 = new Nivose!"Windows"("kernel32.dll"); // The "original" way to open Kernel32
    scope (exit) kernel32.dispose();

    auto snapshot = kernel32.CreateToolhelp32Snapshot!HANDLE(TH32CS_SNAPPROCESS, NULL); // You can mix core.sys.windows things with Nivose ones
    scope (exit) CloseHandle(snapshot);

    if (kernel32.Process32FirstW(snapshot, &entry) == TRUE) // You need to choose correct encoding explicitly
    {
        while (kernel32.Process32NextW(snapshot, &entry) == TRUE) // You can use third-party types, like PROCESSENTRY32, with Nivose
        {
            if (entry.szExeFile.to!string.startsWith("explorer.exe"))
            {
                auto moduleSnapshot = CreateToolhelp32Snapshot(0x18, entry.th32ProcessID); // This CreateToolhelp32Snapshot is from core.sys.windows

                if (NULL == moduleSnapshot) break;
                scope(exit) kernel32.CloseHandle(moduleSnapshot);

                MODULEENTRY32 moduleEntry = { dwSize: MODULEENTRY32.sizeof };

                if (!kernel32.Module32FirstW(moduleSnapshot, &moduleEntry)) // Nivose and core.sys.windows APIs can work together seamlessly
                    throw new Exception("Module snapshot not accessable");

                int displayedModuleCount = 0;

                do
                {
                    writeln(moduleEntry.szModule);

                    if (10 == ++displayedModuleCount)
                        break;
                } while (kernel32.Module32NextW(moduleSnapshot, &moduleEntry));

                return;
            }
        }
    }
}