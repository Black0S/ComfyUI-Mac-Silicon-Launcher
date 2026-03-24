#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

REPO_DIR="comfyui"
VENV_DIR="$REPO_DIR/.venv"
VENV_PY="$VENV_DIR/bin/python"

# ─────────────────────────────────────────────────────────────
# PRE-CHECKS
# ─────────────────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
  echo "❌ Directory '$REPO_DIR' not found. Run ./install.sh first."
  exit 1
fi

if [ ! -x "$VENV_PY" ]; then
  echo "❌ Virtualenv not found in $VENV_DIR. Run ./install.sh first."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# DETECT CURRENT PYTHON VERSION IN VENV
# ─────────────────────────────────────────────────────────────
CURRENT_PY_VERSION=$("$VENV_PY" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  switchpy — Switch Python version for ComfyUI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Current venv Python version: ${GREEN}$CURRENT_PY_VERSION${RESET}"
echo ""
echo "  Select a new Python version:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Display options — highlight current version in yellow with a warning
for entry in "1|3.12|⚠️  Older but maximum compatibility with custom nodes" \
             "2|3.13|✅  Recommended, compatible with most custom nodes" \
             "3|3.14|🧪  Experimental, some custom nodes may not work"; do
  NUM="${entry%%|*}"
  REST="${entry#*|}"
  VER="${REST%%|*}"
  NOTE="${REST#*|}"

  if [ "$VER" = "$CURRENT_PY_VERSION" ]; then
    echo -e "  $NUM) ${YELLOW}Python $VER  ← already in use${RESET}  $NOTE"
  else
    echo "  $NUM) Python $VER  — $NOTE"
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -rp "Your choice [1-3]: " PY_CHOICE

case "$PY_CHOICE" in
  1) NEW_PY_VERSION="3.12" ;;
  2) NEW_PY_VERSION="3.13" ;;
  3) NEW_PY_VERSION="3.14" ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac

# ─────────────────────────────────────────────────────────────
# GUARD: same version selected
# ─────────────────────────────────────────────────────────────
if [ "$NEW_PY_VERSION" = "$CURRENT_PY_VERSION" ]; then
  echo ""
  echo "⚠️  Python $NEW_PY_VERSION is already the active version. Nothing to do."
  exit 0
fi

echo ""
echo "✅ Switching from Python $CURRENT_PY_VERSION → Python $NEW_PY_VERSION"
echo ""

# ─────────────────────────────────────────────────────────────
# OS SELECTION (needed for package manager + PyTorch)
# ─────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Select your OS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1) Fedora / RHEL / CentOS   (dnf)"
echo "  2) Arch Linux               (pacman)"
echo "  3) Ubuntu / Debian          (apt)"
echo "  4) macOS                    (brew)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -rp "Your choice [1-4]: " OS_CHOICE

case "$OS_CHOICE" in
  1) OS_TYPE="Fedora"  ;;
  2) OS_TYPE="Arch"    ;;
  3) OS_TYPE="Ubuntu"  ;;
  4) OS_TYPE="MacOS"   ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac
echo "✅ Selected: $OS_TYPE"
echo ""

# ─────────────────────────────────────────────────────────────
# CHECK / INSTALL NEW PYTHON VERSION
# ─────────────────────────────────────────────────────────────
echo "==> Checking Python $NEW_PY_VERSION"
if ! command -v "python$NEW_PY_VERSION" >/dev/null 2>&1; then
  echo "python$NEW_PY_VERSION not found. Installing..."
  case "$OS_TYPE" in
    fedora) sudo dnf install -y "python$NEW_PY_VERSION" ;;
    arch)   sudo pacman -S --noconfirm "python$NEW_PY_VERSION" ;;
    ubuntu) sudo apt-get install -y "python$NEW_PY_VERSION" "python${NEW_PY_VERSION}-venv" ;;
    macos)  brew install "python@$NEW_PY_VERSION" ;;
  esac
fi
echo "✅ $("python$NEW_PY_VERSION" --version)"

# ─────────────────────────────────────────────────────────────
# DELETE OLD VENV
# ─────────────────────────────────────────────────────────────
echo ""
echo "==> Removing old virtualenv (Python $CURRENT_PY_VERSION)..."
rm -rf "$VENV_DIR"
echo "✅ Old virtualenv removed."

# ─────────────────────────────────────────────────────────────
# CREATE NEW VENV
# ─────────────────────────────────────────────────────────────
echo ""
echo "==> Creating new virtualenv with Python $NEW_PY_VERSION..."
"python$NEW_PY_VERSION" -m venv "$VENV_DIR"
VENV_PY="$VENV_DIR/bin/python"
echo "✅ New virtualenv created."

echo ""
echo "==> Updating pip in the new virtualenv..."
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

# ─────────────────────────────────────────────────────────────
# PYTORCH INSTALLATION
# ─────────────────────────────────────────────────────────────
echo ""
if [ "$OS_TYPE" = "macos" ]; then
  echo "==> Installing PyTorch (nightly, CPU — macOS)..."
  "$VENV_PY" -m pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu
else
  echo "==> Installing PyTorch with CUDA support (cu130)..."
  "$VENV_PY" -m pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
fi

# ─────────────────────────────────────────────────────────────
# COMFYUI DEPENDENCIES
# ─────────────────────────────────────────────────────────────
echo ""
echo "==> Installing ComfyUI dependencies..."
"$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"

# ─────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────
echo ""
echo "✅ Switch complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Python: ${GREEN}$CURRENT_PY_VERSION → $NEW_PY_VERSION${RESET}"
echo ""
echo "📊 PyTorch check:"
if [ "$OS_TYPE" = "macos" ]; then
  "$VENV_PY" -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'MPS (Apple GPU) available: {torch.backends.mps.is_available()}')
"
else
  "$VENV_PY" -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')
"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To launch: ./launch.sh"
