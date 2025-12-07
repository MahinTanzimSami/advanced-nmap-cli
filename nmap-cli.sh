#!/usr/bin/env bash
# nmap-cli.sh — Nmap Helper CLI (interactive + non-interactive + NSE pattern + NSE debug + Telegram + fzf NSE search)
# Version: 1.4
# Author: Samir Ahamad Khan
# NOTE: Use only on systems you own or have explicit written permission to test.

set -euo pipefail

VERSION="1.0"
DEFAULT_OUTDIR="./scans"
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

timestamp() { date +"$TIMESTAMP_FORMAT"; }
echoinfo(){ echo -e "\e[1;34m[INFO]\e[0m $*"; }
echoerr(){ echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; }
echowarn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echoerr "Required command '$1' not found. Please install it."
    exit 2
  fi
}

check_deps() {
  require_cmd nmap
  require_cmd date
  require_cmd mkdir
  require_cmd grep
  # fzf optional but required for fuzzy UI feature
  if ! command -v fzf >/dev/null 2>&1; then
    echowarn "fzf not found — fuzzy NSE search disabled. Install 'fzf' for extra UI (see docs)."
  fi
}

print_disclaimer() {
  cat <<EOF
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
IMPORTANT: Use this tool only on systems you own or have explicit,
written permission to test. Unauthorized scanning is illegal.
Author is not responsible for misuse.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
}

make_outdir() {
  local dir="$1"
  mkdir -p "$dir"
  echo "$dir"
}

make_filebase() {
  local outdir="$1"
  local target="$2"
  local tag="$3"
  local ts; ts="$(timestamp)"
  local clean="${target//\//_}"
  echo "${outdir}/${clean}_${tag}_${ts}"
}

save_and_run_nmap() {
  local cmd="$1"
  local filebase="$2"
  echoinfo "Executing: $cmd"
  eval "${cmd} -oN ${filebase}.nmap -oX ${filebase}.xml -oG ${filebase}.gnmap"
  echoinfo "Saved: ${filebase}.nmap, .xml, .gnmap"
  echo "${filebase}.nmap"
}

telegram_notify() {
  local msg="$1"
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echowarn "Telegram token/chat not set; skipping notification."
    return 0
  fi
  local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
  curl -s -X POST "${url}" -d chat_id="${TELEGRAM_CHAT_ID}" -d text="$msg" >/dev/null || echowarn "Telegram notify failed"
}

nse_debug() {
  local target="$1"; local script="$2"
  local outdir; outdir="$(make_outdir "${DEFAULT_OUTDIR}/nse_debug")"
  local base; base="$(make_filebase "$outdir" "$target" "nse_${script}")"
  echoinfo "Running NSE debug for script: $script on $target"
  echoinfo "Updating NSE DB (may require sudo)..."
  if command -v sudo >/dev/null 2>&1; then sudo nmap --script-updatedb >/dev/null 2>&1 || true; else nmap --script-updatedb >/dev/null 2>&1 || true; fi
  echoinfo "Minimal run..."
  eval "nmap -p 80,443 --script ${script} ${target} -oN ${base}_simple.nmap" || echowarn "Minimal run returned non-zero"
  echoinfo "Trace run (verbose)..."
  if command -v sudo >/dev/null 2>&1; then
    sudo nmap -p 80,443 --script "${script}" "${target}" -d --script-trace -oN "${base}_trace.nmap" 2> "${base}_trace.log" || echowarn "Trace run finished with warnings/errors"
  else
    nmap -p 80,443 --script "${script}" "${target}" -d --script-trace -oN "${base}_trace.nmap" 2> "${base}_trace.log" || echowarn "Trace run finished with warnings/errors"
  fi
  echoinfo "Saved NSE debug outputs to ${outdir}"
  telegram_notify "NSE debug completed for ${target} ${script}. Files: ${base}_*.nmap"
}

run_nse_pattern() {
  local target="$1"
  local pattern="$2"
  local portlist="$3"
  local script_args="$4"
  local outdir="$5"
  [[ -z "$pattern" ]] && { echoerr "Script pattern required"; exit 2; }
  local cmd="nmap --script \"${pattern}\""
  if [[ -n "$script_args" ]]; then cmd+=" --script-args '${script_args}'"; fi
  [[ -n "$portlist" ]] && cmd+=" -p ${portlist}"
  cmd+=" ${target}"
  local base; base="$(make_filebase "$outdir" "$target" "nsepattern")"
  save_and_run_nmap "$cmd" "$base"
  telegram_notify "NSE pattern scan completed for ${target} pattern='${pattern}' ports='${portlist:-all}'"
}

