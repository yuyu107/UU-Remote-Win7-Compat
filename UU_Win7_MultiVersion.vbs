Option Explicit
' UU Remote Windows 7 control-side compatibility research tool v3.
' Windows 7 SP1 x64: requires only Windows Script Host, MSXML6, ADODB and certutil.
' Patches two confirmed local OS-version checks. Does not change cloud billing,
' account authentication, queue logic, network protocols or drivers.

Const OLD_ORIGINAL = "ef7112e173cdc6d74735c50292cf9750082ce351cdea60dc068fc2b60f3aa92e"
Const OLD_V1       = "98e02310b355aa94feaa0b6b259260065221fb8db2080c097ce35f151e92c284"
Const OLD_V2       = "e3ddd6ca6c291874116a8373ac52801767b5448a3be06230c404c5e7afd2e0db"
Const NEW_ORIGINAL = "8f1390b33bf003c543eab575aea2299d84e25a753ceb92faba751953844ef10a"
Const NEW_V1       = "97ab3d5803cc0dc4040f82f0b1c20a09b7d361824ad0faa7a0e35ece3692c1b3"
Const NEW_V2       = "23c5e9ab91d7a5eb4e4187cf1f384a62a2bab860af6458c1dbacf77ec21aebc2"
' Build C (verified original and patched binary; 64-bit Windows 7 remote-control user-tested).
Const RECENT_ORIGINAL = "8781857cc8d1b0a037853c2132b2982492002c2ae946bd82fd5ab4f2893ab1a3"
Const RECENT_V1       = "0f7d8c4e4b304859f047ab5bd0ea82e4042b93de110ef783efed37ebdad87e4a"
Const RECENT_V2       = "8da352a0c057f2e38c5f21785dafe4e3cab6d284f32209220e2d17b3f48c8751"
Const MAIN_ORIG = "84C0"
Const MAIN_PATCH = "0C01"
Const COMMON_ORIG = "32C0"
Const COMMON_PATCH = "B001"
' Anchors avoid bytes which differ between original and patched files.
Const MAIN_ANCHOR = "0F85E1000000498B4D18488B01FF90A0000000" ' starts 2 bytes after patch point
Const COMMON_ANCHOR = "84C07417837C2420067709750E837C2424027207B0014883C438C3" ' starts 27 bytes before patch point
Const COMMON_TAIL = "4883C438C3"
Const CHUNK_SIZE = 1048576

Dim fso, shell, action, target, backup, stage, swapPath, verifyPath, src, profile, stateNow, srcHash, known
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 2 Then Die "Usage: cscript //nologo UU_Win7_MultiVersion.vbs check|apply|restore GameViewer.exe"
action = LCase(Trim(WScript.Arguments(0)))
If action <> "check" And action <> "apply" And action <> "restore" Then Die "Invalid action: " & action
target = fso.GetAbsolutePathName(Trim(WScript.Arguments(1)))
If LCase(fso.GetFileName(target)) <> "gameviewer.exe" Then Die "Only GameViewer.exe is supported."
If Not fso.FileExists(target) Then Die "File not found: " & target
backup = target & ".Win7Original.bak"  ' also used by previous v1/v2 tools
stage = target & ".Win7V3Stage.tmp"
swapPath = target & ".Win7V3Swap.tmp"
verifyPath = target & ".Win7V3Verify.tmp"
If fso.FileExists(stage) Or fso.FileExists(swapPath) Or fso.FileExists(verifyPath) Then _
    Die "Existing v3 temp/swap file found; please inspect before retrying."

Set src = Inspect(target)
stateNow = src("state")
srcHash = src("sha256")
known = KnownBuild(src)
WScript.Echo "=== UU Win7 compatibility tool v3 - multi-version ==="
WScript.Echo "File: " & target
WScript.Echo "SHA256: " & srcHash
WScript.Echo "Size: " & src("size")
WScript.Echo "State: " & stateNow
WScript.Echo "Profile: " & BuildName(srcHash)
WScript.Echo "Signature main: " & src("mainCount") & " match(es), file offset " & HexOffset(src("main"))
WScript.Echo "Signature common: " & src("commonCount") & " match(es), file offset " & HexOffset(src("common"))
WScript.Echo "Original backup: " & IIfString(fso.FileExists(backup), "present", "not found")
If action = "check" Then
    If stateNow = "UNSUPPORTED" Then WScript.Echo "Result: unsupported/ambiguous build; no changes made."
    If Not known And stateNow <> "UNSUPPORTED" Then WScript.Echo "Result: structurally recognized but unverified build."
    WScript.Quit 0
