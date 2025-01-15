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

### Funktion: Scrape Plugins ###
function fetch_plugins {
  echo "🔄 Hole aktuelle Plugin-Liste von Oh My Zsh..."
  local plugins_page
  plugins_page=$(curl -s https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins)
  local plugins_raw
  plugins_raw=$(echo "$plugins_page" | grep -oP '(?<=<li><a href=").*?(?=" class)' | awk -F'/' '{print $NF}')
  available_plugins=($(echo "$plugins_raw" | sort))
}

### Interaktive Plugin-Auswahl mit fzf ###
function select_plugins {
  echo "🔧 Wähle die gewünschten Oh My Zsh Plugins aus (mit Leertaste auswählen, Enter zum Bestätigen):"
  local selected_plugins
  selected_plugins=$(printf "%s\n" "${available_plugins[@]}" | fzf --multi --prompt="Plugins auswählen: " --preview="echo {}" --preview-window=up:3:wrap)

  if [[ -n "$selected_plugins" ]]; then
    echo "plugins=(${selected_plugins//\n/ })" >> "$ZSHRC_DEST"
    success "Folgende Plugins wurden konfiguriert: $selected_plugins"
  else
    echo "⚠️ Keine Plugins ausgewählt."
  fi
}

### Interaktive Tool-Auswahl mit fzf ###
function select_tools {
  local optional_tools=(bat exa fd dust ripgrep httpie htop)
  echo "🔧 Wähle optionale Tools aus (mit Leertaste auswählen, Enter zum Bestätigen):"
  local selected_tools
  selected_tools=$(printf "%s\n" "${optional_tools[@]}" | fzf --multi --prompt="Tools auswählen: " --preview="echo {}" --preview-window=up:3:wrap)

  if [[ -n "$selected_tools" ]]; then
    TOOLS+=(${selected_tools//\n/ })
    success "Folgende Tools werden zusätzlich installiert: $selected_tools"
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
      exa)
        echo "alias ls=\"exa --group-directories-first --icons\"" >> "$ZSHRC_DEST"
        echo "alias ll=\"exa -lah --git --icons\"" >> "$ZSHRC_DEST";;
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
ESSENTIALS=(zsh zsh-completions fzf zoxide)
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
brew update && brew upgrade && success "Homebrew aktualisiert."
for tool in "${ESSENTIALS[@]}"; do
  if ! brew list "$tool" &>/dev/null; then
    echo "📦 Installiere $tool..."
    brew install "$tool" && success "$tool installiert."
  else
    success "$tool ist bereits installiert."
  fi
done

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

# Setze Zsh als Standardshell
step "Überprüfe, ob Zsh die Standardshell ist..."
if [[ "$SHELL" != "$(which zsh)" ]]; then
  echo "⚙️ Setze Zsh als Standardshell..."
  if ! grep -Fxq "$(which zsh)" /etc/shells; then
    echo "$(which zsh)" | sudo tee -a /etc/shells
  fi
  chsh -s "$(which zsh)" && success "Zsh als Standardshell gesetzt."
  exec zsh
else
  success "Zsh ist bereits die Standardshell."
fi

# Installiere Oh My Zsh, falls nicht vorhanden
step "Installiere Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "✨ Installiere Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && success "Oh My Zsh installiert."
  exec zsh
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

# Hole verfügbare Plugins
step "Hole verfügbare Plugins von Oh My Zsh..."
fetch_plugins

# Vorschau der Konfiguration
preview_configuration

# Interaktive Plugin-Auswahl
step "Konfiguriere Oh My Zsh Plugins..."
select_plugins
source "$ZSHRC_DEST"

# Füge Aliase basierend auf ausgewählten Tools hinzu
step "Füge Aliase hinzu..."
add_aliases

# Füge FZF Key Bindings hinzu
step "Füge FZF Key Bindings hinzu..."
if [[ ! -f "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" ]]; then
  echo "🔧 Installiere FZF Key Bindings..."
  "$(brew --prefix)/opt/fzf/install" --all && success "FZF Key Bindings installiert."
else
  success "FZF Key Bindings sind bereits konfiguriert."
fi

# Frage nach p10k configure
read -p "Möchtest du den Powerlevel10k Konfigurationsassistenten jetzt starten? (y/n): " configure_choice
if [[ "$configure_choice" =~ ^[Yy]$ ]]; then
  echo "⚙️ Starte 'p10k configure'..."
  exec zsh -i -c "p10k configure"
else
  echo "✨ Du kannst später 'p10k configure' manuell ausführen."
fi

# Frage, ob die Shell neu geladen werden soll
read -p "Möchtest du die Shell jetzt neu laden? (y/n): " reload_choice
if [[ "$reload_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Lade die Shell neu..."
  exec zsh
else
  echo "✨ Du kannst später 'exec zsh' manuell ausführen."
fi

# Endfeedback
echo -e "\n🎉 Fertig! Alle Installationen sind erfolgreich abgeschlossen."

