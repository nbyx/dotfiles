#!/usr/bin/env bash
set -eo pipefail
set -u

function _pm_brew_is_package_a_cask() {
    local package_name_to_check="$1"
    if brew info --cask "$package_name_to_check" &>/dev/null; then
        return 0 
    else
        return 1 
    fi
}

function pm_brew_install_self_if_needed() {
    if ! command_exists "brew"; then
        log_info "🍺 Homebrew nicht gefunden. Installiere Homebrew..."
        if ! execute_or_dryrun "Homebrew Installation" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" -- --non-interactive; then
            return 1
        fi
    fi
    return 0
}

function pm_brew_setup_environment() {
    log_info "Richte Homebrew-Umgebung ein (shellenv)..."
    local brew_executable_path=""
    if [[ -x "/opt/homebrew/bin/brew" ]]; then brew_executable_path="/opt/homebrew/bin/brew";
    elif [[ -x "/usr/local/bin/brew" ]]; then brew_executable_path="/usr/local/bin/brew";
    elif command_exists "brew"; then brew_executable_path=$(command -v brew);
    fi

    if [[ -z "$brew_executable_path" ]]; then
        log_warn "Konnte Homebrew Executable nicht finden, um shellenv zu konfigurieren."
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == false ]]; then
        log_info "Aktiviere Homebrew für die aktuelle Shell-Sitzung..."
        eval "$($brew_executable_path shellenv)"
    else
        log_info "[DRY RUN] Würde Homebrew für aktuelle Shell-Sitzung aktivieren."
    fi

    local homebrew_shellenv_block_content
    read -r -d '' homebrew_shellenv_block_content <<EOF
# Initialize Homebrew environment (added by dotfiles installer)
if [ -x "$brew_executable_path" ]; then
  eval "\$($brew_executable_path shellenv)"
fi
EOF
    manage_config_block "$ZSHRC_DOTFILES_HOMEBREW_SHELLENV_START_MARKER" "$ZSHRC_DOTFILES_HOMEBREW_SHELLENV_END_MARKER" "$homebrew_shellenv_block_content" "$ZSHRC_DEST"
    return 0
}

function pm_brew_init() {
    if ! pm_brew_install_self_if_needed; then
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == false ]]; then
        local brew_exe_path_init
        if [[ -x "/opt/homebrew/bin/brew" ]]; then brew_exe_path_init="/opt/homebrew/bin/brew";
        elif [[ -x "/usr/local/bin/brew" ]]; then brew_exe_path_init="/usr/local/bin/brew";
        elif command_exists "brew"; then brew_exe_path_init=$(command -v brew);
        else brew_exe_path_init=""; fi

        if [[ -n "$brew_exe_path_init" ]]; then
            log_info "Aktiviere Homebrew für die aktuelle Installer-Sitzung..."
            if ! eval "$($brew_exe_path_init shellenv)"; then
                log_warn "Konnte Homebrew nicht vollständig für die aktuelle Shell-Sitzung aktivieren (eval shellenv fehlgeschlagen)."
            fi
        else
            log_warn "brew Kommando nicht im PATH nach potenzieller Installation in pm_brew_init."
        fi
    fi
    log_info "Homebrew Paketmanager-Treiber initialisiert (Bereit für Tool-Installationen)."
    return 0
}

function pm_brew_is_installed() {
    local package_name="$1"
    if _pm_brew_is_package_a_cask "$package_name"; then
        brew list --cask "$package_name" &>/dev/null
    else
        brew list "$package_name" &>/dev/null
    fi
}

function pm_brew_install() {
    local package_name="$1"
    local dry_run_flag="${DRY_RUN:-false}"
    local install_cmd_args=("install")

    if pm_brew_is_installed "$package_name"; then
        log_success "$package_name ist bereits installiert."
        echo "already_installed"
        return 0
    fi

    if _pm_brew_is_package_a_cask "$package_name"; then
        install_cmd_args+=("--cask")
    fi
    install_cmd_args+=("$package_name")

    if execute_or_dryrun "$package_name Homebrew Installation" brew "${install_cmd_args[@]}"; then
        if [[ "$dry_run_flag" == false ]]; then
            echo "newly_installed"
        else
            echo "dry_run_would_install"
        fi
        return 0
    else
        echo "install_failed"
        return 1
    fi
}

function pm_brew_uninstall() {
    local package_name="$1"
    local force_flag="${2:-false}"
    local uninstall_cmd_args=("uninstall")

    local is_installed_as_cask=false
    if brew list --cask "$package_name" &>/dev/null; then
        is_installed_as_cask=true
    elif ! brew list "$package_name" &>/dev/null; then
        log_info "$package_name ist nicht via Homebrew installiert."
        return 0
    fi

    if $is_installed_as_cask; then
        uninstall_cmd_args+=("--cask")
    fi

    [[ "$force_flag" == true ]] && uninstall_cmd_args+=("--force")
    uninstall_cmd_args+=("$package_name")

    if execute_or_dryrun "$package_name Homebrew Deinstallation" brew "${uninstall_cmd_args[@]}"; then
        return 0
    else
        return 1
    fi
}

function pm_brew_update_index() {
    if execute_or_dryrun "Homebrew Index aktualisieren (brew update)" brew update; then
      return 0
    else
      return 1
    fi
}

function pm_brew_update_all() {
    if execute_or_dryrun "Alle Homebrew Pakete aktualisieren (brew upgrade)" brew upgrade; then
      return 0
    else
      return 1
    fi
}

function pm_brew_autoremove() {
    if execute_or_dryrun "Homebrew Autoremove" brew autoremove; then
      return 0
    else
      return 1
    fi
}

export pkg_init="pm_brew_init"
export pkg_is_installed="pm_brew_is_installed"
export pkg_install="pm_brew_install"
export pkg_uninstall="pm_brew_uninstall"
export pkg_update_index="pm_brew_update_index"
export pkg_update_all="pm_brew_update_all"
export pkg_autoremove="pm_brew_autoremove"
export pkg_setup_shell_config="pm_brew_setup_environment"

export PM_NAME="Homebrew"
