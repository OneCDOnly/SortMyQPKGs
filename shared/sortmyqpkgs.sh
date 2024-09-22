#!/usr/bin/env bash
############################################################################
# sortmyqpkgs.sh
# 	copyright 2017-2024 OneCD
#
# Contact:
#	one.cd.only@gmail.com
#
# This script is part of the 'SortMyQPKGs' package
#
# Available in the MyQNAP store: https://www.myqnap.org/product/sortmyqpkgs
# Project source: https://github.com/OneCDOnly/SortMyQPKGs
# Community forum: https://forum.qnap.com/viewtopic.php?t=133132
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
# this program. If not, see http://www.gnu.org/licenses/
############################################################################

set -o nounset -o pipefail
shopt -s extglob
ln -fns /proc/self/fd /dev/fd		# KLUDGE: `/dev/fd` isn't always created by QTS.

readonly USER_ARGS_RAW=$*

Init()
    {

    readonly QPKG_NAME=SortMyQPKGs

    # KLUDGE: mark QPKG installation as complete.
    /sbin/setcfg "$QPKG_NAME" Status complete -f /etc/config/qpkg.conf

    # KLUDGE: 'clean' the QTS 4.5.1+ App Center notifier status.
    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$QPKG_NAME" > /dev/null 2>&1

    local actual_alpha_pathfile=''
    local actual_omega_pathfile=''

    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
		readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
	readonly LOG_GUI_PATHFILE=/home/httpd/$QPKG_NAME.log
	readonly LOG_LINK_PATHFILE=/var/log/$QPKG_NAME.log
    readonly QPKG_PATH=$(/sbin/getcfg "$QPKG_NAME" Install_Path -f /etc/config/qpkg.conf)
		readonly CUSTOM_ALPHA_PATHFILE=$QPKG_PATH/ALPHA.custom
		readonly CUSTOM_OMEGA_PATHFILE=$QPKG_PATH/OMEGA.custom
		local -r DEFAULT_ALPHA_PATHFILE=$QPKG_PATH/ALPHA.default
		local -r DEFAULT_OMEGA_PATHFILE=$QPKG_PATH/OMEGA.default
		readonly LOG_REAL_PATHFILE=$QPKG_PATH/$QPKG_NAME.log
			readonly LOG_TEMP_PATHFILE=$LOG_REAL_PATHFILE.tmp
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -f /etc/config/qpkg.conf)
	readonly SERVICE_ACTION_PATHFILE=/var/log/$QPKG_NAME.action
	readonly SERVICE_RESULT_PATHFILE=/var/log/$QPKG_NAME.result
    readonly SHUTDOWN_PATHFILE=/etc/init.d/shutdown_check.sh

    [[ -e $LOG_REAL_PATHFILE ]] || /bin/touch "$LOG_REAL_PATHFILE"
    [[ ! -e $LOG_TEMP_PATHFILE ]] || rm -f "$LOG_TEMP_PATHFILE"
    [[ -L $LOG_GUI_PATHFILE ]] || /bin/ln -s "$LOG_REAL_PATHFILE" "$LOG_GUI_PATHFILE"
    [[ -L $LOG_LINK_PATHFILE ]] || /bin/ln -s "$LOG_REAL_PATHFILE" "$LOG_LINK_PATHFILE"

    if [[ -e $CUSTOM_ALPHA_PATHFILE ]]; then
        actual_alpha_pathfile=$CUSTOM_ALPHA_PATHFILE
        source_alpha=custom
    elif [[ -e $DEFAULT_ALPHA_PATHFILE ]]; then
        actual_alpha_pathfile=$DEFAULT_ALPHA_PATHFILE
        source_alpha=default
    else
        echo 'ALPHA package list file not found'
        exit 1
    fi

    if [[ -e $CUSTOM_OMEGA_PATHFILE ]]; then
        actual_omega_pathfile=$CUSTOM_OMEGA_PATHFILE
        source_omega=custom
    elif [[ -e $DEFAULT_OMEGA_PATHFILE ]]; then
        actual_omega_pathfile=$DEFAULT_OMEGA_PATHFILE
        source_omega=default
    else
        echo 'OMEGA package list file not found'
        exit 1
    fi

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] || continue
        PKGS_ALPHA_ORDERED+=("$package_ref")
    done < "$actual_alpha_pathfile"

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] || continue
        PKGS_OMEGA_ORDERED+=("$package_ref")
    done < "$actual_omega_pathfile"

    }

