#!/bin/bash
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

	local QPKG_NAME="sort-my-qpkgs"
 	CONFIG_PATHFILE="/etc/config/qpkg.conf"
 	SHUTDOWN_PATHFILE="/etc/init.d/shutdown_check.sh"
	local QPKG_PATH="$(/sbin/getcfg $QPKG_NAME Install_Path -f "$CONFIG_PATHFILE")"

	REAL_LOG_PATHFILE="${QPKG_PATH}/${QPKG_NAME}.log"
	SERVER_LOG_PATHFILE="/home/httpd/${QPKG_NAME}.log"
	[ ! -e "$REAL_LOG_PATHFILE" ] && touch "$REAL_LOG_PATHFILE"
	[ ! -L "$SERVER_LOG_PATHFILE" ] && ln -s "$REAL_LOG_PATHFILE" "$SERVER_LOG_PATHFILE"

	GREP_CMD="/bin/grep"
	SED_CMD="/bin/sed"

	errorcode=0
	colourised=true

	[ ! -e "$CONFIG_PATHFILE" ] && { echo "file not found [$CONFIG_PATHFILE]"; errorcode=1; return 1 ;}
	[ ! -e "$SHUTDOWN_PATHFILE" ] && { echo "file not found [$SHUTDOWN_PATHFILE]"; errorcode=1; return 1 ;}

	PKGS_ALPHA_ORDERED=(update_qpkg_conf DownloadStation Python QPython2 Python3 QPython3 Perl QPerl Optware Entware-ng Entware-3x QGit Mono Qmono DotNET nodejs nodejsv4 JRE QJDK7 QJDK8 Qapache Tomcat Tomcat8 ruby Plex Par2 Par2cmdline-MT)
	PKGS_OMEGA_ORDERED=(QNZBGet QSonarr Radarr SABnzbdplus SickBeard SickBeard-TVRage SickRage SurveillanceStation sort-my-qpkgs)

	}

BackupConf()
	{

	# if a backup file already exists, find a new name for it
	local backup_pathfile="${CONFIG_PATHFILE}.prev"

	if [ -e "$backup_pathfile" ]; then
		for ((acc=2; acc<=1000; acc++)); do
			[ ! -e "$backup_pathfile.$acc" ] && break
		done

		backup_pathfile="$backup_pathfile.$acc"
	fi

	cp "$CONFIG_PATHFILE" "$backup_pathfile"
	echo -e "\n Your original QPKG list was saved as [$backup_pathfile]"

	}

ShowDataBlock()
	{

	# returns the data block for the QPKG name specified as $1

	local returncode=0

	if [ -z "$1" ]; then
		echo "QPKG not specified"
		returncode=1
	else
		if ($GREP_CMD -q $1 $CONFIG_PATHFILE); then
			sl=$($GREP_CMD -nF "[$1]" "$CONFIG_PATHFILE" | cut -f1 -d':')
			ll=$(wc -l < "$CONFIG_PATHFILE" | tr -d ' ')
			bl=$(tail -n$((ll-sl)) < "$CONFIG_PATHFILE" | $GREP_CMD -nF "[" | head -n1 | cut -f1 -d':')
			[ ! -z "$bl" ] && el=$((sl+bl-1)) || el=$ll

			echo "$($SED_CMD -n "$sl,${el}p" "$CONFIG_PATHFILE")"
		else
			echo "QPKG not found"
			returncode=2
		fi
	fi

	return $returncode

	}

SendToStart()
	{

	# sends $1 to the start of qpkg.conf

	local returncode=0
	local temp_pathfile="/tmp/$(basename $CONFIG_PATHFILE).tmp"
	local buffer=$(ShowDataBlock "$1")

	if [ "$?" -gt "0" ]; then
		echo "error - ${buffer}!"
		returncode=2
	else
		rmcfg "$1" -f "$CONFIG_PATHFILE"
		echo -e "$buffer" > "$temp_pathfile"
		cat "$CONFIG_PATHFILE" >> "$temp_pathfile"
		mv "$temp_pathfile" "$CONFIG_PATHFILE"
	fi

	return $returncode

	}

SendToEnd()
	{

	# sends $1 to the end of qpkg.conf

	local returncode=0
	local buffer=$(ShowDataBlock "$1")

	if [ "$?" -gt "0" ]; then
		echo "error - ${buffer}!"
		returncode=2
	else
		rmcfg "$1" -f "$CONFIG_PATHFILE"
		echo -e "$buffer" >> "$CONFIG_PATHFILE"
	fi

	return $returncode

	}

ShowPreferredList()
	{

	ShowSectionTitle "Preferred QPKG order"

	local acc=0
	local fmtacc=""

    for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
		((acc++)); fmtacc="$(printf "%02d\n" $acc)"
		if $($GREP_CMD -qF "[$pref]" $CONFIG_PATHFILE); then
			ShowLineTest "$fmtacc" "A" "$pref"
		else
			ShowLinePlain "$fmtacc" "A" "$pref"
		fi
	done

	echo
	((acc++)); fmtacc="$(printf "%02d\n" $acc)"; ShowLinePlain "$fmtacc" "Φ" "existing unspecified QPKGs go here"
	echo

	for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
		((acc++)); fmtacc="$(printf "%02d\n" $acc)"
		if $($GREP_CMD -qF "[$pref]" $CONFIG_PATHFILE); then
			ShowLineTest "$fmtacc" "Ω" "$pref"
		else
			ShowLinePlain "$fmtacc" "Ω" "$pref"
		fi
	done

	}

