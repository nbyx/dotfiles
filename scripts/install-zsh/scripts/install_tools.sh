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

function update_package_manager_packages() {
    log_step "Aktualisiere Paketquellen und Pakete für $PM_NAME"

    if [[ "$DRY_RUN" == false ]] && ( [[ "$PERFORM_UPDATES" == true ]] || [[ "$INSTALL_MODE" == "full" ]] ); then
        if ! $pkg_update_index; then 
             log_warn "Aktualisierung des Paket-Index ($PM_NAME) fehlgeschlagen."
        fi
    fi

    if [[ "$DRY_RUN" == false && "$PERFORM_UPDATES" == true ]]; then
        if ! $pkg_update_all; then
            log_warn "Aktualisierung aller Pakete ($PM_NAME) fehlgeschlagen."
        fi
    elif [[ "$DRY_RUN" == false && "$INSTALL_MODE" == "full" && "$PERFORM_UPDATES" == false ]]; then
        confirm_upgrade=false
        if [[ "$AUTO_CONFIRM" == true ]]; then
            confirm_upgrade=true
            log_info "Automatische Zustimmung zum Paket-Upgrade ($PM_NAME) durch --yes Flag."
        else
            read -p "Möchtest du alle installierten $PM_NAME Pakete aktualisieren? (y/N): " -r upgrade_choice
            local choice_val="${upgrade_choice:-N}" 
            if [[ "$choice_val" =~ ^[Yy]$ ]]; then
                confirm_upgrade=true
            fi
        fi

        if $confirm_upgrade; then
            if ! $pkg_update_all; then
                 log_warn "Aktualisierung aller Pakete ($PM_NAME) fehlgeschlagen."
            fi
        else
            log_warn "Überspringe $PM_NAME Paket-Upgrade."
        fi
    fi
}

function install_tools_from_file() {
  local tool_file="$1"
  local tool_type="$2"
  
  log_step "Installiere $tool_type Tools aus $tool_file via $PM_NAME"
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
    if [[ "$PM_NAME" == "Homebrew" ]]; then
        case "$tool_name" in
            iterm2|font-hack-nerd-font) is_cask=true ;;
        esac
    fi

    local install_status_output
    local exit_code
    if $is_cask; then
        install_status_output=$($pkg_cask_install "$tool_name")
        exit_code=$?
    else
        install_status_output=$($pkg_install "$tool_name")
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

update_package_manager_packages

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
            if $pkg_is_installed "$tool_name_opt"; then
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
