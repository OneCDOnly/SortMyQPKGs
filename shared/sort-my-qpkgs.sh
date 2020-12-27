#!/usr/bin/env bash
############################################################################
# sort-my-qpkgs.sh - (C)opyright 2017-2020 OneCD [one.cd.only@gmail.com]
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

    readonly THIS_QPKG_NAME=SortMyQPKGs
    readonly CONFIG_PATHFILE=/etc/config/qpkg.conf
    readonly SHUTDOWN_PATHFILE=/etc/init.d/shutdown_check.sh
    readonly LC_ALL=C

    # cherry-pick required binaries
    readonly CAT_CMD=/bin/cat
    readonly DATE_CMD=/bin/date
    readonly GREP_CMD=/bin/grep
    readonly LN_CMD=/bin/ln
    readonly SED_CMD=/bin/sed
    readonly SLEEP_CMD=/bin/sleep
    readonly TOUCH_CMD=/bin/touch
    readonly TR_CMD=/bin/tr

    readonly APP_CENTER_NOTIFIER=/sbin/qpkg_cli     # only needed for QTS 4.5.1-and-later
    readonly GETCFG_CMD=/sbin/getcfg
    readonly RMCFG_CMD=/sbin/rmcfg
    readonly SETCFG_CMD=/sbin/setcfg

    readonly BASENAME_CMD=/usr/bin/basename
    readonly CUT_CMD=/usr/bin/cut
    readonly HEAD_CMD=/usr/bin/head
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee
    readonly WC_CMD=/usr/bin/wc

    $SETCFG_CMD "$THIS_QPKG_NAME" Status complete -f "$CONFIG_PATHFILE"

    # KLUDGE: 'clean' the QTS 4.5.1 App Center notifier status
    [[ -e $APP_CENTER_NOTIFIER ]] && $APP_CENTER_NOTIFIER --clean "$THIS_QPKG_NAME" > /dev/null 2>&1

    if [[ ! -e $CONFIG_PATHFILE ]]; then
        echo "file not found [$CONFIG_PATHFILE]"
        exit 1
    fi

    if [[ ! -e $SHUTDOWN_PATHFILE ]]; then
        echo "file not found [$SHUTDOWN_PATHFILE]"
        exit 1
    fi

    local -r QPKG_PATH=$($GETCFG_CMD $THIS_QPKG_NAME Install_Path -f $CONFIG_PATHFILE)
    local -r ALPHA_PATHFILE_DEFAULT=$QPKG_PATH/ALPHA.default
    local -r OMEGA_PATHFILE_DEFAULT=$QPKG_PATH/OMEGA.default
    local -r ALPHA_PATHFILE_CUSTOM=$QPKG_PATH/ALPHA.custom
    local -r OMEGA_PATHFILE_CUSTOM=$QPKG_PATH/OMEGA.custom
    local alpha_pathfile_actual=''
    local omega_pathfile_actual=''
    readonly REAL_LOG_PATHFILE=$QPKG_PATH/$THIS_QPKG_NAME.log
    readonly TEMP_LOG_PATHFILE=$REAL_LOG_PATHFILE.tmp
    readonly GUI_LOG_PATHFILE=/home/httpd/$THIS_QPKG_NAME.log
    readonly LINK_LOG_PATHFILE=/var/log/$THIS_QPKG_NAME.log

    [[ ! -e $REAL_LOG_PATHFILE ]] && $TOUCH_CMD "$REAL_LOG_PATHFILE"
    [[ -e $TEMP_LOG_PATHFILE ]] && rm -f "$TEMP_LOG_PATHFILE"
    [[ ! -L $GUI_LOG_PATHFILE ]] && $LN_CMD -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
    [[ ! -L $LINK_LOG_PATHFILE ]] && $LN_CMD -s "$REAL_LOG_PATHFILE" "$LINK_LOG_PATHFILE"

    if [[ -e $ALPHA_PATHFILE_CUSTOM ]]; then
        alpha_pathfile_actual=$ALPHA_PATHFILE_CUSTOM
        alpha_source=custom
    elif [[ -e $ALPHA_PATHFILE_DEFAULT ]]; then
        alpha_pathfile_actual=$ALPHA_PATHFILE_DEFAULT
        alpha_source=default
    else
        echo "ALPHA package list file not found"
        exit 1
    fi

    if [[ -e $OMEGA_PATHFILE_CUSTOM ]]; then
        omega_pathfile_actual=$OMEGA_PATHFILE_CUSTOM
        omega_source=custom
    elif [[ -e $OMEGA_PATHFILE_DEFAULT ]]; then
        omega_pathfile_actual=$OMEGA_PATHFILE_DEFAULT
        omega_source=default
    else
        echo "OMEGA package list file not found"
        exit 1
    fi

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_ALPHA_ORDERED+=($package_ref)
    done < $alpha_pathfile_actual

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_OMEGA_ORDERED+=($package_ref)
    done < $omega_pathfile_actual

    PKGS_OMEGA_ORDERED+=($THIS_QPKG_NAME)

    }

