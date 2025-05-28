#!/usr/bin/env bash

source "$(dirname "$0")/../lib/utils.sh"

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"
INSTALL_MODE="${INSTALL_MODE:-full}"
declare -a INSTALLED_TOOLS_BY_SCRIPT=() 


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
      read -p "Möchtest du alle installierten Homebrew-Pakete aktualisieren? (y/N): " -r upgrade_choice
      upgrade_choice=${upgrade_choice:-N}
      if [[ "$upgrade_choice" =~ ^[Yy]$ ]]; then
        if execute_or_dryrun "Alle Homebrew Pakete aktualisieren (Benutzerauswahl)" brew upgrade; then
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

  while IFS= read -r tool_name || [[ -n "$tool_name" ]]; do
    tool_name=$(echo "$tool_name" | xargs) 
    [[ "$tool_name" =~ ^#.*$ || -z "$tool_name" ]] && continue

    if install_package "$tool_name"; then
        INSTALLED_TOOLS_BY_SCRIPT+=("$tool_name")
    fi
  done < "$tool_file"
}


setup_package_manager

ESSENTIALS_TOOLS_FILE="$(dirname "$0")/../config/brew_essentials.txt"
install_tools_from_file "$ESSENTIALS_TOOLS_FILE" "essentielle"

export SELECTED_OPTIONAL_TOOLS_LIST="" 

if [[ "$INSTALL_MODE" == "full" ]]; then
    OPTIONAL_TOOLS_FILE="$(dirname "$0")/../config/brew_optionals.txt"

    log_info "Installiere alle optionalen Tools (Modus: full)..."
    install_tools_from_file "$OPTIONAL_TOOLS_FILE" "optionale"

    if [[ -f "$OPTIONAL_TOOLS_FILE" ]]; then
        temp_selected_opts=()
        while IFS= read -r tool_name || [[ -n "$tool_name" ]]; do
            tool_name=$(echo "$tool_name" | xargs)
            [[ "$tool_name" =~ ^#.*$ || -z "$tool_name" ]] && continue
            # Prüfe, ob das Tool jetzt installiert ist
            if $PKG_LIST_CMD "$tool_name" &>/dev/null; then
                temp_selected_opts+=("$tool_name")
            fi
        done < "$OPTIONAL_TOOLS_FILE"
        SELECTED_OPTIONAL_TOOLS_LIST=$(IFS=" "; echo "${temp_selected_opts[*]}")
    fi
fi

log_success "Tool-Installation abgeschlossen."
