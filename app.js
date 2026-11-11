/**
  MIT HydroSensor Enterprise App Engine
  Main simulation and interactive control file.
  Flutter design layouts compatibility.
*/

// --- App State Configuration ---
const STATE = {
  activeTab: 'dashboard',
  theme: 'light',
  refreshInterval: 5000, // 5 seconds
  audioEnabled: true,
  pushEnabled: true,
    currentUser: {
      name: "Dr. Marcus Vance",
      role: "Director of Utilities & Operations",
      email: "admin@mit.edu",
      campus: "MIT ADT University (Primary)",
      lastLogin: "Today, 11:10 AM"
    },
    tanks: [
      {
        id: 0,
        name: "TANK 1",
        capacity: 25000, // Liters
        level: 75, // Percent
        status: "healthy",
        temp: 18.5, // Celsius
        depth: 4.5, // Meters
        rssi: -62, // dBm
        battery: 3.92, // Volts
        hwId: "ESP32-NODE-M01",
        lastUpdated: "11:10:05 AM",
        history: {
          "24h": [76, 75, 75, 74, 75, 76, 75, 74, 75, 75, 76, 75],
          "7d": [78, 76, 75, 74, 76, 75, 75],
          "30d": [80, 79, 78, 77, 78, 79, 78, 76, 75, 76, 77, 78, 76, 75, 76, 75, 74, 75, 76, 77, 78, 79, 77, 76, 75, 74, 75, 76, 75, 75],
          consumption: [320, 290, 310, 340, 280, 300, 310]
        }
      },
      {
        id: 1,
        name: "TANK 2",
        capacity: 10000,
        level: 92,
        status: "healthy",
        temp: 19.8,
        depth: 2.8,
        rssi: -58,
        battery: 3.88,
        hwId: "ESP32-NODE-C02",
        lastUpdated: "11:09:42 AM",
        history: {
          "24h": [89, 90, 91, 92, 92, 91, 90, 91, 92, 93, 93, 92],
          "7d": [90, 88, 89, 91, 90, 92, 92],
          "30d": [85, 86, 88, 89, 90, 91, 90, 89, 88, 89, 90, 91, 90, 89, 90, 91, 92, 93, 92, 91, 90, 89, 90, 91, 92, 93, 92, 91, 92, 92],
          consumption: [120, 140, 110, 130, 95, 105, 115]
        }
      },
      {
        id: 2,
        name: "TANK 3",
        capacity: 15000,
        level: 45,
        status: "warning",
        temp: 21.2,
        depth: 3.1,
        rssi: -74,
        battery: 3.76,
        hwId: "ESP32-NODE-D03",
        lastUpdated: "11:08:15 AM",
        history: {
          "24h": [62, 59, 56, 52, 49, 47, 46, 45, 45, 46, 47, 45],
          "7d": [65, 60, 55, 50, 48, 47, 45],
          "30d": [75, 72, 70, 68, 65, 62, 60, 58, 59, 61, 63, 62, 60, 58, 56, 55, 57, 59, 61, 60, 58, 56, 53, 51, 48, 46, 45, 47, 46, 45],
          consumption: [450, 480, 490, 510, 420, 440, 460]
        }
      },
      {
        id: 3,
        name: "TANK 4",
        capacity: 8000,
        level: 12,
        status: "critical",
        temp: 22.5,
        depth: 1.1,
        rssi: -68,
        battery: 3.82,
        hwId: "ESP32-NODE-U04",
        lastUpdated: "11:10:12 AM",
        history: {
          "24h": [28, 25, 22, 19, 17, 15, 14, 13, 12, 12, 11, 12],
          "7d": [38, 32, 28, 22, 18, 15, 12],
          "30d": [55, 52, 48, 44, 40, 37, 35, 32, 30, 28, 27, 29, 31, 30, 28, 25, 23, 20, 18, 19, 21, 20, 18, 16, 14, 13, 12, 14, 13, 12],
          consumption: [240, 260, 280, 300, 250, 270, 290]
        }
      },
      {
        id: 4,
        name: "TANK 5",
        capacity: 12000,
        level: 0,
        status: "offline",
        temp: 0.0,
        depth: 0.0,
        rssi: -99,
        battery: 0.00,
        hwId: "ESP32-NODE-F05",
        lastUpdated: "Yesterday, 4:15 PM",
        history: {
          "24h": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          "7d": [0, 0, 0, 0, 0, 0, 0],
          "30d": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          consumption: [0, 0, 0, 0, 0, 0, 0]
        }
      }
    ],
    notifications: [
      { id: 1, title: "TANK 4 Critical Level", desc: "TANK 4 fell below 15% threshold.", time: "11:10 AM", read: false },
      { id: 2, title: "TANK 5 Sensor Offline", desc: "Node ESP32-NODE-F05 missed 3 heartbeat packets.", time: "Yesterday, 4:15 PM", read: false },
      { id: 3, title: "TANK 1 Replenished", desc: "TANK 1 successfully completed daily recharge cycle.", time: "Today, 6:00 AM", read: true }
    ],
    alertsLog: [
      { id: 101, tankName: "TANK 4", type: "Critical Low Level", time: "11:10 AM", status: "active" },
      { id: 102, tankName: "TANK 3", type: "Warning Low Level", time: "11:08 AM", status: "warn" },
      { id: 103, tankName: "TANK 5", type: "Device Connection Timeout", time: "Yesterday, 4:15 PM", status: "offline" },
      { id: 104, tankName: "TANK 2", type: "High Level Threshold Met", time: "Yesterday, 2:30 PM", status: "resolved" }
    ],
  selectedReportTank: 0,
  selectedDetailTank: 0,
  detailTimeframe: '24h'
};

