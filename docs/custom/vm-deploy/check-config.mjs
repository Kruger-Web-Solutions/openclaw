import { readFileSync } from 'node:fs';
const config = JSON.parse(readFileSync('/home/henzard/.openclaw/openclaw.json', 'utf8'));
console.log('Plugins:', JSON.stringify(Object.keys(config.plugins || {})));
console.log('Channels:', JSON.stringify(Object.keys(config.channels || {})));

// Check if whatsapp_archive exists as a tool
const tools = config.tools || {};
console.log('Tools:', JSON.stringify(Object.keys(tools)));

// Check extensions
const extensions = config.extensions || {};
console.log('Extensions:', JSON.stringify(Object.keys(extensions)));
