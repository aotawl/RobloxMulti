# Roblox Multi Launcher (PowerShell, aucune installation requise)
# - Multi-instance : garde les objets "singleton" de Roblox ouverts
# - Comptes : tu te connectes une fois toi-même, la session est gardée
#   CHIFFRÉE avec Windows (DPAPI) et sert à lancer Roblox directement.
# Aucun mot de passe n'est stocké. Rien n'est envoyé ailleurs que sur roblox.com.

# ------------------------------------------------------------ démarrage invisible
# Si on a été lancé avec une fenêtre de terminal (le .bat, clic droit > Exécuter avec PowerShell,
# Terminal Windows sur Windows 11...), on se relance SANS aucune console puis on quitte.
function Start-SelfHidden {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true          # pas de console du tout (même avec Terminal Windows)
    $psi.EnvironmentVariables['RML_HIDDEN'] = '1'
    [void][System.Diagnostics.Process]::Start($psi)
}
if ($env:RML_HIDDEN -ne '1' -and $PSCommandPath) {
    try { Start-SelfHidden; exit } catch {}
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Web.Extensions
    Add-Type -AssemblyName System.Security
    Add-Type -AssemblyName Microsoft.VisualBasic
} catch {
    Write-Host "Erreur au chargement : $($_.Exception.Message)"
    Read-Host "Appuie sur Entrée pour fermer"
    exit
}
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Cache la console si jamais il en reste une, et donne à l'appli sa propre identité
# dans la barre des tâches (sinon Windows la range sous l'icône de PowerShell)
try {
    Add-Type -Namespace RML -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
'@
    [void][RML.Win]::SetCurrentProcessExplicitAppUserModelID('aotawl.RobloxMulti')
    $consoleHwnd = [RML.Win]::GetConsoleWindow()
    if ($consoleHwnd -ne [System.IntPtr]::Zero) { [void][RML.Win]::ShowWindow($consoleHwnd, 0) }
} catch {}

function Show-Msg($text, $title = 'Roblox Multi Launcher', $buttons = 'OK', $icon = 'Information') {
    return [System.Windows.Forms.MessageBox]::Show($text, $title, $buttons, $icon)
}
function Show-Error($err) {
    [void](Show-Msg "Erreur : $($err.Exception.Message)`r`n`r`nEnvoie ce message à Claude." 'Erreur' 'OK' 'Error')
}

trap { Show-Error $_; continue }

# ============================================================ mises à jour
# Version de CE fichier. Augmente-la à chaque fois que tu publies une mise à jour.
$AppVersion = '1.5.0'
# Ton dépôt GitHub (pseudo/nom-du-depot). Laisse vide pour désactiver les mises à jour.
$GitHubRepo   = 'aotawl/RobloxMulti'
$GitHubBranch = 'main'

$RobloxProc = 'RobloxPlayerBeta'
$DataDir    = Join-Path $env:APPDATA 'RobloxMulti'
$AccFile    = Join-Path $DataDir 'accounts.json'
$SetFile    = Join-Path $DataDir 'settings.json'
$script:handles  = @()
$script:accounts = @()
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = [int]::MaxValue

# ============================================================ multi-instance
function Test-Active { return ($script:handles.Count -gt 0) }

function Disable-Multi {
    foreach ($h in $script:handles) {
        try { if ($h -is [System.Threading.Mutex]) { $h.ReleaseMutex() } } catch {}
        try { $h.Dispose() } catch {}
    }
    $script:handles = @()
}

function Enable-Multi {
    Disable-Multi
    $list = @()
    # Si les objets existent déjà, on garde quand même une poignée dessus :
    # c'est souvent Roblox Studio qui les a créés, et ça ne gêne pas.
    try {
        $new = $false
        $list += New-Object System.Threading.Mutex($true, 'ROBLOX_singletonMutex', [ref]$new)
    } catch {}
    try {
        $new = $false
        $list += New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, 'ROBLOX_singletonEvent', [ref]$new)
    } catch {}
    if ((Get-RobloxCount) -gt 0) {
        # Un vrai Roblox (le jeu) tourne : il faut le fermer d'abord
        foreach ($h in $list) { try { if ($h -is [System.Threading.Mutex]) { $h.ReleaseMutex() } } catch {}; $h.Dispose() }
        return "Un Roblox (le jeu) est déjà ouvert. Ferme-le puis réessaie.`r`n(Roblox Studio peut rester ouvert.)"
    }
    if ($list.Count -eq 0) { return "Impossible de créer les objets Windows." }
    $script:handles = $list
    return $null
}

# Ne compte QUE le jeu (RobloxPlayerBeta), jamais Roblox Studio
function Get-RobloxCount { return @(Get-Process -Name $RobloxProc -ErrorAction SilentlyContinue).Count }
function Test-StudioOpen { return (@(Get-Process -Name 'RobloxStudioBeta' -ErrorAction SilentlyContinue).Count -gt 0) }
function Get-CountText {
    $t = "Roblox (jeu) ouverts : $(Get-RobloxCount)"
    if (Test-StudioOpen) { $t += "   |   Studio ouvert (pas gênant)" }
    return $t
}
function Stop-AllRoblox  { Get-Process -Name $RobloxProc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

# ============================================================ stockage chiffré
function Protect-Text($t) {
    return (ConvertTo-SecureString $t -AsPlainText -Force | ConvertFrom-SecureString)
}
function Unprotect-Text($t) {
    $s = ConvertTo-SecureString $t
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Load-Accounts {
    $script:accounts = @()
    if (Test-Path -LiteralPath $AccFile) {
        try {
            $data = Get-Content -LiteralPath $AccFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:accounts = @($data | Where-Object { $_ -and $_.Cookie })
        } catch { $script:accounts = @() }
    }
}
function Save-Accounts {
    if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    ConvertTo-Json -InputObject @($script:accounts) -Depth 3 | Set-Content -LiteralPath $AccFile -Encoding UTF8
}
function Load-LastPlace {
    try { if (Test-Path -LiteralPath $SetFile) { return (Get-Content -LiteralPath $SetFile -Raw | ConvertFrom-Json).LastPlace } } catch {}
    return ''
}
function Save-LastPlace($v) {
    try {
        if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
        @{ LastPlace = $v } | ConvertTo-Json | Set-Content -LiteralPath $SetFile -Encoding UTF8
    } catch {}
}

# ------------------------------------------------------------ presets de jeux
$PresetFile = Join-Path $DataDir 'presets.json'
$script:presets = @()

function Get-DefaultPresets {
    return @(
        [pscustomobject]@{ Name = 'Anime Adventures';  PlaceId = '8304191830' },
        [pscustomobject]@{ Name = 'Grand Piece Online'; PlaceId = '1730877806' }
    )
}
function Load-Presets {
    $script:presets = @()
    if (Test-Path -LiteralPath $PresetFile) {
        try {
            $data = Get-Content -LiteralPath $PresetFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:presets = @($data | Where-Object { $_ -and $_.PlaceId })
            return
        } catch {}
    }
    $script:presets = Get-DefaultPresets
    Save-Presets
}
function Save-Presets {
    if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    ConvertTo-Json -InputObject @($script:presets) -Depth 3 | Set-Content -LiteralPath $PresetFile -Encoding UTF8
}
function Format-Preset($p) { return "$($p.Name)  ($($p.PlaceId))" }

# Récupère le nom d'un jeu depuis Roblox (pour pré-remplir le nom du preset)
function Get-GameName($placeId) {
    try {
        $u = Invoke-RestMethod -Uri "https://apis.roblox.com/universes/v1/places/$placeId/universe" -TimeoutSec 8 -UseBasicParsing
        if (-not $u.universeId) { return '' }
        $g = Invoke-RestMethod -Uri "https://games.roblox.com/v1/games?universeIds=$($u.universeId)" -TimeoutSec 8 -UseBasicParsing
        return "$($g.data[0].name)"
    } catch { return '' }
}

# ============================================================ requêtes Roblox
function Invoke-Rbx {
    param($Method, $Url, $Cookie, $Csrf)
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.Headers.Add('Cookie', ".ROBLOSECURITY=$Cookie")
    $req.Referer = 'https://www.roblox.com/'
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) RobloxMultiLauncher'
    $req.Accept = 'application/json'
    $req.Timeout = 15000
    if ($Csrf) { $req.Headers.Add('X-CSRF-TOKEN', $Csrf) }
    if ($Method -eq 'POST') { $req.ContentType = 'application/json'; $req.ContentLength = 0 }
    try { $resp = $req.GetResponse() }
    catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if (-not $resp) { throw }
    }
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $body = $sr.ReadToEnd(); $sr.Close()
    $out = [pscustomobject]@{ Status = [int]$resp.StatusCode; Headers = $resp.Headers; Body = $body }
    $resp.Close()
    return $out
}

