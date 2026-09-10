$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$null = $null

& {
$null = Add-Type -AssemblyName System.Windows.Forms
$null = Add-Type -AssemblyName System.Drawing

# Fenêtre
$form = New-Object System.Windows.Forms.Form
$form.Text = "EANNA Haute-Vienne - Desc PC"
$form.ClientSize = New-Object System.Drawing.Size(450,320)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(350,250)
$form.AutoSize = $false

# StatusBar
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Prêt"
$statusBar.Items.Add($statusLabel)
$form.Controls.Add($statusBar)

# ProgressBar
$progressBar = New-Object System.Windows.Forms.ToolStripProgressBar
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Visible = $false
$statusBar.Items.Add($progressBar)

# Tooltips (explications au survol)
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 10000
$toolTip.InitialDelay = 400
$toolTip.ReshowDelay = 100
$toolTip.ShowAlways = $true

# Label PC
$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Text = "Nom du PC :"
$lblPC.Location = "20,20"
$form.Controls.Add($lblPC)

# Champs PC
$txtPC = New-Object System.Windows.Forms.TextBox
$txtPC.Location = "120,18"
$txtPC.Width = 180
$txtPC.Anchor = 'Top,Left,Right'
$form.Controls.Add($txtPC)

# === Auto-complétion AD ===
try {
    $null = Import-Module ActiveDirectory -ErrorAction Stop

    $PCList = Get-ADComputer -Filter "Name -like 'PC*' -or Name -like 'PCR*'" |
              Select-Object -ExpandProperty Name

    $autoSource = New-Object System.Windows.Forms.AutoCompleteStringCollection
    $autoSource.AddRange($PCList)

    $txtPC.AutoCompleteMode = 'SuggestAppend'
    $txtPC.AutoCompleteSource = 'CustomSource'
    $txtPC.AutoCompleteCustomSource = $autoSource
}
catch {
    [void][System.Windows.Forms.MessageBox]::Show(
    "Auto-complétion AD indisponible...",
    "Information",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
}

# === Fonction de détection de salle ===
function Get-SalleFromAD {
    $pc = $txtPC.Text.Trim()
    if ($pc.Length -lt 5) { return }

    try {
        $null = Import-Module ActiveDirectory -ErrorAction Stop
        $ADObj = Get-ADComputer $pc -Properties distinguishedName -ErrorAction Stop

        # DN Exemple : CN=PC-00001,OU=S112,OU=Postes Clients,OU=Ordinateurs,DC=LPEV,DC=lan
        $dn = $ADObj.distinguishedName
        $parts = $dn -split ","
        $salle = ($parts[1] -replace "^OU=", "")

        if ($txtDesc.Text -eq "" -or $txtDesc.Text -match '^[A-Za-z0-9\-\s]*$') {
            $txtDesc.Text = "$salle-"
        }
    }
    catch { }
}

# === Déclenchement de Get-SalleFromAD (anti-lag) ===

# Quand l’utilisateur valide avec Entrée
$null = $txtPC.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Get-SalleFromAD
    }
    $null
})

# Quand il sélectionne via la liste ou quitte la TextBox
$null = $txtPC.Add_Leave({
    Get-SalleFromAD
    $null
})

# Label Desc
$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = "Description :"
$lblDesc.Location = "20,60"
$form.Controls.Add($lblDesc)

# Champ Desc
$txtDesc = New-Object System.Windows.Forms.TextBox
$txtDesc.Location = "120,58"
$txtDesc.Width = 180
$form.Controls.Add($txtDesc)
$txtDesc.Anchor = 'Top,Left,Right'

# Zone de résultat
$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = "20,160"
$txtOut.Width = 280
$txtOut.ReadOnly = $true
$txtOut.Anchor = 'Top,Left,Right,Bottom'
$txtOut.Multiline = $true
$txtOut.ScrollBars = 'Vertical'
$form.Controls.Add($txtOut)

# Saut de ligne standard Windows (WinForms)
$nl = [Environment]::NewLine

#Flag bouton annuler
$script:IsCsvRunning = $false
$script:CancelRequested = $false


############################################
# Creation bouton
############################################

# Tailles et positions des boutons
$btnWidth  = 120
$btnLeftX  = 20
$btnGap    = 10
$btnRightX = $btnLeftX + $btnWidth + $btnGap
$btnInfoX = $btnRightX + $btnWidth + $btnGap

# Bouton Vérifier le PC
$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Vérifier le PC"
$btnTest.Location = "$btnLeftX,95"
$btnTest.Width = $btnWidth
$form.Controls.Add($btnTest)

# Bouton Appliquer
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Appliquer"
$btnApply.Location = "$btnLeftX,125"
$btnApply.Width = $btnWidth
$form.Controls.Add($btnApply)

# Bouton Aide CSV
$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = "Aide CSV"
$btnHelp.Location = "$btnRightX,95"
$btnHelp.Width = $btnWidth
$form.Controls.Add($btnHelp)

