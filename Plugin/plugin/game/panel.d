module plugin.game.panel;

public import ui;
public import math.vector;
public import collections.list;
public import allocation;
public import reflection;

public import std.typetuple;
public import std.algorithm;

public import common.components;
public import common.attributes;
public import common.identifiers;
public import bridge;

import plugin.attributes;
import plugin.editor.renderers;

public import plugin.core.data;

enum defFieldSize = 20;
enum defSpacing   = 3;

enum State
{
	running,
	paused,
	stopped
}


@EditorPanel("Game", PanelPos.center)
struct GamePanel
{
	State state;

	this(IAllocator all)	
	{
		state = State.stopped;
	}

	void show(PanelContext* context) 
	{
		auto camera   = &SharedData.camera;
		auto renderer = context.gui.renderer;

		if(context.area.contains(context.gui.mouse.location))
			camera.scale = clamp(context.gui.mouse.scrollDelta.y + camera.scale, 5, 128);

		auto rcontext = RenderContext(Editor.state, camera, renderer);
		camera.viewport = context.area.toFloat4;

		foreach(func; RenderFunctions)
		{
			func(&rcontext);
		}


		auto fstButton = Rect(context.area.zw + float2(-defSpacing - 90, -defSpacing - defFieldSize * 2), 
							   context.area.zw + float2(-defSpacing, -defSpacing));

		auto sndButton = Rect(fstButton.xy + float2(-defSpacing - 90, 0), 
							  fstButton.xw + float2(-defSpacing, 0));

		
		if((*context.gui).button(fstButton, "STOP"))
		{
			state = State.stopped;
		}

		bool res = state == State.running ? true : false;
		if((*context.gui).toggle(sndButton, res, "Pause", "Run"))
		{
			if(state == State.running)
			{
				state = State.paused;
			}
			else 
			{
				//Start running again.
				state = State.running;
			}
		}
	}
}


enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.game.panel);