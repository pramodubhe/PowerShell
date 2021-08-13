$inputfile = "C:\temp\input.txt"
$outputfile = "C:\temp\output.txt"

$list = Get-Content $inputfile

$count = 0
foreach ($group in $list){
$count++
$groupdetails = $null
$groupdetails = Get-ADGroup $group -ErrorAction SilentlyContinue

if ($group){
Remove-ADGroup $group -Confirm:$false
$groupdetails1 = $null
$groupdetails1 = Get-ADGroup $group -ErrorAction SilentlyContinue
if ($groupdetails1){
(Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group could not be deleted." | Out-File $outputfile -Append
Write-Host (Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group could not be deleted." -ForegroundColor Yellow
}
else{
(Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group deleted successfully." | Out-File $outputfile -Append
Write-Host (Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group deleted successfully." -ForegroundColor Green
}
}
else {
(Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group not found in AD." | Out-File $outputfile -Append
Write-Host (Get-Date -UFormat '%Y-%m-%d %T ') + "$count) $group group not found in AD." -ForegroundColor Red
}
}