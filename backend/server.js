const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

let tanks = [
  {
    Device_id: "tank_001",
    tankCapacity: 25000.0,
    tankHeight: 2500.0,
    tankShape: "cylindrical",
    VREF: 3300.0,
    CORRECTION_FACTOR: 1.41,
    OFFSET: 0.0
  },
  {
    Device_id: "tank_002",
    tankCapacity: 10000.0,
    tankHeight: 4000.0,
    tankShape: "cylindrical",
    VREF: 3300.0,
    CORRECTION_FACTOR: 1.41,
    OFFSET: 0.0
  }
];

let telemetries = {
  "tank_001": {
    Device_id: "tank_001",
    waterPercent: 75.0,
    depth: 1.875,
    rawADC: 3072.0,
    dataVoltage: 3300.0,
    dataCurrent: 4.0,
    timestamp: Math.floor(Date.now() / 1000)
  },
  "tank_002": {
    Device_id: "tank_002",
    waterPercent: 88.0,
    depth: 3.52,
    rawADC: 3603.0,
    dataVoltage: 3300.0,
    dataCurrent: 4.0,
    timestamp: Math.floor(Date.now() / 1000)
  }
};

let history = {
  "tank_001": [
    {
      Device_id: "tank_001",
      waterPercent: "75.0",
      depth: "1.875",
      rawADC: "3072",
      dataVoltage: "3300",
      dataCurrent: "4.0",
      timestamp: String(Math.floor(Date.now() / 1000))
    }
  ]
};

app.get('/prod/tanks', (req, res) => {
  res.json(tanks);
});

app.post('/prod/tank', (req, res) => {
  const newConfig = req.body;
  if (!newConfig.Device_id) {
    return res.status(400).json({ error: "Device_id is required" });
  }
  const exists = tanks.some(t => t.Device_id === newConfig.Device_id);
  if (exists) {
    return res.status(409).json({ error: "Conflict: Tank already exists" });
  }

  tanks.push({
    Device_id: newConfig.Device_id,
    tankCapacity: Number(newConfig.tankCapacity) || 15000,
    tankHeight: Number(newConfig.tankHeight) || 5000,
    tankShape: newConfig.tankShape || 'cylindrical',
    VREF: Number(newConfig.VREF) || 3300.0,
    CORRECTION_FACTOR: Number(newConfig.CORRECTION_FACTOR) || 1.0,
    OFFSET: Number(newConfig.OFFSET) || 0.0
  });

  telemetries[newConfig.Device_id] = {
    Device_id: newConfig.Device_id,
    waterPercent: 0.0,
    depth: 0.0,
    rawADC: 0.0,
    dataVoltage: 0.0,
    dataCurrent: 0.0,
    timestamp: Math.floor(Date.now() / 1000)
  };

  history[newConfig.Device_id] = [];

  res.status(201).json({
    message: "Tank created successfully",
    Device_id: newConfig.Device_id
  });
});

app.get('/prod/tank/:deviceId/latest', (req, res) => {
  const { deviceId } = req.params;
  const telemetry = telemetries[deviceId];
  if (!telemetry) {
    return res.status(404).json({ error: "No telemetry found" });
  }
  res.json({
    ...telemetry,
    timestamp: Math.floor(Date.now() / 1000)
  });
});

app.get('/prod/tank/:deviceId/history', (req, res) => {
  const { deviceId } = req.params;
  res.json(history[deviceId] || []);
});

app.get('/prod/tank/:deviceId/config', (req, res) => {
  const { deviceId } = req.params;
  const config = tanks.find(t => t.Device_id === deviceId);
  if (!config) {
    return res.status(404).json({ error: "Config not found" });
  }
  res.json(config);
});

app.put('/prod/tank/:deviceId/config', (req, res) => {
  const { deviceId } = req.params;
  const updatedConfig = req.body;
  const index = tanks.findIndex(t => t.Device_id === deviceId);
  if (index === -1) {
    return res.status(404).json({ error: "Tank config not found" });
  }

  tanks[index] = {
    Device_id: deviceId,
    tankCapacity: Number(updatedConfig.tankCapacity) || tanks[index].tankCapacity,
    tankHeight: Number(updatedConfig.tankHeight) || tanks[index].tankHeight,
    tankShape: updatedConfig.tankShape || tanks[index].tankShape,
    VREF: Number(updatedConfig.VREF) || tanks[index].VREF,
    CORRECTION_FACTOR: Number(updatedConfig.CORRECTION_FACTOR) || tanks[index].CORRECTION_FACTOR,
    OFFSET: Number(updatedConfig.OFFSET) || tanks[index].OFFSET
  };

  res.json({
    message: "Configuration updated successfully",
    Device_id: deviceId
  });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
