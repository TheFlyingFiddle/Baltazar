module bridge.core;

import bridge.attributes;
import util.hash;
import util.variant;
import reflection;

@DontReflect
interface IServiceLocator
{
	void addService(void*, TypeHash, string) nothrow;
	void* locateService(TypeHash, string) nothrow;

	final void add(T)(T* service, string s = "") nothrow if(is(T == struct))
	{
		addService(cast(void*)service, typeHash!T, s);
	}

	final T* locate(T)(string s ="") nothrow if(is(T == struct))
	{
		return cast(T*)locateService(typeHash!T, s);
	}

	final void add(T)(T service, string s = "") nothrow if(is(T == class) || is(T == interface))
	{
		addService(cast(void*)service, typeHash!T, s);
	}

	final T locate(T)(string s ="") nothrow if(is(T == class) || is(T == interface))
	{
		return cast(T)locateService(typeHash!T, s);
	}

}

@DontReflect
interface IEditorData
{
	void* locateData(TypeHash data) nothrow;
	final T* locate(T)() nothrow if(isData!T) 
	{
		return cast(T*)locateData(typeHash!T);
	}
}

template isData(T)
{
	import util.traits;
	enum isData = util.traits.hasAttribute!(T, Data);
}

@DontReflect
interface IAssets
{
	void* locateAsset(TypeHash type, HashID asset) nothrow;
	
	final T* locate(T)(string item) nothrow
	{
		return locate!(T)(HashID(item));
	}

	final T* locate(T)(HashID asset) nothrow
	{
		return cast(T*)locateAsset(typeHash!T, asset);
	}
}

@DontReflect
interface IEditor
{
	nothrow void open(string path);
	nothrow void save(string path);
	nothrow void close();

	nothrow IServiceLocator	services() ;
	nothrow IAssets			assets();
	nothrow IEditorData		data();
}

@DontReflect
struct Editor
{
	private __gshared static IEditor	editor;
	static void open(string path)
	{
		editor.open(path);
	}

	static void save(string path)
	{
		editor.save(path);
	}

	static void close()
	{
		editor.close();
	}

	static IEditorData data() nothrow
	{
		return editor.data;	
	}

	static IAssets assets() nothrow
	{
		return editor.assets;
	}

	static IServiceLocator services() nothrow
	{
		return editor.services;
	}
}

void setupEditorConnection(IEditor editor) nothrow
{
	import log;
	logInfo("Setup called!");
	Editor.editor		   = editor;
}

__gshared static this()
{
	genFunction!(setupEditorConnection)();
}