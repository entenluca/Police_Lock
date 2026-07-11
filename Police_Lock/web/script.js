/* AutoGlovebox Admin NUI
 * Callbacks: getLoadouts, refresh, close, saveLoadout, deleteLoadout,
 * addItem, removeItem, resetEquipped, fillVehicle, copyLoadout
 */

// ---------- NotifyX (eingebettetes Benachrichtigungssystem) ----------
const NotifyX = {
    maxVisible: 5,
    defaultDuration: 4500,
    stack: null,

    icons: {
        success: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M20 6 9 17l-5-5"/></svg>',
        error: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
        warning: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 4.2 2.6 17.1A1.7 1.7 0 0 0 4.1 19.5h15.8a1.7 1.7 0 0 0 1.5-2.4L13.7 4.2a1.7 1.7 0 0 0-3.4 0z"/></svg>',
        info: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>',
    },

    titles: {
        success: 'Erfolg',
        error: 'Fehler',
        warning: 'Hinweis',
        info: 'Info',
    },

    init(stackElement) {
        this.stack = stackElement;
    },

    clear() {
        if (this.stack) {
            this.stack.innerHTML = '';
        }
    },

    notify({ title, message, type = 'info', duration }) {
        if (!this.stack || !message) {
            return null;
        }

        const normalizedType = ['success', 'error', 'warning', 'info'].includes(type) ? type : 'info';
        const ms = typeof duration === 'number' ? duration : this.defaultDuration;
        const resolvedTitle = title || this.titles[normalizedType];
        const showTitle = Boolean(title);
        const notifyKey = `${normalizedType}:${resolvedTitle}:${message}`;

        const existing = Array.from(this.stack.children).find((child) => child.dataset.notifyKey === notifyKey);
        if (existing) {
            existing.remove();
        }

        while (this.stack.children.length >= this.maxVisible) {
            this.stack.firstElementChild?.remove();
        }

        const el = document.createElement('div');
        el.className = `notifyx is-${normalizedType}`;
        el.dataset.notifyKey = notifyKey;
        el.innerHTML = `
            <div class="notifyx-icon">${this.icons[normalizedType]}</div>
            <div class="notifyx-body">
                ${showTitle ? `<div class="notifyx-title">${this.escape(resolvedTitle)}</div>` : ''}
                <div class="notifyx-message${showTitle ? '' : ' is-primary'}">${this.escape(message)}</div>
            </div>
            <button class="notifyx-close" type="button" aria-label="Schließen">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>
            </button>
            <div class="notifyx-progress"><span style="animation-duration:${ms}ms"></span></div>
        `;

        const remove = () => {
            if (!el.isConnected) return;
            el.classList.add('leaving');
            setTimeout(() => el.remove(), 220);
        };

        el.querySelector('.notifyx-close').addEventListener('click', remove);
        this.stack.appendChild(el);

        if (ms > 0) {
            setTimeout(remove, ms);
        }

        return el;
    },

    escape(value) {
        return String(value).replace(/[&<>"']/g, (char) => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;',
        }[char]));
    },
};

// ---------- Dev-Mock (nur außerhalb von FiveM aktiv) ----------
const IS_DEV = typeof GetParentResourceName === 'undefined';

const STORAGE_LABELS = {
    glovebox: 'Handschuhfach',
    trunk: 'Kofferraum',
};

