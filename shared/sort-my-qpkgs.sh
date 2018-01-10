#!/usr/bin/env bash
############################################################################
# sort-my-qpkgs.sh - (C)opyright 2017-2018 OneCD [one.cd.only@gmail.com]
#
# This script is part of the 'SortMyQPKGs' package
#
# For more info: [https://forum.qnap.com/viewtopic.php?f=320&t=133132]
#
# Available in the Qnapclub Store: [https://qnapclub.eu/en/qpkg/508]
# Project source: [https://github.com/OneCDOnly/SortMyQPKGs]
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

    THIS_QPKG_NAME='SortMyQPKGs'
    CONFIG_PATHFILE='/etc/config/qpkg.conf'
    SHUTDOWN_PATHFILE='/etc/init.d/shutdown_check.sh'

    [[ ! -e $CONFIG_PATHFILE ]] && { echo "file not found [$CONFIG_PATHFILE]"; exit 1 ;}
    [[ ! -e $SHUTDOWN_PATHFILE ]] && { echo "file not found [$SHUTDOWN_PATHFILE]"; exit 1 ;}

    local QPKG_PATH="$(getcfg $THIS_QPKG_NAME Install_Path -f "$CONFIG_PATHFILE")"
    local ALPHA_PATHFILE="${QPKG_PATH}/ALPHA.list"
    local OMEGA_PATHFILE="${QPKG_PATH}/OMEGA.list"
    REAL_LOG_PATHFILE="${QPKG_PATH}/${THIS_QPKG_NAME}.log"
    TEMP_LOG_PATHFILE="${QPKG_PATH}/${THIS_QPKG_NAME}.log.tmp"
    GUI_LOG_PATHFILE="/home/httpd/${THIS_QPKG_NAME}.log"
    [[ ! -e $REAL_LOG_PATHFILE ]] && touch "$REAL_LOG_PATHFILE"
    [[ -e $TEMP_LOG_PATHFILE ]] && rm -f "$TEMP_LOG_PATHFILE"
    [[ ! -L $GUI_LOG_PATHFILE ]] && ln -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
    [[ ! -e $ALPHA_PATHFILE ]] && { echo "file not found [$ALPHA_PATHFILE]"; exit 1 ;}
    [[ ! -e $OMEGA_PATHFILE ]] && { echo "file not found [$OMEGA_PATHFILE]"; exit 1 ;}

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_ALPHA_ORDERED+=($package_ref)
    done < "$ALPHA_PATHFILE"

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_OMEGA_ORDERED+=($package_ref)
    done < "$OMEGA_PATHFILE"

    PKGS_OMEGA_ORDERED+=($THIS_QPKG_NAME)

    }

ShowPreferredList()
    {

    ShowSectionTitle 'Preferred QPKG order'
    echo -e "< matching installed packages are indicated with '#' >\n"
    ShowListsMarked

    }

ShowPackagesBefore()
    {

    ShowSectionTitle 'Original QPKG order'
    ShowPackagesUnmarked

    }

ShowPackagesCurrent()
    {

    ShowSectionTitle 'Existing QPKG order'
    ShowPackagesUnmarked

    }

ShowPackagesAfter()
    {

    ShowSectionTitle 'New QPKG order'
    ShowPackagesUnmarked

    }

ShowListsMarked()
    {

    local acc=0
    local fmtacc=''

    for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
        ((acc++)); fmtacc="$(printf "%02d\n" $acc)"
        if (grep -qF "[$pref]" $CONFIG_PATHFILE); then
            ShowLineMarked "$fmtacc" 'A' "$pref"
        else
            ShowLineUnmarked "$fmtacc" 'A' "$pref"
        fi
    done

    echo
    ((acc++)); fmtacc="$(printf "%02d\n" $acc)"; ShowLineUnmarked "$fmtacc" 'Φ' '< existing unspecified packages go here >'
    echo

    for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
        ((acc++)); fmtacc="$(printf "%02d\n" $acc)"
        if (grep -qF "[$pref]" $CONFIG_PATHFILE); then
            ShowLineMarked "$fmtacc" 'Ω' "$pref"
        else
            ShowLineUnmarked "$fmtacc" 'Ω' "$pref"
        fi
    done

    }

