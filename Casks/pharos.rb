cask "pharos" do
  version "3.1.0"
  sha256 "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9"

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
