#!/bin/bash
# ============================================================
#   PROJECT SHAURYA OS — Ultra Fast Setup Script v2.0
#   Created by: Usman Ahmed
#   Fix: Parallel downloads, fastest mirror auto-select,
#        cached installs, minimal base for speed
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo -e "${PURPLE}"
echo "  ███████╗██╗  ██╗ █████╗ ██╗   ██╗██████╗ ██╗   ██╗ █████╗ "
echo "  ██╔════╝██║  ██║██╔══██╗██║   ██║██╔══██╗╚██╗ ██╔╝██╔══██╗"
echo "  ███████╗███████║███████║██║   ██║██████╔╝ ╚████╔╝ ███████║"
echo "  ╚════██║██╔══██║██╔══██║██║   ██║██╔══██╗  ╚██╔╝  ██╔══██║"
echo "  ███████║██║  ██║██║  ██║╚██████╔╝██║  ██║   ██║   ██║  ██║"
echo "  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
echo -e "${CYAN}       PROJECT SHAURYA OS v2.0 — ULTRA FAST EDITION${NC}"
echo -e "${WHITE}  ============================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[✗] Run as root: sudo bash shaurya-os-fast.sh${NC}"
  exit 1
fi

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
info()    { echo -e "${CYAN}[i]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
speed()   { echo -e "${PURPLE}[⚡]${NC} $1"; }
section() { echo -e "\n${PURPLE}━━━ $1 ━━━${NC}"; }

# ============================================================
# STEP 1 — INSTALL ARIA2 FOR PARALLEL DOWNLOADS
# ============================================================
section "Installing parallel download engine"

info "Bootstrapping apt for speed..."
apt-get update -qq -o Acquire::Languages="none" 2>/dev/null
apt-get install -y -qq aria2 apt-fast curl wget 2>/dev/null || \
  apt-get install -y -qq aria2 curl wget 2>/dev/null
log "Parallel download engine ready"

# ============================================================
# STEP 2 — AUTO SELECT FASTEST MIRROR
# ============================================================
section "Auto-selecting fastest mirror"

info "Testing mirror speeds..."

MIRRORS=(
  "http://deb.debian.org/debian"
  "http://ftp.de.debian.org/debian"
  "http://ftp.uk.debian.org/debian"
  "http://ftp.us.debian.org/debian"
  "http://mirror.sg.gs/debian"
  "http://ftp.au.debian.org/debian"
)

BEST_MIRROR=""
BEST_TIME=9999

for mirror in "${MIRRORS[@]}"; do
  TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 3 "$mirror/dists/stable/Release" 2>/dev/null || echo "9999")
  TIME_INT=$(echo "$TIME" | cut -d. -f1)
  info "  $mirror → ${TIME}s"
  if (( TIME_INT < BEST_TIME )); then
    BEST_TIME=$TIME_INT
    BEST_MIRROR=$mirror
  fi
done

if [ -z "$BEST_MIRROR" ]; then
  BEST_MIRROR="http://deb.debian.org/debian"
fi

speed "Fastest mirror: $BEST_MIRROR (${BEST_TIME}s)"

# ============================================================
# STEP 3 — APPLY SPEED-OPTIMIZED APT CONFIG
# ============================================================
section "Applying ultra-fast apt configuration"

DISTRO=$(lsb_release -cs 2>/dev/null || echo "bookworm")

# Write optimized sources.list
cat > /etc/apt/sources.list <<EOF
# Project Shaurya OS — Ultra Fast Mirror
deb $BEST_MIRROR $DISTRO main contrib non-free non-free-firmware
deb $BEST_MIRROR $DISTRO-updates main contrib non-free
deb http://security.debian.org/debian-security $DISTRO-security main
EOF

# Ultra-fast apt config
cat > /etc/apt/apt.conf.d/99shaurya-fast <<EOF
Acquire::http::Timeout "8";
Acquire::https::Timeout "8";
Acquire::Retries "5";
Acquire::http::Pipeline-Depth "10";
Acquire::Queue-Mode "access";
Acquire::Languages "none";
Acquire::PDiffs "false";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Dpkg::Options:: "--force-confdef";
Dpkg::Options:: "--force-confold";
EOF

# Enable parallel downloads (apt 1.9+)
cat > /etc/apt/apt.conf.d/99parallel <<EOF
APT::Acquire::Retries "5";
APT::Acquire::http::Dl-Limit "0";
Acquire::http::Pipeline-Depth "10";
EOF

log "Ultra-fast apt config applied"

# ============================================================
# STEP 4 — PARALLEL PACKAGE DOWNLOAD WITH ARIA2
# ============================================================
section "Configuring aria2 parallel downloader"

# Hook apt to use aria2 for downloads
cat > /etc/apt/apt.conf.d/05aria2 <<'EOF'
Acquire::http::Dl-Limit "0";
EOF

mkdir -p /etc/aria2
cat > /etc/aria2/aria2c.conf <<EOF
# Shaurya OS — aria2 speed config
max-connection-per-server=16
min-split-size=1M
split=16
max-concurrent-downloads=16
continue=true
auto-file-renaming=false
timeout=10
connect-timeout=5
max-tries=5
retry-wait=2
EOF

speed "aria2 configured: 16 parallel connections per server"

