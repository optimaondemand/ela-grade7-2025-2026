# Canvas Build Script - Module 1: The Odyssey
# Course: OAO ELA Grade 7 | Course ID: 2432642
# PowerShell 5.1

param([switch]$Preview)

$token    = "6936~DT7Yk4T963keRVfXnnzDAumnf9FyfWV76hBXMuntLrxUTB7RTTYUnRDtrtXnLz9F"
$baseUrl  = "https://k12.instructure.com"
$courseId = 2432642
$root     = "C:\Users\JessicaDrexel\OneDrive - OptimaEd\ELA\7th Grade ELA\ela-grade7-2025-2026\module-1-odyssey"

$authHdr  = @{ "Authorization" = "Bearer $token" }
$jsonHdr  = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$script:errors = @()

Write-Host "=== Canvas Build: Module 1 - The Odyssey ===" -ForegroundColor Cyan
if ($Preview) { Write-Host "PREVIEW MODE - no changes will be made" -ForegroundColor Magenta }

# --------------------------------------------------
# HELPERS
# --------------------------------------------------

function Invoke-FormPost {
    param([string]$ep, [string]$form)
    if ($Preview) { Write-Host "  [Preview] POST $ep" -ForegroundColor DarkGray; return [pscustomobject]@{id=99;url="preview"} }
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
    if ($Preview) { Write-Host "  [Preview] POST $ep" -ForegroundColor DarkGray; return [pscustomobject]@{id=99;url="preview"} }
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
    return Invoke-JsonPost "/courses/$courseId/quizzes" @{
        quiz = @{
            title                = $title
            description          = $desc
            quiz_type            = "assignment"
            points_possible      = $pts
            allowed_attempts     = 1
            shuffle_answers      = $true
            show_correct_answers = $true
            published            = $false
        }
    }
}

function Add-QuizQ {
    param([int]$qid, [string]$text, [array]$ans, [string]$correct, [int]$pts = 5)
    $answers = $ans | ForEach-Object {
        @{ answer_text = $_.text; answer_weight = $(if ($_.letter -eq $correct) { 100 } else { 0 }) }
    }
    Invoke-JsonPost "/courses/$courseId/quizzes/$qid/questions" @{
        question = @{
            question_text   = $text
            question_type   = "multiple_choice_question"
            points_possible = $pts
            answers         = $answers
        }
    } | Out-Null
}

