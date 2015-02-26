module plugin;

import common.components;
import common.attributes;

public import plugin.editor.renderers;
public import plugin.editor.tools;
public import plugin.editor.panels;
public import plugin.editor.menus;

template isTest(T...) if(T.length == 1)
{
	enum isTest = true;
}

import reflection;
mixin GenerateMetaData!(isTest,
                        common.components,
						plugin.editor.commands,
                        plugin.editor.data,
                        plugin.editor.menus,
                        plugin.editor.renderers, 
                        plugin.editor.tools,
                        plugin.editor.panels);