#!/usr/bin/env bash

source "$(dirname "$0")/../lib/utils.sh"

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
        
        if execute_or_dryrun "Oh My Zsh Update" ZSH=$OMZ_DIR sh -c '$ZSH/tools/upgrade.sh'; then
            [[ "$DRY_RUN" == false ]] && log_success "✅ Oh My Zsh aktualisiert."
        else
            [[ "$DRY_RUN" == false ]] && log_warn "Oh My Zsh Update fehlgeschlagen oder keine Änderungen."
        fi
    fi
    return
  fi

  log_info "✨ Installiere Oh My Zsh..."
  
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Würde Oh My Zsh Installationsskript ausführen."
    return
  fi
  
  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
    log_success "✅ Oh My Zsh installiert."
  else
    log_error "Fehler bei der Installation von Oh My Zsh."
    exit 1
  fi
}


if ! command_exists "zsh"; then
    log_error "Zsh ist nicht installiert. Bitte zuerst 'scripts/install_tools.sh' ausführen oder Zsh manuell installieren."
    exit 1
fi

setup_oh_my_zsh
set_zsh_as_default_shell

log_success "Shell Setup abgeschlossen."
