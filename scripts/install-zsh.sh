#!/bin/bash

### Helper Funktionen ###
function step {
  echo -e "\n➡️ $1"
}

function success {
  echo -e "✅ $1"
}

function error {
  echo -e "❌ $1"
}

### FZF Einrichten ###
function setup_fzf {
  step "Richte FZF ein..."
  if [[ ! -f "$(brew --prefix)/opt/fzf/install" ]]; then
    echo "📦 Installiere FZF..."
    brew install fzf && success "FZF installiert."
  fi
  "$(brew --prefix)/opt/fzf/install" --all && success "FZF ist vollständig eingerichtet."
}

function select_plugins {
  local optional_plugins=(docker 1password aliases brew dotnet zsh-autosuggestions zsh-syntax-highlighting)
  echo "🔧 Wähle die gewünschten Oh My Zsh Plugins aus (mit Tab auswählen, Enter zum Bestätigen):"
  local selected_plugins
  selected_plugins=$(printf "%s\n" "${optional_plugins[@]}" | fzf --multi --select-1 --prompt="Plugins abwählen mit TAB: " --preview="echo {}" --preview-window=up:3:wrap | tr '\n' ' ')

  if [[ -n "$selected_plugins" ]]; then
    IFS=' ' read -r -a selected_plugins_array <<< "$selected_plugins"
    echo "plugins=(fzf fzf-tab ${selected_plugins_array[*]})" >> "$ZSHRC_DEST"
    success "Folgende Plugins wurden konfiguriert: ${selected_plugins_array[*]}"
  else
    echo "⚠️ Keine Plugins ausgewählt."
  fi
}

function select_tools {
  local optional_tools=(bat neofetch glances lsd fd dust ripgrep httpie htop glow poppler lazydocker grc tldr 1password-cli)
  echo "🔧 Wähle optionale Tools aus (mit Tab auswählen, Enter zum Bestätigen):"
  local selected_tools
  selected_tools=$(printf "%s\n" "${optional_tools[@]}" | fzf --multi --select-1 --prompt="Tools abwählen mit TAB: " --preview="echo {}" --preview-window=up:3:wrap | tr '\n' ' ')

  if [[ -n "$selected_tools" ]]; then
    IFS=' ' read -r -a selected_tools_array <<< "$selected_tools"
    TOOLS+=("${selected_tools_array[@]}")
    success "Folgende Tools wurden zusätzlich installiert: ${selected_tools_array[*]}"
  else
    echo "⚠️ Keine optionalen Tools ausgewählt."
  fi
}

### Dynamische Alias-Erstellung ###
function add_aliases {
  echo "# Modern CLI Tool Aliases" >> "$ZSHRC_DEST"
  for tool in "${TOOLS[@]}"; do
    case "$tool" in
      bat)
        echo "alias cat=\"bat --theme=TwoDark\"" >> "$ZSHRC_DEST";;
      lsd)
        echo "alias ls=\"lsd --group-dirs first --icon always\"" >> "$ZSHRC_DEST"
        echo "alias ll=\"lsd -lah --icon always\"" >> "$ZSHRC_DEST";;
      fd)
        echo "alias find=\"fd\"" >> "$ZSHRC_DEST";;
      dust)
        echo "alias du=\"dust\"" >> "$ZSHRC_DEST";;
      ripgrep)
        echo "alias grep=\"rg --color=auto\"" >> "$ZSHRC_DEST";;
      httpie)
        echo "alias curl=\"http\"" >> "$ZSHRC_DEST";;
      htop)
        echo "alias top=\"htop\"" >> "$ZSHRC_DEST";;
      tldr)
        echo "alias tldr=\"tldr --color\"";;
      lazydocker)
        echo "alias lzd='lazydocker'" >> "$ZSHRC_DEST";;
      grc)
        echo "alias ping=\"grc ping\"" >> "$ZSHRC_DEST"
        echo "alias traceroute=\"grc traceroute\"" >> "$ZSHRC_DEST"
        echo "alias netstat=\"grc netstat\"" >> "$ZSHRC_DEST"
        echo "alias make=\"grc make\"" >> "$ZSHRC_DEST"
        echo "alias gcc=\"grc gcc\"" >> "$ZSHRC_DEST"
        echo "alias g++=\"grc g++\"" >> "$ZSHRC_DEST"
        echo "alias dig=\"grc dig\"" >> "$ZSHRC_DEST"
        echo "alias df=\"grc df\"" >> "$ZSHRC_DEST"
        echo "alias mount=\"grc mount\"" >> "$ZSHRC_DEST";;
    esac
  done
  success "Aliase für installierte Tools hinzugefügt."
}

