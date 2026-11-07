export interface Env {
  GITHUB_REPO?: string;
  GITHUB_TOKEN?: string;
}

interface GitHubAsset {
  name: string;
  size: number;
  browser_download_url: string;
  content_type?: string;
}

interface GitHubRelease {
  tag_name: string;
  name?: string;
  published_at?: string;
  body?: string;
  html_url?: string;
  assets?: GitHubAsset[];
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const repo = env.GITHUB_REPO || "Zhengyuuuui/Pharos";

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    // Health check
    if (url.pathname === "/health" || url.pathname === "/healthz") {
      return new Response(JSON.stringify({ ok: true, service: "pharos-update" }), {
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": "no-cache",
        },
      });
    }

    // Latest version metadata API
    if (url.pathname === "/api/v1/latest") {
      const cache = caches.default;
      const cacheKey = new Request(url.toString(), request);
      const cached = await cache.match(cacheKey);
      if (cached) {
        return cached;
      }

      const ghHeaders: Record<string, string> = {
        "User-Agent": "Pharos-Update-Worker/1.0",
        "Accept": "application/vnd.github.v3+json",
      };
      if (env.GITHUB_TOKEN) {
        ghHeaders["Authorization"] = `Bearer ${env.GITHUB_TOKEN}`;
      }

      const ghRes = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
        headers: ghHeaders,
      });

      if (!ghRes.ok) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch release from GitHub",
            status: ghRes.status,
            statusText: ghRes.statusText,
          }),
          {
            status: ghRes.status === 404 ? 404 : 502,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          }
        );
      }

      const release = (await ghRes.json()) as GitHubRelease;
      const tagName = release.tag_name || "";
      const version = tagName.replace(/^v/i, "");
      const releaseNotes = release.body || "";

      // Extract 64-char hex SHA-256 from notes
      const shaMatch = releaseNotes.match(/\b([a-fA-F0-9]{64})\b/);
      const sha256 = shaMatch ? shaMatch[1].toLowerCase() : null;

      // Locate .dmg asset
      const dmgAsset = (release.assets || []).find((a) => a.name.toLowerCase().endsWith(".dmg"));
      const dmgName = dmgAsset?.name || `Pharos-${version}.dmg`;
      const dmgSize = dmgAsset?.size ?? null;
      const githubDmgUrl = dmgAsset?.browser_download_url || `https://github.com/${repo}/releases/download/${tagName}/${dmgName}`;
      const dmgUrl = `${url.origin}/download/latest/${dmgName}`;

      const payload = {
        version,
        tagName,
        releaseName: release.name || `Pharos ${tagName}`,
        publishedAt: release.published_at || new Date().toISOString(),
        notes: releaseNotes,
        sha256,
        dmgName,
        dmgSize,
        dmgUrl,
        githubDmgUrl,
        htmlUrl: release.html_url || `https://github.com/${repo}/releases/tag/${tagName}`,
      };

      const response = new Response(JSON.stringify(payload, null, 2), {
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": "public, max-age=60, s-maxage=300",
          "Access-Control-Allow-Origin": "*",
        },
      });

      ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    }

    // Binary download proxy: /download/latest/:filename or /download/:tag/:filename
    const downloadMatch = url.pathname.match(/^\/download\/([^/]+)\/(.+)$/);
    if (downloadMatch) {
      const tagOrLatest = downloadMatch[1];
      const filename = decodeURIComponent(downloadMatch[2]);

      const upstreamUrl =
        tagOrLatest.toLowerCase() === "latest"
          ? `https://github.com/${repo}/releases/latest/download/${encodeURIComponent(filename)}`
          : `https://github.com/${repo}/releases/download/${encodeURIComponent(tagOrLatest)}/${encodeURIComponent(filename)}`;

      const upstreamRes = await fetch(upstreamUrl, {
        redirect: "follow",
        headers: {
          "User-Agent": "Pharos-Update-Worker/1.0",
        },
      });

      if (!upstreamRes.ok) {
        return new Response(`Upstream error: ${upstreamRes.status} ${upstreamRes.statusText}`, {
          status: upstreamRes.status,
          headers: {
            "Content-Type": "text/plain; charset=utf-8",
            "Access-Control-Allow-Origin": "*",
          },
        });
      }

      const headers = new Headers();
      headers.set("Content-Type", "application/x-apple-diskimage");
      const contentLength = upstreamRes.headers.get("Content-Length");
      if (contentLength) {
        headers.set("Content-Length", contentLength);
      }
      headers.set("Content-Disposition", `attachment; filename="${filename}"`);
      headers.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
      headers.set("Access-Control-Allow-Origin", "*");

      // Stream directly without reading entire file into memory
      return new Response(upstreamRes.body, {
        status: 200,
        headers,
      });
    }

    return new Response("Not Found", { status: 404 });
  },
};
