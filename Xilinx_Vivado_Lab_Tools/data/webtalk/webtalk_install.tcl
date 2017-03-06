#!/bin/sh
# This is a tcl script to be used by the installer with planAhead
# to either enable or disable Webtalk.
# Usage: webtalk_install [off|on]

if {$argc == 0} {
    set arg1 off
} else {
    set arg1 [lindex $argv 0]
}

if {[string compare $arg1 "on"] == 0} {
    puts "Will enable webtalk...\n"
    config_webtalk -install on -user on
} else {
    puts "Will disable webtalk...\n"
    config_webtalk -install off -user off
}
config_webtalk -info

exit