function Get-AuthTicket($cookie) {
    $url = 'https://auth.roblox.com/v1/authentication-ticket'
    $r = Invoke-Rbx 'POST' $url $cookie $null
    $csrf = $r.Headers['x-csrf-token']
    if ($csrf) { $r = Invoke-Rbx 'POST' $url $cookie $csrf }
    return [pscustomobject]@{ Ticket = $r.Headers['rbx-authentication-ticket']; Status = $r.Status }
}

function Get-PlaceId($text) {
    $t = "$text".Trim()
    if ($t -match '^\d+$') { return $t }
    if ($t -match 'roblox\.com/(?:[a-z]{2}/)?games/(\d+)') { return $Matches[1] }
    if ($t -match '\((\d+)\)\s*$') { return $Matches[1] }   # preset "Nom  (id)"
    foreach ($p in $script:presets) { if ($p.Name -eq $t) { return "$($p.PlaceId)" } }
    return $null
}

function Start-Account($acc, $placeId) {
    $cookie = Unprotect-Text $acc.Cookie
    $t = Get-AuthTicket $cookie
    if (-not $t.Ticket) {
        if ($t.Status -eq 401) { return "La session de $($acc.Name) a expiré. Supprime ce compte et rajoute-le." }
        return "Impossible de lancer $($acc.Name) (code $($t.Status))."
    }
    $time    = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $tracker = "$(Get-Random -Minimum 100000 -Maximum 999999)$(Get-Random -Minimum 100000 -Maximum 999999)"
    $launcher = "https://www.roblox.com/Game/PlaceLauncher.ashx?request=RequestGame&browserTrackerId=$tracker&placeId=$placeId&isPlayTogetherGame=false&joinAttemptId=$([guid]::NewGuid())&joinAttemptOrigin=PlayButton"
    $uri = "roblox-player:1+launchmode:play+gameinfo:$($t.Ticket)+launchtime:$time" +
           "+placelauncherurl:$([Uri]::EscapeDataString($launcher))" +
           "+browsertrackerid:$tracker+robloxLocale:fr_fr+gameLocale:fr_fr+channel:+LaunchExp:InApp"
    Start-Process $uri
    return $null
}

# ============================================================ ajout de compte
$L = $env:LOCALAPPDATA; $PF = $env:ProgramFiles; $PF86 = ${env:ProgramFiles(x86)}

# Navigateur par défaut de Windows (celui qui ouvre les liens https)
function Get-DefaultBrowser {
    try {
        $progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId
        if (-not $progId) { return $null }
        $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command" -ErrorAction Stop).'(default)'
        if ($cmd -match '^\s*"([^"]+)"') { $exe = $Matches[1] }
        elseif ($cmd -match '^\s*(\S+\.exe)') { $exe = $Matches[1] }
        else { return $null }
        $exe = [Environment]::ExpandEnvironmentVariables($exe)
        if (-not (Test-Path -LiteralPath $exe)) { return $null }

        $file = [IO.Path]::GetFileName($exe).ToLower()
        # Opera passe souvent par launcher.exe
        if ($file -eq 'launcher.exe' -and $exe -match 'Opera') { $file = 'opera.exe' }
        $names = @{ 'msedge.exe' = 'Edge'; 'chrome.exe' = 'Chrome'; 'brave.exe' = 'Brave';
                    'opera.exe' = 'Opera'; 'vivaldi.exe' = 'Vivaldi'; 'chromium.exe' = 'Chromium' }
        if ($names.ContainsKey($file)) {
            return [pscustomobject]@{ Exe = $exe; Name = $names[$file]; Supported = $true }
        }
        $label = if ($file -eq 'firefox.exe') { 'Firefox' } else { [IO.Path]::GetFileNameWithoutExtension($exe) }
        return [pscustomobject]@{ Exe = $exe; Name = $label; Supported = $false }
    } catch { return $null }
}

# Navigateur à utiliser pour la connexion : le principal si possible, sinon Edge/Chrome
function Find-BrowserExe {
    $def = Get-DefaultBrowser
    if ($def -and $def.Supported) { return $def.Exe }

    foreach ($p in @("$PF86\Microsoft\Edge\Application\msedge.exe", "$PF\Microsoft\Edge\Application\msedge.exe",
                     "$PF\Google\Chrome\Application\chrome.exe", "$PF86\Google\Chrome\Application\chrome.exe",
                     "$L\Google\Chrome\Application\chrome.exe")) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            if ($def -and -not $def.Supported -and -not $script:warnedBrowser) {
                $script:warnedBrowser = $true
                [void](Show-Msg ("Ton navigateur principal ($($def.Name)) ne permet pas au launcher de récupérer la connexion.`r`n" +
                                 "J'ouvre la connexion dans $([IO.Path]::GetFileNameWithoutExtension($p)) à la place (juste pour te connecter).") 'Info')
            }
            return $p
        }
    }
    return $null
}

