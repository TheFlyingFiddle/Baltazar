module content.reloading;
import concurency.task;
import content.content;
import std.socket;
import allocation;

version(RELOADING)
{
	void setupReloader(uint ip, ushort port, AsyncContentLoader* loader)
	{
		doPoolTask!reloading(ip, port, loader);
	}

	private void connect(TcpSocket socket, uint ip, ushort port)
	{
		import std.stdio;
		auto remote = new InternetAddress(ip, port);
		socket.connect(remote);
		socket.blocking = true;
	}

	void reloading(uint ip, ushort port, AsyncContentLoader* loader)
	{
		registerThread("reloader");
		auto socket  = new TcpSocket();
		connect(socket, ip, port);

		import log;
		logInfo("Listening on port ", port);
		ubyte[1024 * 8] buffer;
		while(false) // <- Gotta fix this!
		{
			//uint received = cast(uint)socket.receive(buffer[0 .. 2]);
			//
			//import util.bitmanip;
			//auto buf = buffer[0 .. received];
			//auto numItems = buf.read!ushort;
			//received	= cast(uint)socket.receive(buffer[0 .. 2]); 
			//
			//logInfo("received ", numItems, " items");
			//
			//foreach(i; 0 .. numItems)
			//{
			//    received = cast(uint)socket.receive(buffer);
			//    auto name   = buffer.read!string;
			//    auto length = buffer.read!uint;
			//}
			//

			//auto array = Mallocator.it.allocate!(char[])(i);
			//array[0 .. i] = cast(char[])buffer[0 .. i];
			//doTaskOnMain!performReload(cast(string)array, loader);
		}
	}

	void performReload(string id, AsyncContentLoader* loader)
	{
		import std.path, std.conv, util.hash;
		auto path = id[0 .. $ - id.extension.length];
		loader.reload(HashID(path.to!uint));
		Mallocator.it.deallocate(cast(void[])id);
	}
}