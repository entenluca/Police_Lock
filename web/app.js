const app = document.getElementById('app');
const viewAuth = document.getElementById('view-auth');
const viewLocker = document.getElementById('view-locker');
const viewAdmin = document.getElementById('view-admin');
const pinDisplay = document.getElementById('pin-display');
const pinPad = document.getElementById('pin-pad');
const authMessage = document.getElementById('auth-message');
const itemsGrid = document.getElementById('items-grid');
const confirmOverlay = document.getElementById('confirm-overlay');

let state = {
    pin: '',
    token: null,
    session: null,
    lockerData: null,
    adminData: null,
    selectedLocker: null,
    strings: {},
    confirmThreshold: 10,
    pendingAction: null,
};

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'fivem_lockers';

function nuiFetch(endpoint, data = {}) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

function requestId() {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function showApp() {
    document.documentElement.classList.remove('nui-hidden');
    app.classList.remove('hidden');
}

function hideApp() {
    app.classList.add('hidden');
    viewAuth.classList.add('hidden');
    viewLocker.classList.add('hidden');
    viewAdmin.classList.add('hidden');
    document.documentElement.classList.add('nui-hidden');
}

function toast(message, type = 'info') {
    const stack = document.getElementById('toast-stack');
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = message;
    stack.appendChild(el);
    setTimeout(() => el.remove(), 3500);
}

function showMessage(text, type = 'error') {
    authMessage.textContent = text;
    authMessage.className = `message ${type}`;
    authMessage.classList.remove('hidden');
}

function renderPinDots() {
    pinDisplay.innerHTML = '';
    for (let i = 0; i < 8; i += 1) {
        const dot = document.createElement('span');
        dot.className = `pin-dot${i < state.pin.length ? ' filled' : ''}`;
        pinDisplay.appendChild(dot);
    }
}

function buildPinPad() {
    pinPad.innerHTML = '';
    const keys = ['1','2','3','4','5','6','7','8','9','0'];

    keys.forEach((key) => {
        const btn = document.createElement('button');
        btn.className = 'pin-key';
        btn.textContent = key;
        btn.addEventListener('click', () => {
            if (state.pin.length < 8) {
                state.pin += key;
                renderPinDots();
            }
        });
        pinPad.appendChild(btn);
    });
}

function openAuth(session, strings) {
    state.session = session;
    state.token = session.token;
    state.pin = '';
    state.strings = strings || {};

    document.getElementById('auth-title').textContent = strings.pin_title || 'PIN eingeben';
    document.getElementById('auth-subtitle').textContent = session.name || '';
    document.getElementById('pin-clear').textContent = strings.pin_clear || 'Löschen';
    document.getElementById('pin-submit').textContent = strings.pin_confirm || 'Bestätigen';
    document.getElementById('use-key-btn').classList.toggle('hidden', !session.requires_key);
    authMessage.classList.add('hidden');

    showApp();
    viewAuth.classList.remove('hidden');
    viewLocker.classList.add('hidden');
    viewAdmin.classList.add('hidden');
    renderPinDots();
}

function openLocker(payload) {
    state.lockerData = payload;
    state.token = payload.token;
    state.strings = payload.strings || {};
    state.confirmThreshold = payload.confirm_threshold || 10;

    document.getElementById('locker-name').textContent = payload.locker.name;
    document.getElementById('locker-desc').textContent = payload.locker.description || '';

    showApp();
    viewLocker.classList.remove('hidden');
    viewAuth.classList.add('hidden');
    viewAdmin.classList.add('hidden');
    renderItems(payload.items || []);
}

function renderItems(items) {
    itemsGrid.innerHTML = '';

    if (!items.length) {
        itemsGrid.innerHTML = '<div class="empty-state">Keine Items verfügbar.</div>';
        return;
    }

    items.forEach((item) => {
        const card = document.createElement('article');
        card.className = `item-card${item.allowed ? '' : ' disabled'}`;

        const stockText = item.unlimited ? (state.strings.unlimited || 'Unbegrenzt') : item.amount;
        const maxTake = item.maximum_take_amount || 1;

        card.innerHTML = `
            <div class="item-image-wrap">
                <img src="${item.image}" alt="${item.display_name}" onerror="this.src='nui://ox_inventory/web/images/placeholder.png'">
                <span class="rank-badge">${item.rank_label || ''}</span>
            </div>
            <div class="item-body">
                <h3>${item.display_name}</h3>
                <p>${item.description || ''}</p>
                <div class="item-stats">
                    <div>${state.strings.stock || 'Bestand'}<strong>${stockText}</strong></div>
                    <div>${state.strings.inventory || 'Inventar'}<strong>${item.player_amount}</strong></div>
                    <div>${state.strings.weight || 'Gewicht'}<strong>${item.weight}g</strong></div>
                    <div>Max<strong>${maxTake}</strong></div>
                </div>
                <div class="amount-input">
                    <input type="number" min="1" max="${maxTake}" value="1" data-amount>
                </div>
                <div class="card-actions">
                    <button class="btn btn-primary" data-take ${item.allowed ? '' : 'disabled'}>${state.strings.take || 'Nehmen'}</button>
                    <button class="btn btn-ghost" data-return ${item.returnable && item.allowed ? '' : 'disabled'}>${state.strings.return_item || 'Zurücklegen'}</button>
                </div>
            </div>
        `;

        const amountInput = card.querySelector('[data-amount]');
        const takeBtn = card.querySelector('[data-take]');
        const returnBtn = card.querySelector('[data-return]');

        if (takeBtn) {
            takeBtn.addEventListener('click', () => {
                const amount = Math.min(parseInt(amountInput.value, 10) || 1, maxTake);
                handleTake(item, amount);
            });
        }

        if (returnBtn) {
            returnBtn.addEventListener('click', () => {
                const amount = Math.min(parseInt(amountInput.value, 10) || 1, maxTake);
                handleReturn(item, amount);
            });
        }

        itemsGrid.appendChild(card);
    });
}

function confirmAction(title, text, callback) {
    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-text').textContent = text;
    state.pendingAction = callback;
    confirmOverlay.classList.remove('hidden');
}

function handleTake(item, amount) {
    const run = () => {
        document.getElementById('locker-loading').classList.remove('hidden');
        nuiFetch('takeItem', { itemId: item.id, amount, requestId: requestId() });
    };

    if (amount >= state.confirmThreshold) {
        const text = (state.strings.confirm_take || '%sx %s entnehmen?')
            .replace('%s', amount)
            .replace('%s', item.display_name);
        confirmAction('Bestätigen', text, run);
        return;
    }

    run();
}

function handleReturn(item, amount) {
    document.getElementById('locker-loading').classList.remove('hidden');
    nuiFetch('returnItem', { itemId: item.id, amount, requestId: requestId() });
}

function openAdmin(payload, strings) {
    state.adminData = payload;
    state.strings = strings || {};
    document.getElementById('admin-title').textContent = strings.admin_title || 'Admin';
    document.getElementById('admin-new').textContent = strings.admin_new || 'Neu';

    showApp();
    viewAdmin.classList.remove('hidden');
    viewAuth.classList.add('hidden');
    viewLocker.classList.add('hidden');
    renderAdminList();
}

function renderAdminList() {
    const list = document.getElementById('admin-locker-list');
    list.innerHTML = '';

    (state.adminData.lockers || []).forEach((entry) => {
        const btn = document.createElement('button');
        btn.className = `admin-locker-btn${state.selectedLocker?.locker.id === entry.locker.id ? ' active' : ''}`;
        btn.innerHTML = `<strong>${entry.locker.name}</strong><br><small>#${entry.locker.id}</small>`;
        btn.addEventListener('click', () => {
            state.selectedLocker = JSON.parse(JSON.stringify(entry));
            renderAdminList();
            renderAdminEditor();
        });
        list.appendChild(btn);
    });
}

function renderAdminEditor() {
    const editor = document.getElementById('admin-editor');

    if (!state.selectedLocker) {
        editor.innerHTML = '<div class="empty-state">Wähle ein Schließfach oder erstelle ein neues.</div>';
        return;
    }

    const locker = state.selectedLocker.locker;
    const items = state.selectedLocker.items || [];
    const coords = locker.coordinates || {};

    editor.innerHTML = `
        <div class="admin-toolbar">
            <button class="btn btn-primary" id="save-locker">Speichern</button>
            <button class="btn btn-ghost" id="dup-locker">Duplizieren</button>
            <button class="btn btn-ghost" id="set-pos">Position setzen</button>
            <button class="btn btn-ghost" id="tp-locker">Teleportieren</button>
            <button class="btn btn-ghost" id="show-logs">Logs</button>
            <button class="btn btn-ghost" id="delete-locker" style="color:#ef4444">Löschen</button>
        </div>
        <div class="admin-section">
            <h3>Grunddaten</h3>
            <div class="form-grid">
                <div class="field"><label>Name</label><input id="f-name" value="${locker.name || ''}"></div>
                <div class="field"><label>Zugangsmodus</label>
                    <select id="f-access">
                        ${(state.adminData.access_modes || []).map((m) => `<option value="${m}" ${locker.access_mode === m ? 'selected' : ''}>${m}</option>`).join('')}
                    </select>
                </div>
                <div class="field full"><label>Beschreibung</label><textarea id="f-desc">${locker.description || ''}</textarea></div>
                <div class="field"><label>PIN (leer = unverändert)</label><input id="f-pin" type="password" placeholder="****"></div>
                <div class="field"><label>Schlüssel-Item</label><input id="f-key" value="${locker.key_item || ''}"></div>
                <div class="field"><label>Mindest-Rang</label><input id="f-grade" type="number" value="${locker.minimum_grade || 0}"></div>
                <div class="field"><label>Target-Distanz</label><input id="f-distance" type="number" step="0.1" value="${locker.target_distance || 2}"></div>
                <div class="field"><label>Slots</label><input id="f-slots" type="number" value="${locker.slots || 50}"></div>
                <div class="field"><label>Max. Gewicht</label><input id="f-weight" type="number" value="${locker.max_weight || 100000}"></div>
                <div class="field"><label>X</label><input id="f-x" type="number" step="0.01" value="${coords.x || 0}"></div>
                <div class="field"><label>Y</label><input id="f-y" type="number" step="0.01" value="${coords.y || 0}"></div>
                <div class="field"><label>Z</label><input id="f-z" type="number" step="0.01" value="${coords.z || 0}"></div>
                <div class="field"><label>Heading</label><input id="f-h" type="number" step="0.1" value="${coords.h || 0}"></div>
                <div class="field"><label><input type="checkbox" id="f-enabled" ${locker.enabled ? 'checked' : ''}> Aktiv</label></div>
                <div class="field"><label><input type="checkbox" id="f-consume" ${locker.key_consume ? 'checked' : ''}> Schlüssel verbrauchen</label></div>
            </div>
        </div>
        <div class="admin-section">
            <h3>Items (${items.length})</h3>
            <div class="form-grid">
                <div class="field"><label>Item-Name</label><input id="new-item-name" placeholder="weapon_pistol"></div>
                <div class="field"><label>Menge</label><input id="new-item-amount" type="number" value="1"></div>
                <div class="field"><label>Max. Entnahme</label><input id="new-item-take" type="number" value="1"></div>
                <div class="field"><label>Min. Rang</label><input id="new-item-grade" type="number" value="0"></div>
            </div>
            <button class="btn btn-primary" id="add-item" style="margin-top:10px">Item hinzufügen</button>
            <div style="margin-top:12px" id="admin-items-list">
                ${items.map((item) => `
                    <div class="admin-item-row" data-item-id="${item.id}">
                        <span>${item.display_name || item.item_name} (${item.amount}${item.unlimited ? ', ∞' : ''})</span>
                        <button class="btn btn-ghost" data-edit-item="${item.id}">Bearbeiten</button>
                        <button class="btn btn-ghost" data-del-item="${item.id}" style="color:#ef4444">X</button>
                    </div>
                `).join('')}
            </div>
        </div>
        <div class="admin-section">
            <h3>Transaktionsverlauf</h3>
            <div class="log-list" id="log-list">Logs laden…</div>
        </div>
    `;

    document.getElementById('save-locker').addEventListener('click', saveLocker);
    document.getElementById('dup-locker').addEventListener('click', () => nuiFetch('adminDuplicateLocker', { lockerId: locker.id }));
    document.getElementById('set-pos').addEventListener('click', () => nuiFetch('adminGetPosition'));
    document.getElementById('tp-locker').addEventListener('click', () => nuiFetch('adminTeleport', { coords: locker.coordinates }));
    document.getElementById('show-logs').addEventListener('click', () => nuiFetch('adminGetLogs', { lockerId: locker.id }));
    document.getElementById('delete-locker').addEventListener('click', () => {
        if (confirm('Schließfach wirklich löschen?')) {
            nuiFetch('adminDeleteLocker', { lockerId: locker.id });
        }
    });
    document.getElementById('add-item').addEventListener('click', addAdminItem);

    editor.querySelectorAll('[data-del-item]').forEach((btn) => {
        btn.addEventListener('click', () => {
            nuiFetch('adminDeleteItem', { lockerId: locker.id, itemId: parseInt(btn.dataset.delItem, 10) });
        });
    });
}

function collectLockerForm() {
    const locker = state.selectedLocker.locker;
    const pin = document.getElementById('f-pin').value;

    return {
        id: locker.id,
        name: document.getElementById('f-name').value,
        description: document.getElementById('f-desc').value,
        access_mode: document.getElementById('f-access').value,
        pin: pin || undefined,
        keep_pin: !pin && locker.has_pin,
        key_item: document.getElementById('f-key').value,
        minimum_grade: parseInt(document.getElementById('f-grade').value, 10) || 0,
        target_distance: parseFloat(document.getElementById('f-distance').value) || 2,
        slots: parseInt(document.getElementById('f-slots').value, 10) || 50,
        max_weight: parseInt(document.getElementById('f-weight').value, 10) || 100000,
        enabled: document.getElementById('f-enabled').checked,
        key_consume: document.getElementById('f-consume').checked,
        coordinates: {
            x: parseFloat(document.getElementById('f-x').value) || 0,
            y: parseFloat(document.getElementById('f-y').value) || 0,
            z: parseFloat(document.getElementById('f-z').value) || 0,
            h: parseFloat(document.getElementById('f-h').value) || 0,
        },
        allowed_jobs: locker.allowed_jobs || {},
        allowed_identifiers: locker.allowed_identifiers || [],
        key_metadata: locker.key_metadata || {},
        key_job_restrict: locker.key_job_restrict || {},
    };
}

function saveLocker() {
    nuiFetch('adminSaveLocker', collectLockerForm());
    toast('Speichern…', 'success');
}

function addAdminItem() {
    const lockerId = state.selectedLocker.locker.id;
    const item = {
        item_name: document.getElementById('new-item-name').value,
        amount: parseInt(document.getElementById('new-item-amount').value, 10) || 1,
        maximum_take_amount: parseInt(document.getElementById('new-item-take').value, 10) || 1,
        minimum_grade: parseInt(document.getElementById('new-item-grade').value, 10) || 0,
        returnable: true,
        unlimited: false,
    };

    nuiFetch('adminSaveItem', { lockerId, item });
}

document.getElementById('pin-clear').addEventListener('click', () => {
    state.pin = '';
    renderPinDots();
});

document.getElementById('pin-submit').addEventListener('click', () => {
    if (!state.pin) return;
    nuiFetch('submitPin', { pin: state.pin, requestId: requestId() });
});

document.getElementById('use-key-btn').addEventListener('click', () => {
    nuiFetch('useKey', { requestId: requestId() });
});

document.querySelectorAll('[data-close]').forEach((btn) => {
    btn.addEventListener('click', () => nuiFetch('close'));
});

document.querySelector('[data-admin-close]').addEventListener('click', () => nuiFetch('adminClose'));

document.getElementById('confirm-cancel').addEventListener('click', () => {
    confirmOverlay.classList.add('hidden');
    state.pendingAction = null;
});

document.getElementById('confirm-ok').addEventListener('click', () => {
    confirmOverlay.classList.add('hidden');
    if (state.pendingAction) state.pendingAction();
    state.pendingAction = null;
});

document.getElementById('admin-new').addEventListener('click', () => {
    state.selectedLocker = {
        locker: {
            name: 'Neues Schließfach',
            description: '',
            access_mode: 'pin_or_key',
            coordinates: { x: 0, y: 0, z: 0, h: 0 },
            target_distance: 2,
            minimum_grade: 0,
            slots: 50,
            max_weight: 100000,
            enabled: true,
            allowed_jobs: {},
            allowed_identifiers: [],
        },
        items: [],
    };
    renderAdminList();
    renderAdminEditor();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (!confirmOverlay.classList.contains('hidden')) {
            confirmOverlay.classList.add('hidden');
            return;
        }

        if (!viewAdmin.classList.contains('hidden')) {
            nuiFetch('adminClose');
            return;
        }

        nuiFetch('close');
    }
});

