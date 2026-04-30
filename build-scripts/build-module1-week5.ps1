# Canvas Build - Module 1 Week 5 + Module-Level Items
# PowerShell 5.1

$token    = "6936~DT7Yk4T963keRVfXnnzDAumnf9FyfWV76hBXMuntLrxUTB7RTTYUnRDtrtXnLz9F"
$baseUrl  = "https://k12.instructure.com"
$courseId = 2432642
$root     = "C:\Users\JessicaDrexel\OneDrive - OptimaEd\ELA\7th Grade ELA\ela-grade7-2025-2026\module-1-odyssey"

$authHdr  = @{ "Authorization" = "Bearer $token" }
$jsonHdr  = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$script:errors = @()

Write-Host "=== Canvas Build: Module 1 Week 5 + Module Items ===" -ForegroundColor Cyan

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

function New-Page {
    param([string]$title, [string]$body)
    Write-Host "  Page: $title" -ForegroundColor White
    $form = "wiki_page[title]=" + [System.Uri]::EscapeDataString($title) +
            "&wiki_page[body]="  + [System.Uri]::EscapeDataString($body) +
            "&wiki_page[published]=true"
    return Invoke-FormPost "/courses/$courseId/pages" $form
}

function New-Assignment {
    param([string]$title, [string]$body, [int]$pts, [string]$gradingType = "pass_fail", [string[]]$subTypes)
    Write-Host "  Assignment: $title ($pts pts)" -ForegroundColor White
    $subStr = ($subTypes | ForEach-Object { "assignment[submission_types][]=" + [System.Uri]::EscapeDataString($_) }) -join "&"
    $form = "assignment[name]="            + [System.Uri]::EscapeDataString($title) +
            "&assignment[description]="    + [System.Uri]::EscapeDataString($body) +
            "&assignment[points_possible]=$pts" +
            "&assignment[grading_type]=$gradingType" +
            "&assignment[published]=true" +
            "&$subStr"
    return Invoke-FormPost "/courses/$courseId/assignments" $form
}