ShowPreferredList()
    {

    ShowSectionTitle 'Preferred order'
    echo -e "< matching installed packages are indicated with '#' >\n"
    ShowListsMarked

    }

ShowPackagesBefore()
    {

    ShowSectionTitle 'Original order'
    ShowPackagesUnmarked

    }

ShowPackagesCurrent()
    {

    ShowSectionTitle 'Existing order'
    ShowPackagesUnmarked

    }

ShowPackagesAfter()
    {

    ShowSectionTitle 'New order'
    ShowPackagesUnmarked

    }

ShowListsMarked()
    {

    local acc=0
    local fmtacc=''

    for pref in ${PKGS_ALPHA_ORDERED[@]}; do
        ((acc++)); fmtacc=$(printf "%02d\n" $acc)
        if ($GREP_CMD -qF "[$pref]" $CONFIG_PATHFILE); then
            ShowLineMarked "$fmtacc" A "$pref"
        else
            ShowLineUnmarked "$fmtacc" A "$pref"
        fi
    done

    echo
    ((acc++)); fmtacc=$(printf "%02d\n" $acc); ShowLineUnmarked "$fmtacc" Φ '< existing unspecified packages go here >'
    echo

    for pref in ${PKGS_OMEGA_ORDERED[@]}; do
        ((acc++)); fmtacc=$(printf "%02d\n" $acc)
        if ($GREP_CMD -qF "[$pref]" $CONFIG_PATHFILE); then
            ShowLineMarked "$fmtacc" Ω "$pref"
        else
            ShowLineUnmarked "$fmtacc" Ω "$pref"
        fi
    done

    }

