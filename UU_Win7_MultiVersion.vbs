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
If WScript.Arguments.Count < 2 Then Die ZH("4F7F752865B96CD5FF1A00630073006300720069007000740020002F002F006E006F006C006F0067006F002000550055005F00570069006E0037005F004D0075006C0074006900560065007200730069006F006E002E00760062007300200063006800650063006B007C006100700070006C0079007C0072006500730074006F00720065002000470061006D0065005600690065007700650072002E006500780065")
action = LCase(Trim(WScript.Arguments(0)))
If action <> "check" And action <> "apply" And action <> "restore" Then Die ZH("65E0654864CD4F5CFF1A") & action
target = fso.GetAbsolutePathName(Trim(WScript.Arguments(1)))
If LCase(fso.GetFileName(target)) <> "gameviewer.exe" Then Die ZH("53EA80FD59047406002000470061006D0065005600690065007700650072002E0065007800653002")
If Not fso.FileExists(target) Then Die ZH("627E4E0D523065874EF6FF1A") & target
' Avoid modifying the small launcher in the installation root.
' Never auto-pick a candidate: the user must inspect the selected versioned EXE first.
If IsInstallerRootLauncher(target) Then
    ShowVersionedExecutableHints target
    WScript.Quit 2
End If
backup = target & ".Win7Original.bak"  ' also used by previous v1/v2 tools
stage = target & ".Win7V3Stage.tmp"
swapPath = target & ".Win7V3Swap.tmp"
verifyPath = target & ".Win7V3Verify.tmp"
If fso.FileExists(stage) Or fso.FileExists(swapPath) Or fso.FileExists(verifyPath) Then _
    Die ZH("68C06D4B52304E0A6B2164CD4F5C75594E0B76844E3465F665874EF6FF0C8BF7514868C067E55E7659047406540E518D91CD8BD53002")

Set src = Inspect(target)
stateNow = src("state")
srcHash = src("sha256")
known = KnownBuild(src)
WScript.Echo "=== " & ZH("7F51661300200055005500208FDC7A0B002000570069006E0064006F00770073002000370020517C5BB988654E01002000760033002E0031002E0030FF087B804F534E2D6587FF09") & " ==="
WScript.Echo "File: " & target & "  (" & ZH("76EE68077A0B5E8F") & ")"
WScript.Echo "SHA256: " & srcHash
WScript.Echo "Size: " & src("size") & " " & ZH("5B578282")
WScript.Echo "State: " & stateNow & "  (" & StateName(stateNow) & ")"
WScript.Echo "Profile: " & BuildName(srcHash)
WScript.Echo "Signature main: " & src("mainCount") & " match(es), file offset " & HexOffset(src("main")) & "  (" & ZH("8FDC63A7516553E368C067E5") & ")"
WScript.Echo "Signature common: " & src("commonCount") & " match(es), file offset " & HexOffset(src("common")) & "  (" & ZH("516C51717CFB7EDF7248672C68C067E5") & ")"
WScript.Echo "Original backup: " & IIfString(fso.FileExists(backup), ZH("5DF25B585728"), ZH("5C1A672A521B5EFA"))
If action = "check" Then
    If stateNow = "UNSUPPORTED" Then WScript.Echo "Result: " & ZH("72795F817F3A5931300191CD590D621663074EE44E0D7B2654089884671FFF1B672A4FEE653965874EF63002")
    If Not known And stateNow <> "UNSUPPORTED" Then WScript.Echo "Result: " & ZH("72795F815339914DFF0C4F468BE565874EF654C85E0C5C1A672A767B8BB030024FEE886565F65C065F3951FA786E8BA47A9753E33002")
    WScript.Quit 0
