-- mock_data.sql

-- Insert mock assets
INSERT INTO assets (asset_type, file_name, file_path, file_size, location) VALUES
('image', 'sunset1.jpg', '/images/sunset1.jpg', 2048000, ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)),
('image', 'mountain1.png', '/images/mountain1.png', 3072000, ST_SetSRID(ST_MakePoint(-106.8175, 39.1911), 4326)),
('video', 'interview1.mp4', '/videos/interview1.mp4', 15360000, ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)),
('image', 'beach1.jpg', '/images/beach1.jpg', 1536000, ST_SetSRID(ST_MakePoint(-80.1918, 25.7617), 4326)),
('video', 'tutorial1.mp4', '/videos/tutorial1.mp4', 20480000, ST_SetSRID(ST_MakePoint(-0.1276, 51.5074), 4326));

-- Insert mock dimensions
INSERT INTO asset_dimensions (asset_id, width, height) VALUES
(1, 1920, 1080),
(2, 2560, 1440),
(3, 1280, 720),
(4, 1600, 900),
(5, 1920, 1080);

-- Insert mock tags
INSERT INTO tags (name) VALUES
('nature'), ('interview'), ('tutorial'), ('landscape'), ('beach'), ('mountain'), ('sunset');

-- Associate tags with assets
INSERT INTO asset_tags (asset_id, tag_id) VALUES
(1, 1), (1, 4), (1, 7),  -- sunset1.jpg: nature, landscape, sunset
(2, 1), (2, 4), (2, 6),  -- mountain1.png: nature, landscape, mountain
(3, 2),                  -- interview1.mp4: interview
(4, 1), (4, 4), (4, 5),  -- beach1.jpg: nature, landscape, beach
(5, 3);                  -- tutorial1.mp4: tutorial

-- Insert mock metadata
INSERT INTO asset_metadata (asset_id, metadata) VALUES
(1, '{"camera": "Canon EOS R5", "iso": 100, "aperture": "f/2.8", "location": "San Francisco"}'),
(2, '{"camera": "Nikon D850", "iso": 200, "aperture": "f/4", "location": "Rocky Mountains"}'),
(3, '{"duration": "00:15:30", "codec": "H.264", "interviewer": "John Doe", "interviewee": "Jane Smith"}'),
(4, '{"camera": "Sony A7III", "iso": 400, "aperture": "f/5.6", "location": "Miami Beach"}'),
(5, '{"duration": "00:45:00", "codec": "H.265", "instructor": "Alice Johnson", "topic": "PostgreSQL Advanced Features"}');

-- Update search vectors
UPDATE assets SET search_vector =
  setweight(to_tsvector('english', COALESCE(file_name, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE((SELECT string_agg(name, ' ') FROM tags JOIN asset_tags ON tags.id = asset_tags.tag_id WHERE asset_tags.asset_id = assets.id), '')), 'B');

-- Refresh materialized view
REFRESH MATERIALIZED VIEW cached_asset_counts;
