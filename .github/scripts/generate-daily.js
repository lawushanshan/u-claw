#!/usr/bin/env node
/**
 * 每日内容生成脚本
 * 调用智谱 GLM API 生成每日小技巧和每日最佳案例
 * 写入 website/daily/data.json
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const DATA_FILE = path.join(__dirname, '../../website/daily/data.json');
const MAX_HISTORY = 30;

const TODAY = new Date().toLocaleDateString('zh-CN', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
}).replace(/\//g, '-');

const SYSTEM_PROMPT = `你是 U-Claw 虾盘的内容助手。U-Claw 是一款专为中国用户打造的 OpenClaw AI 助手离线安装 U 盘，特点如下：
- 完全离线安装，无需翻墙
- 支持 macOS / Windows / Linux
- 内置 52 个预装技能（Skills）
- 支持 8 大国产模型：DeepSeek、Kimi、通义千问、智谱GLM、MiniMax、豆包、千帆、Mimo
- 多平台接入：QQ / 飞书 / 钉钉 / 企业微信 / Telegram / Discord
- 便携模式：插上 U 盘即用，配置跟着 U 盘走
- 安装到电脑：一键永久安装
- 支持远程控制（Agent 模式）
- 基于 OpenClaw 开源项目

每日内容需要实用、具体、对真实用户有帮助。内容要中英双语，json格式，不要有多余的格式。`;

const USER_PROMPT = `请生成今天（${TODAY}）的内容，包含两部分：

1. **每日小技巧**（tip）：一个关于 U-Claw / OpenClaw 的具体使用技巧，可以是快捷操作、配置方法、隐藏功能等
2. **每日最佳案例**（case）：一个真实使用场景的案例，展示如何用 U-Claw 解决实际问题

要求：
- 每部分有标题（title）和正文（content），正文 80-150 字
- 中英双语：zh（中文）和 en（英文）版本
- 实用、具体，避免空泛

请严格按以下 JSON 格式返回，不要有多余文字：
{
  "tip": {
    "title": { "zh": "中文标题", "en": "English Title" },
    "content": { "zh": "中文内容", "en": "English content" },
    "tag": { "zh": "技巧", "en": "Tip" }
  },
  "case": {
    "title": { "zh": "中文标题", "en": "English Title" },
    "content": { "zh": "中文内容", "en": "English content" },
    "tag": { "zh": "案例", "en": "Case" }
  }
}`;

function callGLM(apiKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      model: 'deepseek-chat',
      max_tokens: 1024,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: USER_PROMPT }
      ]
    });

    const options = {
      hostname: 'api.deepseek.com',
      path: '/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`API error ${res.statusCode}: ${data}`));
          return;
        }
        try {
          const parsed = JSON.parse(data);
          const text = parsed.choices[0].message.content.trim();
          // 提取 JSON（防止模型输出额外文字）
          const jsonMatch = text.match(/\{[\s\S]*\}/);
          if (!jsonMatch) throw new Error('No JSON found in response');
          resolve(JSON.parse(jsonMatch[0]));
        } catch (e) {
          reject(new Error(`Parse error: ${e.message}\nRaw: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    console.error('DEEPSEEK_API_KEY not set');
    process.exit(1);
  }

  console.log(`Generating content for ${TODAY}...`);

  let content;
  try {
    content = await callGLM(apiKey);
    console.log('API call successful');
  } catch (err) {
    console.error('API call failed:', err.message);
    process.exit(0); // 失败时退出但不破坏 CI
  }

  // 读取现有数据
  let data = { latest: null, history: [] };
  if (fs.existsSync(DATA_FILE)) {
    try {
      data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    } catch (e) {
      console.warn('Could not parse existing data, starting fresh');
    }
  }

  // 构建今日条目
  const entry = {
    date: TODAY,
    tip: content.tip,
    case: content.case
  };

  // 如果今天已有记录，替换；否则追加到 history
  if (data.latest && data.latest.date !== TODAY) {
    data.history.unshift(data.latest);
    // 保留最近 MAX_HISTORY 条
    if (data.history.length > MAX_HISTORY) {
      data.history = data.history.slice(0, MAX_HISTORY);
    }
  }

  data.latest = entry;

  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
  console.log(`Written to ${DATA_FILE}`);
}

main();
