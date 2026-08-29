# PSMarkdownEditor
Simple Markdown editor/viewer for PowerShell 7

<img width="615" height="344" alt="image" src="https://github.com/user-attachments/assets/855c7b29-822b-4109-889d-d2fafdb60047" />

# Setup

```powershell
pwsh -NoProfile -File path\to\setup.ps1
```

1. Download WebView2 package
   - Create directory: `webview2_userdata`
   - Download WebView2 package: `Microsoft.Web.WebView2.nupkg`
   - Extract DLLs to `libs` directory
2. Create shortcut file
   - `MDView.lnk`
   - Can launch the program by drag-&-drop a Markdown file onto this shortcut.
