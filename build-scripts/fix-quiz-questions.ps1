# Fix quiz questions for Weeks 1, 2, 3
# Week 1: 0 questions - uses different format (- A) and **Correct: B**)
# Week 2: 9 questions - Q9 mêtis failed, add it manually
# Week 3: 10 questions exist but points_possible = 45, update to 50

$token    = "6936~DT7Yk4T963keRVfXnnzDAumnf9FyfWV76hBXMuntLrxUTB7RTTYUnRDtrtXnLz9F"
$baseUrl  = "https://k12.instructure.com"
$courseId = 2432642
$root     = "C:\Users\JessicaDrexel\OneDrive - OptimaEd\ELA\7th Grade ELA\ela-grade7-2025-2026\module-1-odyssey"

$authHdr  = @{ "Authorization" = "Bearer $token" }
$jsonHdr  = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

$w1QuizId = 4013034
$w2QuizId = 4013035
$w3QuizId = 4013036

Write-Host "=== Quiz Fix Script ===" -ForegroundColor Cyan

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
        $r = Invoke-RestMethod -Method POST -Uri "$baseUrl/api/v1/courses/$courseId/quizzes/$qid/questions" -Headers $jsonHdr -Body $body
        Start-Sleep -Milliseconds 300
        Write-Host "  Added: $($text.Substring(0, [Math]::Min(60, $text.Length)))..." -ForegroundColor DarkGreen
        return $r
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

function Publish-Quiz {
    param([int]$qid, [int]$pts)
    $body = "{`"quiz`":{`"published`":true,`"points_possible`":$pts}}"
    try {
        Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/v1/courses/$courseId/quizzes/$qid" -Headers $jsonHdr -Body $body | Out-Null
        Write-Host "  Published quiz $qid ($pts pts)" -ForegroundColor Green
    } catch { Write-Host "  WARN: could not update quiz $qid" -ForegroundColor Yellow }
}

# -----------------------------------------------
# WEEK 1: Parse with correct regex (- A) format)
# -----------------------------------------------
Write-Host "`n--- Fixing Week 1 Quiz (0 questions) ---" -ForegroundColor Yellow

$content = Get-Content "$root\week-1\1.7-quiz.md" -Raw -Encoding UTF8
$qs1 = @()
# Week 1 format: "- A) answer" and "**Correct: B**"
$w1pattern = '\*\*Q\d+\.\*\*\s*([\s\S]+?)(?=\r?\n\r?\n- A\))\r?\n\r?\n- A\)\s*(.+?)\r?\n- B\)\s*(.+?)\r?\n- C\)\s*(.+?)\r?\n- D\)\s*(.+?)\r?\n[\s\S]*?\*\*Correct:\s*([A-D])\*\*'
[regex]::Matches($content, $w1pattern) | ForEach-Object {
    $m = $_
    $qs1 += @{
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
Write-Host "Parsed $($qs1.Count) questions from 1.7-quiz.md"

$qs1 | ForEach-Object {
    $safeText = $_.text -replace '[^\x00-\x7F]', ''
    $safeAns  = $_.answers | ForEach-Object { @{ letter=$_.letter; text=($_.text -replace '[^\x00-\x7F]', '') } }
    Add-QuizQ -qid $w1QuizId -text $safeText -ans $safeAns -correct $_.correct
}
Publish-Quiz -qid $w1QuizId -pts 50

# -----------------------------------------------
# WEEK 2: Add missing Q9 (metis - ASCII safe)
# -----------------------------------------------
Write-Host "`n--- Fixing Week 2 Quiz (adding Q9) ---" -ForegroundColor Yellow

$q9Text = "What does the Greek term metis (cunning intelligence) suggest about Odysseus's heroism?"
$q9Answers = @(
    @{ letter = "A"; text = "True heroism requires brute strength, not cleverness." },
    @{ letter = "B"; text = "Intelligence and practical wisdom are legitimate forms of heroic excellence, not inferior to strength." },
    @{ letter = "C"; text = "Odysseus is only a hero because Athena helps him -- his own intelligence is secondary." },
    @{ letter = "D"; text = "Metis is a weakness because it requires deception, and deception is dishonorable." }
)
Add-QuizQ -qid $w2QuizId -text $q9Text -ans $q9Answers -correct "B"
Publish-Quiz -qid $w2QuizId -pts 50

# -----------------------------------------------
# WEEK 3: Update points_possible to 50
# -----------------------------------------------
Write-Host "`n--- Fixing Week 3 Quiz (update pts to 50) ---" -ForegroundColor Yellow
Publish-Quiz -qid $w3QuizId -pts 50

# -----------------------------------------------
# VERIFY
# -----------------------------------------------
Write-Host "`n--- Verification ---" -ForegroundColor Cyan
Start-Sleep -Seconds 2
$quizzes = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/v1/courses/$courseId/quizzes?per_page=50" -Headers $authHdr
$quizzes | Sort-Object title | ForEach-Object {
    Write-Host "  $($_.title): $($_.question_count) questions, $($_.points_possible) pts"
}
