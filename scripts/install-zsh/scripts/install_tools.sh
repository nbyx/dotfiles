#!/usr/bin/env bash
set -eo pipefail
set -u

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"
INSTALL_MODE="${INSTALL_MODE:-full}"
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"

MANIFEST_FILE="$HOME/.config/dotfiles_installer/installed_tools_manifest.txt"

function update_package_manager_packages() {
    log_step "Aktualisiere Paketquellen und Pakete für $PM_NAME"

    if [[ "$DRY_RUN" == false ]] && ( [[ "$PERFORM_UPDATES" == true ]] || [[ "$INSTALL_MODE" == "full" ]] ); then
        if ! "$pkg_update_index"; then
             log_warn "Aktualisierung des Paket-Index ($PM_NAME) fehlgeschlagen."
        fi
    fi

    if [[ "$DRY_RUN" == false && "$PERFORM_UPDATES" == true ]]; then
        if ! "$pkg_update_all"; then
            log_warn "Aktualisierung aller Pakete ($PM_NAME) fehlgeschlagen."
        fi
    elif [[ "$DRY_RUN" == false && "$INSTALL_MODE" == "full" && "$PERFORM_UPDATES" == false ]]; then
        if gum_confirm_wrapper "Möchtest du alle installierten $PM_NAME Pakete aktualisieren?" "N"; then
            if ! "$pkg_update_all"; then
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
  local tools_to_install_list=()

  if [[ "$tool_type" == "optionale_interaktiv" && ("$INSTALL_MODE" == "full_interactive" || "$INSTALL_MODE" == "full") ]]; then
    log_step "Wähle optionale Tools zur Installation via $PM_NAME"
    if [[ ! -f "$tool_file" ]]; then log_warn "Tool-Datei $tool_file nicht gefunden."; return; fi

    local available_opts_for_choice=()
    local tool_name_raw_choice
    while IFS= read -r tool_name_raw_choice || [[ -n "$tool_name_raw_choice" ]]; do
        local tool_name_choice
        tool_name_choice=$(echo "$tool_name_raw_choice" | xargs)
        [[ "$tool_name_choice" =~ ^#.*$ || -z "$tool_name_choice" ]] && continue

        if ! "$pkg_is_installed" "$tool_name_choice"; then
            available_opts_for_choice+=("$tool_name_choice")
        fi
    done < "$tool_file"

    if [[ ${#available_opts_for_choice[@]} -gt 0 ]]; then
        if ! command_exists "gum"; then
            if ! try_install_gum; then
                 log_warn "Installation von 'gum' fehlgeschlagen oder abgelehnt."
            fi
        fi

        if command_exists "gum"; then
            log_info "Verwende 'gum' für die interaktive Tool-Auswahl..."
            local selected_tools_str
            selected_tools_str=$(gum choose --no-limit --header "Wähle optionale Tools (SPACE zum Markieren, ENTER):" "${available_opts_for_choice[@]}")
            if [[ -n "$selected_tools_str" ]]; then
                while IFS= read -r selected_line; do
                    tools_to_install_list+=("$selected_line")
                done < <(echo "$selected_tools_str")
                log_success "Ausgewählte optionale Tools (via gum): ${tools_to_install_list[*]}"
            else
                log_warn "Keine optionalen Tools ausgewählt (via gum)."
            fi
        elif command_exists "fzf"; then
            log_warn "'gum' nicht verfügbar. Fallback zur Tool-Auswahl mit 'fzf'."
            local fzf_selection_str
            fzf_selection_str=$(printf "%s\n" "${available_opts_for_choice[@]}" | \
              fzf --multi --ansi --height=40% --border \
                  --prompt="Wähle optionale Tools (TAB zum Markieren, ENTER): " \
                  --preview="echo {}" --preview-window=up:3:wrap)
            if [[ -n "$fzf_selection_str" ]]; then
                while IFS= read -r selected_line; do
                    tools_to_install_list+=("$selected_line")
                done < <(echo "$fzf_selection_str")
                log_success "Ausgewählte optionale Tools (via fzf): ${tools_to_install_list[*]}"
            else
                log_warn "Keine optionalen Tools ausgewählt (via fzf)."
            fi
        else
            log_warn "'gum' und 'fzf' nicht gefunden. Überspringe interaktive Auswahl optionaler Tools. Installiere alle aus '$tool_file'."
            tools_to_install_list=("${available_opts_for_choice[@]}")
        fi
    else
        log_info "Keine (neuen) optionalen Tools in $tool_file zur Auswahl verfügbar oder alle bereits installiert."
    fi
  else
    log_step "Installiere $tool_type Tools aus $tool_file via $PM_NAME"
    if [[ ! -f "$tool_file" ]]; then log_warn "Tool-Datei $tool_file nicht gefunden."; return; fi
    local tool_name_raw_file
    while IFS= read -r tool_name_raw_file || [[ -n "$tool_name_raw_file" ]]; do
        local tool_name_file
        tool_name_file=$(echo "$tool_name_raw_file" | xargs)
        [[ "$tool_name_file" =~ ^#.*$ || -z "$tool_name_file" ]] && continue
        tools_to_install_list+=("$tool_name_file")
    done < "$tool_file"
  fi


  if [[ "$DRY_RUN" == false && ${#tools_to_install_list[@]} -gt 0 ]]; then
      mkdir -p "$(dirname "$MANIFEST_FILE")"
      touch "$MANIFEST_FILE"
  fi

  for tool_name_install in "${tools_to_install_list[@]}"; do
    local install_status_output
    local exit_code
    install_status_output=$("$pkg_install" "$tool_name_install")
    exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        if [[ "$DRY_RUN" == false && "$install_status_output" == "newly_installed" ]]; then
            if ! grep -Fxq "$tool_name_install" "$MANIFEST_FILE" 2>/dev/null; then
                echo "$tool_name_install" >> "$MANIFEST_FILE"
            fi
        fi
    else
        log_warn "Installation von $tool_name_install ($tool_type) nicht erfolgreich abgeschlossen (Status: $install_status_output)."
    fi
  done
}

update_package_manager_packages

ESSENTIALS_TOOLS_FILE="${DOTFILES_ROOT_DIR}/config/brew_essentials.txt"
install_tools_from_file "$ESSENTIALS_TOOLS_FILE" "essentielle"

export SELECTED_OPTIONAL_TOOLS_LIST=""

if [[ "$INSTALL_MODE" == "full_interactive" ]]; then
    OPTIONAL_TOOLS_FILE="${DOTFILES_ROOT_DIR}/config/brew_optionals.txt"
    install_tools_from_file "$OPTIONAL_TOOLS_FILE" "optionale_interaktiv"
elif [[ "$INSTALL_MODE" == "full" ]]; then
    OPTIONAL_TOOLS_FILE="${DOTFILES_ROOT_DIR}/config/brew_optionals.txt"
    log_info "Installiere alle optionalen Tools (Modus: full)..."
    install_tools_from_file "$OPTIONAL_TOOLS_FILE" "optionale"
fi

temp_selected_opts_final=()
all_configured_tools_files=("${DOTFILES_ROOT_DIR}/config/brew_essentials.txt" "${DOTFILES_ROOT_DIR}/config/brew_optionals.txt")
for tool_list_file in "${all_configured_tools_files[@]}"; do
    if [[ -f "$tool_list_file" ]]; then
        tool_name_raw_final=""
        while IFS= read -r tool_name_raw_final || [[ -n "$tool_name_raw_final" ]]; do
            tool_name_final=$(echo "$tool_name_raw_final" | xargs)
            [[ "$tool_name_final" =~ ^#.*$ || -z "$tool_name_final" ]] && continue
            if "$pkg_is_installed" "$tool_name_final"; then
                temp_selected_opts_final+=("$tool_name_final")
            fi
        done < "$tool_list_file"
    fi
done

# shellcheck disable=SC2207
unique_final_selected_opts=($(echo "${temp_selected_opts_final[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
SELECTED_OPTIONAL_TOOLS_LIST=$(IFS=" "; echo "${unique_final_selected_opts[*]}")


if [[ "$DRY_RUN" == false && -f "$MANIFEST_FILE" ]]; then
    sort -u "$MANIFEST_FILE" -o "$MANIFEST_FILE"
    log_info "Manifest der durch diesen Installer neu installierten Tools aktualisiert: $MANIFEST_FILE"
fi

log_success "Tool-Installation abgeschlossen."