const devState = {
    defaultAddMode: 'once',
    nextId: 100,
    loadouts: [
        { id: 1, loadout_type: 'model', loadout_key: 'sektranser', storage_type: 'glovebox', add_mode: null, items: [
            { id: 11, item: 'zf_weste', amount: 1 },
            { id: 12, item: 'einsatzmappe', amount: 1 },
            { id: 13, item: 'flashlight', amount: 2 },
        ]},
        { id: 2, loadout_type: 'model', loadout_key: 'hlf', storage_type: 'glovebox', add_mode: 'always', items: [
            { id: 21, item: 'atemschutzmaske', amount: 4 },
            { id: 22, item: 'feuerwehraxt', amount: 1 },
        ]},
        { id: 3, loadout_type: 'plate', loadout_key: 'FW 1234', storage_type: 'glovebox', add_mode: 'once', items: [
            { id: 31, item: 'funkgeraet', amount: 2 },
        ]},
        { id: 4, loadout_type: 'model', loadout_key: 'rtw', storage_type: 'trunk', add_mode: null, items: [
            { id: 41, item: 'bandage', amount: 10 },
            { id: 42, item: 'defibrillator', amount: 1 },
            { id: 43, item: 'painkillers', amount: 5 },
        ]},
    ],
};

function devPost(name, data) {
    const s = devState;
    const payload = { loadouts: JSON.parse(JSON.stringify(s.loadouts)), defaultAddMode: s.defaultAddMode };
    switch (name) {
        case 'getLoadouts': return payload;
        case 'refresh': return { success: true, ...payload };
        case 'close':
            setUiVisible(false);
            if (IS_DEV) setTimeout(() => setUiVisible(true), 400);
            return { success: true };
        case 'saveLoadout': {
            if (!data.loadout_key) return { success: false, error: 'Schlüssel darf nicht leer sein.' };
            let entry = s.loadouts.find((l) => l.id === data.id);
            if (!entry) { entry = { id: s.nextId++, items: [] }; s.loadouts.push(entry); }
            Object.assign(entry, {
                loadout_type: data.loadout_type,
                loadout_key: data.loadout_key,
                storage_type: data.storage_type || 'glovebox',
                add_mode: data.add_mode,
            });
            return { success: true, loadoutId: entry.id };
        }
        case 'deleteLoadout':
            s.loadouts = s.loadouts.filter((l) => l.id !== data.loadoutId);
            return { success: true };
        case 'addItem': {
            const entry = s.loadouts.find((l) => l.id === data.loadout_id);
            if (!entry) return { success: false, error: 'Loadout nicht gefunden.' };
            entry.items.push({ id: s.nextId++, item: data.item, amount: data.amount });
            return { success: true };
        }
        case 'removeItem':
            s.loadouts.forEach((l) => { l.items = l.items.filter((i) => i.id !== data.itemId); });
            return { success: true };
        case 'resetEquipped': return { success: true };
        case 'fillVehicle': {
            if (!data.loadoutId) {
                return { success: false, error: 'Bitte zuerst den Loadout speichern.', type: 'error' };
            }
            return {
                success: true,
                title: 'Erfolg',
                message: 'Fahrzeug wurde befüllt (Dev-Modus).',
                type: 'success',
            };
        }
        case 'copyLoadout': {
            if (!data.newSpawnName) return { success: false, error: 'Spawn-Name fehlt.' };
            const source = s.loadouts.find((l) => l.id === data.loadoutId);
            if (!source || source.loadout_type !== 'model') return { success: false, error: 'Nur Modell-Loadouts können kopiert werden.' };
            const spawnName = data.newSpawnName.toLowerCase();
            if (s.loadouts.some((l) => l.loadout_type === 'model' && l.loadout_key === spawnName && l.storage_type === source.storage_type)) {
                return { success: false, error: 'Spawn-Name existiert bereits.' };
            }
            const copy = {
                id: s.nextId++,
                loadout_type: 'model',
                loadout_key: spawnName,
                storage_type: source.storage_type || 'glovebox',
                add_mode: source.add_mode,
                items: source.items.map((item) => ({ ...item, id: s.nextId++ })),
            };
            s.loadouts.push(copy);
            return { success: true, loadoutId: copy.id };
        }
        default: return { success: false };
    }
}

