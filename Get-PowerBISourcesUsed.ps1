#Requires -Version '5.1'
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName='Path')]
[OutputType([String])]
param (
	[Parameter(Mandatory, Position=0, ParameterSetName='Path', HelpMessage='A .pbix or .pbit file.')]
	[String]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ Test-Path $PSItem -PathType 'Leaf' })]
	$Path,

	[Parameter(Mandatory, Position=0, ParameterSetName='LiteralPath', HelpMessage='A .pbix or .pbit file.')]
	[String]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ Test-Path -LiteralPath $PSItem -PathType 'Leaf' })]
	$LiteralPath
)
begin {
	if ($Path) {
		$LiteralPathList = Resolve-Path $Path | Select-Object -ExpandProperty 'ProviderPath'
	} else {
		$LiteralPathList = $LiteralPath
	}

	foreach ($SourceLiteralPath in $LiteralPathList) {
		$TempFile = New-TemporaryFile
		Remove-Item -LiteralPath $TempFile
		$TempFile = Join-Path $([System.IO.Path]::GetDirectoryName($TempFile)) `
							  "$([System.IO.Path]::GetFileNameWithoutExtension($TempFile)).zip"
		Copy-Item -LiteralPath $SourceLiteralPath  -Destination $TempFile

		$TempDir = New-TemporaryFile
		Remove-Item -LiteralPath $TempDir
		$TempDir = Join-Path $([System.IO.Path]::GetDirectoryName($TempDir)) `
							 $([System.IO.Path]::GetFileNameWithoutExtension($TempDir))
		Expand-Archive -LiteralPath $TempFile -DestinationPath $TempDir

		$DataModelSchemaFile = Join-Path $TempDir 'DataModelSchema'
		$Content = Get-Content -LiteralPath $DataModelSchemaFile -Encoding 'unicode' -Raw

		Write-Output $content | jq @'
[.
	| .model
	| .tables[] | . as $tbl
	| select(any(.annotations[]; .name == "LinkedQueryName"))
	| (.annotations[] | select(.name == "LinkedQueryName") | .value) as $qry
	| .columns[] | . as $col
	| .sourceColumn? | select(.) | . as $src_col
	| {
		SourceQueryName: $qry,
		SourceColumnName: $src_col
	}
]
| unique
| sort_by([.SourceQueryName, .SourceColumnName])
'@
	}
}