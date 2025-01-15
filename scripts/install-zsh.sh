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

### Interaktive Plugin-Auswahl mit fzf ###
function select_plugins {
  local optional_plugins=(docker 1password aliases brew dotnet zsh-autosuggestions zsh-syntax-highlighting)
  echo "🔧 Wähle die gewünschten Oh My Zsh Plugins aus (mit Tab auswählen, Enter zum Bestätigen):"
  local selected_plugins
  selected_plugins=$(printf "%s\n" "${optional_plugins[@]}" | fzf --multi --prompt="Plugins auswählen mit TAB: " --preview="echo {}" --preview-window=up:3:wrap | tr '\n' ' ')

  if [[ -n "$selected_plugins" ]]; then
    IFS=' ' read -r -a selected_plugins_array <<< "$selected_plugins"
    echo "plugins=(fzf fzf-tab ${selected_plugins_array[*]})" >> "$ZSHRC_DEST"
    success "Folgende Plugins wurden konfiguriert: ${selected_plugins_array[*]}"
  else
    echo "⚠️ Keine Plugins ausgewählt."
  fi
}

### Interaktive Tool-Auswahl mit fzf ###
function select_tools {
  local optional_tools=(bat lsd fd dust ripgrep httpie htop)
  echo "🔧 Wähle optionale Tools aus (mit Tab auswählen, Enter zum Bestätigen):"
  local selected_tools
  selected_tools=$(printf "%s\n" "${optional_tools[@]}" | fzf --multi --prompt="Tools auswählen mit TAB: " --preview="echo {}" --preview-window=up:3:wrap | tr '\n' ' ')

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
    esac
  done
  success "Aliase für installierte Tools hinzugefügt."
}

### FZF und Powerlevel10k Setup ###
function setup_advanced {
  echo "# FZF Config" >> "$ZSHRC_DEST"
  echo "export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob \"!.git/*\"'" >> "$ZSHRC_DEST"
  echo "export FZF_CTRL_T_COMMAND='${FZF_DEFAULT_COMMAND}'" >> "$ZSHRC_DEST"
  echo "export FZF_DEFAULT_OPTS=\"--height 40% --layout=reverse --border\"" >> "$ZSHRC_DEST"

  if ! grep -q "[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh" ~/.zshrc; then
      echo "[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh" >> ~/.zshrc
      echo "✅ FZF-Source Zeile zur ~/.zshrc hinzugefügt."
  else
      echo "⚠️ FZF-Source Zeile ist bereits in der ~/.zshrc vorhanden."
  fi

  echo "# Powerlevel10k Config" >> "$ZSHRC_DEST"
  echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$ZSHRC_DEST"

  echo "# Homebrew PATH" >> "$ZSHRC_DEST"
  echo "export PATH=\"/usr/local/bin:/opt/homebrew/bin:$PATH\"" >> "$ZSHRC_DEST"

  echo "# Enable FZF Tab Completion" >> "$ZSHRC_DEST"
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
    git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
    
    success "fzf-tab Plugin installiert."
  else
    success "fzf-tab Plugin ist bereits vorhanden."
  fi

  echo "# FZF-Tab Erweiterte Konfiguration" >> ~/.zshrc
  echo "zstyle ':completion:*' menu select" >> ~/.zshrc
  echo "zstyle ':completion:*' select-prompt '%SScrolling active: %s rows remaining%s'" >> ~/.zshrc
  echo "zstyle ':fzf-tab:*' fzf-preview 'cat {}'" >> ~/.zshrc
  echo "zstyle ':fzf-tab:*' fzf-bindings 'tab:toggle-preview'" >> ~/.zshrc


  echo "source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc
}

### Vorschau der Konfiguration ###
function preview_configuration {
  echo -e "\n📋 Geplante Installation:"
  echo "- Essentials: ${ESSENTIALS[*]}"
  echo "- Optionale Tools: ${TOOLS[*]}"
  echo "- Theme: powerlevel10k"
  read -p "Möchtest du fortfahren? (y/n): " choice
  if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    error "Installation abgebrochen."
    exit 1
  fi
}

