module plugin.editor.panels.world;


import plugin.attributes;
import plugin.editor.panels.common;
import plugin.editor.renderers;
import plugin.editor.tools;

import util.traits;

alias Tools = Classes!(plugin.editor.tools);
alias RenderFunctions = Functions!(plugin.editor.renderers);

@EditorPanel("World", PanelPos.center)
struct WorldPanel
{
	int		   selected;
	List!ITool tools;

	this(IAllocator all)
	{
		tools = List!ITool(all, Tools.length);
		foreach(tool; Tools)
			tools ~= cast(ITool)(all.allocate!(tool)());
	}

	void show(PanelContext* context) 
	{
		auto camera   = &SharedData.camera;
		auto renderer = context.gui.renderer;

		if(context.area.contains(context.gui.mouse.location))
			camera.scale = math.clamp(context.gui.mouse.scrollDelta.y + camera.scale, 5, 128);

		auto rcontext = RenderContext(Editor.state, camera, renderer);
		camera.viewport = context.area.toFloat4;

		foreach(func; RenderFunctions)
		{
			func(&rcontext);
		}

		auto tcontext = ToolContext(Editor.state, context.gui.keyboard, context.gui.mouse, camera);
		Rect lowerLeft = Rect(context.area.x + 3, context.area.y + 3, context.area.w - 6, 20);

		auto ftools = tools.filter!(x => x.usable(&tcontext));
		toolbar(*context.gui, lowerLeft, selected, ftools.map!(x => x.name));

		import std.range;
		ftools = ftools.drop(selected);
		if(!ftools.empty)
		{
			auto idx  = tools.countUntil!(x => x.name == ftools.front.name);
			auto tool = tools[idx];

			if(context.area.contains(context.gui.mouse.location))
			{
				tool.use(&tcontext);
				tool.render(&rcontext);
			}

		}
	}
}


enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.world);