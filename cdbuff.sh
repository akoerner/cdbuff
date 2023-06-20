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

DEFAULT_BUFFER="primary"
DEFAULT_BUFFER_FILE="${HOME}/.cdbuff"
cdbuff_file="${CDBUFF_FILE:-$DEFAULT_BUFFER_FILE}"


_help() {
    cat << EOF 
NAME
    cdbuff - cd but with memory 

    Grandpa's cd with buffers, less typey more workey

SYNOPSIS
  USAGE
    cdbuff -s             Set the 'primary' buffer to the current working directory
    cdbuff -d -b primary  Delete the primary buffer
    cdbuff -d -b 3        Delete buffer at index 3, to list indexes use the -l flag
    cdbuff -s -b test     Create a new buffer called 'test' and save the current working directory 
    cdbuff -b test        Change directory to the path stored with the 'test' buffer
    cdbuff -l             List all defined buffers
    cdbuff -p             Print the primary buffer and exit 

DESCRIPTION
    cdbuffer is an enhancement to the 'cd' command adding named buffers that can
    be saved and restored on-demand. Duck and weave through your file system 
    like a ninja. The features include:
    - Saving directories as a named buffer
    - cd'ing to named buffers
    - list available buffers
    - managing named buffers i.e., deleting them

OPTIONS

    -h, --help             Print this help and exit
    -f, --buffer-file      CD buffer file to save path data. 
                             Default: "${DEFAULT_BUFFER_FILE}"
    -b, --buffer           Buffer name or index
    -d, --delete           Delete named buffer
    -c, --cd               Change directory to project path
    -p, --print            Print the buffer and exit 
    -v, --verbose          verbose output

    The default buffer is always "${DEFAULT_BUFFER}" unless specified with -b <buffer name> or --buffer <buffer name>
EOF
    exit
} 

# set project
# list projects
# primary buffer

list_buffers(){
    buffer_file="${1}"

    if [[ ! -f "${buffer_file}" ]]; then
        exiterr "    ERROR: cd buffer file: ${buffer_file} does not exist."
    fi

    buffers="$(cat "${buffer_file}")"
    index=0
    if [[ -n "$buffers" ]]; then
        echo $(bold "Named buffers:")
        while IFS= read -r buffer_line; do
            buffer=$(echo "$buffer_line" | cut -d '@' -f 1)
            path=$(echo "$buffer_line" | cut -d '@' -f 2-)
            printf "    %s: %-30s: %-45s %-80s\n" "$(bold "${index}")" "($(emphasis ${buffer} "green"))" "${path}" "=> 'cdbuff ${buffer}' or 'cdbuff ${index}' or 'cdbuff -b ${buffer}'"
            ((index=index+1))
        done <<< "$buffers"
    else
        exiterr "$(emphasis "ERROR:" "red") no named buffers in buffer file: ${buffer_file}. Call 'cdbuff -s' or 'cdbuff -s -p some_name' to set a named buffer."
    fi
    printf "    %s %s\n" "$(emphasis "buffer" 'red') $(emphasis "file: " 'red')" "${buffer_file}"

}

cd_buffer(){
    buffer="${1}"
    buffer_file="${2}"

    buffers="$(cat "${buffer_file}")"
    if [[ -z "$buffers" ]]; then
        exiterr "ERROR: no cd buffers set!"
    fi

    if [[ $buffer =~ ^[0-9]+$ ]]; then
        ((buffer=buffer+1))
        buffer_line="$(cat "${buffer_file}" | sed "${buffer}q;d")"
    else
        buffer_line="$(grep -E "^${buffer}@" "${buffer_file}" || echo "")"
    fi

    if [[ -z "$buffer_line" ]]; then
        exiterr "ERROR: no cd buffer for buffer: ${buffer} found in: ${buffer_file}"
    fi
    buffer="$(echo "${buffer_line}" | cut -d "@" -f1)"
    buffer_path="$(echo "${buffer_line}" | cut -d "@" -f2)"
    echo "Changing directory to: $(emphasis "${buffer}" "green")@${buffer_path}"
    echo "${buffer_path}"
}

buffer_print(){
    buffer="${1}"
    buffer_file="${2}"

    buffers="$(cat "${buffer_file}")"
    if [[ -z "$buffers" ]]; then
        exiterr "ERROR: no cd buffers set!"
    fi

    if [[ $buffer =~ ^[0-9]+$ ]]; then
        ((buffer=buffer+1))
        buffer_line="$(cat "${buffer_file}" | sed "${buffer}q;d")"
    else
        buffer_line="$(grep -E "^${buffer}@" "${buffer_file}" || echo "")"
    fi

    if [[ -z "$buffer_line" ]]; then
        exiterr "ERROR: no cd buffer for buffer: ${buffer} found in: ${buffer_file}"
    fi
    buffer="$(echo "${buffer_line}" | cut -d "@" -f1)"
    buffer_path="$(echo "${buffer_line}" | cut -d "@" -f2)"
    echo "Buffer: $(emphasis "${buffer}" "green")@${buffer_path}"
}

