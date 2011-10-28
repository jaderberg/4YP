#!/usr/bin/env python
import commands
pids = [line.split()[1] for line in commands.getoutput("ps aux").split("\n") if "open_wormhole" in line]
for pid in pids:
    print "killing %s"%pid
    commands.getoutput("kill %s"%pid)
