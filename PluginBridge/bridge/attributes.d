module bridge.attributes;

public import common.attributes;

enum PanelPos
{
	left,
	center,
	right
}

struct EditorPanel 
{
	string name;
	PanelPos side;
}

struct EditorTool { }

struct WorldRenderer 
{
	string name;
}

struct ItemRenderer 
{
	string name;
}

public import ui.menu : KeyCommand;
public import window.keyboard : KeyModifiers, Key;

struct MenuItem
{
	string name;
	KeyCommand command;
}	

struct Data { }