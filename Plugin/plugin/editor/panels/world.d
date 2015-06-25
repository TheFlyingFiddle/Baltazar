module plugin.editor.panels.world;

import plugin.attributes;
import plugin.editor.panels.common;
import pluginshared.data;
import util.traits;

@EditorPanel("World", PanelPos.center)
struct WorldPanel
{
	int		   selected;
	this(IAllocator all)
	{
	}

	void show(PanelContext* context) 
	{
		import log;
		try
		{
			auto camera   = &SharedData.camera;
			auto renderer = context.gui.renderer;
			if(context.area.contains(context.gui.mouse.location))
				camera.scale = math.clamp(context.gui.mouse.scrollDelta.y + camera.scale, 5, 128);

			auto rcontext = RenderContext(Editor.state, camera, renderer);
			camera.viewport = context.area.toFloat4;

			logInfo("Render");
			auto renderers = Editor.services.locate!(MetaRenderers).renderers;
			foreach(renderer; renderers)
			{
				renderer.render(&rcontext);
			}

			auto tcontext = ToolContext(Editor.state, context.gui.keyboard, context.gui.mouse, camera);
			Rect lowerLeft = Rect(context.area.x + 3, context.area.y + 3, context.area.w - 6, 20);

			auto tools	= Editor.services.locate!(MetaTools).tools;
		
			auto ftools = tools.filter!(x => x.usable(&tcontext));
			toolbar(*context.gui, lowerLeft, selected, ftools.map!(x => x.name));

			import std.range;

			logInfo("Tools");
			ftools = ftools.drop(selected);
			if(!ftools.empty)
			{
				auto idx  = tools.countUntil!(x => x.name == ftools.front.name);
				auto tool = tools[idx];

				if(context.area.contains(context.gui.mouse.location))
				{
					logInfo("Using tool");
					tool.use(&tcontext);
					tool.render(&rcontext);
				}
			}
		}
		catch(Throwable t) 
		{
			import log, std.stdio;
			logInfo(t);
			readln;
		}
	}
}


enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.world);