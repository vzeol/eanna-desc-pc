Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Fenêtre
$form = New-Object System.Windows.Forms.Form
$form.Text = "Description PC"
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

# ==== Auto-complétion AD pour le champ PC ====

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Récupérer la liste des PC dans l'AD
    # (tu peux filtrer ici si tu veux : Name -like 'PC-006*')
    $PCList = Get-ADComputer -Filter "Name -like 'PC*' -or Name -like 'PCR*'" |
           Select-Object -ExpandProperty Name

    # Charger dans l'objet WinForms
    $autoSource = New-Object System.Windows.Forms.AutoCompleteStringCollection
    $autoSource.AddRange($PCList)

    # Configurer la TextBox en mode auto-complétion
    $txtPC.AutoCompleteMode = 'SuggestAppend'
    $txtPC.AutoCompleteSource = 'CustomSource'
    $txtPC.AutoCompleteCustomSource = $autoSource
}
catch {
    # Si module AD manquant ou AD inaccessible
    $txtOut.Text = "Auto-complétion impossible : $($_.Exception.Message)"
}

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

# Action Tester PC
$btnTest.Add_Click({
    $pc = $txtPC.Text.Trim()

    if ($pc -eq "") {
        $txtOut.Text = "Aucun PC spécifié."
        return
    }

    try {
        # Test 1 : ping
        if (!(Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
            $txtOut.Text = "Ping KO : PC hors ligne."
            return
        }

        # Test 2 : ADMIN$
        if (!(Test-Path "\\$pc\ADMIN$")) {
            $txtOut.Text = "ADMIN$ KO : pas d'accès administrateur."
            return
        }

        # Test 3 : Lecture registre
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

        # Lecture pour validation
        $k2=$r.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',$false)
        $val=$k2.GetValue('srvcomment')
        $k2.Close()

        $txtOut.Text = "Écrit : $val"
    }
    catch {
        $txtOut.Text = "Erreur : $($_.Exception.Message)"
    }
})

$form.Topmost = $true
$form.ShowDialog()