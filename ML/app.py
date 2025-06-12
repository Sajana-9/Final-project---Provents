from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, db
import pandas as pd
import joblib
import numpy as np
from datetime import datetime
import logging
import socket
import atexit
import netifaces
from zeroconf import ServiceInfo, Zeroconf

# Initialize Flask app
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===== Configuration =====
SERVICE_TYPE = "_taskapp._tcp.local."
SERVICE_NAME = "TaskManager"
PORT = 5000

# ===== Firebase Initialization =====
def initialize_firebase():
    try:
        cred = credentials.Certificate("task-app-85e6d-firebase-adminsdk-fbsvc-a48807b68a.json")
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://task-app-85e6d-default-rtdb.asia-southeast1.firebasedatabase.app/'
        })
        logger.info("Firebase initialized successfully")
    except Exception as e:
        logger.error(f"Firebase initialization failed: {str(e)}")
        raise

# ===== ML Models Initialization =====
def load_models():
    try:
        priority_model = joblib.load('priority_model_final.pkl')
        leaderboard_model = joblib.load('leaderboard_model.pkl')
        logger.info("ML models loaded successfully")
        return priority_model, leaderboard_model
    except Exception as e:
        logger.error(f"Model loading failed: {str(e)}")
        raise

# ===== Network Utilities =====
def get_local_ip():
    """Get the most appropriate local IP address"""
    try:
        for interface in netifaces.interfaces():
            addrs = netifaces.ifaddresses(interface)
            if netifaces.AF_INET in addrs:
                for addr in addrs[netifaces.AF_INET]:
                    ip = addr['addr']
                    if not ip.startswith('127.') and not ip.startswith('169.254.'):
                        return ip
        return socket.gethostbyname(socket.gethostname())
    except Exception as e:
        logger.warning(f"IP detection error: {e}")
        return "127.0.0.1"

# ===== mDNS Service Advertisement =====
class ServiceAdvertiser:
    def __init__(self):
        self.zeroconf = None
        self.host_ip = get_local_ip()
        self.hostname = socket.gethostname()
        self.service_name = f"{SERVICE_NAME}-{self.hostname}"

    def start(self):
        try:
            service_info = ServiceInfo(
                SERVICE_TYPE,
                f"{self.service_name}.{SERVICE_TYPE}",
                addresses=[socket.inet_aton(self.host_ip)],
                port=PORT,
                properties={
                    'version': '1.0',
                    'host': self.hostname,
                    'service': 'task-manager',
                    'api': '/leaderboard,/prioritize'
                },
                server=f"{self.hostname}.local."
            )

            self.zeroconf = Zeroconf()
            self.zeroconf.register_service(service_info)
            logger.info(f"Registered service: {self.service_name} at {self.host_ip}:{PORT}")
        except Exception as e:
            logger.error(f"mDNS registration failed: {str(e)}")

    def stop(self):
        if self.zeroconf:
            self.zeroconf.unregister_all_services()
            self.zeroconf.close()
            logger.info("Unregistered mDNS services")

# Initialize components
advertiser = ServiceAdvertiser()
initialize_firebase()
priority_model, leaderboard_model = load_models()

# ===== Core Business Logic =====
def process_tasks(tasks):
    """Process and validate input tasks"""
    df = pd.DataFrame(tasks)
    
    # Date validation
    df['deadline'] = pd.to_datetime(df['deadline'], errors='coerce')
    if df['deadline'].isnull().any():
        raise ValueError("Invalid deadline format")
    
    # Feature engineering
    df['days_left'] = (df['deadline'] - pd.Timestamp.now()).dt.days.clip(lower=0)
    df['status_encoded'] = df['completed'].map(lambda x: 0 if x else 1)
    
    # Dependency processing
    df['dependencies'] = df['dependencies'].apply(
        lambda x: x.split(',') if isinstance(x, str) else []
    )
    df['dependency_count'] = df['dependencies'].apply(len)
    
    # Dependency graph analysis
    dep_map = {}
    for _, row in df.iterrows():
        for dep in row['dependencies']:
            dep_map.setdefault(dep, []).append(row['task_id'])
    
    df['dependency_level'] = df['task_id'].apply(lambda x: len(dep_map.get(x, [])))
    
    return df