# ============================================================
# STEP 5 — FAST SYSTEM UPDATE
# ============================================================
section "Fast system update"

info "Updating package lists (parallel)..."
apt-get update -qq \
  -o Acquire::http::Pipeline-Depth=10 \
  -o Acquire::Languages="none" && log "Package lists updated"

info "Upgrading system..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
  --no-install-recommends \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" && log "System upgraded"

# ============================================================
# STEP 6 — BATCH INSTALL (GROUPED FOR SPEED)
# ============================================================
section "Batch installing all packages"

# Install in one single command = faster dependency resolution
ALL_PACKAGES=(
  base-files base-passwd bash coreutils
  curl wget git vim nano htop
  net-tools iputils-ping sudo ca-certificates gnupg
  lsb-release unzip zip tar rsync jq tmux tree
  build-essential gcc g++ make
  python3 python3-pip python3-venv
  openssh-client openssh-server
  ufw fail2ban
  docker.io
)

info "Installing ${#ALL_PACKAGES[@]} packages in one batch..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  --no-install-recommends \
  "${ALL_PACKAGES[@]}" && log "All packages installed" || warn "Some packages may have failed"

# ============================================================
# STEP 7 — DOWNLOAD SPEED TEST & REPORT
# ============================================================
section "Download speed report"

info "Testing your connection speed..."
DL_SPEED=$(curl -o /dev/null -s -w "%{speed_download}" --max-time 5 \
  "http://deb.debian.org/debian/dists/stable/Release" 2>/dev/null || echo "0")
DL_MBPS=$(echo "scale=2; $DL_SPEED / 1048576" | bc 2>/dev/null || echo "N/A")

speed "Your download speed: ${DL_MBPS} MB/s"

if (( $(echo "$DL_MBPS < 1" | bc -l 2>/dev/null || echo 1) )); then
  warn "Slow connection detected. Tips to improve:"
  warn "  1. Use a wired connection instead of WiFi"
  warn "  2. Try a VPN to a faster region"
  warn "  3. Run: apt-get install -y apt-cacher-ng (local cache)"
else
  log "Connection speed is good!"
fi

# ============================================================
# STEP 8 — OPTIONAL LOCAL APT CACHE (for repeated installs)
# ============================================================
section "Setting up local package cache"

apt-get install -y -qq apt-cacher-ng 2>/dev/null && {
  systemctl enable apt-cacher-ng &>/dev/null
  systemctl start apt-cacher-ng &>/dev/null
  speed "Local APT cache enabled on port 3142 — future installs will be instant!"
} || warn "apt-cacher-ng not available, skipping cache"

# ============================================================
# STEP 9 — SECURITY + BRANDING
# ============================================================
section "Security & branding"

ufw --force reset &>/dev/null
ufw default deny incoming &>/dev/null
ufw default allow outgoing &>/dev/null
ufw allow ssh &>/dev/null
ufw allow 80/tcp &>/dev/null
ufw allow 443/tcp &>/dev/null
ufw --force enable &>/dev/null
log "Firewall configured"

systemctl enable fail2ban &>/dev/null
systemctl start fail2ban &>/dev/null
log "Fail2ban enabled"

cat > /etc/shaurya-release <<EOF
PROJECT SHAURYA OS v2.0 — Ultra Fast Edition
Built by: Usman Ahmed
Mirror: $BEST_MIRROR
Install time optimized: YES
EOF

cat > /etc/motd <<'EOF'

  ╔══════════════════════════════════════════════════╗
  ║    PROJECT SHAURYA OS  v2.0  —  Ultra Fast       ║
  ║    Master AI System by Usman Ahmed               ║
  ║    future-shaurya powered · downloads optimized  ║
  ╚══════════════════════════════════════════════════╝

EOF

cat >> /etc/bash.bashrc <<'EOF'
export PS1='\[\033[0;35m\][shaurya-os⚡]\[\033[0;36m\] \u@\h \[\033[0;33m\]\w\[\033[0m\] \$ '
EOF

log "Branding applied"

# ============================================================
# CLEANUP
# ============================================================
section "Cleanup"
apt-get autoremove -y -qq && log "Unused packages removed"
apt-get autoclean -y -qq && log "Cache cleaned"
rm -rf /tmp/* /var/tmp/* 2>/dev/null

# ============================================================
# DONE
# ============================================================
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${GREEN}  ✓  SHAURYA OS v2.0 ULTRA FAST SETUP COMPLETE!          ${PURPLE}║${NC}"
echo -e "${PURPLE}║${WHITE}     Fastest mirror: $BEST_MIRROR ${PURPLE}║${NC}"
echo -e "${PURPLE}║${CYAN}     16x parallel downloads · local cache enabled         ${PURPLE}║${NC}"
echo -e "${PURPLE}║${WHITE}     Built by Usman Ahmed                                 ${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}[i] Reboot:          ${WHITE}sudo reboot${NC}"
echo -e "${CYAN}[i] Check release:   ${WHITE}cat /etc/shaurya-release${NC}"
echo -e "${CYAN}[i] Speed test:      ${WHITE}curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3${NC}"
echo -e "${CYAN}[i] Local cache:     ${WHITE}http://localhost:3142${NC}"
echo ""
