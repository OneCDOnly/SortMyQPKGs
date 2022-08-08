#!/usr/bin/env bash
############################################################################
# sortmyqpkgs.sh - (C)opyright 2017-2022 OneCD [one.cd.only@gmail.com]
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

    readonly QPKG_NAME=SortMyQPKGs
    readonly SHUTDOWN_PATHFILE=/etc/init.d/shutdown_check.sh
    readonly LC_ALL=C
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz

    /sbin/setcfg "$QPKG_NAME" Status complete -f /etc/config/qpkg.conf

    # KLUDGE: 'clean' the QTS 4.5.1 App Center notifier status
    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$QPKG_NAME" > /dev/null 2>&1

    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    local -r ALPHA_PATHFILE_DEFAULT=$QPKG_PATH/ALPHA.default
    local -r OMEGA_PATHFILE_DEFAULT=$QPKG_PATH/OMEGA.default
    readonly ALPHA_PATHFILE_CUSTOM=$QPKG_PATH/ALPHA.custom
    readonly OMEGA_PATHFILE_CUSTOM=$QPKG_PATH/OMEGA.custom
    local alpha_pathfile_actual=''
    local omega_pathfile_actual=''
    readonly REAL_LOG_PATHFILE=$QPKG_PATH/$QPKG_NAME.log
    readonly TEMP_LOG_PATHFILE=$REAL_LOG_PATHFILE.tmp
    readonly GUI_LOG_PATHFILE=/home/httpd/$QPKG_NAME.log
    readonly LINK_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation

    [[ ! -e $REAL_LOG_PATHFILE ]] && /bin/touch "$REAL_LOG_PATHFILE"
    [[ -e $TEMP_LOG_PATHFILE ]] && rm -f "$TEMP_LOG_PATHFILE"
    [[ ! -L $GUI_LOG_PATHFILE ]] && /bin/ln -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
    [[ ! -L $LINK_LOG_PATHFILE ]] && /bin/ln -s "$REAL_LOG_PATHFILE" "$LINK_LOG_PATHFILE"

    if [[ -e $ALPHA_PATHFILE_CUSTOM ]]; then
        alpha_pathfile_actual=$ALPHA_PATHFILE_CUSTOM
        alpha_source=custom
    elif [[ -e $ALPHA_PATHFILE_DEFAULT ]]; then
        alpha_pathfile_actual=$ALPHA_PATHFILE_DEFAULT
        alpha_source=default
    else
        echo 'ALPHA package list file not found'
        SetServiceOperationResultFailed
        exit 1
    fi

    if [[ -e $OMEGA_PATHFILE_CUSTOM ]]; then
        omega_pathfile_actual=$OMEGA_PATHFILE_CUSTOM
        omega_source=custom
    elif [[ -e $OMEGA_PATHFILE_DEFAULT ]]; then
        omega_pathfile_actual=$OMEGA_PATHFILE_DEFAULT
        omega_source=default
    else
        echo 'OMEGA package list file not found'
        SetServiceOperationResultFailed
        exit 1
    fi

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_ALPHA_ORDERED+=("$package_ref")
    done < "$alpha_pathfile_actual"

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] && PKGS_OMEGA_ORDERED+=("$package_ref")
    done < "$omega_pathfile_actual"

    PKGS_OMEGA_ORDERED+=("$QPKG_NAME")

    }

BackupConfig()
    {

    local source=''

    if [[ -e $ALPHA_PATHFILE_CUSTOM ]]; then
        source=$(/usr/bin/basename "$ALPHA_PATHFILE_CUSTOM")
    fi

    if [[ -e $OMEGA_PATHFILE_CUSTOM ]]; then
        [[ -n $source ]] && source+=" "
        source+=$(/usr/bin/basename "$OMEGA_PATHFILE_CUSTOM")
    fi

    if [[ -z $source ]]; then
        echo 'nothing to backup' | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"
        return 0
    fi

    /bin/tar --create --gzip --file="$BACKUP_PATHFILE" --directory="$QPKG_PATH" "$source" | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"

    return 0

    }

RestoreConfig()
    {

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        echo 'unable to restore: no backup file was found!' | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"
        return 1
    fi

    /bin/tar --extract --gzip --file="$BACKUP_PATHFILE" --directory="$QPKG_PATH" | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"

    return 0

    }

ResetConfig()
    {

    rm -rf "$ALPHA_PATHFILE_CUSTOM" "$OMEGA_PATHFILE_CUSTOM"

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

    local -i acc=0
    local fmtacc=''

    for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
        ((acc++)); fmtacc=$(printf "%02d\n" "$acc")
        if (/bin/grep -qF "[$pref]" /etc/config/qpkg.conf); then
            ShowLineMarked "$fmtacc" A "$pref"
        else
            ShowLineUnmarked "$fmtacc" A "$pref"
        fi
    done

    echo
    ((acc++)); fmtacc=$(printf "%02d\n" "$acc"); ShowLineUnmarked "$fmtacc" Φ '< existing unspecified packages go here >'
    echo

    for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
        ((acc++)); fmtacc=$(printf "%02d\n" "$acc")
        if (/bin/grep -qF "[$pref]" /etc/config/qpkg.conf); then
            ShowLineMarked "$fmtacc" Ω "$pref"
        else
            ShowLineUnmarked "$fmtacc" Ω "$pref"
        fi
    done

    }

