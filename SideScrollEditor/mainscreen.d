module mainscreen;

import framework;
import ui;
import skin;
import graphics;


import std.algorithm;
import collections.list;

import allocation;
import dialogs;
import bridge_core_impl;
import bridge_os;

import bridge.core;
import bridge.os;
import bridge.contexts;
import bridge.attributes;
import bridge.plugins;

enum defFieldSize = 20;
enum defSpacing   = 3;

final class MainScreen : Screen, IEditor, IOS
{
	//These will be here!
	Menu m;
	Gui gui;
	Plugins* plugin;
		
	EditorState			 editorState;	
	EditorServiceLocator locator;
	Assets				 assets_;


	Panels   centerPanels;
	Panels	 leftPanels;
	Panels	 rightPanels;

	//Could be better;
	bool movingLeft  = false;
	float left  =  300;
	bool movingRight = false;
	float right =  300;

	import derelict.glfw3.glfw3;
	GLFWcursor* test;

	Screen other;
	this(Screen other) 
	{
		super(false, false); 
		this.other = other;
	}

	override void initialize() 
	{
		import content.sdl, plugins;
		auto pluginConfig = fromSDLFile!PluginConfig(Mallocator.it, "pluginsConfig.sdl");
		app.addComponent(Mallocator.it.allocate!PluginComponent(Mallocator.it, pluginConfig));

		auto all = Mallocator.cit;
		gui = loadGui(all, app, "guiconfig.sdl");


		plugin = app.locate!Plugins;
		plugin.preReload  = &prePluginReload;
		plugin.postReload = &postPluginReload; 

		editorState = all.allocate!EditorState(Mallocator.cit);
		locator   = all.allocate!EditorServiceLocator(&app.services);
		assets_	  = all.allocate!Assets(all, app.locate!AsyncContentLoader);
	
		IFileFinder finder = all.allocate!FileFinder();
		locator.add(finder);

		createMenu();
		setupPlugins();


		leftPanels = Panels(all, 10, PanelPos.left);
		leftPanels.addPanels(Mallocator.cit, plugin);

		rightPanels = Panels(all, 10, PanelPos.right);
		rightPanels.addPanels(Mallocator.cit, plugin);

		centerPanels = Panels(all, 10, PanelPos.center);
		centerPanels.addPanels(Mallocator.cit, plugin);

		test = glfwCreateStandardCursor(GLFW_HRESIZE_CURSOR);

		/*
		tools = ToolBox(all, 10);
		tools.addTools(plugin);
		*/
	}

	void setupPlugins()
	{
		foreach(ref func; plugin.functions)
		{
			if(func.name == "bridge.core.setupEditorConnection")
			{
				(&func).invoke(cast(IEditor)this);
			}
		}
	}

	void createMenu()
	{
		m = Menu(Mallocator.it, 100); 
		foreach(ref func; plugin.attributeFunctions!(bridge.attributes.MenuItem))
		{
			auto makeDel(const(MetaFunction)* fun)
			{
				return () => fun.invoke!(void)();
			}
			
			auto attrib = func.getAttribute!(bridge.attributes.MenuItem);
			m.addItem(attrib.name, makeDel(&func), attrib.command);
		}
	}

	//IOS interface
	override const(char)[] clipboardText() nothrow
	{
		scope(failure) return (char[]).init;
		import window.clipboard;
		auto cb = app.locate!(Clipboard);
		return cb.text();
	}

	override void clipboardText(const(char)[] text) nothrow
	{	
		scope(failure) return;

		import window.clipboard;
		auto cb = app.locate!(Clipboard);
		return cb.longText(text);
	}

	override void save(string path) nothrow
	{
		try
		{
			import reflection.serialization;
			auto context = ReflectionContext(plugin.assemblies.array);
			toSDLFile(editorState.store, &context, path);
		}
		catch(Exception e)
		{
			import log;
			logInfo(e);
			logInfo("Failed to save! ", path);
		}
	}

	override void open(string path) nothrow
	{
		try
		{
			import reflection.serialization;
			auto context = ReflectionContext(plugin.assemblies.array);
			auto data    = fromSDLFile!DataStore(Mallocator.it, path, context);
			editorState.deallocate();
			editorState.initialize(Mallocator.cit, data);

		}
		catch(Exception e)
		{
			import log;
			logInfo(e);
			logInfo("Failed to open! ", path);
		}
	}

 	///IEDITOR INTERFACE
	override void create() nothrow
	{
		scope(failure) assert(0, "Failed to create project!");
	}

	override void close() nothrow
	{
		scope(failure) return;

		import window;
		auto wnd = app.locate!Window;
		auto fl  = locator.locate!(IFileFinder);

		auto p = fl.saveProjectPath();
		if(p) save(p);
		
		wnd.shouldClose = true;
	}

	override IServiceLocator services() nothrow
	{
		return locator;
	}

	override IAssets assets() nothrow
	{
		return assets_;
	}