function Publish-Quiz {
    param([int]$qid)
    if ($Preview) { return }
    try {
        Invoke-RestMethod -Method PUT -Uri "$baseUrl/api/v1/courses/$courseId/quizzes/$qid" `
            -Headers $jsonHdr -Body '{"quiz":{"published":true}}' | Out-Null
        Start-Sleep -Milliseconds 300
    } catch { Write-Host "  WARN: could not publish quiz $qid" -ForegroundColor Yellow }
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

function New-Module {
    param([string]$name, [int]$pos)
    Write-Host "`nCreating module: $name" -ForegroundColor Cyan
    return Invoke-JsonPost "/courses/$courseId/modules" @{
        module = @{ name = $name; position = $pos; published = $true }
    }
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
    $content = Get-Content $path -Raw
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
# BUILD MODULE 1
# --------------------------------------------------

$mod = New-Module -name "Module 1: The Odyssey" -pos 1
if (-not $mod) { Write-Host "Failed to create module. Aborting." -ForegroundColor Red; exit 1 }
$mid = [int]$mod.id

# ---- WEEK 1 ----
Add-SubHead -mid $mid -title "Week 1 - Who Is Odysseus?"

$p = New-Page -title "1.1 Lesson: The Epic Hero" -body (Get-Content "$root\week-1\1.1-lesson-epic-hero.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "1.1 Lesson: The Epic Hero" }

$p = New-Page -title "1.2 Grammar: Gerund Phrases" -body (Get-Content "$root\week-1\1.2-grammar-gerund-phrases.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "1.2 Grammar: Gerund Phrases" }

$p = New-Page -title "1.3 Grammar: Infinitive Phrases" -body (Get-Content "$root\week-1\1.3-grammar-infinitive-phrases.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "1.3 Grammar: Infinitive Phrases" }

$a = New-Assignment -title "VR 1.4: Aegean Investigation" -body (Get-Content "$root\week-1\1.4-vr-aegean-investigation.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 1.4: Aegean Investigation" }

$a = New-Assignment -title "VR 1.5: Hero Composition" -body (Get-Content "$root\week-1\1.5-vr-hero-composition.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 1.5: Hero Composition" }

$a = New-Assignment -title "Quick Write 1: Who Is Odysseus?" -body (Get-Content "$root\week-1\1.6-quickwrite-odysseus.html" -Raw) -pts 5 -subTypes @("online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "Quick Write 1: Who Is Odysseus?" }

$q = New-Quiz -title "Week 1 Quiz: Books 1 and 5" -desc "Ten multiple-choice questions on Books 1 and 5. One attempt. 50 points." -pts 50
if ($q) {
    Parse-Quiz "$root\week-1\1.7-quiz.md" | ForEach-Object { Add-QuizQ -qid ([int]$q.id) -text $_.text -ans $_.answers -correct $_.correct }
    Publish-Quiz ([int]$q.id)
    Add-QuizItem -mid $mid -qid ([int]$q.id) -title "Week 1 Quiz: Books 1 and 5"
}

# ---- WEEK 2 ----
Add-SubHead -mid $mid -title "Week 2 - Cunning and Hubris"

$p = New-Page -title "2.1 Lesson: Cunning and Hubris" -body (Get-Content "$root\week-2\2.1-lesson-cunning-hubris.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "2.1 Lesson: Cunning and Hubris" }

$p = New-Page -title "2.2 Grammar: Appositive Chains" -body (Get-Content "$root\week-2\2.2-grammar-appositive-chains.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "2.2 Grammar: Appositive Chains" }

$p = New-Page -title "2.3 Grammar: Relative Clauses" -body (Get-Content "$root\week-2\2.3-grammar-relative-clauses.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "2.3 Grammar: Relative Clauses" }

$a = New-Assignment -title "VR 2.4: Cyclops Cave Staging" -body (Get-Content "$root\week-2\2.4-vr-cyclops-staging.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 2.4: Cyclops Cave Staging" }

$a = New-Assignment -title "VR 2.5: Cunning vs. Strength Composition" -body (Get-Content "$root\week-2\2.5-vr-cunning-composition.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 2.5: Cunning vs. Strength Composition" }

$a = New-Assignment -title "Quick Write 2: When Does Cleverness Become Cruelty?" -body (Get-Content "$root\week-2\2.6-quickwrite-cleverness.html" -Raw) -pts 5 -subTypes @("online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "Quick Write 2: When Does Cleverness Become Cruelty?" }

$q = New-Quiz -title "Week 2 Quiz: Books 9-10" -desc "Ten multiple-choice questions on Books 9-10. One attempt. 50 points." -pts 50
if ($q) {
    Parse-Quiz "$root\week-2\2.7-quiz.md" | ForEach-Object { Add-QuizQ -qid ([int]$q.id) -text $_.text -ans $_.answers -correct $_.correct }
    Publish-Quiz ([int]$q.id)
    Add-QuizItem -mid $mid -qid ([int]$q.id) -title "Week 2 Quiz: Books 9-10"
}

# ---- WEEK 3 ----
Add-SubHead -mid $mid -title "Week 3 - The Underworld and Its Cost"

$p = New-Page -title "3.1 Lesson: The Underworld and the Cost of the Journey" -body (Get-Content "$root\week-3\3.1-lesson-underworld-cost.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "3.1 Lesson: The Underworld and the Cost of the Journey" }

$p = New-Page -title "3.2 Grammar: Subordinate Clauses" -body (Get-Content "$root\week-3\3.2-grammar-subordinate-clauses.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "3.2 Grammar: Subordinate Clauses" }

$p = New-Page -title "3.3 Grammar: Adverbial Concession in Argument" -body (Get-Content "$root\week-3\3.3-grammar-adverbial-concession.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "3.3 Grammar: Adverbial Concession in Argument" }

$a = New-Assignment -title "VR 3.4: Underworld Annotation Walk" -body (Get-Content "$root\week-3\3.4-vr-underworld-walk.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 3.4: Underworld Annotation Walk" }

$a = New-Assignment -title "VR 3.5: Hubris Composition" -body (Get-Content "$root\week-3\3.5-vr-hubris-composition.html" -Raw) -pts 10 -subTypes @("online_upload","online_text_entry")
if ($a) { Add-AssignItem -mid $mid -aid ([int]$a.id) -title "VR 3.5: Hubris Composition" }

$discMsg = "<p><strong>Post your response first, then reply to one classmate.</strong></p><p>Homer gives Odysseus two qualities that seem to pull against each other: <em>metis</em> (cunning intelligence) and a pride so powerful that he shouts his real name to the Cyclops and invites ten more years of suffering.</p><p><strong>Take a position:</strong> Is Odysseus's cunning a virtue, or does his pride make it impossible for cunning to be virtuous? Use <strong>one specific scene from Books 1-12</strong> as your primary evidence. Your post must: (1) state your position in your first sentence, (2) name the specific scene and explain what it shows, (3) acknowledge what the opposing view would say and answer it.</p><p><strong>Reply to one classmate</strong> whose position differs from yours. Identify their specific evidence and explain why you read it differently.</p><p><em>Rubric: 15 pts = clear position + specific scene + concession answered + substantive reply. 8 pts = vague position or generic reply. 0 = not submitted.</em></p>"
$d = New-Discussion -title "Discussion: Is Odysseus's Cunning a Virtue?" -msg $discMsg -pts 15
if ($d) { Add-DiscItem -mid $mid -did ([int]$d.id) -title "Discussion: Is Odysseus's Cunning a Virtue?" }

$q = New-Quiz -title "Week 3 Quiz: Books 11-12" -desc "Ten multiple-choice questions on Books 11-12. One attempt. 50 points." -pts 50
if ($q) {
    Parse-Quiz "$root\week-3\3.7-quiz.md" | ForEach-Object { Add-QuizQ -qid ([int]$q.id) -text $_.text -ans $_.answers -correct $_.correct }
    Publish-Quiz ([int]$q.id)
    Add-QuizItem -mid $mid -qid ([int]$q.id) -title "Week 3 Quiz: Books 11-12"
}

# ---- WEEK 4 (partial) ----
Add-SubHead -mid $mid -title "Week 4 - Homecoming and Justice"

$p = New-Page -title "4.1 Lesson: Homecoming and Justice" -body (Get-Content "$root\week-4\4.1-lesson-homecoming-justice.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "4.1 Lesson: Homecoming and Justice" }

$p = New-Page -title "4.2 Grammar: Parallel Structure" -body (Get-Content "$root\week-4\4.2-grammar-parallel-structure.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "4.2 Grammar: Parallel Structure" }

$p = New-Page -title "4.3 Grammar: Anaphora" -body (Get-Content "$root\week-4\4.3-grammar-anaphora.html" -Raw)
if ($p) { Add-PageItem -mid $mid -url $p.url -title "4.3 Grammar: Anaphora" }

# --------------------------------------------------
# SUMMARY
# --------------------------------------------------
Write-Host "`n=== Build complete ===" -ForegroundColor Cyan
Write-Host "Week 4 VR/QW/Quiz and Week 5 will be added in the next run." -ForegroundColor Yellow

if ($script:errors.Count -gt 0) {
    Write-Host "`nERRORS ($($script:errors.Count)):" -ForegroundColor Red
    $script:errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "No errors." -ForegroundColor Green
}