// --- Chart Instances Storage ---
const CHARTS = {
  dashboardAvail: null,
  dashboardConsumption: null,
  reportLevel: null,
  reportConsumption: null,
  reportDoughnut: null,
  detailLevel: null,
  detailConsumption: null
};

// --- Audio Alarm Engine (Web Audio API Synthesizer) ---
let audioCtx = null;
function playAlarmBeep(isCritical = true) {
  if (!STATE.audioEnabled) return;
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const osc1 = audioCtx.createOscillator();
    const osc2 = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();

    osc1.type = 'sawtooth';
    osc2.type = 'sine';

    if (isCritical) {
      osc1.frequency.setValueAtTime(880, audioCtx.currentTime); // A5
      osc2.frequency.setValueAtTime(440, audioCtx.currentTime); // A4
      osc1.frequency.exponentialRampToValueAtTime(660, audioCtx.currentTime + 0.3); // E5
    } else {
      osc1.frequency.setValueAtTime(554, audioCtx.currentTime); // C#5
      osc2.frequency.setValueAtTime(277, audioCtx.currentTime); // C#4
    }

    gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.45);

    osc1.connect(gainNode);
    osc2.connect(gainNode);
    gainNode.connect(audioCtx.destination);

    osc1.start();
    osc2.start();
    osc1.stop(audioCtx.currentTime + 0.5);
    osc2.stop(audioCtx.currentTime + 0.5);
  } catch (e) {
    console.warn("Audio Context failed to start (interaction required).", e);
  }
}

// --- App Initialization ---
window.addEventListener('DOMContentLoaded', () => {
  // Initialize Lucide Icons
  lucide.createIcons();
  
  // Set real-time clock in simulator status bar
  updateSimulatorClock();
  setInterval(updateSimulatorClock, 1000);

  // Splash Screen Sequence
  setTimeout(() => {
    const splash = document.getElementById('splash-screen');
    if (splash) {
      splash.style.transition = 'opacity 0.5s ease';
      splash.style.opacity = 0;
    }
    
    setTimeout(() => {
      if (splash) splash.style.display = 'none';
      const login = document.getElementById('login-screen');
      if (login) {
        login.style.display = 'flex';
        // Force reflow
        login.offsetHeight;
        login.classList.add('active');
      }
    }, 500);
  }, 2200);

  // Password View/Hide toggle listener
  const togglePasswordBtn = document.getElementById('toggle-password-btn');
  if (togglePasswordBtn) {
    togglePasswordBtn.addEventListener('click', () => {
      const passInput = document.getElementById('login-pass');
      const icon = togglePasswordBtn.querySelector('i');
      if (passInput.type === 'password') {
        passInput.type = 'text';
        icon.setAttribute('data-lucide', 'eye-off');
      } else {
        passInput.type = 'password';
        icon.setAttribute('data-lucide', 'eye');
      }
      lucide.createIcons();
    });
  }

  // Layout presentation toggle
  document.getElementById('layout-toggle-btn').addEventListener('click', () => {
    const host = document.getElementById('app-host');
    const isFull = host.classList.toggle('fullscreen-mode');
    document.getElementById('layout-toggle-btn').innerHTML = isFull 
      ? `<i data-lucide="minimize-2"></i> Device Frame View`
      : `<i data-lucide="maximize-2"></i> Toggle Full Screen`;
    safeCreateIcons();
    // Re-render active charts to fit new container dimensions
    setTimeout(resizeAllActiveCharts, 300);
  });

  // Map clicks listener
  document.querySelectorAll('.map-node').forEach(node => {
    node.addEventListener('click', (e) => {
      const idx = parseInt(e.target.getAttribute('data-tank-index'));
      openTankDetails(idx);
    });
  });
});

function updateSimulatorClock() {
  const now = new Date();
  let hours = now.getHours();
  let minutes = now.getMinutes();
  hours = hours < 10 ? '0' + hours : hours;
  minutes = minutes < 10 ? '0' + minutes : minutes;
  const timeStr = `${hours}:${minutes}`;
  
  const simTime = document.getElementById('simulator-time');
  if (simTime) simTime.textContent = timeStr;
}

// --- Authentication Handler ---
function handleLogin() {
  const emailInput = document.getElementById('login-email').value;
  const loginScreen = document.getElementById('login-screen');
  
  STATE.currentUser.email = emailInput;
  document.getElementById('prof-user-name').textContent = emailInput === 'admin@mit.edu' ? 'Dr. Marcus Vance' : 'MIT Operator';
  
  // Staggered premium slide-out
  loginScreen.classList.remove('active');
  loginScreen.style.opacity = 0;
  loginScreen.style.transform = 'translateY(-20px)';
  
  setTimeout(() => {
    loginScreen.style.display = 'none';
    loginScreen.style.transform = ''; // reset transform
    initDashboardData();
    initSimulation();
    triggerToast("Identity Verified. AWS Telemetry Stream Active.");
  }, 550);
}

