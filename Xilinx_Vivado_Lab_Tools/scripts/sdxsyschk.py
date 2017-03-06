#!/usr/bin/env python

#############################################################################
#
#  SDAccel utility script for analysing and helping troubleshoot current Xilinx PCIe platform status
#
#  Requirements:
#       1)  MUST use python version 2.7.5 and above to run this script
#       2)  MUST have lspci package installed either under /sbin or /usr/bin directory
#       3)  MUST have the lspci paths added to user's environment variable: "PATH"
#  
#  Usage:
#
#  1. To query system and Xilinx PCIe hardware statistic status
#
#      sudo python ./sdxsyschk.py
#
#  2. To query status and redirect the output to a text file specified with argument
#
#      sudo python ./sdxsyschk.py > <path_and_file_name>
#
#  3. To query basic system status plus environment variables info
#		(MUST be run WITHOUT sudo access)
#
#      python ./sdxsyschk.py -e
#
#############################################################################

from __future__ import print_function
import os
import subprocess
import sys
import datetime
import socket
import argparse
import traceback
import re
import random

## Initial Level Version Check ##
b"ERROR: Python version below the 2.7.5 requirement!"

ARGS = {"DEBUG":False,
        "VERBOSE":False,
        "ENV":False,
        "FILE_NAME":None}

RH_SUPPORT_VER = {
    "6.5": "OK",
    "6.6": "OK",
}

UBT_SUPPORT_VER = {
    "15.04": "OK",
    "15.10": "OK",
}

ENV_TO_CHECK = [
    "XILINX_OPENCL",
    "XILINX_SDACCEL",
    "XCL_EMULATION_CONFIGFILE",
    "LD_LIBRARY_PATH"
];

SPEED_TYPES = {
    "2.5": "PCIe Gen1(2.5 GT/s)",
    "5": "PCIe Gen2(5 GT/s)",
    "8": "PCIe Gen3(8 GT/s)",
    "16": "PCIe Gen4(16 GT/s)",
}

## Per 2016.1 SDA release criteria
LATEST_DRIVER_TYPES = {
    "7138": "Xilinx XCLDMA",
    "8138": "Xilinx XCLDMA",
    "8238": "Xilinx XCLDMA",
}

LATEST_UC_DEVS = {
    "8138": "OK",
    "8238": "OK",
}

DDR_DEV_RANGE = {
    "7038": "8",
    "8038": "8",
    "7138": "8",
    "8138": "8",
    "8238": "4",
}

LATEST_DSA_TYPES = {
    # 2015.4
    "71380121": "xilinx:adm-pcie-7v3:1ddr:2.1",
    "71380221": "xilinx:adm-pcie-7v3:2ddr:2.1",
    "81380121": "xilinx:adm-pcie-ku3:1ddr:2.1",
    "81380221": "xilinx:adm-pcie-ku3:2ddr:2.1",
    "81388221": "xilinx:adm-pcie-ku3:tandem-2ddr:2.1",
    "81384221": "xilinx:adm-pcie-ku3:exp-pr-2ddr:2.1",
    # 2016.1
    "71380130": "xilinx:adm-pcie-7v3:1ddr:3.0",
    "81380130": "xilinx:adm-pcie-ku3:1ddr:3.0",
    "81380230": "xilinx:adm-pcie-ku3:2ddr:3.0",
    "81384230": "xilinx:adm-pcie-ku3:2ddr-xpr:3.0",
    "82380230": "xilinx:tul-pcie3-ku115:2ddr:3.0",
    "82384430": "xilinx:tul-pcie3-ku115:4ddr-xpr:3.0",
}

LEGACY_DRIVER_TYPES = {
    "7038": "Xilinx XDMA",
    "8038": "Xilinx XDMA",
}

LEGACY_DSA_TYPES = {
    "70380010": "xilinx:adm-pcie-7v3:1ddr:2.0",
    "70380020": "xilinx:adm-pcie-7v3:1ddr:2.0",
    "70380220": "xilinx:adm-pcie-7v3:2ddr:2.0",
    "70380120": "xilinx:adm-pcie-7v3:1ddr:2.0",
    "70381120": "xilinx:adm-pcie-7v3:1ddr-1eth:2.0",
    "70380121": "xilinx:adm-pcie-7v3:1ddr:2.1",
    "80380010": "xilinx:adm-pcie-ku3:1ddr:2.0",
    "80380020": "xilinx:adm-pcie-ku3:1ddr:2.0",
    "80380220": "xilinx:adm-pcie-ku3:2ddr:2.0",
    "80380120": "xilinx:adm-pcie-ku3:1ddr:2.0",
    "80380121": "xilinx:adm-pcie-ku3:1ddr:2.1",
}

# Default ID to Xilinx
MFG_ID = "10ee"

devCount = 0
pcieException = False
drvFoundList = []
devIDList = []
subSysIDList = []
rootResult = subprocess.check_output(["whoami"])
endline = rootResult.find('\n')
user = rootResult[:endline]

#############################################################################
def dumpArgs():
    print ("PROGRAM COMMAND LINE ARGUMENT DUMP:")
    for arg in ARGS.keys():
        print ("    ", arg, '=', ARGS[arg])

