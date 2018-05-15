#! /usr/bin/env bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Henry	Feng
# 
#	Bash Script:				Script to compile the simulation libraries from Actel/Microsemi
#											Libero SOC for GHDL on Linux
# 
# Description:
# ------------------------------------
#	This is a Bash script (executable) which:
#		- creates a subdirectory in the current working directory
#		- compiles all Actel/Microsemi Libero SOC simulation libraries and packages
#
# ==============================================================================
#	Copyright (C) 2015-2016 Patrick Lehmann - Dresden, Germany
#	Copyright (C) 2018 Henry Feng - Massachusetts, USA
#	
#	GHDL is free software; you can redistribute it and/or modify it under
#	the terms of the GNU General Public License as published by the Free
#	Software Foundation; either version 2, or (at your option) any later
#	version.
#	
#	GHDL is distributed in the hope that it will be useful, but WITHOUT ANY
#	WARRANTY; without even the implied warranty of MERCHANTABILITY or
#	FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#	for more details.
#	
#	You should have received a copy of the GNU General Public License
#	along with GHDL; see the file COPYING.  If not, write to the Free
#	Software Foundation, 59 Temple Place - Suite 330, Boston, MA
#	02111-1307, USA.
# ==============================================================================

# ---------------------------------------------
# work around for Darwin (Mac OS)
READLINK=readlink; if [[ $(uname) == "Darwin" ]]; then READLINK=greadlink; fi

# save working directory
WorkingDir=$(pwd)
ScriptDir="$(dirname $0)"
ScriptDir="$($READLINK -f $ScriptDir)"

# source configuration file from GHDL's 'vendors' library directory
. $ScriptDir/../ansi_color.sh
. $ScriptDir/config.sh
. $ScriptDir/shared.sh

# command line argument processing
NO_COMMAND=1
SKIP_EXISTING_FILES=0
SKIP_LARGE_FILES=0
SUPPRESS_WARNINGS=0
HALT_ON_ERROR=0
VHDLStandard=93
GHDLBinDir=""
DestDir=""
SrcDir=""
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-c|--clean)
		CLEAN=TRUE
		NO_COMMAND=0
		;;
		-a|--all)
		COMPILE_ALL=TRUE
		NO_COMMAND=0
		;;
		--fusion)
		COMPILE_FUSION=TRUE
		NO_COMMAND=0
		;;
		--smartfusion)
		COMPILE_SMARTFUSION=TRUE
		NO_COMMAND=0
		;;
		--iglooe)
		COMPILE_IGLOOE=TRUE
		NO_COMMAND=0
		;;
		--iglooplus)
		COMPILE_IGLOOPLUS=TRUE
		NO_COMMAND=0
		;;
		--igloo)
		COMPILE_IGLOO=TRUE
		NO_COMMAND=0
		;;
		--proasic3e)
		COMPILE_PROASIC3E=TRUE
		NO_COMMAND=0
		;;
		--proasic3l)
		COMPILE_PROASIC3L=TRUE
		NO_COMMAND=0
		;;
		--proasic3)
		COMPILE_PROASIC3=TRUE
		NO_COMMAND=0
		;;
		-h|--help)
		HELP=TRUE
		NO_COMMAND=0
		;;
		-s|--skip-existing)
		SKIP_EXISTING_FILES=1
		;;
		-S|--skip-largefiles)
		SKIP_LARGE_FILES=1
		;;
		-n|--no-warnings)
		SUPPRESS_WARNINGS=1
		;;
		-H|--halt-on-error)
		HALT_ON_ERROR=1
		;;
		--vhdl93)
		VHDLStandard=93
		;;
		--vhdl2008)
		VHDLStandard=2008
		;;
		--ghdl)
		GHDLBinDir="$2"
		shift						# skip argument
		;;
		--src)
		SrcDir="$2"
		shift						# skip argument
		;;
		--out)
		DestDir="$2"
		shift						# skip argument
		;;
		*)		# unknown option
		echo 1>&2 -e "${COLORED_ERROR} Unknown command line option '$key'.${ANSI_NOCOLOR}"
		exit -1
		;;
	esac
	shift # past argument or value
