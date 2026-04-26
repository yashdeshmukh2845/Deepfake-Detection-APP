import React, { useEffect, useState } from 'react';
import { supabase } from './supabaseClient';
import { 
  BarChart3, 
  Download, 
  AlertTriangle, 
  CheckCircle2, 
  Filter, 
  RefreshCcw,
  LayoutDashboard,
  MessageSquare,
  Search,
  ImageOff,
  Video
} from 'lucide-react';

interface Report {
  id: string;
  media_url: string;
  predicted_result: string;
  confidence: number;
  is_incorrect: boolean;
  feedback_text: string;
  created_at: string;
}

const MediaPreview: React.FC<{ url: string }> = ({ url }) => {
  const [error, setError] = useState(false);
  const isVideo = url.toLowerCase().match(/\.(mp4|webm|ogg|mov)$/) || url.includes('/video');

  if (isVideo) {
    return (
      <div className="preview-placeholder">
        <Video size={20} color="var(--text-dim)" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="preview-placeholder">
        <ImageOff size={20} color="var(--text-dim)" />
      </div>
    );
  }

  return (
    <img 
      src={url} 
      className="preview-img" 
      alt="Preview" 
      onError={() => setError(true)} 
    />
  );
};

const App: React.FC = () => {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterIncorrect, setFilterIncorrect] = useState(false);
  const [stats, setStats] = useState({ total: 0, incorrect: 0, avgConfidence: 0 });

  useEffect(() => {
    fetchReports();
  }, [filterIncorrect]);

  const fetchReports = async () => {
    setLoading(true);
    let query = supabase.from('reports').select('*').order('created_at', { ascending: false });
    
    if (filterIncorrect) {
      query = query.eq('is_incorrect', true);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching reports:', error);
    } else {
      setReports(data || []);
      calculateStats(data || []);
    }
    setLoading(false);
  };

  const calculateStats = (data: Report[]) => {
    const total = data.length;
    const incorrect = data.filter(r => r.is_incorrect).length;
    const avgConfidence = data.reduce((acc, r) => acc + r.confidence, 0) / (total || 1);
    setStats({ total, incorrect, avgConfidence });
  };

  const handleDownload = (url: string) => {
    window.open(url, '_blank');
  };

  return (
    <div className="app-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '40px' }}>
          <div style={{ padding: '8px', background: 'var(--primary)', borderRadius: '10px' }}>
            <AlertTriangle color="black" size={24} />
          </div>
          <h2 style={{ fontSize: '20px', fontWeight: '800' }}>Deep Guard</h2>
        </div>

        <nav>
          <div className="btn" style={{ background: 'rgba(255,255,255,0.05)', width: '100%', justifyContent: 'flex-start' }}>
            <LayoutDashboard size={20} color="var(--primary)" />
            Dashboard
          </div>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="main-content">
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '40px' }}>
          <div>
            <h1 style={{ fontSize: '32px', fontWeight: '800' }}>Admin Dashboard</h1>
            <p style={{ color: 'var(--text-dim)' }}>ML Model Performance & User Reports</p>
          </div>
          <button className="btn btn-primary" onClick={fetchReports}>
            <RefreshCcw size={18} />
            Refresh Data
          </button>
        </header>

        {/* Stats Cards */}
        <div className="stats-grid">
          <div className="card stat-card">
            <div className="stat-label">Total Reports</div>
            <div className="stat-value">{stats.total}</div>
          </div>
          <div className="card stat-card">
            <div className="stat-label">Incorrect Detections</div>
            <div className="stat-value" style={{ color: 'var(--danger)' }}>{stats.incorrect}</div>
          </div>
          <div className="card stat-card">
            <div className="stat-label">Avg. Confidence</div>
            <div className="stat-value" style={{ color: 'var(--success)' }}>{stats.avgConfidence.toFixed(1)}%</div>
          </div>
        </div>

        {/* Table Controls */}
        <div className="card">
          <div className="filters">
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Filter size={18} color="var(--text-dim)" />
              <span style={{ fontSize: '14px' }}>Filters:</span>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input 
                type="checkbox" 
                checked={filterIncorrect} 
                onChange={(e) => setFilterIncorrect(e.target.checked)} 
              />
              <span style={{ fontSize: '14px' }}>Only Incorrect Results</span>
            </label>
          </div>

          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>Loading reports...</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Media</th>
                  <th>Predicted</th>
                  <th>Confidence</th>
                  <th>Status</th>
                  <th>Feedback</th>
                  <th>Date</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((report) => (
                  <tr key={report.id}>
                    <td>
                      <MediaPreview url={report.media_url} />
                    </td>
                    <td>
                      <span style={{ fontWeight: 'bold' }}>{report.predicted_result.toUpperCase()}</span>
                    </td>
                    <td>{report.confidence.toFixed(1)}%</td>
                    <td>
                      {report.is_incorrect ? (
                        <span className="badge badge-danger">Incorrect</span>
                      ) : (
                        <span className="badge" style={{ background: 'rgba(0, 230, 118, 0.1)', color: 'var(--success)', border: '1px solid rgba(0, 230, 118, 0.2)' }}>Correct</span>
                      )}
                    </td>
                    <td style={{ maxWidth: '200px', fontSize: '13px', color: 'var(--text-dim)' }}>
                      {report.feedback_text || 'No feedback'}
                    </td>
                    <td>{new Date(report.created_at).toLocaleDateString()}</td>
                    <td>
                      <button className="btn" style={{ padding: '8px', background: 'rgba(255,255,255,0.05)' }} onClick={() => handleDownload(report.media_url)}>
                        <Download size={18} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          
          {!loading && reports.length === 0 && (
            <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-dim)' }}>
              No reports found for the selected filter.
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default App;
