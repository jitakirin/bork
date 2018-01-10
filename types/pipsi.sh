#!/bin/bash

action=$1
name=$2
shift 2

if [[ -n ${name} && ${name} == --global ]]; then
  global=true
  name=''
else
  global=$(arguments get global $*)
fi

# set paths, try variables pipsi itself uses first and fall-back to
# defaults; take the 'global' option into account
declare -a pipsi_opts=( )
pipsi_bin_dir="${PIPSI_BIN_DIR:-"${HOME}/.local/bin"}"
pipsi_home="${PIPSI_HOME:-"${HOME}/.local/venvs"}"
if [[ ${global} == true ]]; then
  pipsi_bin_dir="${PIPSI_GLOBAL_BIN_DIR:-"/usr/local/bin"}"
  pipsi_home="${PIPSI_GLOBAL_HOME:-"/usr/local/lib/pipsi"}"
  pipsi_opts+=( --bin-dir=${pipsi_bin_dir} --home=${pipsi_home} )
fi

# if bin_dir or home are not writable, automatically attempt to elevate
# permissions using sudo
get_su() {
  su=''
  bake test -w "${pipsi_bin_dir}/" || su='sudo'
  bake test -w "${pipsi_home}/" || su='sudo'
  printf '%s' "${su}"
}

case "${action}" in
  desc)
    printf '%s\n' \
      'asserts presence of packages installed via pipsi' \
      '* pipsi                (install/upgrade pipsi itself)' \
      '* pipsi packge-name    (works on given package from pypi)' \
      '--global               (work on global packages instead of per-user)'
    ;;
  status)
    needs_exec "python" || return "${STATUS_FAILED_PRECONDITION}"
    needs_exec "virtualenv" || return "${STATUS_FAILED_PRECONDITION}"

    if [[ -z ${name} ]]; then  # operate on pipsi itself
      bake which pipsi || return "${STATUS_MISSING}"
      if [[ ${global} == true ]]; then
        bake type -ap pipsi |grep '^/usr' || return "${STATUS_MISSING}"
      else
        bake type -ap pipsi |grep "^${HOME}" || return "${STATUS_MISSING}"
      fi
      # we got here so pipsi is available, check if up-to-date same as
      # a regular packge
      name="pipsi"
    else  # operate on provided packge
      bake which pipsi || return "${STATUS_FAILED_PRECONDITION}"

      # check output of `pipsi list` to see if package is installed
      [[ $(bake pipsi "${pipsi_opts[@]}" list) =~ "Package \"${name}\"" ]] \
        || return "${STATUS_MISSING}"
    fi

    # pipsi doesn't provide a way to check if packge is up-to-date,
    # so for now have to use `pip` directly, which also means we need
    # to know location of pipsi virtualenvs
    pip="${pipsi_home}/${name}/bin/pip"
    ! bake "${pip}" list --outdated --format=legacy | egrep "^${name} " \
      || return "${STATUS_OUTDATED}"
    return "${STATUS_OK}"
    ;;
  install)
    su="$(get_su)"
    if [[ -z ${name} ]]; then  # operate on pipsi itself
      # escape the pipe as we want `bake` to evaluate it lazily
      bake curl -fsSL \
        https://raw.githubusercontent.com/mitsuhiko/pipsi/master/get-pipsi.py \
        \| "${su}" python - "${pipsi_opts[@]}"
    else  # operate on provided packge
      bake "${su}" pipsi "${pipsi_opts[@]}" install "${name}"
    fi
    ;;
  upgrade|delete)
    if [[ ${action} == delete ]]; then
      action="uninstall"
    fi
    if [[ -z ${name} ]]; then
      name="pipsi"
    fi
    bake "$(get_su)" pipsi "${pipsi_opts[@]}" "${action}" "${name}"
    ;;
  *) return 1 ;;
esac