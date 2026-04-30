# Canvas Build - Module 1 Week 4 Addendum
# Adds missing Week 4 items (4.4, 4.5, 4.6, 4.7) to the existing module
# PowerShell 5.1

$token    = "6936~DT7Yk4T963keRVfXnnzDAumnf9FyfWV76hBXMuntLrxUTB7RTTYUnRDtrtXnLz9F"
$baseUrl  = "https://k12.instructure.com"
$courseId = 2432642
$root     = "C:\Users\JessicaDrexel\OneDrive - OptimaEd\ELA\7th Grade ELA\ela-grade7-2025-2026\module-1-odyssey"

$authHdr  = @{ "Authorization" = "Bearer $token" }
$jsonHdr  = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$script:errors = @()

Write-Host "=== Canvas Build: Module 1 Week 4 Addendum ===" -ForegroundColor Cyan

# --------------------------------------------------
# HELPERS
# --------------------------------------------------

function Invoke-FormPost {
    param([string]$ep, [string]$form)
    try {
        $r = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/v1$ep" -Headers $authHdr -Body $form -ContentType "application/x-www-form-urlencoded"
        Start-Sleep -Milliseconds 400
        return $r
    } catch {
        $msg = "POST $ep : $_"
        Write-Host "  ERROR: $msg" -ForegroundColor Red
        $script:errors += $msg
        return $null
    }
}

function Invoke-JsonPost {
    param([string]$ep, [hashtable]$obj)
    try {
        $body = $obj | ConvertTo-Json -Depth 10
        $r = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/v1$ep" -Headers $jsonHdr -Body $body
        Start-Sleep -Milliseconds 400
        return $r
    } catch {
        $msg = "POST $ep : $_"
        Write-Host "  ERROR: $msg" -ForegroundColor Red
        $script:errors += $msg
        return $null
    }
}

function New-Assignment {
    param([string]$title, [string]$body, [int]$pts, [string[]]$subTypes)
    Write-Host "  Assignment: $title ($pts pts)" -ForegroundColor White
    $subStr = ($subTypes | ForEach-Object { "assignment[submission_types][]=" + [System.Uri]::EscapeDataString($_) }) -join "&"
    $form = "assignment[name]="            + [System.Uri]::EscapeDataString($title) +
            "&assignment[description]="    + [System.Uri]::EscapeDataString($body) +
            "&assignment[points_possible]=$pts" +
            "&assignment[grading_type]=pass_fail" +
            "&assignment[published]=true" +
            "&$subStr"
    return Invoke-FormPost "/courses/$courseId/assignments" $form
}

function New-Quiz {
    param([string]$title, [string]$desc, [int]$pts)
    Write-Host "  Quiz: $title ($pts pts)" -ForegroundColor White
    $body = @{ quiz = @{
        title                = $title
        description          = $desc
        quiz_type            = "assignment"
        points_possible      = $pts
        allowed_attempts     = 1
        shuffle_answers      = $true
        show_correct_answers = $true
        published            = $false
    } } | ConvertTo-Json -Depth 10
    try {
        $r = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/v1/courses/$courseId/quizzes" -Headers $jsonHdr -Body $body
        Start-Sleep -Milliseconds 400
        return $r
    } catch {
        Write-Host "  ERROR creating quiz: $_" -ForegroundColor Red
        $script:errors += "New-Quiz: $_"
        return $null
    }
}

function Add-QuizQ {
    param([int]$qid, [string]$text, [array]$ans, [string]$correct, [int]$pts = 5)
    $answers = $ans | ForEach-Object {
        @{ answer_text = $_.text; answer_weight = $(if ($_.letter -eq $correct) { 100 } else { 0 }) }
    }
    $body = @{ question = @{
        question_text   = $text
        question_type   = "multiple_choice_question"
        points_possible = $pts
        answers         = $answers
    } } | ConvertTo-Json -Depth 10
    try {
        Invoke-RestMethod -Method POST -Uri "$baseUrl/api/v1/courses/$courseId/quizzes/$qid/questions" -Headers $jsonHdr -Body $body | Out-Null
        Start-Sleep -Milliseconds 300
    } catch {
        Write-Host "  ERROR adding question: $_" -ForegroundColor Red
        $script:errors += "Add-QuizQ: $_"
    }
}

function Publish-Quiz {
    param([int]$qid)
    try {
        Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/v1/courses/$courseId/quizzes/$qid" `
            -Headers $jsonHdr -Body '{"quiz":{"published":true}}' | Out-Null
        Start-Sleep -Milliseconds 300
    } catch { Write-Host "  WARN: could not publish quiz $qid" -ForegroundColor Yellow }
}

