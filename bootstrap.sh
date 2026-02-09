#!/bin/bash
# =============================================================================
# Bootstrap Script - Claude Code Workstation POC
# =============================================================================
# Este script se ejecuta como user_data al iniciar la instancia EC2
# Instala: AWS CLI v2, Claude Code, Node.js, Python, herramientas de desarrollo
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

LOG_FILE="/var/log/bootstrap.log"
CLAUDE_USER="ubuntu"
HOME_DIR="/home/${CLAUDE_USER}"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

exec > >(tee -a "$LOG_FILE") 2>&1
echo "=========================================="
echo "Bootstrap iniciado: $(date)"
echo "=========================================="

# -----------------------------------------------------------------------------
# Actualizar sistema
# -----------------------------------------------------------------------------

echo "[1/9] Actualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# -----------------------------------------------------------------------------
# Instalar dependencias base
# -----------------------------------------------------------------------------

echo "[2/9] Instalando dependencias base..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    jq \
    htop \
    tree \
    vim \
    tmux \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential

# -----------------------------------------------------------------------------
# Instalar AWS CLI v2
# -----------------------------------------------------------------------------

echo "[3/9] Instalando AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    cd /tmp
    curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -qq awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi
aws --version

# -----------------------------------------------------------------------------
# Instalar Node.js 20 LTS
# -----------------------------------------------------------------------------

echo "[4/9] Instalando Node.js 20 LTS..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
fi
node --version
npm --version

# -----------------------------------------------------------------------------
# Instalar Python 3.12
# -----------------------------------------------------------------------------

echo "[5/9] Instalando GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update -qq
apt-get install -y -qq gh
gh --version

# -----------------------------------------------------------------------------
# Instalar Python 3.12
# -----------------------------------------------------------------------------

echo "[6/9] Instalando Python 3.12..."
apt-get install -y -qq python3 python3-pip python3-venv
python3 --version
pip3 --version

# -----------------------------------------------------------------------------
# Instalar Claude Code CLI
# -----------------------------------------------------------------------------

echo "[7/9] Instalando Claude Code CLI..."
npm install -g @anthropic-ai/claude-code || true
claude --version || echo "Claude Code instalado (requiere configuración)"

# -----------------------------------------------------------------------------
# Configurar usuario ubuntu
# -----------------------------------------------------------------------------

echo "[8/9] Configurando usuario ubuntu..."

# Crear directorios necesarios
sudo -u "$CLAUDE_USER" mkdir -p "${HOME_DIR}/.aws"
sudo -u "$CLAUDE_USER" mkdir -p "${HOME_DIR}/.claude"

# Crear estructura /opt/claude-workstation según PrompClaude.md
mkdir -p /opt/claude-workstation
mkdir -p /opt/claude-workstation/agents-md
mkdir -p /opt/claude-workstation/scripts
mkdir -p /var/log/claude-workstation
chown -R ${CLAUDE_USER}:${CLAUDE_USER} /opt/claude-workstation
chown -R ${CLAUDE_USER}:${CLAUDE_USER} /var/log/claude-workstation

# Configurar bashrc
cat >> "${HOME_DIR}/.bashrc" << 'EOF'

# Claude Code Workstation aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'

# AWS aliases
alias aws-whoami='aws sts get-caller-identity'
alias aws-region='echo $AWS_DEFAULT_REGION'

# Colores para prompt
export PS1='\[\033[01;32m\]\u@claude-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Variables de entorno
export AWS_DEFAULT_REGION=us-east-2
export EDITOR=vim
EOF

chown -R "${CLAUDE_USER}:${CLAUDE_USER}" "${HOME_DIR}"

# -----------------------------------------------------------------------------
# Instalar SSM Agent (ya incluido en Ubuntu 24.04, verificar)
# -----------------------------------------------------------------------------

echo "[9/9] Verificando SSM Agent..."
if ! systemctl is-active --quiet amazon-ssm-agent; then
    snap install amazon-ssm-agent --classic || true
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
fi
systemctl status amazon-ssm-agent --no-pager || true

# -----------------------------------------------------------------------------
# Limpieza
# -----------------------------------------------------------------------------

echo "Limpiando..."
apt-get autoremove -y -qq
apt-get clean

# -----------------------------------------------------------------------------
# Finalización
# -----------------------------------------------------------------------------

echo "=========================================="
echo "Bootstrap completado: $(date)"
echo "=========================================="
echo ""
echo "Herramientas instaladas:"
echo "  - AWS CLI: $(aws --version 2>&1 | head -1)"
echo "  - Node.js: $(node --version)"
echo "  - npm: $(npm --version)"
echo "  - Python: $(python3 --version)"
echo "  - GitHub CLI: $(gh --version | head -1)"
echo "  - Claude Code: $(claude --version 2>&1 || echo 'requiere configuración')"
echo ""
echo "Directorios creados:"
echo "  - /opt/claude-workstation"
echo "  - /opt/claude-workstation/agents-md"
echo "  - /var/log/claude-workstation"
echo ""
echo "Próximos pasos (via SSM Session Manager):"
echo "  1. Conectar: aws ssm start-session --target <instance-id> --profile 025270448741 --region us-east-2"
echo "  2. Configurar AWS SSO profiles: ~/.aws/config"
echo "  3. Configurar Claude Code: claude configure"
echo "  4. Autenticar GitHub CLI: gh auth login"
echo "=========================================="