function logoutUser() {
  // Stop simulation
  if (STATE.simIntervalId) {
    clearInterval(STATE.simIntervalId);
  }
  
  // Slide back overlays
  closeTankDetails();
  closeProfile();
  document.getElementById('notifications-panel').style.display = 'none';
  
  // Go back to login screen with entry animation
  const loginScreen = document.getElementById('login-screen');
  loginScreen.style.display = 'flex';
  loginScreen.style.opacity = 0;
  loginScreen.style.transform = 'translateY(40px)';
  // Force reflow
  loginScreen.offsetHeight;
  loginScreen.style.opacity = 1;
  loginScreen.style.transform = 'translateY(0)';
  loginScreen.classList.add('active');
  
  // Reset navigation state to dashboard
  STATE.activeTab = 'dashboard';
  document.querySelectorAll('.bottom-nav-item').forEach(item => item.classList.remove('active'));
  document.querySelector('.bottom-nav-item:first-child').classList.add('active');
  
  document.querySelectorAll('.screen').forEach(scr => scr.classList.remove('active'));
  document.getElementById('screen-dashboard').classList.add('active');
  document.getElementById('global-header').style.display = 'flex';
}

// --- Navigation Tabs Switcher ---
function switchTab(event, tabName) {
  if (event) event.preventDefault();
  
  STATE.activeTab = tabName;
  
  // Update nav item classes
  document.querySelectorAll('.bottom-nav-item').forEach(item => {
    item.classList.remove('active');
  });
  
  let targetNav = event ? event.currentTarget : null;
  if (!targetNav) {
    // Fallback search
    const items = document.querySelectorAll('.bottom-nav-item');
    if (tabName === 'dashboard') targetNav = items[0];
    if (tabName === 'reports') targetNav = items[1];
    if (tabName === 'alerts') targetNav = items[2];
    if (tabName === 'settings') targetNav = items[3];
  }
  if (targetNav) targetNav.classList.add('active');

  // Hide/Show Screens
  document.querySelectorAll('.screen').forEach(screen => {
    screen.classList.remove('active');
  });
  
  const activeScreen = document.getElementById(`screen-${tabName}`);
  activeScreen.classList.add('active');

  // Close popup widgets
  document.getElementById('notifications-panel').style.display = 'none';

  // Screen-specific hooks
  if (tabName === 'dashboard') {
    document.getElementById('global-header').style.display = 'flex';
    initDashboardCharts();
  } else if (tabName === 'reports') {
    document.getElementById('global-header').style.display = 'flex';
    initReportsCharts();
    updateReportData();
  } else if (tabName === 'alerts') {
    document.getElementById('global-header').style.display = 'flex';
    renderAlertsScreenList();
  } else if (tabName === 'settings') {
    // Settings has its own localized header, hide global
    document.getElementById('global-header').style.display = 'none';
  }
}

// --- Toast Notification ---
function triggerToast(message) {
  const toast = document.getElementById('global-toast');
  toast.textContent = message;
  toast.classList.add('show');
  
  setTimeout(() => {
    toast.classList.remove('show');
  }, 2500);
}

// --- Live Telemetry AWS Simulator Feed ---
function appendTelemetryLog(tank) {
  const consoleEl = document.getElementById('iot-console');
  if (!consoleEl) return;

  const now = new Date();
  let h = now.getHours();
  let m = now.getMinutes();
  let s = now.getSeconds();
  h = h < 10 ? '0' + h : h;
  m = m < 10 ? '0' + m : m;
  s = s < 10 ? '0' + s : s;
  const timeStr = `${h}:${m}:${s}`;

  const payload = {
    device_id: tank.hwId,
    timestamp: timeStr,
    water_level_pct: tank.level,
    volume_liters: Math.round((tank.level / 100) * tank.capacity),
    voltage: tank.battery,
    rssi_dbm: tank.rssi,
    water_temp_c: tank.temp
  };

  const line = document.createElement('div');
  line.className = 'console-line';
  line.innerHTML = `<span class="timestamp">[${timeStr}]</span><span class="topic">mit/utility/tanks/${tank.id}</span>${JSON.stringify(payload)}`;
  
  consoleEl.appendChild(line);
  consoleEl.scrollTop = consoleEl.scrollHeight;

  // Limit lines to 30
  while (consoleEl.childElementCount > 30) {
    consoleEl.removeChild(consoleEl.firstChild);
  }
}

// --- Simulation Engine ---
function initSimulation() {
  // Clear any existing simulation interval
  if (STATE.simIntervalId) {
    clearInterval(STATE.simIntervalId);
  }

  // Trigger initial packet log
  appendTelemetryLog(STATE.tanks[0]);

  // Main simulation tick loop
  STATE.simIntervalId = setInterval(() => {
    // 1. Pick a random online tank to change
    const onlineTanks = STATE.tanks.filter(t => t.status !== 'offline');
    if (onlineTanks.length === 0) return;

    const targetTank = onlineTanks[Math.floor(Math.random() * onlineTanks.length)];
    
    // Simulate water depletion or refill cycles
    // Main tank drains slowly, Dorms drains quickly during simulation
    let delta = 0;
    if (targetTank.id === 0) {
      delta = Math.random() > 0.6 ? 1 : -1; // Steady
    } else if (targetTank.id === 2) {
      delta = Math.random() > 0.45 ? -2 : 1; // High consumption
    } else if (targetTank.id === 3) {
      // Tank 4 utility cycles rapidly
      delta = Math.random() > 0.5 ? -3 : 3;
    } else {
      delta = Math.random() > 0.5 ? 1 : -1;
    }

    const previousStatus = targetTank.status;
    targetTank.level = Math.max(5, Math.min(100, targetTank.level + delta)); // min 5%
    
    // Update variables
    targetTank.depth = parseFloat(((targetTank.level / 100) * (targetTank.capacity / 2500)).toFixed(2));
    targetTank.temp = parseFloat((20.0 + (Math.random() * 4 - 2)).toFixed(1));
    targetTank.battery = parseFloat((3.7 + (Math.random() * 0.25)).toFixed(2));
    targetTank.rssi = -60 - Math.floor(Math.random() * 15);
    
    const now = new Date();
    let hrs = now.getHours();
    let mins = now.getMinutes();
    hrs = hrs < 10 ? '0' + hrs : hrs;
    mins = mins < 10 ? '0' + mins : mins;
    targetTank.lastUpdated = `${hrs}:${mins} AM`;

    // Recalculate Alert state
    if (targetTank.level < 15) {
      targetTank.status = 'critical';
    } else if (targetTank.level < 50) {
      targetTank.status = 'warning';
    } else {
      targetTank.status = 'healthy';
    }

    // Trigger audible alarm if transitioned to critical/warning status
    if (targetTank.status !== previousStatus) {
      handleStatusChange(targetTank, previousStatus);
    }

    // Append to live feed
    appendTelemetryLog(targetTank);

    // Refresh active screen components
    renderDynamicUI();

  }, STATE.refreshInterval);
}