#############################################################################
def printHeader():
    try:
        print ("\nCopyright 1986-2016 Xilinx, Inc. All Rights Reserved.")
        print ("---------------------------------------------------------------------")
        print ("| Tool Version\t:", "SDAccel System Information Checker V2016.2")
        print ("| Date\t:", datetime.date.today())
        print ("| Time\t:", datetime.datetime.now().time())
        print ("| Host Name\t:", socket.gethostname())
        print ("---------------------------------------------------------------------")
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def printTable():
    try:
        print ("\nTable of Contents")
        print ("--------------------------------------------")
        print ("1. System and Environment Diagnosis")
        # print ("Python Version Check")
        print ("1.1 Linux OS System Check")
        print ("1.2 64-bit Architecture Check")
        print ("1.3 Environment Variables Check")
        print ("1.4 Motherboard System Info")
        print ("\n2. PCIe Diagnosis")
        print ("2.1 Xilinx PCIe Device Check")
        print ("2.2 Device Link Speed Check")
        print ("2.3 Root Port Speed Check")
        print ("2.4 Xilinx Kernel Driver Check")
        print ("2.5 Xilinx DSA-Device Matching Check")
        print ("\n3. Memory Functions (DMA) Testing")
        print ("3.1 DMA Channel Check")
        print ("3.2 Zero Data Pattern Transfer Test")
        print ("3.3 Random Data Transfer Test")
        print ("3.4 Memory Interface (MIG) Range Test")
        print ("\n4. Summary\n")
    except:
        e = sys.exc_info()[1]
        print (e)
        
#############################################################################
def printSummary(entries, sep=True):
    try:
        widths = []
        for line in entries:
            for i, size in enumerate([len(x) for x in line]):
                while i >= len(widths):
                    widths.append(0)
                if size > widths[i]:
                    widths[i] = size

        print_string = ""
        for i, width in enumerate(widths):
            print_string += "{" + str(i) + ":" + str(width) + "} | "
        if (len(print_string) == 0):
            return

        print_string = print_string[:-3]

        for i, line in enumerate(entries):
            print(print_string.format(*line))
            if (i == 0 and sep):
                print("-"*(sum(widths)+3*(len(widths)-1)))

    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def checkPath(cName):
    try:
        found = False
        result = os.environ.get("PATH")
        result = ':' + result + ':'
        if ( os.path.exists("/sbin/" + cName) ):
            if (result.find(":/sbin:") != -1):
                found = True
        elif ( os.path.exists("/usr/bin/" + cName) ):
            if (result.find(":/usr/bin:") != -1):
                found = True
        return found
    except:
        e = sys.exc_info()[1]
        print (e)	
        
#############################################################################
def isModBusy(modInput, starti):
    try:
        endi = modInput.find('\n', starti)
        modStat = modInput[starti:endi]
        result = modStat.split()
        useCount = result[2]
        # print ("Used by count check :", useCount)
        if ( int(useCount) > 0 ):
            return True
        else:
            return False
    except:
        e = sys.exc_info()[1]
        print (e)
		
#############################################################################
def getPython():
    try:
        # print ("Python Version Check")
        print ("----------------------------------")
        print ("Checking Python environment...")
        req_ver = (2,7,5)
        cur_ver = sys.version_info
        result = sys.version
        print ("Version", result)
        if cur_ver < req_ver:
            print ("\nWARNING: Below the required 2.7.5 version.")
            return "WARNING"
        else:
            return "PASS"
    except:
        e = sys.exc_info()[1]
        print (e)
		
#############################################################################
def getOS():
    try:
        print ("\n1.1 Linux OS System Check")
        print ("----------------------------------")
        result = subprocess.check_output(["lsb_release", "-a"])
        print ("\nYour Linux System info is:\n", result, sep='')
        
        ## OS version check
        releaseInfo = subprocess.check_output(["lsb_release", "-r"])
        starti = 9
        endi = releaseInfo.find('\n', starti)
        if result.find("RedHat") != -1:
            redhatVer = releaseInfo[starti:endi]
            isVerSupported = RH_SUPPORT_VER.get(redhatVer)
            if (isVerSupported is None):
                print ("WARNING: Your version of Red Hat distribution is not officially supported!")
                return "WARNING"
            else:
                print ("PASS: OS version check okay.")
                return "PASS"
        elif result.find("Ubuntu") != -1:
            ubtVer = releaseInfo[starti:endi]
            isVerSupported = UBT_SUPPORT_VER.get(ubtVer)
            if (isVerSupported is None):
                print ("WARNING: Your version of Ubuntu is not officially supported!")
                return "WARNING"
            else:
                cpuType = subprocess.check_output(["uname", "-p"])
                if ( cpuType != "ppc64" and cpuType != "ppc64le"):
                	print ("WARNING: Your system which is not running on IBM Power8 is not officially supported!")
                	return "WARNING"
                else:
                	print ("PASS: OS version check okay.")
                	return "PASS"
        else:
            print ("WARNING: Your type of Linux OS is not officially supported!")
            return "WARNING"
    except:
        e = sys.exc_info()[1]
        print (e)
		
