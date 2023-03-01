#Requires -Version 7.0
#Requires -Modules PSSQLite

[CmdletBinding()]
param ()

Add-Type -AssemblyName 'PresentationFramework', 'PresentationCore'

#region Form Data =====================================================================================================
# Note: load and set form data

# copy/paste form XAML into here-string
# replacements performed at end so VS generated XAML does not require further, external modification after export
$xaml = [System.Xml.XmlDocument](@'
<Window x:Name="ExGUIWindow" x:Class="ExGUI.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:ExGUI"
        mc:Ignorable="d"
        Title="ExGUI" Height="260" Width="320" ResizeMode="NoResize" SizeToContent="WidthAndHeight">
    <Grid Height="244" VerticalAlignment="Center" HorizontalAlignment="Left" Width="320">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="423*"/>
            <ColumnDefinition Width="377*"/>
        </Grid.ColumnDefinitions>
        <GroupBox x:Name="GroupBoxAction" Header="Action" HorizontalAlignment="Left" Height="38" Margin="10,10,0,0" VerticalAlignment="Top" Width="300" Grid.ColumnSpan="2">
            <Grid>
                <RadioButton x:Name="RadioButtonQuery" Content="Query" HorizontalAlignment="Left" VerticalAlignment="Top" IsChecked="True" ToolTip="Execute action will query database for Information"/>
                <RadioButton x:Name="RadioButtonUpdate" Content="Update" HorizontalAlignment="Left" Margin="56,0,0,0" VerticalAlignment="Top" ToolTip="Execute action will update database with Information"/>
            </Grid>
        </GroupBox>
        <GroupBox x:Name="GroupBoxInformation" Header="Information" HorizontalAlignment="Left" Height="128" Margin="10,53,0,0" VerticalAlignment="Top" Width="300" Grid.ColumnSpan="2">
            <Grid>
                <Label x:Name="LabelFirstName" Content="First Name:" HorizontalAlignment="Left" VerticalAlignment="Top"/>
                <Label x:Name="LabelLastName" Content="Last Name:" HorizontalAlignment="Left" Margin="0,26,0,0" VerticalAlignment="Top"/>
                <Label x:Name="LabelDOB" Content="DOB:" HorizontalAlignment="Left" Margin="0,52,0,0" VerticalAlignment="Top"/>
                <Label x:Name="LabelAge" Content="Age:" HorizontalAlignment="Left" Margin="0,78,0,0" VerticalAlignment="Top"/>
                <TextBox x:Name="TextBoxFirstName" HorizontalAlignment="Left" Margin="75,4,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="213"/>
                <TextBox x:Name="TextBoxLastName" HorizontalAlignment="Left" Margin="75,30,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="213"/>
                <DatePicker x:Name="DatePickerDOB" HorizontalAlignment="Left" Margin="75,53,0,0" VerticalAlignment="Top" Width="213"/>
                <TextBox x:Name="TextBoxAge" HorizontalAlignment="Left" Margin="75,82,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="213" IsReadOnly="True"/>
            </Grid>
        </GroupBox>
        <Button x:Name="ButtonExecute" Content="Execute" Margin="13,186,0,0" Grid.Column="1" Height="32" VerticalAlignment="Top" HorizontalAlignment="Left" Width="128"/>
        <StatusBar x:Name="StatusBar" HorizontalAlignment="Left" Margin="0,223,0,0" Width="320" Grid.ColumnSpan="2">
            <TextBlock x:Name="TextBlockStatus" TextWrapping="Wrap"/>
        </StatusBar>

    </Grid>
</Window>
'@ -replace 'mc:Ignorable="d"' -replace 'x:N','N' -replace '^<Win.*', '<Window')

$reader = New-Object -TypeName 'System.Xml.XmlNodeReader' -ArgumentList $xaml

try {
    $form = [Windows.Markup.XamlReader]::Load($reader)
} catch {

    Write-Warning -Message "Unable to parse XML, with error: $($Error[0])"
    Write-Warning -Message "Ensure NO SelectionChanged or TextChanged properties on textboxes (PS cannot process them)"

    throw

}

# generate form variables to access/modify elements
$xaml.SelectNodes('//*[@Name]') | ForEach-Object -Process {
    Set-Variable -Name "WPF$($_.Name)" -Value $form.FindName($_.Name) -ErrorAction Stop
}

# timer will eventually be used to keep form responsive
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [timespan]::FromMilliseconds(500)
$timer.Add_Tick({
    Write-Verbose -Message "timer tick"
})

# TODO: remove later - for easy reference while building
Get-Variable -Name 'WPF*' | ForEach-Object -Process {
    Write-Verbose -Message $_.Name
}

#endregion Form Data ==================================================================================================

#region App Functions =================================================================================================
# Note: application functions

# validate form data before submitting query or update
function Test-FormData {
    [CmdletBinding()]
    param (
        [string]$FirstName,
        [string]$LastName,
        [string]$DOB,
        [bool]$Query
    )

    $result = if (-not $FirstName -or -not $LastName) {
        @{ Validation = $false; Message = 'First and Last Name required' }
    } elseif ($Query) {
        @{ Validation = $true; Message = '' }
    } else {

        if (-not $DOB) {
            @{ Validation = $false; Message = 'must specify DOB for entry' }
        } elseif ([datetime]$DOB -gt (Get-Date)){
            @{ Validation = $false; Message = 'DOB cannot be in future' }
        } else {
            @{ Validation = $true; Message = '' }
        }

    }

    $result

}

# queries DB for user info
function Get-ExGUIEntry {
    [CmdletBinding()]
    param (
        [string]$FirstName,
        [string]$LastName
    )

    # sanitize form input
    $FirstName = $FirstName -replace "'", "''"
    $LastName  = $LastName  -replace "'", "''"

    $query = "SELECT * FROM Test WHERE FirstName = '$FirstName' AND LastName = '$LastName'"

    $user = Invoke-SqliteQuery -DataSource "$PSScriptRoot\exdb.db" -Query $query

    $result = if (-not $user) {
        @{ User = $null; Message = "No user found: $FirstName $LastName" }
    } else {
        @{ User = $user; Message = "Found user: $($user.FirstName) $($user.LastName)" }
    }

    $result

}

# inserts or updates new DB entry for user
function Update-ExGUIEntry {
    [CmdletBinding()]
    param (
        [string]$FirstName,
        [string]$LastName,
        [datetime]$DOB,
        [bool]$Update
    )

    # sanitize form input
    $FirstName = $FirstName -replace "'", "''"
    $LastName  = $LastName  -replace "'", "''"

    $query = if ($Update) {
        "UPDATE Test SET DOB = '$($DOB.ToString('MM/dd/yyyy'))'
        WHERE FirstName = '$FirstName' AND LastName = '$LastName'"
    } else {
        "INSERT INTO Test (FirstName,LastName,DOB)
        VALUES ('$FirstName','$LastName','$($DOB.ToString('MM/dd/yyyy'))')"
    }

    try {

        Invoke-SqliteQuery -DataSource "$PSScriptRoot\exdb.db" -Query $query -ErrorAction Stop

        Write-Verbose -Message 'database records updated'

    } catch {
        Write-Warning -Message 'unable to update database, record not created'
    }

}

# given a past [datetime], returns [string] of exact years, months, and days up to now
# NOTE: math on this seems off compared to other online calculators tested against
function Get-Age {
    [CmdletBinding()]
    param (
        [datetime]$DOB
    )

    $age = [datetime]((Get-Date) - $DOB).Ticks

    "$($age.Year - 1)Y, $($age.Month - 1)M, $($age.Day - 1)D"

}

#endregion App Functions ==============================================================================================

#region WPF Events ====================================================================================================
# Note: implement function events for WPF objects

$WPFButtonExecute.Add_Click({

    $firstName = $WPFTextBoxFirstName.Text
    $lastName  = $WPFTextBoxLastName.Text
    $dob       = $WPFDatePickerDOB.SelectedDate

    $result = Test-FormData -FirstName $firstName -LastName $lastName -DOB $dob -Query:$WPFRadioButtonQuery.IsChecked

    $WPFTextBlockStatus.Text = $result.Message

    if (-not $result.Validation) {
        return
    }

    $query = Get-ExGUIEntry -FirstName $firstName -LastName $lastName

    if ($WPFRadioButtonQuery.IsChecked) {

        $WPFTextBlockStatus.Text = $query.Message

        $WPFDatePickerDOB.SelectedDate = $query.User.DOB

        if ($query.User) {
            $WPFTextBoxAge.Text = Get-Age -DOB $query.User.DOB
        } else {
            $WPFTextBoxAge.Text = ''
        }

    } else {

        $update = $false

        if ($query.User) {

            $messagePrompt = [System.Windows.MessageBox]::Show(
                "User [$firstName $lastName] already exists, overwrite entry?",
                'Confirm Entry Overwrite',
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Warning
            )

            if ($messagePrompt -notlike 'Yes') {
                return
            } else {
                $update = $true
            }

        }

        Update-ExGUIEntry -FirstName $firstName -LastName $lastName -DOB $dob -Update:$update

        $WPFTextBlockStatus.Text = "User created: $firstName $lastName"

        $WPFTextBoxAge.Text = Get-Age -DOB $dob

    }

})

$form.add_Loaded({

    $icon = 'AAABAAEAEBAAAAEAIABOAwAAFgAAAIlQTkcNChoKAAAADUlIRFIAAAAQAAAAEAgGAAAAH/P/YQAAAxVJREFUOI1lU89LI2cYfr6ZzNdxMm
    JmxiRGg2CKKRGXhO0pbPcg6KmHIlLBm6eC9FC6l6WX/gV7caF3oR6EQg899bSIrOhSqeLB1EMijRgnP2YSdWaSzHwzX0+RdfvCe3h5n+fh4eF9Ceccn
    xZjTOx0OnnLsnKcc6Lr+lUymfxHkqTwU2zs4yEIAun4+Pi7s7OzH4fD4RwhROCcI4oiyLL8b7FYfFsul3+hlA5HHDJy4DiOvre393u3232ZSqUE13Ux
    GAwQRREURQEA2LaNdDr9YX19/ZuJiYnmo4Dv+3RnZ+ddLBZ74bouJEmCLMsghCCZTMKyLHiehzAMwRgDpfTvzc3Nl7IsewIAHBwc/PDw8PDCcRwYhoF
    EIgFRFFEqlZDL5bC8vIzx8XEkk0lwzjEYDJ7v7+//BACC7/ufnZycvBJFEZIkIZFIwPM8jI2NIZvNghACQggWFhYQhiE0TUMURTg9Pf2+3++rQr1e/x
    LAlCzLmJqagmmaj+QoiqCqKvr9Phhj6PV6MAxjlJ9Wq9W+ipmm+YVt27AsC7quo9frIZvNgjGGarWKWCyGTqeDcrmM6+treJ6HVqsFxhhub2/zQhiGo
    iiKEEXxMe1mswnf93FxcYFarQZKKQRBQLfbRTweB+cc8XgcjDExput63XEcEELQbDaRy+VGSxSLRVBKUa1WcXR0hCAI0O/3H1vX9bowNzd3TCl1MpkM
    Op0OLMuCLMvIZDJQFAWtVguGYaBSqUDTNDQaDWSzWQiCMJyfn38vqKp6v7i4+OvIYqPRgOu6qFQqODw8RBRFmJmZwcrKCmzbRrvdxv39PQqFwm+apjU
    FAFhdXf253W5fq6qKm5sbAMDS0hJmZ2cxOTkJXdfhui4sywLnHEEQNNfW1l4/OeWrq6tn29vbf6bT6WnbtkEpxfT0NBhjuLu7g+/7YIxhOBy2t7a2vs
    7n8389EQAAy7Iyu7u7by4vL79VFEUyDAO2bYMxBs/zgkKh8MfGxsardDpd/98zfVymac6en58vm6b5OeecpFKpWqlUepdKpWqiKD7B/gfXC4XIKZuYV
    gAAAABJRU5ErkJggg==' -replace "[`n ]"

    $bitmap = New-Object -TypeName 'System.Windows.Media.Imaging.BitMapImage'

    $bitmap.BeginInit()
    $bitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($icon)
    $bitmap.EndInit()
    $bitmap.Freeze()

    $form.Icon = $bitmap

    Write-Verbose -Message 'form loaded'

})

$form.Add_Closing({
    Write-Verbose -Message 'gracefully closing form'
})

#endregion WPF Events =================================================================================================

#region Render Form ===================================================================================================
# Note: renders form to screen

$form.ShowDialog() | Out-Null

#endregion Render Form
