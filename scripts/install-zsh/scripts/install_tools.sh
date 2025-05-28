#!/usr/bin/env bash
set -eo pipefail
set -u

# shellcheck source=../lib/utils.sh
source "$(dirname "$0")/../lib/utils.sh"

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"
INSTALL_MODE="${INSTALL_MODE:-full}"
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"

MANIFEST_FILE="$HOME/.config/dotfiles_installer/installed_tools_manifest.txt"

function setup_package_manager() {
  log_step "Paketmanager einrichten (Homebrew)"
  
  local brew_executable_path=""
  if [[ -x "/opt/homebrew/bin/brew" ]]; then brew_executable_path="/opt/homebrew/bin/brew";
  elif [[ -x "/usr/local/bin/brew" ]]; then brew_executable_path="/usr/local/bin/brew";
  elif command_exists "brew"; then brew_executable_path=$(command -v brew);
  fi

  if [[ -z "$brew_executable_path" ]]; then
    log_info "🍺 Homebrew nicht gefunden. Installiere Homebrew..."
    if ! execute_or_dryrun "Homebrew Installation" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" -- --non-interactive; then
        [[ "$DRY_RUN" == false ]] && exit 1
    fi
    [[ "$DRY_RUN" == false ]] && log_success "✅ Homebrew installiert."
    if [[ -x "/opt/homebrew/bin/brew" ]]; then brew_executable_path="/opt/homebrew/bin/brew";
    elif [[ -x "/usr/local/bin/brew" ]]; then brew_executable_path="/usr/local/bin/brew"; fi
    
    if [[ "$DRY_RUN" == false && -z "$brew_executable_path" ]]; then
        log_error "Konnte Homebrew nach der Installation nicht im erwarteten Pfad finden. Breche ab."
        exit 1
    fi
  else
    log_success "Homebrew ist bereits installiert."
  fi

  if [[ -n "$brew_executable_path" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
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
  else
    log_warn "Homebrew Executable nicht im Standardpfad gefunden. Überspringe shellenv Konfiguration."
  fi
  
  PKG_CMD="brew"
  PKG_INSTALL_CMD="brew install"
  PKG_LIST_CMD="brew list"
  PKG_CASK_INSTALL_CMD="brew install --cask"
  PKG_CASK_LIST_CMD="brew list --cask"
  PKG_MANAGER_NAME="Homebrew"

  if [[ "$DRY_RUN" == false ]] && ( [[ "$PERFORM_UPDATES" == true ]] || [[ "$INSTALL_MODE" == "full" ]] ); then
    if execute_or_dryrun "Homebrew Formeln aktualisieren" brew update; then
        [[ "$DRY_RUN" == false ]] && log_success "✅ Homebrew Formeln aktualisiert."
    fi
  fi

  if [[ "$DRY_RUN" == false && "$PERFORM_UPDATES" == true ]]; then
    if execute_or_dryrun "Alle Homebrew Pakete aktualisieren" brew upgrade; then
        [[ "$DRY_RUN" == false ]] && log_success "✅ Alle Homebrew Pakete aktualisiert."
    fi
  elif [[ "$DRY_RUN" == false && "$INSTALL_MODE" == "full" && "$PERFORM_UPDATES" == false ]]; then
      confirm_upgrade=false
      if [[ "$AUTO_CONFIRM" == true ]]; then
          confirm_upgrade=true
          log_info "Automatische Zustimmung zum Homebrew-Paket-Upgrade durch --yes Flag."
      else
          read -p "Möchtest du alle installierten Homebrew-Pakete aktualisieren? (y/N): " -r upgrade_choice
          local choice_val="${upgrade_choice:-N}" 
          if [[ "$choice_val" =~ ^[Yy]$ ]]; then
              confirm_upgrade=true
          fi
      fi

      if $confirm_upgrade; then
        if execute_or_dryrun "Alle Homebrew Pakete aktualisieren (Benutzerauswahl/--yes)" brew upgrade; then
            log_success "✅ Alle Homebrew Pakete aktualisiert."
        fi
      else
        log_warn "Überspringe Homebrew-Paket-Upgrade."
      fi
  fi
}

function install_tools_from_file() {
  local tool_file="$1"
  local tool_type="$2"
  
  log_step "Installiere $tool_type Tools aus $tool_file"
  if [[ ! -f "$tool_file" ]]; then
    log_warn "Tool-Datei $tool_file nicht gefunden."
    return
  fi

  if [[ "$DRY_RUN" == false ]]; then
      mkdir -p "$(dirname "$MANIFEST_FILE")"
      touch "$MANIFEST_FILE"
  fi

  local tool_name_raw 
  while IFS= read -r tool_name_raw || [[ -n "$tool_name_raw" ]]; do
    local tool_name
    tool_name=$(echo "$tool_name_raw" | xargs) 
    [[ "$tool_name" =~ ^#.*$ || -z "$tool_name" ]] && continue

    local is_cask=false
    case "$tool_name" in
        iterm2|font-hack-nerd-font) is_cask=true ;;
    esac

    local install_status_output
    local exit_code
    if $is_cask; then
        install_status_output=$(install_cask_package "$tool_name")
        exit_code=$?
    else
        install_status_output=$(install_package "$tool_name")
        exit_code=$?
    fi
    
    if [[ "$exit_code" -eq 0 ]]; then
        if [[ "$DRY_RUN" == false && "$install_status_output" == "newly_installed" ]]; then
            if ! grep -Fxq "$tool_name" "$MANIFEST_FILE" 2>/dev/null; then
                echo "$tool_name" >> "$MANIFEST_FILE"
            fi
        fi
    else
        log_warn "Installation von $tool_name ($tool_type) nicht erfolgreich abgeschlossen (Status: $install_status_output)."
    fi
  done < "$tool_file"
}

setup_package_manager

ESSENTIALS_TOOLS_FILE="$(dirname "$0")/../config/brew_essentials.txt"
install_tools_from_file "$ESSENTIALS_TOOLS_FILE" "essentielle"

export SELECTED_OPTIONAL_TOOLS_LIST="" 

if [[ "$INSTALL_MODE" == "full" ]]; then
    OPTIONAL_TOOLS_FILE="$(dirname "$0")/../config/brew_optionals.txt"
    log_info "Installiere optionale Tools (Modus: full)..."
    install_tools_from_file "$OPTIONAL_TOOLS_FILE" "optionale"
    
    if [[ -f "$OPTIONAL_TOOLS_FILE" ]]; then
        temp_selected_opts=()
        tool_name_raw_opt="" 
        while IFS= read -r tool_name_raw_opt || [[ -n "$tool_name_raw_opt" ]]; do
            local tool_name_opt
            tool_name_opt=$(echo "$tool_name_raw_opt" | xargs)
            [[ "$tool_name_opt" =~ ^#.*$ || -z "$tool_name_opt" ]] && continue
            # shellcheck disable=SC2086
            if $PKG_LIST_CMD $tool_name_opt &>/dev/null; then
                temp_selected_opts+=("$tool_name_opt")
            fi
        done < "$OPTIONAL_TOOLS_FILE"
        SELECTED_OPTIONAL_TOOLS_LIST=$(IFS=" "; echo "${temp_selected_opts[*]}")
    fi
fi

if [[ "$DRY_RUN" == false && -f "$MANIFEST_FILE" ]]; then
    sort -u "$MANIFEST_FILE" -o "$MANIFEST_FILE"
    log_info "Manifest der durch diesen Installer neu installierten Tools aktualisiert: $MANIFEST_FILE"
fi

log_success "Tool-Installation abgeschlossen."
