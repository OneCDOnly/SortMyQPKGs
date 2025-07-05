#!/usr/bin/env bash
############################################################################
# sortmyqpkgs.sh
# 	Copyright 2017-2025 OneCD
#
# Contact:
#	one.cd.only@gmail.com
#
# Description:
#	This script is part of the 'SortMyQPKGs' package
#
# Available in the MyQNAP store:
#	https://www.myqnap.org/product/sortmyqpkgs
#
# And via the sherpa package manager:
#	https://git.io/sherpa
#
# Project source:
#	https://github.com/OneCDOnly/SortMyQPKGs
#
# Community forum:
#	https://community.qnap.com/t/qpkg-sortmyqpkgs/1095
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
[[ -L /dev/fd ]] || ln -fns /proc/self/fd /dev/fd		# KLUDGE: `/dev/fd` isn't always created by QTS.
readonly r_user_args_raw=$*

Init()
    {

    readonly r_qpkg_name=SortMyQPKGs

    # KLUDGE: mark QPKG installation as complete.

    /sbin/setcfg $r_qpkg_name Status complete -f /etc/config/qpkg.conf

    # KLUDGE: 'clean' the QTS 4.5.1+ App Center notifier status.

    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean $r_qpkg_name &> /dev/null

    local actual_alpha_pathfile=''
    local actual_omega_pathfile=''

    local -r r_backup_path=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
		readonly r_backup_pathfile=$r_backup_path/$r_qpkg_name.config.tar.gz
	readonly r_log_gui_pathfile=/home/httpd/$r_qpkg_name.log
	readonly r_log_link_pathfile=/var/log/$r_qpkg_name.log
    readonly r_qpkg_path=$(/sbin/getcfg $r_qpkg_name Install_Path -f /etc/config/qpkg.conf)
		readonly r_custom_alpha_pathfile=$r_qpkg_path/ALPHA.custom
		readonly r_custom_omega_pathfile=$r_qpkg_path/OMEGA.custom
		local -r r_default_alpha_pathfile=$r_qpkg_path/ALPHA.default
		local -r r_default_omega_pathfile=$r_qpkg_path/OMEGA.default
		readonly r_log_real_pathfile=$r_qpkg_path/$r_qpkg_name.log
			readonly r_log_temp_pathfile=$r_log_real_pathfile.tmp
    readonly r_qpkg_version=$(/sbin/getcfg $r_qpkg_name Version -f /etc/config/qpkg.conf)
	readonly r_service_action_pathfile=/var/log/$r_qpkg_name.action
	readonly r_service_result_pathfile=/var/log/$r_qpkg_name.result
    readonly r_shutdown_pathfile=/etc/init.d/shutdown_check.sh

    [[ -e $r_log_real_pathfile ]] || /bin/touch "$r_log_real_pathfile"
    [[ ! -e $r_log_temp_pathfile ]] || rm -f "$r_log_temp_pathfile"
    [[ -L $r_log_gui_pathfile ]] || /bin/ln -s "$r_log_real_pathfile" "$r_log_gui_pathfile"
    [[ -L $r_log_link_pathfile ]] || /bin/ln -s "$r_log_real_pathfile" "$r_log_link_pathfile"

    if [[ -e $r_custom_alpha_pathfile ]]; then
        actual_alpha_pathfile=$r_custom_alpha_pathfile
        source_alpha=custom
    elif [[ -e $r_default_alpha_pathfile ]]; then
        actual_alpha_pathfile=$r_default_alpha_pathfile
        source_alpha=default
    else
        echo 'ALPHA package list file not found'
        exit 1
    fi

    if [[ -e $r_custom_omega_pathfile ]]; then
        actual_omega_pathfile=$r_custom_omega_pathfile
        source_omega=custom
    elif [[ -e $r_default_omega_pathfile ]]; then
        actual_omega_pathfile=$r_default_omega_pathfile
        source_omega=default
    else
        echo 'OMEGA package list file not found'
        exit 1
    fi

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] || continue
        pkgs_alpha_ordered+=("$package_ref")
    done < "$actual_alpha_pathfile"

    while read -r package_ref comment; do
        [[ -n $package_ref && $package_ref != \#* ]] || continue
        pkgs_omega_ordered+=("$package_ref")
    done < "$actual_omega_pathfile"

    }

StartQPKG()
	{

	if IsNotQPKGEnabled; then
		echo -e "This QPKG is disabled. Please enable it first with:\n\tqpkg_service enable $r_qpkg_name"
		return 1
	else
        AddHook
	fi

	}

Fix()
    {

    RecordOperationRequest fix
    ShowSources | /usr/bin/tee -a "$r_log_temp_pathfile"
    Upshift /etc/config/qpkg.conf
    ShowPackagesBefore | /usr/bin/tee -a "$r_log_temp_pathfile"
    SortPackages
    ShowPackagesAfter | /usr/bin/tee -a "$r_log_temp_pathfile"
    RecordOperationComplete fix
    CommitLog
    echo -e '\nPackages will be started in this order during next boot-up.\n'

    }

AutoFix()
	{

	RecordOperationRequest autofix
	ShowSources >> "$r_log_temp_pathfile"
	Upshift /etc/config/qpkg.conf
	ShowPackagesBefore >> "$r_log_temp_pathfile"
	SortPackages
	ShowPackagesAfter >> "$r_log_temp_pathfile"
	RecordOperationComplete autofix
	CommitLog

	}

StatusQPKG()
	{

	if /bin/grep 'sortmyqpkgs.sh' "$r_shutdown_pathfile" &> /dev/null; then
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

    if [[ -e $r_custom_alpha_pathfile ]]; then
        a=$(/usr/bin/basename "$r_custom_alpha_pathfile")
    fi

    if [[ -e $r_custom_omega_pathfile ]]; then
        [[ -n $a ]] && a+=' '
        a+=$(/usr/bin/basename "$r_custom_omega_pathfile")
    fi

    if [[ -z $a ]]; then
        /bin/touch "$r_backup_pathfile"
        echo 'nothing to backup' | /usr/bin/tee -a "$r_log_temp_pathfile"
        z=1
    else
        /bin/tar --create --gzip --file="$r_backup_pathfile" --directory="$r_qpkg_path" "$a" | /usr/bin/tee -a "$r_log_temp_pathfile"
    fi

    RecordOperationComplete backup
    CommitLog

    return $z

    }

RestoreConfig()
    {

    local z=0

    RecordOperationRequest restore

    if [[ ! -s $r_backup_pathfile ]]; then
        echo 'unable to restore: backup file is unusable!' | /usr/bin/tee -a "$r_log_temp_pathfile"

        RecordOperationComplete restore
        CommitLog
        z=1
    else
        /bin/tar --extract --gzip --file="$r_backup_pathfile" --directory="$r_qpkg_path" | /usr/bin/tee -a "$r_log_temp_pathfile"
        RecordOperationComplete restore
        CommitLog
    fi

    return $z

    }

ResetConfig()
    {

    RecordOperationRequest reset
    rm -f "$r_custom_alpha_pathfile" "$r_custom_omega_pathfile"
    RecordOperationComplete reset
    CommitLog

    }

AddHook()
    {

	if ! /bin/grep 'sortmyqpkgs.sh' $r_shutdown_pathfile &> /dev/null; then
		findtext='#backup logs'
		inserttext='/etc/init.d/sortmyqpkgs.sh autofix'
		/bin/sed -i "s|$findtext|$inserttext\n$findtext|" "$r_shutdown_pathfile"
        echo 'shutdown hook has been added'
    fi

    }

RemoveHook()
    {

    if /bin/grep 'sortmyqpkgs.sh' "$r_shutdown_pathfile" &> /dev/null; then
        /bin/sed -i '/sortmyqpkgs.sh/d' "$r_shutdown_pathfile"
        echo 'shutdown hook has been removed'
    fi

    }

ShowTitle()
    {

    echo "$(ShowAsTitleName) $(ShowAsVersion)"

    }

ShowAsTitleName()
	{

	TextBrightWhite $r_qpkg_name

	}

ShowAsVersion()
	{

	printf '%s' "v$r_qpkg_version"

	}

ShowAsUsage()
    {

	echo -e "\nUsage: $0 {backup|fix|pref|reset|restart|restore|status}\n"
	ShowSources
	ShowPackagesCurrent
	echo -e "\nTo re-order packages:\n\t$0 now"

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

    for pref in "${pkgs_alpha_ordered[@]}"; do
        ((n++)); printf -v a '%03d' "$n"

        if (/bin/grep -F "[$pref]" /etc/config/qpkg.conf &> /dev/null); then
            ShowLineMarked "$a" A "$pref"
        else
            ShowLineUnmarked "$a" A "$pref"
        fi
    done

    echo
    ((n++)); printf -v a '%03d' "$n"; ShowLineUnmarked "$a" Φ '< existing unspecified packages go here >'
    echo

    for pref in "${pkgs_omega_ordered[@]}"; do
        ((n++)); printf -v a '%03d' "$n"

        if (/bin/grep -F "[$pref]" /etc/config/qpkg.conf &> /dev/null); then
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

        for e in "${pkgs_alpha_ordered[@]}"; do
            [[ $b = "$e" ]] || continue
            d=$(ShowLineUnmarked "$c" A "$b")
            break
        done

        for e in "${pkgs_omega_ordered[@]}"; do
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

    # Remove whitespace lines

    /bin/sed -i '/^$/d' /etc/config/qpkg.conf

    # Read 'ALPHA' packages in-reverse and prepend each to /etc/config/qpkg.conf

    for ((i=${#pkgs_alpha_ordered[@]}-1; i>=0; i--)); do
		a=${pkgs_alpha_ordered[$i]}
		/bin/grep "^\[$a\]" /etc/config/qpkg.conf &> /dev/null && MoveConfigToTop "$a"
    done

    # Now, read 'OMEGA' packages and append each to /etc/config/qpkg.conf

    for a in "${pkgs_omega_ordered[@]}"; do
		/bin/grep "^\[$a\]" /etc/config/qpkg.conf &> /dev/null && MoveConfigToBottom "$a"
    done

    # Re-add whitespace lines (between config blocks) only.

	/bin/sed -i -e ':a' -e 'N' -e '$!ba' -e 's/\n\[/\n\n\[/g' /etc/config/qpkg.conf

    echo 'done'

    }

MoveConfigToTop()
    {

    # Move $1 (QPKG name) to the top of /etc/config/qpkg.conf

    [[ -n ${1:-} ]] || return

    local a=''

    a=$(GetConfigBlock ${1:-})
    [[ -n $a ]] || return

    /sbin/rmcfg ${1:-} -f /etc/config/qpkg.conf
    echo -e "$a" > /tmp/qpkg.conf.tmp
    /bin/cat /etc/config/qpkg.conf >> /tmp/qpkg.conf.tmp
    mv /tmp/qpkg.conf.tmp /etc/config/qpkg.conf

    }

MoveConfigToBottom()
    {

    # Move $1 (QPKG name) to the bottom of /etc/config/qpkg.conf

    [[ -n ${1:-} ]] || return

    local a=''

    a=$(GetConfigBlock ${1:-})
    [[ -n $a ]] || return

    /sbin/rmcfg ${1:-} -f /etc/config/qpkg.conf
    echo -e "$a" >> /etc/config/qpkg.conf

    }

GetConfigBlock()
    {

    # Output the config block for $1 (QPKG name).

    [[ -n ${1:-} ]] || return

    local -i sl=0       # start line number of config block.
    local -i ll=0       # last line number in file.
    local -i tl=0       # total lines in config block.
    local -i el=0       # end line number of config block.

    sl=$(/bin/grep -n "^\[${1:-}\]" /etc/config/qpkg.conf | /usr/bin/cut -f1 -d':')
    [[ -n $sl ]] || return

    ll=$(/usr/bin/wc -l < /etc/config/qpkg.conf | /bin/tr -d ' ')
    tl=$(/usr/bin/tail -n$((ll-sl)) < /etc/config/qpkg.conf | /bin/grep -n '^\[' | /usr/bin/head -n1 | /usr/bin/cut -f1 -d':')

    [[ $tl -ne 0 ]] && el=$((sl+tl-1)) || el=$ll
    [[ -n $el ]] || return

    echo -e "$(/bin/sed -n "$sl,${el}p" /etc/config/qpkg.conf)"     # Output this with 'echo' to strip trailing LFs from config block.

    }

Upshift()
    {

    # Move specified existing filename by incrementing extension value (upshift extension).
    # If extension is not a number, then create new extension of '1' and copy file.

	# Inputs: (local)
    #	$1 = pathfilename to upshift

    [[ -n ${1:-} ]] || return
    [[ -e ${1:-} ]] || return

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
            dest="${1:-}.1"
            [[ -e $dest ]] && Upshift "$dest"
            cp "${1:-}" "$dest"
            ;;
        *)          # Extension IS a number, so move it if possible.
            if [[ $ext -lt $((rotate_limit-1)) ]]; then
                ((ext++)); dest="${1%.*}.$ext"
                [[ -e $dest ]] && Upshift "$dest"
                mv "${1:-}" "$dest"
            else
                rm "${1:-}"
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

	op_lines=$(/bin/grep -n '^──' "$r_log_real_pathfile")
    op_count=$(/usr/bin/wc -l <<< "$op_lines")

    if [[ $op_count -gt $max_ops ]]; then
        last_op_line_num=$(echo "$op_lines" | /usr/bin/head -n$((max_ops+1)) | /usr/bin/tail -n1 | /usr/bin/cut -f1 -d:)
        /usr/bin/head -n"${last_op_line_num}" "$r_log_real_pathfile" > "$r_log_temp_pathfile"
        mv "$r_log_temp_pathfile" "$r_log_real_pathfile"
    fi

    }

ShowLineUnmarked()
    {

	# Inputs: (local)
    #	$1 = number
    #	$2 = symbol
    #	$3 = name

    printf '(%s) (%s) %s\n' "${1:-}" "${2:-}" "${3:-}"

    }

ShowLineMarked()
    {

	# Inputs: (local)
    #	$1 = number
    #	$2 = symbol
    #	$3 = name

    printf '(%s)#(%s) %s\n' "${1:-}" "${2:-}" "${3:-}"

    }

RecordOperationRequest()
    {

	# Inputs: (local)
    #	$1 = Operation.

    local a=''
    local -i b=0
    local c=''

    a="[$(/bin/date)] '${1:-}' requested"
    b=${#a}
    printf -v c "%${b}s"

    echo -e "${c// /─}\n$r_qpkg_name ($(/sbin/getcfg $r_qpkg_name Build -f /etc/config/qpkg.conf))\n$a" >> "$r_log_temp_pathfile"

    LogWrite "'${1:-}' requested" 0

    }

RecordOperationComplete()
    {

	# Inputs: (local)
    #	$1 = Operation.

    echo -e "[$(/bin/date)] '${1:-}' completed" >> "$r_log_temp_pathfile"

    LogWrite "'${1:-}' completed" 0

    }

ShowSectionTitle()
    {

	# Inputs: (local)
    #	$1 = Description.

    printf '\n * %s *\n' "${1:-}"

    }

CommitLog()
    {

    echo -e "$(<"$r_log_temp_pathfile")\n$(<"$r_log_real_pathfile")" > "$r_log_real_pathfile"

    TrimLog

    }

LogWrite()
    {

	# Inputs: (local)
    #	$1 = Message to write into NAS system log.
    #	$2 = Event type:
    #		0 : Information
    #		1 : Warning
    #		2 : Error

    /sbin/log_tool --append "[$r_qpkg_name] ${1:-}" --type "${2:-}"

    }

IsQPKGEnabled()
	{

	# Inputs: (local)
	#   $1 = (optional) package name to check. If unspecified, default is $r_qpkg_name

	# Outputs: (local)
	#   $? = 0 : true
	#   $? = 1 : false

	[[ $(Lowercase "$(/sbin/getcfg ${1:-$r_qpkg_name} Enable -d false -f /etc/config/qpkg.conf)") = true ]]

	}

IsNotQPKGEnabled()
	{

	# Inputs: (local)
	#   $1 = (optional) package name to check. If unspecified, default is $r_qpkg_name

	# Outputs: (local)
	#   $? = 0 : true
	#   $? = 1 : false

	! IsQPKGEnabled "${1:-$r_qpkg_name}"

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

    echo "$service_action" > "$r_service_action_pathfile"

	}

CommitServiceResult()
	{

    echo "$service_result" > "$r_service_result_pathfile"

	}

TextBrightWhite()
	{

	[[ -n ${1:-} ]] || return

    printf '\033[1;97m%s\033[0m' "${1:-}"

	}

Lowercase()
	{

	/bin/tr 'A-Z' 'a-z' <<< "${1:-}"

	}

Init

user_arg=${r_user_args_raw%% *}		# Only process first argument.

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
    init|?(--)stop)         # Ignore these.
        /bin/sleep 1
        ;;
    ?(--)now)
        ShowTitle
        echo
        Fix
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
        echo -e "\nTo re-order packages:\n\t$0 now"
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

rm -f "$r_log_temp_pathfile"

exit 0