StartQPKG()
	{

	if IsNotQPKGEnabled; then
		echo -e "This QPKG is disabled. Please enable it first with:\n\tqpkg_service enable $QPKG_NAME"
		return 1
	else
        AddHook
	fi

	}

Fix()
    {

    RecordOperationRequest fix
    ShowSources | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
    Upshift /etc/config/qpkg.conf
    ShowPackagesBefore | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
    SortPackages
    ShowPackagesAfter | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
    RecordOperationComplete fix
    CommitLog
    echo -e '\nPackages will be started in this order during next boot-up.\n'

    }

AutoFix()
	{

	RecordOperationRequest autofix
	ShowSources >> "$LOG_TEMP_PATHFILE"
	Upshift /etc/config/qpkg.conf
	ShowPackagesBefore >> "$LOG_TEMP_PATHFILE"
	SortPackages
	ShowPackagesAfter >> "$LOG_TEMP_PATHFILE"
	RecordOperationComplete autofix
	CommitLog

	}

StatusQPKG()
	{

	if /bin/grep -q 'sortmyqpkgs.sh' "$SHUTDOWN_PATHFILE"; then
		echo active
		exit 0
	else
		echo inactive
		exit 1
	fi

	}

BackupConfig()
    {

    local a=''
    local z=0

    RecordOperationRequest backup

    if [[ -e $CUSTOM_ALPHA_PATHFILE ]]; then
        a=$(/usr/bin/basename "$CUSTOM_ALPHA_PATHFILE")
    fi

    if [[ -e $CUSTOM_OMEGA_PATHFILE ]]; then
        [[ -n $a ]] && a+=' '
        a+=$(/usr/bin/basename "$CUSTOM_OMEGA_PATHFILE")
    fi

    if [[ -z $a ]]; then
        /bin/touch "$BACKUP_PATHFILE"
        echo 'nothing to backup' | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
        z=1
    else
        /bin/tar --create --gzip --file="$BACKUP_PATHFILE" --directory="$QPKG_PATH" "$a" | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
    fi

    RecordOperationComplete backup
    CommitLog

    return $z

    }

RestoreConfig()
    {

    local z=0

    RecordOperationRequest restore

    if [[ ! -s $BACKUP_PATHFILE ]]; then
        echo 'unable to restore: backup file is unusable!' | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"

        RecordOperationComplete restore
        CommitLog
        z=1
    else
        /bin/tar --extract --gzip --file="$BACKUP_PATHFILE" --directory="$QPKG_PATH" | /usr/bin/tee -a "$LOG_TEMP_PATHFILE"
        RecordOperationComplete restore
        CommitLog
    fi

    return $z

    }

ResetConfig()
    {

    RecordOperationRequest reset
    rm -f "$CUSTOM_ALPHA_PATHFILE" "$CUSTOM_OMEGA_PATHFILE"
    RecordOperationComplete reset
    CommitLog

    }

AddHook()
    {

	if ! /bin/grep -q 'sortmyqpkgs.sh' $SHUTDOWN_PATHFILE; then
		findtext='#backup logs'
		inserttext='/etc/init.d/sortmyqpkgs.sh autofix'
		/bin/sed -i "s|$findtext|$inserttext\n$findtext|" "$SHUTDOWN_PATHFILE"
        echo 'shutdown hook has been added'
    fi

    }

RemoveHook()
    {

    if /bin/grep -q 'sortmyqpkgs.sh' "$SHUTDOWN_PATHFILE"; then
        /bin/sed -i '/sortmyqpkgs.sh/d' "$SHUTDOWN_PATHFILE"
        echo 'shutdown hook has been removed'
    fi

    }

ShowTitle()
    {

    echo "$(ShowAsTitleName) $(ShowAsVersion)"

    }

