#install-Module -name posh-git
#git config --global user.email 'toor.irk@gmail.com'
git clone https://github.com/kontur-exploitation/testcase-posharp.git testclonedfromposh -q
Set-Location -Path .\testclonedfromposh
$hash=@{}
$hashprev=@{}
$needbuild=@()
Do {
git fetch --all
$list = (git branch -r --sort=committerdate --format='%(HEAD) %(refname:short)=%(objectname:short);')

$list.split(";").Trim()|ForEach-Object {
    $line = @($_ -split "="); 
    if ($line[0] -ne "") {
        $hash.add($line[0],$line[1]) 
    }
}

$hash.remove('origin/HEAD')

$hash.keys| ForEach-Object {
    if ($hash.$_ -ne $hashprev.$_) {
        Write-Host "`Added a new branch [$_] or a new commit. Need to build!" -ForegroundColor Green
        $needbuild += $_
    }
}
Write-Output $needbuild

if ($needbuild.Count -gt 0) {
    Foreach ($neededbranch in $needbuild) {
    Write-Host "Working on the $neededbranch branch" -ForegroundColor Green
    git merge $neededbranch
    git checkout $neededbranch
    if (Test-Path CSharpProject.csproj -PathType Leaf) {
    Write-Host "Begin compilation" -ForegroundColor Green
    & 'C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe' .\CSharpProject.csproj
        if ($?){Write-Host "Succeess!!!" -ForegroundColor Green
            Write-Host "Start CSharpProject.exe" -ForegroundColor Green
            .\bin\Debug\CSharpProject.exe > .\output.txt
            Write-Host (Get-Content ".\output.txt") -ForegroundColor Green
            if (-not (Test-Path Nuget.exe -PathType Leaf)) {
                Write-Host "getting Nuget.exe" -ForegroundColor Green
                Invoke-WebRequest -uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile nuget.exe
                }
            Write-Host "Generating nuspec file" -ForegroundColor Green
            .\nuget.exe spec -Force
            $XMLnuspec = [XML](Get-Content ".\CSharpProject.nuspec")
            $XMLnuspec.package.metadata.id = "kontur.testtask"
            $XMLnuspec.package.metadata.Version = (Get-Item .\bin\Debug\CSharpProject.exe).VersionInfo.FileVersion
            $XMLnuspec.package.metadata.description =((Get-Content ".\output.txt") +" Latest commit is " +$hash[$neededbranch])
            $XMLnuspec.package.metadata.authors = (git show  | Select-String -Pattern "Author:").ToString().Substring(8)
            $XMLnuspec.package.metadata.tags = ""
            $XMLnuspec.package.metadata.releaseNotes = ""
            $XMLnuspec.Save((Get-Location).Path + "\CSharpProject.nuspec")
            Write-Host "Creating nuget package" -ForegroundColor Green
            .\nuget.exe pack .\CSharpProject.nuspec
            Write-Host "Publishing the nuget package to Nuget.Org" -ForegroundColor Green
            .\nuget.exe push .\*.nupkg -apikey *** -Source https://api.nuget.org/v3/index.json -SkipDuplicate
             
        }  
    }
    }
}


Write-Output $hash
$hashprev = $hash.clone()
$hash=@{}
$needbuild=@()

Write-Host `n
sleep 10 

} Until (!$true)


