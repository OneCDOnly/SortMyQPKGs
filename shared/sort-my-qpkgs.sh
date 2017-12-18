#!/usr/bin/env bash
############################################################################
# sort-my-qpkgs.sh
#
# (C)opyright 2017 OneCD
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# for more info:
#	https://forum.qnap.com/viewtopic.php?f=320&t=133132
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
############################################################################

Init()
	{

	local THIS_QPKG_NAME='SortMyQPKGs'
 	CONFIG_PATHFILE='/etc/config/qpkg.conf'
 	SHUTDOWN_PATHFILE='/etc/init.d/shutdown_check.sh'
	local QPKG_PATH="$(getcfg $THIS_QPKG_NAME Install_Path -f "$CONFIG_PATHFILE")"

	REAL_LOG_PATHFILE="${QPKG_PATH}/${THIS_QPKG_NAME}.log"
	GUI_LOG_PATHFILE="/home/httpd/${THIS_QPKG_NAME}.log"
	[[ ! -e $REAL_LOG_PATHFILE ]] && touch "$REAL_LOG_PATHFILE"
	[[ ! -L $GUI_LOG_PATHFILE ]] && ln -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"

	colourised=true

	[[ ! -e $CONFIG_PATHFILE ]] && { echo "file not found [$CONFIG_PATHFILE]"; exit 1 ;}
	[[ ! -e $SHUTDOWN_PATHFILE ]] && { echo "file not found [$SHUTDOWN_PATHFILE]"; exit 1 ;}

	PKGS_ALPHA_ORDERED=(update_qpkg_conf DownloadStation Python QPython2 Python3 QPython3 Perl QPerl Optware Optware-NG Entware-ng Entware-3x QGit Mono Qmono DotNET nodejs nodejsv4 JRE QJDK7 QJDK8 Qapache QNginx Tomcat Tomcat8 ruby Plex Emby EmbyServer Par2 Par2cmdline-MT)

	PKGS_OMEGA_ORDERED=(QNZBGet QSonarr Radarr SABnzbdplus SickBeard SickBeard-TVRage SickRage SurveillanceStation $THIS_QPKG_NAME)

	}

ShowDataBlock()
	{

	# returns the data block for the QPKG name specified as $1

	[[ -z $1 ]] && { echo "QPKG not specified"; return 1 ;}
	! (grep -q $1 $CONFIG_PATHFILE) && { echo "QPKG not found"; return 2 ;}

	sl=$(grep -n "^\[$1\]" "$CONFIG_PATHFILE" | cut -f1 -d':')
	ll=$(wc -l < "$CONFIG_PATHFILE" | tr -d ' ')
	bl=$(tail -n$((ll-sl)) < "$CONFIG_PATHFILE" | grep -n '^\[' | head -n1 | cut -f1 -d':')
	[[ ! -z $bl ]] && el=$((sl+bl-1)) || el=$ll

	echo "$(sed -n "$sl,${el}p" "$CONFIG_PATHFILE")"

	}

SendToStart()
	{

	# sends $1 to the start of qpkg.conf

	local temp_pathfile="/tmp/$(basename $CONFIG_PATHFILE).tmp"
	local buffer=$(ShowDataBlock "$1")
	[[ $? -gt 0 ]] && { echo "error - ${buffer}!"; return 2 ;}

	rmcfg "$1" -f "$CONFIG_PATHFILE"
	echo -e "$buffer" > "$temp_pathfile"
	cat "$CONFIG_PATHFILE" >> "$temp_pathfile"
	mv "$temp_pathfile" "$CONFIG_PATHFILE"

	}

SendToEnd()
	{

	# sends $1 to the end of qpkg.conf

	local buffer=$(ShowDataBlock "$1")
	[[ $? -gt 0 ]] && { echo "error - ${buffer}!"; return 2 ;}

	rmcfg "$1" -f "$CONFIG_PATHFILE"
	echo -e "$buffer" >> "$CONFIG_PATHFILE"

	}

