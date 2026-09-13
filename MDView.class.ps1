using namespace System.Windows.Forms;
using namespace System.Drawing;
using namespace Microsoft.Web.WebView2.Core;
using namespace Microsoft.Web.WebView2.WinForms;

enum ViewMode { SplitView = 1; Editor = 2; Browser = 3; Preview = 4; }

class MDView : Form {
    [IO.FileInfo] $File
    [bool] $Preview
    [Timer] $UpdateTimer
    [IO.FileSystemWatcher] $FileWatcher
    [SplitContainer] $SplitContainer
    [TextBox] $MarkdownTextBox
    [WebView2] $WebView
    [ToolStripStatusLabel] $StatusTitleLabel
    [ToolStripStatusLabel] $StatusModeLabel
    [ordered] $ViewModeMenus
    MDView([string] $aFile, [bool] $aPreview) {
        if ([IO.File]::Exists($aFile)) {
            $this.File = [IO.FileInfo]::new($aFile)
        }
        $this.Preview = $aPreview

        $this.SuspendLayout()
        $this.Text = 'MDView';
        $this.Size = [Size]::new(800, 450);
        $this.MinimumSize = [Size]::new(200, 200);
        $this.Add_Load($this.Form_Load)

        # --------------------------------------------------
        # MenuStrip
        # --------------------------------------------------
        $menuStrip = [MenuStrip]::new();
        $menuStrip.SuspendLayout()

        # ---- File ----
        $fileToolStripMenu = [ToolStripMenuItem]::new('&File', $null, @(
            [ToolStripMenuItem]::new('&Open', $null, $this.OpenMenu_Click, [Keys]::Control -bor [Keys]::O)
            [ToolStripMenuItem]::new('&Save', $null, $this.SaveMenu_Click, [Keys]::Control -bor [Keys]::S)
            [ToolStripSeparator]::new()
            [ToolStripMenuItem]::new('&Quit', $null, $this.QuitMenu_Click, [Keys]::Control -bor [Keys]::Q)
        ))

        # ---- View ----
        $this.ViewModeMenus = [ordered]@{
            SplitView   = New-Object ToolStripMenuItem -ArgumentList @('&SplitView',
                            $null, $this.ViewModeMenu_Click, ([Keys]::Control -bor [Keys]::D1)) -Property @{ Name = 'SplitView' }
            EditorView  = New-Object ToolStripMenuItem -ArgumentList @('&Editor Only',
                            $null, $this.ViewModeMenu_Click, ([Keys]::Control -bor [Keys]::D2)) -Property @{ Name = 'Editor' }
            BrowserView = New-Object ToolStripMenuItem -ArgumentList @('&Browser Only',
                            $null, $this.ViewModeMenu_Click, ([Keys]::Control -bor [Keys]::D3)) -Property @{ Name = 'Browser' }
            PreviewMode = New-Object ToolStripMenuItem -ArgumentList @('&Perview Mode',
                            $null, $this.ViewModeMenu_Click, ([Keys]::Control -bor [Keys]::D4)) -Property @{ Name = 'Perview' }
        }
        $viewToolStripMenu = [ToolStripMenuItem]::new('&View', $null, @(
            [ToolStripMenuItem]::new('&TopMost', $null, $this.TopMostMenu_Click, ([Keys]::Control -bor [Keys]::T))
            [ToolStripSeparator]::new()
            $this.ViewModeMenus.Values
            [ToolStripSeparator]::new()
            [ToolStripMenuItem]::new('&Font', $null, $this.FontMenu_Click)
        ))

        $menuStrip.Items.AddRange(@(
            $fileToolStripMenu,
            $viewToolStripMenu
        ))

        # --------------------------------------------------
        # Main Panels
        # --------------------------------------------------
        $mainPanel = New-Object Panel -Property @{ Dock = [DockStyle]::Fill; Padding = [Padding]::new(3) }
        $mainPanel.SuspendLayout()

        $this.UpdateTimer = New-Object Timer -Property @{ Interval = 500 }

        $this.MarkdownTextBox = New-Object TextBox -Property @{
            Dock = [DockStyle]::Fill;
            Multiline = $true;
            ScrollBars = [Scrollbars]::Vertical;
            WordWrap = $true;
            AllowDrop = $true;
        }
        $this.WebView = New-Object WebView2 -Property @{ Dock = [DockStyle]::Fill; }

        $this.SplitContainer = New-Object SplitContainer -Property @{ Dock = [DockStyle]::Fill; }
        $this.SplitContainer.SuspendLayout()
        $this.SplitContainer.Panel1.Controls.Add($this.MarkdownTextBox)
        $this.SplitContainer.Panel2.Controls.Add($this.WebView)

        $mainPanel.Controls.AddRange($this.SplitContainer)

        # --------------------------------------------------
        # StatusStrip
        # --------------------------------------------------
        $statusStrip = [StatusStrip]::new();
        $this.StatusTitleLabel = [ToolStripStatusLabel]::new()
        $this.StatusModeLabel = [ToolStripStatusLabel]::new('Mode:')
        $statusStrip.Items.AddRange(@($this.StatusModeLabel, $this.StatusTitleLabel))

        $this.Controls.AddRange(@($mainPanel, $menuStrip, $statusStrip));
        $this.SplitContainer.ResumeLayout($false)
        $mainPanel.ResumeLayout($false)
        $menuStrip.ResumeLayout($false)
        $statusStrip.ResumeLayout($false)
        $this.ResumeLayout()
        $this.PerformLayout()
    }

