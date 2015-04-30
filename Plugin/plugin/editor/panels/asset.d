module plugin.editor.panels.asset;

import plugin.editor.panels.common;

@EditorPanel("Assets", PanelPos.right)
struct EntityPanel
{
	this(IAllocator all) 
	{
	}

	void show(PanelContext* context)
	{
	}
}

enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.asset);