done

if [ $NO_COMMAND -eq 1 ]; then
	HELP=TRUE
fi

if [ "$HELP" == "TRUE" ]; then
	test $NO_COMMAND -eq 1 && echo 1>&2 -e "\n${COLORED_ERROR} No command selected."
	echo ""
	echo "Synopsis:"
	echo "  A script to compile the Actel/Microsemi Libero SOC simulation libraries for GHDL on Linux."
	echo "  One library folder 'lib/v??' per VHDL library will be created relative to the current"
	echo "  working directory."
	echo ""
	echo "  Use the adv. options or edit 'config.sh' to supply paths and default params."
	echo ""
	echo "Usage:"
	echo "  compile-microsemi.sh <common command>|<library> [<options>] [<adv. options>]"
	echo ""
	echo "Common commands:"
	echo "  -h --help             Print this help page"
	echo "  -c --clean            Remove all generated files"
	echo ""
	echo "Libraries:"
	echo "  -a --all              Compile all Actel/Microsemi simulation libraries."
	echo "     --fusion           Compile the Actel/Microsemi fusion device libraries."
	echo "     --smartfusion      Compile the Actel/Microsemi smartfusion device libraries."
	echo "     --igloo            Compile the Actel/Microsemi igloo device libraries."
	echo "     --iglooe           Compile the Actel/Microsemi iglooe device libraries."
	echo "     --iglooplus        Compile the Actel/Microsemi iglooplus device libraries."
	echo "     --proasic3         Compile the Actel/Microsemi proasic3 device libraries."
	echo "     --proasic3e        Compile the Actel/Microsemi proasic3e device libraries."
	echo "     --proasic3l        Compile the Actel/Microsemi proasic3l device libraries."
	echo "     --stratix          Compile the Actel/Microsemi Stratix device libraries."
	echo "     --nanometer        Unknown device library."
	echo ""
	echo "Library compile options:"
	echo "     --vhdl93           Compile the libraries with VHDL-93."
	echo "     --vhdl2008         Compile the libraries with VHDL-2008."
	echo "  -s --skip-existing    Skip already compiled files (an *.o file exists)."
	echo "  -S --skip-largefiles  Don't compile large files. Exclude *HSSI* and *HIP* files."
	echo "  -H --halt-on-error    Halt on error(s)."
	echo ""
	echo "Advanced options:"
	echo "  --ghdl <GHDL bin dir> Path to GHDL's binary directory, e.g. /usr/local/bin"
	echo "  --out <dir name>      Name of the output directory, e.g. xilinx-vivado"
	echo "  --src <Path to lib>   Path to the sources, e.g. /opt/altera/16.0/quartus/eda/sim_lib"
	echo ""
	echo "Verbosity:"
	echo "  -n --no-warnings      Suppress all warnings. Show only error messages."
	echo ""
	exit 0
fi

if [ "$COMPILE_ALL" == "TRUE" ]; then
	COMPILE_FUSION=TRUE
	COMPILE_IGLOO=TRUE
	COMPILE_IGLOOE=TRUE
	COMPILE_IGLOOPLUS=TRUE
	COMPILE_SMARTFUSION=TRUE
	COMPILE_PROASIC3=TRUE
	COMPILE_PROASIC3E=TRUE
	COMPILE_PROASIC3L=TRUE
fi

if [ $VHDLStandard -eq 2008 ]; then
	echo -e "${ANSI_RED}Not all Actel/Microsemi packages are VHDL-2008 compatible! Setting HALT_ON_ERROR to FALSE.${ANSI_NOCOLOR}"
	HALT_ON_ERROR=0
fi

