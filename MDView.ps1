using namespace System.Windows.Forms;
using namespace System.Drawing;
using namespace Microsoft.Web.WebView2.Core;
using namespace Microsoft.Web.WebView2.WinForms;
param(
    [Parameter(Position = 0)]
    [string] $File
)
$ErrorActionPreference = 'Stop';
Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;
Add-Type -Path $PSScriptRoot\libs\Microsoft.Web.WebView2.Core.dll
Add-Type -Path $PSScriptRoot\libs\Microsoft.Web.WebView2.WinForms.dll

$form = New-Object Form -Property @{
    Text = "MDView";
    Size = [Size]::new(800, 450);
    MinimumSize = [Size]::new(200, 200)
}
$form.SuspendLayout()
$menuStrip = [MenuStrip]::new();
$menuStrip.SuspendLayout();
$fileToolStripMenu = New-Object ToolStripMenuItem -Property @{ Text = "&File" }
$openMenu = New-Object ToolStripMenuItem -Property @{ Text = "&Open"; ShortcutKeys = [Keys]::Control -bor [Keys]::O; }
$openMenu.Add_Click({
    $dialog = New-Object OpenFileDialog -Property @{
        Filter = "Markdown files (*.md)|*.md|All files (*.*)|*.*";
        Title = "Open Markdown File";
        InitialDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    }
    if ($dialog.ShowDialog($form) -eq [DialogResult]::OK) {
        OpenMarkdownFile $dialog.FileName
    }
})
$saveMenu = New-Object ToolStripMenuItem -Property @{ Text = "&Save"; ShortcutKeys = [Keys]::Control -bor [Keys]::S; }
$saveMenu.Add_Click({
    if (-not [string]::IsNullOrEmpty($File) -and [IO.File]::Exists($File)) {
        [IO.File]::WriteAllText($File, $markdownTextBox.Text, [Text.Encoding]::UTF8);
        return;
    }

    $saveDialog = New-Object SaveFileDialog -Property @{
        Filter = "Markdown files (*.md)|*.md|All files (*.*)|*.*";
        InitialDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    }
    if ($titleTextBox.Text.Length -gt 0) {
        $saveDialog.FileName = $titleTextBox.Text + ".md";
    }
    if ($saveDialog.ShowDialog($form) -eq [DialogResult]::OK) {
        $File = $saveDialog.FileName
        $title = [IO.Path]::GetFileNameWithoutExtension($File);
        [IO.File]::WriteAllText($File, $markdownTextBox.Text, [Text.Encoding]::UTF8);
        $titleTextBox.Text = $title
    }
})
$quitMenu = New-Object ToolStripMenuItem -Property @{ Text = "&Quit"; ShortcutKeys = [Keys]::Control -bor [Keys]::Q; }
$quitMenu.Add_Click({ $form.Close() })
$fileToolStripMenu.DropDownItems.AddRange(@($openMenu, $saveMenu, [ToolStripSeparator]::new(), $quitMenu))

$viewToolStripMenu = New-Object ToolStripMenuItem -Property @{ Text = "&View" }
$fontMenu = New-Object ToolStripMenuItem -Property @{ Text = '&Font'; }
$fontMenu.Add_Click({
    $currentFont = $markdownTextBox.Font
    $fontDialog = New-Object FontDialog -Property @{
        Font = $currentFont;
    }
    if ($fontDialog.ShowDialog($form) -eq [DialogResult]::OK) {
        $markdownTextBox.Font = $fontDialog.Font;
    }
})
$splitViewMenu = New-Object ToolStripMenuItem -Property @{ Text = '&SplitView'; ShortcutKeys = [Keys]::Control -bor [Keys]::D1; }
$showOnlyEditorMenu = New-Object ToolStripMenuItem -Property @{ Text = 'Show &Editor Only'; ShortcutKeys = [Keys]::Control -bor [Keys]::D2; }
$splitViewMenu.Add_Click({ SwitchViewMode 'SplitView' })
$showOnlyBrowserMenu = New-Object ToolStripMenuItem -Property @{ Text = 'Show &Browser Only'; ShortcutKeys = [Keys]::Control -bor [Keys]::D3; }
$showOnlyEditorMenu.Add_Click({ SwitchViewMode 'Editor' })
$viewToolStripMenu.DropDownItems.AddRange(@($splitViewMenu, $showOnlyEditorMenu, $showOnlyBrowserMenu, [ToolStripSeparator]::new(), $fontMenu))
$showOnlyBrowserMenu.Add_Click({ SwitchViewMode 'Browser' })
$menuStrip.Items.AddRange(@($fileToolStripMenu, $viewToolStripMenu))

