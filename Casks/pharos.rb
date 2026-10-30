cask "pharos" do
  version "3.0.0"
  sha256 "cbae534b65edd16aff54adf1ede92f294321a85932e3605ab911dd2d2566443a"

  url "https://github.com/Zhengyuuuui/Pharos/releases/download/v#{version}/Pharos-#{version}.dmg"
  name "Pharos"
  desc "Native macOS menu bar monitor for ports, memory, thermals, fans, battery & AI IDE chats"
  homepage "https://github.com/Zhengyuuuui/Pharos"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Pharos.app"

  uninstall quit: "local.pharos"

  zap trash: [
    "~/Library/Application Support/Pharos",
    "~/Library/Caches/local.pharos",
    "~/Library/Preferences/local.pharos.plist",
    "~/Library/Saved Application State/local.pharos.savedState",
  ]
end
