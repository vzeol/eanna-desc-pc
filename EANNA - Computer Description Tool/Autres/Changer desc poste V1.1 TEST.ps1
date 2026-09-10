Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Fenêtre
$form = New-Object System.Windows.Forms.Form
$form.Text = "EANNA Haute-Vienne - Desc PC"
$form.Size = New-Object System.Drawing.Size(350,250)
$form.StartPosition = "CenterScreen"

# Label PC
$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Text = "Nom du PC :"
$lblPC.Location = "20,20"
$form.Controls.Add($lblPC)

# TextBox PC
$txtPC = New-Object System.Windows.Forms.TextBox
$txtPC.Location = "120,18"
$txtPC.Width = 180
$form.Controls.Add($txtPC)

# === Auto-complétion AD ===
try {
    Import-Module ActiveDirectory -ErrorAction Stop

    $PCList = Get-ADComputer -Filter "Name -like 'PC*' -or Name -like 'PCR*'" |
              Select-Object -ExpandProperty Name

    $autoSource = New-Object System.Windows.Forms.AutoCompleteStringCollection
    $autoSource.AddRange($PCList)

    $txtPC.AutoCompleteMode = 'SuggestAppend'
    $txtPC.AutoCompleteSource = 'CustomSource'
    $txtPC.AutoCompleteCustomSource = $autoSource
}
catch {
    $txtOut.Text = "Auto-complétion impossible : $($_.Exception.Message)"
}

# === Fonction de détection de salle ===
function Get-SalleFromAD {
    $pc = $txtPC.Text.Trim()
    if ($pc.Length -lt 5) { return }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $ADObj = Get-ADComputer $pc -Properties distinguishedName -ErrorAction Stop

        # DN : CN=PC-00001,OU=S112,OU=Postes Clients,OU=Ordinateurs,DC=LPEV,DC=lan
        $dn = $ADObj.distinguishedName
        $parts = $dn -split ","
        $salle = ($parts[1] -replace "^OU=", "")

        if ($txtDesc.Text -eq "" -or $txtDesc.Text -match '^[A-Za-z0-9\-\s]*$') {
            $txtDesc.Text = "$salle-"
        }
    }
    catch { }
}

# === Déclenchement de Get-SalleFromAD ===

# Quand l’utilisateur valide avec Entrée
$txtPC.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Get-SalleFromAD
    }
})

# Quand il sélectionne via la liste ou quitte la TextBox
$txtPC.Add_Leave({
    Get-SalleFromAD
})

# Label Desc
$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = "Description :"
$lblDesc.Location = "20,60"
$form.Controls.Add($lblDesc)

# TextBox Desc
$txtDesc = New-Object System.Windows.Forms.TextBox
$txtDesc.Location = "120,58"
$txtDesc.Width = 180
$form.Controls.Add($txtDesc)

# Zone de résultat
$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = "20,160"
$txtOut.Width = 280
$txtOut.ReadOnly = $true
$form.Controls.Add($txtOut)

# Bouton Appliquer
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Appliquer"
$btnApply.Location = "120,95"
$form.Controls.Add($btnApply)

# Bouton Tester le PC
$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Tester le PC"
$btnTest.Location = "120,125"
$form.Controls.Add($btnTest)

$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = "Aide CSV"
$btnHelp.Location = "20,95"
$btnHelp.Width = 90
$form.Controls.Add($btnHelp)

$btnCSV = New-Object System.Windows.Forms.Button
$btnCSV.Text = "Traiter CSV"
$btnCSV.Location = "20,125"
$btnCSV.Width = 90
$form.Controls.Add($btnCSV)

# Aide CSV
$btnHelp.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
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

# Action Tester PC
$btnTest.Add_Click({
    $pc = $txtPC.Text.Trim()

    if ($pc -eq "") {
        $txtOut.Text = "Aucun PC spécifié."
        return
    }

    try {
        if (!(Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
            $txtOut.Text = "Ping KO : PC hors ligne."
            return
        }

        if (!(Test-Path "\\$pc\ADMIN$")) {
            $txtOut.Text = "ADMIN$ KO : pas d'accès administrateur."
            return
        }

        $r=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$pc)
        $k=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$false)
        $val=$k.GetValue('srvcomment')
        $k.Close()

        $txtOut.Text = "OK : PC joignable. Description actuelle = $val"
    }
    catch {
        $txtOut.Text = "Erreur : $($_.Exception.Message)"
    }
})

# Action Appliquer
$btnApply.Add_Click({
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
        Import-Module ActiveDirectory -ErrorAction Stop
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

# --- Traitement d'un CSV ---
$btnCSV.Add_Click({
    # Fenêtre de sélection CSV
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Fichier CSV (*.csv)|*.csv"
    $dialog.Title = "Sélectionner un fichier CSV"

    if ($dialog.ShowDialog() -ne "OK") { return }

    $path = $dialog.FileName
    $txtOut.Text = "Traitement du CSV..."

    try {
        $data = Import-Csv -Path $path -Delimiter ";"

        $resultats = @()

        foreach ($line in $data) {

            $pc = $line.PC.Trim()
            $desc = $line.Description.Trim()

            $etat = "OK"

            # Test ping
            if (!(Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
                $etat = "PING K.O"
            }

            # Test admin$
            elseif (!(Test-Path "\\$pc\ADMIN$")) {
                $etat = "ADMIN$ K.O"
            }

            else {
                try {
                    # Registre
                    $r=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$pc)
                    $k=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$true)
                    $k.SetValue('srvcomment',$desc,'String')
                    $k.Close()

                    # AD
                    Set-ADComputer -Identity $pc -Description $desc
                }
                catch {
                    $etat = "ERREUR : $($_.Exception.Message)"
                }
            }

            # Ajout au rapport
            $resultats += [PSCustomObject]@{
                PC = $pc
                Description = $desc
                Etat = $etat
            }
        }

        # Export du rapport
		$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $rep = $path -replace "\.csv$", "_RAPPORT_$date.csv"
        $resultats | Export-Csv -Path $rep -Delimiter ";" -NoTypeInformation -Encoding UTF8
        $txtOut.Text += "`nRapport exporté : $rep"
    }
    catch {
        $txtOut.Text = "Erreur CSV : $($_.Exception.Message)"
    }
})

$form.Topmost = $true
$form.ShowDialog()