#!/usr/bin/env bash
set -eo pipefail

export DRY_RUN=false
export UNINSTALL_MODE=true
export AUTO_CONFIRM=false
export ONLY_CLEANUP_MODE=false

declare -a REMOVED_TOOLS_LIST=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) export DRY_RUN=true; shift ;;
    -y|--yes) export AUTO_CONFIRM=true; shift ;;
    --only-cleanup) export ONLY_CLEANUP_MODE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --dry-run          Zeigt nur an, was getan würde."
      echo "  -y, --yes          Automatische Zustimmung für alle Abfragen."
      echo "  --only-cleanup     Entfernt nur Konfigurationen, nicht die installierten Tools."
      exit 0 ;;
    *) echo "Unbekannte Option für uninstall.sh: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

log_step "Starte Deinstallation des Dotfiles Setups (Dry Run: $DRY_RUN, Auto-Confirm: $AUTO_CONFIRM, Only-Cleanup: $ONLY_CLEANUP_MODE)"

confirm_uninstall=false
uninstall_prompt_message="BIST DU SICHER, dass du "
if [[ "$ONLY_CLEANUP_MODE" == true ]]; then
    uninstall_prompt_message+="alle von diesem Installer erstellten Konfigurationen entfernen möchtest (Tools bleiben installiert)? (ja/NEIN): "
else
    uninstall_prompt_message+="alle von diesem Installer verwalteten Komponenten und Konfigurationen entfernen möchtest? (ja/NEIN): "
fi

if [[ "$AUTO_CONFIRM" == true ]]; then
    confirm_uninstall=true
    log_info "Automatische Zustimmung zur Deinstallation durch --yes Flag."
else
    read -p "$uninstall_prompt_message" confirm_input
    if [[ "$confirm_input" =~ ^(ja|JA|Ja)$ ]]; then
        confirm_uninstall=true
    fi
fi

if ! $confirm_uninstall; then
    log_warn "Deinstallation abgebrochen."
    exit 0
fi

PKG_CMD="brew"
PKG_LIST_CMD="brew list"
PKG_UNINSTALL_CMD="brew uninstall"
PKG_AUTOREMOVE_CMD="brew autoremove --force"
PKG_CASK_LIST_CMD="brew list --cask"
PKG_CASK_UNINSTALL_CMD="brew uninstall --cask"

log_info "🗑️  Entferne Oh My Zsh..."
if [[ -d "$OMZ_DIR" ]]; then
    if execute_or_dryrun "Oh My Zsh entfernen" rm -rf "$OMZ_DIR"; then
        [[ "${DRY_RUN:-false}" == false ]] && log_success "🗑️ Oh My Zsh entfernt."
    fi
else
    log_info "Oh My Zsh Verzeichnis ($OMZ_DIR) nicht gefunden."
fi

log_info "🗑️  Entferne FZF Preview Skript..."
fzf_preview_script_path="$HOME/.config/fzf/fzf-preview.sh"
fzf_config_dir="$HOME/.config/fzf"

if [[ -f "$fzf_preview_script_path" ]]; then
    if execute_or_dryrun "FZF Preview Skript entfernen" rm -f "$fzf_preview_script_path"; then
        [[ "${DRY_RUN:-false}" == false ]] && log_success "🗑️ FZF Preview Skript entfernt."
        if [[ -d "$fzf_config_dir" ]] && [[ -z "$(ls -A "$fzf_config_dir" 2>/dev/null)" ]]; then
            if execute_or_dryrun "Leeres FZF Konfig-Verzeichnis entfernen" rmdir "$fzf_config_dir"; then
                 [[ "${DRY_RUN:-false}" == false ]] && log_success "🗑️ Leeres Verzeichnis $fzf_config_dir entfernt."
            fi
        fi
    fi
else
    log_info "FZF Preview Skript ($fzf_preview_script_path) nicht gefunden."
fi

log_info "🗑️  Entferne FZF Source-Zeile aus $ZSHRC_DEST..."
if [[ "$DRY_RUN" == false ]]; then
    if [[ -f "$ZSHRC_DEST" ]]; then
        local sed_inplace_opt='-i'
        [[ "$(uname)" == "Darwin" ]] && sed_inplace_opt='-i ""'
        eval "sed $sed_inplace_opt '/\[ -f ~\/\.fzf\.zsh \] && source ~\/\.fzf\.zsh/d' \"$ZSHRC_DEST\""
        log_success "🗑️ FZF Source Zeile aus $ZSHRC_DEST entfernt (falls vorhanden)."
    else
        log_info "$ZSHRC_DEST nicht gefunden, nichts zu entfernen."
    fi
else
    log_info "[DRY RUN] Würde FZF Source Zeile aus $ZSHRC_DEST entfernen."
fi

log_info "🗑️  Entferne Konfigurationsblöcke aus $ZSHRC_DEST..."
manage_config_block "$ZSHRC_DOTFILES_HOMEBREW_SHELLENV_START_MARKER" "$ZSHRC_DOTFILES_HOMEBREW_SHELLENV_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
manage_config_block "$ZSHRC_DOTFILES_OMZ_PLUGINS_START_MARKER" "$ZSHRC_DOTFILES_OMZ_PLUGINS_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
manage_config_block "$ZSHRC_DOTFILES_NEOFETCH_START_MARKER" "$ZSHRC_DOTFILES_NEOFETCH_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
manage_config_block "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_START_MARKER" "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"

