const express = require('express');
const prometheus = require('prom-client');

const app = express();

// Prometheus metrics collection
const collectDefaultMetrics = prometheus.collectDefaultMetrics;
collectDefaultMetrics();

app.get('/', (req, res) => {
    res.status(200).send('Hello DevOps TP4!');
});

app.get('/metrics', async (req, res) => {
    try {
        res.set('Content-Type', prometheus.register.contentType);
        res.end(await prometheus.register.metrics());
    } catch (ex) {
        res.status(500).end(ex);
    }
});

module.exports = app;
