#!/usr/bin/env bash


set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

echoerr (){ printf "$@" >&2;}
exiterr (){ echoerr "$@\n"; exit 1;}

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

DEFAULT_REGISTER="primary"
DEFAULT_REGISTER_FILE="${HOME}/.cdbuff"
cdbuff_file="${CDBUFF_FILE:-$DEFAULT_REGISTER_FILE}"


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
    cdbuff -d 3           Delete register at index 3, to list indexes use the -l flag
    cdbuff -l             List all defined registers
    cdbuff -p             Print the primary register and exit 

DESCRIPTION
    cdregister is an enhancement to the 'cd' command adding named registers and a 
    circular index register, similar to vim, that can be saved and restored 
    on-demand. Duck and weave through your file system like a ninja. The 
    features include:
    - Saving directories as a named register
    - Vim like circular register 
    - cd'ing to named and indexed registers
    - list available registers
    - managing named registers i.e., deleting them
    - 

OPTIONS

    -h, --help             Print this help and exit
    -f, --register-file    CD register register file to save path data. 
                           Default: "${DEFAULT_REGISTER_FILE}"
    -d, --delete           Delete named register
    -p, --print            Print the `primary` register and exit 
    -n, --nuke             Delete all registers in the register file 
    -D, --dump             cat the register file 
    -v, --verbose          verbose output

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

list_registers(){
    register_file="${1}"

    if [[ ! -f "${register_file}" ]]; then
        exiterr "    ERROR: cdbuff register file: ${register_file} does not exist."
    fi
    numerical_registers="$(cat ${register_file} | sed -n '/^[0-9]@/p')"
    literal_registers="$(cat "${register_file}" | sed -n '/^[0-9]@/!p')"
    index=0
    echo $(bold "Numerical registers:")
    if [[ -n "$numerical_registers" ]]; then
        while IFS= read -r register_line; do
            register=$(echo "$register_line" | cut -d '@' -f 1)
            path=$(echo "$register_line" | cut -d '@' -f 2-)
            printf "    %s: %-30s\n" "$(bold "${register}")" "${path}"
        done <<< "$numerical_registers"
    fi
    echo
    echo $(bold "Named registers:")
    if [[ -n "$literal_registers" ]]; then
        while IFS= read -r register_line; do
            register=$(echo "$register_line" | cut -d '@' -f 1)
            path=$(echo "$register_line" | cut -d '@' -f 2-)
            #printf "    %s: %-30s: %-45s %-80s\n" "$(bold "${index}")" "($(emphasis ${register} "green"))" "${path}" "=> 'cdbuff ${register}' or 'cdbuff ${index}' or 'cdbuff -b ${register}'"
            printf "    %s: %-50s \n" "($(emphasis ${register} "green"))" "${path}"
            ((index=index+1))
        done <<< "$literal_registers"
    else
        echo "$(bold "INFO:") No named registers in register file: ${register_file}. Call 'cdbuff -s' to set a named register."
    fi
    printf "    %s %s\n" "$(emphasis "register" 'red') $(emphasis "file: " 'red')" "${register_file}"
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

cd_register(){
    register="${1}"
    register_file="${2}"

    registers="$(cat "${register_file}")"
    if [[ -z "$registers" ]]; then
        exiterr "ERROR: no registers set!"
    fi


    #if [[ $register =~ ^[0-9]+$ ]]; then
    #    ((register=register+1))
    #    register_line="$(cat "${register_file}" | sed "${register}q;d")"
    #else
    register_line="$(grep -E "^${register}@" "${register_file}" || echo "")"
    #fi

    if [[ -z "$register_line" ]]; then
        exiterr "ERROR: no register set for register: ${register} found in: ${register_file}"
    fi
    register="$(echo "${register_line}" | cut -d "@" -f1)"
    register_path="$(echo "${register_line}" | cut -d "@" -f2)"
    echo "Changing directory to: $(emphasis "${register}" "green")@${register_path}"
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
    echo "Buffer: $(emphasis "${register}" "green")@${register_path}"
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

cd_register_delete(){
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

bold() {
    printf "\033[1m%s\033[0m" "$1"
}

red() {
    printf "\033[1;31m%s\033[0m" "$1"
}

green() {
    printf "\033[1;32m%s\033[0m" "$1"
}

emphasis () {
    local string="${1}"
    local color="${2}"
    eval "$color $(bold "${string}")"
} 



register_file=
register=

parse_params() {
  register="${DEFAULT_REGISTER}"
  register_file="${DEFAULT_REGISTER_FILE}"
  list=0
  set_register=0
  _cd=0
  delete=0
  dump=0
  nuke=0
  print=0

  if [ $# -eq 1 ] && [[ "${1:0:1}" != "-" ]]; then
    register=$1
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
    -f | --register-file) # example named parameter
      register_file="${2-}"
      shift
      ;;
    -l | --list-registers) list=1;;
    -s | --set-register) 
      set_register=1
      if [[ $# -gt 1 && ! "$2" == -* ]]; then
        register="$2"
        shift
      else
        register="${DEFAULT_REGISTER}"  # No value provided for "register"
      fi
      ;;
    -c | --cd) _cd=1;;
    -d | --delete) 
      delete=1
      register="${2-}"
      shift
      ;;
    -D | --dump) dump=1;;
    -n | --nuke) nuke=1;;
    -p | --print) print=1;;
    -?*) exiterr "ERROR: Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

    args=("$@")

    [[ -z "${register+x}" ]] && exiterr "ERROR: no register provided."

    touch ${register_file}
    #echo "  Buffer: ${register}"
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
        list_registers "${register_file}"
    fi
    if [[ "${set_register}" -eq 1 ]]; then
        cd_register_set "${register}" "${register_file}"
        #cd_register_sort "${register_file}"
        numerical_register_push "$(pwd)" "${register_file}"
    fi
    if [[ "${_cd}" -eq 1 ]]; then
        cd_register "${register}" "${register_file}"
        exit 0
    fi

    if [[ $list -eq 1 && $set_register -eq 1 && $_cd -eq 1 && -z $register ]]; then
        cd_register "${register}" "${register_file}"
    fi

    if [[ "${delete}" -eq 1 ]]; then
        cd_register_delete "${register}" "${register_file}"
        cd_register_sort "${register_file}"
    fi

    numerical_registers_init "${register_file}"
    return 0
}
parse_params "$@"