$mainPanel = New-Object Panel -Property @{ Dock = [DockStyle]::Fill; Padding = [Padding]::new(3) }
$mainPanel.SuspendLayout()

$titlePanel = New-Object Panel -Property @{ Dock = [DockStyle]::Top; Height = 25; }
$titlePanel.SuspendLayout();
$titleLabel = New-Object Label -Property @{
    Dock = [DockStyle]::Left;
    Size = [Size]::new(30, 25);
    Text = "Title:";
    TextAlign = [ContentAlignment]::MiddleLeft
}
$titleTextBox = New-Object TextBox -Property @{
    Dock = [DockStyle]::Fill;
    Height = 25;
    Multiline = $false;
}
$titlePanel.Controls.Add($titleTextBox)
$titlePanel.Controls.Add($titleLabel);

enum ViewMode { SplitView = 1; Editor = 2; Browser = 3; }
function SwitchViewMode([ViewMode] $Mode) {
    switch ($Mode) {
        'SplitView' {
            if ($splitViewMenu.Checked) { return }
            $splitContainer.Panel1Collapsed = $false;
            $splitContainer.Panel2Collapsed = $false;
            $splitViewMenu.Checked = $true;
            $showOnlyEditorMenu.Checked = $false;
            $showOnlyBrowserMenu.Checked = $false;
        }
        'Editor' {
            if ($showOnlyEditorMenu.Checked) { return }
            $splitContainer.Panel1Collapsed = $false;
            $splitContainer.Panel2Collapsed = $true;
            $splitViewMenu.Checked = $false;
            $showOnlyEditorMenu.Checked = $true;
            $showOnlyBrowserMenu.Checked = $false;
        }
        'Browser' {
            if ($showOnlyBrowserMenu.Checked) { return }
            $splitContainer.Panel1Collapsed = $true;
            $splitContainer.Panel2Collapsed = $false;
            $splitViewMenu.Checked = $false;
            $showOnlyEditorMenu.Checked = $false;
            $showOnlyBrowserMenu.Checked = $true;
        }
    }
}