function changeRefreshInterval() {
  const select = document.getElementById('refresh-interval-select');
  STATE.refreshInterval = parseInt(select.value);
  initSimulation();
  triggerToast(`AWS polling interval updated to ${STATE.refreshInterval / 1000}s`);
}

function handleStatusChange(tank, oldStatus) {
  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  if (tank.status === 'critical') {
    playAlarmBeep(true);
    
    // Add Alarm to logs
    const newAlert = {
      id: Date.now(),
      tankName: tank.name,
      type: "Critical Low Level",
      time: timeStr,
      status: "active"
    };
    STATE.alertsLog.unshift(newAlert);
    
    // Notification
    STATE.notifications.unshift({
      id: Date.now(),
      title: `${tank.name} Critical`,
      desc: `Liquid volume critical at ${tank.level}%. Refill sequence recommended.`,
      time: timeStr,
      read: false
    });
    
    if (STATE.pushEnabled) {
      triggerToast(`🚨 ALARM: ${tank.name} level is critical (${tank.level}%)!`);
    }
  } else if (tank.status === 'warning' && oldStatus === 'healthy') {
    playAlarmBeep(false);
    
    const newAlert = {
      id: Date.now(),
      tankName: tank.name,
      type: "Warning Low Level",
      time: timeStr,
      status: "warn"
    };
    STATE.alertsLog.unshift(newAlert);

    STATE.notifications.unshift({
      id: Date.now(),
      title: `${tank.name} Warning`,
      desc: `Water volume dropped below 50% threshold.`,
      time: timeStr,
      read: false
    });
  } else if (tank.status === 'healthy' && oldStatus !== 'healthy') {
    // Recovered
    const newAlert = {
      id: Date.now(),
      tankName: tank.name,
      type: "Level Threshold Restored",
      time: timeStr,
      status: "resolved"
    };
    STATE.alertsLog.unshift(newAlert);
    
    STATE.notifications.unshift({
      id: Date.now(),
      title: `${tank.name} Recovered`,
      desc: `Liquid levels restored above safety threshold.`,
      time: timeStr,
      read: false
    });
    triggerToast(`ℹ️ INFO: ${tank.name} level returned to normal.`);
  }

  // Update badge count
  const unreadCount = STATE.notifications.filter(n => !n.read).length;
  document.getElementById('notif-badge').textContent = unreadCount;
  document.getElementById('notif-badge').style.display = unreadCount > 0 ? 'block' : 'none';
}

// --- Dynamic UI Renderings ---
function initDashboardData() {
  switchTab(null, 'dashboard');
  renderDynamicUI();
}

