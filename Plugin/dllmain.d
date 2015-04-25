module dllmain;

import std.c.stdio;
import std.c.windows.windows;
import core.sys.windows.dll;
__gshared HINSTANCE g_hInst;

extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
	import util.bench;
    final switch (ulReason)
    {
    case DLL_PROCESS_ATTACH:
        g_hInst = hInstance;
		printf("Attaching Process!\n");	
		dll_process_attach(hInstance, false);
		printf("Attached Process\n");	
        break;

    case DLL_PROCESS_DETACH:
		printf("Detaching Process\n");
		dll_process_detach(hInstance, false);
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