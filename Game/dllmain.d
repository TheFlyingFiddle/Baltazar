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
			import util.bench;
			auto prof = StackProfile("RT initialize");
			Runtime.initialize();
			break;

		case DLL_PROCESS_DETACH:
			Runtime.terminate();
			std.c.stdio._fcloseallp = null;
			break;

		case DLL_THREAD_ATTACH:
			break;

		case DLL_THREAD_DETACH:
			break;
    }
    return true;
}


import reflection.data;
export extern(C) void* GetAssembly(void* errorFunction)
{
	import dll.error;
	dll.error.errorHandler = cast(errorHandler_t)(errorFunction);

	return cast(void*)(&assembly);		
}