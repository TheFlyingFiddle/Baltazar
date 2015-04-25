module dllmain;
import std.c.windows.windows;
__gshared HINSTANCE g_hInst;

import core.runtime;

extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    final switch (ulReason)
    {
		case DLL_PROCESS_ATTACH:
			g_hInst = hInstance;
			break;

		case DLL_PROCESS_DETACH:
			Runtime.terminate();
			import std.c.stdio;
			std.c.stdio._fcloseallp = null;
			break;

		case DLL_THREAD_ATTACH:
			break;

		case DLL_THREAD_DETACH:
			break;
    }
    return true;
}


//import reflection.data;
export extern(C) void* GetAssembly(void* errorFunction)
{
	Runtime.initialize();
	return null;		
}