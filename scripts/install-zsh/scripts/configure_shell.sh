#!/usr/bin/env bash
set -eo pipefail
set -u

DRY_RUN="${DRY_RUN:-false}"
PERFORM_UPDATES="${PERFORM_UPDATES:-false}"
INSTALL_MODE="${INSTALL_MODE:-full}" 

function modify_zshrc_for_omz_core() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Würde .zshrc für OMZ Kernkonfiguration anpassen."
        return
    fi

    log_info "Stelle OMZ Kernkonfiguration in $ZSHRC_DEST sicher..."

    local zshrc_content=""
    if [[ -f "$ZSHRC_DEST" ]]; then
        zshrc_content=$(cat "$ZSHRC_DEST")
    else
        touch "$ZSHRC_DEST"
    fi

    local export_zsh_line="export ZSH=\"$OMZ_DIR\""
    local source_omz_line_escaped_dollar='source "$ZSH/oh-my-zsh.sh"' 
    local source_omz_line_no_quotes_escaped_dollar='source $ZSH/oh-my-zsh.sh'


    local temp_cleaned_zshrc
    temp_cleaned_zshrc=$(create_temp_file "OMZ core config cleanup")

    [[ $? -ne 0 ]] && return 1

    echo "$zshrc_content" | grep -Fxv -- "$export_zsh_line" | grep -Fxv -- "$source_omz_line_escaped_dollar" | grep -Fxv -- "$source_omz_line_no_quotes_escaped_dollar" > "$temp_cleaned_zshrc"
    
    local current_content_after_clean
    current_content_after_clean=$(cat "$temp_cleaned_zshrc")
    
    echo -e "${export_zsh_line}\n${current_content_after_clean}" > "$ZSHRC_DEST"
    
    safe_remove_temp_file "$temp_cleaned_zshrc" "OMZ core config cleanup"
    
    log_info "$ZSHRC_DEST für OMZ-Kernzeilen vorbereitet."
}


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
        local temp_zshrc_theme
        temp_zshrc_theme=$(create_temp_file "ZSH theme update")

        [[ $? -ne 0 ]] && return 1

        if grep -q "^ZSH_THEME=" "$ZSHRC_DEST"; then
          awk -v theme_line="$p10k_theme_line" '{if ($0 ~ /^ZSH_THEME=/) print theme_line; else print $0}' "$ZSHRC_DEST" > "$temp_zshrc_theme"
          log_info "ZSH_THEME in $ZSHRC_DEST auf powerlevel10k/powerlevel10k aktualisiert."
        else
            log_warn "ZSH_THEME Zeile nicht in .zshrc gefunden. Füge sie hinzu."
            local export_zsh_pattern="^export ZSH="
            if grep -q "$export_zsh_pattern" "$ZSHRC_DEST"; then 
                awk -v theme_line="$p10k_theme_line" -v pattern="$export_zsh_pattern" '
                {print $0} $0 ~ pattern {print theme_line}
                ' "$ZSHRC_DEST" > "$temp_zshrc_theme"
            else 
                (echo "$p10k_theme_line"; cat "$ZSHRC_DEST") > "$temp_zshrc_theme"
            fi
            log_info "$p10k_theme_line zu $ZSHRC_DEST hinzugefügt."
        fi
        cp "$temp_zshrc_theme" "$ZSHRC_DEST"

        safe_remove_temp_file "$temp_zshrc_theme" "ZSH theme update"
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

  if [[ "$INSTALL_MODE" == "full" || "$INSTALL_MODE" == "full_interactive" ]]; then
    log_info "Interaktive Auswahl für zusätzliche Oh My Zsh Plugins..."
    local omz_plugins_file
    omz_plugins_file="${DOTFILES_ROOT_DIR}/config/omz_plugins.txt"
    if [[ -f "$omz_plugins_file" ]]; then
      local available_plugins_for_choice=()
      local line_content_plugin
      while IFS= read -r line_content_plugin || [[ -n "$line_content_plugin" ]]; do
        local plugin_name_from_file_choice
        plugin_name_from_file_choice=$(echo "$line_content_plugin" | awk '{print $1}')
        [[ "$plugin_name_from_file_choice" =~ ^#.*$ || -z "$plugin_name_from_file_choice" ]] && continue
        local is_base_or_fzf_tab=false
        for p_base_iter_choice in "${base_plugins[@]}"; do [[ "$p_base_iter_choice" == "$plugin_name_from_file_choice" ]] && is_base_or_fzf_tab=true && break; done
        [[ "$plugin_name_from_file_choice" == "fzf-tab" ]] && is_base_or_fzf_tab=true
        ! $is_base_or_fzf_tab && available_plugins_for_choice+=("$plugin_name_from_file_choice")
      done < "$omz_plugins_file"
      
      if [[ ${#available_plugins_for_choice[@]} -gt 0 ]]; then
        local user_selected_plugins_arr_omz=()
        if ! command_exists "gum"; then
            if ! try_install_gum; then
                 log_warn "Installation von 'gum' fehlgeschlagen oder abgelehnt."
            fi
        fi

        if command_exists "gum"; then
            log_info "Verwende 'gum' für die interaktive Plugin-Auswahl..."
            local gum_selected_plugins_str
            gum_selected_plugins_str=$(gum choose --no-limit --header "Wähle zusätzliche OMZ Plugins (SPACE zum Markieren, ENTER):" "${available_plugins_for_choice[@]}")
            if [[ -n "$gum_selected_plugins_str" ]]; then
                while IFS= read -r selected_line; do
                    user_selected_plugins_arr_omz+=("$selected_line")
                done < <(echo "$gum_selected_plugins_str")
            fi
        elif command_exists "fzf"; then
            log_warn "'gum' nicht verfügbar. Fallback zur Plugin-Auswahl mit 'fzf'."
            local fzf_selected_plugins_str
            fzf_selected_plugins_str=$(printf "%s\n" "${available_plugins_for_choice[@]}" | \
              fzf --multi --ansi --height=40% --border \
                  --prompt="Wähle zusätzliche OMZ Plugins (TAB zum Markieren, ENTER): " \
                  --preview="echo {}" --preview-window=up:3:wrap)
            if [[ -n "$fzf_selected_plugins_str" ]]; then
                while IFS= read -r selected_line; do
                    user_selected_plugins_arr_omz+=("$selected_line")
                done < <(echo "$fzf_selected_plugins_str")
            fi
        else
            log_warn "'gum' und 'fzf' nicht gefunden. Überspringe interaktive Plugin-Auswahl."
        fi

        if [[ ${#user_selected_plugins_arr_omz[@]} -gt 0 ]]; then
            selected_plugins_for_omz+=("${user_selected_plugins_arr_omz[@]}")
            log_success "Ausgewählte zusätzliche Plugins: ${user_selected_plugins_arr_omz[*]}"
        else
            log_warn "Keine zusätzlichen Plugins ausgewählt."
        fi
      else
        log_info "Keine weiteren Plugins in $omz_plugins_file zur Auswahl verfügbar."
      fi
    else
        log_warn "Plugin-Definitionsdatei $omz_plugins_file nicht gefunden."
    fi
  else
    log_info "Minimal-Installation: Nur Basis-Plugins werden verwendet."
  fi
  
  # shellcheck disable=SC2207
  local unique_plugins_list=($(echo "${selected_plugins_for_omz[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  
  log_info "Überprüfe und installiere ausgewählte Oh My Zsh Community Plugins..."
  local community_plugin_names=("zsh-autosuggestions" "zsh-syntax-highlighting")
  local community_plugin_repos=(
      "https://github.com/zsh-users/zsh-autosuggestions"
      "https://github.com/zsh-users/zsh-syntax-highlighting"
  )

  for plugin_to_activate_check in "${unique_plugins_list[@]}"; do
      for i in "${!community_plugin_names[@]}"; do 
          local known_community_plugin_name="${community_plugin_names[$i]}"
          
          if [[ "$plugin_to_activate_check" == "$known_community_plugin_name" ]]; then
              local plugin_repo_url="${community_plugin_repos[$i]}"
              local plugin_install_dir="$OMZ_CUSTOM_DIR/plugins/$known_community_plugin_name"

              if [[ ! -d "$plugin_install_dir" ]]; then
                  log_info "Ausgewähltes Community-Plugin '$known_community_plugin_name' nicht gefunden. Klone von $plugin_repo_url..."
                  if ! execute_or_dryrun "Plugin $known_community_plugin_name klonen" git clone --depth=1 "$plugin_repo_url" "$plugin_install_dir"; then
                      [[ "$DRY_RUN" == false ]] && log_warn "Konnte Plugin '$known_community_plugin_name' nicht klonen. Es wird möglicherweise nicht funktionieren."
                  else
                      [[ "$DRY_RUN" == false ]] && log_success "✅ Plugin '$known_community_plugin_name' erfolgreich geklont."
                  fi
              else
                  log_info "Ausgewähltes Community-Plugin '$known_community_plugin_name' bereits vorhanden in $plugin_install_dir."
                  if [[ "$PERFORM_UPDATES" == true && -d "$plugin_install_dir/.git" ]]; then
                      log_info "Aktualisiere Plugin '$known_community_plugin_name'..."
                      if execute_or_dryrun "Plugin $known_community_plugin_name Update" git -C "$plugin_install_dir" pull; then :
                      else [[ "$DRY_RUN" == false ]] && log_warn "Update für Plugin '$known_community_plugin_name' fehlgeschlagen."; fi
                  fi
              fi
              break 
          fi
      done
  done

  local plugin_line_content_str 
  plugin_line_content_str=$(IFS=" "; echo "${unique_plugins_list[*]}")
  local plugin_line_content="plugins=($plugin_line_content_str)" 
  plugin_line_content="${plugin_line_content% }" 
  
  if [[ "$DRY_RUN" == false ]]; then
      local temp_zshrc_plugins_update
      temp_zshrc_plugins_update=$(create_temp_file "plugin list update")
      [[ $? -ne 0 ]] && return 1

      if grep -q "^plugins=(" "$ZSHRC_DEST"; then
          log_info "Aktualisiere Plugin-Liste in $ZSHRC_DEST..."
          awk -v plugin_line="$plugin_line_content" '{if ($0 ~ /^plugins=\(.*\)/) print plugin_line; else print $0}' "$ZSHRC_DEST" > "$temp_zshrc_plugins_update"
      else
          log_warn "Zeile 'plugins=(...)' nicht in $ZSHRC_DEST gefunden. Füge sie hinzu."
          local source_omz_sh_line_pattern_grep='source "$ZSH/oh-my-zsh.sh"' 
          if grep -q "$source_omz_sh_line_pattern_grep" "$ZSHRC_DEST"; then 
              awk -v plugin_line="$plugin_line_content" -v pattern_re='source "\$ZSH/oh-my-zsh\.sh"' '
              $0 ~ pattern_re { print plugin_line; print $0; next }
              { print }
              ' "$ZSHRC_DEST" > "$temp_zshrc_plugins_update"
          else 
              (cat "$ZSHRC_DEST"; echo "$plugin_line_content") > "$temp_zshrc_plugins_update"
          fi
      fi
      cp "$temp_zshrc_plugins_update" "$ZSHRC_DEST"
      safe_remove_temp_file "$temp_zshrc_plugins_update" "plugin list update"
  else
      log_info "[DRY RUN] Würde Plugin-Liste in $ZSHRC_DEST prüfen/setzen auf: $plugin_line_content"
  fi
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

  if [[ "$INSTALL_MODE" == "full" || "$INSTALL_MODE" == "full_interactive" ]]; then
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

    local fzf_opts_content_raw
    fzf_opts_content_raw=$(cat <<-EOF_FZF_OPTS
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
	EOF_FZF_OPTS
)
    local fzf_opts_content_for_awk
    fzf_opts_content_for_awk=$(echo "$fzf_opts_content_raw" | sed 's/\\$//')
    manage_config_block "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_START_MARKER" "$ZSHRC_DOTFILES_FZF_ADVANCED_CONFIG_END_MARKER" "$fzf_opts_content_for_awk" "$ZSHRC_DEST"
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
  local tools_for_aliases_str="${SELECTED_OPTIONAL_TOOLS_LIST:-}" 
  local tools_for_aliases_arr=()
  if [[ -n "$tools_for_aliases_str" ]]; then
      # shellcheck disable=SC2206 
      tools_for_aliases_arr=($tools_for_aliases_str) 
  fi
  
  for tool_name_alias in "${tools_for_aliases_arr[@]}"; do
      case "$tool_name_alias" in
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
  done

  if [[ -n "$aliases_content" ]]; then
    aliases_content=$(echo -e "${aliases_content%'\n'}")
    manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "$aliases_content" "$ZSHRC_DEST"
  else
    log_info "Keine Aliase zu konfigurieren."
    manage_config_block "$ZSHRC_DOTFILES_TOOL_ALIASES_START_MARKER" "$ZSHRC_DOTFILES_TOOL_ALIASES_END_MARKER" "__REMOVE_BLOCK__" "$ZSHRC_DEST"
  fi

  local neofetch_is_selected_and_installed=false
  for tool_in_list in "${tools_for_aliases_arr[@]}"; do
      if [[ "$tool_in_list" == "neofetch" ]]; then
          neofetch_is_selected_and_installed=true
          break
      fi
  done

  if $neofetch_is_selected_and_installed; then
    local neofetch_config_content
    neofetch_config_content=$(cat <<-EOF_NEOFETCH
# Display Neofetch on interactive shell startup (added by dotfiles installer)
if [[ \$- == *i* ]] && command -v neofetch &>/dev/null; then
  neofetch --ascii_distro Tux --color_blocks off \\
    --colors 4 6 1 3 5 7 \\
    --disable term termfont theme icons cursor shell de wm resolution cpu gpu memory
fi
EOF_NEOFETCH
)
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
if ! command_exists "gum" && [[ "$INSTALL_MODE" != "minimal" ]]; then 
    log_warn "'gum' ist nicht installiert. Einige interaktive Auswahlen könnten auf Fallbacks zurückgreifen oder nicht verfügbar sein."
fi

if [[ "$DRY_RUN" == false && ! -f "$ZSHRC_DEST" ]]; then
    log_info "$ZSHRC_DEST nicht gefunden, erstelle leere Datei."
    touch "$ZSHRC_DEST"
fi

modify_zshrc_for_omz_core

setup_powerlevel10k
configure_omz_plugins 

if [[ "$DRY_RUN" == false ]]; then
    append_if_missing "$ZSHRC_DEST" "source \"\$ZSH/oh-my-zsh.sh\""
fi

setup_fzf 
configure_aliases_and_greetings

log_success "Shell-Konfiguration abgeschlossen."