function renderDynamicUI() {
  const onlineCount = STATE.tanks.filter(t => t.status !== 'offline').length;
  const offlineCount = STATE.tanks.length - onlineCount;
  const activeAlerts = STATE.tanks.filter(t => t.status === 'critical' || t.status === 'warning').length;

  // Overview KPIs updates
  const kpiOnline = document.getElementById('kpi-online-val');
  const kpiOffline = document.getElementById('kpi-offline-val');
  const kpiAlerts = document.getElementById('kpi-alerts-val');

  if (kpiOnline) kpiOnline.textContent = onlineCount;
  if (kpiOffline) kpiOffline.textContent = offlineCount;
  if (kpiAlerts) kpiAlerts.textContent = activeAlerts;

  // Active alarms command center in dashboard
  const activeAlertsContainer = document.getElementById('dashboard-active-alerts');
  if (activeAlertsContainer) {
    const list = STATE.alertsLog.filter(a => a.status === 'active' || a.status === 'warn');
    if (list.length === 0) {
      document.getElementById('dashboard-alert-banner').style.display = 'none';
    } else {
      document.getElementById('dashboard-alert-banner').style.display = 'block';
      activeAlertsContainer.innerHTML = list.map(a => `
        <div class="alert-banner-item ${a.status === 'warn' ? 'warning-alert' : ''}">
          <span>${a.tankName} - ${a.type.toUpperCase()}</span>
          <span class="alert-badge ${a.status === 'warn' ? 'badge-warn' : 'badge-crit'}">${a.status === 'warn' ? 'WARNING' : 'CRITICAL'}</span>
        </div>
      `).join('');
    }
  }

  // Tank cards carousel render
  const carousel = document.getElementById('tank-list-carousel');
  if (carousel) {
    carousel.innerHTML = STATE.tanks.map((tank, idx) => {
      const vol = Math.round((tank.level / 100) * tank.capacity);
      return `
        <div class="tank-card" data-status="${tank.status}" onclick="openTankDetails(${idx})">
          <div class="tank-card-header">
            <div style="display: flex; flex-direction: column; align-items: flex-start; gap: 2px;">
              <span class="tank-card-name">${tank.name}</span>
              <span class="tank-status-text ${tank.status}">${tank.status.toUpperCase()}</span>
            </div>
            <div class="status-dot ${tank.status}"></div>
          </div>
          <div class="tank-visual">
            <div class="tank-liquid" style="height: ${tank.level}%;"></div>
            <div class="tank-percentage-float">${tank.level}%</div>
          </div>
          <div class="tank-card-vol">${vol.toLocaleString()} L</div>
          <div class="tank-card-label">Volume Level</div>
          <div class="tank-card-time">Refreshed ${tank.lastUpdated}</div>
        </div>
      `;
    }).join('');
  }

  // Campus map status nodes glow sync
  STATE.tanks.forEach((tank, idx) => {
    const node = document.querySelector(`.map-node[data-tank-index="${idx}"]`);
    if (node) {
      let color = 'var(--offline)';
      if (tank.status === 'healthy') color = 'var(--success)';
      if (tank.status === 'warning') color = 'var(--warning)';
      if (tank.status === 'critical') color = 'var(--critical)';
      node.setAttribute('fill', color);
    }
  });

  // Dynamic overlays update if currently opened
  if (document.getElementById('tank-details-overlay').style.display === 'flex') {
    const curIdx = STATE.selectedDetailTank;
    const t = STATE.tanks[curIdx];
    
    // Update live metrics on overlay
    document.getElementById('overlay-tank-fill').style.height = `${t.level}%`;
    document.getElementById('overlay-tank-pct').textContent = `${t.level}%`;
    document.getElementById('overlay-vol').textContent = `${Math.round((t.level / 100) * t.capacity).toLocaleString()} L`;
    document.getElementById('overlay-depth').textContent = `${t.depth} m`;
    document.getElementById('overlay-dev-status').textContent = t.status.toUpperCase();
    document.getElementById('overlay-dev-status').style.color = t.status === 'offline' ? 'var(--offline)' : (t.status === 'healthy' ? 'var(--success)' : 'var(--critical)');
    document.getElementById('overlay-dev-rssi').textContent = `${t.rssi} dBm`;
    document.getElementById('overlay-dev-battery').textContent = t.status === 'offline' ? '0.00V' : `${t.battery}V`;
    document.getElementById('overlay-dev-time').textContent = t.lastUpdated;
  }

  // Live charts updates
  updateChartsDynamic();
}

// --- Chart rendering utilities ---
function resizeAllActiveCharts() {
  Object.values(CHARTS).forEach(chart => {
    if (chart) chart.resize();
  });
}

function getChartColors() {
  const isDark = document.body.classList.contains('dark-theme');
  return {
    text: isDark ? '#94A3B8' : '#64748B',
    grid: isDark ? '#334155' : '#E2E8F0',
    primary: '#1565C0',
    secondary: '#42A5F5'
  };
}

