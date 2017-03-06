#!/usr/bin/env bash
# 1. script should be bourne shell (.sh)
# 2. file must be executable-text type in perforce (-t text+x)
# 3. makefile passes in build directory as argument to the script
# 4. $1 is the variable for build dir - all generated files go there
# 5. script can validate itself and issue exit code 1 to fail 
# 6. ok for primary script to call secondary scripts as long as
#    the other scripts follow above guidelines
echo "generating files for EN java help system"
echo "path = " $1
rm -fr JavaHelpSearch

# create new JavaHelpSearch
JAVAHELP_ROOT=../../../ext/jh2.0/javahelp/bin
${JAVAHELP_ROOT}/jhindexer pages

# check the integrity of the database
#${JAVAHELP_ROOT}/jhsearch JavaHelpSearch
exit 0