End If
If stateNow = "UNSUPPORTED" Then Die ZH("68C067E572795F814E0D7B26540889816C42FF0C5DF262D27EDD4FEE653930028BF7786E8BA4900962E97684662F7248672C5B5076EE5F554E2D76845BA262377AEF4E3B4F53FF0C800C975E683976EE5F55542F52A856683002")
If action = "apply" Then
    If stateNow = "V2" Then
        WScript.Echo ZH("5F53524D65874EF65DF25B8C65744FEE8865FF0800560032FF09FF0C4E0D9700898191CD590D64CD4F5C3002")
        WScript.Quit 0
    End If
    If Not known Then ConfirmUnknown srcHash
    If fso.FileExists(backup) Then
        CheckBackup src, backup, verifyPath
    Else
        If stateNow <> "ORIGINAL" Then Die ZH("53D173B065E77248002000560031002088654E01FF0C4F466CA16709539F724859074EFD30028BF751486062590D539F59CB65874EF63002")
        fso.CopyFile target, backup, False
        If Sha256(backup) <> srcHash Then Die ZH("539F724859074EFD76840020005300480041002D003200350036002068219A8C59318D25FF0C672A4FEE653976EE680765874EF63002")
        WScript.Echo ZH("5DF259074EFD539F724865874EF6FF1A") & backup
    End If
    RewriteToState target, stage, "V2", src("main"), src("common")
    CheckStaged src, stage, "V2"
    ' Revert the staged copy back to its input state and compare the FULL SHA256.
    ' This detects any unintended change outside the two planned instruction bytes.
    RewriteToState stage, verifyPath, stateNow, src("main"), src("common")
    If Sha256(verifyPath) <> srcHash Then Die ZH("5B8C657465874EF6768453EF9006602768219A8C59318D25FF0C76EE680765874EF6672A4FEE65393002")
    fso.DeleteFile verifyPath, True
    SwapVerified target, stage, swapPath, Sha256(stage)
    WScript.Echo ZH("4FEE88656210529FFF018BF7517395ED8C038BD55668540E91CD65B0542F52A800200055005500208FDC7A0B8FDB884C6D4B8BD53002")
    WScript.Echo ZH("539F724859074EFDFF1A") & backup
End If
If action = "restore" Then
    If stateNow = "ORIGINAL" Then
        WScript.Echo ZH("5F53524D65874EF65DF27ECF662F539F7248FF0C65E097006062590D3002")
        WScript.Quit 0
    End If
    If Not fso.FileExists(backup) Then Die ZH("627E4E0D52305DF29A8C8BC17684539F724859074EFDFF0C65E06CD56062590D3002")
    CheckBackup src, backup, verifyPath
    fso.CopyFile backup, stage, False
    If Sha256(stage) <> Sha256(backup) Then Die ZH("6062590D66825B5865874EF676840020005300480041002D003200350036002068219A8C59318D25FF0C76EE680765874EF6672A4FEE65393002")
    SwapVerified target, stage, swapPath, Sha256(stage)
    WScript.Echo ZH("6062590D6210529FFF015DF26309539F724859074EFD8FD8539F002000470061006D0065005600690065007700650072002E0065007800653002")
End If
WScript.Quit 0

' Windows 7 WSH may not parse UTF-8 VBScript literals reliably.
' Store Simplified Chinese text as UTF-16 code units in ASCII source for portability.
Function ZH(code)
    Dim n, i, t
    t = ""
    For i = 1 To Len(code) Step 4
        n = CLng("&H" & Mid(code, i, 4))
        If n > 32767 Then n = n - 65536
        t = t & ChrW(n)
    Next
    ZH = t
End Function

Function StateName(state)
    Select Case state
        Case "ORIGINAL": StateName = ZH("539F7248FF0C5C1A672A4FEE8865")
        Case "V1": StateName = ZH("5DF24FEE65398FDC63A7516553E368C067E5")
        Case "V2": StateName = ZH("4E244E2A68C067E570B95DF24FEE8865")
        Case Else: StateName = ZH("65E06CD55B8951688BC6522BFF0C62D27EDD4FEE6539")
    End Select
End Function

' A frequent mistake is selecting ...\\Netease\\GameViewer\\GameViewer.exe
' (about 10 MB in the tested installation) instead of its version subfolder's
' GameViewer.exe (about 70 MB). Sizes are only hints, not validity criteria.
Function IsInstallerRootLauncher(path)
    Dim folderPath, parentName, grandParentName, subFolder, candidate, hasVersionExe
    IsInstallerRootLauncher = False
    folderPath = fso.GetParentFolderName(path)
    parentName = LCase(fso.GetFileName(folderPath))
    If parentName <> "gameviewer" Then Exit Function
    ' A versioned client can vary in size. Only flag the observed small root launcher.
    If fso.GetFile(path).Size >= 20971520 Then Exit Function
    grandParentName = LCase(fso.GetFileName(fso.GetParentFolderName(folderPath)))
    hasVersionExe = False
    For Each subFolder In fso.GetFolder(folderPath).SubFolders
        candidate = fso.BuildPath(subFolder.Path, "GameViewer.exe")
        If fso.FileExists(candidate) Then
            hasVersionExe = True
            Exit For
        End If
    Next
    If grandParentName = "netease" Or hasVersionExe Then IsInstallerRootLauncher = True
End Function

