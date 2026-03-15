import React, { useState, useEffect } from 'react'
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'

// API endpoint - will be replaced during deployment
const API_ENDPOINT = import.meta.env.VITE_API_ENDPOINT || 'https://api.example.com/dev/results'

const COLORS = ['#0066ff', '#4d94ff', '#80b3ff', '#b3d9ff']

// Animated counter hook
function useCountUp(end, duration = 2000) {
  const [count, setCount] = useState(0)

  useEffect(() => {
    if (!end) return
    let startTime
    const animate = (currentTime) => {
      if (!startTime) startTime = currentTime
      const progress = Math.min((currentTime - startTime) / duration, 1)
      setCount(Math.floor(progress * end))
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    requestAnimationFrame(animate)
  }, [end, duration])

  return count
}

// StatCard component with tooltip
function StatCard({ label, value, unit, tooltip, isViolation }) {
  const animatedValue = useCountUp(parseFloat(value))

  return (
    <div className={`stat-card ${isViolation ? 'violation' : ''}`}>
      <div className="stat-header">
        <div className="stat-label">{label}</div>
        {tooltip && (
          <div className="tooltip-icon" data-tooltip={tooltip}>
            ?
          </div>
        )}
      </div>
      <div className="stat-value">
        {animatedValue}{unit && <span className="stat-unit">{unit}</span>}
      </div>
    </div>
  )
}

function App() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [lastUpdate, setLastUpdate] = useState(new Date())
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
      setLastUpdate(new Date())
    } catch (err) {
      console.error('Error fetching data:', err)
      setError(err.message)
      // Use mock data for demo
      setData(generateMockData())
      setLastUpdate(new Date())
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
        <div className="header-content">
          <h1>Traffic Speed Analyzer</h1>
          <p>Real-time vehicle detection and speed analytics powered by AWS</p>
          <div className="update-indicator">
            <div className="update-dot"></div>
            Last updated: {lastUpdate.toLocaleTimeString()}
          </div>
        </div>
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
        <StatCard
          label="Total Vehicles"
          value={stats.totalVehicles || 0}
          tooltip="Total number of vehicles detected in the dataset"
        />

        <StatCard
          label="Average Speed"
          value={stats.averageSpeed || 0}
          unit=" km/h"
          tooltip="Mean speed of all detected vehicles"
        />

        <StatCard
          label="Max Speed"
          value={stats.maxSpeed || 0}
          unit=" km/h"
          tooltip="Highest speed recorded"
        />

        <StatCard
          label="Violations"
          value={stats.violations || 0}
          unit={` (${stats.violationRate || 0}%)`}
          tooltip="Vehicles exceeding 80 km/h speed limit"
          isViolation={true}
        />
      </div>

      <div className="chart-container">
        <h3 className="chart-title">Speed Over Time</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={prepareTimeSeriesData()}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e0e0e0" />
            <XAxis dataKey="frame" stroke="#6b6b6b" />
            <YAxis stroke="#6b6b6b" label={{ value: 'Speed (km/h)', angle: -90, position: 'insideLeft' }} />
            <Tooltip contentStyle={{ background: '#f0f0f3', border: 'none', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }} />
            <Legend wrapperStyle={{ paddingTop: '20px' }} />
            <Line type="monotone" dataKey="speed" stroke="#0066ff" strokeWidth={3} dot={{ fill: '#0066ff', r: 4 }} name="Vehicle Speed" />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="grid-2">
        <div className="chart-container">
          <h3 className="chart-title">Speed Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={prepareSpeedDistribution()}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e0e0e0" />
              <XAxis dataKey="speed" stroke="#6b6b6b" label={{ value: 'Speed Range (km/h)', position: 'insideBottom', offset: -5 }} />
              <YAxis stroke="#6b6b6b" label={{ value: 'Count', angle: -90, position: 'insideLeft' }} />
              <Tooltip contentStyle={{ background: '#f0f0f3', border: 'none', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }} />
              <Legend wrapperStyle={{ paddingTop: '20px' }} />
              <Bar dataKey="count" fill="#0066ff" radius={[8, 8, 0, 0]} name="Number of Vehicles" />
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
                labelLine={true}
                label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                outerRadius={100}
                fill="#0066ff"
                dataKey="value"
              >
                {prepareVehicleTypeData().map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip contentStyle={{ background: '#f0f0f3', border: 'none', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }} />
              <Legend wrapperStyle={{ paddingTop: '20px' }} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="chart-container">
        <h3 className="chart-title">Traffic Location</h3>
        <div style={{ height: '400px', borderRadius: '0.75rem', overflow: 'hidden' }}>
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

      <footer>
        <p>Traffic Speed Analyzer | Powered by AWS Serverless Architecture</p>
        <small>Demo project using BrnoCompSpeed dataset</small>
      </footer>
    </div>
  )
}

export default App
