#!/usr/bin/env bash
#
# ParsDev Mirror — automatic repository setup
# https://mirror.parsdev.com/
#
# Usage (as root — many minimal installs have no sudo):
#   bash setup.sh              # detect the OS and switch it to the mirror
#   bash setup.sh --dry-run    # show what would change, write nothing
#   bash setup.sh --rollback   # restore the most recent backup of every file touched
#
# Backups are kept in /var/backups/parsdev-mirror/<timestamp>/, never beside the
# original — apt warns about any stray file in /etc/apt/sources.list.d/.
#
set -euo pipefail

MIRROR="https://mirror.parsdev.com"
STAMP="$(date +%Y%m%d%H%M%S)"
DRY_RUN=0
ROLLBACK=0

c_ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
c_warn() { printf '\033[33m%s\033[0m\n' "$*"; }
c_err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
info()   { printf '\033[36m==>\033[0m %s\n' "$*"; }

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=1 ;;
    --rollback) ROLLBACK=1 ;;
    -h|--help)  usage ;;
    *) c_err "unknown option: $arg"; exit 2 ;;
  esac
done

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    c_err "This script must run as root. Log in as root and re-run it, or use sudo if it is installed."
    exit 1
  fi
}

# Backups live outside /etc/apt and /etc/yum.repos.d on purpose: apt scans
# sources.list.d/ and warns about every file whose name does not end in .list
# or .sources, so a .bak sitting next to the original is noise on every run.
BACKUP_ROOT="/var/backups/parsdev-mirror"
SNAPSHOT="$BACKUP_ROOT/$STAMP"

# stash_file <path> — copy the current contents into this run's snapshot
stash_file() {
  local path="$1" dest="$SNAPSHOT$1"
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest"
}

# record <created|modified> <path> — what rollback should do with this file
record() {
  mkdir -p "$SNAPSHOT"
  printf '%s\t%s\n' "$1" "$2" >> "$SNAPSHOT/manifest"
}

# write_file <path> <<< "content"  — backs the file up first, honours --dry-run
write_file() {
  local path="$1" content
  content="$(cat)"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] would write $path:"
    printf '%s\n' "$content" | sed 's/^/    /'
    return 0
  fi

  if [ -e "$path" ]; then
    stash_file "$path"
    record modified "$path"
    info "backed up $path -> $SNAPSHOT$path"
  else
    record created "$path"
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  c_ok "wrote $path"
}

backup_only() {
  local path="$1"
  [ -e "$path" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] would back up $path"
    return 0
  fi
  stash_file "$path"
  record modified "$path"
  info "backed up $path -> $SNAPSHOT$path"
}

