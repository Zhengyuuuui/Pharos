cask "pharos" do
  version "3.2.0"
  sha256 "dd678c6eb2367616057948c7ed63a14df4df5ae1b016790ca4699a6925f3c857"

  url "https://github.com/Zhengyuuuui/Pharos/releases/download/v#{version}/Pharos-#{version}.dmg"
  name "Pharos"
  desc "Native macOS menu bar monitor for ports, memory, thermals, fans, battery & AI IDE chats"
  homepage "https://github.com/Zhengyuuuui/Pharos"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Pharos.app"

  uninstall quit: "local.pharos"

  zap trash: [
    "~/Library/Application Support/Pharos",
    "~/Library/Caches/local.pharos",
    "~/Library/Preferences/local.pharos.plist",
    "~/Library/Saved Application State/local.pharos.savedState",
  ]
end