    [void] Form_Load($s, $e) {
        $this.MarkdownTextBox.Add_TextChanged($this.MarkdownTextBox_TextChanged)
        $this.MarkdownTextBox.Add_DragEnter($this.MarkdownTextBox_DragEnter)
        $this.MarkdownTextBox.Add_DragDrop($this.MarkdownTextBox_DragDrop)

        $this.UpdateTimer.Add_Tick($this.UpdateTimer_Tick)

        # Initialize WebView2
        $opts = [CoreWebView2EnvironmentOptions]::new("--allow-file-access-from-files")
        $webViewEnv = [CoreWebView2Environment]::CreateAsync($null, "$PSScriptRoot\webview2_userdata", $opts).Result
        $this.WebView.Add_CoreWebView2InitializationCompleted($this.WebView_InitializationCompleted)
        $this.WebView.Add_NavigationCompleted($this.WebView_NavigationCompleted)
        $this.WebView.EnsureCoreWebView2Async($webViewEnv)
    }
    [void] WebView_InitializationCompleted($s, [CoreWebView2InitializationCompletedEventArgs] $e) {
        if ($e.IsSuccess) {
            $pageUrl = [uri]::new((Join-Path -Path $PSScriptRoot -ChildPath MDView.html))
            $this.WebView.CoreWebView2.Navigate($pageUrl.AbsoluteUri)
            $this.WebView.CoreWebView2.Add_NewWindowRequested($this.WebView_NewWindowRequested)
        } else {
            [MessageBox]::Show(("Failed to initialize WebView2: {0}" -f $e.InitializationException), "Error")
            $this.Dispose()
        }
    }
    [void] WebView_NavigationCompleted($s, [CoreWebView2NavigationCompletedEventArgs] $e) {
        $this.WebView.Remove_NavigationCompleted($this.WebView_NavigationCompleted)
        if ($e.IsSuccess) {
            $mode = [ViewMode]::SplitView
            try {
                if ($this.TryOpenMarkdownFile($null)) {
                    if ($this.Preview) {
                        $mode = [ViewMode]::Preview
                    } else {
                        $mode = [ViewMode]::Browser
                    }
                } else {
                    $this.ViewModeMenus.PreviewMode.Enabled = $false
                }
                $this.TrySwitchMode($mode);
            } catch {
                [MessageBox]::Show(("{0}" -f $_), "Error")
            }
            $this.WebView.Add_NavigationStarting($this.WebView_NavigationStarting)
        } else {
            [MessageBox]::Show(("Failed to Navigate WebView2: {0} {1}" -f $e.WebErrorStatus, $e.HttpStatusCode), "Error")
            $this.Dispose()
        }
    }
    [void] WebView_NewWindowRequested($s, [CoreWebView2NewWindowRequestedEventArgs] $e) {
        $uri = [uri]::new($e.Uri)
        if ($uri.IsFile) {
            $e.Handled = $true
            $fileInfo = [IO.FileInfo]::new($uri.LocalPath)
            if ($fileInfo.Extension -eq ".md") {
                $this.TryOpenMarkdownFile($fileInfo)
            }
        }
    }
    [void] WebView_NavigationStarting($s, [CoreWebView2NavigationStartingEventArgs] $e) {
        $uri = [uri]::new($e.Uri)
        if ($uri.IsFile) {
            $e.Cancel = $true
            $fileInfo = [IO.FileInfo]::new($uri.LocalPath)
            if ($fileInfo.Extension -eq '.md') {
                $this.TryOpenMarkdownFile($fileInfo)
            }
            return
        }
        if ($uri.Scheme -in @('https', 'http')) {
            $e.Cancel = $true
            [System.Diagnostics.Process]::Start($uri.AbsoluteUri)
        }
    }

