
$items = (Get-ChildItem *.ps1)
$index = 0..($items.length - 1)
$index | ForEach-Object{
        "{0,3} --- {1}" -f ($_ + 1),($items[$_].BaseName)
    }
