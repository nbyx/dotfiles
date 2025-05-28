#!/usr/bin/env bash
set -eo pipefail
set -u

export DRY_RUN=false
export PERFORM_UPDATES=false
export INSTALL_MODE="full"
export AUTO_CONFIRM=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh" 

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) export DRY_RUN=true; shift ;;
    --minimal) export INSTALL_MODE="minimal"; shift ;;
    --full) export INSTALL_MODE="full"; shift ;;
    --update) export PERFORM_UPDATES=true; shift ;;
    -y|--yes) export AUTO_CONFIRM=true; shift ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --dry-run          Zeigt nur an, was getan würde."
      echo "  --minimal          Installiert nur essentielle Komponenten."
      echo "  --full             Installiert alle Features (Standard)."
      echo "  --update           Versucht, OMZ und geklonte Plugins/Themes zu aktualisieren."
      echo "  -y, --yes          Automatische Zustimmung für alle Abfragen."
      exit 0 ;;
    *) echo "Unbekannte Option: $1"; exit 1 ;;
  esac
done


log_step "Starte Dotfiles Installation (Modus: $INSTALL_MODE, Dry Run: $DRY_RUN, Updates: $PERFORM_UPDATES, Auto-Confirm: $AUTO_CONFIRM)"
date

if ! detect_and_load_package_manager_driver; then
    log_error "Konnte keinen passenden Paketmanager-Treiber laden. Breche ab."
    exit 1
fi
log_info "Paketmanager $PM_NAME wird verwendet."


if [[ "$DRY_RUN" == false ]]; then
    if [[ -f "$ZSHRC_DEST" ]] && [[ ! -f "$ZSHRC_BACKUP_FILE" ]]; then
        cp "$ZSHRC_DEST" "$ZSHRC_BACKUP_FILE"
        log_success "💾 Bestehende $ZSHRC_DEST gesichert nach $ZSHRC_BACKUP_FILE."
    elif [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
        log_info "Backup-Datei $ZSHRC_BACKUP_FILE existiert bereits."
    fi
    if [[ ! -f "$ZSHRC_DEST" ]]; then
        log_info "$ZSHRC_DEST nicht gefunden, erstelle leere Datei."
        touch "$ZSHRC_DEST"
    fi
elif [[ "$DRY_RUN" == true && ! -f "$ZSHRC_DEST" ]]; then
    log_info "[DRY RUN] $ZSHRC_DEST existiert nicht. Operationen darauf werden simuliert."
fi

log_info "Führe Tool-Installation aus..."
if ! bash "$SCRIPT_DIR/scripts/install_tools.sh"; then
    log_error "Tool-Installation fehlgeschlagen. Breche ab."
    exit 1
fi

log_info "Führe Shell-Setup aus..."
if ! bash "$SCRIPT_DIR/scripts/setup_shell.sh"; then
    log_error "Shell-Setup fehlgeschlagen. Breche ab."
    exit 1
fi

log_info "Führe Shell-Konfiguration aus..."
if ! bash "$SCRIPT_DIR/scripts/configure_shell.sh"; then
    log_error "Shell-Konfiguration fehlgeschlagen. Breche ab."
    exit 1
fi

log_step "Installation abgeschlossen!"
if [[ "$DRY_RUN" == true ]]; then
    log_success "🌵 Dry Run beendet. Es wurden keine Änderungen vorgenommen."
else
    log_success "✨ Alle ausgewählten Komponenten wurden installiert und konfiguriert."
    echo ""
    log_info "Wichtige Hinweise:"
    log_info "  1. Shell neu starten: Damit alle Änderungen wirksam werden, starte bitte dein Terminal neu oder führe 'exec zsh -l' aus."
    log_info "  2. Powerlevel10k: Falls noch nicht geschehen und gewünscht, führe 'p10k configure' aus, um dein Prompt individuell anzupassen."
    log_info "  3. .zshrc: Deine Konfiguration wurde in '$ZSHRC_DEST' geschrieben."
    if [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
        log_info "     Ein Backup deiner vorherigen .zshrc (falls vorhanden) liegt unter '$ZSHRC_BACKUP_FILE'."
    fi
    echo ""

    confirm_shell_restart=false
    if [[ "$AUTO_CONFIRM" == true ]]; then
        confirm_shell_restart=true
        log_info "Automatische Zustimmung zum Shell-Neustart durch --yes Flag."
    else
        read -p "Möchtest du die Shell jetzt neu starten (exec zsh -l)? (Y/n): " -r restart_choice
        local choice_val_restart="${restart_choice:-Y}"
        if [[ "$choice_val_restart" =~ ^[Yy]$ ]]; then
            confirm_shell_restart=true
        fi
    fi

    if $confirm_shell_restart; then
      log_info "Starte Zsh neu..."
      exec zsh -l
    else
      log_info "Du kannst die Änderungen mit 'exec zsh -l' oder durch Öffnen eines neuen Terminals übernehmen."
    fi
fi
date
