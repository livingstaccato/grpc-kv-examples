#
# utils/database.py
#

import sqlite3
from contextlib import contextmanager
from typing import Any, Dict, Optional, Generator
import logging
from queue import Queue
import threading

# Configure logging
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(levelname)s %(name)s: %(message)s',
    datefmt='%Y/%m/%d %H:%M:%S',
)

DB_PATH = "celersql.db"
SCHEMA_VERSION = 1  # Increment this for schema updates

logger = logging.getLogger(__name__)

class DatabaseConnectionPool:
    def __init__(self, db_path, max_connections=5):
        self.db_path = db_path
        self.max_connections = max_connections
        self.connections = Queue(maxsize=max_connections)
        self.lock = threading.Lock()

        for _ in range(max_connections):
            self.connections.put(self._create_connection())

    def _create_connection(self):
        try:
            conn = sqlite3.connect(self.db_path, detect_types=sqlite3.PARSE_DECLTYPES, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            logger.debug("🔌 New database connection established.")
            return conn
        except sqlite3.Error as e:
            logger.error(f"❌ Database connection error: {e}")
            raise

    def get_connection(self):
        return self.connections.get()

    def release_connection(self, conn):
        if conn:
            self.connections.put(conn)
            logger.debug("🔌 Database connection released to pool.")

db_pool = DatabaseConnectionPool(DB_PATH)

@contextmanager
def connect_db() -> Generator[sqlite3.Connection, None, None]:
    conn = None
    try:
        conn = db_pool.get_connection()
        yield conn
    finally:
        db_pool.release_connection(conn)

@contextmanager
def connect_db() -> Generator[sqlite3.Connection, None, None]:
    """
    Context manager to handle SQLite database connection.
    Yields:
        sqlite3.Connection: Database connection object.
    """
    conn = None
    try:
        conn = sqlite3.connect(DB_PATH, detect_types=sqlite3.PARSE_DECLTYPES)
        conn.row_factory = sqlite3.Row  # Enable named column access
        logger.debug("🔌 Database connection established.")
        yield conn
    except sqlite3.Error as e:
        logger.error(f"❌ Database connection error: {e}")
        raise
    finally:
        if conn:
            conn.close()
            logger.debug("🔌 Database connection closed.")


def initialize_schema() -> None:
    """
    Initializes or updates the database schema. Handles migrations if necessary.
    """
    with connect_db() as conn:
        cursor = conn.cursor()

        # Create schema version tracking table
        logger.info("🔧 Creating schema_version table if not exists.")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version INTEGER NOT NULL
            )
        """)

        # Check the current schema version
        cursor.execute("SELECT MAX(version) FROM schema_version")
        current_version = cursor.fetchone()[0]
        if not current_version:
            logger.info("🆕 No schema version found. Initializing database...")
            apply_migration(conn, SCHEMA_VERSION)
        elif current_version < SCHEMA_VERSION:
            logger.info(f"🔄 Updating schema from version {current_version} to {SCHEMA_VERSION}.")
            for version in range(current_version + 1, SCHEMA_VERSION + 1):
                apply_migration(conn, version)
        else:
            logger.info(f"✅ Database schema is up-to-date (version {current_version}).")

        conn.commit()


def apply_migration(conn: sqlite3.Connection, version: int) -> None:
    """
    Apply schema migration for a specific version.

    Args:
        conn (sqlite3.Connection): Active database connection.
        version (int): Target schema version to apply.
    """
    logger.info(f"🚀 Applying schema migration for version {version}.")
    cursor = conn.cursor()

    if version == 1:
        logger.info("🆕 Creating initial schema.")
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
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS request_metadata (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id TEXT,
                key TEXT,
                value TEXT,
                FOREIGN KEY(transaction_id) REFERENCES transactions(id)
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS response_metadata (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id TEXT,
                key TEXT,
                value TEXT,
                FOREIGN KEY(transaction_id) REFERENCES transactions(id)
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS certificate_logs (
                log_id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id TEXT,
                cert_type TEXT,
                cert_details TEXT,
                FOREIGN KEY(transaction_id) REFERENCES transactions(id)
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS errors (
                error_id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id TEXT,
                error_message TEXT,
                stack_trace TEXT,
                logged_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(transaction_id) REFERENCES transactions(id)
            )
        """)
        cursor.execute("INSERT INTO schema_version (version) VALUES (1)")
    else:
        logger.warning(f"⚠️ No migration script found for version {version}. Skipping.")


def execute_query(query: str, params: Optional[Dict[str, Any]] = None) -> list:
    """
    Execute a SQL query and return the results.

    Args:
        query (str): The SQL query to execute.
        params (Dict[str, Any], optional): Parameters to bind to the query.

    Returns:
        list: List of rows from the query result.
    """
    with connect_db() as conn:
        cursor = conn.cursor()
        try:
            logger.debug(f"📝 Executing query: {query} with params: {params}")
            cursor.execute(query, params or {})
            results = cursor.fetchall()
            logger.debug(f"✅ Query executed successfully. Rows fetched: {len(results)}")
            return [dict(row) for row in results]
        except sqlite3.Error as e:
            logger.error(f"❌ Query execution error: {e}")
            raise


def execute_update(query: str, params: Optional[list] = None) -> int:
    """
    Execute a SQL update/insert/delete and return the affected row count.

    Args:
        query (str): The SQL query to execute.
        params (list, optional): Parameters to bind to the query.

    Returns:
        int: Number of rows affected by the query.
    """
    with connect_db() as conn:
        cursor = conn.cursor()
        try:
            # Default params to an empty list if None
            logger.debug(f"📝 Executing update: {query} with params: {params}")
            cursor.execute(query, params or [])
            conn.commit()
            logger.debug(f"✅ Update executed successfully. Rows affected: {cursor.rowcount}")
            return cursor.rowcount
        except sqlite3.Error as e:
            logger.error(f"❌ Update execution error: {e}")
            raise


if __name__ == "__main__":
    try:
        logger.info("🚀 Bootstrapping database...")
        initialize_schema()
        logger.info("✅ Database is ready.")
    except Exception as e:
        logger.error(f"❌ Failed to bootstrap database: {e}")
