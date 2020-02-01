# nivose.d
A simple D dynamic link library accessor, aimed at making calling to third-party APIs easier. Windows and POSIX supported.

# Usage
For cases where a dynamic link library is loaded and used at run time, a series of API call processes are usually required (`LoadLibrary-GetProcAddress-FreeLibrary` or `dlopen-dlsym-dlclose`), and the type of the function pointer needs to be specified. When this happens multiple times, the code can become complex and verbose.

__nivose.d__ aims to simplify this process, allowing call to APIs in the dynamic link library by written with a more natural and smooth syntax, while avoiding introducing additional performance overhead during run time. With __nivose.d__, you can now load dynamic link libraries and call functions in the runtime like those methods built into D language.

__nivose.d__ generates the required type information and underlying code at compile time, and provides a simple caching implemention. __nivose.d__ does not provide anything from any third-party libraries. It will just generate and adapt everything at compile time.

#### Before
```D
import core.sys.windows.winbase;
import core.sys.windows.windef;

auto hDLL = LoadLibrary("MYDLL.DLL");

if (hDLL == NULL) ;// Error handling
scope (exit) FreeLibrary(hDLL);

alias LPMYFUNCTION = extern(C) long function(int, void*, immutable(char*));
auto lpMyFunction = cast(LPMYFUNCTION) GetProcAddress(hDLL, "MyFunction");

if (lpMyFunction == NULL) ;// Error handling

auto result = lpMyFunction(1, null, "hello".ptr);
```

#### After
```D
import nivose;

auto myDll = new Nivose!"C"("MYDLL.DLL");
scope (exit) myDll.dispose();

auto result = myDll.MyFunction!long(1, null, "hello".ptr);
```

# Quickstart
This is a simple example for Windows system users. You can see a more detailed one in [example.d](https://github.com/LimiQS/nivose.d/blob/master/Nivose/example/example.d)
```D
import nivose; // <- here!
import std.stdio;
import core.sys.windows.winbase;

// Kernel32 class is a shortcut provided in Nivose.
// You can write your own shortcuts and it's pretty simple, I promise.
auto k32 = new Kernel32;

// Release resources after use.
// Wondering what if you want to call the `dispose` routine in your dll? You can use `dispose_` to call it.
// And now you want to call `dispose_` in dll? Just attach another underscore and it will work.
scope (exit) k32.dispose();

// Use the template parameter to specify return type.
// These two should almost always have same result.
// Type information and `GetProcAddress` works will be generated at compile time.
writeln("Nivose GetTickCount() Got: ", k32.GetTickCount!int());
writeln("core.sys.windows GetTickCount() Got: ", GetTickCount());

// One line quickstart:
// NivoseInstanceName.YourFunctionNameHere!ReturnTypeHere(ArgumentsWithCorrectTypeHere);
```