ShowPackagesMarked()
    {

    local acc=0
    local fmtacc=''
    local buffer=''

    for label in $(grep '^\[' $CONFIG_PATHFILE); do
        ((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
        buffer=$(ShowLineUnmarked "$fmtacc" 'Φ' "$package")

        for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
            [[ $package = $pref ]] && { buffer=$(ShowLineMarked "$fmtacc" 'A' "$package"); break ;}
        done

        for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
            [[ $package = $pref ]] && { buffer=$(ShowLineMarked "$fmtacc" 'Ω' "$package"); break ;}
        done

        echo -e "$buffer"
    done

    }

ShowPackagesUnmarked()
    {

    local acc=0
    local fmtacc=''
    local buffer=''

    for label in $(grep '^\[' $CONFIG_PATHFILE); do
        ((acc++)); a=${label//[}; package=${a//]}; fmtacc="$(printf "%02d\n" $acc)"
        buffer=$(ShowLineUnmarked "$fmtacc" 'Φ' "$package")

        for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
            [[ $package = $pref ]] && { buffer=$(ShowLineUnmarked "$fmtacc" 'A' "$package"); break ;}
        done

        for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
            [[ $package = $pref ]] && { buffer=$(ShowLineUnmarked "$fmtacc" 'Ω' "$package"); break ;}
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
        *[!0-9]*)   # specified file extension is not a number so add number and copy it
            dest="$1.1"
            [[ -e $dest ]] && Upshift "$dest"
            cp "$1" "$dest"
            ;;
        *)          # extension IS a number, so move it if possible
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

TrimLog()
    {

    local max_ops=10
    local op_lines=$(grep -n "^──" "$REAL_LOG_PATHFILE")
    local op_count=$(echo "$op_lines" | wc -l)

    if [[ $op_count -gt $max_ops ]]; then
        local last_op_line_num=$(echo "$op_lines" | head -n$((max_ops+1)) | tail -n1 | cut -f1 -d:)
        head -n${last_op_line_num} "$REAL_LOG_PATHFILE" > "$TEMP_LOG_PATHFILE"
        mv "$TEMP_LOG_PATHFILE" "$REAL_LOG_PATHFILE"
    fi

    }

ShowLineUnmarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    echo -e "($1) ($2) $3"

    }

ShowLineMarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    echo -e "($1)#($2) $3"

    }

RecordOperation()
    {

    # $1 = operation

    local buffer="[$(date)] '$1' requested"
    local length=${#buffer}
    local temp=$(printf "%${length}s")
    local build=$(getcfg $THIS_QPKG_NAME Build -f $CONFIG_PATHFILE)

    echo "${temp// /─}" >> "$TEMP_LOG_PATHFILE"
    echo -e "$THIS_QPKG_NAME ($build)" >> "$TEMP_LOG_PATHFILE"
    echo "$buffer" >> "$TEMP_LOG_PATHFILE"

    LogWrite "'$1' requested" 0

    }

ShowSectionTitle()
    {

    # $1 = description

    echo -e "\n * $1 *"

    }

LogWrite()
    {

    # $1 = message to write into NAS system log
    # $2 = event type:
    #    0 : Information
    #    1 : Warning
    #    2 : Error

    /sbin/log_tool --append "[$THIS_QPKG_NAME] $1" --type "$2"

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
        RecordOperation "$1"
        Upshift "$CONFIG_PATHFILE"
        ShowPackagesBefore >> "$TEMP_LOG_PATHFILE"
        SortPackages
        ShowPackagesAfter >> "$TEMP_LOG_PATHFILE"
        echo -e "$(<$TEMP_LOG_PATHFILE)\n\n$(<$REAL_LOG_PATHFILE)" > "$REAL_LOG_PATHFILE"
        TrimLog
        ;;
    fix)
        RecordOperation "$1"
        Upshift "$CONFIG_PATHFILE"
        ShowPackagesBefore | tee -a "$TEMP_LOG_PATHFILE"
        SortPackages
        ShowPackagesAfter | tee -a "$TEMP_LOG_PATHFILE"
        echo -e "$(<$TEMP_LOG_PATHFILE)\n\n$(<$REAL_LOG_PATHFILE)" > "$REAL_LOG_PATHFILE"
        TrimLog
        echo -e "\n ! NOTE: you must restart your NAS to load the QPKGs in this order.\n"
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
        echo -e "\n Usage: $0 {fix|pref}"
        ShowPackagesCurrent
        echo -e "\n Launch with '$0 fix' to re-order packages.\n"
        ;;
esac

[[ -e $TEMP_LOG_PATHFILE ]] && rm -f "$TEMP_LOG_PATHFILE"