# Bouton Traiter CSV
$btnCSV = New-Object System.Windows.Forms.Button
$btnCSV.Text = "Traiter CSV"
$btnCSV.Location = "$btnRightX,125"
$btnCSV.Width = $btnWidth
$form.Controls.Add($btnCSV)

# Bouton Info Préfixes
$btnInfo = New-Object System.Windows.Forms.Button
$btnInfo.Text = "Info préfixes"
$btnInfo.Location = "$btnInfoX,95"
$btnInfo.Width = $btnWidth
$form.Controls.Add($btnInfo)

############################################
# Action Tooltips
############################################

# Tooltips
$toolTip.SetToolTip($txtPC,   "Nom du poste (ex : PC-00478-TUL)")
$toolTip.SetToolTip($txtDesc, "Description à appliquer (ex : C014-014)")

$toolTip.SetToolTip($btnTest,  "Teste l'accès (Ping + ADMIN$) et lit la description actuelle")
$toolTip.SetToolTip($btnApply,"Applique la description dans le registre et l'AD")
$toolTip.SetToolTip($btnHelp, "Affiche l'aide sur le format CSV attendu")
$toolTip.SetToolTip($btnCSV,  "Traite un fichier CSV et génère un rapport")
$toolTip.SetToolTip($btnInfo, "Signification des préfixes PC / Nomenclature")

############################################
# Fonction
############################################

#Fonction Désactiver/Activer l'ui pendant traitement
function Disable-UI {
    $btnTest.Enabled  = $false
    $btnApply.Enabled = $false
    $btnHelp.Enabled  = $false
    $btnInfo.Enabled = $false
    # $btnCSV.Enabled   = $false
}

function Enable-UI {
    $btnTest.Enabled  = $true
    $btnApply.Enabled = $true
    $btnHelp.Enabled  = $true
    $btnCSV.Enabled   = $true
    $btnInfo.Enabled = $true
}
#Fonction StatusBar
function Set-Status {
    param (
        [string]$Text
    )

    $statusLabel.Text = $Text
    $statusBar.Refresh()
}
#Fonction CsvButtonMode/annuler
function Set-CsvButtonMode {
    param([bool]$Running)

    if ($Running) {
        $btnCSV.Text = "Annuler"
    } else {
        $btnCSV.Text = "Traiter CSV"
    }
}

############################################
# Action bouton
############################################

# Action bouton Info
$null = $btnInfo.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
"Signification des préfixes :

PC   → Poste neuf
PCR  → Poste reconditionné
PO   → Poste portable
POR  → Portable reconditionné

Établissement :