// ---------- DOM ----------
const app = document.getElementById('app');
const loadoutList = document.getElementById('loadoutList');
const emptyState = document.getElementById('emptyState');
const editorPanel = document.getElementById('editorPanel');
const statusBar = document.getElementById('statusBar');
const statusDot = document.getElementById('statusDot');
const itemsList = document.getElementById('itemsList');
const itemsEmpty = document.getElementById('itemsEmpty');
const keyInput = document.getElementById('loadoutKey');
const dirtyBadge = document.getElementById('dirtyBadge');

NotifyX.init(document.getElementById('notifyxStack'));

let loadouts = [];
let selectedLoadout = null;
let defaultAddMode = 'once';
let activeTab = 'all';
let activeStorage = 'glovebox';
let searchQuery = '';
let editorType = 'model';
let editorMode = 'once';
let isDirty = false;

function post(name, data = {}) {
    if (IS_DEV) return Promise.resolve(devPost(name, data));
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then((response) => response.json());
}

// ---------- UI-Helfer ----------
function showNotify(message, type = 'success', title) {
    NotifyX.notify({ title, message, type });
}

function showResult(result, fallbackError) {
    if (result.success) {
        showNotify(result.message || 'Aktion erfolgreich.', result.type || 'success', result.title);
        return true;
    }

    showNotify(result.error || result.message || fallbackError, result.type || 'error', result.title);
    return false;
}

function setStatus(message, state = 'ready') {
    if (state === true) state = 'busy';
    if (state === false) state = 'ready';
    statusBar.textContent = message;
    statusDot.classList.remove('is-busy', 'is-error');
    if (state === 'busy') statusDot.classList.add('is-busy');
    if (state === 'error') statusDot.classList.add('is-error');
}

function setDirty(value) {
    isDirty = value;
    dirtyBadge.classList.toggle('hidden', !value);
}

function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function confirmDialog({ title, text, okLabel = 'Löschen' }) {
    return new Promise((resolve) => {
        const overlay = document.getElementById('confirmOverlay');
        document.getElementById('confirmTitle').textContent = title;
        document.getElementById('confirmText').innerHTML = text;
        const okBtn = document.getElementById('confirmOk');
        okBtn.textContent = okLabel;
        overlay.classList.remove('hidden');

        const done = (result) => {
            overlay.classList.add('hidden');
            okBtn.onclick = null;
            document.getElementById('confirmCancel').onclick = null;
            overlay.onclick = null;
            resolve(result);
        };

        okBtn.onclick = () => done(true);
        document.getElementById('confirmCancel').onclick = () => done(false);
        overlay.onclick = (e) => { if (e.target === overlay) done(false); };
    });
}

function getStorageLabel(storageType) {
    return STORAGE_LABELS[storageType] || STORAGE_LABELS.glovebox;
}

function getVisibleLoadouts() {
    return loadouts.filter((entry) => (entry.storage_type || 'glovebox') === activeStorage);
}

function updateStorageUi() {
    const label = getStorageLabel(activeStorage);
    document.getElementById('itemsSectionTitle').textContent = `Items im ${label}`;
    document.getElementById('fillVehicleBtnLabel').textContent = `${label} befüllen`;
}

function setActiveStorageTab(storageType) {
    activeStorage = storageType || 'glovebox';
    document.querySelectorAll('.storage-tab').forEach((tab) => {
        tab.classList.toggle('active', tab.dataset.storage === activeStorage);
    });
    updateStorageUi();
}

// ---------- Rendering ----------
function updateStats() {
    const visible = getVisibleLoadouts();
    const models = visible.filter((e) => e.loadout_type === 'model').length;
    const plates = visible.filter((e) => e.loadout_type === 'plate').length;
    const items = visible.reduce((sum, e) => sum + e.items.length, 0);

    document.getElementById('countAll').textContent = visible.length;
    document.getElementById('countModel').textContent = models;
    document.getElementById('countPlate').textContent = plates;
    document.getElementById('statLoadouts').textContent = visible.length;
    document.getElementById('statItems').textContent = items;
    document.getElementById('statMode').textContent = defaultAddMode;
}