function initDashboardCharts() {
  const colors = getChartColors();

  // 1. Average Availability (Over 24h)
  const ctxAvail = document.getElementById('availChart');
  if (ctxAvail) {
    if (CHARTS.dashboardAvail) CHARTS.dashboardAvail.destroy();
    
    // Compute mean availability curve from history of online tanks
    const hourlyAvail = [74, 73, 73, 72, 73, 74, 74, 75, 73, 74, 75, 74];
    
    CHARTS.dashboardAvail = new Chart(ctxAvail, {
      type: 'line',
      data: {
        labels: ['12 AM', '2 AM', '4 AM', '6 AM', '8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM', '8 PM', '10 PM'],
        datasets: [{
          label: 'Availability %',
          data: hourlyAvail,
          borderColor: colors.secondary,
          backgroundColor: 'rgba(66, 165, 245, 0.1)',
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { min: 0, max: 100, grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }

  // 2. Daily consumption Bar Chart
  const ctxCons = document.getElementById('consumptionChart');
  if (ctxCons) {
    if (CHARTS.dashboardConsumption) CHARTS.dashboardConsumption.destroy();
    CHARTS.dashboardConsumption = new Chart(ctxCons, {
      type: 'bar',
      data: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        datasets: [{
          label: 'Campus Consumption (L)',
          data: [1200, 1450, 1300, 1650, 1100, 950, 1050],
          backgroundColor: colors.primary,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }
}

function initReportsCharts() {
  const colors = getChartColors();
  const tank = STATE.tanks[STATE.selectedReportTank];
  const timeframe = document.getElementById('report-timeframe').value;

  // 1. Water Level Trend Area Chart
  const ctxRepLevel = document.getElementById('reportLevelChart');
  if (ctxRepLevel) {
    if (CHARTS.reportLevel) CHARTS.reportLevel.destroy();
    
    const dataPoints = tank.history[timeframe] || tank.history["24h"];
    const labels = dataPoints.map((_, i) => timeframe === '24h' ? `${i*2}h` : `D${i+1}`);

    CHARTS.reportLevel = new Chart(ctxRepLevel, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Level %',
          data: dataPoints,
          borderColor: colors.primary,
          backgroundColor: 'rgba(21, 101, 192, 0.1)',
          fill: true,
          tension: 0.25,
          borderWidth: 2,
          pointRadius: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { min: 0, max: 100, grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }

  // 2. Hourly Consumption Bar Chart
  const ctxRepCons = document.getElementById('reportConsumptionChart');
  if (ctxRepCons) {
    if (CHARTS.reportConsumption) CHARTS.reportConsumption.destroy();
    CHARTS.reportConsumption = new Chart(ctxRepCons, {
      type: 'bar',
      data: {
        labels: ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
        datasets: [{
          label: 'Consumption (L)',
          data: [45, 20, 110, 140, 95, 125],
          backgroundColor: colors.secondary,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }

  // 3. Capacity utilization Donut Chart
  const ctxRepDonut = document.getElementById('reportDoughnutChart');
  if (ctxRepDonut) {
    if (CHARTS.reportDoughnut) CHARTS.reportDoughnut.destroy();
    
    const filledVol = Math.round((tank.level / 100) * tank.capacity);
    const emptyVol = tank.capacity - filledVol;

    CHARTS.reportDoughnut = new Chart(ctxRepDonut, {
      type: 'doughnut',
      data: {
        labels: ['Filled Volume', 'Available Space'],
        datasets: [{
          data: [filledVol, emptyVol],
          backgroundColor: [colors.primary, colors.grid],
          borderWidth: 1,
          borderColor: colors.grid
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: colors.text, font: { size: 9, family: 'Inter' } }
          }
        },
        cutout: '65%'
      }
    });
  }
}

function updateReportData() {
  const selectTank = document.getElementById('report-tank-select');
  if (!selectTank) return;
  
  STATE.selectedReportTank = parseInt(selectTank.value);
  const tank = STATE.tanks[STATE.selectedReportTank];
  
  // Calculate average, min, max levels
  const timeframe = document.getElementById('report-timeframe').value;
  const historyPoints = tank.history[timeframe] || tank.history["24h"];
  
  const sum = historyPoints.reduce((a, b) => a + b, 0);
  const avg = historyPoints.length > 0 ? (sum / historyPoints.length).toFixed(1) : 0.0;
  const max = historyPoints.length > 0 ? Math.max(...historyPoints) : 0;
  const min = historyPoints.length > 0 ? Math.min(...historyPoints) : 0;
  const totalUsage = tank.history.consumption.reduce((a,b) => a+b, 0);

  // Update DOM
  document.getElementById('report-avg-level').textContent = `${avg}%`;
  document.getElementById('report-max-level').textContent = `${max}%`;
  document.getElementById('report-min-level').textContent = `${min}%`;
  document.getElementById('report-total-usage').textContent = `${totalUsage.toLocaleString()} L`;

  document.getElementById('rep-hw-id').textContent = tank.hwId;
  document.getElementById('rep-battery').textContent = tank.status === 'offline' ? '0.00V' : `${tank.battery}V`;
  document.getElementById('rep-rssi').textContent = tank.status === 'offline' ? 'Disconnected' : `${tank.rssi} dBm`;

  // Draw Charts
  initReportsCharts();
}

function updateChartsDynamic() {
  // If Dashboard view, push new availability data
  if (STATE.activeTab === 'dashboard' && CHARTS.dashboardAvail) {
    // Add real-time fluctuation to graph
    const data = CHARTS.dashboardAvail.data.datasets[0].data;
    const onlineTanks = STATE.tanks.filter(t => t.status !== 'offline');
    const totalLevelSum = onlineTanks.reduce((sum, t) => sum + t.level, 0);
    const avgLevel = Math.round(totalLevelSum / (onlineTanks.length || 1));

    // Shift window
    data.pop();
    data.push(avgLevel);
    CHARTS.dashboardAvail.update();
  }

  // If reports open, sync level charts
  if (STATE.activeTab === 'reports' && CHARTS.reportLevel) {
    const tank = STATE.tanks[STATE.selectedReportTank];
    const timeframe = document.getElementById('report-timeframe').value;
    const dataPoints = tank.history[timeframe] || tank.history["24h"];
    
    // Update live value in charts data
    if (dataPoints.length > 0) {
      dataPoints[dataPoints.length - 1] = tank.level;
    }
    CHARTS.reportLevel.update();

    if (CHARTS.reportDoughnut) {
      const filled = Math.round((tank.level / 100) * tank.capacity);
      const empty = tank.capacity - filled;
      CHARTS.reportDoughnut.data.datasets[0].data = [filled, empty];
      CHARTS.reportDoughnut.update();
    }
  }

  // Overlay screen chart update
  if (document.getElementById('tank-details-overlay').style.display === 'flex' && CHARTS.detailLevel) {
    const tank = STATE.tanks[STATE.selectedDetailTank];
    const data = CHARTS.detailLevel.data.datasets[0].data;
    if (data.length > 0) {
      data[data.length - 1] = tank.level;
    }
    CHARTS.detailLevel.update();
  }
}

// --- Tank Details Overlay Controller ---
function openTankDetails(tankIndex) {
  STATE.selectedDetailTank = tankIndex;
  const tank = STATE.tanks[tankIndex];

  // Set titles
  document.getElementById('overlay-tank-name').textContent = tank.name;
  document.getElementById('overlay-vol').textContent = `${Math.round((tank.level / 100) * tank.capacity).toLocaleString()} L`;
  document.getElementById('overlay-capacity').textContent = `${tank.capacity.toLocaleString()} L`;
  document.getElementById('overlay-depth').textContent = `${tank.depth} m`;
  document.getElementById('overlay-tank-fill').style.height = `${tank.level}%`;
  document.getElementById('overlay-tank-pct').textContent = `${tank.level}%`;

  // Set HW diagnostics
  document.getElementById('overlay-dev-status').textContent = tank.status.toUpperCase();
  document.getElementById('overlay-dev-status').style.color = tank.status === 'offline' ? 'var(--offline)' : (tank.status === 'healthy' ? 'var(--success)' : 'var(--critical)');
  document.getElementById('overlay-dev-rssi').textContent = tank.status === 'offline' ? 'Disconnected' : `${tank.rssi} dBm`;
  document.getElementById('overlay-dev-battery').textContent = tank.status === 'offline' ? '0.00V' : `${tank.battery}V (Optimal)`;
  document.getElementById('overlay-dev-topic').textContent = `mit/adt/node_${tank.id}`;
  document.getElementById('overlay-dev-fw').textContent = tank.id === 4 ? 'Unknown' : 'v1.3.6-stable';
  document.getElementById('overlay-dev-time').textContent = tank.lastUpdated;

  // Open sliding container
  const overlay = document.getElementById('tank-details-overlay');
  overlay.style.display = 'flex';
  overlay.offsetHeight; // Force reflow
  overlay.classList.add('active');

  // Render detail overlay charts
  initDetailOverlayCharts(tank);
}

function closeTankDetails() {
  const overlay = document.getElementById('tank-details-overlay');
  overlay.classList.add('exit-active');
  overlay.classList.remove('active');
  setTimeout(() => {
    overlay.style.display = 'none';
    overlay.classList.remove('exit-active');
  }, 350);
}

function initDetailOverlayCharts(tank) {
  const colors = getChartColors();
  const tf = STATE.detailTimeframe;

  // Level Trend
  const ctxDetailLevel = document.getElementById('detailLevelChart');
  if (ctxDetailLevel) {
    if (CHARTS.detailLevel) CHARTS.detailLevel.destroy();
    
    const dataPoints = tank.history[tf] || tank.history["24h"];
    const labels = dataPoints.map((_, i) => tf === '24h' ? `${i*2}h` : `D${i+1}`);

    CHARTS.detailLevel = new Chart(ctxDetailLevel, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Water level %',
          data: dataPoints,
          borderColor: colors.primary,
          backgroundColor: 'rgba(21, 101, 192, 0.1)',
          fill: true,
          tension: 0.25,
          borderWidth: 2,
          pointRadius: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { min: 0, max: 100, grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }

  // Consumption rate
  const ctxDetailCons = document.getElementById('detailConsumptionChart');
  if (ctxDetailCons) {
    if (CHARTS.detailConsumption) CHARTS.detailConsumption.destroy();
    CHARTS.detailConsumption = new Chart(ctxDetailCons, {
      type: 'bar',
      data: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        datasets: [{
          label: 'Liters Consumed',
          data: tank.history.consumption,
          backgroundColor: colors.secondary,
          borderRadius: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false }, ticks: { color: colors.text, font: { size: 9 } } },
          y: { grid: { color: colors.grid }, ticks: { color: colors.text, font: { size: 9 } } }
        }
      }
    });
  }
}

function changeDetailTimeframe(element, tf) {
  const chips = element.parentNode.querySelectorAll('.chip');
  chips.forEach(c => c.classList.remove('active'));
  element.classList.add('active');

  STATE.detailTimeframe = tf;
  const tank = STATE.tanks[STATE.selectedDetailTank];
  initDetailOverlayCharts(tank);
}

// --- Notifications Center Drawer ---
function toggleNotifications() {
  const panel = document.getElementById('notifications-panel');
  if (panel.style.display === 'flex') {
    panel.style.display = 'none';
  } else {
    panel.style.display = 'flex';
    renderNotificationsList();
  }
}

function renderNotificationsList() {
  const list = document.getElementById('notifications-list');
  if (!list) return;

  if (STATE.notifications.length === 0) {
    list.innerHTML = `<div style="text-align:center; padding: 24px 0; color:var(--text-muted); font-size:0.8rem;">No notifications.</div>`;
  } else {
    list.innerHTML = STATE.notifications.map(n => `
      <div class="notification-item ${n.read ? 'read' : ''}" onclick="markNotificationRead(${n.id})">
        <div class="notification-item-dot"></div>
        <div class="notification-item-content">
          <h5>${n.title}</h5>
          <p>${n.desc}</p>
          <span style="font-size:0.6rem; color:var(--text-muted); display:block; margin-top:2px;">${n.time}</span>
        </div>
      </div>
    `).join('');
  }

  // Update badge count
  const unreadCount = STATE.notifications.filter(n => !n.read).length;
  document.getElementById('notif-badge').textContent = unreadCount;
  document.getElementById('notif-badge').style.display = unreadCount > 0 ? 'block' : 'none';
}

function markNotificationRead(id) {
  const notif = STATE.notifications.find(n => n.id === id);
  if (notif) {
    notif.read = true;
    renderNotificationsList();
  }
}

function clearAllNotifications() {
  STATE.notifications = [];
  renderNotificationsList();
  triggerToast("Notifications feed cleared.");
}

// --- Profile Sheet Overlay ---
function openProfile() {
  const overlay = document.getElementById('profile-overlay');
  overlay.style.display = 'flex';
  overlay.offsetHeight; // Force reflow
  overlay.classList.add('active');
}

function closeProfile() {
  const overlay = document.getElementById('profile-overlay');
  overlay.classList.add('exit-active');
  overlay.classList.remove('active');
  setTimeout(() => {
    overlay.style.display = 'none';
    overlay.classList.remove('exit-active');
  }, 350);
}

// --- Alerts Screen Logging ---
let activeAlertFilter = 'all';

function renderAlertsScreenList() {
  const activeContainer = document.getElementById('active-alert-list');
  const historicalContainer = document.getElementById('historical-alert-list');

  // Compute filtering
  let filteredLogs = STATE.alertsLog;
  if (activeAlertFilter === 'critical') {
    filteredLogs = STATE.alertsLog.filter(l => l.status === 'active');
  } else if (activeAlertFilter === 'warning') {
    filteredLogs = STATE.alertsLog.filter(l => l.status === 'warn');
  } else if (activeAlertFilter === 'offline') {
    filteredLogs = STATE.alertsLog.filter(l => l.status === 'offline');
  }

  // Filter out resolved vs active
  const activeAlarmsList = filteredLogs.filter(a => a.status === 'active' || a.status === 'warn' || a.status === 'offline');
  const historicalList = filteredLogs.filter(a => a.status === 'resolved');

  document.getElementById('alert-list-header').textContent = `Active Alarms (${activeAlarmsList.length})`;

  // Render active alerts
  if (activeAlarmsList.length === 0) {
    activeContainer.innerHTML = `<div style="text-align:center; padding:16px 0; color:var(--text-muted); font-size:0.8rem;">No active alarm alerts.</div>`;
  } else {
    activeContainer.innerHTML = activeAlarmsList.map(a => `
      <div class="alert-card-item">
        <div class="alert-card-left">
          <div class="alert-indicator ${a.status === 'active' ? 'crit' : (a.status === 'warn' ? 'warn' : 'off')}"></div>
          <div class="alert-card-details">
            <h4>${a.tankName}</h4>
            <p>${a.type}</p>
            <span>Time triggered: ${a.time}</span>
          </div>
        </div>
        <span class="alert-status-badge ${a.status === 'active' ? 'active' : (a.status === 'warn' ? 'warn' : 'offline')}">
          ${a.status === 'active' ? 'CRITICAL' : (a.status === 'warn' ? 'WARNING' : 'OFFLINE')}
        </span>
      </div>
    `).join('');
  }

  // Render historic resolved logbook
  if (historicalList.length === 0) {
    historicalContainer.innerHTML = `<div style="text-align:center; padding:16px 0; color:var(--text-muted); font-size:0.8rem;">No historical events recorded.</div>`;
  } else {
    historicalContainer.innerHTML = historicalList.map(a => `
      <div class="alert-card-item" style="opacity: 0.85;">
        <div class="alert-card-left">
          <div class="alert-indicator" style="background-color: var(--success);"></div>
          <div class="alert-card-details">
            <h4>${a.tankName}</h4>
            <p>${a.type}</p>
            <span>Resolved: ${a.time}</span>
          </div>
        </div>
        <span class="alert-status-badge resolved">RESOLVED</span>
      </div>
    `).join('');
  }
}

function setAlertFilter(chip, type) {
  const chips = chip.parentNode.querySelectorAll('.chip');
  chips.forEach(c => c.classList.remove('active'));
  chip.classList.add('active');

  activeAlertFilter = type;
  renderAlertsScreenList();
}

function filterAlerts() {
  const searchVal = document.getElementById('alert-search').value.toLowerCase();
  
  const cards = document.querySelectorAll('#active-alert-list .alert-card-item, #historical-alert-list .alert-card-item');
  
  cards.forEach(card => {
    const text = card.textContent.toLowerCase();
    if (text.includes(searchVal)) {
      card.style.display = 'flex';
    } else {
      card.style.display = 'none';
    }
  });
}

// --- Global Settings and Toggles ---
function toggleDarkTheme() {
  const body = document.body;
  const isDark = body.classList.toggle('dark-theme');
  STATE.theme = isDark ? 'dark' : 'light';
  
  // Sync inputs
  document.getElementById('theme-switch').checked = isDark;
  
  // Rebuild active charts with proper text/grid color systems
  if (STATE.activeTab === 'dashboard') {
    initDashboardCharts();
  } else if (STATE.activeTab === 'reports') {
    initReportsCharts();
  }
  
  if (document.getElementById('tank-details-overlay').style.display === 'flex') {
    initDetailOverlayCharts(STATE.tanks[STATE.selectedDetailTank]);
  }
  
  triggerToast(`SCADA mode set to ${isDark ? 'DARK' : 'LIGHT'}`);
}

function clearLocalLogs() {
  STATE.alertsLog = STATE.alertsLog.filter(a => a.status !== 'resolved');
  if (STATE.activeTab === 'alerts') {
    renderAlertsScreenList();
  }
  triggerToast("Historical database sync cleared.");
}

// --- Mock Document Exports ---
function exportData(format) {
  triggerToast(`Exporting data package to ${format}...`);
  setTimeout(() => {
    // Generate simple simulated download trigger
    const tank = STATE.tanks[STATE.selectedReportTank];
    const dataStr = `MIT Utility Dashboard Report\nTank: ${tank.name}\nGenerated: ${new Date().toLocaleString()}\nCapacity: ${tank.capacity}L\nCurrent Level: ${tank.level}%\n`;
    const blob = new Blob([dataStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `MIT_Report_${tank.name.replace(/\s+/g, '_')}.${format === 'Excel' ? 'xlsx' : (format === 'CSV' ? 'csv' : 'pdf')}`;
    a.click();
    URL.revokeObjectURL(url);
    triggerToast(`${format} Report successfully generated!`);
  }, 1500);
}