Sub ShowVersionedExecutableHints(launcher)
    Dim rootFolder, subFolder, candidate, count
    rootFolder = fso.GetParentFolderName(launcher)
    WScript.Echo "ERROR: " & ZH("4F6090094E2D4E865B8988C576EE5F55683990E87684002000470061006D0065005600690065007700650072002E006500780065FF0C5B835F8853EF80FD53EA662F542F52A85668FF0C4E0D80FD752867654FEE88653002")
    WScript.Echo ZH("5F53524D65874EF659275C0FFF1A") & fso.GetFile(launcher).Size & " " & ZH("5B57828230025DF2505C6B6264CD4F5CFF0C65874EF66CA1670988AB4FEE65393002")
    WScript.Echo ZH("8BF7653990094E0B65B97248672C5B5076EE5F554E2D7684002000470061006D0065005600690065007700650072002E006500780065FF085B9E964576EE5F55540D79F053EF80FD4E0D540CFF09FF1A")
    count = 0
    For Each subFolder In fso.GetFolder(rootFolder).SubFolders
        candidate = fso.BuildPath(subFolder.Path, "GameViewer.exe")
        If fso.FileExists(candidate) Then
            count = count + 1
            If count <= 15 Then WScript.Echo "  [" & count & "] " & candidate & "  (" & fso.GetFile(candidate).Size & " " & ZH("5B578282") & ")"
        End If
    Next
    If count = 0 Then WScript.Echo ZH("672A57284E007EA75B5076EE5F554E2D627E52305019900965874EF630028BF7572800200055005500208FDC7A0B5B8988C565874EF659394E2D7EE77EED67E5627E3002")
    If count > 15 Then WScript.Echo ZH("501990098F83591AFF0C4EC5521751FA524D00200031003500204E2A3002")
    WScript.Echo ZH("51485C0690094E2D76845019900965874EF662D6523000200043006800650063006B005F00570069006E0037002E0063006D0064FF0C68C067E50020005300740061007400650020662F54264E3A0020004F0052004900470049004E0041004C30010056003100206216002000560032FF0C4E144E2498790020005300690067006E0061007400750072006500205339914D657057474E3A002000313002")
    WScript.Echo ZH("82E56709591A4E2A7248672C76EE5F55FF0C8BF7786E8BA400200055005500208FDC7A0B5F53524D5B9E96454F7F752876847248672CFF1B520752FF76F276EE4FEE8865624067095019900965874EF63002")
End Sub

Function IIfString(condition, yesValue, noValue)
    If condition Then IIfString = yesValue Else IIfString = noValue
End Function

Function HexOffset(n)
    If n < 0 Then HexOffset = "N/A" Else HexOffset = "0x" & Hex(n)
End Function

