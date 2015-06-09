module plugin.tile.panel;


import ui;
import math.vector;
import collections.list;
import allocation;
import reflection;

import std.typetuple;
import std.algorithm;

import pluginshared.components;
import pluginshared.data;
import bridge;

import plugin.attributes;
import plugin.editor.renderers;
import plugin.tile.data;

enum defFieldSize = 20;
enum defSpacing   = 3;

@EditorPanel("Tile", PanelPos.right)
struct TilePanel
{
	int selectedAtlas;
	int selectedImage;
	float2 scroll;

	this(IAllocator all)	
	{
		import log;

	}

	void show(PanelContext* context) 
	{
		auto a   = context.area;
		auto gui = context.gui;
		auto atlasRect = Rect(a.x, a.top - defSpacing - defFieldSize, a.w, defFieldSize);

		auto atlases = Editor.gameAssets.loadedAssets("atl");
		if((*gui).selectionfield(atlasRect, selectedAtlas, atlases.map!(x => x.name)))
		{
			scroll = float2.zero;
		}

		import graphics.textureatlas;
		auto lab	= atlasRect; lab.y -= lab.h + defSpacing;
		(*gui).label(lab, "Tiles");

		auto handle = Editor.gameAssets.locate!(TextureAtlas)(atlases.length > selectedAtlas ? atlases[selectedAtlas].name : "");
		if(handle)
		{
			auto width  = a.x + a.w - defSpacing;
			auto y      = lab.bottom - defSpacing * 2 - 32;
			auto x		= a.x + defSpacing - 32;

			auto itemsPerRow = (a.w - defSpacing) / 32;
			auto size   = (handle.length / itemsPerRow + 1) * (32 + defSpacing);

			auto tileRect = Rect(a.x + defSpacing, 
								 y - size + 32 + defSpacing,
								 a.w - defSpacing * 2,
								 size);

			auto pixel = (*Editor.assets.locate!(TextureAtlas)(Atlas))[Pixel];
			gui.renderer.drawQuad(tileRect, pixel, Color(0xFF434343));
			foreach(i, frame; *handle)
			{
				if(x + 64 > width)
				{
					x  = a.x + defSpacing;
					y -= 32;
				}
				else 
					x += 32 + defSpacing;

				if(context.gui.wasDown(Rect(x,y, 32, 32)))
				{
					selectedImage = i;

					TileData.atlas = atlases[selectedAtlas].name;
					TileData.image = handle.indexToID(i);
				}

				gui.renderer.drawQuad(Rect(x,y, 32, 32).toFloat4, frame, Color.white);
				if(selectedImage == i)
				{
					gui.renderer.drawQuadOutline(Rect(x,y, 32, 32).toFloat4, 1.0f, pixel, Color(0xFF00aaaa));
				}
			}
		}
	}
}


enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.tile.panel);