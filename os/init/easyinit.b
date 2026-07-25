implement Init;
#
# easyinit — first-boot friendly standalone init for newcomers.
#
# No remote file server. No bootp requirement. Just devices, a shell,
# and a short map of how Inferno talks on the network.
#

include "sys.m";
	sys: Sys;
	print, bind, open, fildes: import sys;

include "draw.m";
	draw: Draw;
	Context: import draw;

include "keyring.m";
	kr: Keyring;

Init: module
{
	init:	fn();
};

Shell: module
{
	init:	fn(ctxt: ref Context, argv: list of string);
};

init()
{
	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;

	banner();

	print("Setting up a local name space...\n");

	sys->unmount(nil, "/dev");
	bind("#p", "/prog", sys->MREPL);		# processes
	sys->bind("#d", "/fd", Sys->MREPL);		# file descriptors
	bind("#c", "/dev", sys->MBEFORE);		# console
	bind("#e", "/env", sys->MREPL|sys->MCREATE);	# environment
	bind("#m", "/dev", sys->MAFTER);		# mouse (if present)
	bind("#t", "/dev", sys->MAFTER);		# serial

	# Network stack is optional — useful when you are ready.
	if(bind("#l", "/net", sys->MREPL) >= 0){
		bind("#I", "/net", sys->MAFTER);
		print("Network devices ready under /net\n");
	}else
		print("No ethernet yet — console-only mode is fine\n");

	setsysname("inferno");

	mouse := load Shell "/dis/mouse.dis";
	if(mouse != nil){
		print("Pointer device...\n");
		mouse->init(nil, "/dis/mouse.dis" :: nil);
		mouse = nil;
	}

	ramfile := load Shell "/dis/ramfile.dis";
	if(ramfile != nil){
		ramfile->init(nil, "/dis/ramfile.dis" :: "/services/dns/db" :: "" :: nil);
		ramfile = nil;
	}

	hints();

	shell := load Shell "/dis/sh.dis";
	if(shell == nil){
		print("init: load /dis/sh.dis: %r\n");
		exit;
	}
	print("Starting shell.  Type `ls' or `bind -a '#c' /dev'.\n\n");
	shell->init(nil, "/dis/sh.dis" :: nil);
	print("shell exited\n");
}

banner()
{
	print("\n");
	print("  ========================================\n");
	print("   Inferno OS — welcome\n");
	print("  ========================================\n");
	print("\n");
	print("  You are in standalone mode.\n");
	print("  Everything you need for a first look is\n");
	print("  already inside this kernel's root.\n");
	print("\n");
}

hints()
{
	print("\n");
	print("  Quick map (learn these once):\n");
	print("    8080  loco   — local services on this machine\n");
	print("    9090  grid   — shared / distributed services\n");
	print("\n");
	print("  Address roles:\n");
	print("    127.0.0.0/8     self   — stay inside this host\n");
	print("    0.0.0.0         host   — accept from all guests\n");
	print("    255.255.255.255 guest  — speak to all hosts\n");
	print("\n");
	print("  Ports are like sensor↔motor pairs: one side listens,\n");
	print("  the other side acts. Same idea as bind/mount in Inferno.\n");
	print("\n");
	print("  Docs: docs/GETTING_STARTED.md  docs/NETWORK_PORTS.md\n");
	print("\n");
}

setsysname(name: string)
{
	fd := open("/dev/sysname", sys->OWRITE);
	if(fd == nil)
		return;
	buf := array of byte name;
	sys->write(fd, buf, len buf);
}