function Invoke-Cdp($wsUrl, $method) {
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ct = [System.Threading.CancellationToken]::None
    try {
        $ws.ConnectAsync([Uri]$wsUrl, $ct).Wait(5000) | Out-Null
        $msg = '{"id":1,"method":"' + $method + '","params":{}}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
        $ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(5000) | Out-Null
        $ms  = New-Object System.IO.MemoryStream
        $buf = New-Object byte[] 65536
        do {
            $task = $ws.ReceiveAsync([System.ArraySegment[byte]]::new($buf), $ct)
            if (-not $task.Wait(5000)) { break }
            $r = $task.Result
            $ms.Write($buf, 0, $r.Count)
        } while (-not $r.EndOfMessage)
        return [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    } finally { $ws.Dispose() }
}

function Get-CdpWs($port, $tries = 10) {
    for ($i = 0; $i -lt $tries; $i++) {
        try {
            $v = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/version" -TimeoutSec 2 -UseBasicParsing
            if ($v.webSocketDebuggerUrl) { return $v.webSocketDebuggerUrl }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Get-CookieFromBrowser($port) {
    try {
        $ws = Get-CdpWs $port
        if (-not $ws) { return $null }
        $res = $json.DeserializeObject((Invoke-Cdp $ws 'Storage.getCookies'))
        foreach ($c in $res['result']['cookies']) {
            if ($c['name'] -eq '.ROBLOSECURITY' -and $c['domain'] -like '*roblox.com') { return $c['value'] }
        }
    } catch {}
    return $null
}

function Add-Account {
    $exe = Find-BrowserExe
    if (-not $exe) { [void](Show-Msg "Aucun navigateur compatible trouvé. Installe Edge, Chrome, Brave ou Opera." 'Erreur' 'OK' 'Error'); return }

    $port = Get-Random -Minimum 9300 -Maximum 9400
    $tmp  = Join-Path $env:TEMP ('RobloxMulti_login_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $argList = @("--user-data-dir=`"$tmp`"", "--remote-debugging-port=$port", '--no-first-run',
                 '--no-default-browser-check', '--new-window', 'https://www.roblox.com/login')
    $proc = Start-Process -FilePath $exe -ArgumentList $argList -PassThru

    try {
        while ($true) {
            $r = Show-Msg ("Une fenêtre de connexion Roblox vient de s'ouvrir.`r`n`r`n" +
                           "1. Connecte-toi dedans (captcha, code, etc. comme d'habitude).`r`n" +
                           "2. Quand tu es sur la page d'accueil Roblox, reviens ici et clique OK.`r`n`r`n" +
                           "Annuler pour abandonner.") 'Ajouter un compte' 'OKCancel' 'Information'
            if ($r -ne 'OK') { return }

            $cookie = Get-CookieFromBrowser $port
            if (-not $cookie) {
                [void](Show-Msg "Je ne vois pas encore de connexion Roblox dans cette fenêtre. Termine la connexion puis clique OK." 'Pas encore connecté' 'OK' 'Warning')
                continue
            }
            $u = Invoke-Rbx 'GET' 'https://users.roblox.com/v1/users/authenticated' $cookie $null
            if ($u.Status -ne 200) {
                [void](Show-Msg "Roblox n'a pas validé la connexion (code $($u.Status)). Réessaie." 'Erreur' 'OK' 'Warning')
                continue
            }
            $info = $json.DeserializeObject($u.Body)
            $acc = [pscustomobject]@{
                Id          = "$($info['id'])"
                Name        = "$($info['name'])"
                DisplayName = "$($info['displayName'])"
                Cookie      = (Protect-Text $cookie)
            }
            $script:accounts = @($script:accounts | Where-Object { $_.Id -ne $acc.Id }) + $acc
            Save-Accounts
            Refresh-List
            [void](Show-Msg "Compte ajouté : $($acc.DisplayName) (@$($acc.Name))" 'OK')
            break
        }
    } finally {
        # Ferme la fenêtre de connexion et efface ses données
        try { $ws = Get-CdpWs $port 2; if ($ws) { Invoke-Cdp $ws 'Browser.close' | Out-Null } } catch {}
        try { if (-not $proc.HasExited) { $proc.Kill() } } catch {}
        Start-Sleep -Milliseconds 1500
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================ interface
# ============================================================ logo (icône .ico en base64)
$AppIconBase64 = @'
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
'@

$form = New-Object System.Windows.Forms.Form
$form.Text = "Roblox Multi Launcher  v$AppVersion"
$form.ClientSize = New-Object System.Drawing.Size(455, 540)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

# --- logo (intégré au script, comme ça les mises à jour l'amènent aussi)
$script:appIcon = $null
try {
    $icoBytes = [Convert]::FromBase64String(($AppIconBase64 -replace '\s', ''))
    $script:appIcon = New-Object System.Drawing.Icon((New-Object System.IO.MemoryStream(, $icoBytes)))
    $form.Icon = $script:appIcon
} catch {}

# --- icône dans la zone de notification (flèche ^ de la barre des tâches)
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = if ($script:appIcon) { $script:appIcon } else { [System.Drawing.SystemIcons]::Application }
$tray.Text = 'Roblox Multi Launcher'
$tray.Visible = $true

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen   = $trayMenu.Items.Add('Ouvrir le launcher')
$miOpen.Font = New-Object System.Drawing.Font($miOpen.Font, [System.Drawing.FontStyle]::Bold)
$miMulti  = New-Object System.Windows.Forms.ToolStripMenuItem('Multi-instance activé')
[void]$trayMenu.Items.Add($miMulti)
$miKill   = $trayMenu.Items.Add('Fermer tous les Roblox')
$miShort  = $trayMenu.Items.Add('Raccourcis (Bureau, menu Démarrer, barre des tâches)...')
[void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miQuit   = $trayMenu.Items.Add('Quitter')
$tray.ContextMenuStrip = $trayMenu
$script:balloonShown = $false

# --- multi-instance
$grpMulti = New-Object System.Windows.Forms.GroupBox
$grpMulti.Text = 'Multi-instance'
$grpMulti.SetBounds(12, 10, 430, 115)
$form.Controls.Add($grpMulti)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$lblStatus.SetBounds(15, 22, 300, 24)
$grpMulti.Controls.Add($lblStatus)

$lblCount = New-Object System.Windows.Forms.Label
$lblCount.SetBounds(15, 48, 300, 20)
$grpMulti.Controls.Add($lblCount)

$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.SetBounds(15, 74, 110, 30)
$grpMulti.Controls.Add($btnToggle)

$btnHide = New-Object System.Windows.Forms.Button
$btnHide.Text = 'Arrière-plan'
$btnHide.SetBounds(131, 74, 110, 30)
$grpMulti.Controls.Add($btnHide)

$btnKill = New-Object System.Windows.Forms.Button
$btnKill.Text = 'Fermer tous les Roblox'
$btnKill.SetBounds(247, 74, 168, 30)
$grpMulti.Controls.Add($btnKill)

# --- comptes
$grpAcc = New-Object System.Windows.Forms.GroupBox
$grpAcc.Text = 'Comptes'
$grpAcc.SetBounds(12, 135, 430, 300)
$form.Controls.Add($grpAcc)

$list = New-Object System.Windows.Forms.ListBox
$list.SetBounds(15, 24, 400, 150)
$list.IntegralHeight = $false
$list.SelectionMode = 'MultiExtended'
$grpAcc.Controls.Add($list)

$lblPlace = New-Object System.Windows.Forms.Label
$lblPlace.Text = 'Jeu : choisis un preset, ou colle un lien / ID'
$lblPlace.SetBounds(15, 182, 400, 18)
$grpAcc.Controls.Add($lblPlace)

# Liste déroulante modifiable : on peut choisir un preset OU taper un lien/ID
$cmbPlace = New-Object System.Windows.Forms.ComboBox
$cmbPlace.DropDownStyle = 'DropDown'
$cmbPlace.SetBounds(15, 203, 236, 24)
$grpAcc.Controls.Add($cmbPlace)

$btnSavePreset = New-Object System.Windows.Forms.Button
$btnSavePreset.Text = '+ Preset'
$btnSavePreset.SetBounds(257, 201, 78, 27)
$grpAcc.Controls.Add($btnSavePreset)

$btnDelPreset = New-Object System.Windows.Forms.Button
$btnDelPreset.Text = 'Retirer'
$btnDelPreset.SetBounds(340, 201, 75, 27)
$grpAcc.Controls.Add($btnDelPreset)

$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = 'Lancer'
$btnLaunch.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$btnLaunch.SetBounds(15, 252, 110, 32)
$grpAcc.Controls.Add($btnLaunch)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = 'Ajouter un compte'
$btnAdd.SetBounds(135, 252, 150, 32)
$grpAcc.Controls.Add($btnAdd)

$btnDel = New-Object System.Windows.Forms.Button
$btnDel.Text = 'Supprimer'
$btnDel.SetBounds(295, 252, 120, 32)
$grpAcc.Controls.Add($btnDel)

# --- aide
$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.ForeColor = [System.Drawing.Color]::Gray
$lblHelp.SetBounds(14, 443, 430, 70)
$lblHelp.Text = "1. Ajoute tes comptes une fois (tu te connectes toi-même).`r`n" +
                "2. Colle le lien du jeu, sélectionne un ou plusieurs comptes`r`n" +
                "    (Ctrl+clic), puis clique sur Lancer.`r`n" +
                "Laisse l'appli ouverte tant que tu joues."
$form.Controls.Add($lblHelp)

$lnkUpdate = New-Object System.Windows.Forms.LinkLabel
$lnkUpdate.Text = "v$AppVersion  -  Vérifier les mises à jour"
$lnkUpdate.SetBounds(14, 515, 280, 20)
$form.Controls.Add($lnkUpdate)

$lnkShort = New-Object System.Windows.Forms.LinkLabel
$lnkShort.Text = 'Raccourcis / épingler'
$lnkShort.TextAlign = 'TopRight'
$lnkShort.SetBounds(300, 515, 141, 20)
$form.Controls.Add($lnkShort)

# ============================================================ logique UI
function Update-Status {
    if (Test-Active) {
        $lblStatus.Text = [char]0x25CF + ' Multi-instance activé'
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(26, 155, 75)
        $btnToggle.Text = 'Désactiver'
    } else {
        $lblStatus.Text = [char]0x25CF + ' Multi-instance désactivé'
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(192, 57, 43)
        $btnToggle.Text = 'Activer'
    }
    $lblCount.Text = Get-CountText
}

function Invoke-Toggle {
    if (Test-Active) {
        Disable-Multi
    } else {
        if ((Get-RobloxCount) -gt 0) {
            $r = Show-Msg "Un Roblox (le jeu) est déjà lancé. Le fermer pour activer le multi-instance ?`r`n(Roblox Studio ne sera pas touché.)" 'Roblox ouvert' 'YesNo' 'Question'
            if ($r -ne 'Yes') { Update-Status; return }
            Stop-AllRoblox
            Start-Sleep -Milliseconds 1500
        }
        $err = Enable-Multi
        if ($err) { [void](Show-Msg $err 'Erreur' 'OK' 'Error') }
    }
    Update-Status
}

function Refresh-List {
    $list.Items.Clear()
    if ($script:accounts.Count -eq 0) {
        [void]$list.Items.Add('(aucun compte : clique sur "Ajouter un compte")')
    } else {
        foreach ($a in $script:accounts) { [void]$list.Items.Add("$($a.DisplayName)   (@$($a.Name))") }
    }
}

function Launch-Selected {
    if ($script:accounts.Count -eq 0) { [void](Show-Msg 'Ajoute d''abord un compte.'); return }
    $idx = @($list.SelectedIndices | ForEach-Object { $_ })
    if ($idx.Count -eq 0) { [void](Show-Msg 'Sélectionne au moins un compte (Ctrl+clic pour plusieurs).'); return }
    $placeId = Get-PlaceId $cmbPlace.Text
    if (-not $placeId) {
        [void](Show-Msg "Choisis un preset, ou colle le lien du jeu (ex : https://www.roblox.com/games/123456/...) ou juste son ID." 'Jeu' 'OK' 'Warning')
        return
    }
    Save-LastPlace $cmbPlace.Text.Trim()
    if (-not (Test-Active) -and $idx.Count -gt 1) {
        $r = Show-Msg "Le multi-instance est désactivé : un seul Roblox restera ouvert. Continuer ?" 'Attention' 'YesNo' 'Warning'
        if ($r -ne 'Yes') { return }
    }
    $form.Cursor = 'WaitCursor'
    try {
        $first = $true
        foreach ($i in $idx) {
            if (-not $first) {
                # petite pause entre deux lancements
                for ($s = 0; $s -lt 30; $s++) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
            }
            $first = $false
            $err = Start-Account $script:accounts[$i] $placeId
            if ($err) { [void](Show-Msg $err 'Erreur' 'OK' 'Warning') }
        }
    } finally { $form.Cursor = 'Default' }
}

function Remove-Selected {
    $idx = @($list.SelectedIndices | ForEach-Object { $_ })
    if ($script:accounts.Count -eq 0 -or $idx.Count -eq 0) { return }
    $names = ($idx | ForEach-Object { $script:accounts[$_].Name }) -join ', '
    $r = Show-Msg "Supprimer : $names ?" 'Supprimer' 'YesNo' 'Question'
    if ($r -ne 'Yes') { return }
    $keep = @()
    for ($i = 0; $i -lt $script:accounts.Count; $i++) { if ($idx -notcontains $i) { $keep += $script:accounts[$i] } }
    $script:accounts = $keep
    Save-Accounts
    Refresh-List
}

function Refresh-Presets($select) {
    $cmbPlace.Items.Clear()
    foreach ($p in $script:presets) { [void]$cmbPlace.Items.Add((Format-Preset $p)) }
    if ($select) { $cmbPlace.Text = $select }
}

function Add-Preset {
    $placeId = Get-PlaceId $cmbPlace.Text
    if (-not $placeId) {
        [void](Show-Msg "Colle d'abord le lien ou l'ID du jeu dans la case, puis clique sur + Preset." 'Preset' 'OK' 'Warning')
        return
    }
    $form.Cursor = 'WaitCursor'
    $guess = Get-GameName $placeId
    $form.Cursor = 'Default'
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Nom du preset pour le jeu $placeId :", 'Nouveau preset', $guess)
    $name = "$name".Trim()
    if (-not $name) { return }   # annulé
    $existing = $script:presets | Where-Object { "$($_.PlaceId)" -eq $placeId } | Select-Object -First 1
    if ($existing) {
        $existing.Name = $name
    } else {
        $script:presets = @($script:presets) + [pscustomobject]@{ Name = $name; PlaceId = $placeId }
    }
    Save-Presets
    $p = $script:presets | Where-Object { "$($_.PlaceId)" -eq $placeId } | Select-Object -First 1
    Refresh-Presets (Format-Preset $p)
}

function Remove-Preset {
    $placeId = Get-PlaceId $cmbPlace.Text
    $p = $script:presets | Where-Object { "$($_.PlaceId)" -eq "$placeId" } | Select-Object -First 1
    if (-not $p) { [void](Show-Msg "Choisis d'abord un preset dans la liste." 'Preset'); return }
    $r = Show-Msg "Retirer le preset `"$($p.Name)`" ?" 'Retirer' 'YesNo' 'Question'
    if ($r -ne 'Yes') { return }
    $script:presets = @($script:presets | Where-Object { "$($_.PlaceId)" -ne "$placeId" })
    Save-Presets
    Refresh-Presets ''
}

$btnSavePreset.Add_Click({ try { Add-Preset } catch { Show-Error $_ } })
$btnDelPreset.Add_Click({ try { Remove-Preset } catch { Show-Error $_ } })
$btnToggle.Add_Click({ try { Invoke-Toggle } catch { Show-Error $_ } })
$btnKill.Add_Click({
    try {
        $r = Show-Msg 'Fermer toutes les fenêtres Roblox ?' 'Confirmer' 'YesNo' 'Question'
        if ($r -eq 'Yes') { Stop-AllRoblox; Update-Status }
    } catch { Show-Error $_ }
})
$btnLaunch.Add_Click({ try { Launch-Selected } catch { Show-Error $_ } })
$list.Add_DoubleClick({ try { Launch-Selected } catch { Show-Error $_ } })
$btnAdd.Add_Click({ try { Add-Account } catch { Show-Error $_ } })
$btnDel.Add_Click({ try { Remove-Selected } catch { Show-Error $_ } })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ $lblCount.Text = Get-CountText })

# ------------------------------------------------------------ logique des mises à jour
$script:updating = $false

function Get-RawUrl($file) {
    return "https://raw.githubusercontent.com/$GitHubRepo/$GitHubBranch/$file"
}

function Get-RemoteText($url) {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add('User-Agent', 'RobloxMultiLauncher')
    $wc.Headers.Add('Cache-Control', 'no-cache')
    try { return $wc.DownloadString("$url`?t=$([DateTime]::UtcNow.Ticks)") } finally { $wc.Dispose() }
}

function Test-UpdateEnabled {
    return ($GitHubRepo -and $GitHubRepo -notmatch 'TON_PSEUDO' -and $GitHubRepo -match '^[\w.-]+/[\w.-]+$')
}

# $manual = $true quand on clique sur le lien (affiche aussi "déjà à jour" et les erreurs)
function Check-Update($manual) {
    if (-not (Test-UpdateEnabled)) {
        if ($manual) { [void](Show-Msg "Les mises à jour ne sont pas configurées (dépôt GitHub pas renseigné en haut du script)." 'Mises à jour') }
        return
    }
    $form.Cursor = 'WaitCursor'
    try {
        try { $txt = Get-RemoteText (Get-RawUrl 'version.txt') }
        catch {
            if ($manual) { [void](Show-Msg "Impossible de joindre GitHub : $($_.Exception.Message)" 'Mises à jour' 'OK' 'Warning') }
            return
        }
        $lines  = @($txt -split "`r?`n")
        $remote = $lines[0].Trim()
        $notes  = (($lines | Select-Object -Skip 1) -join "`r`n").Trim()
        $rv = $null; $lv = $null
        if (-not [version]::TryParse($remote, [ref]$rv) -or -not [version]::TryParse($AppVersion, [ref]$lv)) {
            if ($manual) { [void](Show-Msg "version.txt sur GitHub est invalide (1re ligne = numéro, ex : 1.2.0)." 'Mises à jour' 'OK' 'Warning') }
            return
        }
        if ($rv -le $lv) {
            if ($manual) { [void](Show-Msg "Tu as déjà la dernière version (v$AppVersion)." 'Mises à jour') }
            return
        }

        $msg = "Une mise à jour est disponible (v$remote)."
        $msg += "`r`n`r`nMettre à jour maintenant ?"
        if ((Show-Msg $msg 'Mise à jour' 'YesNo' 'Question') -ne 'Yes') { return }

        if ((Get-RobloxCount) -gt 0) {
            $r = Show-Msg "Des Roblox sont ouverts. Le launcher va redémarrer, ferme-les d'abord pour éviter qu'ils se coupent.`r`n`r`nContinuer quand même ?" 'Mise à jour' 'YesNo' 'Warning'
            if ($r -ne 'Yes') { return }
        }

        Install-Update $remote
    } finally { $form.Cursor = 'Default' }
}

function Install-Update($remote) {
    $self = $PSCommandPath
    if (-not $self -or -not (Test-Path -LiteralPath $self)) {
        [void](Show-Msg "Je ne trouve pas le fichier du launcher, mise à jour impossible." 'Erreur' 'OK' 'Error'); return
    }
    try { $code = Get-RemoteText (Get-RawUrl 'RobloxMulti.ps1') }
    catch { [void](Show-Msg "Téléchargement raté : $($_.Exception.Message)" 'Erreur' 'OK' 'Error'); return }

    # Sécurité : on vérifie que le fichier téléchargé est bien un script valide du launcher
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$errs)
    if ($errs -or $code -notmatch '\$AppVersion\s*=' -or $code -notmatch 'Roblox Multi Launcher') {
        [void](Show-Msg "Le fichier sur GitHub a l'air cassé, mise à jour annulée (ta version actuelle est gardée)." 'Erreur' 'OK' 'Error'); return
    }

    # Sauvegarde de l'ancienne version puis remplacement (UTF-8 avec BOM, fins de ligne Windows)
    try {
        Copy-Item -LiteralPath $self -Destination "$self.bak" -Force
        $code = ($code -replace "`r?`n", "`r`n")
        [System.IO.File]::WriteAllText($self, $code, (New-Object System.Text.UTF8Encoding($true)))
    } catch {
        [void](Show-Msg "Impossible d'écrire le fichier : $($_.Exception.Message)" 'Erreur' 'OK' 'Error'); return
    }

    [void](Show-Msg "Mis à jour en v$remote ! Le launcher redémarre." 'Mise à jour')
    $script:updating = $true
    Start-SelfHidden
    $form.Close()
}

# ------------------------------------------------------------ RobloxMulti.exe (avec le logo)
# Crée à côté du script un petit .exe qui lance le launcher sans aucune fenêtre de terminal.
function Build-LauncherExe {
    if (-not $PSCommandPath) { return }
    $dir = Split-Path -Parent $PSCommandPath
    $exe = Join-Path $dir 'RobloxMulti.exe'
    $stamp = Join-Path $DataDir 'exe_version.txt'
    $exeVersion = '2'   # à augmenter si le code de l'exe ou le logo change
    if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $stamp) -and
        ((Get-Content -LiteralPath $stamp -Raw).Trim() -eq $exeVersion)) { return }

    if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    $ico = Join-Path $DataDir 'icon.ico'
    [System.IO.File]::WriteAllBytes($ico, [Convert]::FromBase64String(($AppIconBase64 -replace '\s', '')))

    $code = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
static class RobloxMultiExe {
    [STAThread]
    static void Main() {
        string ps1 = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "RobloxMulti.ps1");
        if (!File.Exists(ps1)) {
            MessageBox.Show("RobloxMulti.ps1 est introuvable.\nGarde RobloxMulti.exe dans le meme dossier que RobloxMulti.ps1.", "Roblox Multi Launcher");
            return;
        }
        string ps = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
        ProcessStartInfo psi = new ProcessStartInfo(ps, "-NoProfile -STA -ExecutionPolicy Bypass -File \"" + ps1 + "\"");
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.EnvironmentVariables["RML_HIDDEN"] = "1";
        Process.Start(psi);
    }
}
'@
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.GenerateExecutable = $true
    $cp.OutputAssembly = $exe
    $cp.CompilerOptions = "/target:winexe /win32icon:`"$ico`""
    [void]$cp.ReferencedAssemblies.Add('System.dll')
    [void]$cp.ReferencedAssemblies.Add('System.Windows.Forms.dll')
    $res = (New-Object Microsoft.CSharp.CSharpCodeProvider).CompileAssemblyFromSource($cp, $code)
    if (-not $res.Errors.HasErrors -and (Test-Path -LiteralPath $exe)) {
        Set-Content -LiteralPath $stamp -Value $exeVersion
    }
}

$lnkUpdate.Add_LinkClicked({ try { Check-Update $true } catch { Show-Error $_ } })

# ------------------------------------------------------------ arrière-plan
function Hide-ToTray {
    $form.Hide()   # une fenêtre cachée disparaît aussi de la barre des tâches
    if (-not $script:balloonShown) {
        $script:balloonShown = $true
        $tray.ShowBalloonTip(3000, 'Roblox Multi Launcher',
            "Je tourne en arrière-plan. Clique sur mon icône (flèche ^ en bas à droite) pour me rouvrir.",
            [System.Windows.Forms.ToolTipIcon]::Info)
    }
}
function Show-FromTray {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.Activate()
}

$btnHide.Add_Click({ try { Hide-ToTray } catch { Show-Error $_ } })
$tray.Add_MouseClick({
    param($s, $ev)
    if ($ev.Button -eq [System.Windows.Forms.MouseButtons]::Left) { try { Show-FromTray } catch { Show-Error $_ } }
})
$tray.Add_BalloonTipClicked({ try { Show-FromTray } catch { Show-Error $_ } })
$miOpen.Add_Click({ try { Show-FromTray } catch { Show-Error $_ } })
$miMulti.Add_Click({ try { Invoke-Toggle } catch { Show-Error $_ } })
$miKill.Add_Click({
    try {
        $r = Show-Msg 'Fermer toutes les fenêtres Roblox ?' 'Confirmer' 'YesNo' 'Question'
        if ($r -eq 'Yes') { Stop-AllRoblox; Update-Status }
    } catch { Show-Error $_ }
})
$miQuit.Add_Click({ $form.Close() })
$trayMenu.Add_Opening({ $miMulti.Checked = (Test-Active) })

# ------------------------------------------------------------ écran d'accueil (GIF / vidéo)
# L'écran d'accueil est choisi par le propriétaire du dépôt GitHub (fichier splash.json du dépôt).
# Ici on garde juste en cache le dernier média téléchargé.
$SplashCfgFile = Join-Path $DataDir 'splash_state.json'
$OldSplashCfg  = Join-Path $DataDir 'splash.json'   # ancien réglage local (v1.4.0), plus utilisé
$GifExt   = @('.gif')
$VideoExt = @('.mp4', '.m4v', '.wmv', '.avi', '.mov')
$BrowserUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

function Get-SplashConfig {
    $cfg = [pscustomobject]@{ Enabled = $false; Source = ''; File = ''; Sound = $true; MaxSeconds = 6 }
    try {
        if (Test-Path -LiteralPath $SplashCfgFile) {
            $d = Get-Content -LiteralPath $SplashCfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in 'Enabled', 'Source', 'File', 'Sound', 'MaxSeconds') { if ($null -ne $d.$k) { $cfg.$k = $d.$k } }
        }
    } catch {}
    return $cfg
}
function Save-SplashConfig($cfg) {
    if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    $cfg | ConvertTo-Json | Set-Content -LiteralPath $SplashCfgFile -Encoding UTF8
}

function Get-UrlText($url, $timeoutMs) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.UserAgent = $BrowserUA
    $req.Timeout = $timeoutMs; $req.ReadWriteTimeout = $timeoutMs
    $req.Headers.Add('Cache-Control', 'no-cache')
    $resp = $req.GetResponse()
    try {
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        return $sr.ReadToEnd()
    } finally { $resp.Close() }
}

function Save-UrlToFile($url, $path, $timeoutMs) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.UserAgent = $BrowserUA
    $req.Timeout = $timeoutMs; $req.ReadWriteTimeout = $timeoutMs
    $resp = $req.GetResponse()
    try {
        $in = $resp.GetResponseStream()
        $out = [System.IO.File]::Create($path)
        try {
            $buf = New-Object byte[] 65536; $total = 0
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n); $total += $n
                if ($total -gt 60MB) { throw "Fichier trop lourd (60 Mo max)." }
            }
        } finally { $out.Close(); $in.Close() }
    } finally { $resp.Close() }
}

function Get-UrlExt($u) {
    try { return [IO.Path]::GetExtension(([Uri]$u).AbsolutePath).ToLower() } catch { return '' }
}

# Transforme un lien de page (Tenor, Giphy, Discord...) en lien direct vers le GIF / la vidéo
function Resolve-MediaUrl($url) {
    $ext = Get-UrlExt $url
    if ($GifExt -contains $ext -or $VideoExt -contains $ext) { return $url }
    if ($url -match '(youtube\.com|youtu\.be)') { throw "Les liens YouTube ne marchent pas. Prends un lien direct .gif / .mp4, un lien Tenor/Giphy, ou un fichier sur ton PC." }
    if ($url -match 'giphy\.com/(?:gifs|stickers)/(?:[^/?#]*-)?([A-Za-z0-9]+)(?:[/?#]|$)') {
        return "https://media.giphy.com/media/$($Matches[1])/giphy.gif"
    }
    # Sinon on lit la page et on cherche le média dans ses balises (og:image, og:video...)
    $html = Get-UrlText $url 8000
    $found = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches($html, '(?i)<meta[^>]+(?:property|name)\s*=\s*"(?:og:video:secure_url|og:video:url|og:video|og:image|twitter:image|twitter:player:stream)"[^>]*>')) {
        if ($m.Value -match '(?i)content\s*=\s*"([^"]+)"') { [void]$found.Add([System.Net.WebUtility]::HtmlDecode($Matches[1])) }
    }
    foreach ($m in [regex]::Matches($html, '(?i)https?://[^"''\s<>]+?\.(?:gif|mp4)(?:\?[^"''\s<>]*)?')) { [void]$found.Add($m.Value) }
    $gif = $found | Where-Object { (Get-UrlExt $_) -eq '.gif' } | Select-Object -First 1
    if ($gif) { return $gif }
    $vid = $found | Where-Object { $VideoExt -contains (Get-UrlExt $_) } | Select-Object -First 1
    if ($vid) { return $vid }
    throw "Je n'ai pas trouvé de GIF ou de vidéo sur cette page. Essaie avec le lien direct (clic droit sur le GIF > Copier l'adresse de l'image)."
}

# Prépare le média : télécharge le lien ou copie le fichier dans AppData (marche même hors ligne ensuite)
function Get-SplashMedia($source) {
    $source = "$source".Trim().Trim('"')
    if (-not $source) { throw "Mets un lien ou choisis un fichier." }
    if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    $stamp = [DateTime]::Now.Ticks

    if ($source -match '^https?://') {
        $direct = Resolve-MediaUrl $source
        $ext = Get-UrlExt $direct
        $tmp = Join-Path $DataDir "splash_$stamp.tmp"
        try { Save-UrlToFile $direct $tmp 20000 }
        catch { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; throw }
        if (-not ($GifExt -contains $ext -or $VideoExt -contains $ext)) {
            # Pas d'extension dans le lien : on regarde le début du fichier
            $head = [byte[]](Get-Content -LiteralPath $tmp -Encoding Byte -TotalCount 12)
            if ([System.Text.Encoding]::ASCII.GetString($head, 0, 3) -eq 'GIF') { $ext = '.gif' }
            elseif ([System.Text.Encoding]::ASCII.GetString($head, 4, 4) -eq 'ftyp') { $ext = '.mp4' }
            else { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; throw "Ce lien ne donne pas un GIF ou une vidéo .mp4." }
        }
        if ((Get-Item -LiteralPath $tmp).Length -gt 60MB) { Remove-Item -LiteralPath $tmp -Force; throw "Fichier trop lourd (60 Mo max)." }
        $dest = Join-Path $DataDir "splash_$stamp$ext"
        Move-Item -LiteralPath $tmp -Destination $dest -Force
        return $dest
    }

    if (-not (Test-Path -LiteralPath $source)) { throw "Fichier introuvable : $source" }
    $ext = [IO.Path]::GetExtension($source).ToLower()
    if (-not ($GifExt -contains $ext -or $VideoExt -contains $ext)) { throw "Format pas supporté ($ext). Utilise un .gif ou une vidéo .mp4 / .wmv / .avi / .mov." }
    $dest = Join-Path $DataDir "splash_$stamp$ext"
    Copy-Item -LiteralPath $source -Destination $dest -Force
    return $dest
}

function Remove-OldSplashFiles($keep) {
    Get-ChildItem -LiteralPath $DataDir -Filter 'splash_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $keep } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}

# Durée d'une boucle du GIF (en ms)
function Get-GifDuration($img) {
    try {
        $frames = $img.GetFrameCount([System.Drawing.Imaging.FrameDimension]::Time)
        $delays = $img.GetPropertyItem(0x5100).Value
        $total = 0
        for ($i = 0; $i -lt $frames; $i++) {
            $d = [BitConverter]::ToInt32($delays, $i * 4) * 10
            if ($d -lt 20) { $d = 100 }
            $total += $d
        }
        return $total
    } catch { return 2000 }
}

function Show-GifSplash($file, $maxSec) {
    $img = [System.Drawing.Image]::FromFile($file)
    try {
        $scale = [Math]::Min(1.0, [Math]::Min(640.0 / $img.Width, 480.0 / $img.Height))
        $w = [int]($img.Width * $scale); $h = [int]($img.Height * $scale)
        if ($w -lt 200) { $f = 200.0 / $w; $w = 200; $h = [int]($h * $f) }

        $sf = New-Object System.Windows.Forms.Form
        $sf.FormBorderStyle = 'None'
        $sf.StartPosition = 'CenterScreen'
        $sf.ShowInTaskbar = $false
        $sf.TopMost = $true
        $sf.BackColor = [System.Drawing.Color]::Black
        $sf.ClientSize = New-Object System.Drawing.Size($w, $h)
        $sf.KeyPreview = $true

        $pb = New-Object System.Windows.Forms.PictureBox
        $pb.Dock = 'Fill'
        $pb.SizeMode = 'Zoom'
        $pb.Image = $img
        $sf.Controls.Add($pb)

        $ms = [Math]::Max(1500, (Get-GifDuration $img))
        $ms = [Math]::Min($ms, [int]$maxSec * 1000)
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = [Math]::Max(100, $ms)
        $t.Add_Tick({ $t.Stop(); $sf.Close() })
        $sf.Add_Shown({ $t.Start() })
        $pb.Add_Click({ $sf.Close() })
        $sf.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape' -or $e.KeyCode -eq 'Space') { $sf.Close() } })
        [void]$sf.ShowDialog()
        $t.Dispose(); $sf.Dispose()
    } finally { $img.Dispose() }
}

function Show-VideoSplash($file, $maxSec, $sound) {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $win = New-Object System.Windows.Window
    $win.WindowStyle = 'None'
    $win.ResizeMode = 'NoResize'
    $win.ShowInTaskbar = $false
    $win.Topmost = $true
    $win.Background = [System.Windows.Media.Brushes]::Black
    $win.Width = 640; $win.Height = 360
    $win.WindowStartupLocation = 'CenterScreen'

    $me = New-Object System.Windows.Controls.MediaElement
    $me.LoadedBehavior = 'Manual'
    $me.UnloadedBehavior = 'Close'
    $me.Stretch = 'Uniform'
    $me.IsMuted = -not $sound
    $me.Volume = 0.8
    $me.Source = New-Object System.Uri($file)
    $win.Content = $me

    $me.Add_MediaOpened({
        if ($me.NaturalVideoWidth -gt 0) {
            $sc = [Math]::Min(1.0, [Math]::Min(800.0 / $me.NaturalVideoWidth, 600.0 / $me.NaturalVideoHeight))
            $win.Width  = [Math]::Max(240, $me.NaturalVideoWidth * $sc)
            $win.Height = [Math]::Max(135, $me.NaturalVideoHeight * $sc)
            $area = [System.Windows.SystemParameters]::WorkArea
            $win.Left = $area.Left + ($area.Width - $win.Width) / 2
            $win.Top  = $area.Top + ($area.Height - $win.Height) / 2
        }
    })
    $me.Add_MediaEnded({ $win.Close() })
    $me.Add_MediaFailed({ $win.Close() })

    $dt = New-Object System.Windows.Threading.DispatcherTimer
    $dt.Interval = [TimeSpan]::FromSeconds([int]$maxSec)
    $dt.Add_Tick({ $dt.Stop(); $win.Close() })

    $win.Add_ContentRendered({ $me.Play(); $dt.Start() })
    $win.Add_MouseDown({ $win.Close() })
    $win.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape' -or $e.Key -eq 'Space') { $win.Close() } })
    $win.Add_Closed({ $dt.Stop(); try { $me.Stop(); $me.Close() } catch {} })
    [void]$win.ShowDialog()
}

function Show-SplashFile($file, $maxSec, $sound) {
    if (-not $file -or -not (Test-Path -LiteralPath $file)) { return }
    $ext = [IO.Path]::GetExtension($file).ToLower()
    if ($GifExt -contains $ext) { Show-GifSplash $file $maxSec }
    elseif ($VideoExt -contains $ext) { Show-VideoSplash $file $maxSec $sound }
}

# Appelé au démarrage, avant d'afficher le launcher.
# Lit splash.json sur GitHub ; si le GIF/la vidéo a changé, le télécharge une fois puis le garde en cache.
function Show-StartupSplash {
    Remove-Item -LiteralPath $OldSplashCfg -Force -ErrorAction SilentlyContinue
    $state = Get-SplashConfig

    $remote = $null
    if (Test-UpdateEnabled) {
        try { $remote = (Get-UrlText "$(Get-RawUrl 'splash.json')?t=$([DateTime]::UtcNow.Ticks)" 4000) | ConvertFrom-Json } catch {}
    }

    if ($remote) {
        $src = "$($remote.source)".Trim()
        # Nom d'un fichier mis directement sur le dépôt (ex : splash.gif) -> lien GitHub
        if ($src -and $src -notmatch '^https?://') {
            $src = Get-RawUrl ((($src.TrimStart('/') -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
        }
        $state.Enabled = [bool]$remote.enabled -and [bool]$src
        if ($null -ne $remote.maxSeconds) { $state.MaxSeconds = [Math]::Min(30, [Math]::Max(1, [int]$remote.maxSeconds)) }
        if ($null -ne $remote.sound) { $state.Sound = [bool]$remote.sound }
        if ($state.Enabled -and ($src -ne "$($state.Source)" -or -not $state.File -or -not (Test-Path -LiteralPath $state.File))) {
            try {
                $file = Get-SplashMedia $src
                Remove-OldSplashFiles $file
                $state.Source = $src; $state.File = $file
            } catch {}   # lien cassé ou pas d'internet : on garde l'ancien média s'il existe
        }
        try { Save-SplashConfig $state } catch {}
    }

    if (-not $state.Enabled) { return }
    try { Show-SplashFile $state.File $state.MaxSeconds $state.Sound } catch {}
}


# ------------------------------------------------------------ raccourcis & épinglage
$AppId        = 'aotawl.RobloxMulti'
$ShortcutName = 'Roblox Multi Launcher.lnk'

# Petit module Windows (COM) pour : créer des raccourcis avec la bonne identité,
# et rendre "Épingler à la barre des tâches" possible depuis la fenêtre ouverte.
function Initialize-ShellHelper {
    if ('RML.Shell' -as [type]) { return $true }
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
namespace RML {
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropKey { public Guid fmtid; public uint pid; public PropKey(Guid g, uint p) { fmtid = g; pid = p; } }

    [StructLayout(LayoutKind.Explicit)]
    public struct PropVar {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr p;
        [FieldOffset(8)] public long pad;
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        void GetCount(out uint c);
        void GetAt(uint i, out PropKey k);
        void GetValue(ref PropKey k, out PropVar v);
        void SetValue(ref PropKey k, ref PropVar v);
        void Commit();
    }

    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellLinkW {
        void GetPath(IntPtr a, int b, IntPtr c, int d);
        void GetIDList(out IntPtr p);
        void SetIDList(IntPtr p);
        void GetDescription(IntPtr a, int b);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetWorkingDirectory(IntPtr a, int b);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetArguments(IntPtr a, int b);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetHotkey(out short h);
        void SetHotkey(short h);
        void GetShowCmd(out int c);
        void SetShowCmd(int c);
        void GetIconLocation(IntPtr a, int b, out int i);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string s, int i);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string s, int r);
        void Resolve(IntPtr h, int f);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string s);
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink { }

    public static class Shell {
        static readonly Guid AUM = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        const uint PID_RELAUNCH_CMD = 2, PID_RELAUNCH_ICON = 3, PID_RELAUNCH_NAME = 4, PID_ID = 5;

        [DllImport("shell32.dll")]
        static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, out IPropertyStore store);

        [DllImport("shell32.dll")]
        static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);

        // Demande à Windows de redessiner les icônes (sinon il garde l'ancienne en cache)
        public static void RefreshIcons() { SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero); }

        static void Set(IPropertyStore s, uint pid, string value) {
            PropKey k = new PropKey(AUM, pid);
            PropVar v = new PropVar();
            v.vt = 31; // VT_LPWSTR
            v.p = Marshal.StringToCoTaskMemUni(value);
            try { s.SetValue(ref k, ref v); } finally { Marshal.FreeCoTaskMem(v.p); }
        }

        // Rend la fenêtre épinglable : l'épingle lancera l'exe, avec le bon nom et le bon logo
        public static void SetWindowRelaunch(IntPtr hwnd, string appId, string exe, string name, string icon) {
            Guid iid = typeof(IPropertyStore).GUID;
            IPropertyStore s;
            Marshal.ThrowExceptionForHR(SHGetPropertyStoreForWindow(hwnd, ref iid, out s));
            try {
                Set(s, PID_ID, appId);
                Set(s, PID_RELAUNCH_CMD, "\"" + exe + "\"");
                Set(s, PID_RELAUNCH_NAME, name);
                Set(s, PID_RELAUNCH_ICON, icon + ",0");
            } finally { Marshal.ReleaseComObject(s); }
        }

        public static void CreateShortcut(string lnk, string target, string workDir, string icon, string desc, string appId) {
            IShellLinkW link = (IShellLinkW)new ShellLink();
            try {
                link.SetPath(target);
                link.SetWorkingDirectory(workDir);
                link.SetIconLocation(icon, 0);
                link.SetDescription(desc);
                IPropertyStore s = (IPropertyStore)link;
                Set(s, PID_ID, appId);
                s.Commit();
                ((IPersistFile)link).Save(lnk, true);
            } finally { Marshal.ReleaseComObject(link); }
        }
    }
}
'@
        return $true
    } catch { return $false }
}

function Get-ExePath {
    if (-not $PSCommandPath) { return $null }
    $exe = Join-Path (Split-Path -Parent $PSCommandPath) 'RobloxMulti.exe'
    if (Test-Path -LiteralPath $exe) { return $exe }
    return $null
}

# Le logo est rangé dans AppData : cet endroit ne bouge jamais, même si tu déplaces le launcher
function Get-IconFile {
    $ico = Join-Path $DataDir 'icon.ico'
    $bytes = [Convert]::FromBase64String(($AppIconBase64 -replace '\s', ''))
    $same = $false
    if (Test-Path -LiteralPath $ico) { $same = ((Get-Item -LiteralPath $ico).Length -eq $bytes.Length) }
    if (-not $same) {
        if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
        [System.IO.File]::WriteAllBytes($ico, $bytes)
    }
    return $ico
}

function Set-TaskbarIdentity {
    $exe = Get-ExePath
    if (-not $exe -or -not (Initialize-ShellHelper)) { return }
    try { [RML.Shell]::SetWindowRelaunch($form.Handle, $AppId, $exe, 'Roblox Multi Launcher', (Get-IconFile)) } catch {}
}

function New-AppShortcut($folder) {
    $exe = Get-ExePath
    $lnk = Join-Path $folder $ShortcutName
    [RML.Shell]::CreateShortcut($lnk, $exe, (Split-Path -Parent $exe), (Get-IconFile), 'Lance plusieurs Roblox avec plusieurs comptes', $AppId)
    return $lnk
}

# Dossiers où le launcher a pu mettre un raccourci (Bureau, menu Démarrer, épingle de la barre des tâches)
function Get-ShortcutFolders {
    return @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('Programs'),
        (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
}

# À chaque démarrage : si un raccourci existe déjà, on le refait pour qu'il pointe
# vers l'emplacement ACTUEL du launcher (utile si tu as déplacé les fichiers)
function Repair-Shortcuts {
    if (-not (Get-ExePath) -or -not (Initialize-ShellHelper)) { return }
    $fixed = 0
    foreach ($folder in Get-ShortcutFolders) {
        $lnk = Join-Path $folder $ShortcutName
        if (Test-Path -LiteralPath $lnk) {
            try { [void](New-AppShortcut $folder); $fixed++ } catch {}
        }
    }
    if ($fixed -gt 0) { try { [RML.Shell]::RefreshIcons() } catch {} }
}

function Show-ShortcutDialog {
    $exe = Get-ExePath
    if (-not $exe) {
        [void](Show-Msg "RobloxMulti.exe n'a pas pu être créé (ton antivirus l'a peut-être bloqué), donc pas de raccourci possible pour l'instant.`r`n`r`nTu peux continuer avec Lancer RobloxMulti.bat." 'Raccourcis' 'OK' 'Warning')
        return
    }
    if (-not (Initialize-ShellHelper)) {
        [void](Show-Msg "Impossible de créer les raccourcis sur ce PC." 'Raccourcis' 'OK' 'Warning'); return
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMn = [Environment]::GetFolderPath('Programs')

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Où veux-tu mettre le launcher ?'
    $dlg.ClientSize = New-Object System.Drawing.Size(360, 200)
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.StartPosition = 'CenterParent'
    $dlg.Font = $form.Font
    if ($script:appIcon) { $dlg.Icon = $script:appIcon }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Coche ce que tu veux (tu pourras changer plus tard) :'
    $lbl.SetBounds(15, 12, 330, 20)
    $dlg.Controls.Add($lbl)

    $cbDesk = New-Object System.Windows.Forms.CheckBox
    $cbDesk.Text = 'Raccourci sur le Bureau'
    $cbDesk.SetBounds(20, 40, 320, 24)
    $cbDesk.Checked = $true
    $dlg.Controls.Add($cbDesk)

    $cbStart = New-Object System.Windows.Forms.CheckBox
    $cbStart.Text = 'Raccourci dans le menu Démarrer'
    $cbStart.SetBounds(20, 68, 320, 24)
    $cbStart.Checked = $true
    $dlg.Controls.Add($cbStart)

    $cbPin = New-Object System.Windows.Forms.CheckBox
    $cbPin.Text = 'Épingler à la barre des tâches'
    $cbPin.SetBounds(20, 96, 320, 24)
    $cbPin.Checked = $true
    $dlg.Controls.Add($cbPin)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Valider'
    $ok.DialogResult = 'OK'
    $ok.SetBounds(150, 150, 95, 30)
    $dlg.Controls.Add($ok)
    $dlg.AcceptButton = $ok

    $later = New-Object System.Windows.Forms.Button
    $later.Text = 'Plus tard'
    $later.DialogResult = 'Cancel'
    $later.SetBounds(252, 150, 95, 30)
    $dlg.Controls.Add($later)
    $dlg.CancelButton = $later

    if ($form.Visible) { $res = $dlg.ShowDialog($form) } else { $res = $dlg.ShowDialog() }
    if ($res -ne 'OK') { $dlg.Dispose(); return }
    $wantDesk = $cbDesk.Checked; $wantStart = $cbStart.Checked; $wantPin = $cbPin.Checked
    $dlg.Dispose()

    $done = @()
    try {
        if ($wantDesk)  { [void](New-AppShortcut $desktop); $done += 'Bureau' }
        if ($wantStart) { [void](New-AppShortcut $startMn); $done += 'menu Démarrer' }
        if ($done.Count -gt 0) { [RML.Shell]::RefreshIcons() }
    } catch {
        [void](Show-Msg "Erreur pendant la création des raccourcis : $($_.Exception.Message)" 'Raccourcis' 'OK' 'Warning')
    }

    $msg = ''
    if ($done.Count -gt 0) { $msg = "Raccourci créé : $($done -join ' + ')." }
    if ($wantPin) {
        if (-not $form.Visible) { Show-FromTray }
        if ($msg) { $msg += "`r`n`r`n" }
        $msg += "Pour la barre des tâches, Windows interdit aux programmes de s'épingler eux-mêmes, il faut un clic :`r`n`r`n" +
                "Clic droit sur l'icône du launcher dans la barre des tâches (en bas), puis « Épingler à la barre des tâches ».`r`n`r`n" +
                "La prochaine fois, il suffira de cliquer dessus pour lancer le launcher."
    }
    if ($msg) { [void](Show-Msg $msg 'Raccourcis') }
}

function Invoke-FirstRunShortcuts {
    $flag = Join-Path $DataDir 'shortcuts_asked.txt'
    if (Test-Path -LiteralPath $flag) { return }
    if (-not (Get-ExePath)) { return }   # on attend que l'exe existe
    Set-Content -LiteralPath $flag -Value (Get-Date -Format s)
    Show-ShortcutDialog
}

$lnkShort.Add_LinkClicked({ try { Show-ShortcutDialog } catch { Show-Error $_ } })
$miShort.Add_Click({ try { Show-ShortcutDialog } catch { Show-Error $_ } })

$form.Add_Shown({
    try {
        Check-Update $false   # vérif silencieuse au démarrage
        if ($script:updating) { return }
        Load-Accounts
        Refresh-List
        Load-Presets
        $last = Load-LastPlace
        if (-not $last -and $script:presets.Count -gt 0) { $last = Format-Preset $script:presets[0] }
        Refresh-Presets $last
        Update-Status
        Invoke-Toggle   # active direct au lancement
        $timer.Start()
        try { Build-LauncherExe } catch {}   # silencieux : si ça rate, le .bat marche toujours
        try { Set-TaskbarIdentity } catch {} # rend "Épingler à la barre des tâches" possible
        try { Repair-Shortcuts } catch {}    # répare les raccourcis si le launcher a été déplacé
        Invoke-FirstRunShortcuts             # 1er lancement : propose Bureau / Démarrer / barre des tâches
    } catch { Show-Error $_ }
})

$form.Add_FormClosing({
    param($s, $ev)
    if (-not $script:updating -and (Test-Active) -and (Get-RobloxCount) -gt 0) {
        $r = Show-Msg "Des Roblox sont ouverts. Si tu quittes, le prochain lancé fermera les autres. Quitter quand même ?" 'Quitter' 'YesNo' 'Warning'
        if ($r -ne 'Yes') { $ev.Cancel = $true; return }
    }
    $timer.Stop()
    Disable-Multi
    $tray.Visible = $false
    $tray.Dispose()
})

# Écran d'accueil (GIF / vidéo) avant d'ouvrir le launcher
try { Show-StartupSplash } catch {}

# Application.Run (et pas ShowDialog) pour que l'appli continue de tourner une fois cachée
[System.Windows.Forms.Application]::Run($form)
