implement Myspace;

#
# myspace — friendly local name-space tour for newcomers.
#
# Distributed Inferno can wait. First, see this machine as a file tree:
# devices, processes, and network endpoints as paths you can ls/cat.
#

include "sys.m";
	sys: Sys;

include "draw.m";

Myspace: module
{
	init:	fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	argv = tl argv;

	verbose := 0;
	for(; argv != nil; argv = tl argv){
		case hd argv {
		"-v" or "--verbose" =>
			verbose = 1;
		"-h" or "--help" =>
			usage();
			return;
		* =>
			sys->fprint(sys->fildes(2), "myspace: unknown option %s\n", hd argv);
			usage();
			raise "fail:usage";
		}
	}

	sys->print("\n");
	sys->print("  Your machine is a file tree\n");
	sys->print("  ===========================\n");
	sys->print("\n");
	sys->print("  Inferno puts devices, processes, and networks in a\n");
	sys->print("  name space — like an IDE sidebar where CPU/GPU were\n");
	sys->print("  just files. Learn this locally before 'distributed'.\n");
	sys->print("\n");

	show("/", "root of your name space");
	show("/dev", "devices (console, pointers, …) — sensors & motors");
	show("/prog", "processes — each PID is a directory of files");
	show("/net", "network stacks & interfaces as files");
	show("/chan", "channels for local IPC");
	show("/env", "environment variables as files");
	show("/dis", "programs you can run (Dis modules)");
	show("/n", "mount points for *other* trees (grid comes later)");

	sys->print("  Try:\n");
	sys->print("    ls /dev\n");
	sys->print("    ls /prog\n");
	sys->print("    cat /dev/sysname\n");
	sys->print("\n");
	sys->print("  Ports to remember later (not required yet):\n");
	sys->print("    8080  loco  — local services on this machine\n");
	sys->print("    9090  grid  — shared / distributed services\n");
	sys->print("\n");
	sys->print("  Doc: docs/NAMESPACE.md\n");
	sys->print("\n");

	if(verbose){
		sys->print("  Verbose peek:\n");
		peek("/dev");
		peek("/prog");
		peek("/net");
		sys->print("\n");
	}
}

usage()
{
	sys->print("usage: myspace [-v]\n");
	sys->print("  -v  list a few names under /dev /prog /net\n");
}

show(path: string, note: string)
{
	(ok, dir) := sys->stat(path);
	mark := " ";
	if(ok >= 0)
		mark = "+";
	else
		mark = "·";
	sys->print("  %s %-8s  %s\n", mark, path, note);
}

peek(path: string)
{
	fd := sys->open(path, Sys->OREAD);
	if(fd == nil){
		sys->print("    %s: (not available: %r)\n", path);
		return;
	}
	sys->print("    %s:\n", path);
	shown := 0;
	for(;;){
		(nr, d) := sys->dirread(fd);
		if(nr <= 0)
			break;
		for(i := 0; i < nr && shown < 8; i++){
			sys->print("      %s\n", d[i].name);
			shown++;
		}
		if(shown >= 8){
			sys->print("      ...\n");
			break;
		}
	}
}
