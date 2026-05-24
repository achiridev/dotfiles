#!/usr/bin/env bash
set -e
DOTFILES="$HOME/dotfiles"

echo "→ Stowing config packages..."
cd "$DOTFILES/config"
for pkg in */; do
    echo "  stow: $pkg"
    stow --target="$HOME" "${pkg%/}"
done

echo "→ Stowing home..."
cd "$DOTFILES/home"
stow --target="$HOME" .

echo "→ Stowing bin..."
cd "$DOTFILES/bin"
stow --target="$HOME" .

echo "✓ Listo. Revisa cambios con: cd $DOTFILES && git status"
