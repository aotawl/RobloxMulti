# Roblox Multi Launcher (PowerShell, aucune installation requise)
# - Multi-instance : garde les objets "singleton" de Roblox ouverts
# - Comptes : tu te connectes une fois toi-même, la session est gardée
#   CHIFFRÉE avec Windows (DPAPI) et sert à lancer Roblox directement.
# Aucun mot de passe n'est stocké. Rien n'est envoyé ailleurs que sur roblox.com.

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

function Show-Msg($text, $title = 'Roblox Multi Launcher', $buttons = 'OK', $icon = 'Information') {
    return [System.Windows.Forms.MessageBox]::Show($text, $title, $buttons, $icon)
}
function Show-Error($err) {
    [void](Show-Msg "Erreur : $($err.Exception.Message)`r`n`r`nEnvoie ce message à Claude." 'Erreur' 'OK' 'Error')
}

trap { Show-Error $_; continue }

# ============================================================ mises à jour
# Version de CE fichier. Augmente-la à chaque fois que tu publies une mise à jour.
$AppVersion = '1.0.0'
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
$form = New-Object System.Windows.Forms.Form
$form.Text = "Roblox Multi Launcher  v$AppVersion"
$form.ClientSize = New-Object System.Drawing.Size(455, 540)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

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
$btnToggle.SetBounds(15, 74, 120, 30)
$grpMulti.Controls.Add($btnToggle)

$btnKill = New-Object System.Windows.Forms.Button
$btnKill.Text = 'Fermer tous les Roblox'
$btnKill.SetBounds(255, 74, 160, 30)
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
$lnkUpdate.SetBounds(14, 515, 430, 20)
$form.Controls.Add($lnkUpdate)

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

        $msg = "Nouvelle version disponible : v$remote (tu as v$AppVersion)."
        if ($notes) { $msg += "`r`n`r`nNouveautés :`r`n$notes" }
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
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$self`"")
    $form.Close()
}

$lnkUpdate.Add_LinkClicked({ try { Check-Update $true } catch { Show-Error $_ } })

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
})

[void]$form.ShowDialog()
