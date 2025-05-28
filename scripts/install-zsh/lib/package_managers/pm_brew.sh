#!/usr/bin/env bash
set -eo pipefail
set -u

function pm_brew_install_self_if_needed() {
    if ! command_exists "brew"; then
        log_info "🍺 Homebrew nicht gefunden. Installiere Homebrew..."
        if ! execute_or_dryrun "Homebrew Installation" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" -- --non-interactive; then
            return 1
        fi
        [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ Homebrew installiert."
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
    if ! pm_brew_setup_environment; then
        log_warn "Einrichtung der Homebrew-Umgebung (shellenv) nicht vollständig erfolgreich."
    fi
    log_info "Homebrew Paketmanager-Treiber initialisiert und Umgebung eingerichtet."
    return 0
}

function pm_brew_is_installed() {
    local package_name="$1"
    brew list "$package_name" &>/dev/null
}

function pm_brew_install() {
    local package_name="$1"
    local dry_run_flag="${DRY_RUN:-false}" 
    
    if pm_brew_is_installed "$package_name"; then
        log_success "$package_name ist bereits installiert."
        echo "already_installed"
        return 0
    fi

    log_info "📦 Installiere $package_name via Homebrew..."
    if execute_or_dryrun "$package_name Homebrew Installation" brew install "$package_name"; then
        if [[ "$dry_run_flag" == false ]]; then
            log_success "✅ $package_name installiert."
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
    local uninstall_args=("uninstall")
    [[ "$force_flag" == true ]] && uninstall_args+=("--force")
    uninstall_args+=("$package_name")

    if ! pm_brew_is_installed "$package_name"; then
        log_info "$package_name ist nicht via Homebrew installiert."
        return 0 
    fi

    log_info "🗑️  Entferne $package_name via Homebrew..."
    if execute_or_dryrun "$package_name Homebrew Deinstallation" brew "${uninstall_args[@]}"; then
        [[ "${DRY_RUN:-false}" == false ]] && log_success "🗑️ $package_name entfernt."
        return 0
    else
        return 1
    fi
}

function pm_brew_update_index() {
    if execute_or_dryrun "Homebrew Index aktualisieren (brew update)" brew update; then
      [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ Homebrew Index aktualisiert."
      return 0
    else
      return 1
    fi
}

function pm_brew_update_all() {
    if execute_or_dryrun "Alle Homebrew Pakete aktualisieren (brew upgrade)" brew upgrade; then
      [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ Alle Homebrew Pakete aktualisiert."
      return 0
    else
      return 1
    fi
}

function pm_brew_autoremove() {
    if execute_or_dryrun "Homebrew Autoremove" brew autoremove --force; then
      [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ Homebrew Autoremove erfolgreich."
      return 0
    else
      return 1
    fi
}

function pm_brew_cask_is_installed() {
    local cask_name="$1"
    brew list --cask "$cask_name" &>/dev/null
}

function pm_brew_cask_install() {
    local cask_name="$1"
    local dry_run_flag="${DRY_RUN:-false}"

    if pm_brew_cask_is_installed "$cask_name"; then
        log_success "Cask $cask_name ist bereits installiert."
        echo "already_installed"
        return 0
    fi
    log_info "📦 Installiere Cask $cask_name via Homebrew..."
    if execute_or_dryrun "$cask_name Homebrew Cask Installation" brew install --cask "$cask_name"; then
        if [[ "$dry_run_flag" == false ]]; then
            log_success "✅ Cask $cask_name installiert."
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

function pm_brew_cask_uninstall() {
    local cask_name="$1"
    local force_flag="${2:-false}"
    local uninstall_args=("uninstall" "--cask")
    [[ "$force_flag" == true ]] && uninstall_args+=("--force")
    uninstall_args+=("$cask_name")

    if ! pm_brew_cask_is_installed "$cask_name"; then
        log_info "Cask $cask_name ist nicht via Homebrew installiert."
        return 0
    fi
    log_info "🗑️  Entferne Cask $cask_name via Homebrew..."
    if execute_or_dryrun "$cask_name Homebrew Cask Deinstallation" brew "${uninstall_args[@]}"; then
        [[ "${DRY_RUN:-false}" == false ]] && log_success "🗑️ Cask $cask_name entfernt."
        return 0
    else
        return 1
    fi
}

pkg_init="pm_brew_init"
pkg_is_installed="pm_brew_is_installed"
pkg_install="pm_brew_install"
pkg_uninstall="pm_brew_uninstall"
pkg_update_index="pm_brew_update_index"
pkg_update_all="pm_brew_update_all"
pkg_autoremove="pm_brew_autoremove"

pkg_cask_is_installed="pm_brew_cask_is_installed"
pkg_cask_install="pm_brew_cask_install"
pkg_cask_uninstall="pm_brew_cask_uninstall"

PM_NAME="Homebrew"
