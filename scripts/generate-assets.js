"use strict";

const path = require("node:path");
const sharp = require("sharp");

const appRoot = path.resolve(__dirname, "..");
const source = path.resolve(appRoot, "..", "public", "assets", "app-icon.png");
const iconPath = path.join(appRoot, "assets", "icon.png");
const splashPath = path.join(appRoot, "assets", "splash.png");

const mobileBadge = Buffer.from(`
  <svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="badge" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#1769f7"/>
        <stop offset="1" stop-color="#8b42e8"/>
      </linearGradient>
    </defs>
    <rect x="446" y="774" width="474" height="166" rx="58" fill="#ffffff" fill-opacity="0.97"/>
    <rect x="453" y="781" width="460" height="152" rx="52" fill="none" stroke="#d9d4fa" stroke-width="7"/>
    <text x="683" y="884" text-anchor="middle" font-family="Microsoft YaHei, PingFang SC, sans-serif"
      font-size="78" font-weight="800" fill="url(#badge)">AI小梦</text>
  </svg>
`);

async function main() {
  await sharp(source)
    .resize(1024, 1024, { fit: "cover" })
    .composite([{ input: mobileBadge }])
    .flatten({ background: "#ffffff" })
    .png()
    .toFile(iconPath);

  const iconBuffer = await sharp(iconPath).resize(620, 620).png().toBuffer();
  await sharp({ create: { width: 2732, height: 2732, channels: 4, background: "#ffffff" } })
    .composite([{ input: iconBuffer, gravity: "center" }])
    .png()
    .toFile(splashPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
