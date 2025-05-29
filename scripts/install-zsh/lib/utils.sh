#!/usr/bin/env bash
set -eo pipefail
set -u

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_CYAN='\033[1;36m'

if [[ -t 1 ]] && type tput &>/dev/null; then
    if [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
        :
    else
        COLOR_RESET=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_RED=''; COLOR_BLUE=''; COLOR_CYAN='';
    fi
else
    COLOR_RESET=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_RED=''; COLOR_BLUE=''; COLOR_CYAN='';
fi

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

function try_install_gum() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        log_info "[DRY RUN] Würde Installation von 'gum' prüfen und ggf. anbieten."
        return 1
    fi

    log_warn "'gum' nicht gefunden. Es wird für eine bessere interaktive Erfahrung empfohlen."
    local install_gum_confirm
    read -p "Möchtest du 'gum' jetzt über $PM_NAME installieren? (Y/n): " -r install_gum_confirm
    local choice_val_gum="${install_gum_confirm:-Y}"

    if [[ "$choice_val_gum" =~ ^[Yy]$ ]]; then
        log_info "Installiere 'gum'..."
        if ! type "$pkg_install" &>/dev/null || [[ -z "$pkg_install" ]]; then
            log_error "Fehler: pkg_install Variable ('$pkg_install') zeigt nicht auf eine gültige Funktion. Kann 'gum' nicht installieren."
            return 1
        fi

        if "$pkg_install" "gum" > /dev/null; then
            if command_exists "gum"; then
                log_success "'gum' erfolgreich installiert/gefunden."
                return 0
            else
                log_error "Installation von 'gum' scheint fehlgeschlagen zu sein (Befehl nicht gefunden nach Installation)."
                return 1
            fi
        else
            log_error "Fehler bei der Installation von 'gum' (Aufruf von $pkg_install fehlgeschlagen)."
            return 1
        fi
    else
        log_warn "Installation von 'gum' übersprungen."
        return 1
    fi
}

function gum_confirm_wrapper() {
    local prompt_message="$1"
    local read_default="${2:-N}"

    if [[ "${AUTO_CONFIRM:-false}" == true ]]; then
        log_info "Automatische Zustimmung für \"$prompt_message\" durch --yes Flag."
        return 0
    fi

    if ! command_exists "gum"; then
        if ! try_install_gum; then
            log_warn "Fallback zu 'read -p' für Bestätigung, da 'gum' nicht verfügbar/installiert wurde."
            local user_choice
            read -p "$prompt_message ($read_default): " -r user_choice
            local choice_val="${user_choice:-$read_default}"
            if [[ "$choice_val" =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        fi
    fi

    if gum confirm "$prompt_message"; then
        return 0
    else
        return 1
    fi
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
    local temp_output_file=""
    local temp_content_file=""

    _cleanup_temp_files() {
        set +u
        if [[ -n "$temp_output_file" && -f "$temp_output_file" ]]; then
            rm -f "$temp_output_file"
        fi
        if [[ -n "$temp_content_file" && -f "$temp_content_file" ]]; then
            rm -f "$temp_content_file"
        fi
        set -u
    }
    trap _cleanup_temp_files RETURN EXIT SIGINT SIGTERM

    temp_output_file=$(mktemp)
    if [[ -z "$temp_output_file" || ! -f "$temp_output_file" ]]; then
        log_error "Konnte temporäre Ausgabedatei nicht erstellen mit mktemp."
        return 1
    fi

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
        ' "$target_file" > "$temp_output_file"
        if cp "$temp_output_file" "$target_file"; then
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

    temp_content_file=$(mktemp)
    if [[ -z "$temp_content_file" || ! -f "$temp_content_file" ]]; then
        log_error "Konnte temporäre Inhaltsdatei nicht erstellen mit mktemp."
        return 1
    fi
    echo -e "$block_content" > "$temp_content_file"

    awk -v sm="$start_marker" \
        -v em="$end_marker" \
        -v content_file="$temp_content_file" \
        '
        BEGIN {
            in_block = 0;
            block_written = 0;
        }
        $0 == sm {
            if (!block_written) {
                print sm;
                while ((getline line < content_file) > 0) {
                    print line;
                }
                close(content_file);
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
                while ((getline line < content_file) > 0) {
                    print line;
                }
                close(content_file);
                print em;
            }
        }
        { prev_line = $0 }
        ' "$target_file" > "$temp_output_file"

    if cp "$temp_output_file" "$target_file"; then
        log_success "📝 Block '$start_marker' in '$target_file' aktualisiert/hinzugefügt."
    else
        local cp_exit_code=$?
        log_error "Fehler beim Kopieren von temp_output_file nach '$target_file' (Exit Code: $cp_exit_code)."
        if [[ -f "$temp_output_file" ]]; then
            log_error "Inhalt von temp_output_file ($temp_output_file):"
            cat "$temp_output_file"
        else
            log_error "temp_output_file ($temp_output_file) wurde nicht erstellt oder ist nicht lesbar."
        fi
        if [[ -f "$target_file" ]]; then
            log_error "Berechtigungen von target_file ($target_file):"
            ls -l "$target_file"
        else
            log_error "target_file ($target_file) existiert nicht."
        fi
        return 1
    fi
    return 0
}

PM_NAME=""

pkg_init=""
pkg_is_installed=""
pkg_install=""
pkg_uninstall=""
pkg_update_index=""
pkg_update_all=""
pkg_autoremove=""


function detect_and_load_package_manager_driver() {
    log_step "Erkenne und lade Paketmanager-Treiber..."
    local base_dir_pm
    base_dir_pm="$(dirname "${BASH_SOURCE[0]}")/package_managers"

    if command_exists "brew"; then
        log_info "Homebrew erkannt."
        if [[ -f "$base_dir_pm/pm_brew.sh" ]]; then
            # shellcheck source=package_managers/pm_brew.sh
            source "$base_dir_pm/pm_brew.sh"
        else
            log_error "Homebrew-Treiber ($base_dir_pm/pm_brew.sh) nicht gefunden."
            return 1
        fi
    elif command_exists "apt-get"; then
        log_info "APT (Debian/Ubuntu) erkannt."
        log_error "APT-Treiber ist noch nicht implementiert."
        return 1
    else
        log_error "Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    if [[ -z "$pkg_init" ]]; then
        log_error "Paketmanager-Treiber wurde gesourct, aber pkg_init wurde nicht korrekt zugewiesen (ist leer)."
        return 1
    fi
    if ! type "$pkg_init" &>/dev/null; then
        log_error "Der in pkg_init ('$pkg_init') zugewiesene Name ist keine gültige Funktion."
        return 1
    fi

    if ! "$pkg_init"; then
        log_error "Initialisierung des Paketmanager-Treibers ($PM_NAME) fehlgeschlagen."
        return 1
    fi
    return 0
}
