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



final class MainScreen : Screen, IEditor
{
	//These will be here!
	Menu m;
	Gui gui;
	Plugins* plugin;
		
	EditorData			 editorData;	
	EditorServiceLocator locator;
	Assets				 assets_;

	/*
		ToolBox	 tools;
	*/

	Panels   centerPanels;
	Panels	 leftPanels;
	Panels	 rightPanels;

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

		editorData = all.allocate!EditorData(Mallocator.cit, 100);
		locator   = all.allocate!EditorServiceLocator(&app.services);
		assets_	  = all.allocate!Assets(all, app.locate!AsyncContentLoader);
	
		IFileFinder finder = all.allocate!FileFinder();
		locator.add(finder);

		createMenu();
		setupPlugins();

		foreach(ref type; plugin.attributeTypes!(Data))
		{
			editorData.addData(&type);
		}

		leftPanels = Panels(all, 10, PanelPos.left);
		leftPanels.addPanels(Mallocator.cit, plugin);

		rightPanels = Panels(all, 10, PanelPos.right);
		rightPanels.addPanels(Mallocator.cit, plugin);

		centerPanels = Panels(all, 10, PanelPos.center);
		centerPanels.addPanels(Mallocator.cit, plugin);

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


	///IEDITOR INTERFACE
	override void create() nothrow
	{
		scope(failure) assert(0, "Failed to create project!");

		editorData.clear();
		foreach(ref type; plugin.attributeTypes!(Data))
		{
			editorData.addData(&type);
		}
	}

	override void save(string path) nothrow
	{
		try
		{
			import reflection.serialization;
			SaveData data = SaveData(editorData);
			auto context = ReflectionContext(plugin.assemblies.array);
			toSDLFile(data, &context, path);
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
			auto data    = fromSDLFile!SaveData(Mallocator.it, path, context);
			scope(exit) deallocate(Mallocator.it, cast(void[])data.data);

			editorData.clear();
			foreach(ref type; plugin.attributeTypes!(Data))
			{
				bool res = false;
				VariantN!(64) variant;
				foreach(ref v; data.data)
				{
					if(type.isTypeOf(v))
					{
						res = true;
						variant = v;
						break;
					}
				}

				if(res)
					editorData.addData(&type, variant);
				else 
					editorData.addData(&type);

			}

		}
		catch(Exception e)
		{
			import log;
			logInfo(e);
			logInfo("Failed to open! ", path);
		}
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

	override IEditorData data() nothrow
	{
		return editorData;
	}

	//Need to save the state of the application here
	void prePluginReload(Plugin p)
	{
		m.clear();
		//Save Data here
		import content.sdl, reflection.serialization;

		save("tempsaved.sdl");
		editorData.clear();
		leftPanels.clear();
		rightPanels.clear();
		centerPanels.clear();

		//saveFile("temp.sidal");
		//tools.tools.clear();
	}

	//Need to load the state of the application here
	void postPluginReload(Plugin plugin)
	{
		createMenu();
		setupPlugins();
		open("tempsaved.sdl");
		leftPanels .addPanels(Mallocator.cit, this.plugin);
		rightPanels.addPanels(Mallocator.cit, this.plugin);
		centerPanels.addPanels(Mallocator.cit, this.plugin);


		//tools.addTools(this.plugin);
		//createMenu();
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

		auto wr =  Rect(300, defSpacing, w.size.x - 600, w.size.y - 23);
		auto leftSide  = Rect(defSpacing, wr.y, 300 - defSpacing * 2, wr.h);
		leftPanels.show(gui, leftSide);

		auto rightSide = Rect(wr.right + defSpacing, wr.y, 300 - defSpacing * 2, wr.h);
		rightPanels.show(gui, rightSide);

		auto center = wr;
		centerPanels.show(gui, center);

		gui.menu(m);
		gui.end();
	}

	/*
	void renderWorld(ref Gui gui)
	{
		import graphics;
		import derelict.opengl3.gl3;

		auto area = gui.area;
		auto renderer = gui.renderer;
		renderer.end();

		gl.enable(GL_SCISSOR_TEST);
		gl.scissor(cast(int)area.x, cast(int)area.y,  cast(int)area.w, cast(int)area.h);

		renderer.begin();

		import plugins, bridge.attributes, bridge.state;
		auto plugin = app.locate!Plugins;

		void*[3] args;				
		auto rend = RenderContext(renderer, &state.camera, state.images, state.fonts);

		foreach(func; plugin.worldRenderFuncs)
		{
			alias func_t = void function(RenderContext*);
			(cast(func_t)func.funcptr)(&rend);
		}

		foreach(i, ref item; state.items)
		{
			foreach(func; plugin.itemRenderFuncs)
			{
				int count = 0;
				auto params = func.parameters;
				int length = params[1 .. $].length;
				foreach(param; params[1 .. $])
				{
					auto outer = param.typeInfo;
					auto info = param.typeInfo.inner;
					auto comp = item.peekComponent(info);
					if(comp)
					{
						args[count++] = comp.data.ptr;
						if(count == length)
						{
							alias func_t = void function(RenderContext*,void*,void*);
							(cast(func_t)func.funcptr)(&rend, args[0], args[1]);
							break;
						}
					}
					else 
						break;
				}
			}
		}

		renderer.end();	
		gl.disable(GL_SCISSOR_TEST);
		renderer.begin();
	}


	void run()
	{	
		save();
		owner.push(other);
	}
	*/
}

/*
struct ToolBox
{
	struct Tool
	{
		MetaType     type;
		VariantN!32 data;
	}

	List!Tool tools;
	int selected;

	this(A)(ref A a, size_t size)
	{
		tools = List!Tool(a, size);
		selected = -1;
	}

	void clear()
	{
		tools.clear();
		selected = -1;
	}

	void addTools(Plugins* plugin)
	{
		foreach(ref type; plugin.attributeTypes!(EditorTool))
		{	
			tools ~= Tool(type, type.initial!32);
		}
	}
	
	void use(EditorState* state, ref Gui gui)
	{
		if(selected == -1) return;

		auto tool = &tools[selected];
		auto func = tool.type.findMethod("use");

		ToolContext context;
		context.state	 = state;
		context.mouse    = gui.mouse;
		context.keyboard = gui.keyboard;

		try
		{
			func.invoke(tool.data, &context);
		}
		catch(Exception e)
		{
			import log;
			logInfo(e);
		}
	}

	auto itemNames()
	{
		return tools.map!(x => x.type.typeInfo.name);
	}	
}
*/

struct Panels
{
	struct Panel
	{
		MetaType     type;
		VariantN!64  data;
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

			panels ~= Panel(type, (&type).create!64(allocator));
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
