#!/usr/bin/env bash
set -eo pipefail
set -u

export DRY_RUN=false
export UNINSTALL_MODE=true
export AUTO_CONFIRM=false
export ONLY_CLEANUP_MODE=false
export FORCE_REMOVE_ALL_CONFIGURED_TOOLS=false

declare -a REMOVED_TOOLS_LIST=()
MANIFEST_FILE="$HOME/.config/dotfiles_installer/installed_tools_manifest.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) export DRY_RUN=true; shift ;;
    -y|--yes) export AUTO_CONFIRM=true; shift ;;
    --only-cleanup) export ONLY_CLEANUP_MODE=true; shift ;;
    --force-remove-all-configured-tools) export FORCE_REMOVE_ALL_CONFIGURED_TOOLS=true; shift;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --dry-run          Zeigt nur an, was getan würde."
      echo "  -y, --yes          Automatische Zustimmung für alle Abfragen."
      echo "  --only-cleanup     Entfernt nur Konfigurationen, nicht die installierten Tools."
      echo "  --force-remove-all-configured-tools"
      echo "                     Entfernt alle in config/*.txt gelisteten Tools, auch wenn sie nicht"
      echo "                     explizit vom Installer hinzugefügt wurden (VORSICHT!)."
      exit 0 ;;
    *) echo "Unbekannte Option für uninstall.sh: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

log_step "Starte Deinstallation (Dry Run: $DRY_RUN, Auto-Confirm: $AUTO_CONFIRM, Only-Cleanup: $ONLY_CLEANUP_MODE, Force-Remove: $FORCE_REMOVE_ALL_CONFIGURED_TOOLS)"

confirm_uninstall=false
uninstall_prompt_message="BIST DU SICHER, dass du "
if [[ "$ONLY_CLEANUP_MODE" == true ]]; then
    uninstall_prompt_message+="alle von diesem Installer erstellten Konfigurationen entfernen möchtest (Tools bleiben installiert)? (ja/NEIN): "
elif [[ "$FORCE_REMOVE_ALL_CONFIGURED_TOOLS" == true ]]; then
    uninstall_prompt_message+="alle von diesem Installer verwalteten Konfigurationen UND ALLE in config/*.txt gelisteten Tools entfernen möchtest (AUCH WENN SIE NICHT DURCH DIESES SKRIPT INSTALLIERT WURDEN)? (ja/NEIN): "
else
    uninstall_prompt_message+="alle von diesem Installer verwalteten Konfigurationen und die DURCH DIESES SKRIPT INSTALLIERTEN Tools (gemäß Manifest) entfernen möchtest? (ja/NEIN): "
fi

if [[ "$AUTO_CONFIRM" == true ]]; then
    confirm_uninstall=true
    log_info "Automatische Zustimmung zur Deinstallation durch --yes Flag."
