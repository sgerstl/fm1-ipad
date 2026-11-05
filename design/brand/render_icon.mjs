// Renders lupe-icon.svg to lupe-icon-1024.png with the installed Chrome (the SVG's blur needs a real browser).
// Needs playwright-core: NODE_PATH=~/.claude/skills/design-standards/node_modules node render_icon.mjs
import { chromium } from 'playwright-core'
import { readFileSync } from 'node:fs'
const svg = readFileSync(new URL('./lupe-icon.svg', import.meta.url), 'utf8')
const browser = await chromium.launch({ channel: 'chrome' })
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 })
await page.setContent(`<html><body style="margin:0;background:#0A0A0B">${svg}</body></html>`)
await page.locator('svg').screenshot({ path: new URL('./lupe-icon-1024.png', import.meta.url).pathname, omitBackground: false })
await browser.close()
console.log('wrote lupe-icon-1024.png')
