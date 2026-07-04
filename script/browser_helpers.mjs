import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { chromium } from "playwright"

export const baseUrl = (process.env.PENNYLUNCH_BASE_URL || "http://127.0.0.1:3000").replace(/\/$/, "")

const chromePath = process.env.PLAYWRIGHT_CHROME_EXECUTABLE || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

export async function assertServerReady(path = "/recipes") {
  try {
    const response = await fetch(`${baseUrl}${path}`)
    if (response.ok) return
  } catch {
  }

  throw new Error(`No PennyLunch server is reachable at ${baseUrl}. Start bin/dev or set PENNYLUNCH_BASE_URL to an existing app URL.`)
}

export async function launchBrowser(viewport = { width: 1440, height: 1000 }) {
  const launchOptions = {
    headless: true,
    ...(existsSync(chromePath) ? { executablePath: chromePath } : {})
  }
  const browser = await chromium.launch(launchOptions)
  const page = await browser.newPage({ viewport })
  await page.emulateMedia({ reducedMotion: "no-preference" })

  return { browser, page }
}

export function runRailsRunner(code) {
  const result = spawnSync("bin/rails", ["runner", code], {
    cwd: process.cwd(),
    encoding: "utf8",
    env: { ...process.env, RAILS_ENV: process.env.RAILS_ENV || "development" }
  })

  if (result.status === 0) return

  throw new Error([result.stdout, result.stderr].filter(Boolean).join("\n").trim())
}
