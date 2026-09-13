# PSMarkdownEditor
Simple Markdown editor/viewer for PowerShell 7

<img width="786" height="443" alt="image" src="https://github.com/user-attachments/assets/3bbce5a1-53e7-4770-948b-780c74fdc6e5" />

Menus:

<img width="148" height="126" alt="File Menu" src="https://github.com/user-attachments/assets/5894f326-3b2b-4a9d-8c07-f8cebedfe6a4" /> 
<img width="192" height="172" alt="View Menu" src="https://github.com/user-attachments/assets/bde9da28-3b0f-42f8-8a35-218bcf62a45c" />

# Requirements

- Windows 11
- PowerShell 7.6

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
