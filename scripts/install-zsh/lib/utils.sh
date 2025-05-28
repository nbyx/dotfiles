#!/usr/bin/env bash
set -eo pipefail
set -u

# shellcheck disable=SC2034
ZSHRC_DEST="$HOME/.zshrc"
# shellcheck disable=SC2034
ZSHRC_BACKUP_FILE="$HOME/.zshrc.pre-dotfiles-installer-backup"
# shellcheck disable=SC2034
OMZ_DIR="$HOME/.oh-my-zsh"
# shellcheck disable=SC2034
OMZ_CUSTOM_DIR="${OMZ_DIR}/custom"

# shellcheck disable=SC2034
ZSHRC_DOTFILES_HOMEBREW_SHELLENV_START_MARKER="# DOTFILES_HOMEBREW_SHELLENV_START"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_HOMEBREW_SHELLENV_END_MARKER="# DOTFILES_HOMEBREW_SHELLENV_END"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_OMZ_PLUGINS_START_MARKER="# DOTFILES_OMZ_PLUGINS_START"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_OMZ_PLUGINS_END_MARKER="# DOTFILES_OMZ_PLUGINS_END"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_NEOFETCH_START_MARKER="# DOTFILES_NEOFETCH_WELCOME_START"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_NEOFETCH_END_MARKER="# DOTFILES_NEOFETCH_WELCOME_END"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_START_MARKER="# DOTFILES_FZF_ADVANCED_CONFIG_START"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_END_MARKER="# DOTFILES_FZF_ADVANCED_CONFIG_END"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER="# DOTFILES_TOOL_ALIASES_START"
# shellcheck disable=SC2034
ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER="# DOTFILES_TOOL_ALIASES_END"

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'

