import fs from 'fs';
import os from 'os';
import path from 'path';

const filePath = path.join(os.tmpdir(), 'openrouter_models.json');
const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
const models = data.data || [];
console.log('Total models:', models.length);

const interesting = models.filter((m) => /ernie|nemotron|gemma/i.test(m.id));
for (const m of interesting) {
  const info = {
    id: m.id,
    name: m.name,
    pricing: m.pricing,
    context_length: m.context_length,
    free: m.free,
    supported_parameters: m.supported_parameters,
  };
  console.log(JSON.stringify(info, null, 2));
  console.log('---');
}

// Also list ALL free models (pricing prompt === "0" and completion === "0")
const free = models.filter((m) => {
  const p = m.pricing || {};
  return String(p.prompt) === '0' && String(p.completion) === '0';
});
console.log('\n=== FREE MODELS COUNT:', free.length, '===');
for (const m of free) {
  console.log(m.id, '|', m.context_length, '|', (m.supported_parameters || []).join(','));
}