    [void] OpenMenu_Click($s, $e) {
        $dialog = New-Object OpenFileDialog -Property @{
            Filter = "Markdown files (*.md)|*.md|All files (*.*)|*.*";
            Title = "Open Markdown File";
            InitialDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        }
        if ($dialog.ShowDialog($this.Form) -eq [DialogResult]::OK) {
            $this.TryOpenMarkdownFile([IO.FileInfo]::new($dialog.FileName))
        }
    }
    [void] SaveMenu_Click($s, $e) {
        if ($this.File.Exists) {
            [IO.File]::WriteAllText($this.File, $this.MarkdownTextBox.Text, [Text.Encoding]::UTF8);
            return;
        }

        $saveDialog = New-Object SaveFileDialog -Property @{
            Filter = "Markdown files (*.md)|*.md|All files (*.*)|*.*";
            InitialDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        }
        if ($saveDialog.ShowDialog($this) -eq [DialogResult]::OK) {
            $filePath = $saveDialog.FileName
            [IO.File]::WriteAllText($filePath, $this.MarkdownTextBox.Text, [Text.Encoding]::UTF8);
            $this.File = [IO.FileInfo]::new($filePath)
            $this.UpdateTitle();
        }
    }
    [void] QuitMenu_Click($s, $e) {
        $this.Close()
    }

    [void] TopMostMenu_Click($s, $e) {
        $this.TopMost = -not $this.TopMost;
        $s.Checked = $this.TopMost;
    }

    [void] FontMenu_Click($s, $e) {
        $currentFont = $this.MarkdownTextBox.Font
        $fontDialog = New-Object FontDialog -Property @{
            Font = $currentFont;
        }
        if ($fontDialog.ShowDialog($this) -eq [DialogResult]::OK) {
            $this.MarkdownTextBox.Font = $fontDialog.Font;
        }
    }
    [void] ViewModeMenu_Click($s, $e) {
        if ($s -isnot [ToolStripMenuItem]) { return }
        if ($s.Checked) { return }
        $name = $s.Name;
        $this.TrySwitchMode([ViewMode]::$name)
    }
    [void] MarkdownTextBox_TextChanged($s, $e) {
        $this.UpdateTimer.Stop();
        $this.UpdateTimer.Start();
    }
    [void] MarkdownTextBox_DragEnter($s, [DragEventArgs] $e) {
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
    }
    [void] MarkdownTextBox_DragDrop($s, [DragEventArgs] $e) {
        if ($null -eq $e.Data) { return }
        if ($e.Data.GetDataPresent([DataFormats]::Text)) {
            $text = $e.Data.GetData([DataFormats]::Text) -as [string] ?? [string]::Empty
            $this.MarkdownTextBox.Text = $text
        } elseif ($e.Data.GetDataPresent([DataFormats]::FileDrop)) {
            $files = $e.Data.GetData([DataFormats]::FileDrop) -as [string[]] ?? @()
            foreach ($file in $files) {
                switch -Regex ([IO.Path]::GetExtension($file)) {
                    '\.md$' {
                        $this.TryOpenMarkdownFile([IO.FileInfo]::new($file));
                    }
                    '\.(jpe?g|gif|png|webp|svg)$' {
                        $this.InsertImage($file)
                    }
                }
            }
        }
    }
    [void] UpdateTimer_Tick($s, $e) {
        $this.UpdateTimer.Stop();
        if ($this.Preview -and $this.File) {
            $this.TryOpenMarkdownFile($null)
        } else {
            $this.UpdateView($null)
        }
    }