Function BuildName(hash)
    Select Case LCase(hash)
        Case OLD_ORIGINAL, OLD_V1, OLD_V2: BuildName = ZH("5DF2767B8BB067845EFA00200041")
        Case NEW_ORIGINAL, NEW_V1, NEW_V2: BuildName = ZH("5DF2767B8BB067845EFA00200042FF0800570069006E003700205DF25B9E6D4BFF09")
        Case RECENT_ORIGINAL, RECENT_V1, RECENT_V2: BuildName = ZH("5DF2767B8BB067845EFA00200043FF0800570069006E003700205DF25B9E6D4BFF09")
        Case Else: BuildName = ZH("672A767B8BB067845EFAFF084EC57ED367848BC6522BFF09")
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
    ' The default is No; no checksum typing is required for structurally recognized builds.
    Dim response, question
    WScript.Echo ZH("63D0793AFF1A6B645BA262377AEF7248672C768454C85E0C5C1A672A767B8BB0FF0C4F464E2459044EE3780168C067E572795F815747552F4E005339914D3002")
    WScript.Echo ZH("672A77E567845EFA5E764E0D4FDD8BC14E005B9A517C5BB9FF0C5EFA8BAE786E8BA465874EF667656E905E764FDD7559539F724859074EFD3002")
    question = ZH("68C06D4B5230672A767B8BB07248672CFF0C4F464E2459044EE3780172795F817B2654089884671F3002") & vbCrLf & vbCrLf & _
        ZH("7EE77EED5C0681EA52A859074EFD539F72480020004500580045FF0C5E765C1D8BD54FEE88653002") & vbCrLf & _
        ZH("4FEE8865540E65874EF67684539F670965705B577B7E540D4F1A593165483002") & vbCrLf & vbCrLf & _
        ZH("662F54267EE77EEDFF1FFF089ED88BA4900962E9201C5426201DFF09")
    response = MsgBox(question, vbYesNo + vbQuestion + vbDefaultButton2, ZH("0055005500208FDC7A0B002000570069006E00370020517C5BB988654E010020002D0020672A77E57248672C786E8BA4"))
    If response <> vbYes Then Die ZH("752862375DF253D66D88FF0C76EE680765874EF6672A4FEE65393002")
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
    If Len(h) <> count * 2 Then Die ZH("00500045002065874EF66570636E4E0D5B8C65743002")
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
    If s.Size < 1024 Then Die ZH("8FD94E0D662F67096548768400200036003400204F4D00200050004500207A0B5E8F3002")
    If ReadHex(s, 0, 2) <> "4D5A" Then Die ZH("65874EF67F3A5C110020004D005A002068078BB03002")
    pe = NumLE(s, 60, 4)
    If pe < 64 Or pe > 1048576 Or pe + 256 > s.Size Then Die ZH("00500045002065874EF65934504F79FB65E065483002")
    If ReadHex(s, pe, 4) <> "50450000" Then Die ZH("65874EF67F3A5C11002000500045002068078BB03002")
    If NumLE(s, pe + 4, 2) <> 34404 Then Die ZH("8BE57A0B5E8F4E0D662F0020007800360034FF080036003400204F4DFF097A0B5E8FFF1B0033003200204F4D7CFB7EDF4E0D53D7652F63013002")
    sections = NumLE(s, pe + 6, 2)
    opts = NumLE(s, pe + 20, 2)
    magic = NumLE(s, pe + 24, 2)
    If sections < 1 Or sections > 32 Or magic <> 523 Then Die ZH("0036003400204F4D00200050004500208282886865E065483002")
    sectionTable = pe + 24 + opts
    For i = 0 To sections - 1
        row = sectionTable + i * 40
        If row + 40 > s.Size Then Die ZH("005000450020828288686570636E4E0D5B8C65743002")
        header = ReadHex(s, row, 8)
        If Left(header, 10) = "2E74657874" Then
            rawSize = NumLE(s, row + 16, 4)
            rawPtr = NumLE(s, row + 20, 4)
            If rawSize < 1024 Or rawPtr + rawSize > s.Size Then Die ZH("002E007400650078007400204EE378018282830356F465E065483002")
            d("start") = CLng(rawPtr)
            d("length") = CLng(rawSize)
            Exit For
        End If
    Next
    s.Close
    If d("start") < 0 Then Die ZH("627E4E0D52300020002E007400650078007400204EE3780182823002")
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
    If Not fso.FileExists(exe) Then Die ZH("627E4E0D52307CFB7EDF81EA5E26768400200063006500720074007500740069006C002E0065007800653002")
    cmd = Chr(34) & exe & Chr(34) & " -hashfile " & Chr(34) & path & Chr(34) & " SHA256"
    On Error Resume Next
    Set proc = shell.Exec(cmd)
    If Err.Number <> 0 Then
        v = Err.Description : Err.Clear : On Error GoTo 0
        Die ZH("65E06CD58FD0884C00200063006500720074007500740069006CFF1A") & v
    End If
    On Error GoTo 0
    Do While proc.Status = 0
        WScript.Sleep 100
    Loop
    raw = proc.StdOut.ReadAll() & vbLf & proc.StdErr.ReadAll()
    If proc.ExitCode <> 0 Then Die ZH("0063006500720074007500740069006C00206267884C59318D25FF1A") & raw
    Set re = CreateObject("VBScript.RegExp")
    re.Pattern = "^[0-9a-f]{64}$" : re.IgnoreCase = True
    result = ""
    lines = Split(Replace(raw, vbCr, ""), vbLf)
    For Each line In lines
        v = LCase(Replace(Replace(Trim(line), " ", ""), vbTab, ""))
        If re.Test(v) Then result = v
    Next
    If result = "" Then Die ZH("65E06CD589E3679000200063006500720074007500740069006C002076840020005300480041002D00320035003600207ED3679C3002")
    Sha256 = result
End Function