# Simple heuristic to warn on potentially intrusive/dangerous scripts
is_intrusive_scriptname() {
  local name="$1"
  # if name contains keywords often associated with intrusive scripts
  local kws="vuln|exploit|brute|fuzz|dos|overflow|slowloris|flood|rce|sqlinject|ddos"
  if echo "$name" | grep -Eiq "$kws"; then
    return 0
  fi
  return 1
}

#########################################
# ✅ fzf-based NSE search UI (new)
#########################################
search_nse_scripts_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echoerr "fzf not installed. Install it first (sudo apt install fzf) or use normal search."
    return
  fi

  echo -e "\n--- NSE Script Fuzzy Finder (fzf) ---"
  echo "Type keywords to fuzzy-search NSE scripts. Use Tab to multi-select. Press Enter to confirm."
  # Build list: filename and first line summary (if available)
  scripts_dir="/usr/share/nmap/scripts"
  if [[ ! -d "$scripts_dir" ]]; then
    echoerr "Nmap scripts directory not found at $scripts_dir"
    return
  fi

  # prepare list: "scriptname<TAB>short description"
  tmpfile="$(mktemp)"
  for s in "$scripts_dir"/*.nse; do
    name="$(basename "$s")"
    # try to extract a one-line description from the script header (comment lines)
    desc="$(grep -m1 -E '^--' "$s" | sed 's/^--\s*//; s/\r$//' || true)"
    if [[ -z "$desc" ]]; then
      desc="$(grep -m1 -E '^--' "$s" | sed 's/^--//; s/\r$//' || true)"
    fi
    printf "%s\t%s\n" "$name" "${desc:-No description}" >> "$tmpfile"
  done

  # launch fzf for multi-select
  selected_raw=$(cat "$tmpfile" | fzf --multi --header="Select NSE scripts (multi): TAB select, Enter confirm" --ansi)
  rm -f "$tmpfile"
  if [[ -z "$selected_raw" ]]; then
    echowarn "No script selected."
    return
  fi

  # parse selected names (first column)
  selected_names=()
  while IFS=$'\t' read -r fname rest; do
    selected_names+=("$fname")
  done <<< "$selected_raw"

  echo -e "\nSelected scripts:"
  for s in "${selected_names[@]}"; do echo " - $s"; done

  # Check for intrusive heuristics
  for s in "${selected_names[@]}"; do
    if is_intrusive_scriptname "$s"; then
      echowarn "Script '$s' looks potentially intrusive. You must have explicit permission to run it."
      read -rp "Do you want to continue and run it? (yes/NO): " confirm
      if [[ "$confirm" != "yes" ]]; then
        echoinfo "Skipping '$s' as user chose not to run intrusive scripts."
        # remove from list
        newlist=()
        for q in "${selected_names[@]}"; do [[ "$q" != "$s" ]] && newlist+=("$q"); done
        selected_names=("${newlist[@]}")
      fi
    fi
  done

  if [[ "${#selected_names[@]}" -eq 0 ]]; then
    echowarn "No scripts left to run after filtering."
    return
  fi

  # Build comma-separated script list
  IFS=,; scripts_csv="${selected_names[*]}"; unset IFS

  read -rp "Target: " target
  read -rp "Ports (comma or blank): " ports
  read -rp "Optional --script-args (key=val,key2=val): " sargs

  outdir="$(make_outdir "${DEFAULT_OUTDIR}/nse_search")"
  base="$(make_filebase "$outdir" "$target" "nse_fzf")"

  cmd="nmap --script \"$scripts_csv\""
  [[ -n "$sargs" ]] && cmd+=" --script-args '${sargs}'"
  [[ -n "$ports" ]] && cmd+=" -p ${ports}"
  cmd+=" ${target}"

  echoinfo "Running: $cmd"
  # save outputs
  eval "${cmd} -oN ${base}.nmap -oX ${base}.xml -oG ${base}.gnmap"
  echoinfo "Results saved in $outdir"
  telegram_notify "FZF NSE scan completed for ${target}. Files in ${outdir}"
}

#########################################

run_mode() {
  local mode="$1"; local target="$2"; local port="$3"; local outdir="$4"; local save="$5"; local extra="$6"
  case "$mode" in
    ping) cmd="nmap -sn ${target}" ;;
    quick) cmd="nmap -Pn -T4 -sV --top-ports 100 ${target}" ;;
    full) cmd="sudo nmap -Pn -sS -p- ${target}" ;;
    svc) cmd="nmap -Pn -sV ${target}" ;;
    os) cmd="sudo nmap -Pn -O ${target}" ;;
    aggressive) cmd="sudo nmap -Pn -A ${target}" ;;
    port) [[ -z "$port" ]] && { echoerr "Port required for mode=port"; exit 2; }; cmd="nmap -Pn -p ${port} ${target}" ;;
    nse) IFS='|' read -r pattern ports script_args <<< "$extra"; run_nse_pattern "$target" "$pattern" "$ports" "$script_args" "$outdir"; return 0 ;;
    *) echoerr "Unknown mode: $mode"; exit 2 ;;
  esac

  if [[ "$save" -eq 1 && "${mode}" != "nse" ]]; then
    base="$(make_filebase "$outdir" "$target" "$mode")"
    save_and_run_nmap "$cmd" "$base"
    telegram_notify "Scan completed: ${target} (${mode}). Outputs in ${outdir}"
  else
    echoinfo "Running (not saved): $cmd"
    eval "$cmd"
  fi
}

