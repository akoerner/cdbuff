# ── Resolve cdbuff.sh path ─────────────────────────────────────────────────────

0="${(%):-%x}"
_cdbuff_plugin_dir="${0:A:h}"
export CDBUFF="${_cdbuff_plugin_dir}/cdbuff.sh"
unset _cdbuff_plugin_dir 0

if [[ ! -f "${CDBUFF}" ]]; then
    print "cdbuff: ERROR: unable to locate cdbuff.sh relative to plugin file." >&2
    return 1
fi

# ── ZSH completion ─────────────────────────────────────────────────────────────

_cdbuff_complete_zsh() {
    typeset +t _cdbuff_complete_zsh
    emulate -L zsh
    local register_file="${XDG_CONFIG_HOME:-${HOME}}/.cdbuff/registers"
    local history_file="${XDG_CONFIG_HOME:-${HOME}}/.cdbuff/history"

    _cdbuff_register_completions() {
        if [[ ! -f "${register_file}" ]]; then
            return
        fi

        local -a names descs
        local raw
        raw=$(
            exec 2>/dev/null
            unsetopt verbose xtrace
            zmodload zsh/datetime 2>/dev/null
            local tmp
            tmp=$(mktemp)
            local line reg reg_path count last_access
            while IFS= read -r line; do
                reg="${line%%@*}"
                reg_path="${line#*@}"
                [[ -d "${reg_path}" ]] || continue
                count=0
                last_access="never"
                if [[ -f "${history_file}" ]]; then
                    count=$(grep -c "^${reg}@${reg_path}@" "${history_file}" || true)
                    last_access=$(grep "^${reg}@${reg_path}@" "${history_file}" | tail -1 | cut -d '@' -f 3)
                    [[ -z "${last_access}" ]] && last_access="never"
                fi
                printf '%s\t%s\t%s\t%s\n' "${count}" "${reg}" "${last_access}" "${reg_path}" >> "${tmp}"
            done < <(grep -v "^[0-9]@" "${register_file}")

            local -a _names _counts _ages _paths
            while IFS=$'\t' read -r c n l p; do
                local age_str ts days
                if [[ "${l}" == "never" ]]; then
                    age_str="never"
                else
                    strftime -rs ts '%Y-%m-%d %H:%M:%S' "${l}" 2>/dev/null || ts=${EPOCHSECONDS}
                    days=$(( (EPOCHSECONDS - ts) / 86400 ))
                    if   (( days == 0 )); then age_str="today"
                    elif (( days == 1 )); then age_str="1 day ago"
                    else                        age_str="${days} days ago"
                    fi
                fi
                _names+=("${n}")
                _counts+=("${c}")
                _ages+=("${age_str}")
                _paths+=("${p}")
            done < <(sort -rn "${tmp}")
            rm -f "${tmp}"

            local max_name=0 max_count=0 max_age=0 i
            for (( i=1; i <= ${#_names[@]}; i++ )); do
                local clen=$(( ${#_counts[i]} + 9 ))
                (( ${#_names[i]} > max_name )) && max_name=${#_names[i]}
                (( clen          > max_count )) && max_count=$clen
                (( ${#_ages[i]}  > max_age  )) && max_age=${#_ages[i]}
            done

            for (( i=1; i <= ${#_names[@]}; i++ )); do
                local n="${_names[i]}" c="${_counts[i]}" a="${_ages[i]}" p="${_paths[i]}"
                local count_str="${c} accesses"
                local pn="${(r:max_name:)n}"
                local pc="${(r:max_count:)count_str}"
                local pa="${(r:max_age:)a}"
                local desc
                desc=$(print -P "%B%F{green}${pn}%f%b  %F{yellow}${pc}%f  %F{cyan}${pa}%f  ${p}")
                printf '%s\x00%s\n' "${n}" "${desc}"
            done
        )

        local -a raw_lines
        raw_lines=("${(@f)raw}")
        raw_lines=("${(M)raw_lines[@]:#*$'\x00'*}")
        names=("${raw_lines[@]%%$'\x00'*}")
        descs=("${raw_lines[@]#*$'\x00'}")

        compadd -l -d descs -a names
    }

    local -a opts
    opts=(
        '(-h --help)'{-h,--help}'[print help and exit]'
        '(-v --verbose)'{-v,--verbose}'[verbose output]'
        '(-l --list-registers)'{-l,--list-registers}'[list all registers]'
        '(-s --set-register)'{-s,--set-register}'[set register]: :_cdbuff_register_completions'
        '(-d --delete)'{-d,--delete}'[delete register]: :_cdbuff_register_completions'
        '(-D --dump)'{-D,--dump}'[dump register file]'
        '(-n --nuke)'{-n,--nuke}'[delete all registers]'
        '(-p --print)'{-p,--print}'[print primary register]'
        '(-P --prune-dead)'{-P,--prune-dead}'[prune dead registers]'
        '(-t --stats)'{-t,--stats}'[show register stats]: :_cdbuff_register_completions'
        '(-f --register-file)'{-f,--register-file}'[register file path]: :_files'
        '1: :_cdbuff_register_completions'
    )
    _arguments -s "${opts[@]}"
}

# ── Defer compdef until after compinit ────────────────────────────────────────
# compdef called at plugin load time fires before compinit in most plugin
# managers and standalone sourcing. Register via precmd and self-remove.

_cdbuff_init_completion() {
    compdef _cdbuff_complete_zsh cdbuff cb
    add-zsh-hook -d precmd _cdbuff_init_completion
    unfunction _cdbuff_init_completion
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _cdbuff_init_completion

# ── Tab on empty prompt opens cb completions ───────────────────────────────────

_cdbuff_tab_or_complete() {
    if [[ -z "${BUFFER}" ]]; then
        BUFFER="cb "
        CURSOR=${#BUFFER}
    fi
    zle expand-or-complete
}
zle -N _cdbuff_tab_or_complete
bindkey "^I" _cdbuff_tab_or_complete

# ── cdbuff function ────────────────────────────────────────────────────────────

cdbuff() {
    if [[ -t 1 && -t 0 ]]; then
        export CDBUFF_INTERACTIVE=1
    else
        export CDBUFF_INTERACTIVE=
    fi

    local output
    output="$(bash "${CDBUFF}" "$@")"
    printf "%s\n" "${output}"
    local project_path
    project_path="$(echo "${output}" | tail -n 1)"
    if [[ -d "${project_path}" ]]; then
        cd "${project_path}"
    fi

    unset CDBUFF_INTERACTIVE
}

alias cb=cdbuff