$markdownTextBox = New-Object TextBox -Property @{
    Dock = [DockStyle]::Fill;
    Multiline = $true;
    ScrollBars = [Scrollbars]::Vertical;
    WordWrap = $true;
    AllowDrop = $true;
}
$markdownTextBox.Add_DragEnter({ param([object] $s, [DragEventArgs] $e)
    if ($null -eq $e.Data) {
        $e.Effect = [DragDropEffects]::None
        return;
    }
    if ($e.Data.GetDataPresent([DataFormats]::Text)) {
        $e.Effect = [DragDropEffects]::Move
    } elseif ($e.Data.GetDataPresent([DataFormats]::FileDrop)) {
        $e.Effect = [DragDropEffects]::Copy
    } else {
        $e.Effect = [DragDropEffects]::None
    }
})
$markdownTextBox.Add_DragDrop({ param([object] $s, [DragEventArgs] $e)
    if ($null -eq $e.Data) { return }
    if ($e.Data.GetDataPresent([DataFormats]::Text)) {
        $text = $e.Data.GetData([DataFormats]::Text) -as [string] ?? [string]::Empty
        $markdownTextBox.Text = $text
    } elseif ($e.Data.GetDataPresent([DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([DataFormats]::FileDrop) -as [string[]] ?? @()
        foreach ($file in $files) {
            switch -Regex ([IO.Path]::GetExtension($file)) {
                '\.md$' { OpenMarkdownFile $file; return }
                '\.(jpe?g|gif|png|webp|svg)$' { InsertImage $file }
            }
        }
    }
})
$webView = New-Object WebView2 -Property @{ Dock = [DockStyle]::Fill; }

$form.Add_Load({
    $opts = [CoreWebView2EnvironmentOptions]::new("--allow-file-access-from-files")
    $webViewEnv = [CoreWebView2Environment]::CreateAsync($null, "$PSScriptRoot\webview2_userdata", $opts).Result
    $webView.Add_CoreWebView2InitializationCompleted({
        param([WebView2] $s, [CoreWebView2InitializationCompletedEventArgs] $e)
        if ($e.IsSuccess) {
            $webView.Add_NavigationCompleted({
                param([WebView2] $s, [CoreWebView2NavigationCompletedEventArgs] $e)
                if ($e.IsSuccess) {
                    OpenMarkdownFile $File
                }
            })
            $pageUrl = [uri]::new((Join-Path -Path $PSScriptRoot -ChildPath MDView.html))
            $s.CoreWebView2.Navigate($pageUrl.AbsoluteUri)
        } else {
            [MessageBox]::Show(("Failed to initialize WebView2: {0}" -f $e.InitializationException))
            $form.Dispose()
        }
    })
    $null = $webView.EnsureCoreWebView2Async($webViewEnv)
})
$markdownTextBox.Add_TextChanged({ UpdateView; })
# $webView = New-Object WebBrowser -Property @{ Dock = [DockStyle]::Fill; Url = $pageUrl; }

$splitContainer = New-Object SplitContainer -Property @{ Dock = [DockStyle]::Fill; }
$splitContainer.SuspendLayout()
$splitContainer.Panel1.Controls.Add($markdownTextBox)
$splitContainer.Panel2.Controls.Add($webView)

$mainPanel.Controls.Add($splitContainer)
$mainPanel.Controls.Add($titlePanel)
$statusStrip = [StatusStrip]::new();
$statusLabel = [ToolStripStatusLabel]::new()
$statusStrip.Items.AddRange($statusLabel)

$form.Controls.AddRange(@($mainPanel, $statusStrip, $menuStrip))

$menuStrip.ResumeLayout($false);
$menuStrip.PerformLayout();
$titlePanel.ResumeLayout($false)
$titlePanel.PerformLayout()
$splitContainer.ResumeLayout($false)
$splitContainer.PerformLayout()
$mainPanel.ResumeLayout($false);
$mainPanel.PerformLayout()
$form.ResumeLayout();
$form.PerformLayout();

function OpenMarkdownFile([string] $markdownFile) {
    if (-not [IO.File]::Exists($markdownFile)) { return }
    $File = $markdownFile
    $titleTextBox.Text = [IO.Path]::GetFileNameWithoutExtension($File);
    $markdownTextBox.Lines = [IO.File]::ReadLines($File, [Text.Encoding]::UTF8);
    UpdateView ([Uri]::new($markdownFile).AbsoluteUri);
    $statusLabel.Text = $File
}
function UpdateView([string] $baseUri) {
    $html = (ConvertFrom-Markdown -InputObject $markdownTextBox.Text).Html
    $js = if ([string]::IsNullOrEmpty($baseUri)) { [string]::Empty; } else { "setBaseUrl(`"{0}`");" -f $baseUri; }
    $js += "updateContent(`"{0}`");" -f ($html.Trim() -replace '"','\"' -replace "`n",'\n');
    $null = $webView.CoreWebView2.ExecuteScriptAsync($js);
}
function InsertImage([string] $imageFile) {
    $alt = [IO.Path]::GetFileNameWithoutExtension($imageFile)
    $uri = [Uri]::new($imageFile)
    $mdText = "![{0}]({1})`n" -f $alt, $uri.AbsoluteUri
    $selectionStart = $markdownTextBox.SelectionStart
    $markdownTextBox.Text =
        $markdownTextBox.Text.Substring(0, $selectionStart) +
        $mdText +
        $markdownTextBox.Text.Substring($selectionStart + $markdownTextBox.SelectionLength);
    $markdownTextBox.SelectionStart = $selectionStart + $mdText.Length;
    $markdownTextBox.SelectionLength = 0;
}

[Application]::Run($form);