function getFilteredLoadouts() {
    const query = searchQuery.toLowerCase();
    return getVisibleLoadouts()
        .filter((entry) => {
            const matchesTab = activeTab === 'all' || entry.loadout_type === activeTab;
            const matchesSearch = !query
                || entry.loadout_key.toLowerCase().includes(query)
                || entry.items.some((item) => item.item.toLowerCase().includes(query));
            return matchesTab && matchesSearch;
        })
        .sort((a, b) => a.loadout_key.localeCompare(b.loadout_key));
}

function renderLoadouts() {
    const filtered = getFilteredLoadouts();
    loadoutList.innerHTML = '';

    if (filtered.length === 0) {
        loadoutList.innerHTML = '<p class="list-empty">Keine Loadouts gefunden.</p>';
        return;
    }

    filtered.forEach((loadout) => {
        const isModel = loadout.loadout_type === 'model';
        const card = document.createElement('button');
        card.type = 'button';
        card.className = `loadout-card${selectedLoadout?.id === loadout.id ? ' active' : ''}`;
        card.innerHTML = `
            <div class="title">${escapeHtml(loadout.loadout_key)}</div>
            <div class="meta">
                <span class="chip">${isModel ? 'Modell' : 'Kennzeichen'}</span>
                <span class="chip">${loadout.add_mode || defaultAddMode}</span>
                <span class="chip chip-items">${loadout.items.length} Item${loadout.items.length === 1 ? '' : 's'}</span>
            </div>
        `;
        card.addEventListener('click', () => selectLoadout(loadout.id));
        loadoutList.appendChild(card);
    });
}

function renderItems() {
    itemsList.innerHTML = '';
    const items = selectedLoadout?.items || [];
    document.getElementById('itemCount').textContent = `${items.length} Item${items.length === 1 ? '' : 's'}`;
    itemsEmpty.classList.toggle('hidden', items.length > 0);

    items.forEach((item) => {
        const row = document.createElement('div');
        row.className = 'item-row';
        row.innerHTML = `
            <strong>${escapeHtml(item.item)}</strong>
            <span class="item-amount">${item.amount}×</span>
            <button class="item-remove" title="Entfernen">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>
            </button>
        `;

        row.querySelector('.item-remove').addEventListener('click', async () => {
            const result = await post('removeItem', { itemId: item.id });
            if (!result.success) {
                showNotify(result.error || 'Item konnte nicht entfernt werden.', 'error');
                return;
            }
            await refreshLoadouts();
            showNotify(`"${item.item}" entfernt.`);
        });

        itemsList.appendChild(row);
    });
}

function setSegmented(segEl, value) {
    segEl.querySelectorAll('button').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.value === value);
    });
}

function updateHints() {
    const isModel = editorType === 'model';
    document.getElementById('keyLabel').textContent = isModel ? 'Modellname' : 'Kennzeichen';
    document.getElementById('keyHint').textContent = isModel
        ? 'Nur Kleinbuchstaben, ohne Leerzeichen'
        : 'Exakt wie im Spiel, inkl. Leerzeichen';
    keyInput.placeholder = isModel ? 'z. B. hlf20' : 'z. B. 54554SW';

    const modeHints = {
        once: 'Items werden pro Fahrzeug nur einmal eingelegt',
        always: 'Items werden bei jedem Spawn eingelegt',
    };
    document.getElementById('modeHint').textContent = modeHints[editorMode] || modeHints.once;
    document.getElementById('resetEquippedBtn').classList.toggle('hidden', editorType !== 'plate' || !selectedLoadout?.id);
    document.getElementById('copyLoadoutBtn').classList.toggle('hidden', editorType !== 'model' || !selectedLoadout?.id);
    document.getElementById('fillVehicleBtn').disabled = !selectedLoadout?.id || (selectedLoadout?.items?.length || 0) === 0;
    updateStorageUi();
}

