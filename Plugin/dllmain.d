module dllmain;

import std.c.stdio;
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
		printf("Attaching Process!\n");	
		Runtime.initialize();
		printf("Attached Process\n");	
        break;

    case DLL_PROCESS_DETACH:
		printf("Detaching Process\n");
		Runtime.terminate();
		printf("Detached Process\n");
		std.c.stdio._fcloseallp = null;
        break;

    case DLL_THREAD_ATTACH:
       // dll_thread_attach( true, true );
		printf("Atached Thread\n");	
        break;

    case DLL_THREAD_DETACH:
       // dll_thread_detach( true, true );
		printf("Detached Thread\n");	
        break;
    }
    return true;
}

import reflection;
export extern(C) void* GetAssembly(void* errorFunction)
{
	import dll.error;
	dll.error.errorHandler = cast(errorHandler_t)(errorFunction);

	return cast(void*)(&assembly);		
}