window.addEventListener('message', (event) => {
    const { action, data, strings, success, message, extra } = event.data;

    switch (action) {
        case 'show':
            showApp();
            break;
        case 'hide':
            hideApp();
            break;
        case 'openAuth':
            openAuth(data, strings);
            buildPinPad();
            break;
        case 'authResult':
            if (success && extra && (extra.needsKey || extra.needsPin)) {
                showMessage(message || 'Weiterer Schritt erforderlich', 'success');
            } else if (success) {
                showMessage(message || 'OK', 'success');
            } else {
                showMessage(message || 'Fehler', 'error');
                state.pin = '';
                renderPinDots();
            }
            break;
        case 'openLocker':
            document.getElementById('locker-loading').classList.add('hidden');
            openLocker(data);
            break;
        case 'openAdmin':
            openAdmin(data, strings);
            break;
        case 'adminLogs':
            document.getElementById('log-list').innerHTML = (data || []).map((log) => `
                <div class="log-row">[${log.timestamp}] ${log.player_name} – ${log.action} ${log.item_name || ''} ${log.amount || ''}</div>
            `).join('') || 'Keine Logs.';
            break;
        case 'adminPosition':
            if (state.selectedLocker && data) {
                state.selectedLocker.locker.coordinates = data;
                renderAdminEditor();
                toast('Position übernommen', 'success');
            }
            break;
        default:
            break;
    }
});

buildPinPad();