function updateEditorBadges() {
    const badge = document.getElementById('editorBadge');
    const modeBadge = document.getElementById('editorModeBadge');

    if (!selectedLoadout?.id) {
        badge.textContent = 'Neu';
        badge.className = 'badge badge-type is-new';
    } else {
        badge.textContent = editorType === 'model' ? 'Modell' : 'Kennzeichen';
        badge.className = `badge badge-type${editorType === 'plate' ? ' is-plate' : ''}`;
    }
    modeBadge.textContent = editorMode === 'always' ? 'Immer' : 'Einmal';
}

function showEditor(loadout) {
    selectedLoadout = loadout;
    emptyState.classList.add('hidden');
    editorPanel.classList.remove('hidden');

    editorType = loadout.loadout_type;
    editorMode = loadout.add_mode || defaultAddMode;
    setActiveStorageTab(loadout.storage_type || activeStorage);
    keyInput.value = loadout.loadout_key;
    document.getElementById('editorTitle').textContent = loadout.loadout_key || 'Neuer Loadout';
    setSegmented(document.getElementById('typeSeg'), editorType);
    setSegmented(document.getElementById('modeSeg'), editorMode);
    setDirty(!loadout.id);
    updateEditorBadges();
    updateHints();
    renderLoadouts();
    renderItems();
}

function selectLoadout(loadoutId) {
    const found = loadouts.find((entry) => entry.id === loadoutId) || null;
    if (!found) {
        selectedLoadout = null;
        emptyState.classList.remove('hidden');
        editorPanel.classList.add('hidden');
        renderLoadouts();
        return;
    }
    showEditor(found);
}

async function refreshLoadouts() {
    setStatus('Lade Daten…', true);
    const data = await post('getLoadouts');
    loadouts = data.loadouts || [];
    defaultAddMode = data.defaultAddMode || 'once';
    updateStats();

    if (selectedLoadout?.id) {
        selectLoadout(selectedLoadout.id);
    } else {
        renderLoadouts();
        renderItems();
    }
    setStatus('Bereit');
}

// ---------- Events ----------
document.getElementById('closeBtn').addEventListener('click', () => post('close'));

document.getElementById('refreshBtn').addEventListener('click', async () => {
    setStatus('Aktualisiere…', true);
    const result = await post('refresh');
    if (result.success) {
        loadouts = result.loadouts || [];
        defaultAddMode = result.defaultAddMode || 'once';
        updateStats();
        if (selectedLoadout?.id) selectLoadout(selectedLoadout.id);
        else renderLoadouts();
        showNotify('Daten aktualisiert.');
    }
    setStatus('Bereit');
});

document.getElementById('newLoadoutBtn').addEventListener('click', () => {
    showEditor({
        id: null,
        loadout_type: 'model',
        loadout_key: '',
        storage_type: activeStorage,
        add_mode: defaultAddMode,
        items: [],
    });
    keyInput.focus();
});

document.getElementById('typeSeg').addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-value]');
    if (!btn) return;
    editorType = btn.dataset.value;
    setSegmented(document.getElementById('typeSeg'), editorType);
    setDirty(true);
    updateEditorBadges();
    updateHints();
});

document.getElementById('modeSeg').addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-value]');
    if (!btn) return;
    editorMode = btn.dataset.value;
    setSegmented(document.getElementById('modeSeg'), editorMode);
    setDirty(true);
    updateEditorBadges();
    updateHints();
});

keyInput.addEventListener('input', () => setDirty(true));

document.querySelectorAll('.storage-tab').forEach((tab) => {
    tab.addEventListener('click', () => {
        setActiveStorageTab(tab.dataset.storage);
        selectedLoadout = null;
        emptyState.classList.remove('hidden');
        editorPanel.classList.add('hidden');
        updateStats();
        renderLoadouts();
    });
});

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((entry) => entry.classList.remove('active'));
        tab.classList.add('active');
        activeTab = tab.dataset.tab;
        renderLoadouts();
    });
});

document.getElementById('searchInput').addEventListener('input', (event) => {
    searchQuery = event.target.value.trim();
    renderLoadouts();
});

