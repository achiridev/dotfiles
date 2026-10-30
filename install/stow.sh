#!/usr/bin/env bash
set -e
DOTFILES="$HOME/dotfiles"

echo "→ Stowing config packages..."
cd "$DOTFILES/config"
for pkg in */; do
    name="${pkg%/}"
    # Obsidian se enlaza dentro del Vault, no en $HOME (ver más abajo).
    [ "$name" = "obsidian" ] && continue
    echo "  stow: $name"
    stow --target="$HOME" "$name"
done

echo "→ Stowing Obsidian vault..."
VAULT="$HOME/Documentos/Obsidian/Achiri"
if [ -d "$VAULT" ]; then
    cd "$DOTFILES/config/obsidian"
    stow --target="$VAULT" achiri
else
    echo "  (omitido: $VAULT no existe)"
fi

echo "→ Stowing home..."
cd "$DOTFILES/home"
stow --target="$HOME" .

echo "→ Stowing bin..."
cd "$DOTFILES/bin"
stow --target="$HOME" .

echo "✓ Listo. Revisa cambios con: cd $DOTFILES && git status"