#############################################################################
def getArch():
    try:
        print ("\n1.2 64-bit Architecture Check")
        print ("----------------------------------")
        result = subprocess.check_output(["uname", "-p"])
        print ("\nThe architecture of your system processor is:\n", result)
        
        ## 64-bit arch check
        if result.find("64") != -1:
            print ("PASS: 64-bit system requirement check okay.")
            return "PASS"
        else:
            print ("ERROR: Non 64-bit architecture system detected. NOT supported officially by Xilinx SDAccel!")
            return "ERROR"
    except:
        e = sys.exc_info()[1]
        print (e)
		
#############################################################################
def printEnv():
    try:
        print ("\n1.3 Environment Variables Check")
        print ("----------------------------------")

        ## Do a root/sudo check first
        if (user != "root"):
            print ("\nThe following are some environment variables that need to be checked, as SDAccel requires them to be set correctly:\n")
            envCount = len(ENV_TO_CHECK)
            i = 0

            while i < envCount:
                result = os.environ.get(ENV_TO_CHECK[i])
                print ('\t', ENV_TO_CHECK[i], ":\t", result)
                i = i + 1
            return "DONE"
        else:
            print ("\nWARNING: '-e' argument to get environment variables CANNOT be run with sudo. Please rerun the script without sudo access.\n")
            return "WARNING"
    except:
        e = sys.exc_info()[1]
        print (e)        

#############################################################################
def getMTBoard():
    try:
        print ("\n1.4 Motherboard System Info")
        print ("----------------------------------")

        ## Do a root/sudo check first
        if (user == "root"):
            result = subprocess.check_output(["dmidecode", "-t", "system"])
            starti = result.find("System Information")
            endi = result.find("Serial Number")
            MTBInfo = result[starti:endi-2]
            print ('\n', MTBInfo)
            return "DONE"
        else:
            print ("WARNING: You did not run this utility with root or sudo, motherboard information cannot be queried.")
            print ("Example Usage:  sudo sdxsyschk")
            return "NOT RUN"
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def getDrvVer(drvName):
    try:
        if (user != "root"):
            print ("WARNING: Driver version cannot be queried without root or sudo access.")
        else:
            result = subprocess.check_output(["modinfo", drvName])
            starti = result.find("version:")
            endi = result.find('\n', starti)
            verLine = result[starti:endi]
            result = verLine.split()
            verNum = result[1]
            print ("Driver Version: ", verNum)
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def checkDSABin(devStr, subsysStr):
    try:
        result = "WARNING"
        binName = MFG_ID+"-"+devStr+"-"+subsysStr+"-0000000000000000.dsabin"
        if (os.path.isfile("/lib/firmware/xilinx/"+binName)):
            result = "PASS"
            print ("PASS: The DSA binary is correctly installed and being detected as: ", binName)
        else:
            print ("WARNING: The DSA binary cannot be found. Please re-install the firmware files after building your design archive.")
        return result
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def getLinkCap(result):
    try:
        starti = result.find("LnkCap:")
        endi = result.find("LnkCtl:")
        lnkcap = result[starti:endi]
        starti = lnkcap.find("Speed")
        lnkcap = lnkcap[starti:]
        endi = lnkcap.find("GT")
        speed = lnkcap[6:endi]
        genCap = SPEED_TYPES.get(speed)
        starti = lnkcap.find("Width x")
        lnkcap = lnkcap[starti:]
        endi = lnkcap.find(",")
        laneNum = lnkcap[7:endi]
        print ("The link capability is:  ", genCap, "with", laneNum, "lanes")
        return genCap
    except:
        e = sys.exc_info()[1]
        print (e)		

