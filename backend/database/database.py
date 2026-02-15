"""SQLite database connection and schema management."""

import os
import aiosqlite
from core.logger import logger

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "travver.db")

_SCHEMA_SQL = """
-- app_config
CREATE TABLE IF NOT EXISTS app_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- trips
CREATE TABLE IF NOT EXISTS trips (
    id                     TEXT    PRIMARY KEY,
    destination            TEXT    NOT NULL,
    period_start           TEXT    NOT NULL,
    period_end             TEXT    NOT NULL,
    travelers              INTEGER NOT NULL DEFAULT 1,
    budget_estimated       INTEGER NOT NULL DEFAULT 0,
    budget_currency        TEXT    NOT NULL DEFAULT 'KRW',
    styles                 TEXT    NOT NULL DEFAULT '[]',
    custom_preference      TEXT,
    accommodation_location TEXT,
    status                 TEXT    NOT NULL DEFAULT 'upcoming',
    image_url              TEXT,
    created_at             TEXT    NOT NULL,
    updated_at             TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_created_at ON trips(created_at);

-- daily_plans
CREATE TABLE IF NOT EXISTS daily_plans (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id TEXT    NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    day     INTEGER NOT NULL,
    date    TEXT    NOT NULL,
    theme   TEXT    NOT NULL,
    UNIQUE(trip_id, day)
);

CREATE INDEX IF NOT EXISTS idx_daily_plans_trip_id ON daily_plans(trip_id);

-- schedules
CREATE TABLE IF NOT EXISTS schedules (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    daily_plan_id  INTEGER NOT NULL REFERENCES daily_plans(id) ON DELETE CASCADE,
    order_index    INTEGER NOT NULL,
    time           TEXT    NOT NULL,
    place          TEXT    NOT NULL,
    category       TEXT    NOT NULL,
    duration_min   INTEGER NOT NULL,
    estimated_cost INTEGER NOT NULL DEFAULT 0,
    description    TEXT    NOT NULL DEFAULT '',
    latitude       REAL    NOT NULL,
    longitude      REAL    NOT NULL,
    image_url      TEXT,
    rating         REAL,
    place_id       TEXT,
    UNIQUE(daily_plan_id, order_index)
);

CREATE INDEX IF NOT EXISTS idx_schedules_daily_plan_id ON schedules(daily_plan_id);
CREATE INDEX IF NOT EXISTS idx_schedules_category ON schedules(category);

-- decorated_photos
CREATE TABLE IF NOT EXISTS decorated_photos (
    id                  TEXT PRIMARY KEY,
    trip_id             TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    original_filename   TEXT NOT NULL,
    style               TEXT NOT NULL,
    result_image_base64 TEXT NOT NULL,
    result_mime_type    TEXT NOT NULL DEFAULT 'image/jpeg',
    created_at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_decorated_photos_trip_id ON decorated_photos(trip_id);
CREATE INDEX IF NOT EXISTS idx_decorated_photos_created_at ON decorated_photos(created_at);

-- chat_messages
CREATE TABLE IF NOT EXISTS chat_messages (
    id           TEXT    PRIMARY KEY,
    trip_id      TEXT    REFERENCES trips(id) ON DELETE SET NULL,
    role         TEXT    NOT NULL,
    content      TEXT    NOT NULL,
    status       TEXT    NOT NULL DEFAULT 'sent',
    is_tool_call INTEGER NOT NULL DEFAULT 0,
    tool_name    TEXT,
    timestamp    TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_trip_id ON chat_messages(trip_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp);
"""


class Database:
    """SQLite database wrapper with async support."""

    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path
        self._connection: aiosqlite.Connection | None = None

    async def connect(self):
        """Open database connection and initialize schema."""
        self._connection = await aiosqlite.connect(self.db_path)
        self._connection.row_factory = aiosqlite.Row
        await self._connection.execute("PRAGMA foreign_keys = ON")
        await self._connection.execute("PRAGMA journal_mode = WAL")

        # Create tables
        await self._connection.executescript(_SCHEMA_SQL)
        await self._connection.commit()

        logger.info(f"SQLite database connected: {self.db_path}")

    async def disconnect(self):
        """Close database connection."""
        if self._connection:
            await self._connection.close()
            self._connection = None
            logger.info("SQLite database disconnected")

    @property
    def connection(self) -> aiosqlite.Connection:
        """Get the active database connection."""
        if self._connection is None:
            raise RuntimeError("Database not connected. Call connect() first.")
        return self._connection


# Global database instance
db = Database()


async def get_db() -> aiosqlite.Connection:
    """Get the database connection (for dependency injection)."""
    return db.connection