document.getElementById('saveLoadoutBtn').addEventListener('click', async () => {
    const key = keyInput.value.trim();
    if (!key) {
        showNotify(`Bitte ein${editorType === 'model' ? 'en Modellnamen' : ' Kennzeichen'} eingeben.`, 'error');
        keyInput.focus();
        return;
    }

    const payload = {
        id: selectedLoadout?.id || null,
        loadout_type: editorType,
        loadout_key: editorType === 'model' ? key.toLowerCase() : key,
        storage_type: activeStorage,
        add_mode: editorMode,
    };

    const result = await post('saveLoadout', payload);
    if (!result.success) {
        showNotify(result.error || 'Loadout konnte nicht gespeichert werden.', 'error');
        return;
    }

    await refreshLoadouts();
    selectLoadout(result.loadoutId);
    setDirty(false);
    showNotify('Loadout gespeichert.');
});

document.getElementById('deleteLoadoutBtn').addEventListener('click', async () => {
    if (!selectedLoadout?.id) {
        selectLoadout(null);
        return;
    }

    const ok = await confirmDialog({
        title: 'Loadout löschen?',
        text: `<code>${escapeHtml(selectedLoadout.loadout_key)}</code> und alle zugehörigen Items werden dauerhaft gelöscht.`,
    });
    if (!ok) return;

    const result = await post('deleteLoadout', { loadoutId: selectedLoadout.id });
    if (!result.success) {
        showNotify(result.error || 'Loadout konnte nicht gelöscht werden.', 'error');
        return;
    }

    selectedLoadout = null;
    emptyState.classList.remove('hidden');
    editorPanel.classList.add('hidden');
    await refreshLoadouts();
    showNotify('Loadout gelöscht.');
});

async function addItem() {
    const item = document.getElementById('itemName').value.trim();
    const amount = Math.max(1, Math.min(999, Number(document.getElementById('itemAmount').value || 1)));

    if (!selectedLoadout?.id) {
        showNotify('Bitte zuerst den Loadout speichern.', 'error');
        return;
    }
    if (!item) {
        showNotify('Bitte einen Item-Namen eingeben.', 'error');
        document.getElementById('itemName').focus();
        return;
    }

    const result = await post('addItem', { loadout_id: selectedLoadout.id, item, amount });
    if (!result.success) {
        showNotify(result.error || 'Item konnte nicht hinzugefügt werden.', 'error');
        return;
    }

    document.getElementById('itemName').value = '';
    document.getElementById('itemAmount').value = '1';
    await refreshLoadouts();
    showNotify(`"${item}" hinzugefügt.`);
    document.getElementById('itemName').focus();
}

document.getElementById('addItemBtn').addEventListener('click', addItem);
document.getElementById('itemName').addEventListener('keydown', (e) => { if (e.key === 'Enter') addItem(); });
document.getElementById('itemAmount').addEventListener('keydown', (e) => { if (e.key === 'Enter') addItem(); });

document.getElementById('amountMinus').addEventListener('click', () => {
    const input = document.getElementById('itemAmount');
    input.value = Math.max(1, Number(input.value || 1) - 1);
});

document.getElementById('amountPlus').addEventListener('click', () => {
    const input = document.getElementById('itemAmount');
    input.value = Math.min(999, Number(input.value || 1) + 1);
});

document.getElementById('resetEquippedBtn').addEventListener('click', async () => {
    if (!selectedLoadout || selectedLoadout.loadout_type !== 'plate') {
        showNotify('Reset nur für Kennzeichen-Loadouts verfügbar.', 'error');
        return;
    }

    const result = await post('resetEquipped', {
        plate: selectedLoadout.loadout_key,
        storage_type: selectedLoadout.storage_type || activeStorage,
    });
    if (!result.success) {
        showNotify(result.error || 'Reset fehlgeschlagen.', 'error');
        return;
    }
    showNotify('Once-Status zurückgesetzt.');
});