End If
If stateNow = "UNSUPPORTED" Then Die "Signatures absent, duplicated or unexpected. Refusing to modify."
If action = "apply" Then
    If stateNow = "V2" Then
        WScript.Echo "Already fully patched (v2 equivalent)."
        WScript.Quit 0
    End If
    If Not known Then ConfirmUnknown srcHash
    If fso.FileExists(backup) Then
        CheckBackup src, backup, verifyPath
    Else
        If stateNow <> "ORIGINAL" Then Die "Legacy v1 patch without original backup. Restore original first."
        fso.CopyFile target, backup, False
        If Sha256(backup) <> srcHash Then Die "Original backup SHA256 mismatch. Target untouched."
        WScript.Echo "Backup created: " & backup
    End If
    RewriteToState target, stage, "V2", src("main"), src("common")
    CheckStaged src, stage, "V2"
    ' Revert the staged copy back to its input state and compare the FULL SHA256.
    ' This detects any unintended change outside the two planned instruction bytes.
    RewriteToState stage, verifyPath, stateNow, src("main"), src("common")
    If Sha256(verifyPath) <> srcHash Then Die "Full-file reversibility check failed; target unchanged."
    fso.DeleteFile verifyPath, True
    SwapVerified target, stage, swapPath, Sha256(stage)
    WScript.Echo "SUCCESS: v3 multi-version patch installed. Reopen UU without x64dbg."
    WScript.Echo "Original backup: " & backup
End If
If action = "restore" Then
    If stateNow = "ORIGINAL" Then
        WScript.Echo "Already original."
        WScript.Quit 0
    End If
    If Not fso.FileExists(backup) Then Die "Verified original backup missing. Cannot restore."
    CheckBackup src, backup, verifyPath
    fso.CopyFile backup, stage, False
    If Sha256(stage) <> Sha256(backup) Then Die "Restore staging SHA256 mismatch. Target unchanged."
    SwapVerified target, stage, swapPath, Sha256(stage)
    WScript.Echo "SUCCESS: exact original GameViewer.exe restored."
End If
WScript.Quit 0

Function IIfString(condition, yesValue, noValue)
    If condition Then IIfString = yesValue Else IIfString = noValue
End Function

Function HexOffset(n)
    If n < 0 Then HexOffset = "N/A" Else HexOffset = "0x" & Hex(n)
End Function

Function BuildName(hash)
    Select Case LCase(hash)
        Case OLD_ORIGINAL, OLD_V1, OLD_V2: BuildName = "earlier archive build (known)"
        Case NEW_ORIGINAL, NEW_V1, NEW_V2: BuildName = "Win7-tested build (known)"
        Case RECENT_ORIGINAL, RECENT_V1, RECENT_V2: BuildName = "new Win7-tested build (known)"
        Case Else: BuildName = "other build (structural detection only)"
    End Select
End Function

Function KnownBuild(d)
    Dim h, st
    h = LCase(d("sha256")) : st = d("state")
    KnownBuild = (h = OLD_ORIGINAL And st = "ORIGINAL") Or _
      (h = OLD_V1 And st = "V1") Or (h = OLD_V2 And st = "V2") Or _
      (h = NEW_ORIGINAL And st = "ORIGINAL") Or _
      (h = NEW_V1 And st = "V1") Or (h = NEW_V2 And st = "V2") Or _
      (h = RECENT_ORIGINAL And st = "ORIGINAL") Or _
      (h = RECENT_V1 And st = "V1") Or (h = RECENT_V2 And st = "V2")
End Function

