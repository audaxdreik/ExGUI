[CmdletBinding()]
param ()

[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

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
        <StatusBar x:Name="StatusBar" HorizontalAlignment="Left" Height="17" Margin="0,223,0,0" VerticalAlignment="Top" Width="320" Grid.ColumnSpan="2">
            <TextBlock x:Name="TextBlockStatus" TextWrapping="Wrap"/>
        </StatusBar>

    </Grid>
</Window>
'@ -replace 'mc:Ignorable="d"' -replace 'x:N','N' -replace '^<Win.*', '<Window')

$reader = New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml

try {
    $form = [Windows.Markup.XamlReader]::Load($reader)
} catch {

    Write-Warning -Message "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"

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

# load some test data, will be replaced by SQL connection later
function Get-TestData {
    [CmdletBinding()]
    param ()

    # ignore this scoped variable for now
    $script:users = Get-ChildItem -Path '.\sample' | ForEach-Object -Process {
        Get-Content -Path $_.FullName | ConvertFrom-Json
    }

}

# validate form data before submitting query or update
function Test-FormData {
    [CmdletBinding()]
    param ()

    $validation = if ((-not $WPFTextBoxFirstName.Text) -or (-not $WPFTextBoxLastName.Text)) {

        $WPFTextBlockStatus.Text = 'First and Last Name required'

        $false

    } elseif ($WPFRadioButtonQuery.IsChecked) {
        $true
    } else {

        if (-not $WPFDatePickerDOB.SelectedDate) {

            $WPFTextBlockStatus.Text = 'Must have DOB selected'

            $false

        } else {

            if ($WPFDatePickerDOB.SelectedDate -gt (Get-Date)) {

                $WPFTextBlockStatus.Text = 'DOB cannot be in future'

                $false

            } else {
                $true
            }

        }

    }

    $validation

}

function Update-ExGUIEntry {
    [CmdletBinding()]
    param ()

    $firstName = $WPFTextBoxFirstName.Text
    $lastName  = $WPFTextBoxLastName.Text

    $data = @{
        FirstName = $firstName
        LastName  = $lastName
        DOB       = $WPFDatePickerDOB.SelectedDate.ToString('MM/dd/yyyy')
    }

    $data | ConvertTo-Json -Compress | Set-Content -Path ".\sample\$firstName$lastName.json"

}

# the math on this seems off compared to other online calculators tested against
function Get-Age {
    [CmdletBinding()]
    param ()

    $age = [datetime]((Get-Date) - $WPFDatePickerDOB.SelectedDate).Ticks

    $WPFTextBoxAge.Text = "$($age.Year - 1)Y, $($age.Month - 1)M, $($age.Day - 1)D"

}

#endregion App Functions ==============================================================================================

#region WPF Events ====================================================================================================
# Note: implement function events for WPF objects

$WPFButtonExecute.Add_Click({

    if (-not (Test-FormData)) {

        Write-Verbose -Message 'form data could not be validated'

        return

    }

    if ($WPFRadioButtonQuery.IsChecked) {

        $user = $script:users | Where-Object -FilterScript {
            ($_.FirstName -match $WPFTextBoxFirstName.Text) -and ($_.LastName -match $WPFTextBoxLastName.Text)
        }

        if ($user) {

            $WPFTextBlockStatus.Text = "Found user: $($user.FirstName) $($user.LastName)"

            $WPFDatePickerDOB.SelectedDate = $user.DOB

            Get-Age

        } else {
            $WPFTextBlockStatus.Text = "No user found: $($WPFTextBoxFirstName.Text) $($WPFTextBoxLastName.Text)"
        }

    } else {

        Update-ExGUIEntry

        Get-Age

        $WPFTextBlockStatus.Text = "User created: $($WPFTextBoxFirstName.Text) $($WPFTextBoxLastName.Text)"

    }

})

$form.Add_ContentRendered({

    Write-Verbose -Message 'form loaded, checking content'

    Get-TestData

})

$form.Add_Closing({
    Write-Verbose -Message 'gracefully closing form'
})

#endregion WPF Events =================================================================================================

#region Render Form ===================================================================================================
# Note: renders form to screen

$form.ShowDialog() | Out-Null

#endregion Render Form
