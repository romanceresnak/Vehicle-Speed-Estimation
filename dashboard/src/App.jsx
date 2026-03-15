import React, { useState, useEffect } from 'react'
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { MapContainer, TileLayer, HeatmapLayer, Marker, Popup } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'

// API endpoint - will be replaced during deployment
const API_ENDPOINT = import.meta.env.VITE_API_ENDPOINT || 'https://api.example.com/dev/results'

const COLORS = ['#667eea', '#764ba2', '#f093fb', '#4facfe']

function App() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filter, setFilter] = useState({
    location: '',
    videoId: ''
  })

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    try {
      setLoading(true)
      setError(null)

      // Build query params
      const params = new URLSearchParams()
      if (filter.location) params.append('location', filter.location)
      if (filter.videoId) params.append('videoId', filter.videoId)
      params.append('limit', '500')

      const url = `${API_ENDPOINT}?${params.toString()}`
      const response = await fetch(url)

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`)
      }

      const result = await response.json()
      setData(result)
    } catch (err) {
      console.error('Error fetching data:', err)
      setError(err.message)
      // Use mock data for demo
      setData(generateMockData())
    } finally {
      setLoading(false)
    }
  }

  const generateMockData = () => {
    const results = []
    const vehicleTypes = ['car', 'truck', 'bus', 'motorcycle']

    for (let i = 0; i < 100; i++) {
      results.push({
        videoId: 'session-001.mp4',
        timestamp: Date.now() + i * 1000,
        frameNumber: i * 30,
        vehicleType: vehicleTypes[Math.floor(Math.random() * vehicleTypes.length)],
        speed: Math.floor(Math.random() * 90) + 30,
        confidence: 0.7 + Math.random() * 0.29,
        location: 'brno-location-1'
      })
    }

    const speeds = results.map(r => r.speed)
    const avgSpeed = speeds.reduce((a, b) => a + b, 0) / speeds.length
    const violations = results.filter(r => r.speed > 80).length

    const vehicleTypeCounts = {}
    results.forEach(r => {
      vehicleTypeCounts[r.vehicleType] = (vehicleTypeCounts[r.vehicleType] || 0) + 1
    })

    return {
      count: results.length,
      results: results,
      statistics: {
        totalVehicles: results.length,
        averageSpeed: avgSpeed.toFixed(2),
        maxSpeed: Math.max(...speeds),
        minSpeed: Math.min(...speeds),
        violations: violations,
        violationRate: ((violations / results.length) * 100).toFixed(2),
        vehicleTypes: vehicleTypeCounts
      }
    }
  }

  const prepareSpeedDistribution = () => {
    if (!data?.results) return []

    const distribution = {}
    data.results.forEach(item => {
      const bucket = Math.floor(item.speed / 10) * 10
      distribution[bucket] = (distribution[bucket] || 0) + 1
    })

    return Object.entries(distribution)
      .map(([speed, count]) => ({
        speed: `${speed}-${parseInt(speed) + 10}`,
        count
      }))
      .sort((a, b) => parseInt(a.speed) - parseInt(b.speed))
  }

  const prepareVehicleTypeData = () => {
    if (!data?.statistics?.vehicleTypes) return []

    return Object.entries(data.statistics.vehicleTypes).map(([type, count]) => ({
      name: type,
      value: count
    }))
  }

  const prepareTimeSeriesData = () => {
    if (!data?.results) return []

    const sorted = [...data.results].sort((a, b) => a.frameNumber - b.frameNumber)
    return sorted.slice(0, 50).map(item => ({
      frame: item.frameNumber,
      speed: item.speed
    }))
  }

  if (loading) {
    return <div className="loading">Loading traffic data...</div>
  }

  if (error && !data) {
    return (
      <div className="container">
        <div className="error">
          Error loading data: {error}
          <br />
          <small>Showing demo data instead</small>
        </div>
      </div>
    )
  }

  const stats = data?.statistics || {}

  return (
    <div className="container">
      <header className="header">
        <h1>AI Traffic Safety Analyzer</h1>
        <p>Real-time vehicle detection and speed estimation dashboard</p>
      </header>

      <div className="controls">
        <input
          type="text"
          placeholder="Location"
          value={filter.location}
          onChange={(e) => setFilter({ ...filter, location: e.target.value })}
        />
        <input
          type="text"
          placeholder="Video ID"
          value={filter.videoId}
          onChange={(e) => setFilter({ ...filter, videoId: e.target.value })}
        />
        <button onClick={fetchData}>Filter</button>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">Total Vehicles</div>
          <div className="stat-value">{stats.totalVehicles || 0}</div>
        </div>

        <div className="stat-card">
          <div className="stat-label">Average Speed</div>
          <div className="stat-value">
            {stats.averageSpeed || 0}
            <span className="stat-unit">km/h</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-label">Max Speed</div>
          <div className="stat-value">
            {stats.maxSpeed || 0}
            <span className="stat-unit">km/h</span>
          </div>
        </div>

        <div className="stat-card violation">
          <div className="stat-label">Violations</div>
          <div className="stat-value">
            {stats.violations || 0}
            <span className="stat-unit">({stats.violationRate || 0}%)</span>
          </div>
        </div>
      </div>

      <div className="chart-container">
        <h3 className="chart-title">Speed Over Time</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={prepareTimeSeriesData()}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="frame" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="speed" stroke="#667eea" strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
        <div className="chart-container">
          <h3 className="chart-title">Speed Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={prepareSpeedDistribution()}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="speed" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="count" fill="#764ba2" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="chart-container">
          <h3 className="chart-title">Vehicle Types</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={prepareVehicleTypeData()}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="value"
              >
                {prepareVehicleTypeData().map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="chart-container">
        <h3 className="chart-title">Traffic Heatmap</h3>
        <div style={{ height: '400px', borderRadius: '10px', overflow: 'hidden' }}>
          <MapContainer
            center={[49.1951, 16.6068]}
            zoom={13}
            style={{ height: '100%', width: '100%' }}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <Marker position={[49.1951, 16.6068]}>
              <Popup>
                Brno Location 1<br />
                {stats.totalVehicles || 0} vehicles detected<br />
                {stats.violations || 0} violations
              </Popup>
            </Marker>
          </MapContainer>
        </div>
      </div>

      <footer style={{ textAlign: 'center', padding: '40px 0', color: '#666' }}>
        <p>AI Traffic Safety Analyzer | Powered by AWS & YOLOv8</p>
        <p><small>Using BrnoCompSpeed dataset from Brno University of Technology</small></p>
      </footer>
    </div>
  )
}

export default App
