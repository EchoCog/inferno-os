implement Init;
#
# easyinit — first-boot friendly standalone init for newcomers.
#
# Lead with the local name space (devices/processes as files).
# Distributed / grid comes later — same tree, bigger world.
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
	bind("#p", "/prog", sys->MREPL);		# processes as directories
	sys->bind("#d", "/fd", Sys->MREPL);		# file descriptors
	bind("#c", "/dev", sys->MBEFORE);		# console device files
	bind("#e", "/env", sys->MREPL|sys->MCREATE);	# environment as files
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

	nstour();
	hints();

	shell := load Shell "/dis/sh.dis";
	if(shell == nil){
		print("init: load /dis/sh.dis: %r\n");
		exit;
	}
	print("Starting shell.  Try:  ls /dev    ls /prog    cat /dev/sysname\n\n");
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
	print("  Standalone mode: your machine is a file tree.\n");
	print("  Devices and processes live in the name space —\n");
	print("  like an IDE where CPU/GPU were just files.\n");
	print("\n");
}

nstour()
{
	print("  Local name space (learn this first):\n");
	print("    /dev     devices — sensors & motors as files\n");
	print("    /prog    processes — each PID is a directory\n");
	print("    /net     network interfaces & protocols\n");
	print("    /chan    local IPC channels\n");
	print("    /dis     programs you can run\n");
	print("    /n       mount points for *other* trees (later)\n");
	print("\n");
}

hints()
{
	print("  When you are ready for the wider world:\n");
	print("    8080  loco   — local services on this machine\n");
	print("    9090  grid   — shared / distributed services\n");
	print("\n");
	print("  Address roles:\n");
	print("    127.0.0.0/8     self   — stay inside this host\n");
	print("    0.0.0.0         host   — accept from all guests\n");
	print("    255.255.255.255 guest  — speak to all hosts\n");
	print("\n");
	print("  Host ports stay closed until you ask (peerbot).\n");
	print("  Docs: docs/NAMESPACE.md  docs/PEERBOT.md\n");
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
