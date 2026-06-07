const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;
const PROJECT_ROOT = path.resolve(__dirname, '..');

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Helper to strip ANSI escape codes
function stripAnsi(str) {
  return str.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g, '');
}

// Helper to recursively find files with extensions
function findFiles(dir, exts, maxDepth = 3, currentDepth = 0) {
  let results = [];
  if (currentDepth > maxDepth) return results;
  
  try {
    const list = fs.readdirSync(dir);
    for (const file of list) {
      if (file === 'node_modules' || file === 'dist-newstyle' || file === '.git' || file === 'web-ui') {
        continue;
      }
      
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        results = results.concat(findFiles(filePath, exts, maxDepth, currentDepth + 1));
      } else {
        const ext = path.extname(file).toLowerCase();
        if (exts.includes(ext)) {
          results.push(path.relative(PROJECT_ROOT, filePath));
        }
      }
    }
  } catch (err) {
    console.error(err);
  }
  return results;
}

// Helper to find log folders (folders containing .log files)
function findLogDirs(dir, maxDepth = 3, currentDepth = 0) {
  let results = [];
  if (currentDepth > maxDepth) return results;
  
  try {
    const list = fs.readdirSync(dir);
    let hasLog = false;
    for (const file of list) {
      if (file === 'node_modules' || file === 'dist-newstyle' || file === '.git' || file === 'web-ui') {
        continue;
      }
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        results = results.concat(findLogDirs(filePath, maxDepth, currentDepth + 1));
      } else if (path.extname(file).toLowerCase() === '.log') {
        hasLog = true;
      }
    }
    if (hasLog) {
      results.push(path.relative(PROJECT_ROOT, dir));
    }
  } catch (err) {
    console.error(err);
  }
  return results;
}

// Endpoint to fetch available DSL files and log paths
app.get('/api/resources', (req, res) => {
  const dslFiles = findFiles(PROJECT_ROOT, ['.dsl']);
  const logFiles = findFiles(PROJECT_ROOT, ['.log']);
  const logDirs = findLogDirs(PROJECT_ROOT);
  
  // Combine single log files and log directories
  const logSources = [...new Set([...logDirs, ...logFiles])].sort();
  
  res.json({
    dslFiles: dslFiles.sort(),
    logSources: logSources
  });
});

// Endpoint to get rule file content
app.get('/api/rules/content', (req, res) => {
  const { file } = req.query;
  if (!file) {
    return res.status(400).json({ error: 'File parameter is required.' });
  }
  const fullPath = path.resolve(PROJECT_ROOT, file);
  
  // Security check: ensure path is within PROJECT_ROOT
  if (!fullPath.startsWith(PROJECT_ROOT)) {
    return res.status(403).json({ error: 'Access denied.' });
  }

  try {
    const content = fs.readFileSync(fullPath, 'utf8');
    res.json({ success: true, content });
  } catch (err) {
    res.status(500).json({ error: 'Failed to read rule file.', details: err.message });
  }
});

