implement WmWelcome;

#
# welcome — first-run window for Express (hosted emu + wm).
#
# Teaching order: tree → bind → loco → grid.
# Fonts / Acme stay out of the first screen on purpose.
#

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;

include "tk.m";
	tk: Tk;

include "tkclient.m";
	tkclient: Tkclient;

WmWelcome: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

Shell: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

tkcfg := array[] of {
	"frame .f",
	"label .ico -bitmap @/icons/inferno.bit",
	"label .t -text {Welcome to Inferno} -font /fonts/pelm/ascii.12.font",
	"label .l1 -anchor w -justify left -text {Your machine is a file tree.}",
	"label .l2 -anchor w -justify left -text {Devices and processes live as paths - like an IDE}",
	"label .l3 -anchor w -justify left -text {sidebar where CPU/GPU were just files.}",
	"label .gap1 -text {}",
	"label .l4 -anchor w -justify left -text {Start here (Shell menu, then type):}",
	"label .l5 -anchor w -justify left -text {    myspace     guided tour of /dev /prog /net}",
	"label .l6 -anchor w -justify left -text {    ls /dev     sensors and motors as files}",
	"label .gap2 -text {}",
	"label .l7 -anchor w -justify left -text {Later (not required yet):}",
	"label .l8 -anchor w -justify left -text {    8080  loco   local services on this machine}",
	"label .l9 -anchor w -justify left -text {    9090  grid   shared / distributed services}",
	"label .gap3 -text {}",
	"label .l10 -anchor w -justify left -text {Host ports stay closed until you ask (peerbot).}",
	"frame .btns",
	"button .ok -text {Continue} -command {send cmd ok}",
	"button .shell -text {Open Shell} -command {send cmd shell}",
	"pack .ok .shell -in .btns -side left -padx 8 -pady 4",
	"pack .ico .t -in .f -pady 2",
	"pack .l1 .l2 .l3 .gap1 .l4 .l5 .l6 .gap2 .l7 .l8 .l9 .gap3 .l10 -in .f -anchor w -padx 8",
	"pack .btns -in .f -pady 8",
	"pack .f -padx 6 -pady 4",
	"pack propagate . 0",
	"update",
};

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	if (ctxt == nil) {
		# Console fallback (bootable / shell-only).
		sys->print("\n");
		sys->print("  Welcome to Inferno\n");
		sys->print("  ==================\n");
		sys->print("\n");
		sys->print("  Your machine is a file tree.\n");
		sys->print("  Try:  myspace    ls /dev    cat /dev/sysname\n");
		sys->print("  Later: 8080 loco / 9090 grid  (peerbot keeps ports closed)\n");
		sys->print("\n");
		return;
	}

	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tkclient = load Tkclient Tkclient->PATH;

	sys->pctl(Sys->NEWPGRP, nil);
	tkclient->init();
	(t, menubut) := tkclient->toplevel(ctxt, "", "Welcome", 0);

	cmdc := chan of string;
	tk->namechan(t, cmdc, "cmd");

	for (i := 0; i < len tkcfg; i++)
		tk->cmd(t, tkcfg[i]);

	e := tk->cmd(t, "variable lasterror");
	if (e != "")
		tk->cmd(t, ".t configure -font *default*; variable lasterror {}");

	tkclient->onscreen(t, nil);
	tkclient->startinput(t, "kbd" :: "ptr" :: nil);

	for (;;) {
		alt {
		s := <-t.ctxt.kbd =>
			tk->keyboard(t, s);
		s := <-t.ctxt.ptr =>
			tk->pointer(t, *s);
		s := <-t.ctxt.ctl or
		s = <-t.wreq or
		s = <-menubut =>
			if (s == "exit")
				return;
			tkclient->wmctl(t, s);
		s := <-cmdc =>
			case s {
			"ok" =>
				return;
			"shell" =>
				openshell(ctxt);
				return;
			}
		}
	}
}

openshell(ctxt: ref Draw->Context)
{
	sh := load Shell "/dis/wm/sh.dis";
	if (sh == nil) {
		sys->fprint(sys->fildes(2), "welcome: load /dis/wm/sh.dis: %r\n");
		return;
	}
	spawn sh->init(ctxt, "/dis/wm/sh.dis" :: nil);
}