function log_step { echo -e "\n${COLOR_BLUE}➡️  $1${COLOR_RESET}"; }
function log_success { echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"; }
function log_error { echo -e "${COLOR_RED}❌ $1${COLOR_RESET}"; }
function log_warn { echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"; }
function log_info { echo -e "${COLOR_GREEN}ℹ️  $1${COLOR_RESET}"; }

function run_command() {
  local description="$1"
  shift
  log_step "$description"
  if "$@"; then
    log_success "$description: Erfolgreich."
  else
    log_error "$description: Fehlgeschlagen (Exit Code: $?)."
    exit 1
  fi
}

function execute_or_dryrun() {
    local action_description="$1"
    shift
    local cmd_to_run=("$@")
    if [[ "${DRY_RUN:-false}" == true ]]; then
        log_info "[DRY RUN] Würde Aktion '$action_description' ausführen: ${cmd_to_run[*]}"
        return 0
    else
        if "${cmd_to_run[@]}"; then
            return 0
        else
            log_error "Fehler bei Aktion '$action_description' (Befehl: ${cmd_to_run[*]})"
            return 1
        fi
    fi
}

function command_exists() {
  command -v "$1" &>/dev/null
}

function append_if_missing() {
  local file="$1"
  local line="$2"
  local dry_run_flag="${DRY_RUN:-false}"
  if [[ "$dry_run_flag" == true && ! -f "$file" ]]; then
    log_info "[DRY RUN] Datei '$file' existiert nicht. Würde hinzufügen: $line"
    return
  fi
  if ! grep -Fxq -- "$line" "$file" 2>/dev/null; then
    if [[ "$dry_run_flag" == true ]]; then
      log_info "[DRY RUN] Würde zur Datei '$file' hinzufügen: $line"
    else
      if [[ ! -f "$file" ]]; then
        mkdir -p "$(dirname "$file")"
        touch "$file"
      fi
      if [[ -s "$file" ]] && [[ "$(tail -c1 "$file"; echo x)" != $'\nx' ]]; then
          echo "" >> "$file"
      fi
      echo "$line" >> "$file"
      log_success "📝 Zur Datei '$file' hinzugefügt: $line"
    fi
  else
    log_info "Eintrag existiert bereits in '$file': $line"
  fi
}

function manage_config_block() {
    local start_marker="$1"
    local end_marker="$2"
    local block_content="$3"
    local target_file="$4"
    local dry_run_flag="${DRY_RUN:-false}"
    local uninstall_flag="${UNINSTALL_MODE:-false}"
    local temp_file
    temp_file=$(mktemp) || { log_error "Konnte temporäre Datei nicht erstellen."; return 1; }
    trap 'rm -f "$temp_file"' RETURN

    if [[ "$dry_run_flag" == true && "$uninstall_flag" == false ]]; then
        log_info "[DRY RUN] Würde Block '$start_marker' in '$target_file' verwalten mit Inhalt:"
        echo -e "$block_content"
        return 0
    fi

    if [[ "$uninstall_flag" == true && "$block_content" == "__REMOVE_BLOCK__" ]]; then
        if [[ "$dry_run_flag" == true ]]; then
            log_info "[DRY RUN] Würde Block '$start_marker' aus '$target_file' entfernen."
            return 0
        fi
        if [[ ! -f "$target_file" ]]; then
            log_info "Datei '$target_file' nicht gefunden. Nichts zu entfernen für Block '$start_marker'."
            return 0
        fi
        awk -v sm="$start_marker" -v em="$end_marker" '
            BEGIN { printing = 1 }
            $0 == sm { printing = 0; next }
            $0 == em { printing = 1; next }
            printing { print }
        ' "$target_file" > "$temp_file"
        if cp "$temp_file" "$target_file"; then
            log_success "🗑️ Block '$start_marker' aus '$target_file' entfernt."
        else
            log_error "Fehler beim Entfernen des Blocks '$start_marker' aus '$target_file'."
            return 1
        fi
        return 0
    fi

    if [[ "$dry_run_flag" == true && ! -f "$target_file" ]]; then
        log_info "[DRY RUN] Datei '$target_file' existiert nicht. Würde Block '$start_marker' erstellen mit Inhalt:"
        echo -e "$block_content"
        return 0
    fi
    
    if [[ ! -f "$target_file" ]] && [[ "$dry_run_flag" == false ]]; then
        mkdir -p "$(dirname "$target_file")"
        touch "$target_file"
        log_info "Datei $target_file erstellt."
    fi

    awk -v sm="$start_marker" \
        -v em="$end_marker" \
        -v content="$block_content" \
        '
        BEGIN {
            in_block = 0;
            block_written = 0;
            if (content != "") {
                split(content, lines, "\n");
                lines_len = length(lines);
            } else {
                lines_len = 0; 
            }
        }
        $0 == sm {
            if (!block_written) {
                print sm;
                for (i=1; i<=lines_len; i++) {
                    print lines[i];
                }
                print em;
                block_written = 1;
            }
            in_block = 1;
            next;
        }
        $0 == em {
            in_block = 0;
            next;
        }
        !in_block { print; }
        END {
            if (!block_written) {
                if (NR > 0 && prev_line != "") print "";
                print sm;
                for (i=1; i<=lines_len; i++) {
                    print lines[i];
                }
                print em;
            }
        }
        { prev_line = $0 }
        ' "$target_file" > "$temp_file"

    if cp "$temp_file" "$target_file"; then
        log_success "📝 Block '$start_marker' in '$target_file' aktualisiert/hinzugefügt."
    else
        log_error "Fehler beim Aktualisieren des Blocks '$start_marker' aus '$target_file'."
        return 1
    fi
    return 0
}

PKG_CMD=""
PKG_INSTALL_CMD=""
PKG_LIST_CMD=""
PKG_CASK_INSTALL_CMD=""
PKG_CASK_LIST_CMD=""
PKG_MANAGER_NAME=""

function install_package() {
  local package_name="$1"
  local dry_run_flag="${DRY_RUN:-false}"
  
  if [[ -z "$PKG_CMD" || -z "$PKG_INSTALL_CMD" || -z "$PKG_LIST_CMD" ]]; then
    log_error "Paketmanager-Befehle nicht initialisiert. Kann '$package_name' nicht installieren."
    echo "install_failed_no_pkg_manager"
    return 1
  fi

  local is_installed=false
  if [[ "$PKG_CMD" == "brew" ]]; then
    # shellcheck disable=SC2086
    $PKG_LIST_CMD $package_name &>/dev/null && is_installed=true
  else
    log_warn "Installationsprüfung für $PKG_CMD nicht implementiert."
  fi

  if ! $is_installed; then
    log_info "📦 Installiere $package_name..."
    # shellcheck disable=SC2086
    if execute_or_dryrun "$package_name Installation" $PKG_INSTALL_CMD $package_name; then
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
  else
    log_success "$package_name ist bereits installiert."
    echo "already_installed"
    return 0
  fi
}

function install_cask_package() {
  local cask_name="$1"
  local dry_run_flag="${DRY_RUN:-false}"

  if [[ "$PKG_MANAGER_NAME" != "Homebrew" ]]; then
    log_warn "Cask-Installation ist spezifisch für Homebrew."
    echo "install_failed_wrong_pkg_manager"
    return 1
  fi
  if [[ -z "$PKG_CASK_INSTALL_CMD" || -z "$PKG_CASK_LIST_CMD" ]]; then
    log_error "Cask-Paketmanager-Befehle nicht initialisiert. Kann '$cask_name' nicht installieren."
    echo "install_failed_no_cask_cmd"
    return 1
  fi

  # shellcheck disable=SC2086
  if ! $PKG_CASK_LIST_CMD $cask_name &>/dev/null; then
    log_info "📦 Installiere Cask $cask_name..."
    # shellcheck disable=SC2086
    if execute_or_dryrun "$cask_name Cask Installation" $PKG_CASK_INSTALL_CMD $cask_name; then
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
  else
    log_success "Cask $cask_name ist bereits installiert."
    echo "already_installed"
    return 0
  fi
}