Sub RewriteToState(sourcePath, destPath, desired, mainPos, commonPos)
    Dim s
    If fso.FileExists(destPath) Then Die ZH("66825B5865874EF65DF25B585728FF0C8BF7514868C067E5FF1A") & destPath
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
    If d("state") <> desired Then Die ZH("66825B58526F672C768488654E0172B660014E0D6B63786EFF0C76EE680765874EF6672A4FEE65393002")
    If d("size") <> before("size") Then Die ZH("66825B5865874EF6768459275C0F53D1751F53D85316FF0C76EE680765874EF6672A4FEE65393002")
    If d("main") <> before("main") Or d("common") <> before("common") Then _
        Die ZH("66825B5865874EF6768488654E014F4D7F6E53D1751F53D85316FF0C76EE680765874EF6672A4FEE65393002")
    If KnownBuild(before) Then
        Select Case LCase(before("sha256"))
            Case OLD_ORIGINAL, OLD_V1, OLD_V2
                If desired = "V2" And d("sha256") <> OLD_V2 Then Die ZH("5DF2767B8BB067845EFA002000410020768488654E0154C85E0C68219A8C59318D253002")
            Case NEW_ORIGINAL, NEW_V1, NEW_V2
                If desired = "V2" And d("sha256") <> NEW_V2 Then Die ZH("5DF2767B8BB067845EFA002000420020768488654E0154C85E0C68219A8C59318D253002")
            Case RECENT_ORIGINAL, RECENT_V1, RECENT_V2
                If desired = "V2" And d("sha256") <> RECENT_V2 Then Die ZH("5DF2767B8BB067845EFA002000430020768488654E0154C85E0C68219A8C59318D253002")
        End Select
    End If
End Sub

Sub CheckBackup(current, backupPath, tempPath)
    Dim orig, tmpHash
    Set orig = Inspect(backupPath)
    If orig("state") <> "ORIGINAL" Then Die ZH("59074EFD4E0D662F670965487684539F724865874EF6FF0C62D27EDD6062590D3002")
    If orig("main") <> current("main") Or orig("common") <> current("common") Then Die ZH("59074EFD5C5E4E8E51764ED667845EFAFF0C4E0D80FD6DF775283002")
    If orig("size") <> current("size") Then Die ZH("59074EFD65874EF659275C0F4E0D5339914D3002")
    If current("state") = "ORIGINAL" Then
        If orig("sha256") <> current("sha256") Then Die ZH("73B0670959074EFD4E0E5F53524D539F724865874EF64E0D4E0081F43002")
    Else
        RewriteToState backupPath, tempPath, current("state"), current("main"), current("common")
        tmpHash = Sha256(tempPath)
        fso.DeleteFile tempPath, True
        If tmpHash <> current("sha256") Then Die ZH("73B0670959074EFD65E06CD57CBE786E8FD8539F5F53524D88654E0172B660013002")
    End If
End Sub

Sub SwapVerified(dst, staged, swap, stageHash)
    Dim msg, restoreError, got
    On Error Resume Next
    Err.Clear
    fso.MoveFile dst, swap
    If Err.Number <> 0 Then
        msg = Err.Description : Err.Clear : On Error GoTo 0
        Die ZH("65E06CD579FB52A80020004500580045FF1B8BF7517395ED00200055005500208FDC7A0B53CA8C038BD55668FF0C5E7668C067E567439650FF1A") & msg
    End If
    Err.Clear
    fso.MoveFile staged, dst
    If Err.Number <> 0 Then
        msg = Err.Description : Err.Clear
        fso.MoveFile swap, dst
        restoreError = Err.Description
        If Err.Number <> 0 Then
            On Error GoTo 0
            Die ZH("4E2591CD95198BEFFF1A8BF7624B52A891CD547D540D0020") & swap & " to " & dst & ZH("300295198BEFFF1A") & msg & " / " & restoreError
        End If
        On Error GoTo 0
        Die ZH("65874EF666FF636259318D25FF0C5DF2653E56DE539F65874EF63002") & msg
    End If
    On Error GoTo 0
    got = Sha256(dst)
    If got <> stageHash Then
        On Error Resume Next
        fso.DeleteFile dst, True
        fso.MoveFile swap, dst
        If Err.Number <> 0 Then
            msg = Err.Description : Err.Clear : On Error GoTo 0
            Die ZH("4E2591CD95198BEFFF1A51995165540E768468219A8C59318D25FF0C8BF7624B52A84ECE4EE54E0B65874EF66062590DFF1A") & swap & ": " & msg
        End If
        On Error GoTo 0
        Die ZH("51995165540E54C85E0C4E0D4E0081F4FF0C5DF26062590D5148524D7A0B5E8F3002")
    End If
    On Error Resume Next
    fso.DeleteFile swap, True
    If Err.Number <> 0 Then WScript.Echo ZH("8B66544AFF1A4E0A4E006B217A0B5E8F65874EF64FDD75595728FF1A") & swap
    On Error GoTo 0
End Sub

Sub Die(message)
    WScript.Echo ZH("95198BEFFF1A") & message
    WScript.Quit 1
End Sub