ShowPreferredList()
	{

	ShowSectionTitle 'Preferred QPKG order'

	local acc=0
	local fmtacc=''

    for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
		((acc++)); fmtacc="$(printf "%02d\n" $acc)"
		if (grep -qF "[$pref]" $CONFIG_PATHFILE); then
			ShowLineTest "$fmtacc" 'A' "$pref"
		else
			ShowLinePlain "$fmtacc" 'A' "$pref"
		fi
	done

	echo
	((acc++)); fmtacc="$(printf "%02d\n" $acc)"; ShowLinePlain "$fmtacc" 'Φ' 'existing unspecified QPKGs go here'
	echo

	for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
		((acc++)); fmtacc="$(printf "%02d\n" $acc)"
		if (grep -qF "[$pref]" $CONFIG_PATHFILE); then
			ShowLineTest "$fmtacc" 'Ω' "$pref"
		else
			ShowLinePlain "$fmtacc" 'Ω' "$pref"
		fi
	done

	}

ShowPackagesCurrent()
	{

	ShowSectionTitle 'Existing QPKG order'

	local acc=0
	local fmtacc=''
	local buffer=''

	for label in $(grep '^\[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" 'Φ' "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			[[ $package = $pref ]] && { buffer=$(ShowLineTest "$fmtacc" 'A' "$package"); break ;}
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			[[ $package = $pref ]] && { buffer=$(ShowLineTest "$fmtacc" 'Ω' "$package"); break ;}
		done

		echo -e "$buffer"
	done

	}

ShowPackagesBefore()
	{

	ShowSectionTitle 'Original QPKG order'

	local acc=0
	local fmtacc=''
	local buffer=''

	for label in $(grep '^\[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" 'Φ' "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			if [[ $package = $pref ]]; then
				if [[ $colourised = true ]]; then
					buffer=$(ShowLineTest "$fmtacc" 'A' "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" 'A' "$package")
				fi
				break
			fi
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			if [[ $package = $pref ]]; then
				if [[ $colourised = true ]]; then
					buffer=$(ShowLineTest "$fmtacc" 'Ω' "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" 'Ω' "$package")
				fi
				break
			fi
		done

		echo -e "$buffer"
	done

	}

ShowPackagesAfter()
	{

	ShowSectionTitle 'New QPKG order'

	local acc=0
	local fmtacc=''
	local buffer=''

	for label in $(grep '^\[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" 'Φ' "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			if [[ $package = $pref ]]; then
				if [[ $colourised = true ]]; then
					buffer=$(ShowLinePass "$fmtacc" 'A' "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" 'A' "$package")
				fi
				break
			fi
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			if [[ $package = $pref ]]; then
				if [[ $colourised = true ]]; then
					buffer=$(ShowLinePass "$fmtacc" 'Ω' "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" 'Ω' "$package")
				fi
				break
			fi
		done

		echo -e "$buffer"
	done

	}

SortPackages()
	{

	# cruft: remove previous backup system files. This code can be removed once no-one is using sort-my-qpkgs.sh version earlier than 171207.
	rm -f "$CONFIG_PATHFILE".prev*

	# read 'ALPHA' packages in reverse and prepend each to qpkg.conf
	for ((i=${#PKGS_ALPHA_ORDERED[@]}-1; i>=0; i--)); do
		for label in $(grep '^\[' $CONFIG_PATHFILE); do
			a=${label//[}; package=${a//]}; [[ $package = ${PKGS_ALPHA_ORDERED[$i]} ]] && { SendToStart "$package"; break ;}
		done
	done

	# now read 'OMEGA' packages and append each to qpkg.conf
	for i in "${PKGS_OMEGA_ORDERED[@]}"; do
		for label in $(grep '^\[' $CONFIG_PATHFILE); do
			a=${label//[}; package=${a//]}; [[ $package = $i ]] && { SendToEnd "$package"; break ;}
		done
	done

	}

Upshift()
	{

	# move specified existing filename by incrementing extension value (upshift extension)
	# if extension is not a number, then create new extension of '1' and copy file

	# $1 = pathfilename to Upshift

	[[ -z $1 ]] && return 1
	[[ ! -e $1 ]] && return 1

	local ext=''
	local dest=''
	local rotate_limit=10

	# keep count of recursive calls
	local rec_limit=$((rotate_limit*2))
	local rec_count=0
	local rec_track_file="/tmp/$FUNCNAME.count"
	[[ -e $rec_track_file ]] && rec_count=$(<"$rec_track_file")
	((rec_count++)); [[ $rec_count -gt $rec_limit ]] && { echo "recursive limit reached!"; rm "$rec_track_file"; exit 1 ;}
	echo $rec_count > "$rec_track_file"

	ext=${1##*.}
	case $ext in
		*[!0-9]*)	# specified file extension is not a number so add number and copy it
			dest="$1.1"
			[[ -e $dest ]] && Upshift "$dest"
			cp "$1" "$dest"
			;;
		*)			# extension IS a number, so move it if possible
			if [[ $ext -lt $((rotate_limit-1)) ]]; then
				((ext++)); dest="${1%.*}.$ext"
				[[ -e $dest ]] && Upshift "$dest"
				mv "$1" "$dest"
			else
				rm "$1"
			fi
			;;
	esac

	[[ -e $rec_track_file ]] && { rec_count=$(<"$rec_track_file"); ((rec_count--)); echo $rec_count > "$rec_track_file" ;}

	}

ShowLinePlain()
	{

	# $1 = number
	# $2 = symbol
	# $3 = name

	ShowLine "$1" "$2" "$3"

	}

ShowLineTest()
	{

	# $1 = number
	# $2 = symbol
	# $3 = name

	ShowLine "$(ColourTextBrightOrange "$1")" "$(ColourTextBrightOrange "$2")" "$(ColourTextBrightOrange "$3")"

	}

ShowLinePass()
	{

	# $1 = number
	# $2 = symbol
	# $3 = name

	ShowLine "$(ColourTextBrightGreen "$1")" "$(ColourTextBrightGreen "$2")" "$(ColourTextBrightGreen "$3")"

	}

ShowLine()
	{

	# $1 = number
	# $2 = symbol
	# $3 = name

	echo -e "($1) ($2) $3"

	}

ShowSectionTitle()
	{

	# $1 = description

	if [[ $colourised = true ]]; then
		echo -e "\n $(ColourTextBrightWhite "* $1 *")"
	else
		echo -e "\n * $1 *"
	fi

	}

ColourTextBrightWhite()
	{

	echo -en '\E[1;97m'"$(PrintResetColours "$1")"

	}

ColourTextBrightGreen()
	{

	echo -en '\E[1;32m'"$(PrintResetColours "$1")"

	}

ColourTextBrightOrange()
	{

	echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

	}

PrintResetColours()
	{

	echo -en "$1"'\E[0m'

	}

Init

case "$1" in
	install)
		$0 start
		$0 init
		;;
	start)
		if ! (grep -q 'sort-my-qpkgs.sh' "$SHUTDOWN_PATHFILE"); then
			findtext='#backup logs'
			inserttext='/etc/init.d/sort-my-qpkgs.sh autofix'
			sed -i "s|$findtext|$inserttext\n$findtext|" "$SHUTDOWN_PATHFILE"
		fi
		;;
	remove)
		(grep -q 'sort-my-qpkgs.sh' "$SHUTDOWN_PATHFILE") && sed -i '/sort-my-qpkgs.sh/d' "$SHUTDOWN_PATHFILE"
		[[ -L $GUI_LOG_PATHFILE ]] && rm -f "$GUI_LOG_PATHFILE"
		;;
	init|autofix)
		colourised=false
		echo "[$(date)] $1 requested" >> "$REAL_LOG_PATHFILE"
		Upshift "$CONFIG_PATHFILE"
		ShowPackagesBefore >> "$REAL_LOG_PATHFILE"
		SortPackages
		echo -e "$(ShowPackagesAfter)\n" >> "$REAL_LOG_PATHFILE"
		;;
	fix)
		Upshift "$CONFIG_PATHFILE"
		ShowPackagesBefore
		SortPackages
		ShowPackagesAfter
		echo -e "\n ! NOTE: you must restart your NAS to load QPKGs in this order.\n"
		;;
	pref)
		ShowPreferredList
		echo
		;;
	stop|restart)
		# do nothing
		sleep 1
		;;
	*)
		echo -e "\nUsage: $0 {fix|pref}"
		ShowPackagesCurrent
		echo -e "\n Launch with '$0 fix' to re-order packages."
		echo
		;;
esac