### FZF und Powerlevel10k Setup ###
function setup_advanced {
  echo "# FZF Config" >> "$ZSHRC_DEST"
  echo "# Set up fzf key bindings and fuzzy completion" >> "$ZSHRC_DEST"
  echo "source <(fzf --zsh)" >> "$ZSHRC_DEST"
  FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob \"!.git/*\""
  echo "export FZF_DEFAULT_COMMAND='$FZF_DEFAULT_COMMAND'" >> "$ZSHRC_DEST"
  echo "export FZF_CTRL_T_COMMAND=\$FZF_DEFAULT_COMMAND" >> "$ZSHRC_DEST"

  # Grundoptionen für FZF
  FZF_OPTS="--height 40% --layout=reverse --border"

  # Preview-Befehl erstellen
  PREVIEW_COMMAND='
  if [[ -z {} ]]; then
    echo \"[error] Datei existiert nicht oder Pfad ungültig.\"
  elif [[ \$(file --mime {}) =~ inode/x-empty ]]; then
    echo \"[info] Datei ist leer.\"
  elif [[ \$(file --mime {}) =~ application/pdf ]]; then'
  if [[ " ${TOOLS[*]} " =~ " poppler " ]]; then
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    pdftotext {} - 2>/dev/null || echo \\\"[error] Kann PDF nicht lesen.\\\""
  else
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    echo \\\"[info] PDF-Vorschau nicht verfügbar. Installiere 'poppler'.\\\""
  fi
  PREVIEW_COMMAND="${PREVIEW_COMMAND}
  elif [[ \\\$(file --mime {}) =~ binary ]]; then
    echo \\\"[info] Binärdateien werden nicht unterstützt.\\\"
  elif [[ \\\$(file --mime {}) =~ image/.* ]]; then"
  if [[ " ${TOOLS[*]} " =~ " kitty " ]]; then
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    kitty +kitten icat {} || echo \\\"[info] Bildvorschau nicht verfügbar.\\\""
  else
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    echo \\\"[info] Bildvorschau nicht verfügbar. Installiere 'kitty'.\\\""
  fi
  PREVIEW_COMMAND="${PREVIEW_COMMAND}
  elif [[ {} =~ .*\\\\.md$ ]]; then"
  if [[ " ${TOOLS[*]} " =~ " glow " ]]; then
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    glow {} || echo \\\"[info] Markdown-Vorschau nicht verfügbar.\\\""
  else
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    echo \\\"[info] Markdown-Vorschau nicht verfügbar. Installiere 'glow'.\\\""
  fi
  PREVIEW_COMMAND="${PREVIEW_COMMAND}
  else"
  if [[ " ${TOOLS[*]} " =~ " bat " ]]; then
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    bat --style=numbers --color=always {} || cat {} | head -500"
  else
    PREVIEW_COMMAND="${PREVIEW_COMMAND}
    cat {} | head -500"
  fi
  PREVIEW_COMMAND="${PREVIEW_COMMAND}
  fi"

  # FZF_OPTS mit Preview-Befehl erweitern
  FZF_OPTS="${FZF_OPTS} --preview=\"${PREVIEW_COMMAND}\" --preview-window=up:30%:wrap"

  # In der Zsh-Konfiguration speichern
  echo "export FZF_DEFAULT_OPTS='${FZF_OPTS}'" >> "$ZSHRC_DEST"


  if ! grep -q "[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh" ~/.zshrc; then
      echo "[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh" >> ~/.zshrc
      echo "✅ FZF-Source Zeile zur ~/.zshrc hinzugefügt."
  else
      echo "⚠️ FZF-Source Zeile ist bereits in der ~/.zshrc vorhanden."
  fi

  echo "# Powerlevel10k Config" >> "$ZSHRC_DEST"
  echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$ZSHRC_DEST"

  echo "# Homebrew PATH" >> "$ZSHRC_DEST"
  NEW_PATH="/usr/local/bin:/opt/homebrew/bin"

  CLEANED_PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')

  if [[ ":$CLEANED_PATH:" != *":$NEW_PATH:"* ]]; then
    FINAL_PATH="$NEW_PATH:$CLEANED_PATH"
  else
    FINAL_PATH="$CLEANED_PATH"
  fi

  echo "export PATH=\"$FINAL_PATH\"" >> "$ZSHRC_DEST"

  echo "# Enable FZF Tab Completion" >> "$ZSHRC_DEST"
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
    git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
    
    success "fzf-tab Plugin installiert."
  else
    success "fzf-tab Plugin ist bereits vorhanden."
  fi

  # Ergänze die .zshrc für fzf-tab und autoload
  echo "# FZF Tab Plugin" >> "$HOME/.zshrc"
  echo "if [ -d \"\${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab\" ]; then" >> "$HOME/.zshrc"
  echo "  source \"\${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh\"" >> "$HOME/.zshrc"
  echo "fi" >> "$HOME/.zshrc"

  # Ergänze autoload für Tab Completion
  echo "# Autoload for Tab Completion" >> "$HOME/.zshrc"
  echo "autoload -U compinit && compinit" >> "$HOME/.zshrc"

  echo "# FZF-Tab Erweiterte Konfiguration" >> ~/.zshrc
  echo "zstyle ':completion:*' menu select" >> ~/.zshrc
  echo "zstyle ':completion:*' select-prompt '%SScrolling active: %s rows remaining%s'" >> ~/.zshrc
  echo "zstyle ':fzf-tab:*' fzf-preview 'cat {}'" >> ~/.zshrc
  echo "zstyle ':fzf-tab:*' fzf-bindings 'tab:toggle-preview'" >> ~/.zshrc


  echo "source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc

  if [[ " ${TOOLS[*]} " =~ " neofetch " ]]; then
      echo 'if [[ $- == *i* ]]; then' >>~/.zshrc
      echo '  echo "🚀 Willkommen, $(whoami)! Dein Terminal ist bereit.\n"' >>~/.zshrc
      NEOFETCH_COMMAND="  neofetch --ascii_distro MacOS --memory_display infobar --disable shell packages resolution --color_blocks on --colors 4 6 1 3 5 7"
      echo "$NEOFETCH_COMMAND" >>~/.zshrc
      echo 'fi' >>~/.zshrc
      echo "✅ Neofetch-Befehl wurde in die .zshrc eingefügt!"
  fi
}