#############################################################################
def getLinkStat(result):
    try:
        starti = result.find("LnkSta:")
        endi = result.find("TrErr")
        lnkstat = result[starti:endi]
        starti = lnkstat.find("Speed")
        lnkstat = lnkstat[starti:]
        endi = lnkstat.find("GT")
        speed = lnkstat[6:endi]
        genStat = SPEED_TYPES.get(speed)
        starti = lnkstat.find("Width x")
        starti = starti + 7
        endi = lnkstat.rfind(",")
        laneNum = lnkstat[starti:endi]
        print ("The link status is:  ", genStat, "with", laneNum, "lanes")
        return genStat
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def getPCI():
    try:
        print ("\n2.1 Xilinx PCIe Device Check")
        print ("----------------------------------")
        print ("\nProcessing PCIe info...\n")
        
        global devCount
        global pcieException
        global drvFoundList
        global devIDList
        global subSysIDList
        resultBag = []
        result = subprocess.check_output(["lspci", "-d", MFG_ID+":"])
        devCount = result.count("\n")
        if devCount != 0:
            devAddr = ""
            devAddrList = []
            devResultList = []
            resultBag.append(("2.1 Xilinx PCIe Device Check","PASS"))
            print ("PASS: Found Xilinx PCIe device(s):")
            
            devIndex = 0
            for line in result.splitlines():
                devAddr = line[:7]
                devAddrList.append(devAddr)
                print ("\nDevice", devIndex, '-')
                print (line)
                devIndex = devIndex + 1

            devIndex = 0
            ## Store detailed PCIe devices info first
            while devIndex < devCount:
                devAddr = devAddrList[devIndex]
                result = subprocess.check_output(["lspci", "-s", devAddr, "-vv"])
                devResultList.append(result)
                devIndex = devIndex + 1
            
            ## Do a root/sudo check
            if (user != "root"):
                print ("\n2.2 Device Link Speed Check")
                print ("----------------------------------")
                print ("WARNING: You did not run this utility with root or sudo, PCIe link status analysis cannot continue.")
                print ("Example Usage:  sudo sdxsyschk")
                resultBag.append(("2.2 Device Link Speed Check","NOT RUN"))
                print ("\n2.3 Root Port Speed Check")
                print ("----------------------------------")
                print ("WARNING: Needs root or sudo access to run.")
                resultBag.append(("2.3 Root Port Speed Check","NOT RUN"))
            else:
                devCapList = []
                devStatList = []
                
                ## Link Speed
                devIndex = 0
                while devIndex < devCount:
                    print ("\n2.2.", devIndex+1, " Device Link Speed Check - Device ", devIndex, sep='')
                    print ("--------------------------------------------")
                    devAddr = devAddrList[devIndex]
                    result = devResultList[devIndex]
                    print ("\nDevice", devIndex, '-')
                    
                    devCap = getLinkCap(result)
                    devCapList.append(devCap)
                    devStat = getLinkStat(result)
                    devStatList.append(devStat)

                    if devStat is None:
                        print ("\nERROR: Your card's running transfer rate cannot be detected!")
                        resultBag.append(("2.2."+str(devIndex+1)+" Device Link Speed Check - Device "+str(devIndex),"ERROR"))
                        pcieException = True
                    elif devStat == devCap:
                        print ("\nPASS: Your card's running transfer rate matches its capabilities.")
                        resultBag.append(("2.2."+str(devIndex+1)+" Device Link Speed Check - Device "+str(devIndex),"PASS"))
                    else:
                        print ("\nWARNING: Your card's running transfer rate does NOT match its capabilities!")
                        print ("Please see root port analysis. For optimal performance, consider installing the card in a PCIe slot that matches: ", devCap)
                        resultBag.append(("2.2."+str(devIndex+1)+" Device Link Speed Check - Device "+str(devIndex),"WARNING"))
                    
                    devIndex = devIndex + 1
                    
                ## Root Port Speed
                devIndex = 0
                while devIndex < devCount:
                    if devStatList[devIndex] != None:
                        print ("\n2.3.", devIndex+1, " Root Port Speed Check - Device ", devIndex, sep='')
                        print ("--------------------------------------------")
                        print ("\nRoot Port speed analysis on Device", devIndex, '-')
                        
                        devAddr = devAddrList[devIndex]
                        rootBusNum = devAddr[:1] + "0"
                        treeView = subprocess.check_output(["lspci", "-s", rootBusNum+":", "-tvv"])
                        devBusNum = devAddr[:2]
                        endi = treeView.find("-["+devBusNum+"]")
                        if endi != -1:
                            rootSlotNum = treeView[endi-4:endi]
                            rootAddr = rootBusNum + ":" + rootSlotNum
                            rootResult = subprocess.check_output(["lspci", "-s", rootAddr, "-vv"])
                            rootStat = getLinkStat(rootResult)
                            rootCap = getLinkCap(rootResult)

                            if rootStat == devStatList[devIndex]:
                                print ("\nPASS: Your card's running transfer rate matches its root port's running link status rate.")
                                resultBag.append(("2.3."+str(devIndex+1)+" Root Port Speed Check - Device "+str(devIndex),"PASS"))
                            else:
                                print ("\nERROR: Your card's running transfer rate does NOT match its root port's running link status rate!")
                                print ("Please try installing the card in another available PCIe slot that matches: ", devCapList[devIndex])
                                resultBag.append(("2.3."+str(devIndex+1)+" Root Port Speed Check - Device "+str(devIndex),"ERROR"))
                                pcieException = True
                        else:
                            print ("\nWARNING: The card appears to be connected through PCIe switches/bridges, thus further analysis cannot be run effectively.")
                            print ("This does not mean the connection is faulty. If you are experiencing difficulties or performance issue when running applications, please contact hardware system support.")
                            resultBag.append(("2.3."+str(devIndex+1)+" Root Port Speed Check - Device "+str(devIndex),"WARNING"))

                    devIndex = devIndex + 1
                    
            ## Kernel Driver & DSA
            drvExpList = []
            devIndex = 0
            while devIndex < devCount:
                result = devResultList[devIndex]
                endi = result.find('\n')
                starti = endi - 4
                devID = result[starti:endi]
                starti = result.find("Subsystem:")
                endi = result.find('\n', starti)
                starti = endi - 4
                subSysID = result[starti:endi]
                starti = result.find("Kernel driver in use:")
                if (starti == -1):
                    driverFound = "NONE!"
                else:
                    endi = result.find('\n', starti)
                    starti = starti + 22
                    driverFound = result[starti:endi]

                modResult = subprocess.check_output(["lsmod"])

                driverExpected = LATEST_DRIVER_TYPES.get(devID)
                print ("\n2.4.", devIndex+1, " Xilinx Kernel Driver Check - Device ", devIndex, sep='')
                print ("----------------------------------------------")
                print ("\nDevice", devIndex, '-')
                if (driverExpected is None):
                    driverExpected = LEGACY_DRIVER_TYPES.get(devID)
                    if (driverExpected is None):
                        driverExpected = "Unknown"
                        print ("ERROR: The device ID is unrecognizable, Driver and DSA version analysis will not proceed.")
                        print ("* If you are running this test on an officially supported platform by Xilinx SDAccel, please check firmware programming")
                        print ("  and driver installation procedures as specified in UG1020 SDAccel Installation Guide.")
                        print ("* You may also want to try hard rebooting the host machine where the target PCIe card resides.")
                        resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"ERROR"))
                        pcieException = True
                    else:
                        print ("WARNING: The device is configured to be expecting legacy ", driverExpected, "kernel driver, you may need to update it.")
                        if (driverFound == "xdma"):
                            print ("PASS: The device is running on ", driverExpected, "kernel driver")
                            modLoaded = modResult.find(driverFound)
                            if ( modLoaded != -1):
                                print ("PASS: The kernel module is loaded successfully.")
                                if ( isModBusy(modResult,modLoaded) != True ):
                                    resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"PASS"))
                                else:
                                    print ("WARNING: The kernel module is currently being occupied by some process!")
                                    resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"WARNING"))
                                    pcieException = True
                            else:
                                print ("ERROR: The kernel module failed to load. Please re-install the driver.")
                                resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"ERROR"))
                                pcieException = True
                            getDrvVer(driverFound)
                        else:
                            print ("ERROR: The kernel driver detected: ", driverFound, ", does not match the device's expected version. Please re-install the driver.")
                            resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"ERROR"))
                            pcieException = True
                        print ("\n2.5.", devIndex+1, " Xilinx DSA-Device Matching Check - Device ", devIndex, sep='')
                        print ("---------------------------------------------------")
                        print ("\nDevice", devIndex, '-')
                        dsaName = LEGACY_DSA_TYPES.get(devID + subSysID)
                        if (dsaName is None):
                            print ("\nWARNING: Your DSA version is unrecognizable. Contact manufacturer for official DSA support if needed.")
                            resultBag.append(("2.5."+str(devIndex+1)+" Xilinx DSA-Device Matching Check - Device "+str(devIndex),"WARNING"))
                            pcieException = True
                        else:
                            print ("PASS: The DSA version is being detected as: ", dsaName)
                            resultBag.append(("2.5."+str(devIndex+1)+" Xilinx DSA-Device Matching Check - Device "+str(devIndex),"PASS"))
                else:
                    print ("NOTE: The device is expecting ", driverExpected, "driver")
                    if (driverFound == "xcldma"):
                        print ("PASS: The device is running on ", driverExpected, "kernel driver")
                        modLoaded = modResult.find(driverFound)
                        if ( modLoaded != -1):
                            print ("PASS: The kernel module is loaded successfully.")
                            if ( isModBusy(modResult,modLoaded) != True ):
                                resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"PASS"))
                            else:
                                print ("WARNING: The kernel module is currently being occupied by some process!")
                                resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"WARNING"))
                                pcieException = True
                        else:
                            print ("ERROR: The kernel module failed to load. Please re-install the driver.")
                            resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"ERROR"))
                            pcieException = True
                        getDrvVer(driverFound)
                    else:
                        print ("ERROR: The kernel driver detected: ", driverFound, ", does not match the device's expected version. Please re-install the driver.")
                        resultBag.append(("2.4."+str(devIndex+1)+" Xilinx Kernel Driver Check - Device "+str(devIndex),"ERROR"))
                        pcieException = True
                    print ("\n2.5.", devIndex+1, " Xilinx DSA-Device Matching Check - Device ", devIndex, sep='')
                    print ("---------------------------------------------------")
                    print ("\nDevice", devIndex, '-')
                    dsaName = LATEST_DSA_TYPES.get(devID + subSysID)
                    if (dsaName is None):
                        print ("\nWARNING: Your DSA version is unrecognizable. Contact manufacturer for official DSA support if needed.")
                        resultBag.append(("2.5."+str(devIndex+1)+" Xilinx DSA-Device Matching Check - Device "+str(devIndex),"WARNING"))
                        pcieException = True
                    else:
                        print ("PASS: The DSA version is being detected as: ", dsaName)
                        isUCPart = LATEST_UC_DEVS.get(devID)
                        if (isUCPart is None):
                            resultBag.append(("2.5."+str(devIndex+1)+" Xilinx DSA-Device Matching Check - Device "+str(devIndex),"PASS"))
                        else:
                            resultBag.append(("2.5."+str(devIndex+1)+" Xilinx DSA-Device Matching Check - Device "+str(devIndex),checkDSABin(devID,subSysID)))

                drvExpList.append(driverExpected)
                drvFoundList.append(driverFound)
                devIDList.append(devID)
                subSysIDList.append(subSysID)
                devIndex = devIndex + 1

            ## Print if in Verbose mode
            if (ARGS["VERBOSE"] != False):
                devIndex = 0
                while devIndex < devCount:
                    print ("\nHere are verbose lspci results on Device", devIndex)
                    print ("----------------------------------")
                    print (devResultList[devIndex])
                    if (drvExpList[devIndex] != "Unknown"):
                        if (user != "root"):
                            print ("WARNING: Verbose kernel driver info cannot be queried without root or sudo access.")
                        else:
                            result = subprocess.check_output(["modinfo", drvFoundList[devIndex]])
                            print ("\nHere is verbose kernel module info on Device", devIndex, ":\n ", result)
                    else:
                        print ("Kernel driver type is unknown, no verbose info can be given.")
                    devIndex = devIndex + 1
        else:
            print ("ERROR: No Xilinx PCIe card found. Things to check:")
            print ("* Did you plug the card in the host machine you are running this utility?")
            print ("* Did you program the flash on your card as instructed in UG1020 SDAccel Installation Guide?")
            print ("  Xilinx PCIe cards are not preprogrammed with valid firmware for SDAccel. The flash on the card needs to be programmed", "\n  with valid configuration file before the PCIe card can be enumerated by the host machine.")
            print ("* Did you reboot the FPGA and reboot the machine?")
            resultBag.append(("2.1 Xilinx PCIe Device Check","ERROR"))
        return resultBag
    except:
        e = sys.exc_info()[1]
        print (e)