    [void] StartWatchingFile() {
        if ($null -eq $this.File -or -not $this.File.Exists) { return }
        if ($null -eq $this.FileWatcher) {
            $fsw = [IO.FileSystemWatcher]::new($this.File.DirectoryName, $this.File.Name)
            $fsw.NotifyFilter = [IO.NotifyFilters]::LastWrite;
            $fsw.IncludeSubdirectories = $false;
            $fsw.SynchronizingObject = $this;
            $fsw.EnableRaisingEvents = $true;
            $fsw.Add_Changed($this.FileWatcher_Changed)
            $this.FileWatcher = $fsw;
            $this.ViewModeMenus.PreviewMode.Enabled = $true
        }
    }
    [void] StopWatchingFile() {
        if ($this.FileWatcher) {
            $this.FileWatcher.Dispose()
            $this.FileWatcher = $null
            $this.ViewModeMenus.PreviewMode.Enabled = $false
        }
    }
    [bool] TryOpenMarkdownFile([IO.FileInfo] $aFile) {
        $isFileChanged = $true
        if ($null -eq $aFile) {
            $targetFile = $this.File
            $isFileChanged = $false
        } elseif ($aFile -eq $this.File) {
            $targetFile = $aFile;
            $isFileChanged = $false
        } else {
            $targetFile = $aFile
        }
        if ($null -eq $targetFile -or -not $targetFile.Exists) { return $false }
        $filePath = $targetFile.FullName
        $this.MarkdownTextBox.Lines = [IO.File]::ReadLines($targetFile, [Text.Encoding]::UTF8);
        $this.UpdateView([Uri]::new($filePath).AbsoluteUri);
        $this.File = $targetFile
        if ($isFileChanged) {
            $this.UpdateTitle();
            $this.ViewModeMenus.PreviewMode.Enabled = $true
            if ($this.Preview) {
                $this.StopWatchingFile()
                $this.StartWatchingFile()
            }
        }
        return $true
    }
    [void] UpdateView([string] $baseUri) {
        $html = (ConvertFrom-Markdown -InputObject $this.MarkdownTextBox.Text).Html
        $js = if ([string]::IsNullOrEmpty($baseUri)) { [string]::Empty; } else { "setBaseUrl(`"{0}`");" -f $baseUri; }
        $js += "updateContent(`"{0}`");" -f ($html.Trim() -replace '"','\"' -replace "`n",'\n');
        try {
        $this.WebView.CoreWebView2.ExecuteScriptAsync($js);
        } catch {
            [MessageBox]::Show(("{0}" -f $_), "Error");
        }
    }
    [void] UpdateTitle() {
        if ($null -ne $this.File -and $this.File.Exists) {
            $title = [IO.Path]::GetFileNameWithoutExtension($this.File.FullName)
            $this.Text = 'MDView - {0}' -f $this.File.FullName
            $this.StatusTitleLabel.Text = 'Title: {0}' -f $title
        } else {
            $this.Text = 'MDView'
            $this.StatusTitleLabel.Text = ''
        }
    }

    [void] UpdateStatus() {
        $mode = ($this.ViewModeMenus.Values | Where-Object Checked | Select-Object -First 1).Name
        $this.StatusModeLabel.Text = 'Mode: {0}' -f $mode
        $this.UpdateTitle()
    }

    [bool] TrySwitchMode([ViewMode] $mode) {
        try {
            $this.SplitContainer.SuspendLayout()
            switch ($mode) {
                'SplitView' {
                    $this.SplitContainer.Panel1Collapsed = $false
                    $this.SplitContainer.Panel2Collapsed = $false
                    $this.StopWatchingFile()
                }
                'Editor' {
                    $this.SplitContainer.Panel1Collapsed = $false
                    $this.SplitContainer.Panel2Collapsed = $true
                    $this.StopWatchingFile()
                }
                'Browser' {
                    $this.SplitContainer.Panel1Collapsed = $true
                    $this.SplitContainer.Panel2Collapsed = $false
                    $this.StopWatchingFile()
                }
                'Preview' {
                    if ($null -eq $this.File -or -not $this.File.Exists) { return $false }
                    $this.SplitContainer.Panel1Collapsed = $true
                    $this.SplitContainer.Panel2Collapsed = $false
                    $this.StartWatchingFile()
                }
            }
            foreach ($menuItem in $this.ViewModeMenus.Values) {
                $menuItem.Checked = ($menuItem.Name -eq $mode)
            }
            $this.UpdateStatus()
        } finally {
            $this.SplitContainer.ResumeLayout()
        }
        return $true
    }
    [void] InsertImage([string] $imageFile) {
        $alt = [IO.Path]::GetFileNameWithoutExtension($imageFile)
        $uri = [Uri]::new($imageFile)
        $mdText = "![{0}]({1})`n" -f $alt, $uri.AbsoluteUri
        $selectionStart = $this.MarkdownTextBox.SelectionStart
        $this.MarkdownTextBox.Text =
            $this.MarkdownTextBox.Text.Substring(0, $selectionStart) +
            $mdText +
            $this.MarkdownTextBox.Text.Substring($selectionStart + $this.MarkdownTextBox.SelectionLength);
        $this.MarkdownTextBox.SelectionStart = $selectionStart + $mdText.Length;
        $this.MarkdownTextBox.SelectionLength = 0;
    }
}
