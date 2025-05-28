#!/usr/bin/env bash

source "$(dirname "$0")/../lib/utils.sh"

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"
INSTALL_MODE="${INSTALL_MODE:-full}"

function setup_powerlevel10k() {
  log_step "Powerlevel10k Theme einrichten"
  local p10k_dir="${OMZ_CUSTOM_DIR}/themes/powerlevel10k"
  local p10k_theme_line='ZSH_THEME="powerlevel10k/powerlevel10k"'

  if [[ -d "$p10k_dir" ]]; then
    log_success "Powerlevel10k ist bereits installiert."
    if [[ "$PERFORM_UPDATES" == true ]]; then
        log_info "Aktualisiere Powerlevel10k..."
        if execute_or_dryrun "Powerlevel10k Update" git -C "$p10k_dir" pull; then
             [[ "$DRY_RUN" == false ]] && log_success "✅ Powerlevel10k aktualisiert."
        else
             [[ "$DRY_RUN" == false ]] && log_warn "Powerlevel10k Update fehlgeschlagen/keine Änderungen."
        fi
    fi
  else
    log_info "Installiere Powerlevel10k..."
    if ! execute_or_dryrun "Powerlevel10k Klonen" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"; then
        [[ "$DRY_RUN" == false ]] && return 1 
    fi
    [[ "$DRY_RUN" == false ]] && log_success "✅ Powerlevel10k installiert."
  fi

  if [[ "$DRY_RUN" == false ]]; then
    if grep -q "^ZSH_THEME=" "$ZSHRC_DEST"; then
        if ! grep -qF "$p10k_theme_line" "$ZSHRC_DEST"; then 
            log_info "Aktualisiere ZSH_THEME auf powerlevel10k/powerlevel10k..."
            local sed_inplace_opt='-i'
            [[ "$(uname)" == "Darwin" ]] && sed_inplace_opt='-i ""'
            eval "sed $sed_inplace_opt 's|^ZSH_THEME=.*|$p10k_theme_line|' \"$ZSHRC_DEST\""
        fi
    else
        append_if_missing "$ZSHRC_DEST" "$p10k_theme_line"
    fi
  else
    log_info "[DRY RUN] Würde ZSH_THEME in $ZSHRC_DEST auf powerlevel10k/powerlevel10k prüfen/setzen."
  fi
  
  
  append_if_missing "$ZSHRC_DEST" "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh"
}