ShowAsTitleName()
	{

	TextBrightWhite $QPKG_NAME

	}

ShowAsVersion()
	{

	printf '%s' "v$QPKG_VERSION"

	}

ShowAsUsage()
    {

	echo -e "\nUsage: $0 {backup|fix|pref|reset|restart|restore|status}\n"
	ShowSources
	ShowPackagesCurrent
	echo -e "\nTo re-order packages:\n\t$0 fix"

	}

ShowPreferredList()
    {

    ShowSectionTitle 'Preferred order'
    echo -e "< installed packages are indicated with '#' >\n"
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

    local a=''
    local -i n=0

    for pref in "${PKGS_ALPHA_ORDERED[@]}"; do
        ((n++)); printf -v a '%03d' "$n"

        if (/bin/grep -qF "[$pref]" /etc/config/qpkg.conf); then
            ShowLineMarked "$a" A "$pref"
        else
            ShowLineUnmarked "$a" A "$pref"
        fi
    done

    echo
    ((n++)); printf -v a '%03d' "$n"; ShowLineUnmarked "$a" Φ '< existing unspecified packages go here >'
    echo

    for pref in "${PKGS_OMEGA_ORDERED[@]}"; do
        ((n++)); printf -v a '%03d' "$n"

        if (/bin/grep -qF "[$pref]" /etc/config/qpkg.conf); then
            ShowLineMarked "$a" Ω "$pref"
        else
            ShowLineUnmarked "$a" Ω "$pref"
        fi
    done

    }