Sub ConfirmUnknown(hash)
    Dim response, expected
    expected = "APPLY " & UCase(Left(hash, 8))
    WScript.Echo "WARNING: no exact-version validation has been performed for this build."
    WScript.Echo "Both unique code signatures matched, but compatibility is NOT guaranteed."
    WScript.Echo "Original EXE signature will be invalidated. The original backup is required."
    WScript.Echo "Type exactly [" & expected & "] to opt into an experimental patch:"
    On Error Resume Next
    response = Trim(WScript.StdIn.ReadLine())
    If Err.Number <> 0 Then
        Err.Clear
        On Error GoTo 0
        Die "Cannot read interactive confirmation. Run from CMD."
    End If
    On Error GoTo 0
    If UCase(response) <> expected Then Die "Cancelled. No changes made."
End Sub

Function HexBytes(bytes)
    Dim doc, el
    Set doc = CreateObject("MSXML2.DOMDocument.6.0")
    Set el = doc.createElement("b")
    el.dataType = "bin.hex"
    el.nodeTypedValue = bytes
    HexBytes = UCase(Replace(Replace(el.text, vbLf, ""), vbCr, ""))
End Function

Function BytesFromHex(h)
    Dim doc, el
    Set doc = CreateObject("MSXML2.DOMDocument.6.0")
    Set el = doc.createElement("b")
    el.dataType = "bin.hex"
    el.text = h
    BytesFromHex = el.nodeTypedValue
End Function

Function ReadHex(s, pos, count)
    s.Position = pos
    ReadHex = HexBytes(s.Read(count))
End Function

Function NumLE(s, pos, count)
    Dim h, i, value
    h = ReadHex(s, pos, count)
    If Len(h) <> count * 2 Then Die "Truncated PE file."
    value = CDbl(0)
    For i = count - 1 To 0 Step -1
        value = value * 256 + CLng("&H" & Mid(h, i * 2 + 1, 2))
    Next
    NumLE = value
End Function

Function GetTextSection(path)
    Dim s, d, pe, sections, opts, magic, sectionTable, i, row, header, rawSize, rawPtr
    Set d = CreateObject("Scripting.Dictionary")
    d.Add "start", -1
    d.Add "length", 0
    Set s = CreateObject("ADODB.Stream")
    s.Type = 1 : s.Open : s.LoadFromFile path
    If s.Size < 1024 Then Die "Not a valid x64 PE executable."
    If ReadHex(s, 0, 2) <> "4D5A" Then Die "MZ signature missing."
    pe = NumLE(s, 60, 4)
    If pe < 64 Or pe > 1048576 Or pe + 256 > s.Size Then Die "Invalid PE header offset."
    If ReadHex(s, pe, 4) <> "50450000" Then Die "PE signature missing."
    If NumLE(s, pe + 4, 2) <> 34404 Then Die "Not a 64-bit AMD64 executable."
    sections = NumLE(s, pe + 6, 2)
    opts = NumLE(s, pe + 20, 2)
    magic = NumLE(s, pe + 24, 2)
    If sections < 1 Or sections > 32 Or magic <> 523 Then Die "Invalid PE64 section table."
    sectionTable = pe + 24 + opts
    For i = 0 To sections - 1
        row = sectionTable + i * 40
        If row + 40 > s.Size Then Die "PE section header truncated."
        header = ReadHex(s, row, 8)
        If Left(header, 10) = "2E74657874" Then
            rawSize = NumLE(s, row + 16, 4)
            rawPtr = NumLE(s, row + 20, 4)
            If rawSize < 1024 Or rawPtr + rawSize > s.Size Then Die "Invalid .text section range."
            d("start") = CLng(rawPtr)
            d("length") = CLng(rawSize)
            Exit For
        End If
    Next
    s.Close
    If d("start") < 0 Then Die "Missing .text section."
    Set GetTextSection = d
End Function