ShowPackagesUnmarked()
    {

    local acc=0
    local pref=''
    local fmtacc=''
    local buffer=''
    local label=''

    for label in $($GREP_CMD '^\[' $CONFIG_PATHFILE); do
        ((acc++)); package=${label//[\[\]]}; fmtacc=$(printf "%02d\n" $acc)
        buffer=$(ShowLineUnmarked "$fmtacc" Φ "$package")

        for pref in ${PKGS_ALPHA_ORDERED[@]}; do
            [[ $package = $pref ]] && { buffer=$(ShowLineUnmarked "$fmtacc" A "$package"); break ;}
        done

        for pref in ${PKGS_OMEGA_ORDERED[@]}; do
            [[ $package = $pref ]] && { buffer=$(ShowLineUnmarked "$fmtacc" Ω "$package"); break ;}
        done

        echo -e "$buffer"
    done

    }

ShowSources()
    {

    echo "ALPHA=$alpha_source, OMEGA=$omega_source"

    }

SortPackages()
    {

    local index=0
    local label=''

    # read 'ALPHA' packages in reverse and prepend each to qpkg.conf
    for ((index=${#PKGS_ALPHA_ORDERED[@]}-1; index>=0; index--)); do
        for label in $($GREP_CMD '^\[' $CONFIG_PATHFILE); do
            package=${label//[\[\]]}; [[ $package = ${PKGS_ALPHA_ORDERED[$index]} ]] && { SendToStart "$package"; break ;}
        done
    done

    # now read 'OMEGA' packages and append each to qpkg.conf
    for index in ${PKGS_OMEGA_ORDERED[@]}; do
        for label in $($GREP_CMD '^\[' $CONFIG_PATHFILE); do
            package=${label//[\[\]]}; [[ $package = $index ]] && { SendToEnd "$package"; break ;}
        done
    done

    }

SendToStart()
    {

    # sends $1 to the start of qpkg.conf

    local temp_pathfile=/tmp/$($BASENAME_CMD $CONFIG_PATHFILE).tmp
    local buffer=$(ShowDataBlock $1)

    if [[ $? -gt 0 ]]; then
        echo "error - ${buffer}!"
        return 2
    fi

    $RMCFG_CMD $1 -f $CONFIG_PATHFILE
    echo -e "$buffer" > $temp_pathfile
    $CAT_CMD $CONFIG_PATHFILE >> $temp_pathfile
    mv $temp_pathfile $CONFIG_PATHFILE

    }

SendToEnd()
    {

    # sends $1 to the end of qpkg.conf

    local buffer=$(ShowDataBlock "$1")

    if [[ $? -gt 0 ]]; then
        echo "error - ${buffer}!"
        return 2
    fi

    $RMCFG_CMD $1 -f $CONFIG_PATHFILE
    echo -e "$buffer" >> $CONFIG_PATHFILE

    }

ShowDataBlock()
    {

    # returns the data block for the QPKG name specified as $1

    local sl=''
    local ll=''
    local bl=''
    local el=''

    if [[ -z $1 ]]; then
        echo "QPKG not specified"
        return 1
    fi

    if ! $GREP_CMD -q $1 $CONFIG_PATHFILE; then
        echo "QPKG not found"; return 2
    fi

    sl=$($GREP_CMD -n "^\[$1\]" $CONFIG_PATHFILE | $CUT_CMD -f1 -d':')
    ll=$($WC_CMD -l < $CONFIG_PATHFILE | $TR_CMD -d ' ')
    bl=$($TAIL_CMD -n$((ll-sl)) < $CONFIG_PATHFILE | $GREP_CMD -n '^\[' | $HEAD_CMD -n1 | $CUT_CMD -f1 -d':')
    [[ ! -z $bl ]] && el=$((sl+bl-1)) || el=$ll

    $SED_CMD -n "$sl,${el}p" $CONFIG_PATHFILE

    }

Upshift()
    {

    # move specified existing filename by incrementing extension value (upshift extension)
    # if extension is not a number, then create new extension of '1' and copy file

    # $1 = pathfilename to upshift

    [[ -z $1 ]] && return 1
    [[ ! -e $1 ]] && return 1

    local ext=''
    local dest=''
    local rotate_limit=10

    # keep count of recursive calls
    local rec_limit=$((rotate_limit*2))
    local rec_count=0
    local rec_track_file=/tmp/$FUNCNAME.count
    [[ -e $rec_track_file ]] && rec_count=$(<$rec_track_file)
    ((rec_count++))

    if [[ $rec_count -gt $rec_limit ]]; then
        echo "recursive limit reached!"
        rm $rec_track_file
        exit 1
    fi

    echo $rec_count > $rec_track_file

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

    [[ -e $rec_track_file ]] && { rec_count=$(<$rec_track_file); ((rec_count--)); echo $rec_count > $rec_track_file ;}

    }

TrimLog()
    {

    local max_ops=10
    local op_lines=$($GREP_CMD -n "^──" $REAL_LOG_PATHFILE)
    local op_count=$(echo "$op_lines" | $WC_CMD -l)

    if [[ $op_count -gt $max_ops ]]; then
        local last_op_line_num=$(echo "$op_lines" | $HEAD_CMD -n$((max_ops+1)) | $TAIL_CMD -n1 | $CUT_CMD -f1 -d:)
        $HEAD_CMD -n${last_op_line_num} $REAL_LOG_PATHFILE > $TEMP_LOG_PATHFILE
        mv $TEMP_LOG_PATHFILE $REAL_LOG_PATHFILE
    fi

    }

ShowLineUnmarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    echo "($1) ($2) $3"

    }

ShowLineMarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    echo "($1)#($2) $3"

    }

RecordOperationRequest()
    {

    # $1 = operation

    local buffer="[$($DATE_CMD)] '$1' requested"
    local length=${#buffer}
    local temp=$(printf "%${length}s")
    local build=$($GETCFG_CMD $THIS_QPKG_NAME Build -f $CONFIG_PATHFILE)

    echo -e "${temp// /─}\n$THIS_QPKG_NAME ($build)\n$buffer" >> $TEMP_LOG_PATHFILE

    LogWrite "'$1' requested" 0

    }

RecordOperationComplete()
    {

    # $1 = operation

    local buffer="\n[$($DATE_CMD)] '$1' completed"

    echo -e "$buffer" >> $TEMP_LOG_PATHFILE

    LogWrite "'$1' completed" 0

    }

ShowSectionTitle()
    {

    # $1 = description

    echo -e "\n * $1 *"

    }

CommitLog()
    {

    echo -e "$(<$TEMP_LOG_PATHFILE)\n$(<$REAL_LOG_PATHFILE)" > $REAL_LOG_PATHFILE

    TrimLog

    }

LogWrite()
    {

    # $1 = message to write into NAS system log
    # $2 = event type:
    #    0 : Information
    #    1 : Warning
    #    2 : Error

    log_tool --append "[$THIS_QPKG_NAME] $1" --type $2

    }

Init

case $1 in
    install|start)
        if ! ($GREP_CMD -q 'sort-my-qpkgs.sh' $SHUTDOWN_PATHFILE); then
            findtext='#backup logs'
            inserttext='/etc/init.d/sort-my-qpkgs.sh autofix'
            $SED_CMD -i "s|$findtext|$inserttext\n$findtext|" $SHUTDOWN_PATHFILE
        fi
        if [[ $1 = install ]]; then
            RecordOperationRequest "$1"
            RecordOperationComplete "$1"
            CommitLog
        fi
        ;;
    remove)
        ($GREP_CMD -q 'sort-my-qpkgs.sh' $SHUTDOWN_PATHFILE) && $SED_CMD -i '/sort-my-qpkgs.sh/d' $SHUTDOWN_PATHFILE
        [[ -L $GUI_LOG_PATHFILE ]] && rm -f $GUI_LOG_PATHFILE
        ;;
    autofix)
        RecordOperationRequest "$1"
        ShowSources >> $TEMP_LOG_PATHFILE
        Upshift $CONFIG_PATHFILE
        ShowPackagesBefore >> $TEMP_LOG_PATHFILE
        SortPackages
        ShowPackagesAfter >> $TEMP_LOG_PATHFILE
        RecordOperationComplete "$1"
        CommitLog
        ;;
    fix)
        RecordOperationRequest "$1"
        ShowSources | $TEE_CMD -a $TEMP_LOG_PATHFILE
        Upshift $CONFIG_PATHFILE
        ShowPackagesBefore | $TEE_CMD -a $TEMP_LOG_PATHFILE
        SortPackages
        ShowPackagesAfter | $TEE_CMD -a $TEMP_LOG_PATHFILE
        RecordOperationComplete "$1"
        CommitLog
        echo -e "\n Packages will be loaded in this order during next boot-up.\n"
        ;;
    pref)
        ShowSources
        ShowPreferredList
        echo -e "\n To re-order packages: $0 fix\n"
        ;;
    init|stop|restart)
        # do nothing
        $SLEEP_CMD 1
        ;;
    *)
        echo -e "\n Usage: $0 {fix|pref}\n"
        ShowSources
        ShowPackagesCurrent
        echo -e "\n To re-order packages: $0 fix\n"
        ;;
esac

[[ -e $TEMP_LOG_PATHFILE ]] && rm -f $TEMP_LOG_PATHFILE