// Endpoint to save rule file content with syntax validation
app.post('/api/rules/save', (req, res) => {
  const { file, content } = req.body;
  if (!file || content === undefined) {
    return res.status(400).json({ error: 'File and content are required.' });
  }
  const fullPath = path.resolve(PROJECT_ROOT, file);

  // Security check: ensure path is within PROJECT_ROOT
  if (!fullPath.startsWith(PROJECT_ROOT)) {
    return res.status(403).json({ error: 'Access denied.' });
  }

  const tempPath = fullPath + '.tmp';
  const dummyLog = path.resolve(PROJECT_ROOT, 'examples/test.log');

  try {
    // 1. Write to temporary file
    fs.writeFileSync(tempPath, content, 'utf8');

    // 2. Validate by running the log unifier on the temp rules
    const args = ['run', '-v0', 'haskell-log-unifier', '--', '--rules', tempPath, '--logs', dummyLog];
    console.log('Validating rules: cabal', args.join(' '));
    
    const child = spawn('cabal', args, { cwd: PROJECT_ROOT });

    let stdoutData = '';
    let stderrData = '';

    child.stdout.on('data', (data) => {
      stdoutData += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderrData += data.toString();
    });

    child.on('close', (code) => {
      // Clean up temp file
      try {
        if (fs.existsSync(tempPath)) {
          fs.unlinkSync(tempPath);
        }
      } catch (err) {
        console.error('Failed to delete temp file:', err);
      }

      // Check if it printed compile/parse errors
      const hasParseError = code !== 0 || stdoutData.includes('Error parsing rules:') || stderrData.includes('Error parsing rules:');

      if (hasParseError) {
        const rawError = stdoutData + '\n' + stderrData;
        const cleanError = stripAnsi(rawError)
          .replace(new RegExp(tempPath, 'g'), file)
          .replace('Error parsing rules:', '')
          .trim();

        return res.status(400).json({
          error: '構文エラーがあります',
          details: cleanError || 'ルールファイルのパースに失敗しました。'
        });
      }

      // 3. Validation passed: write to the actual file
      try {
        fs.writeFileSync(fullPath, content, 'utf8');
        res.json({ success: true });
      } catch (saveErr) {
        res.status(500).json({ error: 'ファイルの保存に失敗しました。', details: saveErr.message });
      }
    });

  } catch (err) {
    try {
      if (fs.existsSync(tempPath)) {
        fs.unlinkSync(tempPath);
      }
    } catch (cleanupErr) {
      console.error(cleanupErr);
    }
    res.status(500).json({ error: 'ファイル操作エラー', details: err.message });
  }
});

// Endpoint to run haskell-log-unifier
app.post('/api/unify', (req, res) => {
  const { rulesFile, logsPath, services, startTime, endTime, useTimeFilter } = req.body;
  
  if (!rulesFile || !logsPath) {
    return res.status(400).json({ error: 'Rules file and logs path are required.' });
  }

  // Construct arguments
  const args = ['run', '-v0', 'haskell-log-unifier', '--'];
  
  // Determine if it uses advanced parameters
  const isAdvanced = services && useTimeFilter && startTime && endTime;
  
  if (isAdvanced) {
    args.push('--rules', rulesFile);
    args.push('--services', services);
    
    // Format: YYYY/MM/DD HH:MM
    const fmtStart = startTime.replace('T', ' ').substring(0, 16).replace(/-/g, '/');
    const fmtEnd = endTime.replace('T', ' ').substring(0, 16).replace(/-/g, '/');
    args.push('--time', `${fmtStart}-${fmtEnd}`);
    args.push('--logs', logsPath);
  } else {
    args.push('--rules', rulesFile);
    args.push('--logs', logsPath);
  }

  console.log('Executing: cabal', args.join(' '));

  const child = spawn('cabal', args, { cwd: PROJECT_ROOT });

  let stdoutData = '';
  let stderrData = '';

  child.stdout.on('data', (data) => {
    stdoutData += data.toString();
  });

  child.stderr.on('data', (data) => {
    stderrData += data.toString();
  });

  child.on('close', (code) => {
    if (code !== 0 && !stdoutData) {
      return res.status(500).json({
        error: `Log unifier exited with code ${code}`,
        details: stderrData || 'Unknown error'
      });
    }

    // Parse stdoutData
    const lines = stdoutData.split('\n');
    const entries = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = stripAnsi(lines[i]).trim();
      if (!line) continue;
      
      if (line.startsWith('→')) {
        if (entries.length > 0) {
          entries[entries.length - 1].transformed = line.substring(1).trim();
        }
      } else {
        entries.push({
          raw: line,
          transformed: null
        });
      }
    }

    res.json({
      success: true,
      logs: entries,
      stderr: stderrData
    });
  });
});

app.listen(PORT, () => {
  console.log(`Server is running at http://localhost:${PORT}`);
});