ShowPackagesUnmarked()
    {

    local a=''
    local b=''
    local c=''
    local d=''
    local e=''
    local -i n=0

    for a in $(/bin/grep '^\[.*\]$' /etc/config/qpkg.conf); do
        b=${a//[\[\]]}
        ((n++)); printf -v c '%02d' "$n"
        d=$(ShowLineUnmarked "$c" Φ "$b")

        for e in "${PKGS_ALPHA_ORDERED[@]}"; do
            [[ $b = "$e" ]] || continue
            d=$(ShowLineUnmarked "$c" A "$b")
            break
        done

        for e in "${PKGS_OMEGA_ORDERED[@]}"; do
            [[ $b = "$e" ]] || continue
            d=$(ShowLineUnmarked "$c" Ω "$b")
            break
        done

        echo -e "$d"
    done

    }

ShowSources()
    {

    echo "ALPHA=$source_alpha, OMEGA=$source_omega"

    }

SortPackages()
    {

    local a=''
    local -i i=0

    echo -ne '\nsorting packages ... '

    # Read 'ALPHA' packages in-reverse and prepend each to /etc/config/qpkg.conf
    for ((i=${#PKGS_ALPHA_ORDERED[@]}-1; i>=0; i--)); do
		a=${PKGS_ALPHA_ORDERED[$i]}
		/bin/grep -q "^\[$a\]" /etc/config/qpkg.conf && MoveConfigToTop "$a"
    done

    # Now, read 'OMEGA' packages and append each to /etc/config/qpkg.conf
    for a in "${PKGS_OMEGA_ORDERED[@]}"; do
		/bin/grep -q "^\[$a\]" /etc/config/qpkg.conf && MoveConfigToBottom "$a"
    done

    echo 'done'

    }

MoveConfigToTop()
    {

    # Move $1 to the top of /etc/config/qpkg.conf

    [[ -n ${1:-} ]] || return

    local a=''

    a=$(GetConfigBlock "$1")
    [[ -n $a ]] || return

    /sbin/rmcfg "$1" -f /etc/config/qpkg.conf
    echo -e "$a" > /tmp/qpkg.conf.tmp
    /bin/cat /etc/config/qpkg.conf >> /tmp/qpkg.conf.tmp
    mv /tmp/qpkg.conf.tmp /etc/config/qpkg.conf

    }

MoveConfigToBottom()
    {

    # Move $1 to the bottom of /etc/config/qpkg.conf

    [[ -n ${1:-} ]] || return

    local a=''

    a=$(GetConfigBlock "$1")
    [[ -n $a ]] || return

    /sbin/rmcfg "$1" -f /etc/config/qpkg.conf
    echo -e "\n${a}" >> /etc/config/qpkg.conf

    }

GetConfigBlock()
    {

    # Return the config block for the QPKG name specified as $1

    [[ -n ${1:-} ]] || return

    local -i sl=0       # line number: start of specified config block
    local -i ll=0       # line number: last line in file
    local -i bl=0       # total lines in specified config block
    local -i el=0       # line number: end of specified config block

    sl=$(/bin/grep -n "^\[$1\]" /etc/config/qpkg.conf | /usr/bin/cut -f1 -d':')
    [[ -n $sl ]] || return

    ll=$(/usr/bin/wc -l < /etc/config/qpkg.conf | /bin/tr -d ' ')
    bl=$(/usr/bin/tail -n$((ll-sl)) < /etc/config/qpkg.conf | /bin/grep -n '^\[' | /usr/bin/head -n1 | /usr/bin/cut -f1 -d':')

    [[ $bl -ne 0 ]] && el=$((sl+bl-1)) || el=$ll
    [[ -n $el ]] || return

    echo -e "$(/bin/sed -n "$sl,${el}p" /etc/config/qpkg.conf)"     # Output this with 'echo' to strip trailing LFs from config block.

    }

Upshift()
    {

    # Move specified existing filename by incrementing extension value (upshift extension).
    # If extension is not a number, then create new extension of '1' and copy file.

    # $1 = pathfilename to upshift

    [[ -n $1 ]] || return
    [[ -e $1 ]] || return

    local ext=''
    local dest=''
    local -i rotate_limit=10

    # Keep count of recursive calls.
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
        *[!0-9]*)   # Specified file extension is not a number so add number and copy it.
            dest="$1.1"
            [[ -e $dest ]] && Upshift "$dest"
            cp "$1" "$dest"
            ;;
        *)          # Extension IS a number, so move it if possible.
            if [[ $ext -lt $((rotate_limit-1)) ]]; then
                ((ext++)); dest="${1%.*}.$ext"
                [[ -e $dest ]] && Upshift "$dest"
                mv "$1" "$dest"
            else
                rm "$1"
            fi
    esac

    [[ -e $rec_track_file ]] && { rec_count=$(<"$rec_track_file"); ((rec_count--)); echo "$rec_count" > "$rec_track_file" ;}

    }

TrimLog()
    {

    local -i max_ops=10
    local op_lines=''
    local -i op_count=0
	local -i last_op_line_num=0

	op_lines=$(/bin/grep -n '^──' "$LOG_REAL_PATHFILE")
    op_count=$(/usr/bin/wc -l <<< "$op_lines")

    if [[ $op_count -gt $max_ops ]]; then
        last_op_line_num=$(echo "$op_lines" | /usr/bin/head -n$((max_ops+1)) | /usr/bin/tail -n1 | /usr/bin/cut -f1 -d:)
        /usr/bin/head -n"${last_op_line_num}" "$LOG_REAL_PATHFILE" > "$LOG_TEMP_PATHFILE"
        mv "$LOG_TEMP_PATHFILE" "$LOG_REAL_PATHFILE"
    fi

    }

ShowLineUnmarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    printf '(%s) (%s) %s\n' "$1" "$2" "$3"

    }

ShowLineMarked()
    {

    # $1 = number
    # $2 = symbol
    # $3 = name

    printf '(%s)#(%s) %s\n' "$1" "$2" "$3"

    }

RecordOperationRequest()
    {

    # $1 = Operation.

    local a=''
    local -i b=0
    local c=''

    a="[$(/bin/date)] '$1' requested"
    b=${#a}
    printf -v c "%${b}s"

    echo -e "${c// /─}\n$QPKG_NAME ($(/sbin/getcfg "$QPKG_NAME" Build -f /etc/config/qpkg.conf))\n$a" >> "$LOG_TEMP_PATHFILE"

    LogWrite "'$1' requested" 0

    }

RecordOperationComplete()
    {

    # $1 = Operation.

    echo -e "[$(/bin/date)] '$1' completed" >> "$LOG_TEMP_PATHFILE"

    LogWrite "'$1' completed" 0

    }

ShowSectionTitle()
    {

    # $1 = Description.

    printf '\n * %s *\n' "$1"

    }

CommitLog()
    {

    echo -e "$(<"$LOG_TEMP_PATHFILE")\n$(<"$LOG_REAL_PATHFILE")" > "$LOG_REAL_PATHFILE"

    TrimLog

    }

LogWrite()
    {

    # $1 = Message to write into NAS system log.
    # $2 = Event type:
    #    0 : Information
    #    1 : Warning
    #    2 : Error

    log_tool --append "[$QPKG_NAME] $1" --type "$2"

    }

IsQPKGEnabled()
	{

	# input:
	#   $1 = (optional) package name to check. If unspecified, default is $QPKG_NAME

	# output:
	#   $? = 0 : true
	#   $? = 1 : false

	[[ $(Lowercase "$(/sbin/getcfg "${1:-$QPKG_NAME}" Enable -d false -f /etc/config/qpkg.conf)") = true ]]

	}

IsNotQPKGEnabled()
	{

	# input:
	#   $1 = (optional) package name to check. If unspecified, default is $QPKG_NAME

	# output:
	#   $? = 0 : true
	#   $? = 1 : false

	! IsQPKGEnabled "${1:-$QPKG_NAME}"

	}

SetServiceAction()
	{

	service_action=${1:-none}
	CommitServiceAction
	SetServiceResultAsInProgress

	}

SetServiceResultAsOK()
	{

	service_result=ok
	CommitServiceResult

	}

SetServiceResultAsFailed()
	{

	service_result=failed
	CommitServiceResult

	}

SetServiceResultAsInProgress()
	{

	# Selected action is in-progress and hasn't generated a result yet.

	service_result=in-progress
	CommitServiceResult

	}

CommitServiceAction()
	{

    echo "$service_action" > "$SERVICE_ACTION_PATHFILE"

	}

CommitServiceResult()
	{

    echo "$service_result" > "$SERVICE_RESULT_PATHFILE"

	}

TextBrightWhite()
	{

	[[ -n ${1:-} ]] || return

    printf '\033[1;97m%s\033[0m' "$1"

	}

Lowercase()
	{

	/bin/tr 'A-Z' 'a-z' <<< "$1"

	}

Init

user_arg=${USER_ARGS_RAW%% *}		# Only process first argument.

case $user_arg in
    autofix)
        AutoFix
        ;;
    ?(-)b|?(--)backup)
        SetServiceAction backup

        if BackupConfig; then
            SetServiceResultAsOK
        else
            SetServiceResultAsFailed
        fi
        ;;
    ?(--)fix)
        Fix
        ;;
    init|?(--)stop)         # Ignore these.
        /bin/sleep 1
        ;;
    ?(--)restart)
        SetServiceAction restart

        if RemoveHook && StartQPKG; then
            SetServiceResultAsOK
        else
            SetServiceResultAsFailed
        fi
        ;;
    ?(--)pref)
        ShowSources
        ShowPreferredList
        echo -e "\nTo re-order packages: $0 fix\n"
        ;;
    remove)
        RemoveHook
        ;;
    ?(--)reset)
        ResetConfig
        ;;
    ?(--)restore)
        SetServiceAction restore

        if RestoreConfig; then
            SetServiceResultAsOK
        else
            SetServiceResultAsFailed
        fi
        ;;
    install)
        SetServiceAction install
        RecordOperationRequest install

        if StartQPKG; then
            SetServiceResultAsOK
            CommitLog
        else
            SetServiceResultAsFailed
        fi

        RecordOperationComplete install
        ;;
    ?(--)start)
        SetServiceAction start

        if StartQPKG; then
            SetServiceResultAsOK
        else
            SetServiceResultAsFailed
        fi
        ;;
    ?(-)s|?(--)status)
        StatusQPKG
        ;;
    *)
        ShowTitle
        ShowAsUsage
esac

rm -f "$LOG_TEMP_PATHFILE"

exit 0