log_info "Stelle ursprüngliche $ZSHRC_DEST wieder her, falls Backup existiert..."
if [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
    if execute_or_dryrun "$ZSHRC_DEST aus Backup wiederherstellen" cp "$ZSHRC_BACKUP_FILE" "$ZSHRC_DEST"; then
        [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ $ZSHRC_DEST aus Backup $ZSHRC_BACKUP_FILE wiederhergestellt."
    fi
else
    log_warn "Keine Backup-Datei $ZSHRC_BACKUP_FILE gefunden."
fi

if [[ "$ONLY_CLEANUP_MODE" == true ]]; then
    log_info "--only-cleanup Modus: Überspringe Deinstallation von Tools, Casks und brew autoremove."
else
    log_info "🗑️  Versuche, installierte Tools zu entfernen (basierend auf Konfigurationsdateien)..."
    TOOLS_TO_UNINSTALL=()
    if [[ -f "$SCRIPT_DIR/config/brew_essentials.txt" ]]; then
        while IFS= read -r tool || [[ -n "$tool" ]]; do
            tool=$(echo "$tool" | xargs); [[ "$tool" =~ ^#.*$ || -z "$tool" ]] && continue
            TOOLS_TO_UNINSTALL+=("$tool")
        done < "$SCRIPT_DIR/config/brew_essentials.txt"
    fi
    if [[ -f "$SCRIPT_DIR/config/brew_optionals.txt" ]]; then
        while IFS= read -r tool || [[ -n "$tool" ]]; do
            tool=$(echo "$tool" | xargs); [[ "$tool" =~ ^#.*$ || -z "$tool" ]] && continue
            TOOLS_TO_UNINSTALL+=("$tool")
        done < "$SCRIPT_DIR/config/brew_optionals.txt"
    fi

    # shellcheck disable=SC2207
    unique_tools_to_uninstall=($(echo "${TOOLS_TO_UNINSTALL[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for tool_name in "${unique_tools_to_uninstall[@]}"; do
        is_cask=false
        case "$tool_name" in
            iterm2|font-hack-nerd-font) is_cask=true ;;
        esac

        if $is_cask; then
            if [[ "${DRY_RUN:-false}" == true ]]; then
                log_info "[DRY RUN] Würde Deinstallation von Cask '$tool_name' prüfen."
            elif $PKG_CASK_LIST_CMD "$tool_name" &>/dev/null; then
                # shellcheck disable=SC2086
                if execute_or_dryrun "Cask $tool_name entfernen" $PKG_CASK_UNINSTALL_CMD --force "$tool_name"; then
                    log_success "🗑️ Cask $tool_name entfernt."
                    [[ "${DRY_RUN:-false}" == false ]] && REMOVED_TOOLS_LIST+=("$tool_name (cask)")
                fi
            else
                log_info "Cask $tool_name ist nicht installiert."
            fi
        else
            if [[ "${DRY_RUN:-false}" == true ]]; then
                log_info "[DRY RUN] Würde Deinstallation von Tool '$tool_name' prüfen."
            elif $PKG_LIST_CMD "$tool_name" &>/dev/null; then
                # shellcheck disable=SC2086
                if execute_or_dryrun "Tool $tool_name entfernen" $PKG_UNINSTALL_CMD --force "$tool_name"; then
                    log_success "🗑️ Tool $tool_name entfernt."
                    [[ "${DRY_RUN:-false}" == false ]] && REMOVED_TOOLS_LIST+=("$tool_name")
                fi
            else
                log_info "Tool $tool_name ist nicht installiert."
            fi
        fi
    done

    if [[ -n "$PKG_AUTOREMOVE_CMD" ]]; then
        confirm_autoremove=false
        if [[ "$AUTO_CONFIRM" == true ]]; then
            confirm_autoremove=true
            log_info "Automatische Zustimmung zu '$PKG_AUTOREMOVE_CMD' durch --yes Flag."
        else
            read -p "Möchtest du '$PKG_AUTOREMOVE_CMD' ausführen, um verwaiste Abhängigkeiten zu entfernen? (y/N): " confirm_autoremove_input
            if [[ "$confirm_autoremove_input" =~ ^[Yy]$ ]]; then
                confirm_autoremove=true
            fi
        fi
        
        if $confirm_autoremove; then
            log_info "Führe '$PKG_AUTOREMOVE_CMD' aus..."
            # shellcheck disable=SC2086
            if execute_or_dryrun "Verwaiste Abhängigkeiten entfernen" $PKG_AUTOREMOVE_CMD; then
                [[ "${DRY_RUN:-false}" == false ]] && log_success "✅ Verwaiste Abhängigkeiten entfernt.";
            fi
        fi
    fi
fi

if [[ "${DRY_RUN:-false}" == false && "$ONLY_CLEANUP_MODE" == false && ${#REMOVED_TOOLS_LIST[@]} -gt 0 ]]; then
    log_info "\nFolgende Tools/Casks wurden erfolgreich entfernt:"
    for removed_tool in "${REMOVED_TOOLS_LIST[@]}"; do
        echo "  - $removed_tool"
    done
elif [[ "${DRY_RUN:-false}" == false && "$ONLY_CLEANUP_MODE" == false ]]; then
    log_info "Keine Tools/Casks wurden im Rahmen dieser Deinstallation entfernt."
fi

log_success "✅ Deinstallation abgeschlossen."
log_info "Bitte starte deine Shell neu und überprüfe $ZSHRC_DEST."
if [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
    log_info "Ein Backup deiner ursprünglichen .zshrc liegt weiterhin unter $ZSHRC_BACKUP_FILE."
fi