#############################################################################
def testDMA():
    try:
        resultBag = []
        devIndex = 0
        
        if (devCount == 0):
            print ("\n3.1 DMA Channel Check")
            print ("----------------------------------")
            print ("\nPCIe analysis failed to detect any device, DMA analysis will not be performed.\n")
            resultBag.append(("3.1 DMA Channel Check","NOT RUN"))
        elif pcieException == True:
            print ("\n3.1 DMA Channel Check")
            print ("----------------------------------")
            print ("\nException(s) found in above PCIe diagnosis sections, DMA analysis will not be performed.\n")
            resultBag.append(("3.1 DMA Channel Check","NOT RUN"))
        else:
            while devIndex < devCount:
                print ("\n3.1.", devIndex+1, " DMA Channel Check - Device ", devIndex, sep='')
                print ("--------------------------------------------")
                drvName = drvFoundList[devIndex]
                result = subprocess.check_output(["ls", "/dev/"+drvName])
                chCount = result.count("c2h")
                hcCount = result.count("h2c")

                if ( (chCount * hcCount) != 0):
                    print ("Device ", devIndex, " uses ", drvName)
                    print ("Number of card to host channels detected: ", chCount)
                    print ("Number of host to card channels detected: ", hcCount)
                    if (chCount == hcCount):
                        print ("\nPASS: DMA channels are detected.")
                        resultBag.append(("3.1."+str(devIndex+1)+" DMA Channel Check - Device "+str(devIndex),"PASS"))

                        print ("\n3.2.", devIndex+1, " Zero Data Pattern Transfer Test - Device ", devIndex, sep='')
                        print ("--------------------------------------------")
                        if (user == "root"):
                            chnIndex = 0
                            chnFailed = False
                            if (ARGS["VERBOSE"] != True):
                                statarg = " status=none"
                            else:
                                statarg = ""

                            print ("Initializing byte count and block count to the following default values for the transfer...")
                            print ("Byte count = ", "1K")
                            print ("Block count =", "16")
                            print ("Generating golden file with null data pattern...")
                            result = subprocess.check_output("dd"+" if=/dev/zero"+" of=/tmp/goldnull"+" bs=1K"+" count=16"+statarg, shell=True)
                            while chnIndex < chCount:
                                print ("\nTesting channel ", chnIndex)
                                outfile = " of=/dev/"+drvName+"/"+drvName+"0_h2c_"+str(chnIndex)
                                infile = " if=/dev/"+drvName+"/"+drvName+"0_c2h_"+str(chnIndex)
                                print ("Transferring data from host to card...")
                                result = subprocess.check_output("dd"+" if=/dev/zero"+outfile+" bs=1K"+" count=16"+statarg, shell=True)
                                print ("Transferring data from card back to host...")
                                result = subprocess.check_output("dd"+infile+" of=/tmp/outnull"+" bs=1K"+" count=16"+statarg, shell=True)
                                result = subprocess.check_output(["du", "-b", "/tmp/outnull"])
                                fsize = result.split()
                                print ("Verifying the size (bytes) of binary data output... : ", fsize[0])
                                try:
                                    result = subprocess.check_output(["diff", "/tmp/goldnull", "/tmp/outnull"])
                                except subprocess.CalledProcessError as exp:
                                    result = exp.output
                                if (result != ""):
                                    print ("FAIL: Output of binary data from the DMA transfer failed to match expected null value!")
                                    chnFailed = True
                                else:
                                    print ("PASS: Output of binary data from the DMA transfer matches expected null value.")
                                chnIndex = chnIndex + 1

                            if (chnFailed == False):
                                resultBag.append(("3.2."+str(devIndex+1)+" Zero Data Pattern Transfer Test - Device "+str(devIndex),"PASS"))
                            else:
                                resultBag.append(("3.2."+str(devIndex+1)+" Zero Data Pattern Transfer Test - Device "+str(devIndex),"FAIL"))
                            
                            print ("\n3.3.", devIndex+1, " Random Data Transfer Test - Device ", devIndex, sep='')
                            print ("--------------------------------------------")
                            chnIndex = 0
                            chnFailed = False
                            print ("Randomizing byte count and block count used for the transfer...")
                            kbyteCount = random.randint(1,32)
                            blockCount = random.randint(1,64)
                            print ("Byte count = ", kbyteCount, "K", sep='')
                            print ("Block count =", blockCount)
                            print ("\nGenerating golden file with random data...")
                            result = subprocess.check_output("dd"+" if=/dev/urandom"+" of=/tmp/goldrand"+" bs="+str(kbyteCount)+"K"+" count="+str(blockCount)+statarg, shell=True)
                            while chnIndex < chCount:
                                print ("\nTesting channel ", chnIndex)
                                outfile = " of=/dev/"+drvName+"/"+drvName+"0_h2c_"+str(chnIndex)
                                infile = " if=/dev/"+drvName+"/"+drvName+"0_c2h_"+str(chnIndex)
                                print ("Transferring data from host to card...")
                                result = subprocess.check_output("dd"+" if=/tmp/goldrand"+outfile+" bs="+str(kbyteCount)+"K"+" count="+str(blockCount)+statarg, shell=True)
                                print ("Transferring data from card back to host...")
                                result = subprocess.check_output("dd"+infile+" of=/tmp/outrand"+" bs="+str(kbyteCount)+"K"+" count="+str(blockCount)+statarg, shell=True)
                                result = subprocess.check_output(["du", "-b", "/tmp/outrand"])
                                fsize = result.split()
                                print ("Verifying the size (bytes) of binary data output... : ", fsize[0])
                                try:
                                    result = subprocess.check_output(["diff", "/tmp/goldrand", "/tmp/outrand"])
                                except subprocess.CalledProcessError as exp:
                                    result = exp.output
                                if (result != ""):
                                    print ("FAIL: Output of binary data from the DMA transfer failed to match expected golden value!")
                                    chnFailed = True
                                else:
                                    print ("PASS: Output of binary data from the DMA transfer matches expected golden value.")
                                chnIndex = chnIndex + 1

                            if (chnFailed == False):
                                resultBag.append(("3.3."+str(devIndex+1)+" Random Data Transfer Test - Device "+str(devIndex),"PASS"))
                            else:
                                resultBag.append(("3.3."+str(devIndex+1)+" Random Data Transfer Test - Device "+str(devIndex),"FAIL"))
                                
                            print ("\n3.4.", devIndex+1, " Memory Interface (MIG) Range Test - Device ", devIndex, sep='')
                            print ("--------------------------------------------")
                            subID = subSysIDList[devIndex]
                            DDRCount = int(subID[1])
                            devID = devIDList[devIndex]
                            MIGRange = DDR_DEV_RANGE[devID]
                            if ( DDRCount <=1 ):
                                print ("Single DDR MIG detected from the DSA, and is dedicated for", MIGRange, "Gbytes of memory space.")
                                print ("\nTransfer test per MIG core will not run, since previous sections covered single core setup.")
                            else: 
                                print (DDRCount, "DDR MIG detected from the DSA, each is dedicated for", MIGRange, "Gbytes of memory space.")
                                migIndex = 1
                                migFailed = False
                                print ("\nInitializing byte count and block count used for the transfer...")
                                print ("Byte count = ", "1K")
                                print ("Block count =", "64")
                                print ("\nGenerating golden file with random data...")
                                result = subprocess.check_output("dd"+" if=/dev/urandom"+" of=/tmp/goldrand"+" bs=1K"+" count=64"+statarg, shell=True)
                                while migIndex < DDRCount:
                                    outfile = " of=/dev/"+drvName+"/"+drvName+"0_h2c_0"
                                    infile = " if=/dev/"+drvName+"/"+drvName+"0_c2h_0"
                                    offset = migIndex * int(MIGRange)
                                    print ("\nTesting MIG ", migIndex, " with ", str(offset), "G of offset...", sep="")
                                    print ("Transferring data from host to card...")
                                    result = subprocess.check_output("dd"+" if=/tmp/goldrand"+outfile+" bs=1K"+" count=64"+" seek="+str(offset)+"M"+statarg, shell=True)
                                    print ("Transferring data from card back to host...")
                                    result = subprocess.check_output("dd"+infile+" of=/tmp/outrand"+" bs=1K"+" count=64"+" skip="+str(offset)+"M"+statarg, shell=True)
                                    result = subprocess.check_output(["du", "-b", "/tmp/outrand"])
                                    fsize = result.split()
                                    print ("Verifying the size (bytes) of binary data output... : ", fsize[0])
                                    try:
                                        result = subprocess.check_output(["diff", "/tmp/goldrand", "/tmp/outrand"])
                                    except subprocess.CalledProcessError as exp:
                                        result = exp.output
                                    if (result != ""):
                                        print ("FAIL: Output of binary data from the DMA transfer failed to match expected golden value!")
                                        migFailed = True
                                    else:
                                        print ("PASS: Output of binary data from the DMA transfer matches expected golden value.")
                                    migIndex = migIndex + 1

                                if (migFailed == False):
                                    resultBag.append(("3.4."+str(devIndex+1)+" Memory Interface (MIG) Range Test - Device "+str(devIndex),"PASS"))
                                else:
                                    resultBag.append(("3.4."+str(devIndex+1)+" Memory Interface (MIG) Range Test - Device "+str(devIndex),"FAIL"))
                        else:
                            print ("WARNING: You did not run this utility with root or sudo, memory transfer tests cannot be run.")
                            print ("Example Usage:  sudo sdxsyschk")
                            resultBag.append(("3.2."+str(devIndex+1)+" Zero Data Pattern Transfer Test - Device "+str(devIndex),"NOT RUN"))
                        
                    else:
                        print ("\nERROR: Number of card to host and host to card DMA channels detected do not match! Please check driver installation again.")
                        resultBag.append(("3.1."+str(devIndex+1)+" DMA Channel Check - Device "+str(devIndex),"FAIL"))
                else:
                    if (chCount == hcCount):
                        print ("\nERROR: DMA channels are not detected. Please check driver installation again.")
                    elif (hcCount > 0):
                        print ("\nERROR: DMA card to host channels are missing! Please check driver installation again.")
                    else:
                        print ("\nERROR: DMA host to card channels are missing! Please check driver installation again.")
                    resultBag.append(("3.1."+str(devIndex+1)+" DMA Channel Check - Device "+str(devIndex),"FAIL"))
                
                devIndex = devIndex + 1

        return resultBag
    except:
        e = sys.exc_info()[1]
        print (e)
        
