import sqlite3
import logging

logger = logging.getLogger(__name__)

DB_PATH = "celersql.db"

def connect_db():
    return sqlite3.connect(DB_PATH)

def migrate():
    with connect_db() as conn:
        cursor = conn.cursor()
        logger.info("🔧 Bootstrapping database...")
        
        # Initialize schema_version table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                id INTEGER PRIMARY KEY,
                version INTEGER NOT NULL
            )
        """)
        
        # Create other tables if needed
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                client_id TEXT,
                request_type TEXT,
                status TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                message TEXT
            )
        """)
        # Add other table creation queries here...

        # Check and set initial schema version
        cursor.execute("SELECT MAX(version) FROM schema_version")
        current_version = cursor.fetchone()[0]
        if not current_version:
            cursor.execute("INSERT INTO schema_version (version) VALUES (1)")

        conn.commit()
        logger.info("✅ Database bootstrapped successfully.")