cd_buffer_set(){
    local buffer="${1}"
    local buffer_file="${2}"
    
    if [[ ! -f "${buffer_file}" ]]; then
        exiterr "ERROR: cd buffer file: ${buffer_file} does not exist."
    fi
    cwd="$(pwd)"
    echo "$(bold "Setting cd buffer:") ($(emphasis "${buffer}" "green")): ${cwd}"
    sed -i "/^${buffer}\b/d" "${buffer_file}"
    printf "\n%s@%s\n" "${buffer}" "${cwd}" >> "${buffer_file}"
}

cd_buffer_sort(){
    local buffer_file="${1}"
    local line=""
 
    if [[ ! -f "${buffer_file}" ]]; then
        exiterr "    ERROR: cd buffer file: ${buffer_file} does not exist."
    fi

    buffer_list="$(cat "${buffer_file}" | sort)"
    buffer_line=$(echo "${buffer_list}" | grep -m 1 "^${DEFAULT_BUFFER}")
    buffer_list="$(echo "${buffer_list}" | sed "/^$DEFAULT_BUFFER@/d")"
    buffer_list="$(echo "${buffer_list}" | sed '/^$/d')"
    printf "${buffer_line}\n${buffer_list}" > "${buffer_file}"
}

cd_buffer_delete(){
    buffer="${1}"
    buffer_file="${2}"
 
    if [[ $buffer =~ ^[0-9]+$ ]]; then
        ((buffer=buffer+1))
        buffer_line="$(cat "${buffer_file}" | sed "${buffer}q;d")"
        IFS="@" read -r buffer _ <<< "${buffer_line}"
    else
        buffer_line="$(grep -E "^${buffer}" "${buffer_file}" || echo "")"
    fi

    if [[ "$buffer_line" =~ ^[[:space:]]*$ ]]; then
        exiterr "    ERROR: Named buffer: ${buffer} not found in: ${buffer_file}"
    fi
    buffer=$(trim_string "${buffer}")
    sed -i "/^$buffer/d" "$buffer_file"
    echo "$(emphasis "Deleted:" "red") ${buffer_line}"
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



buffer_file=
buffer=

function parse_params() {
  buffer="${DEFAULT_BUFFER}"
  buffer_file="${cdbuff_file}"
  list=0
  set_buffer=0
  _cd=0
  delete=0
  print=0

  
  if [ $# -eq 1 ] && [[ "${1:0:1}" != "-" ]]; then
    buffer=$1
    _cd=1
  fi
  
  if [ $# -eq 0 ]; then
    buffer="${DEFAULT_BUFFER}"
    _cd=1
  fi

  while :; do
    case "${1-}" in
    -h | --help) echo "$(_help)" | less ;;
    -v | --verbose) set -x ;;
    -b | --buffer)
      buffer="${2-}"
      shift
      ;;
    -f | --buffer-file) # example named parameter
      buffer_file="${2-}"
      shift
      ;;
    -l | --list-buffers) list=1;;
    -s | --set-buffer) set_buffer=1;;
    -c | --cd) _cd=1;;
    -d | --delete) delete=1;;
    -p | --print) print=1;;
    -?*) exiterr "ERROR: Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

    args=("$@")

    # check required params and arguments
    [[ -z "${buffer-}" ]] && exiterr "ERROR: no buffer provided."
    #  [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

    touch ${buffer_file}
    #echo "  Buffer: ${buffer}"
    if [[ "${print}" -eq 1 ]]; then
        buffer_print "${buffer}" "${buffer_file}"
        exit 0
    fi
    if [[ "${list}" -eq 1 ]]; then
        list_buffers "${buffer_file}"
    fi
    if [[ "${set_buffer}" -eq 1 ]]; then
        cd_buffer_set "${buffer}" "${buffer_file}"
        cd_buffer_sort "${buffer_file}"
    fi
    if [[ "${_cd}" -eq 1 ]]; then
        cd_buffer "${buffer}" "${buffer_file}"
    fi

    if [[ $list -eq 1 && $set_buffer -eq 1 && $_cd -eq 1 && -z $buffer ]]; then
        cd_buffer "${buffer}" "${buffer_file}"
    fi

    if [[ "${delete}" -eq 1 ]]; then
        cd_buffer_delete "${buffer}" "${buffer_file}"
        cd_buffer_sort "${buffer_file}"
    fi
    return 0
}
parse_params "$@"