ARL  → Auguste Renoir
EVSJ → Édouard Vaillant
GLL  → Gay Lussac
GSY  → André Guillaumin
JDSY → Jean-Baptiste Darnet
JGB  → Jean Giraudoux
JML  → Jean Monnet
LLL  → Léonard Limosin
LVV  → Les Vaseix
MBL  → Maryse Bastié
MJL  → Le Mas Jambost
MLB  → Magnac-Laval
MNB  → Martin Nadaud
MPL  → Marcel Pagnol
PESJ → Paul Éluard
RDL  → Raoul Dautry
SEL  → Antoine de Saint-Exupéry
SVL  → Suzanne Valadon
TUL  → Turgot",
"Information – Préfixes postes",
[System.Windows.Forms.MessageBoxButtons]::OK,
[System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Action Aide CSV
$null = $btnHelp.Add_Click({
    [void][System.Windows.Forms.MessageBox]::Show(
"FORMAT CSV OBLIGATOIRE :

PC;Description
PC-00600-EVSJ;S112-PROF
PC-00601-EVSJ;S112-001

RÈGLES :
- Séparateur : point-virgule (;)
- Première ligne obligatoire
- Un PC par ligne",
"Aide – Format CSV",
[System.Windows.Forms.MessageBoxButtons]::OK,
[System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Action Verifier le PC
$null = $btnTest.Add_Click({
    $pc = $txtPC.Text.Trim()

    if ($pc -eq "") {
        $txtOut.Text = "Aucun PC spécifié."
        return
    }

    try {
        if (!(Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
            $txtOut.Text = "Ping K.O : PC hors ligne."
            return
        }

        if (!(Test-Path "\\$pc\ADMIN$")) {
            $txtOut.Text = "ADMIN$ K.O : pas d'accès administrateur."
            return
        }

        $r=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$pc)
        $k=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$false)
        $val=$k.GetValue('srvcomment')
        $k.Close()

        $kOS = $r.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion',$false)
        $product = $kOS.GetValue('ProductName')
        $version = $kOS.GetValue('DisplayVersion')
        if (-not $version) {
        $version = $kOS.GetValue('ReleaseId')
                            }

        $kOS.Close()


        $txtOut.Text =
        "OK : PC joignable." + $nl +
        "Description actuelle : $val" + $nl +
        "OS : $product $version"
    }
    catch {
        $txtOut.Text = "Erreur : $($_.Exception.Message)"
    }
})

# Action Appliquer
$null = $btnApply.Add_Click({
    try {
        $pc = $txtPC.Text
        $desc = $txtDesc.Text

        if ($pc -eq "" -or $desc -eq "") {
            $txtOut.Text = "Champs incomplets."
            return
        }

        # Écriture registre
        $r=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$pc)
        $k=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$true)
        $k.SetValue('srvcomment',$desc,'String')
        $k.Close()

        # Mise à jour description AD
        $null = Import-Module ActiveDirectory -ErrorAction Stop
        Set-ADComputer -Identity $pc -Description $desc

        # Lecture pour validation
        $k2=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$false)
        $val=$k2.GetValue('srvcomment')
        $k2.Close()

        $txtOut.Text = "Description appliquée : Registre = '$val' / AD = OK"
    }
    catch {
        $txtOut.Text = "Erreur : $($_.Exception.Message)"
    }
})

# Action Traiter CSV
$null = $btnCSV.Add_Click({

    # Si déjà en cours → on demande l'annulation
    if ($script:IsCsvRunning) {
        $script:CancelRequested = $true
        Set-Status "Annulation demandée..."
        return
    }

    # Fenêtre de sélection CSV
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Fichier CSV (*.csv)|*.csv"
    $dialog.Title = "Sélectionner un fichier CSV"

    $result = $dialog.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return }


    $script:IsCsvRunning = $true
    $script:CancelRequested = $false
    Set-CsvButtonMode $true

    Disable-UI
    Set-Status "Traitement du CSV..."
    
    $progressBar.Visible = $true
    $progressBar.Value = 0

    try {

        $null = Import-Module ActiveDirectory -ErrorAction Stop
        $path = $dialog.FileName
        $txtOut.Clear()
        $txtOut.Text = "Traitement du CSV..."

        $data = Import-Csv -Path $path -Delimiter ";"
        $resultats = @()
        $nbOK = 0
        $nbKO = 0
        $total = $data.Count
        $index = 0

        foreach ($line in $data) {

            # === PATCH ANNULER ===
            if ($script:CancelRequested) {
                Set-Status "Traitement annulé ($index / $total)"
                $txtOut.Text += $nl + "Traitement annulé par l'utilisateur."
                break
            }

            $pc   = $line.PC.Trim()
            $desc = $line.Description.Trim()
            $etat = "OK"

            if (!(Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
                $etat = "PING K.O"
            }
            elseif (!(Test-Path "\\$pc\ADMIN$")) {
                $etat = "ADMIN$ K.O"
            }
            else {
                try {
                    $r=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$pc)
                    $k=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$true)
                    $k.SetValue('srvcomment',$desc,'String')
                    $k.Close()

                    Set-ADComputer -Identity $pc -Description $desc
                }
                catch {
                    $etat = "ERREUR"
                }
            }

            if ($etat -eq "OK") { $nbOK++ } else { $nbKO++ }

            $resultats += [PSCustomObject]@{
                PC = $pc
                Description = $desc
                Etat = $etat
            }

            $index++
            $progressBar.Value = [Math]::Min(100, [int](($index / $total) * 100))
            Set-Status "Traitement du CSV... ($index / $total)"

            [System.Windows.Forms.Application]::DoEvents()
        }

        if (-not $script:CancelRequested) {
            Set-Status "Traitement terminé"
        }

        $date = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $rep = $path -replace "\.csv$", "_RAPPORT_$date.csv"
        $resultats | Export-Csv -Path $rep -Delimiter ";" -NoTypeInformation -Encoding UTF8

        $txtOut.Text += $nl + "Résumé : OK = $nbOK | Échecs = $nbKO"
        $txtOut.Text += $nl + "Rapport exporté : $rep"
    }
    catch {
        Set-Status "Erreur CSV"
        $txtOut.Text = "Erreur CSV : fichier non conforme."
    }
    finally {
        Enable-UI
        $progressBar.Value = 0
        $progressBar.Visible = $false

        $script:IsCsvRunning = $false
        $script:CancelRequested = $false
        Set-CsvButtonMode $false

        Set-Status "Prêt"
    }
})


$null = $form.Topmost = $true

$null = $form.Add_Shown({

    $margeDroite = 20

    # TextBox PC
    $txtPC.Width = $form.ClientSize.Width - $txtPC.Left - $margeDroite

    # TextBox Description
    $txtDesc.Width = $form.ClientSize.Width - $txtDesc.Left - $margeDroite

    # Zone de sortie
    $txtOut.Width  = $form.ClientSize.Width - $txtOut.Left - $margeDroite
    $txtOut.Height = $form.ClientSize.Height - $txtOut.Top - 20
})

$null = $form.ShowDialog()

} | Out-Null