def calculate_member_stats(member_data):
    """Calculate performance metrics for a member"""
    stats = {
        'total_tasks': 0,
        'complexity_4': 0,
        'complexity_3': 0,
        'avg_completion_time': 0,
        'on_time_rate': 0
    }
    
    completion_times = []
    on_time_count = 0

    for project in member_data.get('projects', {}).values():
        for task in project.get('tasks', {}).values():
            if task.get('status', False):
                stats['total_tasks'] += 1
                complexity = task.get('complextivity', 1)
                if complexity == 4: stats['complexity_4'] += 1
                if complexity == 3: stats['complexity_3'] += 1

                try:
                    created = datetime.strptime(task['created_date'], "%Y-%m-%d")
                    completed = datetime.strptime(task['completed_date'], "%Y-%m-%d")
                    due_date = datetime.strptime(task['due_date'], "%Y-%m-%d")
                    
                    completion_days = (completed - created).days
                    completion_times.append(completion_days)
                    
                    if completed <= due_date:
                        on_time_count += 1
                except KeyError as e:
                    logger.warning(f"Missing date field in task: {e}")
                    continue

    if stats['total_tasks'] > 0:
        stats['avg_completion_time'] = np.mean(completion_times)
        stats['on_time_rate'] = on_time_count / stats['total_tasks']
    
    return stats

# ===== API Endpoints =====
@app.route('/prioritize', methods=['POST'])
def prioritize_tasks():
    """Prioritize tasks using ML model"""
    try:
        data = request.json
        if not data or 'tasks' not in data:
            return jsonify({'error': 'No tasks provided'}), 400
            
        df = process_tasks(data['tasks'])
        features = df[['complexity', 'days_left', 'dependency_count', 'status_encoded', 'dependency_level']]
        
        # Generate predictions
        df['predicted_priority'] = priority_model.predict(features)
        df.loc[df['completed'], 'predicted_priority'] = -9999
        
        # Sort tasks
        sorted_df = df.sort_values(
            by=['status_encoded', 'predicted_priority', 'dependency_level'],
            ascending=[False, False, False]
        )
        
        # Prepare response
        result = sorted_df.to_dict('records')
        for task in result:
            task['deadline'] = task['deadline'].isoformat()
            task['dependencies'] = ', '.join(task['dependencies']) if task['dependencies'] else ''
        print(result)
        return jsonify({'tasks': result})
    
    except Exception as e:
        logger.error(f"Prioritization error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/leaderboard', methods=['GET'])
def get_leaderboard():
    """Generate team leaderboard"""
    try:
        ref = db.reference('/members')
        all_members = ref.get()
        leaderboard = []

        for member_key, member_data in all_members.items():
            stats = calculate_member_stats(member_data)
            
            if stats['total_tasks'] > 0:
                features = [
                    stats['total_tasks'],
                    stats['complexity_4'],
                    stats['complexity_3'],
                    stats['avg_completion_time'],
                    stats['on_time_rate']
                ]
                score = leaderboard_model.predict([features])[0]
            else:
                score = 0.0

            leaderboard.append({
                'name': member_data.get('name', 'Unknown'),
                'email': member_data.get('email', member_key.replace(',', '.')),
                'score': round(score, 2),
                'total_tasks': stats['total_tasks'],
                'on_time_rate': round(stats['on_time_rate'], 2),
                'complexity_4': stats['complexity_4'],
                'complexity_3': stats['complexity_3']
            })

        # Sort and rank
        leaderboard.sort(key=lambda x: x['score'], reverse=True)
        current_rank = 1
        prev_score = None
        
        for idx, entry in enumerate(leaderboard):
            if entry['score'] == prev_score:
                entry['rank'] = current_rank
            else:
                current_rank = idx + 1
                entry['rank'] = current_rank
                prev_score = entry['score']

        return jsonify(leaderboard)

    except Exception as e:
        logger.error(f"Leaderboard error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/discovery', methods=['GET'])
def discovery_info():
    """Return service discovery information"""
    return jsonify({
        'service': SERVICE_NAME,
        'host': advertiser.hostname,
        'ip': advertiser.host_ip,
        'port': PORT,
        'endpoints': {
            'leaderboard': '/leaderboard',
            'prioritize': '/prioritize'
        }
    })

# ===== Startup/Shutdown =====
def cleanup():
    advertiser.stop()
    logger.info("Service cleanup complete")

atexit.register(cleanup)

if __name__ == '__main__':
    try:
        advertiser.start()
        logger.info(f"""
        ====================================
        Task Management Server Started
        Local IP: {advertiser.host_ip}
        Hostname: {advertiser.hostname}
        mDNS Service: {advertiser.service_name}
        ====================================
        """)
        app.run(host='0.0.0.0', port=PORT, debug=False)
    except Exception as e:
        logger.critical(f"Failed to start server: {str(e)}")
        cleanup()