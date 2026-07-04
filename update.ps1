$zip = "toml.hx.zip"

Remove-Item $zip -Force -ErrorAction SilentlyContinue

Compress-Archive `
  -Path src, haxelib.json, README.md, assets, LICENSE.md `
  -DestinationPath $zip `
  -Force

haxelib submit $zip