ShowPackagesUnmarked()
    {

    local -i acc=0
    local pref=''
    local fmtacc=''
    local buffer=''
    local label=''

    for label in $(/bin/grep '^\[' /etc/config/qpkg.conf); do
        ((acc++)); package=${label//[\[\]]}; fmtacc=$(printf "%02d\n" "$acc")
        buffer=$(ShowLineUnmarked "$fmtacc" Φ "$package")

        for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
            [[ $package = "$pref" ]] && { buffer=$(ShowLineUnmarked "$fmtacc" A "$package"); break ;}
        done

        for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
            [[ $package = "$pref" ]] && { buffer=$(ShowLineUnmarked "$fmtacc" Ω "$package"); break ;}
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

    local -i index=0
    local label=''
    local package=''

    # read 'ALPHA' packages in reverse and prepend each to qpkg.conf
    for ((index=${#PKGS_ALPHA_ORDERED[@]}-1; index>=0; index--)); do
        for label in $(/bin/grep '^\[' /etc/config/qpkg.conf); do
            package=${label//[\[\]]}; [[ $package = "${PKGS_ALPHA_ORDERED[$index]}" ]] && { SendToStart "$package"; break ;}
        done
    done

    # now read 'OMEGA' packages and append each to qpkg.conf
    for package in "${PKGS_OMEGA_ORDERED[@]}"; do
        for label in $(/bin/grep '^\[' /etc/config/qpkg.conf); do
            [[ $package = "${label//[\[\]]}" ]] && { SendToEnd "$package"; break ;}
        done
    done

    }

SendToStart()
    {

    # sends $1 to the start of qpkg.conf

    local temp_pathfile=/tmp/qpkg.conf.tmp
    local buffer=$(ShowDataBlock "$1")

    if [[ $? -gt 0 ]]; then
        echo "error - ${buffer}!"
        return 2
    fi

    /sbin/rmcfg "$1" -f /etc/config/qpkg.conf
    echo -e "$buffer" > "$temp_pathfile"
    /bin/cat /etc/config/qpkg.conf >> "$temp_pathfile"
    mv "$temp_pathfile" /etc/config/qpkg.conf

    }

SendToEnd()
    {

    # sends $1 to the end of qpkg.conf

    local buffer=$(ShowDataBlock "$1")

    if [[ $? -gt 0 ]]; then
        echo "error - ${buffer}!"
        return 2
    fi

    /sbin/rmcfg "$1" -f /etc/config/qpkg.conf
    echo -e "$buffer" >> /etc/config/qpkg.conf

    }

ShowDataBlock()
    {

    # returns the data block for the QPKG name specified as $1

    local -i sl=0       # line number: start of specified config block
    local -i ll=0       # line number: last line in file
    local -i bl=0       # total lines in specified config block
    local -i el=0       # line number: end of specified config block

    if [[ -z $1 ]]; then
        echo 'QPKG not specified'
        return 1
    fi

    if ! /bin/grep -q "$1" /etc/config/qpkg.conf; then
        echo 'QPKG not found'; return 2
    fi

    sl=$(/bin/grep -n "^\[$1\]" /etc/config/qpkg.conf | /usr/bin/cut -f1 -d':')
    ll=$(/usr/bin/wc -l < /etc/config/qpkg.conf | /bin/tr -d ' ')
    bl=$(/usr/bin/tail -n$((ll-sl)) < /etc/config/qpkg.conf | /bin/grep -n '^\[' | /usr/bin/head -n1 | /usr/bin/cut -f1 -d':')
    [[ $bl -ne 0 ]] && el=$((sl+bl-1)) || el=$ll

    /bin/sed -n "$sl,${el}p" /etc/config/qpkg.conf

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
    local -i rotate_limit=10

    # keep count of recursive calls
    local rec_limit=$((rotate_limit*2))
    local rec_count=0
    local rec_track_file=/tmp/${FUNCNAME[0]}.count
    [[ -e $rec_track_file ]] && rec_count=$(<"$rec_track_file")
    ((rec_count++))

    if [[ $rec_count -gt $rec_limit ]]; then
        echo 'recursive limit reached!'
        rm "$rec_track_file"
        exit 1
    fi

    echo "$rec_count" > "$rec_track_file"

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

    [[ -e $rec_track_file ]] && { rec_count=$(<"$rec_track_file"); ((rec_count--)); echo "$rec_count" > "$rec_track_file" ;}

    }

TrimLog()
    {

    local -i max_ops=10
    local op_lines=$(/bin/grep -n "^──" "$REAL_LOG_PATHFILE")
    local -i op_count=$(echo "$op_lines" | /usr/bin/wc -l)

    if [[ $op_count -gt $max_ops ]]; then
        local last_op_line_num=$(echo "$op_lines" | /usr/bin/head -n$((max_ops+1)) | /usr/bin/tail -n1 | /usr/bin/cut -f1 -d:)
        /usr/bin/head -n"${last_op_line_num}" "$REAL_LOG_PATHFILE" > "$TEMP_LOG_PATHFILE"
        mv "$TEMP_LOG_PATHFILE" "$REAL_LOG_PATHFILE"
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

    local buffer="[$(/bin/date)] '$1' requested"
    local -i length=${#buffer}
    local temp=$(printf "%${length}s")
    local build=$(/sbin/getcfg $QPKG_NAME Build -f /etc/config/qpkg.conf)

    echo -e "${temp// /─}\n$QPKG_NAME ($build)\n$buffer" >> "$TEMP_LOG_PATHFILE"

    LogWrite "'$1' requested" 0

    }

RecordOperationComplete()
    {

    # $1 = operation

    local buffer="[$(/bin/date)] '$1' completed"

    echo -e "$buffer" >> "$TEMP_LOG_PATHFILE"

    LogWrite "'$1' completed" 0
    SetServiceOperationResultOK

    }

SetServiceOperationResultOK()
    {

    SetServiceOperationResult ok

    }

SetServiceOperationResultFailed()
    {

    SetServiceOperationResult failed

    }

SetServiceOperationResult()
    {

    # $1 = result of operation to recorded

    [[ -n $1 && -n $SERVICE_STATUS_PATHFILE ]] && echo "$1" > "$SERVICE_STATUS_PATHFILE"

    }
ShowSectionTitle()
    {

    # $1 = description

    echo -e "\n * $1 *"

    }

CommitLog()
    {

    echo -e "$(<"$TEMP_LOG_PATHFILE")\n$(<"$REAL_LOG_PATHFILE")" > "$REAL_LOG_PATHFILE"

    TrimLog

    }

LogWrite()
    {

    # $1 = message to write into NAS system log
    # $2 = event type:
    #    0 : Information
    #    1 : Warning
    #    2 : Error

    log_tool --append "[$QPKG_NAME] $1" --type "$2"

    }

Init

case $1 in
    autofix)
        if [[ $(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f /etc/config/qpkg.conf) != "TRUE" ]]; then
            echo "$QPKG_NAME is disabled. You must first enable with: qpkg_service enable $QPKG_NAME"
            SetServiceOperationResultFailed
            exit 1
        fi
        RecordOperationRequest "$1"
        ShowSources >> "$TEMP_LOG_PATHFILE"
        Upshift /etc/config/qpkg.conf
        ShowPackagesBefore >> "$TEMP_LOG_PATHFILE"
        SortPackages
        ShowPackagesAfter >> "$TEMP_LOG_PATHFILE"
        RecordOperationComplete "$1"
        CommitLog
        ;;
    backup)
        RecordOperationRequest "$1"
        BackupConfig
        RecordOperationComplete "$1"
        CommitLog
        ;;
    fix)
        RecordOperationRequest "$1"
        ShowSources | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"
        Upshift /etc/config/qpkg.conf
        ShowPackagesBefore | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"
        SortPackages
        ShowPackagesAfter | /usr/bin/tee -a "$TEMP_LOG_PATHFILE"
        RecordOperationComplete "$1"
        CommitLog
        echo -e "\n Packages will be loaded in this order during next boot-up.\n"
        ;;
    init|stop|restart)
        # do nothing
        /bin/sleep 1
        ;;
    install|start)
        if ! /bin/grep -q 'sortmyqpkgs.sh' $SHUTDOWN_PATHFILE; then
            findtext='#backup logs'
            inserttext='/etc/init.d/sortmyqpkgs.sh autofix'
            /bin/sed -i "s|$findtext|$inserttext\n$findtext|" $SHUTDOWN_PATHFILE
        fi
        if [[ $1 = install ]]; then
            RecordOperationRequest "$1"
            RecordOperationComplete "$1"
            CommitLog
        fi
        ;;
    pref)
        ShowSources
        ShowPreferredList
        echo -e "\n To re-order packages: $0 fix\n"
        ;;
    remove)
        /bin/grep -q 'sortmyqpkgs.sh' $SHUTDOWN_PATHFILE && /bin/sed -i '/sortmyqpkgs.sh/d' $SHUTDOWN_PATHFILE
        [[ -L $GUI_LOG_PATHFILE ]] && rm -f $GUI_LOG_PATHFILE
        ;;
    reset)
        RecordOperationRequest "$1"
        ResetConfig
        RecordOperationComplete "$1"
        CommitLog
        ;;
    restore)
        RecordOperationRequest "$1"
        RestoreConfig
        RecordOperationComplete "$1"
        CommitLog
        ;;
    *)
        echo -e "\n Usage: $0 {backup|fix|pref|reset|restore}\n"
        ShowSources
        ShowPackagesCurrent
        echo -e "\n To re-order packages: $0 fix\n"
esac

[[ -e $TEMP_LOG_PATHFILE ]] && rm -f "$TEMP_LOG_PATHFILE"

exit 0
