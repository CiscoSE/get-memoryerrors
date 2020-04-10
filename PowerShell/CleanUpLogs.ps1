[array]$path = @('.\TACReport','.\Processing') 
 $path | %{
    If (Test-Path -Path $_){
        $_ | 
            get-childitem |
                Remove-Item -force -Recurse
    }
}