function New-Discussion {
    param([string]$title, [string]$msg, [int]$pts)
    Write-Host "  Discussion: $title ($pts pts)" -ForegroundColor White
    $form = "title="   + [System.Uri]::EscapeDataString($title) +
            "&message=" + [System.Uri]::EscapeDataString($msg) +
            "&discussion_type=threaded" +
            "&require_initial_post=true" +
            "&published=true" +
            "&assignment[points_possible]=$pts" +
            "&assignment[grading_type]=points" +
            "&assignment[submission_types][]=discussion_topic"
    return Invoke-FormPost "/courses/$courseId/discussion_topics" $form
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

function Add-SubHead {
    param([int]$mid, [string]$title)
    Write-Host "`n  [Week] $title" -ForegroundColor Yellow
    Invoke-JsonPost "/courses/$courseId/modules/$mid/items" @{
        module_item = @{ title = $title; type = "SubHeader"; indent = 0; published = $true }
    } | Out-Null
}

function Add-PageItem {
    param([int]$mid, [string]$url, [string]$title)
    Invoke-JsonPost "/courses/$courseId/modules/$mid/items" @{
        module_item = @{ title = $title; type = "Page"; page_url = $url; indent = 1; published = $true }
    } | Out-Null
    Write-Host "    [+] $title" -ForegroundColor DarkGreen
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

function Add-DiscItem {
    param([int]$mid, [int]$did, [string]$title)
    Invoke-JsonPost "/courses/$courseId/modules/$mid/items" @{
        module_item = @{ title = $title; type = "Discussion"; content_id = $did; indent = 1; published = $true }
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
# MODULE-LEVEL ITEMS (top of module)
# --------------------------------------------------

Write-Host "`nAdding module-level items..." -ForegroundColor Yellow

$introMsg = "Ten multiple-choice questions on The Odyssey as a whole - narrative irony, epithets, periodic and cumulative sentences, sentence variety, and the poem's central argument. One attempt. 50 points."
$q = New-Quiz -title "Week 5 Quiz: The Poem as a Whole" -desc $introMsg -pts 50
if ($q) {
    $parsed = Parse-Quiz "$root\week-5\5.7-quiz.md"
    $parsed | ForEach-Object {
        $safeText = $_.text -replace '[^\x00-\x7F]', ''
        $safeAns  = $_.answers | ForEach-Object { @{ letter=$_.letter; text=($_.text -replace '[^\x00-\x7F]', '') } }
        Add-QuizQ -qid ([int]$q.id) -text $safeText -ans $safeAns -correct $_.correct
    }
    Publish-Quiz ([int]$q.id)
}

# Module project assignment (Tier 3 - points grading, not pass_fail)
$projBody = Get-Content "$root\module-1-project.html" -Raw -Encoding UTF8
$a = New-Assignment -title "Module 1 Project: Is Odysseus a Hero?" -body $projBody -pts 100 -gradingType "points" -subTypes @("online_upload","online_text_entry")

# --------------------------------------------------
# WEEK 5 ITEMS
# --------------------------------------------------

Add-SubHead -mid $mid -title "Week 5 - The Poem Looks Back at Itself"

$p = New-Page -title "5.1 Lesson: The Poem Looks Back at Itself" -body (Get-Content "$root\week-5\5.1-lesson-epic-retrospect.html" -Raw -Encoding UTF8)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "5.1 Lesson: The Poem Looks Back at Itself" }

$p = New-Page -title "5.2 Grammar: Periodic and Cumulative Sentences" -body (Get-Content "$root\week-5\5.2-grammar-periodic-cumulative.html" -Raw -Encoding UTF8)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "5.2 Grammar: Periodic and Cumulative Sentences" }

$p = New-Page -title "5.3 Grammar: Sentence Variety in Analytical Writing" -body (Get-Content "$root\week-5\5.3-grammar-sentence-variety.html" -Raw -Encoding UTF8)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "5.3 Grammar: Sentence Variety in Analytical Writing" }

$a = New-Assignment -title "VR 5.4: Module Gallery Walk" `
    -body (Get-Content "$root\week-5\5.4-vr-project-gallery.html" -Raw -Encoding UTF8) `
    -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 5.4: Module Gallery Walk" }

$a = New-Assignment -title "VR 5.5: Final Argument Recording" `
    -body (Get-Content "$root\week-5\5.5-vr-final-composition.html" -Raw -Encoding UTF8) `
    -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 5.5: Final Argument Recording" }

$discMsg = "<p><strong>Post your response first, then reply to one classmate whose position differs from yours.</strong></p><p>The module opened with a question: is Odysseus a hero? You have now read the full poem, argued in VR, and written your project. Answer the question now &mdash; not with your first impression, but with the argument you have built.</p><p><strong>Your post must include:</strong></p><ol><li><strong>A parallel-structure thesis</strong> in your first sentence. Name at least two specific qualities and use parallel grammatical form.</li><li><strong>Two specific scenes</strong> &mdash; one from the voyage (Books 9-12) and one from the homecoming (Books 13-24). For each scene, say what it shows and connect it to your claim.</li><li><strong>One concessive sentence</strong> beginning with 'Although...' that grants the strongest objection to your position, then answers it.</li></ol><p><strong>Reply to one classmate</strong> whose claim differs from yours. Name their specific claim, identify their strongest scene, and explain where your reading differs.</p><p><em>Rubric: 15 pts = parallel thesis + two specific scenes + genuine concession + engaged reply. 8 pts = vague claim or generic reply. 0 = not submitted.</em></p>"
$d = New-Discussion -title "Closing Discussion: Is Odysseus a Hero?" -msg $discMsg -pts 15
if ($d) { Add-DiscItem -mid $mid -did ([int]$d.id) -title "Closing Discussion: Is Odysseus a Hero?" }

if ($q) { Add-QuizItem -mid $mid -qid ([int]$q.id) -title "Week 5 Quiz: The Poem as a Whole" }

# Add subheader and project at the end
Add-SubHead -mid $mid -title "Module 1 Project"

# Find the project assignment we created above and add it
$allAssign = Invoke-RestMethod -Method GET -Uri "$baseUrl/api/v1/courses/$courseId/assignments?per_page=100" -Headers $authHdr
$projAssign = $allAssign | Where-Object { $_.name -like "*Module 1 Project*" } | Select-Object -First 1
if ($projAssign) {
    Add-AssignItem -mid $mid -aid ([int]$projAssign.id) -title "Module 1 Project: Is Odysseus a Hero?"
} else {
    Write-Host "  WARN: Could not find Module 1 Project assignment to add to module" -ForegroundColor Yellow
}

# --------------------------------------------------
# SUMMARY
# --------------------------------------------------

Write-Host "`n=== Week 5 build complete ===" -ForegroundColor Cyan
Write-Host "Module 1 is fully built in Canvas." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Create Module 1 Intro and Outro quizzes manually in Canvas (survey type)" -ForegroundColor Yellow
Write-Host "  2. Add printable checklist page after the intro quiz" -ForegroundColor Yellow
Write-Host "  3. Push all files to GitHub" -ForegroundColor Yellow

if ($script:errors.Count -gt 0) {
    Write-Host "`nERRORS ($($script:errors.Count)):" -ForegroundColor Red
    $script:errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "No errors." -ForegroundColor Green
}