### Vorschau der Konfiguration ###
function preview_configuration {
  echo -e "\n📋 Geplante Installation:"
  echo "- Essentials: ${ESSENTIALS[*]}"
  echo "- Optionale Tools: ${TOOLS[*]}"
  echo "- Theme: powerlevel10k"
  read -p "Möchtest du fortfahren? (Y/n): " choice
  choice=${choice:-Y}
  if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    error "Installation abgebrochen."
    exit 1
  fi
}

### Setup-Script ###

ESSENTIALS=(zsh git zsh-completions fzf zoxide)
TOOLS=(${ESSENTIALS[@]})

step "Überprüfe Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "🍺 Homebrew wird installiert..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && success "Homebrew installiert."
else
  success "Homebrew ist bereits installiert."
fi

step "Aktualisiere Homebrew und installiere essentielle Tools..."
brew update && success "Homebrew Formeln aktualisiert."
read -p "Möchtest du alle installierten Homebrew-Pakete aktualisieren? (y/N): " -r -n 1 upgrade_choice
echo 
upgrade_choice=${upgrade_choice:-N}

if [[ "$upgrade_choice" =~ ^[Yy]$ ]]; then
  brew upgrade && echo "✅ Homebrew-Pakete aktualisiert."
else
  echo "⚠️ Überspringe Homebrew-Upgrade. Bereits installierte Pakete bleiben unverändert."
fi

for tool in "${ESSENTIALS[@]}"; do
  if ! brew list "$tool" &>/dev/null; then
    echo "📦 Installiere $tool..."
    brew install "$tool" && success "$tool installiert."
  else
    success "$tool ist bereits installiert."
  fi
done

setup_fzf

step "Wähle optionale Tools aus..."
select_tools

for tool in "${TOOLS[@]}"; do
  if ! brew list "$tool" &>/dev/null; then
    echo "📦 Installiere $tool..."
    brew install "$tool" && success "$tool installiert."
  else
    success "$tool ist bereits installiert."
  fi
done

step "Überprüfe iTerm2..."
if ! brew list --cask iterm2 &>/dev/null; then
  echo "📟 Installiere iTerm2..."
  brew install --cask iterm2 && success "iTerm2 installiert."
else
  success "iTerm2 ist bereits installiert."
fi

step "Stelle sicher, dass Nerd Fonts verfügbar sind..."
if ! brew list --cask font-hack-nerd-font &>/dev/null; then
  echo "🎨 Installiere Hack Nerd Font..."
  brew install --cask font-hack-nerd-font && success "Hack Nerd Font installiert."
else
  success "Hack Nerd Font ist bereits installiert."
fi

step "Überprüfe, ob Zsh die Standardshell ist..."
if [[ "$SHELL" != "$(which zsh)" ]]; then
  echo "⚙️ Setze Zsh als Standardshell..."
  if ! grep -Fxq "$(which zsh)" /etc/shells; then
    echo "$(which zsh)" | sudo tee -a /etc/shells
  fi
  chsh -s "$(which zsh)" && success "Zsh als Standardshell gesetzt."
else
  success "Zsh ist bereits die Standardshell."
fi

step "Installiere Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "✨ Installiere Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && success "Oh My Zsh installiert."
else
  success "Oh My Zsh ist bereits installiert."
fi

preview_configuration

step "Erstelle eine neue .zshrc..."
ZSHRC_DEST="$HOME/.zshrc"
echo "# Zsh Konfigurationsdatei" > "$ZSHRC_DEST"
echo "export ZSH=\"$HOME/.oh-my-zsh\"" >> "$ZSHRC_DEST"
echo "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" >> "$ZSHRC_DEST"
source "$ZSHRC_DEST"

step "Konfiguriere Oh My Zsh Plugins..."
select_plugins
source "$ZSHRC_DEST"

step "Füge Aliase hinzu..."
add_aliases

setup_advanced

read -p "Möchtest du die Shell jetzt neu starten, um die Änderungen zu übernehmen? (Y/n): " -r -n 1 restart_choice
echo
restart_choice=${restart_choice:-Y}

if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Starte die Shell neu..."
  exec zsh
else
  echo "✨ Du kannst die Änderungen mit \"source ~/.zshrc\" übernehmen."
fi