ShowPackagesCurrent()
	{

	ShowSectionTitle "Existing QPKG order"

	local acc=0
	local fmtacc=""
	local buffer=""

	for label in $($GREP_CMD -F '[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" "Φ" "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			[ "$package" == "$pref" ] && { buffer=$(ShowLineTest "$fmtacc" "A" "$package"); break ;}
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			[ "$package" == "$pref" ] && { buffer=$(ShowLineTest "$fmtacc" "Ω" "$package"); break ;}
		done

		echo -e "$buffer"
	done

	}

ShowPackagesBefore()
	{

	ShowSectionTitle "Original QPKG order"

	local acc=0
	local fmtacc=""
	local buffer=""

	for label in $($GREP_CMD -F '[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" "Φ" "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			if [ "$package" == "$pref" ]; then
				if [ "$colourised" == "true" ]; then
					buffer=$(ShowLineTest "$fmtacc" "A" "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" "A" "$package")
				fi
				break
			fi
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			if [ "$package" == "$pref" ]; then
				if [ "$colourised" == "true" ]; then
					buffer=$(ShowLineTest "$fmtacc" "Ω" "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" "Ω" "$package")
				fi
				break
			fi
		done

		echo -e "$buffer"
	done

	}

ShowPackagesAfter()
	{

	ShowSectionTitle "New QPKG order"

	local acc=0
	local fmtacc=""
	local buffer=""

	for label in $($GREP_CMD -F '[' $CONFIG_PATHFILE); do
		((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
		buffer=$(ShowLinePlain "$fmtacc" "Φ" "$package")

		for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
			if [ "$package" == "$pref" ]; then
				if [ "$colourised" == "true" ]; then
					buffer=$(ShowLinePass "$fmtacc" "A" "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" "A" "$package")
				fi
				break
			fi
		done

		for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
			if [ "$package" == "$pref" ]; then
				if [ "$colourised" == "true" ]; then
					buffer=$(ShowLinePass "$fmtacc" "Ω" "$package")
				else
					buffer=$(ShowLinePlain "$fmtacc" "Ω" "$package")
				fi
				break
			fi
		done

		echo -e "$buffer"
	done

	}

SortPackages()
	{

	# read 'ALPHA' packages in reverse and prepend each to qpkg.conf
	for ((i=${#PKGS_ALPHA_ORDERED[@]}-1; i>=0; i--)); do
		for label in $($GREP_CMD -F '[' $CONFIG_PATHFILE); do
			a=${label//[}; package=${a//]}; [ "$package" == "${PKGS_ALPHA_ORDERED[$i]}" ] && { SendToStart "$package"; break ;}
		done
	done

	# now read 'OMEGA' packages and append each to qpkg.conf
	for i in "${PKGS_OMEGA_ORDERED[@]}"; do
		for label in $($GREP_CMD -F '[' $CONFIG_PATHFILE); do
			a=${label//[}; package=${a//]}; [ "$package" == "$i" ] && { SendToEnd "$package"; break ;}
		done
	done

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

	if [ "$colourised" == "true" ]; then
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

if [ "$errorcode" == "0" ]; then
	case "$1" in
		install)
			$0 start
			$0 init
			;;

		start)
			if ! ($GREP_CMD -q "sort-my-qpkgs.sh" "$SHUTDOWN_PATHFILE"); then
				findtext="#backup logs"
				inserttext='/etc/init.d/sort-my-qpkgs.sh autofix'
				$SED_CMD -i "s|$findtext|$inserttext\n$findtext|" "$SHUTDOWN_PATHFILE"
			fi
			;;

		remove)
			($GREP_CMD -q "sort-my-qpkgs.sh" "$SHUTDOWN_PATHFILE") && $SED_CMD -i '/sort-my-qpkgs.sh/d' "$SHUTDOWN_PATHFILE"
			[ -L "$SERVER_LOG_PATHFILE" ] && rm -f "$SERVER_LOG_PATHFILE"
			;;

		init|autofix)
			colourised=false
			echo "[$(date)] $1 requested" >> "$REAL_LOG_PATHFILE"
			BackupConf >> "$REAL_LOG_PATHFILE"
			ShowPackagesBefore >> "$REAL_LOG_PATHFILE"
			SortPackages
			echo -e "$(ShowPackagesAfter)\n" >> "$REAL_LOG_PATHFILE"
			;;

		--fix)
			BackupConf
			ShowPackagesBefore
			SortPackages
			ShowPackagesAfter
			echo -e "\n ! NOTE: you must restart your NAS to load QPKGs in this order.\n"
			;;

		--pref)
			ShowPreferredList
			echo
			;;

		stop|restart)
			# do nothing
			sleep 1
			;;

		*)
			echo -e "\nUsage: $0 {--fix | --pref}"
			ShowPackagesCurrent
			echo -e "\n Launch with '$0 --fix' to re-order packages."
			echo
			;;
	esac
fi
