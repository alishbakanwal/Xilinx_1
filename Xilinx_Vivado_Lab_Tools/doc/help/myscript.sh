# 1. script should be bourne shell (.sh)
# 2. file must be exectuable-text type in perforce (-t text+x) 
# 3. makefile passes in build directory as argument to the script
# 4. $1 is the variable for build dir - all generated files go there
# 5. script can validate itself and issue exit code 1 to fail 
# 6. ok for primary script to call secondary scripts as long as
#    the other scripts follow above guidelines
echo *** generating files for java help system
touch $1/testfile1
touch $1/testfile2
touch $1/testfile3
touch $1/testfile4
echo "Xilinx" >> $1/testfile1
echo "is the" >> $1/testfile2
echo "inter-galactic" >> $1/testfile3
echo "FPGA leader!" >> $1/testfile4
exit 0


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
