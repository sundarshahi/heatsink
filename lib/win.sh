#!/usr/bin/env bash
# Windows (Git Bash / MSYS / Cygwin) backends for the signals that have no
# POSIX source there. Sourced by lib/signals.sh and lib/procs.sh; both guard
# against double-sourcing.
#
# Everything here shells out to powershell.exe exactly once per call and is
# validated on the way back in: if the output isn't the shape we expect we
# return nothing and the caller fails open, same as every other layer.
[ -n "${HS_WIN_SH:-}" ] && return 0
HS_WIN_SH=1

hs_is_windows() {
  case "${HS_UNAME:=$(uname -s 2>/dev/null || echo unknown)}" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) return 0 ;;
    *) return 1 ;;
  esac
}

# Runs the PowerShell script on stdin. -NoProfile keeps startup down; CRLF is
# stripped so the rest of the pipeline sees plain LF text.
#
# Via a temp .ps1 and -File, NOT `-Command -`: in stdin mode PowerShell treats a
# blank line as end-of-statement, so any script with a blank line inside a
# foreach/if block parses as incomplete and is discarded — silently, returning
# nothing at all. -File parses the script the way a .ps1 is meant to be parsed.
# -EncodedCommand also works but prefixes CLIXML noise once stderr is touched.
hs_ps1() {
  command -v powershell.exe >/dev/null 2>&1 || return 1
  local d f w rc
  d=$(mktemp -d 2>/dev/null) || return 1
  f="$d/s.ps1"                       # -File insists on the .ps1 extension
  cat > "$f"
  w=$(cygpath -w "$f" 2>/dev/null) || w="$f"
  powershell.exe -NoLogo -NoProfile -NonInteractive -File "$w" 2>/dev/null | tr -d '\r'
  rc=$?
  rm -rf "$d"
  return "$rc"
}

# Windows has no load average. The closest equivalent to the Unix run queue is
# ProcessorQueueLength (threads waiting) + the cores currently busy — which is
# what loadavg measures on Linux, minus the exponential decay.
#
# ponytail: instantaneous, not a 1-minute average. Noisier than /proc/loadavg
# on a bursty machine; sample-and-smooth in a daemon if that proves a problem.
hs_win_load() {
  hs_ps1 <<'PS1' | grep -Eo '[0-9]+\.[0-9]+' | tail -1
$ErrorActionPreference = 'SilentlyContinue'
$c = [int]$env:NUMBER_OF_PROCESSORS
if ($c -le 0) { $c = [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors }
if ($c -le 0) { $c = 1 }
$q = (Get-CimInstance Win32_PerfFormattedData_PerfOS_System).ProcessorQueueLength
if ($null -eq $q) { $q = 0 }
$u = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
if ($null -eq $u) { $u = 0 }
$v = [double]$q + ($c * [double]$u / 100)
# Invariant culture on purpose: a comma decimal separator would break awk.
[Console]::Out.Write($v.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture))
PS1
}

# Emits the same six columns as `ps -Ao pid,ppid,user,%cpu,etime,command` so
# lib/procs.sh needs no Windows branch at all. Two normalizations do the work:
#
#   ppid  — Windows has no reparent-to-init, so a process whose parent has
#           exited (or whose parent PID was recycled) is reported as ppid 1,
#           which is exactly what hs_orphans already looks for.
#   %cpu  — sampled over 300ms from the per-process CPU time counters, so it
#           means the same thing as ps's %cpu rather than a lifetime average.
#
# GetOwner is a per-process WMI call, so it only runs for rows that could
# actually be reaped (hot-and-old, or a known burner). Everything else reports
# "-", which never matches the invoking user and is therefore never reaped.
hs_win_ps() {
  hs_ps1 <<'PS1'
$ErrorActionPreference = 'SilentlyContinue'
$now = Get-Date
$first = @{}
foreach ($p in Get-CimInstance Win32_Process) {
  $first[[int]$p.ProcessId] = [double]$p.UserModeTime + [double]$p.KernelModeTime
}
Start-Sleep -Milliseconds 300
$procs = Get-CimInstance Win32_Process
$live = @{}
foreach ($p in $procs) { $live[[int]$p.ProcessId] = $p.CreationDate }
$inv = [Globalization.CultureInfo]::InvariantCulture
'  PID  PPID USER       %CPU ELAPSED COMMAND'
foreach ($p in $procs) {
  $id = [int]$p.ProcessId
  $t2 = [double]$p.UserModeTime + [double]$p.KernelModeTime
  $t1 = $first[$id]
  if ($null -eq $t1) { $t1 = $t2 }
  # CPU times are in 100ns ticks; 300ms of one core is 3,000,000 of them.
  $pct = [math]::Round((($t2 - $t1) / 3000000.0) * 100, 1)
  if ($pct -lt 0) { $pct = 0 }

  $start = $p.CreationDate
  if ($start) { $el = $now - $start } else { $el = [timespan]::Zero }
  if ($el.Days -gt 0) {
    $etime = '{0}-{1:00}:{2:00}:{3:00}' -f $el.Days, $el.Hours, $el.Minutes, $el.Seconds
  } elseif ($el.Hours -gt 0) {
    $etime = '{0:00}:{1:00}:{2:00}' -f $el.Hours, $el.Minutes, $el.Seconds
  } else {
    $etime = '{0:00}:{1:00}' -f $el.Minutes, $el.Seconds
  }

  $ppid = [int]$p.ParentProcessId
  $pstart = $live[$ppid]
  if (-not $live.ContainsKey($ppid) -or ($pstart -and $start -and $pstart -gt $start)) { $ppid = 1 }

  $cmd = $p.CommandLine
  if (-not $cmd) { $cmd = $p.Name }
  $cmd = ($cmd -replace '[\r\n]+', ' ')

  $user = '-'
  $burner = $cmd -match '(^|[\\/])(yes|stress|stress-ng)(\.exe)?( |$)|dd if=/dev/zero|cat /dev/urandom'
  if ($burner -or ($pct -gt 90 -and $el.TotalHours -ge 1)) {
    $o = Invoke-CimMethod -InputObject $p -MethodName GetOwner
    if ($o -and $o.User) { $user = $o.User }
  }

  '{0} {1} {2} {3} {4} {5}' -f $id, $ppid, $user, $pct.ToString('0.0', $inv), $etime, $cmd
}
PS1
}

# taskkill instead of kill: MSYS signals only reach MSYS processes, and the
# burners we reap are native Windows ones. // survives MSYS path mangling.
hs_win_kill()  { local p; for p in "$@"; do taskkill //PID "$p" //T >/dev/null 2>&1; done; return 0; }
hs_win_kill9() { local p; for p in "$@"; do taskkill //F //PID "$p" //T >/dev/null 2>&1; done; return 0; }
# CSV so the PID is its own quoted field — the memory column also holds digits.
hs_win_alive() { tasklist //FI "PID eq $1" //NH //FO CSV 2>/dev/null | grep -q "\"$1\""; }
