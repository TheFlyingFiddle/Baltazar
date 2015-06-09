module bridge.attributes;

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


public import window.keyboard : KeyCommand, Key, KeyModifiers;
struct MenuItem
{
	string name;
	KeyCommand command;
}	