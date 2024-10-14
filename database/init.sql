-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create enum for asset types
CREATE TYPE asset_type AS ENUM ('image', 'video');

-- Create assets table with standard columns
CREATE TABLE assets (
    id SERIAL PRIMARY KEY,
    asset_type asset_type NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    location GEOMETRY(Point, 4326)  -- For geospatial queries
);

-- Create dimensions table (normalize dimension data)
CREATE TABLE asset_dimensions (
    asset_id INTEGER REFERENCES assets(id),
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    PRIMARY KEY (asset_id)
);

-- Create tags table (normalize tag data)
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- Create asset_tags junction table (for many-to-many relationship)
CREATE TABLE asset_tags (
    asset_id INTEGER REFERENCES assets(id),
    tag_id INTEGER REFERENCES tags(id),
    PRIMARY KEY (asset_id, tag_id)
);

-- Create table for additional flexible metadata (using JSONB)
CREATE TABLE asset_metadata (
    asset_id INTEGER REFERENCES assets(id),
    metadata JSONB NOT NULL,
    PRIMARY KEY (asset_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_assets_asset_type ON assets(asset_type);
CREATE INDEX idx_asset_tags_asset_id ON asset_tags(asset_id);
CREATE INDEX idx_asset_tags_tag_id ON asset_tags(tag_id);
CREATE INDEX idx_asset_metadata_gin ON asset_metadata USING GIN (metadata);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to update updated_at
CREATE TRIGGER update_asset_modtime
BEFORE UPDATE ON assets
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

-- Create a view for easy querying of assets with their tags
CREATE OR REPLACE VIEW asset_details AS
SELECT DISTINCT ON (a.id)
    a.id, a.asset_type, a.file_name, a.file_path, a.file_size,
    ad.width, ad.height,
    array_remove(array_agg(t.name), NULL) AS tags,
    am.metadata
FROM assets a
LEFT JOIN asset_dimensions ad ON a.id = ad.asset_id
LEFT JOIN asset_tags at ON a.id = at.asset_id
LEFT JOIN tags t ON at.tag_id = t.id
LEFT JOIN asset_metadata am ON a.id = am.asset_id
GROUP BY a.id, a.asset_type, a.file_name, a.file_path, a.file_size, ad.width, ad.height, am.metadata;

-- Function to add a tag to an asset
CREATE OR REPLACE FUNCTION add_tag_to_asset(p_asset_id INTEGER, p_tag_name VARCHAR(50))
RETURNS VOID AS $$
DECLARE
    v_tag_id INTEGER;
BEGIN
    -- Get or create the tag
    SELECT id INTO v_tag_id FROM tags WHERE name = p_tag_name;
    IF v_tag_id IS NULL THEN
        INSERT INTO tags (name) VALUES (p_tag_name) RETURNING id INTO v_tag_id;
    END IF;

    -- Add the tag to the asset if it doesn't already exist
    INSERT INTO asset_tags (asset_id, tag_id)
    VALUES (p_asset_id, v_tag_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Full-text search setup
ALTER TABLE assets ADD COLUMN search_vector tsvector;
CREATE INDEX asset_search_idx ON assets USING GIN (search_vector);

-- Update trigger for search vector
CREATE OR REPLACE FUNCTION assets_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', COALESCE(NEW.file_name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE((SELECT string_agg(name, ' ') FROM tags JOIN asset_tags ON tags.id = asset_tags.tag_id WHERE asset_tags.asset_id = NEW.id), '')), 'B');
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_search_vector_update
BEFORE INSERT OR UPDATE ON assets
FOR EACH ROW EXECUTE FUNCTION assets_search_vector_update();

-- Update existing rows
UPDATE assets SET search_vector =
  setweight(to_tsvector('english', COALESCE(file_name, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE((SELECT string_agg(name, ' ') FROM tags JOIN asset_tags ON tags.id = asset_tags.tag_id WHERE asset_tags.asset_id = assets.id), '')), 'B');

-- Search function
CREATE OR REPLACE FUNCTION search_assets(search_query text)
RETURNS TABLE (id int, file_name text, asset_type text, tags text[])
AS $$
BEGIN
  RETURN QUERY
  SELECT a.id, a.file_name::text, a.asset_type::text, array_remove(array_agg(t.name), NULL)::text[] as tags
  FROM assets a
  LEFT JOIN asset_tags at ON a.id = at.asset_id
  LEFT JOIN tags t ON at.tag_id = t.id
  WHERE a.search_vector @@ plainto_tsquery('english', search_query)
  GROUP BY a.id, a.file_name, a.asset_type
  ORDER BY ts_rank(a.search_vector, plainto_tsquery('english', search_query)) DESC;
END
$$ LANGUAGE plpgsql;

-- Recreate the cached_asset_counts materialized view
DROP MATERIALIZED VIEW IF EXISTS cached_asset_counts;
CREATE MATERIALIZED VIEW cached_asset_counts AS
SELECT asset_type, COUNT(*) as count
FROM assets
GROUP BY asset_type;

-- Create a unique index on the cached_asset_counts materialized view
CREATE UNIQUE INDEX ON cached_asset_counts (asset_type);

-- Update the refresh_asset_counts function
CREATE OR REPLACE FUNCTION refresh_asset_counts()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY cached_asset_counts;
END
$$ LANGUAGE plpgsql;

-- Set up pg_cron job to refresh the materialized view every hour
SELECT cron.schedule('0 * * * *', 'SELECT refresh_asset_counts()');

-- Enhanced caching with UNLOGGED tables (Redis-like functionality)
CREATE UNLOGGED TABLE cache_table (
    key TEXT PRIMARY KEY,
    value JSONB,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ON cache_table (expires_at);

CREATE OR REPLACE FUNCTION set_cache(p_key TEXT, p_value JSONB, p_ttl INTERVAL)
RETURNS VOID AS $$
BEGIN
    INSERT INTO cache_table (key, value, expires_at)
    VALUES (p_key, p_value, CURRENT_TIMESTAMP + p_ttl)
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value, expires_at = EXCLUDED.expires_at;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_cache(p_key TEXT)
RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    DELETE FROM cache_table WHERE expires_at < CURRENT_TIMESTAMP;
    SELECT value INTO v_value FROM cache_table WHERE key = p_key;
    RETURN v_value;
END;
$$ LANGUAGE plpgsql;

-- Message Queue with SKIP LOCKED (Kafka/RabbitMQ-like functionality)
CREATE TABLE message_queue (
    id SERIAL PRIMARY KEY,
    payload JSONB,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION enqueue_message(p_payload JSONB)
RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO message_queue (payload) VALUES (p_payload) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dequeue_message()
RETURNS TABLE (id INTEGER, payload JSONB) AS $$
BEGIN
    RETURN QUERY
    WITH message AS (
        SELECT mq.id, mq.payload
        FROM message_queue mq
        WHERE mq.status = 'pending'
        ORDER BY mq.created_at
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    UPDATE message_queue mq
    SET status = 'processing'
    FROM message
    WHERE mq.id = message.id
    RETURNING message.*;
END;
$$ LANGUAGE plpgsql;

-- Generating JSON for APIs
CREATE OR REPLACE FUNCTION get_asset_json(p_asset_id INTEGER)
RETURNS JSONB AS $$
SELECT jsonb_build_object(
    'id', a.id,
    'type', a.asset_type,
    'file_name', a.file_name,
    'dimensions', jsonb_build_object('width', ad.width, 'height', ad.height),
    'tags', (SELECT jsonb_agg(t.name) FROM asset_tags at JOIN tags t ON at.tag_id = t.id WHERE at.asset_id = a.id),
    'metadata', am.metadata
)
FROM assets a
LEFT JOIN asset_dimensions ad ON a.id = ad.asset_id
LEFT JOIN asset_metadata am ON a.id = am.asset_id
WHERE a.id = p_asset_id;
$$ LANGUAGE sql;

-- Basic Auditing
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id INTEGER NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT
);

CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), current_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), current_user);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON assets
FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Example usage:
-- SELECT set_cache('asset:1', get_asset_json(1), INTERVAL '1 hour');
-- SELECT get_cache('asset:1');
-- SELECT enqueue_message('{"task": "process_image", "asset_id": 1}'::jsonb);
-- SELECT * FROM dequeue_message();
-- SELECT get_asset_json(1);
-- SELECT * FROM search_assets('sunset');
