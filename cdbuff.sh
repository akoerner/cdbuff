#!/usr/bin/env bash


set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

echoerr (){ printf "$@" >&2;}
exiterr (){ echoerr "$@\n"; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

DEFAULT_REGISTER="primary"
DEFAULT_REGISTER_FILE="${HOME}/.cdbuff"
DEFAULT_HISTORY_FILE="${HOME}/.cdbuff_history"
cdbuff_file="${CDBUFF_FILE:-$DEFAULT_REGISTER_FILE}"
cdbuff_history_file="${CDBUFF_HISTORY_FILE:-$DEFAULT_HISTORY_FILE}"


_help() {
    cat << EOF 
NAME
    cdbuff - cd but with memory and history 

    Grandpa's cd with registers, less typey more workey

SYNOPSIS
  USAGE
    cdbuff -s             Set the 'primary' named register to the current working directory
    cdbuff                Change directory to path stored in the  'primary' named register
 
    cdbuff test           Change directory to the path stored with the 'test' register
    cdbuff -s test        Create a new named register called 'test' and save the current working directory 
    cdbuff -d primary     Delete the primary register
    cdbuff -d 3           Delete register at index 3
    cdbuff -l             List all defined registers with access counts and last access time
    cdbuff -p             Print the primary register and exit
    cdbuff -t <register>  Show statistics for a specific register 
    cdbuff -P             Prune all dead registers (registers with paths that no longer exist)
    cb 7                  cd to directory in indexed register 7

DESCRIPTION
    'cdbuff' or 'cb' is an enhancement to the 'cd' command adding named registers and a 
    circular index register, similar to vim, that can be saved and restored 
    on-demand. Duck and weave through your file system like a ninja. The 
    features include:
    - Saving directories as a named register
    - Vim like circular register 
    - cd'ing to named and indexed registers
    - list available registers
    - managing named registers i.e., deleting them
    - tracking access history with a cdbuff hist file: ${DEFAULT_HISTORY_FILE}
    - viewing register statistics

OPTIONS

    -h, --help             Print this help and exit
    -f, --register-file    cdbuff register file 
                             Default: "${DEFAULT_REGISTER_FILE}"
    -d, --delete           Delete named register
    -p, --print            Print the `primary` register and exit 
    -n, --nuke             Delete all registers in the register file 
    -D, --dump             cat the register file 
    -v, --verbose          verbose output
    -S, --stats            Show access statistics for a specified register
    -P, --prune-dead       Delete all dead registers (paths that no longer exist)

    The default register is always "${DEFAULT_REGISTER}" unless specified 
EOF
    exit
} 

confirm() {
    while true; do
        read -p "All registers in the register file: ${register_file} will be deleted. Do you want to continue? (y/n): " choice
        case "$choice" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer 'yes' or 'no'.";;
        esac
    done
}

confirm_prune() {
    while true; do
        read -p "All dead registers (paths that no longer exist) will be deleted from ${register_file}. Do you want to continue? (y/n): " choice
        case "$choice" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer 'yes' or 'no'.";;
        esac
    done
}

get_access_count() {
    local register="$1"
    local register_path="$2"
    local history_file="$3"
    
    if [[ ! -f "${history_file}" ]]; then
        echo "0"
        return
    fi
    
    local count=$(grep -c "^${register}@${register_path}@" "${history_file}")
    echo "${count}"
}

get_last_access() {
    local register="$1"
    local register_path="$2"
    local history_file="$3"
    
    if [[ ! -f "${history_file}" ]]; then
        echo "Never"
        return
    fi
    
    local last_access=$(grep "^${register}@${register_path}@" "${history_file}" | tail -1 | cut -d '@' -f 3)
    if [[ -z "$last_access" ]]; then
        echo "Never"
    else
        echo "$last_access"
    fi
}

check_path_exists() {
    local path="$1"
    if [[ -z "$path" ]]; then
        return 1
    fi
    if [[ ! -d "$path" ]]; then
        return 1
    fi
    return 0
}

get_dead_register_count() {
    local register_file="${1:-${DEFAULT_REGISTER_FILE}}"
    local dead_register_count=0
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        register=$(echo "$line" | cut -d '@' -f 1)
        path=$(echo "$line" | cut -d '@' -f 2-)
        
        if [[ "$register" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        if ! check_path_exists "$path"; then
            dead_register_count=$((dead_register_count + 1))
        fi
    done < "$register_file"
    echo $dead_register_count
}

prune_dead_registers() {
    local register_file="$1"
    local history_file="$2"
    
    local dead_register_count="$(get_dead_register_count "$register_file")"
    
    if [ "${dead_register_count}" -eq 0 ]; then
        echo "Nothing to prune."
        return
    fi
    
        echo $(bold "Dead registers:")

        named_registers="$(cat "${register_file}" | sed -n '/^[0-9]@/!p')"
        
        if [[ -n "$named_registers" ]]; then
            while IFS= read -r register_line; do
                register=$(echo "$register_line" | cut -d '@' -f 1)
                path=$(echo "$register_line" | cut -d '@' -f 2-)
            
                if ! check_path_exists "$path"; then
                    echo " $(emphasis "DEAD PATH" "red")"
                fi
            done <<< "$named_registers"
        fi 

    
    if ! confirm; then
        return
    fi
    
    echo "Pruning dead registers..."

    if [[ -n "$named_registers" ]]; then
        while IFS= read -r register_line; do
            register=$(echo "$register_line" | cut -d '@' -f 1)
            path=$(echo "$register_line" | cut -d '@' -f 2-)
        
            if ! check_path_exists "$path"; then
               delete_register "${register}" "${register_file}"
                echo "$(emphasis "Pruned:" "red") ${register}@${path}"
            fi
        done <<< "$named_registers"
    fi 

    echo "Pruning complete. Removed $pruned_count dead registers."
    
    numerical_registers_init "${register_file}"
}


list_registers(){
    register_file="${1}"
    history_file="${2}"

    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi
    
    pad_never() {
        local input="$1"
        if [[ "$input" == "Never" ]]; then
            echo "Never"
        else
            echo "$input"
        fi
    }
    
    local tmp_active=$(mktemp)
    local tmp_dead=$(mktemp)
    
    echo $(bold "Numerical registers:")
    numerical_registers="$(cat ${register_file} | sed -n '/^[0-9]@/p')"
    if [[ -n "$numerical_registers" ]]; then
        while IFS= read -r register_line; do
            register=$(echo "$register_line" | cut -d '@' -f 1)
            path=$(echo "$register_line" | cut -d '@' -f 2-)
            count=$(get_access_count "$register" "$path" "$history_file")
            padded_last_access=$(pad_never "$(get_last_access "$register" "$path" "$history_file")")
            
            output_line="    $(bold "${register}"): ${path}\n"
            output_line+="        (access count: ${count}) (last accessed: ${padded_last_access})"
            
            if ! check_path_exists "$path"; then
                output_line+=" $(emphasis "DEAD PATH" "red")"
                echo "${count}|${output_line}" >> "$tmp_dead"
            else
                output_line+=" $(emphasis "ACTIVE" "green")"
                echo "${count}|${output_line}" >> "$tmp_active"
            fi
        done <<< "$numerical_registers"
        
        #if [[ -s "$tmp_active" ]]; then
        #    sort -rn "$tmp_active" | cut -d '|' -f 2- | while IFS= read -r line; do
        #        printf "%b\n" "$line"
        #    done
        #fi
        
        #if [[ -s "$tmp_dead" ]]; then
        #    sort -rn "$tmp_dead" | cut -d '|' -f 2- | while IFS= read -r line; do
        #        printf "%b\n" "$line"
        #    done
        #fi
         
        while IFS= read -r line; do
            printf "  %b\n" "$line"
        done <<< "$numerical_registers"
    fi
    
    rm -f "$tmp_active" "$tmp_dead"
    tmp_active=$(mktemp)
    tmp_dead=$(mktemp)
    
    echo
    echo $(bold "Named registers:")
    literal_registers="$(cat "${register_file}" | sed -n '/^[0-9]@/!p')"
    if [[ -n "$literal_registers" ]]; then
        while IFS= read -r register_line; do
            register=$(echo "$register_line" | cut -d '@' -f 1)
            path=$(echo "$register_line" | cut -d '@' -f 2-)
            count=$(get_access_count "$register" "$path" "$history_file")
            padded_last_access=$(pad_never "$(get_last_access "$register" "$path" "$history_file")")
            
            output_line="  ($(emphasis ${register} "green")): ${path}\n"
            output_line+="    (access count: ${count}) (last accessed: ${padded_last_access})"
            
            if ! check_path_exists "$path"; then
                output_line+=" $(emphasis "DEAD PATH" "red")"
                echo "${count}|${output_line}" >> "$tmp_dead"
            else
                output_line+=" $(emphasis "ACTIVE" "green")"
                echo "${count}|${output_line}" >> "$tmp_active"
            fi
        done <<< "$literal_registers"
        
        if [[ -s "$tmp_active" ]]; then
            sort -rn "$tmp_active" | cut -d '|' -f 2- | while IFS= read -r line; do
                printf "%b\n" "$line"
            done
        fi
        
        if [[ -s "$tmp_dead" ]]; then
            sort -rn "$tmp_dead" | cut -d '|' -f 2- | while IFS= read -r line; do
                printf "%b\n" "$line"
            done
        fi
    else
        echo "$(bold "INFO:") No named registers in register file: ${register_file}. Call 'cdbuff -s' to set a named register."
    fi
    
    rm -f "$tmp_active" "$tmp_dead"
    
    printf "\n"
    printf "    %s %s\n" "$(emphasis "register" 'red') $(emphasis "file: " 'red')" "${register_file}"
    printf "    %s %s\n" "$(emphasis "history" 'red') $(emphasis "file: " 'red')" "${history_file}"
}

show_register_stats() {
    local register="$1"
    local register_file="$2"
    local history_file="$3"
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi
    
    register_line="$(grep -E "^${register}@" "${register_file}" || echo "")"
    if [[ -z "$register_line" ]]; then
        exiterr "ERROR: no register set for register: ${register} found in: ${register_file}"
    fi
    
    local register_path="$(echo "${register_line}" | cut -d "@" -f2)"
    local count=$(get_access_count "$register" "$register_path" "$history_file")
    
    echo "$(bold "Statistics for register:") $(emphasis "${register}" "green")"
    echo "  Path: ${register_path}"
    echo "  Access count: ${count}"
    
    if ! check_path_exists "$register_path"; then
        echo "  $(emphasis "WARNING: Path no longer exists!" "red")"
    fi
    
    if [[ -f "${history_file}" ]]; then
        echo ""
        echo "$(bold "Access history:")"
        grep "^${register}@${register_path}@" "${history_file}" | while IFS= read -r line; do
            timestamp=$(echo "$line" | cut -d '@' -f 3)
            echo "  - $timestamp"
        done
    fi
}

numerical_registers_clear(){
    local register_file="${1}"
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi
   
    sed -i -n '/^[0-9]@/p' "${register_file}"

}

numerical_registers_init(){
    local register_file="${1}"
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi


    numerical_registers="$(cat ${register_file} | sed -n '/^[0-9]@/p')"
    if [[ -z "${numerical_registers}" ]]; then
        numerical_registers_clear "${register_file}"
        for ((index=0; index<=9; index++)); do
            printf "%s@\n" "${index}" >> "${register_file}"
        done
    fi
}

numerical_register_push(){
    path="${1}"
    register_file="${2}"
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi

    numerical_registers="$(cat ${register_file} | sed -n '/^[0-9]@/p')"
    numerical_registers=$(echo "$numerical_registers" | awk -F'@' '{print $1+1 "@" $2}')
    numerical_registers=$(echo "$numerical_registers" | awk -F'@' '$1 <= 10')

    for ((index=9; index>=1; index--)); do
        register=$index
        temp_path=$(echo "${numerical_registers}" | grep "${register}@" | cut -d "@" -f2)
        if [ -n "$temp_path" ]; then
            cd_register_set "${register}" "${register_file}" "${temp_path}"
        fi
    done
    cd_register_set "0" "${register_file}" "${path}"

}

log_access() {
    local register="$1"
    local path="$2"
    local history_file="$3"
    
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf "%s@%s@%s\n" "${register}" "${path}" "${timestamp}" >> "${history_file}"
}

cd_register(){
    register="${1}"
    register_file="${2}"
    history_file="${3}"

    registers="$(cat "${register_file}")"
    if [[ -z "$registers" ]]; then
        exiterr "ERROR: no registers set!"
    fi


    register_line="$(grep -E "^${register}@" "${register_file}" || echo "")"

    if [[ -z "$register_line" ]]; then
        exiterr "ERROR: no register set for register: ${register} found in: ${register_file}"
    fi
    register="$(echo "${register_line}" | cut -d "@" -f1)"
    register_path="$(echo "${register_line}" | cut -d "@" -f2)"
    
    if ! check_path_exists "$register_path"; then
        echo "$(emphasis "WARNING:" "red") Path ${register_path} associated with register $(emphasis "${register}" "green") no longer exists!"
    fi
    
    echo "Changing directory to: $(emphasis "${register}" "green")@${register_path}"
    
    log_access "${register}" "${register_path}" "${history_file}"
    
    echo "${register_path}"
}

register_print(){
    register="${1}"
    register_file="${2}"

    registers="$(cat "${register_file}")"
    if [[ -z "$registers" ]]; then
        exiterr "ERROR: no registers set!"
    fi

    if [[ $register =~ ^[0-9]+$ ]]; then
        ((register=register+1))
        register_line="$(cat "${register_file}" | sed "${register}q;d")"
    else
        register_line="$(grep -E "^${register}@" "${register_file}" || echo "")"
    fi

    if [[ -z "$register_line" ]]; then
        exiterr "ERROR: no register set for register: ${register} found in: ${register_file}"
    fi
    register="$(echo "${register_line}" | cut -d "@" -f1)"
    register_path="$(echo "${register_line}" | cut -d "@" -f2)"
    echo "Register: $(emphasis "${register}" "green")@${register_path}"
    
    if ! check_path_exists "$register_path"; then
        echo "$(emphasis "WARNING:" "red") Path no longer exists!"
    fi
}

cd_register_set(){
    local register="${1}"
    local register_file="${2}"
    local path="${3:-}"
    
    if [[ ! -f "${register_file}" ]]; then
        exiterr "ERROR: cdbuff register file: ${register_file} does not exist."
    fi

    if [[ -z "${path}" || "${path}" =~ ^[[:space:]]+$ ]]; then
        path="$(pwd)"
    fi
    if ! [[ "$register" =~ ^[0-9]+$ ]]; then
        echo "$(bold "Setting register:") ($(emphasis "${register}" "green")): ${path}"
    fi
    sed -i "/^${register}\b/d" "${register_file}"
    printf "%s@%s\n" "${register}" "${path}" >> "${register_file}"
}

cd_register_sort(){
    local register_file="${1}"
    local line=""
 
    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi

    register_list="$(cat "${register_file}" | sort)"
    register_line=$(echo "${register_list}" | grep -m 1 "^${DEFAULT_REGISTER}")
    register_list="$(echo "${register_list}" | sed "/^$DEFAULT_REGISTER@/d")"
    register_list="$(echo "${register_list}" | sed '/^$/d')"
    printf "${register_line}\n${register_list}" > "${register_file}"
}

delete_register(){
    register="${1}"
    register_file="${2}"
 
    if [[ $register =~ ^[0-9]+$ ]]; then
        ((register=register+1))
        register_line="$(cat "${register_file}" | sed "${register}q;d")"
        IFS="@" read -r register _ <<< "${register_line}"
    else
        register_line="$(grep -E "^${register}" "${register_file}" || echo "")"
    fi

    if [[ "$register_line" =~ ^[[:space:]]*$ ]]; then
        exiterr "    ERROR: Named register: ${register} not found in: ${register_file}"
    fi
    register=$(trim_string "${register}")
    sed -i "/^$register/d" "$register_file"
    echo "$(emphasis "Deleted:" "red") ${register_line}"
}


trim_string() {
  local input_string=$1
  local trimmed_string

  trimmed_string=$(echo "$input_string" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  echo "$trimmed_string"
}

FORCE_COLOR="${CDBUFF_FORCE_COLOR:-}"
NO_COLOR="${NO_COLOR:-}"

USE_COLORS=0
if [[ -n "$FORCE_COLOR" ]]; then
    USE_COLORS=1
elif [[ -n "$NO_COLOR" ]]; then
    USE_COLORS=0
else
    if [[ -n "${CDBUFF_INTERACTIVE:-}" ]]; then
        USE_COLORS=1
    fi
fi

bold() {
    if [[ $USE_COLORS -eq 1 ]]; then
        printf "\033[1m%s\033[0m" "$1"
    else
        printf "%s" "$1"
    fi
}

red() {
    if [[ $USE_COLORS -eq 1 ]]; then
        printf "\033[1;31m%s\033[0m" "$1"
    else
        printf "%s" "$1"
    fi
}

green() {
    if [[ $USE_COLORS -eq 1 ]]; then
        printf "\033[1;32m%s\033[0m" "$1"
    else
        printf "%s" "$1"
    fi
}

emphasis() {
    local string="${1}"
    local color="${2}"
    if [[ $USE_COLORS -eq 1 ]]; then
        eval "$color $(bold "${string}")"
    else
        printf "%s" "${string}"
    fi
}

register_file=
register=
history_file=

strip_register_path() {
    local input="$1"

    if [[ -z "${input}" ]]; then
        exiterr "    ERROR: No register name provide, provide a register name and try again."
    fi

    if [[ "$input" == *"@"* ]]; then
        echo "$input" | cut -d '@' -f 1
    else
        echo "$input"
    fi
}

parse_params() {
  register="${DEFAULT_REGISTER}"
  register_file="${DEFAULT_REGISTER_FILE}"
  history_file="${DEFAULT_HISTORY_FILE}"
  list=0
  set_register=0
  _cd=0
  delete=0
  dump=0
  nuke=0
  print=0
  stats=0
  prune_dead=0

  if [ $# -eq 1 ] && [[ "${1:0:1}" != "-" ]]; then
    register=$(strip_register_path "$1")
    _cd=1
  fi
  
  if [ $# -eq 0 ]; then
    register="${DEFAULT_REGISTER}"
    _cd=1
  fi

  while :; do
    case "${1-}" in
    -h | --help) echo "$(_help)" | less ;;
    -v | --verbose) set -x ;;
    -f | --register-file)
      register_file="${2-}"
      shift
      ;;
    -l | --list-registers) list=1;;
    -s | --set-register) 
      set_register=1
      if [[ $# -gt 1 && ! "$2" == -* ]]; then
        register=$(strip_register_path "$2")
        shift
      else
        register="${DEFAULT_REGISTER}"
      fi
      ;;
    -c | --cd) _cd=1;;
    -d | --delete) 
      delete=1
      register=$(strip_register_path "${2-}")
      shift
      ;;
    -D | --dump) dump=1;;
    -n | --nuke) nuke=1;;
    -p | --print) print=1;;
    -P | --prune-dead) prune_dead=1;;
    -S | --stats)
      stats=1
      register=$(strip_register_path "${2-}")
      shift
      ;;
    -?*) exiterr "ERROR: Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

    args=("$@")

    [[ -z "${register+x}" ]] && exiterr "ERROR: no register provided."

    touch ${register_file}
    touch ${history_file}

    
    if [[ "${nuke}" -eq 1 ]]; then
        if confirm; then
           cat /dev/null > ${register_file}
           echo "cdbuff register file nuked: ${register_file}"
           
        else
            echo "Your cdbuff register file has been spared."
        fi 
    fi
    if [[ "${dump}" -eq 1 ]]; then
        echo "cdbuff register file: ${register_file}"
        echo ""
        cat "${register_file}"
        exit 0
    fi
    if [[ "${print}" -eq 1 ]]; then
        register_print "${register}" "${register_file}"
        exit 0
    fi
    if [[ "${list}" -eq 1 ]]; then
        list_registers "${register_file}" "${history_file}"
    fi
    if [[ "${prune_dead}" -eq 1 ]]; then
        prune_dead_registers "${register_file}" "${history_file}"
        exit 0
    fi
    if [[ "${set_register}" -eq 1 ]]; then
        cd_register_set "${register}" "${register_file}"
        numerical_register_push "$(pwd)" "${register_file}"
    fi
    if [[ "${_cd}" -eq 1 ]]; then
        cd_register "${register}" "${register_file}" "${history_file}"
        exit 0
    fi
    if [[ "${stats}" -eq 1 ]]; then
        show_register_stats "${register}" "${register_file}" "${history_file}"
        exit 0
    fi

    if [[ $list -eq 1 && $set_register -eq 1 && $_cd -eq 1 && -z $register ]]; then
        cd_register "${register}" "${register_file}" "${history_file}"
    fi

    if [[ "${delete}" -eq 1 ]]; then
        delete_register "${register}" "${register_file}"
        cd_register_sort "${register_file}"
    fi

    numerical_registers_init "${register_file}"
    return 0
}
parse_params "$@"
