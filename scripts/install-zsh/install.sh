#!/usr/bin/env bash
set -eo pipefail
set -u

export DRY_RUN=false
export PERFORM_UPDATES=false
export INSTALL_MODE="full"
export AUTO_CONFIRM=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export DOTFILES_ROOT_DIR="$SCRIPT_DIR" 

# shellcheck source=lib/utils.sh
source "$DOTFILES_ROOT_DIR/lib/utils.sh" 

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
# shellcheck source=scripts/install_tools.sh
source "$DOTFILES_ROOT_DIR/scripts/install_tools.sh"

log_info "Führe Shell-Setup aus..."
# shellcheck source=scripts/setup_shell.sh
source "$DOTFILES_ROOT_DIR/scripts/setup_shell.sh"

log_info "Führe Shell-Konfiguration aus..."
# shellcheck source=scripts/configure_shell.sh
source "$DOTFILES_ROOT_DIR/scripts/configure_shell.sh"

log_info "Führe Paketmanager-spezifische Shell-Konfiguration für $PM_NAME durch (z.B. PATH in .zshrc)..."
if type "$pkg_setup_shell_config" &>/dev/null && [[ -n "$pkg_setup_shell_config" ]]; then
    if ! "$pkg_setup_shell_config"; then
        log_error "Paketmanager-spezifische Shell-Konfiguration für $PM_NAME in .zshrc fehlgeschlagen."
    else
        log_info "Paketmanager-spezifische Shell-Konfiguration für $PM_NAME erfolgreich."
    fi
else
    log_info "Keine spezifische Shell-Konfigurationsfunktion ($pkg_setup_shell_config) für $PM_NAME definiert oder Treiber hat sie nicht zugewiesen."
fi

log_step "Installation abgeschlossen!"
if [[ "$DRY_RUN" == true ]]; then
    log_success "🌵 Dry Run beendet. Es wurden keine Änderungen vorgenommen."
else
    echo ""
    log_success "✨✨✨ Setup erfolgreich abgeschlossen! ✨✨✨"
    echo ""
    echo -e "${COLOR_YELLOW}╭───────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│ ${COLOR_GREEN}Wichtige nächste Schritte:${COLOR_YELLOW}                                           │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  ${COLOR_CYAN}1. Terminal-Schriftart einstellen:${COLOR_RESET} Damit Symbole korrekt angezeigt │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     werden (z.B. für Powerlevel10k), wähle bitte eine   │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     'Nerd Font' (z.B. 'MesloLGS NF', die gerade        │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     installiert wurde) in den Einstellungen deines      │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     Terminal-Programms aus.                           │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                                                                   │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  ${COLOR_CYAN}2. Shell neu starten:${COLOR_RESET} Führe 'exec zsh -l' aus oder öffne ein         │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     neues Terminalfenster/-Tab.                     │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                                                                   │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  ${COLOR_CYAN}3. Powerlevel10k:${COLOR_RESET} Falls noch nicht geschehen oder gewünscht,       │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     führe 'p10k configure' aus, um dein Prompt      │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     individuell anzupassen.                         │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                                                                   │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  ${COLOR_CYAN}4. Deine .zshrc:${COLOR_RESET} Wurde in '$ZSHRC_DEST' konfiguriert. │${COLOR_RESET}"
    if [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
    echo -e "${COLOR_YELLOW}│                                                                   │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  ${COLOR_CYAN}5. .zshrc Backup:${COLOR_RESET} Ein Backup deiner vorherigen .zshrc (falls    │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     vorhanden) liegt unter:                         │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│                     '$ZSHRC_BACKUP_FILE'                     │${COLOR_RESET}"
    fi
    echo -e "${COLOR_YELLOW}╰───────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo ""

    if gum_confirm_wrapper "Möchtest du die Shell jetzt neu starten (exec zsh -l)?" "Y"; then
      log_info "Starte Zsh neu..."
      exec zsh -l
    else
      log_info "Du kannst die Änderungen mit 'exec zsh -l' oder durch Öffnen eines neuen Terminals übernehmen."
    fi
fi
date