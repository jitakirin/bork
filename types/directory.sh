# TODO add --permissions flag, perhaps copy/extract from file?

action=$1
dir=$2
shift 2

owner=$(arguments get owner $*)
group=$(arguments get group $*)
mode=$(arguments get mode $*)

case "$action" in
  desc)
    printf '%s\n' \
      'asserts presence of a directory' \
      '* directory path [options]' \
      '--owner=user-name' \
      '--group=group-name' \
      '--mode=mode' \
      '> directory ~/.ssh --mode=700'
    ;;

  status)
    bake [ -e "${dir}" ] || return $STATUS_MISSING
    bake [ -d "${dir}" ] || {
      echo "target exists as non-directory"
      return $STATUS_CONFLICT_CLOBBER
    }

    mismatch=false
    if [[ -n ${owner} || -n ${group} || -n ${mode} ]]; then
      readarray -d : -t dir_stat < <(bake stat --printf '%U:%G:%a' "${dir}")

      if [[ -n ${owner} && ${dir_stat[0]} != ${owner} ]]; then
        printf '%s owner: %s\n' \
          'expected' "${owner}" \
          'received' "${dir_stat[0]}"
        mismatch=true
      fi

      if [[ -n ${group} && ${dir_stat[1]} != ${group} ]]; then
        printf '%s group: %s\n' \
          'expected' "${group}" \
          'received' "${dir_stat[1]}"
        mismatch=true
      fi

      if [[ -n ${mode} && ${dir_stat[2]} != ${mode} ]]; then
        printf '%s mode: %s\n' \
          'expected' "${mode}" \
          'received' "${dir_stat[2]}"
        mismatch=true
      fi
    fi

    if ${mismatch}; then
      return "${STATUS_MISMATCH_UPGRADE}"
    fi

    return "${STATUS_OK}"
    ;;

  install|upgrade)
    inst_opts=( -C -d )
    [[ -z ${owner} ]] || inst_opts+=( -o "${owner}" )
    [[ -z ${group} ]] || inst_opts+=( -g "${group}" )
    [[ -z ${mode} ]] || inst_opts+=( -m "${mode}" )
    bake install "${inst_opts[@]}" "${dir}"
    ;;

  *) return 1 ;;
esac