Function ScanAnchor(path, textStart, textLength, needle)
    Dim s, d, curr, textEnd, readLen, scanHex, searchFrom, hit, absolute, added, uniquePos, needleBytes
    Set d = CreateObject("Scripting.Dictionary")
    d.Add "count", 0 : d.Add "offset", -1
    needleBytes = Len(needle) / 2
    textEnd = textStart + textLength
    Set s = CreateObject("ADODB.Stream")
    s.Type = 1 : s.Open : s.LoadFromFile path
    curr = textStart
    Do While curr < textEnd
        readLen = CHUNK_SIZE + 64
        If curr + readLen > textEnd Then readLen = textEnd - curr
        scanHex = ReadHex(s, curr, readLen)
        searchFrom = 1
        Do
            hit = InStr(searchFrom, scanHex, needle, vbBinaryCompare)
            If hit = 0 Then Exit Do
            If ((hit - 1) Mod 2) = 0 Then
                absolute = curr + CLng((hit - 1) / 2)
                If absolute < curr + CHUNK_SIZE And absolute + needleBytes <= textEnd Then
                    d("count") = d("count") + 1
                    d("offset") = absolute
                End If
            End If
            searchFrom = hit + 2
        Loop
        curr = curr + CHUNK_SIZE
    Loop
    s.Close
    Set ScanAnchor = d
End Function

Function Inspect(path)
    Dim d, sec, ma, co, s, mainPos, commonPos, x, y
    Set d = CreateObject("Scripting.Dictionary")
    d.Add "sha256", Sha256(path)
    d.Add "size", fso.GetFile(path).Size
    d.Add "state", "UNSUPPORTED"
    d.Add "main", -1 : d.Add "common", -1
    d.Add "mainCount", 0 : d.Add "commonCount", 0
    Set sec = GetTextSection(path)
    Set ma = ScanAnchor(path, sec("start"), sec("length"), MAIN_ANCHOR)
    Set co = ScanAnchor(path, sec("start"), sec("length"), COMMON_ANCHOR)
    d("mainCount") = ma("count") : d("commonCount") = co("count")
    If ma("count") = 1 And co("count") = 1 Then
        mainPos = ma("offset") - 2
        commonPos = co("offset") + Len(COMMON_ANCHOR) / 2
        If mainPos < sec("start") Or commonPos + 7 > sec("start") + sec("length") Then
            Set Inspect = d : Exit Function
        End If
        Set s = CreateObject("ADODB.Stream")
        s.Type = 1 : s.Open : s.LoadFromFile path
        x = ReadHex(s, mainPos, 2)
        y = ReadHex(s, commonPos, 2)
        If ReadHex(s, commonPos + 2, 5) = COMMON_TAIL Then
            If (x = MAIN_ORIG Or x = MAIN_PATCH) And (y = COMMON_ORIG Or y = COMMON_PATCH) Then
                d("main") = CLng(mainPos)
                d("common") = CLng(commonPos)
                If x = MAIN_ORIG And y = COMMON_ORIG Then d("state") = "ORIGINAL"
                If x = MAIN_PATCH And y = COMMON_ORIG Then d("state") = "V1"
                If x = MAIN_PATCH And y = COMMON_PATCH Then d("state") = "V2"
            End If
        End If
        s.Close
    End If
    Set Inspect = d
End Function

Function Sha256(path)
    Dim exe, cmd, proc, raw, lines, line, v, re, result
    exe = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\certutil.exe"
    If Not fso.FileExists(exe) Then Die "Windows certutil.exe missing."
    cmd = Chr(34) & exe & Chr(34) & " -hashfile " & Chr(34) & path & Chr(34) & " SHA256"
    On Error Resume Next
    Set proc = shell.Exec(cmd)
    If Err.Number <> 0 Then
        v = Err.Description : Err.Clear : On Error GoTo 0
        Die "Cannot run certutil: " & v
    End If
    On Error GoTo 0
    Do While proc.Status = 0
        WScript.Sleep 100
    Loop
    raw = proc.StdOut.ReadAll() & vbLf & proc.StdErr.ReadAll()
    If proc.ExitCode <> 0 Then Die "certutil failed: " & raw
    Set re = CreateObject("VBScript.RegExp")
    re.Pattern = "^[0-9a-f]{64}$" : re.IgnoreCase = True
    result = ""
    lines = Split(Replace(raw, vbCr, ""), vbLf)
    For Each line In lines
        v = LCase(Replace(Replace(Trim(line), " ", ""), vbTab, ""))
        If re.Test(v) Then result = v
    Next
    If result = "" Then Die "Cannot parse certutil SHA256 output."
    Sha256 = result
End Function

