module bridge.plugins;

public import reflection;
import std.exception;
import bridge.attributes;
import std.algorithm;
import collections.list;
import std.file;
import std.datetime;
import std.path;
import util.strings;

extern(Windows) 
{
	void* LoadLibraryA(const(char*) fileName);	
	void* FreeLibrary(void*);
    void* GetProcAddress(void*, const char*);
}

@DontReflect
struct Plugin
{	
	string path;
	void*  handle;
	const(MetaAssembly)* assembly;
}

@DontReflect
struct Plugins
{
	List!SysTime fileChangedInfo;

	List!string paths;
	List!(void*)  libraryHandles;
	List!(MetaAssembly*) assemblies;

	@property void delegate(Plugin) preReload;
	@property void delegate(Plugin) postReload;

	this(A)(ref A all, size_t size)
	{
		fileChangedInfo = List!SysTime(all, size);

		paths		   = List!string(all, size);
		libraryHandles = List!(void*)(all, size);
		assemblies	   = List!(MetaAssembly*)(all, size);

	}

	void loadLibrary(string path)
	{
		import util.bench;
		auto prof = StackProfile("Load plugin total: " ~ path);

		auto time = timeLastModified(path);
		//Copy the files
		char[1024] buffer = void;
		auto pdb = text1024(dirName(path), "\\", baseName(stripExtension(path)), ".pdb\0");
		if(exists(pdb))
			copy(pdb, text(buffer[], "..\\temp\\", baseName(stripExtension(path)), time.stdTime, ".pdb\0"));

		auto dll = text1024("..\\temp\\", baseName(path), time.stdTime, "\0");
		{
			auto prof2 = StackProfile("Copy Library " ~ path);
			copy(path, dll);
		}
		void* lib;
		{
			auto prof2 = StackProfile("Load LibraryA");
			lib = LoadLibraryA(dll.ptr);
			enforce(lib, "Could not load library! " ~ path);
		}

		auto funcAddr = GetProcAddress(lib, "GetAssembly");
		enforce(funcAddr, "Could not load reflection data! " ~ path);

		alias extern(C) void* function(void*) func_t;

		import dll.error;
		auto func = cast(func_t)funcAddr;

		import log;
		void* handler = errorHandler;
		auto assembly = cast(MetaAssembly*)func(handler);

		fileChangedInfo ~= timeLastModified(path);
		paths ~= path;
		libraryHandles ~= lib;
		assemblies ~= assembly;
	}

	void reloadLibrary(string path)
	{
		import log;
		logInfo("Reloading library: ", path);
		auto libi = paths.countUntil!(x => x == path);
		if(libi == -1) return;

		Plugin p = Plugin(paths[libi], 
						  libraryHandles[libi],
					      assemblies[libi]);

		if(preReload !is null)
		{
			preReload(p);
		}

		unloadLibrary(path);
		loadLibrary(path);

		p = Plugin(paths[libi], 
				   libraryHandles[libi],
				   assemblies[libi]);

		if(postReload !is null)
		{
			postReload(p);
		}
	}

	void unloadLibrary(string path)
	{
		auto libi = paths.countUntil!(x => x == path);
		if(libi == -1) return;

		FreeLibrary(libraryHandles[libi]);

		fileChangedInfo.removeAt(libi);
		paths.removeAt(libi);
		libraryHandles.removeAt(libi);
		assemblies.removeAt(libi);
	}

	void unloadAll()
	{
		foreach(handle; libraryHandles)
			FreeLibrary(handle);

		paths.clear();
		libraryHandles.clear();
		assemblies.clear();
	}

	import util.hash;
	auto findType(TypeHash type)
	{
		foreach(ref a; assemblies)
		{
			auto info = a.findInfo(type);
			if(info) return info.metaType;
		}

		return null;
	}

	auto functions()
	{
		return assemblies.map!(x => x.functions).joiner;
	}

	auto attributeTypes(T)()
	{
		return assemblies.map!(x => x.types.filter!(x => x.hasAttribute!T)).joiner;
	}

	auto attributeFunctions(T)()
	{
		return functions.filter!(x => x.hasAttribute!T);
	}
}