DefaultDirectories=("/opt/microsemi" "/usr/local/microsemi")
if [ ! -z $LIBERO_ROOTDIR ]; then
	EnvSourceDir=$LIBERO_ROOTDIR/${SourceDirectories[ActelLibero]}
else
	for DefaultDir in ${DefaultDirectories[@]}; do
		for Major in 11, 10; do
			for Minor in 8, 7, 6, 5, 4, 3, 2, 1, 0; do
				Dir=$DefaultDir/Libero_v${Major}.${Minor}/Libero
				if [ -d $Dir ]; then
					EnvSourceDir=$Dir/${SourceDirectories[ActelLibero]}
					break 3
				fi
			done
		done
	done
fi

# -> $SourceDirectories
# -> $DestinationDirectories
# -> $SrcDir
# -> $DestDir
# -> $GHDLBinDir
# <= $SourceDirectory
# <= $DestinationDirectory
# <= $GHDLBinary
SetupDirectories ActelLibero "Actel/Microsemi Libero"

# create "osvvm" directory and change to it
# => $DestinationDirectory
CreateDestinationDirectory
cd $DestinationDirectory


# => $SUPPRESS_WARNINGS
# <= $GRC_COMMAND
SetupGRCat


# -> $VHDLStandard
# <= $VHDLVersion
# <= $VHDLStandard
# <= $VHDLFlavor
GHDLSetup

# define global GHDL Options
GHDL_OPTIONS=(-fexplicit -frelaxed-rules --no-vital-checks --warn-binding --mb-comments)


GHDL_PARAMS=(${GHDL_OPTIONS[@]})
GHDL_PARAMS+=(--ieee=$VHDLFlavor --std=$VHDLStandard -P$DestinationDirectory)

STOPCOMPILING=0
ERRORCOUNT=0

# Cleanup directories
# ==============================================================================
if [ "$CLEAN" == "TRUE" ]; then
	echo 1>&2 -e "${COLORED_ERROR} '--clean' is not implemented!"
	exit -1
	echo -e "${ANSI_YELLOW}Cleaning up vendor directory ...${ANSI_NOCOLOR}"
	rm *.o 2> /dev/null
	rm *.cf 2> /dev/null
fi


# Actel/Microsemi fusion libraries
# ==============================================================================
# compile fusion devices library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_FUSION" == "TRUE" ]; then
	Library="fusion"
	Files=(
		fusion.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile smartfusion library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_SMARTFUSION" == "TRUE" ]; then
	Library="smartfusion"
	Files=(
		smartfusion.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile iglooe library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_IGLOOE" == "TRUE" ]; then
	Library="iglooe"
	Files=(
		iglooe.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile iglooe library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_IGLOOPLUS" == "TRUE" ]; then
	Library="iglooplus"
	Files=(
		iglooplus.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile iglooe library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_IGLOO" == "TRUE" ]; then
	Library="igloo"
	Files=(
		igloo.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile proasic3 library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_PROASIC3" == "TRUE" ]; then
	Library="proasic3"
	Files=(
		proasic3.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile proasic3e library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_PROASIC3E" == "TRUE" ]; then
	Library="proasic3e"
	Files=(
		proasic3e.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

# compile proasic3l library
if [ $STOPCOMPILING -eq 0 ] && [ "$COMPILE_PROASIC3L" == "TRUE" ]; then
	Library="proasic3l"
	Files=(
		proasic3l.vhd
	)
	# append absolute source path
	SourceFiles=()
	for File in ${Files[@]}; do
		SourceFiles+=("$SourceDirectory/$File")
	done

	GHDLCompilePackages
fi

echo "--------------------------------------------------------------------------------"
echo -n "Compiling Actel/Microsemi Libero libraries "
if [ $ERRORCOUNT -gt 0 ]; then
	echo -e $COLORED_FAILED
else
	echo -e $COLORED_SUCCESSFUL
fi