function Add-AssignItem {
    param([int]$mid, [int]$aid, [string]$title)
    Invoke-JsonPost "/courses/$courseId/modules/$mid/items" @{
        module_item = @{ title = $title; type = "Assignment"; content_id = $aid; indent = 1; published = $true }
    } | Out-Null
    Write-Host "    [+] $title" -ForegroundColor DarkGreen
}

function Add-QuizItem {
    param([int]$mid, [int]$qid, [string]$title)
    Invoke-JsonPost "/courses/$courseId/modules/$mid/items" @{
        module_item = @{ title = $title; type = "Quiz"; content_id = $qid; indent = 1; published = $true }
    } | Out-Null
    Write-Host "    [+] $title" -ForegroundColor DarkGreen
}

function Parse-Quiz {
    param([string]$path)
    $content = Get-Content $path -Raw -Encoding UTF8
    $qs = @()
    $pattern = '\*\*Q\d+\.\*\*\s*([\s\S]+?)(?=\r?\n\r?\nA\))\r?\n\r?\nA\)\s*(.+?)\r?\nB\)\s*(.+?)\r?\nC\)\s*(.+?)\r?\nD\)\s*(.+?)\r?\n[\s\S]*?\*\*Answer:\s*([A-D])\*\*'
    [regex]::Matches($content, $pattern) | ForEach-Object {
        $m = $_
        $qs += @{
            text    = ($m.Groups[1].Value -replace '\s+', ' ').Trim()
            answers = @(
                @{ letter = "A"; text = $m.Groups[2].Value.Trim() },
                @{ letter = "B"; text = $m.Groups[3].Value.Trim() },
                @{ letter = "C"; text = $m.Groups[4].Value.Trim() },
                @{ letter = "D"; text = $m.Groups[5].Value.Trim() }
            )
            correct = $m.Groups[6].Value.Trim()
        }
    }
    Write-Host "    Parsed $($qs.Count) questions from $(Split-Path $path -Leaf)" -ForegroundColor DarkGray
    return $qs
}

# --------------------------------------------------
# FIND EXISTING MODULE 1
# --------------------------------------------------

Write-Host "`nFinding existing Module 1..." -ForegroundColor Cyan
$modules = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/v1/courses/$courseId/modules?per_page=50" -Headers $authHdr
$mod1 = $modules | Where-Object { $_.name -like "*Odyssey*" } | Select-Object -First 1
if (-not $mod1) {
    Write-Host "ERROR: Could not find Module 1. Aborting." -ForegroundColor Red
    exit 1
}
$mid = [int]$mod1.id
Write-Host "Found: $($mod1.name) (ID: $mid)" -ForegroundColor Green

# --------------------------------------------------
# WEEK 4 REMAINING ITEMS
# --------------------------------------------------

Write-Host "`nAdding Week 4 remaining items..." -ForegroundColor Yellow

$a = New-Assignment -title "VR 4.4: The Homecoming Tableau" `
    -body (Get-Content "$root\week-4\4.4-vr-homecoming-tableau.html" -Raw -Encoding UTF8) `
    -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 4.4: The Homecoming Tableau" }

$a = New-Assignment -title "VR 4.5: The Evidence Composition" `
    -body (Get-Content "$root\week-4\4.5-vr-evidence-composition.html" -Raw -Encoding UTF8) `
    -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 4.5: The Evidence Composition" }

$a = New-Assignment -title "Quick Write 4: Justice or Revenge?" `
    -body (Get-Content "$root\week-4\4.6-quickwrite-justice.html" -Raw -Encoding UTF8) `
    -pts 5 -subTypes @("online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "Quick Write 4: Justice or Revenge?" }

$q = New-Quiz -title "Week 4 Quiz: The Homecoming (Books 13-24)" `
    -desc "Ten multiple-choice questions on Books 13-24. One attempt. 50 points." -pts 50
if ($q) {
    $parsed = Parse-Quiz "$root\week-4\4.7-quiz.md"
    $parsed | ForEach-Object {
        # Strip non-ASCII to avoid encoding issues
        $safeText = $_.text -replace '[^\x00-\x7F]', ''
        $safeAns  = $_.answers | ForEach-Object { @{ letter=$_.letter; text=($_.text -replace '[^\x00-\x7F]', '') } }
        Add-QuizQ -qid ([int]$q.id) -text $safeText -ans $safeAns -correct $_.correct
    }
    Publish-Quiz ([int]$q.id)
    Add-QuizItem -mid $mid -qid ([int]$q.id) -title "Week 4 Quiz: The Homecoming (Books 13-24)"
}

# --------------------------------------------------
# SUMMARY
# --------------------------------------------------

Write-Host "`n=== Week 4 addendum complete ===" -ForegroundColor Cyan
if ($script:errors.Count -gt 0) {
    Write-Host "`nERRORS ($($script:errors.Count)):" -ForegroundColor Red
    $script:errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "No errors." -ForegroundColor Green
}