	override IEditorState state() nothrow
	{
		return editorState;
	}

	override IOS os() nothrow
	{
		return this;
	}

	override void runGame() nothrow
	{	
		try
		{
			owner.push(other);
		}
		catch(Exception e)
		{
			import log;
			logInfo("Failed to run game!");
		}
	}

	//Need to save the state of the application here
	void prePluginReload(Plugin p)
	{
		m.clear();
		//Save Data here
		import content.sdl, reflection.serialization;

		save("tempsaved.sdl");
		leftPanels.clear();
		rightPanels.clear();
		centerPanels.clear();

		//saveFile("temp.sidal");
		//tools.tools.clear();
	}

	void postPluginReload(Plugin plugin)
	{
		createMenu();
		setupPlugins();
		open("tempsaved.sdl");
		leftPanels .addPanels(Mallocator.cit, this.plugin);
		rightPanels.addPanels(Mallocator.cit, this.plugin);
		centerPanels.addPanels(Mallocator.cit, this.plugin);

	}

	override void update(Time time)
	{
	}	
	
	override void render(Time time)
	{
		import window.window;
		auto w = app.locate!Window;


		gui.renderer.viewport(float2(w.size));
		gl.viewport(0,0, cast(int)w.size.x, cast(int)w.size.y);

		gui.area = Rect(0,0, w.size.x, w.size.y);
		gui.begin();

		auto mouse = gui.mouse;
		auto mloc = mouse.location.x;
		auto inLeft  = mloc  - 3  < left && mloc + 3 > left;
		auto inRight = mloc  - 3  < w.size.x - right && mloc + 3 > w.size.x - right;

		if(mouse.wasPressed(MouseButton.left))
		{
			if(inLeft)
				movingLeft = true;
			if(inRight)
				movingRight = true;
		}

		if(mouse.wasReleased(MouseButton.left))
		{
			movingLeft  = false;
			movingRight = false;
		}

		if(movingRight)
			right = clamp(right - mouse.moveDelta.x, 200, 400);
		if(movingLeft)
			left  = clamp(left + mouse.moveDelta.x, 200, 400);

		if(inLeft || inRight)
		{
			glfwSetCursor(w._windowHandle, test);
		}
		else 
		{
			glfwSetCursor(w._windowHandle, null);
		}


		auto wr =  Rect(left, defSpacing, w.size.x - left - right, w.size.y - 23);
		auto leftSide  = Rect(defSpacing, wr.y, left - defSpacing * 2, wr.h);
		leftPanels.show(gui, leftSide);

		auto rightSide = Rect(wr.right + defSpacing, wr.y, right - defSpacing * 2, wr.h);
		rightPanels.show(gui, rightSide);

		auto center = wr;
		centerPanels.show(gui, center);

		gui.menu(m);
		gui.end();
	}
}

struct Panels
{
	struct Panel
	{
		MetaType     type;
		void[]      data; //Data for the object Variable size to allow for large and small things.
	}

	List!Panel panels;
	int selected;
	PanelPos	 side;

	this(A)(ref A a, size_t size, PanelPos side)
	{
		panels		  = List!Panel(a, size);
		this.selected = 0;
		this.side     = side;
	}

	void addPanels(IAllocator allocator, Plugins* plugin)
	{
		foreach(ref type; plugin.attributeTypes!EditorPanel)
		{	
			auto attrib = type.getAttribute!EditorPanel;
			if(attrib.side != this.side) continue;

			panels ~= Panel(type, (&type).createNew(allocator, allocator));
		}
	}

	void clear()
	{
		panels.clear();
	}

	void show(ref Gui gui, Rect area)
	{
		Rect tb = Rect(area.x, area.y + area.h - defFieldSize, area.w, defFieldSize);
		area.h -= defFieldSize;

		gui.toolbar(tb, selected, panels.map!(x => toTabPage(&x)));
		if(selected >= panels.length) return;

		auto panel = &panels[selected];
		auto func = panel.type.findMethod("show");

		PanelContext context;
		context.gui	  = &gui;
		context.area  = area;
		

		import graphics;
		import derelict.opengl3.gl3;

		auto renderer = gui.renderer;
		renderer.end();

		gl.enable(GL_SCISSOR_TEST);
		gl.scissor(cast(int)area.x, cast(int)area.y,  cast(int)area.w, cast(int)area.h);
		renderer.begin();

		try
		{
			func.invoke(panel.data, &context);
		}
		catch(Exception e)
		{
			import log;
			logInfo(e);
		}

		renderer.end();	
		gl.disable(GL_SCISSOR_TEST);
		renderer.begin();
	}

	auto toTabPage(Panel* p)
	{
		auto panelAttrib = p.type.getAttribute!EditorPanel;
		return panelAttrib.name;
	}


	auto itemNames()
	{
		return panels.map!(x => x.type.typeInfo.name);
	}	
}