interactive_menu() {
  print_disclaimer
  echo "======================================="
  echo "        NMAP HELPER CLI v${VERSION}"
  echo "======================================="
  echo " 1) Ping Scan"
  echo " 2) Quick Scan"
  echo " 3) Full Port Scan"
  echo " 4) Service & Version Detection"
  echo " 5) OS Detection"
  echo " 6) Aggressive Scan"
  echo " 7) Scan Specific Port"
  echo " 8) Run NSE scripts (pattern/list)"
  echo " 9) NSE Debug"
  echo "10) Exit"
  echo "11) Search NSE Scripts & Run (fzf fuzzy search)"  # updated to fzf
  echo "---------------------------------------"
  read -rp "Select Option (1-11): " choice
  read -rp "Enter Target IP/domain (leave blank for options that ask later): " target
  outdir="$(make_outdir "${DEFAULT_OUTDIR}")"

  case "$choice" in
    1) run_mode "ping" "$target" "" "$outdir" 1 "" ;;
    2) run_mode "quick" "$target" "" "$outdir" 1 "" ;;
    3) run_mode "full" "$target" "" "$outdir" 1 "" ;;
    4) run_mode "svc" "$target" "" "$outdir" 1 "" ;;
    5) run_mode "os" "$target" "" "$outdir" 1 "" ;;
    6) run_mode "aggressive" "$target" "" "$outdir" 1 "" ;;
    7) read -rp "Port: " p; run_mode "port" "$target" "$p" "$outdir" 1 "" ;;
    8) read -rp "Pattern: " pattern; read -rp "Ports: " ports; read -rp "Args: " sargs; extra="${pattern}|${ports}|${sargs}"; run_mode "nse" "$target" "" "$outdir" 1 "$extra" ;;
    9) read -rp "NSE Script: " script; nse_debug "${target:-}" "$script" ;;
    10) echo "Bye"; exit 0 ;;
    11) search_nse_scripts_fzf ;;   # fzf-based search
    *) echoerr "Invalid choice"; exit 2 ;;
  esac
}

print_usage() {
  cat <<EOF
Usage:
Interactive: ./nmap-cli.sh
Non-interactive: ./nmap-cli.sh -n -t target -m mode ...
EOF
}

NONINT=0; TARGET=""; MODE=""; PORT=""; OUTDIR="$DEFAULT_OUTDIR"; SAVE=0; DO_DEBUG=0; INSTALL=0
NSE_PATTERN=""; NSE_SARGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) print_usage; exit 0 ;;
    -n) NONINT=1; shift ;;
    -t) TARGET="$2"; shift 2 ;;
    -m) MODE="$2"; shift 2 ;;
    -p) PORT="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    -s) SAVE=1; shift ;;
    -a) NSE_PATTERN="$2"; shift 2 ;;
    -A) NSE_SARGS="$2"; shift 2 ;;
    --debug) DO_DEBUG=1; TARGET="$2"; SCRIPT_ARG="$3"; shift 3 ;;
    --install) INSTALL=1; shift ;;
    --version) echo "$VERSION"; exit 0 ;;
    *) echoerr "Unknown arg: $1"; print_usage; exit 2 ;;
  esac
done

if [[ $INSTALL -eq 1 ]]; then
  echoinfo "Installing to /usr/local/bin/nmap-cli..."
  sudo cp "$0" /usr/local/bin/nmap-cli
  sudo chmod +x /usr/local/bin/nmap-cli
  echoinfo "Installed. Run 'nmap-cli'"
  exit 0
fi

check_deps

if [[ $DO_DEBUG -eq 1 ]]; then
  nse_debug "${TARGET:-}" "$SCRIPT_ARG"; exit 0
fi

if [[ $NONINT -eq 1 ]]; then
  outdir="$(make_outdir "$OUTDIR")"
  print_disclaimer
  [[ "$MODE" == "nse" ]] && extra="${NSE_PATTERN}|${PORT}|${NSE_SARGS}" && run_mode "nse" "$TARGET" "" "$outdir" 1 "$extra" && exit 0
  run_mode "$MODE" "$TARGET" "$PORT" "$outdir" 1 ""; exit 0
fi

interactive_menu

