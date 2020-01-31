module nivose;

import std.conv;
import std.meta;
import std.range;
import std.traits;
import std.algorithm;
import std.algorithm.searching;

version (Windows)
{
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
} 
else version (Posix)
{
    import core.sys.posix.dlfcn;
}

class Kernel32 : Nivose!"Windows"
{
    this()
    {
        super("kernel32.dll");
    }
}

class User32 : Nivose!"Windows"
{
    this()
    {
        super("user32.dll");
    }
}

/**
Nivose dynamic library invoker.
Params:
expType = Call convention of the dynamic library file in D naming. See enum `ImportType`.
*/
class Nivose(string expType)
{
    private void*[string] _funcCache;
    private void* _handle;
    private bool _useCache;

    /**
    Open a specific dynamic library.
    Params:
    libPath = Path to the dynamic library file.
    loadFlags = Flags for lower level library loading API. Please refer to system API reference to fill in the appropriate value.
    _useCache = Caching the function pointer to prevent performance loss.
    */
    this(string libPath, int loadFlags = 0, bool useCache = true)
    {
        _handle = openLibrary(libPath, loadFlags);
        _useCache = useCache;
    }

    /**
    Releases the resources used by the Nivose instance.
    */
    void dispose()
    {
        closeLibrary();
    }
    
    template opDispatch(string name)
    {
        enum funcName = name.endsWith("_") ? name.take(name.length - 1).to!string : name;

        /**
        Invoke the specified third-party library function with the same name.
        If the function name has been defined in Nivose, or has underscore(s) at the end, please add an underscore after the function name to redirect.
        Params:
            arguments = The parameters of the third-party library function.
            Please view the third-party library documentation for types and available values for the function.
            You must ensure that the parameter types are correct.
        Returns: 
            The return value of the third-party library function. 
            The default type of this value is a 32-bit unsigned integer (`uint`).
            You must specify the correct return value type through the function template.
        */
        TRetn opDispatch(TRetn = uint, TArgs...)(TArgs arguments)
        if (isType!TRetn)
        {
            mixin(importsGenerator!TArgs());
            mixin(importsGenerator!TRetn());

            mixin("extern(" ~ expType ~ ") " ~ TRetn.stringof ~ " function" ~ TArgs.stringof ~ " funcTemplate;");

            if (_useCache)
            {
                auto cachePtr = (funcName in _funcCache);
                if (cachePtr !is null)
                {
                    auto funcPtr = cast(typeof(funcTemplate))*cachePtr;
                    return funcPtr(arguments);
                }
            }

            auto funcTempPtr = findFunction(_handle, funcName);

            if (_useCache)
            {
                _funcCache[funcName] = funcTempPtr;
            }

            auto funcPtr = cast(typeof(funcTemplate)) funcTempPtr;
            return funcPtr(arguments);
        }
    }

    /**
    System independent dynamic library loader.
    */
    private void* openLibrary(string libPath, int loadFlags)
    {
        version (Windows)
        {
            auto hModule = LoadLibraryEx(libPath.to!wstring.ptr, NULL, loadFlags);

            if (hModule == NULL)
            {
                throw new Exception("LoadLibraryEx failed with error code: " ~ GetLastError().to!string ~ ".");
            }

            return hModule;
        }
        else version (Posix)
        {
            auto hModule = dlopen(libPath, loadFlags);

            if (hModule == null)
            {
                throw new Exception("dlopen failed with error message: " ~ dlerror().to!string ~ ".");
            }

            return hModule;
        }
        else
        {
            static assert(0, "This operation system is not currently supported.");
        }
    }

    /**
    System independent function getter.
    */
    private void* findFunction(void* hModule, string functionName)
    {
        if (hModule == null) throw new Exception("Invalid module handle.");

        version (Windows)
        {
            auto func = GetProcAddress(hModule, functionName.ptr);

            if (func == NULL)
            {
                throw new Exception("GetProcAddress failed with error code: " ~ GetLastError().to!string ~ ".");
            }

            return func;
        }
        else version (Posix)
        {
            dlerror();
            auto func = dlsym(hModule, functionName.ptr);

            auto err = dlerror();
            if (func == null)
            {
                throw new Exception(err == null ? "dlsym successed but no valid function address returned" : "dlsym failed with error message: " ~ err.to!string ~ ".");
            }

            return func;
        }
        else
        {
            static assert(0, "This operation system is not currently supported.");
        }
    }

    /**
    System independent dynamic library unloader.
    */
    private void closeLibrary()
    {
        if (_handle == null) return;

        version (Windows)
        {
            auto succ = FreeLibrary(_handle);

            if (succ == 0)
            {
                throw new Exception("FreeLibrary failed with error code: " ~ GetLastError().to!string ~ ".");
            }

            _handle = null;
        }
        else version (Posix)
        {
            auto succ = dlclose(_handle);

            if (succ != 0)
            {
                throw new Exception("dlclose failed with error message: " ~ dlerror().to!string ~ ".");
            }

            _handle = null;
        }
        else
        {
            static assert(0, "This operation system is not currently supported.");
        }
    }
}

/**
Supported import types of Nivose.
*/
enum ImportType : string
{
    C = "C",
    CPP = "C++",
    D = "D",
    Windows = "Windows",
    System = "System",
    ObjC = "Objective-C",
}

private: // codegen for automatic type import

string importsGenerator(I...)()
{
	if (!__ctfe)
		assert (false);
    
    string imports;

    static foreach(T; I)
    {
        imports ~= generateModuleImports!(T)() ~ "\n";
    }

    return imports;
}

/+

Below is a modified version of vibe.d generateModuleImports

Copyright (c) 2012-2020 Sönke Ludwig

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

+/

string generateModuleImports(I)()
{
	if (!__ctfe)
		assert (false);

	import std.algorithm : map;
	import std.array : join;

	auto modules = getRequiredImports!(I)();
	return join(map!(a => "import " ~ a ~ ";")(modules), "\n");
}

string[] getRequiredImports(I)()
{
	import std.traits : ReturnType;

	if( !__ctfe )
		assert(false);

	bool[string] visited;
	string[] ret;

	void addModule(string name)
	{
		if (name !in visited) {
			ret ~= name;
			visited[name] = true;
		}
	}

    foreach (symbol; getSymbols!(I)) {
        static if (__traits(compiles, moduleName!symbol)) {
            addModule(moduleName!symbol);
        }
    }

	return ret;
}

template getSymbols(T)
{
	import std.typetuple : TypeTuple, NoDuplicates, staticMap;
	import std.traits;

	private template Implementation(T)
	{
		static if (is(T == U!V, alias U, V)) { // single-argument template support
			alias Implementation = TypeTuple!(U, Implementation!V);
		}
		else static if (isAggregateType!T || is(T == enum)) {
			alias Implementation = T;
		}
		else static if (isStaticArray!T || isArray!T) {
			alias Implementation = Implementation!(typeof(T.init[0]));
		}
		else static if (isAssociativeArray!T) {
			alias Implementation = TypeTuple!(
                                              Implementation!(ValueType!T),
                                              Implementation!(KeyType!T)
                                              );
		}
		else static if (isPointer!T) {
			alias Implementation = Implementation!(PointerTarget!T);
		}
		else
			alias Implementation = TypeTuple!();
	}

	alias getSymbols = NoDuplicates!(Implementation!T);
}