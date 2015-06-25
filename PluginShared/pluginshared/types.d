module pluginshared.types;

struct TextureID
{
	string atlas;
	string image;
}

struct FontID
{
	string atlas;
	string font;
}

struct GuiContext
{
	import bridge, ui;
	import std.algorithm;

	bool handle(ref Gui gui, Rect r, ref TextureID t, HashID styleID)
	{
		auto atlases = Editor.gameAssets.loadedAssets("atl");
		int aIdx    = cast(uint)atlases.countUntil!(x => x.name == t.atlas);
		int iIdx  = -1;
		if(aIdx != -1) 
		{
			iIdx = cast(uint)atlases[aIdx].subitems.countUntil!(x => x == t.image);
		}

		Rect atlasRect = Rect(r.x, r.y + 23, r.w, 20);
		Rect imgRect   = Rect(r.x, r.y, r.w, 20);

		bool result = false;
		if(gui.selectionfield(atlasRect, aIdx, atlases.array.map!(x => x.name)))
		{
			t.atlas = atlases[aIdx].name;
			result = true;
		}

		if(aIdx != -1 && gui.selectionfield(imgRect, iIdx, atlases[aIdx].subitems))
		{
			t.image = atlases[aIdx].subitems[iIdx];
			result = true;
		}

		return result;
	}

	bool handle(ref Gui gui, Rect r, ref FontID t, HashID styleID)
	{
		auto atlases = Editor.gameAssets.loadedAssets("fontatl");
		int aIdx = cast(int)atlases.countUntil!(x => x.name == t.atlas);
		int fIdx = -1;
		if(aIdx != -1) 
		{
			fIdx = cast(int)atlases[aIdx].subitems.countUntil!(x => x == t.font);
		}

		Rect atlasRect = Rect(r.x, r.y + 23, r.w, 20);
		Rect fntRect   = Rect(r.x, r.y, r.w, 20);

		bool result = false;
		if(gui.selectionfield(atlasRect, aIdx, atlases.array.map!(x => x.name)))
		{
			t.atlas = atlases[aIdx].name;
			result = true;
		}

		if(aIdx != -1 && gui.selectionfield(fntRect, fIdx, atlases[aIdx].subitems))
		{
			t.font = atlases[aIdx].subitems[fIdx];
			result = true;
		}

		return result;
	}
}