else
    read -p "$uninstall_prompt_message" confirm_input
    local confirm_val="${confirm_input:-N}"
    if [[ "$confirm_val" =~ ^(ja|JA|Ja|y|Y)$ ]]; then
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
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i "" '/\[ -f ~\/\.fzf\.zsh \] && source ~\/\.fzf\.zsh/d' "$ZSHRC_DEST"
        else
            sed -i '/\[ -f ~\/\.fzf\.zsh \] && source ~\/\.fzf\.zsh/d' "$ZSHRC_DEST"
        fi
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
    TOOLS_TO_UNINSTALL=()
    if [[ "$FORCE_REMOVE_ALL_CONFIGURED_TOOLS" == true ]]; then
        log_warn "FORCE_REMOVE_ALL_CONFIGURED_TOOLS ist aktiv: Versuche alle Tools aus config/*.txt zu entfernen."
        if [[ -f "$SCRIPT_DIR/config/brew_essentials.txt" ]]; then
            tool_raw_ess=""
            while IFS= read -r tool_raw_ess || [[ -n "$tool_raw_ess" ]]; do
                local tool_ess
                tool_ess=$(echo "$tool_raw_ess" | xargs); [[ "$tool_ess" =~ ^#.*$ || -z "$tool_ess" ]] && continue
                TOOLS_TO_UNINSTALL+=("$tool_ess")
            done < "$SCRIPT_DIR/config/brew_essentials.txt"
        fi
        if [[ -f "$SCRIPT_DIR/config/brew_optionals.txt" ]]; then
            tool_raw_opt=""
            while IFS= read -r tool_raw_opt || [[ -n "$tool_raw_opt" ]]; do
                local tool_opt
                tool_opt=$(echo "$tool_raw_opt" | xargs); [[ "$tool_opt" =~ ^#.*$ || -z "$tool_opt" ]] && continue
                TOOLS_TO_UNINSTALL+=("$tool_opt")
            done < "$SCRIPT_DIR/config/brew_optionals.txt"
        fi
    elif [[ -f "$MANIFEST_FILE" ]]; then
        log_info "🗑️  Entferne Tools gemäß Manifest-Datei: $MANIFEST_FILE"
        tool_name_manifest=""
        while IFS= read -r tool_name_manifest || [[ -n "$tool_name_manifest" ]]; do
            local tool_manifest
            tool_manifest=$(echo "$tool_name_manifest" | xargs)
            [[ -z "$tool_manifest" ]] && continue
            TOOLS_TO_UNINSTALL+=("$tool_manifest")
        done < "$MANIFEST_FILE"
    else
        log_info "Keine Manifest-Datei ($MANIFEST_FILE) gefunden. Es werden keine spezifischen Tools deinstalliert."
    fi

    if [[ ${#TOOLS_TO_UNINSTALL[@]} -gt 0 ]]; then
        # shellcheck disable=SC2207
        unique_tools_to_uninstall=($(echo "${TOOLS_TO_UNINSTALL[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        log_info "Folgende Tools/Casks werden zur Deinstallation geprüft: ${unique_tools_to_uninstall[*]}"

        for tool_name_iter in "${unique_tools_to_uninstall[@]}"; do
            is_cask=false
            case "$tool_name_iter" in
                iterm2|font-hack-nerd-font) is_cask=true ;;
            esac

            if $is_cask; then
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    log_info "[DRY RUN] Würde Deinstallation von Cask '$tool_name_iter' prüfen."
                # shellcheck disable=SC2086
                elif $PKG_CASK_LIST_CMD $tool_name_iter &>/dev/null; then
                    # shellcheck disable=SC2086
                    if execute_or_dryrun "Cask $tool_name_iter entfernen" $PKG_CASK_UNINSTALL_CMD --force "$tool_name_iter"; then
                        log_success "🗑️ Cask $tool_name_iter entfernt."
                        [[ "${DRY_RUN:-false}" == false ]] && REMOVED_TOOLS_LIST+=("$tool_name_iter (cask)")
                    fi
                else
                    log_info "Cask $tool_name_iter ist nicht installiert."
                fi
            else
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    log_info "[DRY RUN] Würde Deinstallation von Tool '$tool_name_iter' prüfen."
                # shellcheck disable=SC2086
                elif $PKG_LIST_CMD $tool_name_iter &>/dev/null; then
                    # shellcheck disable=SC2086
                    if execute_or_dryrun "Tool $tool_name_iter entfernen" $PKG_UNINSTALL_CMD --force "$tool_name_iter"; then
                        log_success "🗑️ Tool $tool_name_iter entfernt."
                        [[ "${DRY_RUN:-false}" == false ]] && REMOVED_TOOLS_LIST+=("$tool_name_iter")
                    fi
                else
                    log_info "Tool $tool_name_iter ist nicht installiert."
                fi
            fi
        done
    else
        log_info "Keine Tools zur Deinstallation markiert."
    fi


    if [[ -n "$PKG_AUTOREMOVE_CMD" ]]; then
        confirm_autoremove=false
        if [[ "$AUTO_CONFIRM" == true ]]; then
            confirm_autoremove=true
            log_info "Automatische Zustimmung zu '$PKG_AUTOREMOVE_CMD' durch --yes Flag."
        else
            read -p "Möchtest du '$PKG_AUTOREMOVE_CMD' ausführen, um verwaiste Abhängigkeiten zu entfernen? (y/N): " confirm_autoremove_input
            local autoremove_choice="${confirm_autoremove_input:-N}"
            if [[ "$autoremove_choice" =~ ^[Yy]$ ]]; then
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
    for removed_tool_iter in "${REMOVED_TOOLS_LIST[@]}"; do
        echo "  - $removed_tool_iter"
    done
elif [[ "${DRY_RUN:-false}" == false && "$ONLY_CLEANUP_MODE" == false ]]; then
    log_info "Keine Tools/Casks wurden im Rahmen dieser Deinstallation entfernt."
fi

if [[ "$DRY_RUN" == false && -f "$MANIFEST_FILE" ]]; then
    if [[ "$FORCE_REMOVE_ALL_CONFIGURED_TOOLS" == true || "$ONLY_CLEANUP_MODE" == true ]]; then
        : 
    elif [[ -f "$MANIFEST_FILE" ]]; then
         : > "$MANIFEST_FILE"
        log_info "Manifest-Datei $MANIFEST_FILE geleert."
    fi
fi

log_success "✅ Deinstallation abgeschlossen."
log_info "Bitte starte deine Shell neu und überprüfe $ZSHRC_DEST."
if [[ -f "$ZSHRC_BACKUP_FILE" ]]; then
    log_info "Ein Backup deiner ursprünglichen .zshrc liegt weiterhin unter $ZSHRC_BACKUP_FILE."
fi