### Setup-Script ###

# Essentials und Standard-Tools definieren
ESSENTIALS=(zsh git zsh-completions fzf zoxide)
TOOLS=(${ESSENTIALS[@]})

# Installiere Homebrew, falls nicht vorhanden
step "Überprüfe Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "🍺 Homebrew wird installiert..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && success "Homebrew installiert."
else
  success "Homebrew ist bereits installiert."
fi

# Update Homebrew und installiere Essentials
step "Aktualisiere Homebrew und installiere essentielle Tools..."
brew update && success "Homebrew Formeln aktualisiert."
read -p "Möchtest du alle installierten Homebrew-Pakete aktualisieren? (y/n): " upgrade_choice
if [[ "$upgrade_choice" =~ ^[Yy]$ ]]; then
  brew upgrade && success "Homebrew Pakete aktualisiert."
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

# FZF einrichten
setup_fzf

# Interaktive Tool-Auswahl
step "Wähle optionale Tools aus..."
select_tools

# Installiere optionale Tools
for tool in "${TOOLS[@]}"; do
  if ! brew list "$tool" &>/dev/null; then
    echo "📦 Installiere $tool..."
    brew install "$tool" && success "$tool installiert."
  else
    success "$tool ist bereits installiert."
  fi
done

# Installiere iTerm2, falls nicht vorhanden
step "Überprüfe iTerm2..."
if ! brew list --cask iterm2 &>/dev/null; then
  echo "📟 Installiere iTerm2..."
  brew install --cask iterm2 && success "iTerm2 installiert."
else
  success "iTerm2 ist bereits installiert."
fi

# Installiere Nerd Fonts für Powerlevel10k
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

# Installiere Oh My Zsh, falls nicht vorhanden
step "Installiere Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "✨ Installiere Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && success "Oh My Zsh installiert."
else
  success "Oh My Zsh ist bereits installiert."
fi

# Erstelle eine neue .zshrc
step "Erstelle eine neue .zshrc..."
ZSHRC_DEST="$HOME/.zshrc"
echo "# Zsh Konfigurationsdatei" > "$ZSHRC_DEST"
echo "export ZSH=\"$HOME/.oh-my-zsh\"" >> "$ZSHRC_DEST"
echo "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" >> "$ZSHRC_DEST"
source "$ZSHRC_DEST"

# Vorschau der Konfiguration
preview_configuration

# Interaktive Plugin-Auswahl
step "Konfiguriere Oh My Zsh Plugins..."
select_plugins
source "$ZSHRC_DEST"

# Füge Aliase basierend auf ausgewählten Tools hinzu
step "Füge Aliase hinzu..."
add_aliases

# Erweiterte Konfiguration hinzufügen
setup_advanced

### Tab-Completion aktivieren ###
echo '
# Temporäres Setup für Zsh-Completion
if [ -f "$HOME/.temp_zsh_setup.sh" ]; then
  source "$HOME/.temp_zsh_setup.sh"
fi
' >> "$HOME/.zshrc"

# Temporäres Script erstellen
cat << 'EOF' > "$HOME/.temp_zsh_setup.sh"
#!/bin/zsh

# Initialisiere Zsh-Komponenten
autoload -U compinit && compinit
autoload -U bashcompinit && bashcompinit

# Entferne den temporären Setup-Block aus der .zshrc
sed -i '' '/# Temporäres Setup für Zsh-Completion/,/fi/d' "$HOME/.zshrc"

# Lösche dieses temporäre Script
rm -- "$0"
EOF

chmod +x "$HOME/.temp_zsh_setup.sh"

echo "⚙️ Temporäres Setup-Script erstellt und in .zshrc eingetragen."
echo "✨ Starte die Shell neu, um die Änderungen zu übernehmen."

# Frage nach Neustart der Shell
read -p "Möchtest du die Shell jetzt neu starten, um die Änderungen zu übernehmen? (y/n): " restart_choice
if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Starte die Shell neu..."
  exec zsh
else
  echo "✨ Du kannst die Änderungen mit \"source ~/.zshrc\" übernehmen."
fi
