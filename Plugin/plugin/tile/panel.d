module plugin.tile.panel;


import ui;
import math.vector;

import std.typetuple;
import std.algorithm;

import plugin.tile.data;
import pluginshared.components;
import pluginshared.data;
import pluginshared.componentmeta;
import bridge;


enum defFieldSize = 20;
enum defSpacing   = 3;

@Component struct TileMap
{
	uint	length;
	int2[]  positions;
	ubyte[] type;
	uint[]  tint;
	uint[]  tileID;

	static void* stdload(IEditorState state, uint id, TileMap* store)
	{
		return store;
	}

	static void stdstore(T)(IEditorState state, uint id, TileMap* store)
	{
	}

	static void show(ref Gui gui, ref float offset, float width, TileMap* data) 
	{
		static int selectedAtlas;
		static int selectedImage;
		static float2 scroll;
		static string atlas;

		offset -= defFieldSize + defSpacing * 2;

		auto lab = Rect(defSpacing, offset, 100, defFieldSize);

		import graphics.textureatlas;
		auto atlasRect	= lab; atlasRect.x = 100; atlasRect.w = width - 100;

		gui.label(lab, "Tiles");
		auto atlases = Editor.gameAssets.loadedAssets("atl");
		if(gui.selectionfield(atlasRect, selectedAtlas, atlases.map!(x => x.name)))
		{
			scroll = float2.zero;
		}

		auto handle = Editor.gameAssets.locate!(TextureAtlas)(atlases.length > selectedAtlas ? atlases[selectedAtlas].name : "");
		if(handle)
		{
			auto right	= gui.area.x + width;
			auto y      = lab.bottom - defSpacing * 2 - 32;
			auto x		= gui.area.x + defSpacing;

			auto itemsPerRow = (width - defSpacing) / 32;
			auto size   = (handle.length / itemsPerRow + 1) * (32 + defSpacing);

			auto tileRect = Rect(gui.area.x + defSpacing, 
								 y - size + 32 + defSpacing,
								 width - defSpacing * 2,
								 size);

			auto pixel = (*Editor.assets.locate!(TextureAtlas)(Atlas))[Pixel];
			gui.renderer.drawQuad(tileRect, pixel, Color(0xFF434343));
			foreach(i, frame; *handle)
			{
				if(x + 64 > right)
				{
					x  = gui.area.x + defSpacing;
					y -= 32;
				}
				else 
					x += 32 + defSpacing;

				if(gui.wasDown(Rect(x,y, 32, 32)))
				{
					selectedImage = i;

					atlas = atlases[selectedAtlas].name;
					TileData.image = handle.indexToID(i);
				}

				gui.renderer.drawQuad(Rect(x, y, 32, 32).toFloat4, frame, Color.white);
				if(selectedImage == i)
				{
					gui.renderer.drawQuadOutline(Rect(x, y, 32, 32).toFloat4, 1.0f, pixel, Color(0xFF00aaaa));
				}
			}

			offset = tileRect.bottom;
		}
	}
}

mixin ComponentBindings!(plugin.tile.panel);