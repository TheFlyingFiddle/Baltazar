module bridge.core;

import bridge.os;
import bridge.data;
import bridge.attributes;
import util.hash;
import util.variant;
import util.traits;
import collections.list;
import collections.map;


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

template isData(T)
{
	import util.traits;
	enum isData = util.traits.hasAttribute!(T, Data);
}

@DontReflect
interface IAssets
{
	import content.content;
	Handle* locateAsset(TypeHash type, string asset) nothrow;
	List!Asset loadedAssets(string type) nothrow;
	
	final T* locate(T)(string item) nothrow
	{
		auto handle = locateAsset(typeHash!T, item);
		if(handle !is null) return cast(T*)(handle.item);
		
		return null;
	}

	final ContentHandle!T getHandle(T)(string item) nothrow
	{
		return ContentHandle!T(locateAsset(typeHash!T, item));
	}
}

@DontReflect
struct Asset
{
	string   name;
	List!string subitems;
}	

@DontReflect
interface IFileFinder
{
	string findOpenProjectPath() nothrow;
	string openProjectPath() nothrow;

	string findSaveProjectPath() nothrow;
	string saveProjectPath() nothrow;

	string openPath(string ext) nothrow;
	string savePath(string ext) nothrow;
}


import math.vector;
import graphics.color;

@DontReflect
interface IEditor
{
	nothrow void create();
	nothrow void runGame();
	nothrow void close();

	nothrow IServiceLocator	services();
	nothrow IAssets			assets();
	nothrow IAssets			gameAssets();

	nothrow IEditorState	state();
	nothrow IOS			    os();
}

@DontReflect
struct Editor
{
	private __gshared static IEditor	editor;

	static void create()
	{
		editor.create();
	}

	static void runGame()
	{
		editor.runGame();
	}

	static void close()
	{
		editor.close();
	}

	static IEditorState state() nothrow
	{
		return editor.state;	
	}

	static IAssets assets() nothrow
	{
		return editor.assets;
	}

	static IAssets gameAssets() nothrow
	{
		return editor.gameAssets;
	}

	static IServiceLocator services() nothrow
	{
		return editor.services;
	}

	static IOS	os() nothrow
	{
		return editor.os;
	}
}

void setupEditorConnection(IEditor editor) nothrow
{
	import log;
	logInfo("Setup called!");
	Editor.editor		   = editor;

	import reflection;
	foreach(func; assembly.functions)
	{
		if(func.hasAttribute!PluginSetup)
		{
			try
			{
				(&func).invoke(editor);
			}
			catch(Throwable e)
			{
				logErr(e);
			}
		}
	}
}

void teardownEditorConnection(IEditor editor) nothrow
{
	import log;
	logInfo("Teardown called!");
	Editor.editor = null;

	import reflection;
	foreach(func; assembly.functions)
	{
		if(func.hasAttribute!PluginTeardown)
		{
			try
			{
				(&func).invoke(editor);
			}
			catch(Throwable e)
			{
				logErr(e);
			}
		}
	}
}

__gshared static this()
{
	genFunction!(setupEditorConnection)();
	genFunction!(teardownEditorConnection)();
}

//Tag that indicates that a function should be called on PluginSetup.
struct PluginSetup { }

//Signature for setup functions.
alias PluginSetupFunc = void function(IEditor);

//Tag that indicates that a function should be called upon PluginTeardown.
struct PluginTeardown { }

//Signature for teardown functions.
alias PluginTeardownFunc = void function(IEditor);