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

public import ui.menu : KeyCommand;
public import window.keyboard : KeyModifiers, Key;

struct MenuItem
{
	string name;
	KeyCommand command;
}	