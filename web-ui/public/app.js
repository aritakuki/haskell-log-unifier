document.addEventListener('DOMContentLoaded', () => {
  // Elements
  const form = document.getElementById('unifier-form');
  const rulesSelect = document.getElementById('rules-file');
  const editRulesBtn = document.getElementById('edit-rules-btn');
  const logsSelect = document.getElementById('logs-path');
  const useCustomPathCheck = document.getElementById('use-custom-path');
  const customLogsInput = document.getElementById('custom-logs-path');
  
  const useAdvancedCheck = document.getElementById('use-advanced-filter');
  const advancedFields = document.getElementById('advanced-fields');
  const servicesInput = document.getElementById('services-list');
  const startTimeInput = document.getElementById('start-time');
  const endTimeInput = document.getElementById('end-time');
  
  const submitBtn = document.getElementById('submit-btn');
  const btnText = submitBtn.querySelector('.btn-text');
  const loader = submitBtn.querySelector('.loader');
  
  const searchInput = document.getElementById('search-input');
  const statTotal = document.getElementById('stat-total');
  const statWarnings = document.getElementById('stat-warnings');
  const statClean = document.getElementById('stat-clean');
  
  const timelineContainer = document.getElementById('timeline-container');
  const placeholder = document.getElementById('timeline-placeholder');
  const errorAlert = document.getElementById('error-alert');
  const errorContent = document.getElementById('error-content');
  const timeline = document.getElementById('timeline');

  // Warnings Area Elements
  const warningsResultsWrapper = document.getElementById('warnings-results-wrapper');
  const warningsList = document.getElementById('warnings-list');

  // Modal Elements
  const ruleModal = document.getElementById('rule-modal');
  const closeModalBtn = document.getElementById('close-modal-btn');
  const cancelEditBtn = document.getElementById('cancel-edit-btn');
  const saveRulesBtn = document.getElementById('save-rules-btn');
  const rulesEditor = document.getElementById('rules-editor');
  const editorFilename = document.getElementById('editor-filename');
  const saveStatus = document.getElementById('save-status');
  const modalErrorAlert = document.getElementById('modal-error-alert');
  const modalErrorContent = document.getElementById('modal-error-content');
  const lineNumbers = document.getElementById('line-numbers');

  let loadedLogs = [];

  // Toggle Custom Path input
  useCustomPathCheck.addEventListener('change', () => {
    if (useCustomPathCheck.checked) {
      logsSelect.classList.add('hidden');
      logsSelect.removeAttribute('required');
      customLogsInput.classList.remove('hidden');
      customLogsInput.setAttribute('required', 'true');
    } else {
      logsSelect.classList.remove('hidden');
      logsSelect.setAttribute('required', 'true');
      customLogsInput.classList.add('hidden');
      customLogsInput.removeAttribute('required');
    }
  });

  // Toggle Advanced Filters
  useAdvancedCheck.addEventListener('change', () => {
    if (useAdvancedCheck.checked) {
      advancedFields.classList.remove('hidden');
      servicesInput.setAttribute('required', 'true');
      startTimeInput.setAttribute('required', 'true');
      endTimeInput.setAttribute('required', 'true');
    } else {
      advancedFields.classList.add('hidden');
      servicesInput.removeAttribute('required');
      startTimeInput.removeAttribute('required');
      endTimeInput.removeAttribute('required');
    }
  });

  // Enable/Disable edit rules button
  rulesSelect.addEventListener('change', () => {
    if (rulesSelect.value) {
      editRulesBtn.disabled = false;
    } else {
      editRulesBtn.disabled = true;
    }
  });

  // Helper to dynamically update editor line numbers
  function updateLineNumbers() {
    const text = rulesEditor.value;
    const lines = text.split('\n');
    const lineCount = Math.max(lines.length, 1);
    
    let numbersText = '';
    for (let i = 1; i <= lineCount; i++) {
      numbersText += i + '\n';
    }
    lineNumbers.textContent = numbersText;
  }

  // Sync scrolling of line numbers with editor
  rulesEditor.addEventListener('scroll', () => {
    lineNumbers.scrollTop = rulesEditor.scrollTop;
  });
  
  // Recalculate line numbers on user typing
  rulesEditor.addEventListener('input', updateLineNumbers);

  // Open rules editor modal
  editRulesBtn.addEventListener('click', async () => {
    const file = rulesSelect.value;
    if (!file) return;

    saveStatus.textContent = '';
    saveStatus.className = 'save-status';
    modalErrorAlert.classList.add('hidden');
    modalErrorContent.textContent = '';
    editorFilename.textContent = file;
    rulesEditor.value = 'ファイルをロード中...';
    lineNumbers.textContent = '1';
    ruleModal.classList.remove('hidden');

    try {
      const res = await fetch(`/api/rules/content?file=${encodeURIComponent(file)}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'ファイルの読み込みに失敗しました');
      
      rulesEditor.value = data.content;
      updateLineNumbers();
    } catch (err) {
      rulesEditor.value = '';
      saveStatus.textContent = err.message;
      saveStatus.className = 'save-status error';
      updateLineNumbers();
    }
  });

  // Close rules editor modal
  const hideModal = () => {
    ruleModal.classList.add('hidden');
    modalErrorAlert.classList.add('hidden');
    modalErrorContent.textContent = '';
  };
  closeModalBtn.addEventListener('click', hideModal);
  cancelEditBtn.addEventListener('click', hideModal);

  // Save rules content with frontend validation handling
  saveRulesBtn.addEventListener('click', async () => {
    const file = rulesSelect.value;
    const content = rulesEditor.value;
    if (!file) return;

    saveStatus.textContent = '保存中（構文チェックを実行中）...';
    saveStatus.className = 'save-status';
    saveRulesBtn.disabled = true;
    modalErrorAlert.classList.add('hidden');
    modalErrorContent.textContent = '';

    try {
      const res = await fetch('/api/rules/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ file, content })
      });
      const data = await res.json();
      
      if (!res.ok) {
        // Validation error or save error
        const detailsMsg = data.details ? `\n${data.details}` : '';
        throw new Error(data.error + detailsMsg);
      }

      saveStatus.textContent = '保存が完了しました！';
      saveStatus.className = 'save-status success';

      // Auto-refresh main timeline after 1 second
      setTimeout(() => {
        hideModal();
        saveRulesBtn.disabled = false;
        // Trigger analyzer submit if logs path is selected
        if (logsSelect.value || customLogsInput.value) {
          form.dispatchEvent(new Event('submit'));
        }
      }, 1000);

    } catch (err) {
      saveStatus.textContent = '保存に失敗しました。構文を確認してください。';
      saveStatus.className = 'save-status error';
      
      // Render details in the modal validation alert box
      const errMsg = err.message.replace(/^Error:\s*/i, '');
      modalErrorContent.textContent = errMsg;
      modalErrorAlert.classList.remove('hidden');
      saveRulesBtn.disabled = false;
    }
  });

  // Fetch initial resources (rules and log sources)
  async function fetchResources() {
    try {
      const res = await fetch('/api/resources');
      const data = await res.json();
      
      // Populate rules
      rulesSelect.innerHTML = '<option value="" disabled selected>選択してください...</option>';
      data.dslFiles.forEach(file => {
        const opt = document.createElement('option');
        opt.value = file;
        opt.textContent = file;
        rulesSelect.appendChild(opt);
      });

      // Populate log sources
      logsSelect.innerHTML = '<option value="" disabled selected>選択してください...</option>';
      data.logSources.forEach(source => {
        const opt = document.createElement('option');
        opt.value = source;
        opt.textContent = source;
        logsSelect.appendChild(opt);
      });
    } catch (err) {
      console.error('Failed to load resources:', err);
      rulesSelect.innerHTML = '<option value="" disabled>読み込み失敗</option>';
      logsSelect.innerHTML = '<option value="" disabled>読み込み失敗</option>';
    }
  }

  fetchResources();

  // Form submit - trigger log integration
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // Set loading state
    submitBtn.disabled = true;
    btnText.textContent = '分析中...';
    loader.classList.remove('hidden');
    
    // Reset output panels
    errorAlert.classList.add('hidden');
    timeline.classList.add('hidden');
    placeholder.classList.add('hidden');
    warningsResultsWrapper.classList.add('hidden');
    timeline.innerHTML = '';
    warningsList.innerHTML = '';
    
    const rulesFile = rulesSelect.value;
    const logsPath = useCustomPathCheck.checked ? customLogsInput.value : logsSelect.value;
    const useTimeFilter = useAdvancedCheck.checked;
    
    const requestData = {
      rulesFile,
      logsPath,
      useTimeFilter,
      services: useTimeFilter ? servicesInput.value : null,
      startTime: useTimeFilter ? startTimeInput.value : null,
      endTime: useTimeFilter ? endTimeInput.value : null
    };

    try {
      const res = await fetch('/api/unify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestData)
      });

      const result = await res.json();

      if (!res.ok) {
        throw new Error(result.error + (result.details ? `\n\n${result.details}` : ''));
      }

      loadedLogs = result.logs;
      renderTimeline(loadedLogs);
      updateDashboard(loadedLogs);
      
      // Enable Search
      searchInput.disabled = false;
      searchInput.value = '';

    } catch (err) {
      console.error(err);
      errorContent.textContent = err.message;
      errorAlert.classList.remove('hidden');
      
      // Reset Stats
      statTotal.textContent = '-';
      statWarnings.textContent = '-';
      statClean.textContent = '-';
      searchInput.disabled = true;
    } finally {
      // Clear loading state
      submitBtn.disabled = false;
      btnText.textContent = 'ログを統合・分析';
      loader.classList.add('hidden');
    }
  });

  // Render logs as timeline items and populate separate warning area
  function renderTimeline(logs) {
    timeline.innerHTML = '';
    warningsList.innerHTML = '';

    if (logs.length === 0) {
      timeline.innerHTML = '<div class="timeline-placeholder"><h3>ログが見つかりませんでした</h3><p>条件に一致するログが存在しません。</p></div>';
      timeline.classList.remove('hidden');
      warningsResultsWrapper.classList.add('hidden');
      return;
    }

    // Populate separate warning & translation results
    const warnings = logs.filter(log => log.transformed !== null);
    if (warnings.length > 0) {
      warningsResultsWrapper.classList.remove('hidden');
      warnings.forEach(log => {
        const card = document.createElement('div');
        card.className = 'warning-item-card';
        
        // Severity subclass detection
        if (log.transformed.includes('【エラー】')) {
          card.classList.add('error');
        } else if (log.transformed.includes('【障害】')) {
          card.classList.add('failure');
        } else if (log.transformed.includes('【警告】')) {
          card.classList.add('warning');
        } else {
          card.classList.add('info');
        }
        
        const transDiv = document.createElement('div');
        transDiv.className = 'warn-trans';
        transDiv.textContent = log.transformed;
        card.appendChild(transDiv);
        
        warningsList.appendChild(card);
      });
    } else {
      warningsResultsWrapper.classList.add('hidden');
    }

    // Populate main timeline
    logs.forEach(log => {
      const item = document.createElement('div');
      item.className = 'timeline-item';
      if (log.transformed) {
        item.classList.add('transformed');
      }

      const rawSpan = document.createElement('div');
      rawSpan.className = 'raw-log';
      rawSpan.textContent = log.raw;
      item.appendChild(rawSpan);

      if (log.transformed) {
        const transSpan = document.createElement('div');
        transSpan.className = 'transformed-log';
        transSpan.textContent = log.transformed;
        item.appendChild(transSpan);
      }

      timeline.appendChild(item);
    });

    timeline.classList.remove('hidden');
  }

  // Update metrics dashboard
  function updateDashboard(logs) {
    const rawLogsCount = logs.length;
    const warningsCount = logs.filter(log => log.transformed !== null).length;
    const totalLinesCount = rawLogsCount + warningsCount;

    statTotal.textContent = totalLinesCount;
    statWarnings.textContent = warningsCount;
    statClean.textContent = rawLogsCount;
  }

  // Search filter implementation
  searchInput.addEventListener('input', () => {
    const query = searchInput.value.toLowerCase().trim();
    if (!query) {
      renderTimeline(loadedLogs);
      return;
    }

    const filtered = loadedLogs.filter(log => {
      const matchRaw = log.raw.toLowerCase().includes(query);
      const matchTrans = log.transformed && log.transformed.toLowerCase().includes(query);
      return matchRaw || matchTrans;
    });

    renderTimeline(filtered);
  });
});
