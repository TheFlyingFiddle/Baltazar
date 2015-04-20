module bridge.os;

interface IOS
{
	nothrow const(char)[] clipboardText();
	nothrow void   clipboardText(const(char)[] text);

	nothrow void open(string path);
	nothrow void save(string path);
}