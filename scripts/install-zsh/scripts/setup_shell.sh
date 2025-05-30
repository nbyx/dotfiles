#!/usr/bin/env bash
set -eo pipefail
set -u

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"

function set_zsh_as_default_shell() {
  log_step "Zsh als Standardshell einrichten"
  local zsh_path
  if ! zsh_path=$(command -v zsh); then
    log_error "Zsh nicht im PATH gefunden. Stelle sicher, dass es installiert ist."
    exit 1
  fi

  if [[ "$SHELL" == "$zsh_path" ]]; then
    log_success "Zsh ist bereits die Standardshell."
    return
  fi

  log_info "Setze Zsh ($zsh_path) als Standardshell..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Würde Zsh als Standardshell setzen und ggf. zu /etc/shells hinzufügen."
    return
  fi

  if ! grep -Fxq "$zsh_path" /etc/shells; then
    log_info "Füge '$zsh_path' zu /etc/shells hinzu (benötigt sudo)..."
    if echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
      log_success "📝 '$zsh_path' zu /etc/shells hinzugefügt."
    else
      log_error "Fehler beim Hinzufügen von '$zsh_path' zu /etc/shells."
    fi
  fi

  if chsh -s "$zsh_path"; then
    log_success "✅ Zsh als Standardshell gesetzt. Änderungen werden nach dem nächsten Login wirksam."
  else
    log_error "Fehler beim Setzen von Zsh als Standardshell. Bitte manuell ausführen: chsh -s $zsh_path"
  fi
}

function setup_oh_my_zsh() {
  log_step "Oh My Zsh einrichten"
  if [[ -d "$OMZ_DIR" ]]; then
    log_success "Oh My Zsh ist bereits installiert in $OMZ_DIR."
    if [[ "$PERFORM_UPDATES" == true ]]; then
        log_info "Aktualisiere Oh My Zsh (wegen --update)..."
        # shellcheck disable=SC2034
        if execute_or_dryrun "Oh My Zsh Update" ZSH="$OMZ_DIR" sh -c '"$ZSH"/tools/upgrade.sh'; then
            : 
        else
            [[ "$DRY_RUN" == false ]] && log_warn "Oh My Zsh Update nicht vollständig erfolgreich oder keine Änderungen."
        fi
    fi
    if [[ "$DRY_RUN" == false ]]; then
        if ! grep -q "export ZSH=" "$ZSHRC_DEST" || ! grep -q "ZSH/oh-my-zsh.sh" "$ZSHRC_DEST"; then
            log_info "OMZ ist installiert, aber Kernzeilen fehlen in .zshrc. Versuche, sie hinzuzufügen."
            local temp_zshrc_omz_core
            temp_zshrc_omz_core=$(create_temp_file "OMZ core zshrc")
            echo "export ZSH=\"$OMZ_DIR\"" >> "$temp_zshrc_omz_core"
            echo "source \"\$ZSH/oh-my-zsh.sh\"" >> "$temp_zshrc_omz_core"
            
            if [[ -f "$ZSHRC_DEST" ]]; then
                cat "$ZSHRC_DEST" >> "$temp_zshrc_omz_core"
            fi
            cp "$temp_zshrc_omz_core" "$ZSHRC_DEST"
            safe_remove_temp_file "$temp_zshrc_omz_core" "OMZ core zshrc"
            log_success "OMZ Kernzeilen zu $ZSHRC_DEST hinzugefügt/aktualisiert."
        fi
    fi
    return
  fi

  log_info "✨ Installiere Oh My Zsh..."
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Würde Oh My Zsh Installationsskript ausführen."
    return
  fi

  local omz_install_log_file
  omz_install_log_file=$(create_temp_file "Oh My Zsh log file")


  local omz_exit_code
  local omz_install_command_string
  [[ $? -ne 0 ]] && return 1
  log_info "Lasse Oh My Zsh die .zshrc verwalten/erstellen."
  omz_install_command_string='export RUNZSH="no" CHSH="no"; sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  
  (
    eval "$omz_install_command_string" > "$omz_install_log_file" 2>&1
  )
  omz_exit_code=$?

  if [[ "$omz_exit_code" -eq 0 ]]; then
    log_success "✅ Oh My Zsh Installationsprozess abgeschlossen (Exit Code: $omz_exit_code)."
    if [[ ! -d "$OMZ_DIR" ]]; then
        log_error "OMZ-Verzeichnis $OMZ_DIR nach der Installation nicht gefunden!"
        log_info "OMZ Installations-Log ($omz_install_log_file):"; cat "$omz_install_log_file"
        exit 1
    fi
    if [[ "$DRY_RUN" == false ]] && (! grep -q "export ZSH=" "$ZSHRC_DEST" || ! grep -q "ZSH/oh-my-zsh.sh" "$ZSHRC_DEST"); then
        log_error "OMZ hat die .zshrc nicht korrekt initialisiert. Kernzeilen fehlen."
        log_info "OMZ Installations-Log ($omz_install_log_file):"; cat "$omz_install_log_file"
        log_info "Inhalt der .zshrc:"; cat "$ZSHRC_DEST"
        exit 1
    fi
  else
    log_error "Fehler bei der Installation von Oh My Zsh (Exit Code: $omz_exit_code)."
    log_info "OMZ Installations-Log ($omz_install_log_file):"; cat "$omz_install_log_file"
    exit 1
  fi
  safe_remove_temp_file "$omz_install_log_file" "Oh My Zsh log file"
}

if ! command_exists "zsh"; then
    log_error "Zsh ist nicht installiert. Bitte zuerst 'scripts/install_tools.sh' ausführen oder Zsh manuell installieren."
    exit 1
fi

setup_oh_my_zsh
set_zsh_as_default_shell

log_success "Shell Setup abgeschlossen."
