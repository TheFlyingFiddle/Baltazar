module broadcaster;
import std.socket;
import std.concurrency;
import compilers;
import util.hash;
import log;
import network.service;
import network.util;
import core.atomic;
import std.conv;
import std.datetime;
import allocation;

shared int reloaderCount = 0;

enum fileService = "FILE_RELOADING_SERVICE";

struct ReloadItem
{
	string name;
	void[] data;
}

struct ReloadingInfo
{
	ReloadItem[] items;
}

Tid reloadServiceTid;
void reloadChanged(CompiledItem[] items, HashID hash)
{
	auto count = atomicLoad(reloaderCount);
	if(count > 0)
	{
		logInfo("sending reloading info");

		ReloadItem[] copy = new ReloadItem[items.length];
		foreach(i, ref item; copy) {
			item.data	   = items[i].data.dup;
			item.name = to!string(hash.value) ~ items[i].extension; 
		}

		ReloadingInfo info;
		info.items = copy;
		send(reloadServiceTid, cast(immutable ReloadingInfo)info);
	}
	else 
	{
		import log;
		logInfo("No reloaders not sending reloaded notifications.");
	}
}


void spawnReloadingService()
{
	reloadServiceTid = spawn(&reloadingService);
}

private void reloadingService()
{
	NetworkServices services = NetworkServices(Mallocator.it, 23451, 1);
	Socket listener = new TcpSocket();
	listener.bind(new InternetAddress(localIPString, 0));
	listener.listen(1);
	listener.blocking = false;

	struct ReloadingData
	{
		uint ip;
		ushort port;
	}

	auto addr = cast(InternetAddress)listener.localAddress;
	ReloadingData data = ReloadingData(addr.addr, addr.port);
	services.add(fileService, data);


	__gshared Tid[] reloaders;
	bool done = false;
	while(!done)
	{
		services.poll();
		
		while(true)
		{
			auto socket = listener.accept();
			if(!socket.isAlive())
			{
				break;
			}
			
			socket.blocking = true;
			reloaders ~= spawn(&reloader, cast(immutable Socket)socket);
		}

		auto received = receiveTimeout(100.msecs, 
		(immutable ReloadingInfo info) 
		{
			foreach(tid; reloaders)
			{
				send(tid, info);
			}
		},
		(bool shutdown)
		{
			done = true;
			foreach(tid; reloaders)
			{
				send(tid, true);
			}
		});
	}
}

bool sendItems(immutable ReloadingInfo info, Socket socket)
{
	logInfo("Attempting to send files: ", info.items.length);

	import util.bitmanip;
	ubyte[128] buffer;

	buffer[].write!ushort(cast(ushort)info.items.length, 0);
	int err = socket.send(buffer[0 .. 2]);
	if(err == Socket.ERROR) return false; 


	foreach(item; info.items)
	{	
		size_t offset = 0;
		buffer[].write!string(item.name, &offset);
		buffer[].write!uint(item.data.length, &offset);
		
		err = socket.send(buffer[0 .. offset]);	
		if(err == Socket.ERROR) return false; 
		err = socket.send(item.data);	
		if(err == Socket.ERROR) return false; 
	}

	return true;
}

void reloader(immutable Socket im_socket)
{
	auto socket = cast(Socket)im_socket; 
	try
	{
		atomicOp!"+="(reloaderCount, 1);
		logInfo("Started reloading for connection: ", socket.remoteAddress);

		bool done = false;
		while(!done)
		{
			receive((immutable ReloadingInfo info) 
			{
				logInfo("Reloader received info sending to client ", socket.remoteAddress);
				done = !sendItems(info, socket);
				if(done) 
					logErr("Failed to send item to connection: ", socket.remoteAddress);
				else 
					logInfo("Sent files to connection: ", socket.remoteAddress);
			},
			(bool shutdown)
			{
				done = true;
			});
		}
	} 
	catch(Throwable t)
	{
		logErr("Reloading thread failed! ", t);
	}
	finally
	{
		atomicOp!"-="(reloaderCount, 1);
	}

	logInfo("Stoped reloading for connection: ", socket.remoteAddress);
}