document.getElementById('fillVehicleBtn').addEventListener('click', async () => {
    const fillBtn = document.getElementById('fillVehicleBtn');

    if (fillBtn.disabled) {
        return;
    }

    if (!selectedLoadout?.id) {
        showNotify('Bitte zuerst den Loadout speichern.', 'error');
        return;
    }

    if (!selectedLoadout.items?.length) {
        showNotify('Dieser Loadout enthält keine Items.', 'warning');
        return;
    }

    fillBtn.disabled = true;
    setStatus('Befülle Fahrzeug…', true);

    try {
        const result = await post('fillVehicle', {
            loadoutId: selectedLoadout.id,
            loadoutType: selectedLoadout.loadout_type,
            loadoutKey: selectedLoadout.loadout_key,
        });
        showResult(result, 'Fahrzeug konnte nicht befüllt werden.');
    } finally {
        setStatus('Bereit');
        updateHints();
    }
});

function openCopyDialog() {
    if (!selectedLoadout?.id || editorType !== 'model') {
        showNotify('Kopieren nur für gespeicherte Modell-Loadouts möglich.', 'error');
        return;
    }

    document.getElementById('copySourceName').textContent = selectedLoadout.loadout_key;
    const input = document.getElementById('copySpawnName');
    input.value = '';
    document.getElementById('copyOverlay').classList.remove('hidden');
    input.focus();
}

function closeCopyDialog() {
    document.getElementById('copyOverlay').classList.add('hidden');
}

document.getElementById('copyLoadoutBtn').addEventListener('click', openCopyDialog);
document.getElementById('copyCancel').addEventListener('click', closeCopyDialog);

document.getElementById('copyOk').addEventListener('click', async () => {
    const newSpawnName = document.getElementById('copySpawnName').value.trim().toLowerCase();

    if (!newSpawnName) {
        showNotify('Bitte einen Spawn-Namen eingeben.', 'error');
        return;
    }

    if (!selectedLoadout?.id) {
        showNotify('Kein Loadout ausgewählt.', 'error');
        return;
    }

    const result = await post('copyLoadout', {
        loadoutId: selectedLoadout.id,
        newSpawnName,
    });

    if (!result.success) {
        showNotify(result.error || 'Kopieren fehlgeschlagen.', 'error');
        return;
    }

    closeCopyDialog();
    await refreshLoadouts();
    selectLoadout(result.loadoutId);
    showNotify(`"${newSpawnName}" wurde erstellt.`);
});

document.getElementById('copySpawnName').addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        document.getElementById('copyOk').click();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        const copyOverlay = document.getElementById('copyOverlay');
        if (!copyOverlay.classList.contains('hidden')) {
            closeCopyDialog();
            return;
        }

        const overlay = document.getElementById('confirmOverlay');
        if (!overlay.classList.contains('hidden')) {
            overlay.classList.add('hidden');
            return;
        }
        post('close');
    }
});

function setUiVisible(visible) {
    const root = document.documentElement;

    if (visible) {
        root.classList.remove('nui-hidden');
        root.style.display = '';
        document.body.style.display = '';
    } else {
        document.getElementById('confirmOverlay').classList.add('hidden');
        document.getElementById('copyOverlay').classList.add('hidden');
        NotifyX.clear();
        root.classList.add('nui-hidden');
        root.style.display = 'none';
        selectedLoadout = null;
    }
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'open') {
        setUiVisible(true);
        refreshLoadouts();
        setStatus('Bereit');
    }

    if (event.data.action === 'close') {
        setUiVisible(false);
    }

    if (event.data.action === 'notify') {
        NotifyX.notify({
            title: event.data.title,
            message: event.data.message,
            type: event.data.type || 'info',
            duration: event.data.duration,
        });
    }
});

// Dev: Panel direkt öffnen
if (IS_DEV) {
    setUiVisible(true);
    updateStorageUi();
    refreshLoadouts();
}