# Earlier versions of this script wrote <file>.bak.<stamp> next to the original.
# Move any of those out of the repository directories so apt stops complaining,
# keeping them where rollback can still find them.
migrate_legacy_backups() {
  local bak dest moved=0
  for bak in /etc/apt/sources.list.bak.* \
             /etc/apt/sources.list.d/*.bak.* \
             /etc/yum.repos.d/*.bak.*; do
    [ -e "$bak" ] || continue
    dest="$BACKUP_ROOT/legacy$bak"
    mkdir -p "$(dirname "$dest")"
    mv "$bak" "$dest"
    moved=$((moved + 1))
  done
  [ "$moved" -eq 0 ] || info "moved $moved stray .bak file(s) into $BACKUP_ROOT/legacy/"
}

PROBE_TOOL=""

probe_init() {
  if command -v curl >/dev/null 2>&1; then
    PROBE_TOOL="curl"
  elif command -v wget >/dev/null 2>&1; then
    PROBE_TOOL="wget"
  else
    c_warn "neither curl nor wget is installed — skipping the mirror availability checks"
  fi
}

# probe_url <url> — true when the URL exists. Always true if neither curl nor wget
# is installed, so a missing tool never silently drops repository lines.
probe_url() {
  case "$PROBE_TOOL" in
    curl) curl -fsIL --max-time 10 -o /dev/null "$1" ;;
    wget) wget -q --spider --timeout=10 "$1" ;;
    *)    return 0 ;;
  esac
}

# suite_available <base-url> <suite>
# debmirror writes Release; a full rsync mirror also writes InRelease. Accept either.
suite_available() {
  probe_url "$1/dists/$2/InRelease" || probe_url "$1/dists/$2/Release"
}

# require_suite <base-url> <suite> — the archive is unusable without it, so stop
# before anything on disk is touched.
require_suite() {
  if ! suite_available "$1" "$2"; then
    c_err "The mirror has no usable '$2' suite under $1/"
    c_err "Nothing was changed. The archive is likely mid-sync or broken — try again later."
    exit 1
  fi
}

# skip_notice <suite> — an optional suite is missing; leave its line out.
skip_notice() {
  c_warn "$1 is not available on the mirror right now — leaving that line out" >&2
}

rollback() {
  require_root
  migrate_legacy_backups

  local restored=0 removed=0 snap="" dir state path bak target

  # Snapshot directories are named after a sortable timestamp, so the glob's last
  # match is the most recent run.
  for dir in "$BACKUP_ROOT"/*; do
    [ -f "$dir/manifest" ] && snap="$dir"
  done

  if [ -n "$snap" ]; then
    info "rolling back the run of $(basename "$snap")"
    while IFS="$(printf '\t')" read -r state path; do
      [ -n "$path" ] || continue
      case "$state" in
        modified)
          [ -e "$snap$path" ] || continue
          cp -a "$snap$path" "$path"
          c_ok "restored $path"
          restored=$((restored + 1))
          ;;
        created)
          [ -e "$path" ] || continue
          rm -f "$path"
          c_ok "removed $path"
          removed=$((removed + 1))
          ;;
      esac
    done < "$snap/manifest"
  else
    # Nothing from this version of the script — fall back to the migrated .bak files.
    info "no snapshot found; restoring from the newest legacy .bak.* instead"
    for target in /etc/apt/sources.list \
                  /etc/apt/sources.list.d/*.sources \
                  /etc/apt/sources.list.d/*.list \
                  /etc/yum.repos.d/*.repo; do
      [ -e "$target" ] || continue
      bak="$(ls -1t "$BACKUP_ROOT/legacy$target".bak.* 2>/dev/null | head -n1 || true)"
      [ -n "$bak" ] || continue
      cp -a "$bak" "$target"
      c_ok "restored $target from $(basename "$bak")"
      restored=$((restored + 1))
    done
  fi

  if [ "$restored" -eq 0 ] && [ "$removed" -eq 0 ]; then
    c_warn "no backups found — nothing to roll back"
  else
    c_ok "restored $restored file(s), removed $removed file(s)."
    echo "    Run 'apt-get update' or 'dnf makecache' to refresh."
  fi
  exit 0
}

detect_os() {
  local os_release="${OS_RELEASE_FILE:-/etc/os-release}"
  if [ ! -r "$os_release" ]; then
    c_err "$os_release not found — unsupported system."
    exit 1
  fi
  # shellcheck disable=SC1091
  . "$os_release"
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  CODENAME="${VERSION_CODENAME:-}"
  VERSION_MAJOR="${VERSION_ID%%.*}"
}

is_proxmox() {
  [ -e /etc/apt/sources.list.d/pve-enterprise.list ] && return 0
  [ -e /usr/bin/pveversion ] && return 0
  return 1
}

is_pbs() {
  [ -e /etc/apt/sources.list.d/pbs-enterprise.list ] && return 0
  [ -e /usr/sbin/proxmox-backup-manager ] && return 0
  return 1
}

setup_ubuntu() {
  case "$CODENAME" in
    jammy|noble|resolute) ;;
    *)
      c_err "Ubuntu '$CODENAME' is not mirrored. Only jammy (22.04), noble (24.04) and resolute (26.04) are available."
      c_err "Installer images for newer releases are at $MIRROR/ubuntu-releases/"
      exit 1
      ;;
  esac

  if command -v dpkg >/dev/null 2>&1 && [ "$(dpkg --print-architecture)" != "amd64" ]; then
    c_err "The Ubuntu mirror carries amd64 only; this host is $(dpkg --print-architecture)."
    exit 1
  fi

  info "configuring Ubuntu $CODENAME (amd64)"
  local comps="main restricted universe multiverse" suffix
  require_suite "$MIRROR/ubuntu" "$CODENAME"

  {
    echo "# ParsDev Mirror — $MIRROR/ubuntu/"
    echo "# generated by setup.sh on $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "deb $MIRROR/ubuntu/ $CODENAME $comps"
    for suffix in updates security backports; do
      if suite_available "$MIRROR/ubuntu" "$CODENAME-$suffix"; then
        echo "deb $MIRROR/ubuntu/ $CODENAME-$suffix $comps"
      else
        skip_notice "$CODENAME-$suffix"
      fi
    done
  } | write_file /etc/apt/sources.list

  # Ubuntu 24.04+ ships a deb822 file that would shadow sources.list; neutralise it.
  if [ -e /etc/apt/sources.list.d/ubuntu.sources ]; then
    backup_only /etc/apt/sources.list.d/ubuntu.sources
    [ "$DRY_RUN" -eq 1 ] || : > /etc/apt/sources.list.d/ubuntu.sources
  fi

  refresh_apt
}

setup_debian() {
  # Each release lives in its own tree on the mirror — debmirror syncs them separately.
  # bullseye predates the non-free-firmware split and is mirrored without it.
  local rel_dir sec_dir comps
  case "$CODENAME" in
    bullseye) rel_dir="debian-11"; sec_dir="debian-11-security"; comps="main contrib non-free" ;;
    bookworm) rel_dir="debian-12"; sec_dir="debian-12-security"; comps="main contrib non-free non-free-firmware" ;;
    trixie)   rel_dir="debian-13"; sec_dir="debian-13-security"; comps="main contrib non-free non-free-firmware" ;;
    *)
      c_err "Debian '${CODENAME:-unknown}' is not mirrored. Available: bullseye (11), bookworm (12), trixie (13)."
      exit 1
      ;;
  esac

  info "configuring Debian $CODENAME"
  require_suite "$MIRROR/debian/$rel_dir" "$CODENAME"

  # backports is deliberately absent: the mirror syncs <codename> and <codename>-updates only.
  {
    echo "# ParsDev Mirror — $MIRROR/debian/$rel_dir/"
    echo "# generated by setup.sh on $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "deb $MIRROR/debian/$rel_dir/ $CODENAME $comps"
    if suite_available "$MIRROR/debian/$rel_dir" "$CODENAME-updates"; then
      echo "deb $MIRROR/debian/$rel_dir/ $CODENAME-updates $comps"
    else
      skip_notice "$CODENAME-updates"
    fi
    if suite_available "$MIRROR/debian/$sec_dir" "$CODENAME-security"; then
      echo "deb $MIRROR/debian/$sec_dir/ $CODENAME-security $comps"
    else
      skip_notice "$CODENAME-security"
    fi
  } | write_file /etc/apt/sources.list

  if [ -e /etc/apt/sources.list.d/debian.sources ]; then
    backup_only /etc/apt/sources.list.d/debian.sources
    [ "$DRY_RUN" -eq 1 ] || : > /etc/apt/sources.list.d/debian.sources
  fi

  refresh_apt
}

setup_proxmox() {
  local pve_suite="$CODENAME"
  case "$pve_suite" in
    bookworm|trixie) ;;
    *) pve_suite="stable" ;;
  esac

  info "configuring Proxmox repositories ($pve_suite)"

  # Check the mirror before disabling anything, so a bad mirror never leaves the
  # host with its enterprise repositories off and no replacement.
  local pve_ok=0 pbs_ok=0
  if is_proxmox && suite_available "$MIRROR/proxmox" "$pve_suite"; then pve_ok=1; fi
  if is_pbs && suite_available "$MIRROR/proxmox/pbs" "$pve_suite"; then pbs_ok=1; fi

  if [ "$pve_ok" -eq 0 ] && [ "$pbs_ok" -eq 0 ]; then
    c_warn "the Proxmox mirror has no '$pve_suite' suite — leaving the Proxmox repositories untouched"
    return 0
  fi

  for ent in /etc/apt/sources.list.d/pve-enterprise.list \
             /etc/apt/sources.list.d/pbs-enterprise.list \
             /etc/apt/sources.list.d/ceph.list; do
    [ -e "$ent" ] || continue
    backup_only "$ent"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[dry-run] would comment out every line in $ent"
    else
      sed -i 's/^\([^#]\)/# \1/' "$ent"
      c_ok "disabled $ent"
    fi
  done

  if [ "$pve_ok" -eq 1 ]; then
    write_file /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
# ParsDev Mirror — Proxmox VE (no-subscription)
deb $MIRROR/proxmox/ $pve_suite pve-no-subscription
EOF
  elif is_proxmox; then
    c_warn "the Proxmox VE mirror has no '$pve_suite' suite — no pve-no-subscription list written"
  fi

  if [ "$pbs_ok" -eq 1 ]; then
    write_file /etc/apt/sources.list.d/pbs-no-subscription.list <<EOF
# ParsDev Mirror — Proxmox Backup Server (no-subscription)
deb $MIRROR/proxmox/pbs/ $pve_suite pbs-no-subscription
EOF
  elif is_pbs; then
    c_warn "the Backup Server mirror has no '$pve_suite' suite — no pbs-no-subscription list written"
  fi
}

setup_almalinux() {
  local rel="$VERSION_MAJOR" crb_id crb_dir
  case "$rel" in
    8)    crb_id="powertools"; crb_dir="PowerTools" ;;
    9|10) crb_id="crb";        crb_dir="CRB" ;;
    *)
      c_err "AlmaLinux $rel is not mirrored. Available: 8, 9, 10."
      exit 1
      ;;
  esac

  info "configuring AlmaLinux $rel"

  local arch
  arch="$(uname -m)"
  if ! probe_url "$MIRROR/Almalinux/$rel/BaseOS/$arch/os/repodata/repomd.xml"; then
    c_err "The mirror has no AlmaLinux $rel BaseOS repository for $arch."
    c_err "Nothing was changed. Browse $MIRROR/Almalinux/ to see what is available."
    exit 1
  fi

  # Point the stock repo files at the mirror instead of the mirrorlist.
  local f
  for f in /etc/yum.repos.d/almalinux*.repo; do
    [ -e "$f" ] || continue
    backup_only "$f"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[dry-run] would rewrite mirrorlist/baseurl in $f"
      continue
    fi
    sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
           -e "s|^#\\?baseurl=https\\?://repo\\.almalinux\\.org/almalinux|baseurl=$MIRROR/Almalinux|g" \
           "$f"
    c_ok "rewrote $f"
  done

  # Explicit fallback repo file, in case the stock files are missing or named differently.
  write_file /etc/yum.repos.d/parsdev.repo <<EOF
# ParsDev Mirror — AlmaLinux $rel
[parsdev-baseos]
name=AlmaLinux \$releasever - BaseOS (ParsDev Mirror)
baseurl=$MIRROR/Almalinux/\$releasever/BaseOS/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=$MIRROR/Almalinux/RPM-GPG-KEY-AlmaLinux-$rel

[parsdev-appstream]
name=AlmaLinux \$releasever - AppStream (ParsDev Mirror)
baseurl=$MIRROR/Almalinux/\$releasever/AppStream/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=$MIRROR/Almalinux/RPM-GPG-KEY-AlmaLinux-$rel

[parsdev-$crb_id]
name=AlmaLinux \$releasever - $crb_dir (ParsDev Mirror)
baseurl=$MIRROR/Almalinux/\$releasever/$crb_dir/\$basearch/os/
enabled=0
gpgcheck=1
gpgkey=$MIRROR/Almalinux/RPM-GPG-KEY-AlmaLinux-$rel

[parsdev-extras]
name=AlmaLinux \$releasever - Extras (ParsDev Mirror)
baseurl=$MIRROR/Almalinux/\$releasever/extras/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=$MIRROR/Almalinux/RPM-GPG-KEY-AlmaLinux-$rel
EOF

  refresh_dnf
}

refresh_apt() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] would run: apt-get update"
    return 0
  fi
  info "running apt-get update"
  apt-get update
}

refresh_dnf() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[dry-run] would run: dnf clean all && dnf makecache"
    return 0
  fi
  info "refreshing dnf metadata"
  dnf clean all >/dev/null
  dnf makecache
}

main() {
  [ "$ROLLBACK" -eq 1 ] && rollback
  [ "$DRY_RUN" -eq 1 ] || require_root

  probe_init
  [ "$DRY_RUN" -eq 1 ] || migrate_legacy_backups
  detect_os
  info "detected: ${PRETTY_NAME:-$OS_ID} (id=$OS_ID codename=${CODENAME:-n/a})"

  case "$OS_ID" in
    ubuntu)
      setup_ubuntu
      ;;
    debian)
      setup_debian
      if is_proxmox || is_pbs; then
        setup_proxmox
        refresh_apt
      fi
      ;;
    almalinux|rocky|rhel|centos)
      [ "$OS_ID" = "almalinux" ] || c_warn "$OS_ID is not AlmaLinux; the AlmaLinux repos are binary-compatible but unofficial for this OS."
      setup_almalinux
      ;;
    *)
      case "$OS_LIKE" in
        *debian*) setup_debian ;;
        *rhel*|*fedora*) setup_almalinux ;;
        *)
          c_err "Unsupported distribution: $OS_ID"
          c_err "Mirrored: Ubuntu (jammy, noble, resolute), Debian (bullseye, bookworm, trixie), AlmaLinux (8, 9, 10), Proxmox VE/PBS."
          exit 1
          ;;
      esac
      ;;
  esac

  echo
  if [ "$DRY_RUN" -eq 1 ]; then
    c_ok "Dry run complete — nothing was modified."
  else
    c_ok "Done. This host now pulls packages from $MIRROR"
    # Read the manifest rather than a shell variable: write_file often runs inside a
    # pipeline, so anything it appended to an array would be lost with the subshell.
    if [ -f "$SNAPSHOT/manifest" ]; then
      while IFS="$(printf '\t')" read -r state path; do
        [ -n "$path" ] && printf '    %-8s %s\n' "$state" "$path"
      done < "$SNAPSHOT/manifest"
      echo "    Backup:  $SNAPSHOT"
    fi
    echo "    Undo with: bash $0 --rollback"
  fi
}

main "$@"