#############################################################################
def main(argv):
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument("-v", "--verbose", help="Get verbose info", default=False, action="store_true")
        parser.add_argument("-e", "--env", help="Get environment variables info, MUST be run without sudo", default=False, action="store_true")
        parser.add_argument("-f", "--file_name", help="Optional argument, specify with a file path(name) to save the program outputs to", default=None)
        parser.add_argument("--debug", help="Turn on debug capability", default=False, action="store_true")
        args = parser.parse_args(argv[1:])

        rdi_root = os.environ.get('RDI_ROOT', None)

        ARGS["DEBUG"] = args.debug
        ARGS["VERBOSE"] = args.verbose
        ARGS["ENV"] = args.env
        
        section1Results = []
        section2Results = []
        section3Results = []
        
        if (args.file_name != None ):
            ARGS["FILE_NAME"] = args.file_name
            print ("\nNOTE: The output is being generated and saved as:", ARGS["FILE_NAME"])
            fName = file(ARGS["FILE_NAME"], 'w')
            sys.stdout = fName
        
        if ( ARGS["DEBUG"] ):
            dumpArgs()
        
        printHeader()
        printTable()
        section1Results.append(getPython())
        lsbRelFound = checkPath("lsb_release")
        if (lsbRelFound == True):
            section1Results.append(getOS())
        else:
            print ("\nWARNING: lsb_release command cannot be found in your PATH. OS support analysis cannot be continued.")
            print ("* Please install the command package first before rerunning this utility.")
            section1Results.append("WARNING")
        section1Results.append(getArch())
        if (ARGS["ENV"] != False):
            section1Results.append(printEnv())
        else:
            section1Results.append("NOT RUN")
        section1Results.append(getMTBoard())
        
        lspciFound = checkPath("lspci")
        if (lspciFound == True):
            section2Results = getPCI()
        else:
            print ("\nERROR: lspci command cannot be found in your PATH. PCIe analysis will not continue!")
            print ("* Please install the command package first before rerunning this utility.")
            section2Results.append(("2.1 Xilinx PCIe Device Check", "ERROR"))

        section3Results = testDMA()
        
        print ("\n4 Summary")
        print ("-----------------------------------------------------------")
        summary = []
        summary.append(("Section ", "Result "))
        # summary.append(("Python Version Check", section1Results[0]))
        summary.append(("1.1 Linux OS System Check", section1Results[1]))
        summary.append(("1.2 64-bit Architecture Check", section1Results[2]))
        summary.append(("1.3 Environment Variables Check", section1Results[3]))
        summary.append(("1.4 Motherboard System Info", section1Results[4]))
        summary.extend(section2Results)
        summary.extend(section3Results)
        printSummary(summary)
        
        sys.stdout.flush()
        if (args.file_name != None ):
            sys.stdout = sys.__stdout__
            fName.close()
            os.system("chmod 777 " + ARGS["FILE_NAME"])
    except:
        e = sys.exc_info()[1]
        print ("*** ERROR: ", e)
        if ( ARGS["DEBUG"] == True ):
            traceback.print_exc(file=sys.stdout)
        exit(1)
        
#############################################################################

if __name__ == "__main__":
    main(sys.argv)
    exit(0)