Sub RewriteToState(sourcePath, destPath, desired, mainPos, commonPos)
    Dim s
    If fso.FileExists(destPath) Then Die "Temporary destination already exists: " & destPath
    Set s = CreateObject("ADODB.Stream")
    s.Type = 1 : s.Open : s.LoadFromFile sourcePath
    s.Position = mainPos
    If desired = "ORIGINAL" Then s.Write BytesFromHex(MAIN_ORIG) Else s.Write BytesFromHex(MAIN_PATCH)
    s.Position = commonPos
    If desired = "V2" Then s.Write BytesFromHex(COMMON_PATCH) Else s.Write BytesFromHex(COMMON_ORIG)
    s.SaveToFile destPath, 2
    s.Close
End Sub

Sub CheckStaged(before, staged, desired)
    Dim d
    Set d = Inspect(staged)
    If d("state") <> desired Then Die "Staging patch state is not correct. Target unchanged."
    If d("size") <> before("size") Then Die "Staging file size changed. Target unchanged."
    If d("main") <> before("main") Or d("common") <> before("common") Then _
        Die "Staging patch offsets changed. Target unchanged."
    If KnownBuild(before) Then
        Select Case LCase(before("sha256"))
            Case OLD_ORIGINAL, OLD_V1, OLD_V2
                If desired = "V2" And d("sha256") <> OLD_V2 Then Die "Known old-build staged SHA256 mismatch."
            Case NEW_ORIGINAL, NEW_V1, NEW_V2
                If desired = "V2" And d("sha256") <> NEW_V2 Then Die "Known tested-build staged SHA256 mismatch."
            Case RECENT_ORIGINAL, RECENT_V1, RECENT_V2
                If desired = "V2" And d("sha256") <> RECENT_V2 Then Die "Known recent-build staged SHA256 mismatch."
        End Select
    End If
End Sub

Sub CheckBackup(current, backupPath, tempPath)
    Dim orig, tmpHash
    Set orig = Inspect(backupPath)
    If orig("state") <> "ORIGINAL" Then Die "Original backup is invalid, unsupported, or patched."
    If orig("main") <> current("main") Or orig("common") <> current("common") Then Die "Backup is from another build."
    If orig("size") <> current("size") Then Die "Backup size does not match."
    If current("state") = "ORIGINAL" Then
        If orig("sha256") <> current("sha256") Then Die "Existing backup does not match current original EXE."
    Else
        RewriteToState backupPath, tempPath, current("state"), current("main"), current("common")
        tmpHash = Sha256(tempPath)
        fso.DeleteFile tempPath, True
        If tmpHash <> current("sha256") Then Die "Existing backup cannot reproduce current patched EXE."
    End If
End Sub

Sub SwapVerified(dst, staged, swap, stageHash)
    Dim msg, restoreError, got
    On Error Resume Next
    Err.Clear
    fso.MoveFile dst, swap
    If Err.Number <> 0 Then
        msg = Err.Description : Err.Clear : On Error GoTo 0
        Die "Unable to move EXE. Close UU/x64dbg and check permissions: " & msg
    End If
    Err.Clear
    fso.MoveFile staged, dst
    If Err.Number <> 0 Then
        msg = Err.Description : Err.Clear
        fso.MoveFile swap, dst
        restoreError = Err.Description
        If Err.Number <> 0 Then
            On Error GoTo 0
            Die "CRITICAL: manually rename " & swap & " to " & dst & ". " & msg & " / " & restoreError
        End If
        On Error GoTo 0
        Die "Replacement failed; original target put back. " & msg
    End If
    On Error GoTo 0
    got = Sha256(dst)
    If got <> stageHash Then
        On Error Resume Next
        fso.DeleteFile dst, True
        fso.MoveFile swap, dst
        If Err.Number <> 0 Then
            msg = Err.Description : Err.Clear : On Error GoTo 0
            Die "CRITICAL post-write verification: restore manually from " & swap & ": " & msg
        End If
        On Error GoTo 0
        Die "Post-write hash mismatch; prior executable restored."
    End If
    On Error Resume Next
    fso.DeleteFile swap, True
    If Err.Number <> 0 Then WScript.Echo "WARNING: previous EXE retained at " & swap
    On Error GoTo 0
End Sub

Sub Die(message)
    WScript.Echo "ERROR: " & message
    WScript.Quit 1
End Sub