function configure_omz_plugins() {
  log_step "Oh My Zsh Plugins konfigurieren"
  local base_plugins=("git" "fzf") 
  local selected_plugins_for_omz=() 
  selected_plugins_for_omz=("${base_plugins[@]}")
  
  if [[ -d "${OMZ_CUSTOM_DIR}/plugins/fzf-tab" ]]; then
    selected_plugins_for_omz+=("fzf-tab")
  fi

  if [[ "$INSTALL_MODE" == "full" ]]; then
    log_info "Interaktive Auswahl für zusätzliche Oh My Zsh Plugins (Modus: full)..."
    local omz_plugins_file
    omz_plugins_file="$(dirname "$0")/../config/omz_plugins.txt" 
    if [[ -f "$omz_plugins_file" ]] && command_exists "fzf"; then
      local available_plugins=() 
      while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | awk '{print $1}')
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        is_base=false
        for p_base in "${base_plugins[@]}"; do [[ "$p_base" == "$line" ]] && is_base=true && break; done
        [[ "$line" == "fzf-tab" ]] && is_base=true 
        ! $is_base && available_plugins+=("$line")
      done < "$omz_plugins_file"
      
      if [[ ${#available_plugins[@]} -gt 0 ]]; then
        
        
        local user_selected_plugins_str
        user_selected_plugins_str=$(printf "%s\n" "${available_plugins[@]}" | \
          fzf --multi --ansi --height=40% --border \
              --prompt="Wähle zusätzliche OMZ Plugins (TAB zum Markieren, ENTER): " \
              --preview="echo {}" --preview-window=up:3:wrap)
        
        if [[ -n "$user_selected_plugins_str" ]]; then
            local user_selected_plugins=()
            readarray -t user_selected_plugins < <(echo "$user_selected_plugins_str")
            selected_plugins_for_omz+=("${user_selected_plugins[@]}")
            log_success "Ausgewählte zusätzliche Plugins: ${user_selected_plugins[*]}"
        else
            log_warn "Keine zusätzlichen Plugins ausgewählt."
        fi
      else
        log_info "Keine weiteren Plugins in $omz_plugins_file zur Auswahl verfügbar."
      fi
    elif ! command_exists "fzf"; then
        log_warn "fzf nicht gefunden. Überspringe interaktive Plugin-Auswahl."
    else
        log_warn "Plugin-Definitionsdatei $omz_plugins_file nicht gefunden."
    fi
  else
    log_info "Minimal-Installation: Nur Basis-Plugins werden verwendet."
  fi
  
  
  local unique_plugins_list=($(echo "${selected_plugins_for_omz[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  local plugin_line_content="plugins=(${unique_plugins_list[*]})"
  
  manage_config_block "$ZSHRC_DOTFILES_OMZ_PLUGINS_START_MARKER" "$ZSHRC_DOTFILES_OMZ_PLUGINS_END_MARKER" "$plugin_line_content" "$ZSHRC_DEST"
}

function setup_fzf() {
  log_step "FZF einrichten"
  
  log_info "FZF Basis-Setup (Keybindings, Completion)..."
  local fzf_source_line="[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh"
  append_if_missing "$ZSHRC_DEST" "$fzf_source_line"

  if [[ "$DRY_RUN" == false && ! -f "$HOME/.fzf.zsh" ]]; then
    log_info "Führe FZF Post-Installation aus, um ~/.fzf.zsh zu generieren..."
    if command_exists brew && brew list fzf &>/dev/null; then
       "$(brew --prefix fzf)/install" --all
    else
       log_warn "FZF scheint nicht über Homebrew installiert zu sein."
    fi
  elif [[ "$DRY_RUN" == true && ! -f "$HOME/.fzf.zsh" ]]; then
    log_info "[DRY RUN] Würde FZF Post-Installation ausführen."
  fi

  log_info "fzf-tab Plugin Setup..."
  local fzf_tab_dir="${OMZ_CUSTOM_DIR}/plugins/fzf-tab"
  if [[ ! -d "$fzf_tab_dir" ]]; then
    log_info "Klone fzf-tab Plugin..."
    if ! execute_or_dryrun "fzf-tab Plugin klonen" git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$fzf_tab_dir"; then
        [[ "$DRY_RUN" == false ]] && log_error "Fehler beim Klonen von fzf-tab." 
    else
        [[ "$DRY_RUN" == false ]] && log_success "✅ fzf-tab Plugin geklont."
    fi
  else
    log_success "fzf-tab Plugin ist bereits vorhanden."
    if [[ "$PERFORM_UPDATES" == true ]]; then
        log_info "Aktualisiere fzf-tab..."
        if execute_or_dryrun "fzf-tab Update" git -C "$fzf_tab_dir" pull; then
             [[ "$DRY_RUN" == false ]] && log_success "✅ fzf-tab aktualisiert."
        else
             [[ "$DRY_RUN" == false ]] && log_warn "fzf-tab Update fehlgeschlagen/keine Änderungen."
        fi
    fi
  fi

  if [[ "$INSTALL_MODE" == "full" ]]; then
    log_info "Erweiterte FZF-Konfiguration (Preview, Default Opts)..."
    local fzf_preview_script_path="$HOME/.config/fzf/fzf-preview.sh"
    
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$(dirname "$fzf_preview_script_path")"
        cat <<'EOF_FZF_PREVIEW' > "$fzf_preview_script_path"
#!/usr/bin/env bash
# FZF Preview Script (generated by dotfiles installer)
# shellcheck disable=SC2086,SC2154
export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8
path="${1}"; [[ -z "${path}" || ! -e "${path}" ]] && exit 0
mime_type=$(file --dereference --brief --mime-type "${path}" 2>/dev/null || echo "text/plain")
case "$mime_type" in
    inode/directory) if command_exists exa; then exa --color=always --icons -l --git "${path}"; elif command_exists lsd; then lsd --color=always --icon=always -l "${path}"; else ls -lhp --color=auto "${path}"; fi ;;
    inode/x-empty) echo "[info] Datei ist leer." ;;
    application/pdf) if command_exists pdftotext; then pdftotext "${path}" - | head -n 50; else echo "[info] 'pdftotext' nicht gefunden."; fi ;;
    image/*) if command_exists kitty && [[ "$TERM" == "xterm-kitty" ]]; then kitty +kitten icat --silent --stdin no --transfer-mode file --place "400x400@0x0" "${path}" < /dev/null > /dev/tty; elif command_exists chafa; then chafa -s "80x40" "${path}"; else echo "[info] Bildvorschau nicht verfügbar."; fi ;;
    text/markdown|application/x-shellscript|text/*) if [[ "${path}" =~ \.(md|markdown)$ ]] && command_exists glow; then glow -s dark -w 80 "${path}"; elif command_exists bat; then bat --style=numbers --color=always --line-range :200 "${path}"; else head -n 200 "${path}"; fi ;;
    *) if command_exists bat; then bat --style=numbers --color=always --line-range :200 "${path}"; else head -n 200 "${path}"; fi ;;
esac
EOF_FZF_PREVIEW
        chmod +x "$fzf_preview_script_path"
        log_success "✅ FZF Preview Skript gespeichert in $fzf_preview_script_path"
    else
        log_info "[DRY RUN] Würde FZF Preview Skript nach $fzf_preview_script_path schreiben."
    fi

    local fzf_opts_content
    read -r -d '' fzf_opts_content <<EOF
# FZF Default Command und Options (added by dotfiles installer)
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND=\$FZF_DEFAULT_COMMAND
export FZF_DEFAULT_OPTS="\\
--height 50% --layout=reverse --border=rounded \\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \\
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \\
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \\
--preview='${fzf_preview_script_path} {}' \\
--preview-window=right:60%:wrap"
EOF
    manage_config_block "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_START_MARKER" "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_END_MARKER" "$fzf_opts_content" "$ZSHRC_DEST"
  fi
}


function configure_aliases_and_greetings() {
  if [[ "$INSTALL_MODE" == "minimal" ]]; then
    log_info "Minimal-Installation: Überspringe Aliase und Neofetch-Begrüßung."
    manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
    manage_config_block "$ZSHRC_DOTFILES_NEOFETCH_START_MARKER" "$ZSHRC_DOTFILES_NEOFETCH_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
    return
  fi

  log_step "Aliase und Neofetch-Begrüßung konfigurieren"
  
  local aliases_content=""
  local optional_tools_file
  optional_tools_file="$(dirname "$0")/../config/brew_optionals.txt" 
  if [[ -f "$optional_tools_file" ]]; then
    while IFS= read -r tool_name || [[ -n "$tool_name" ]]; do
      tool_name=$(echo "$tool_name" | xargs)
      [[ "$tool_name" =~ ^#.*$ || -z "$tool_name" ]] && continue
      
      local tool_exists=false
      if command_exists "$tool_name" || (command_exists brew && brew list "$tool_name" &>/dev/null); then
        tool_exists=true
      fi
      if ! $tool_exists; then continue; fi

      case "$tool_name" in
        bat) aliases_content+="alias cat='bat --theme=Catppuccin-mocha'\n" ;;
        lsd)
          aliases_content+="alias ls='lsd --group-dirs first --icon always'\n"
          aliases_content+="alias ll='lsd -lAh --group-dirs first --icon always'\n"
          aliases_content+="alias llt='lsd -lAh --group-dirs first --icon always --tree --depth 2'\n"
          ;;
        fd) aliases_content+="alias find='fd'\n" ;;
        dust) aliases_content+="alias du='dust'\n" ;;
        ripgrep) aliases_content+="alias grep='rg --color=auto'\n" ;;
        htop) aliases_content+="alias top='htop'\n" ;;
        lazydocker) aliases_content+="alias lzd='lazydocker'\n" ;;
        grc)
          aliases_content+="alias ping='grc ping'\n"
          aliases_content+="alias traceroute='grc traceroute'\n"
          ;;
      esac
    done < "$optional_tools_file"
  fi

  if [[ -n "$aliases_content" ]]; then
    aliases_content=$(echo -e "${aliases_content%'\n'}")
    manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "$aliases_content" "$ZSHRC_DEST"
  else
    log_info "Keine Aliase zu konfigurieren."
    manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
  fi

  local neofetch_is_selected_and_installed=false
  if grep -q "neofetch" "$optional_tools_file" && (command_exists "neofetch" || (command_exists brew && brew list "neofetch" &>/dev/null)); then
    neofetch_is_selected_and_installed=true
  fi

  if $neofetch_is_selected_and_installed; then
    local neofetch_config_content
    read -r -d '' neofetch_config_content <<EOF
# Display Neofetch on interactive shell startup (added by dotfiles installer)
if [[ \$- == *i* ]] && command -v neofetch &>/dev/null; then
  neofetch --ascii_distro Tux --color_blocks off \\
    --colors 4 6 1 3 5 7 \\
    --disable term termfont theme icons cursor shell de wm resolution cpu gpu memory
fi
EOF
    manage_config_block "$ZSHRC_DOTFILES_NEOFETCH_START_MARKER" "$ZSHRC_DOTFILES_NEOFETCH_END_MARKER" "$neofetch_config_content" "$ZSHRC_DEST"
  else
    manage_config_block "$ZSHRC_DOTFILES_NEOFETCH_START_MARKER" "$ZSHRC_DOTFILES_NEOFETCH_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
  fi
}


if [[ ! -d "$OMZ_DIR" ]]; then
    log_error "Oh My Zsh ist nicht installiert. Bitte zuerst 'scripts/setup_shell.sh' ausführen."
    exit 1
fi
if ! command_exists "fzf"; then
    log_error "fzf ist nicht installiert. Bitte zuerst 'scripts/install_tools.sh' ausführen."
    exit 1
fi

if [[ "$DRY_RUN" == false && ! -f "$ZSHRC_DEST" ]]; then
    log_info "$ZSHRC_DEST nicht gefunden, erstelle leere Datei."
    touch "$ZSHRC_DEST"
fi

setup_powerlevel10k
setup_fzf
configure_omz_plugins
configure_aliases_and_greetings

log_success "Shell-Konfiguration abgeschlossen."
