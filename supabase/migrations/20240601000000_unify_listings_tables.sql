-- This migration unifies the structure of our trading_listings and classifieds tables
-- to ensure consistent field names and behavior across the application.

-- First, update the classifieds table to match trading_listings field naming
ALTER TABLE classifieds RENAME COLUMN contact_info TO contact_information;
ALTER TABLE classifieds RENAME COLUMN image_url TO primary_image_url;
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS listing_type VARCHAR DEFAULT 'classified';
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'active';
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS location VARCHAR;
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS condition VARCHAR;
ALTER TABLE classifieds ADD COLUMN IF NOT EXISTS firearm_id UUID REFERENCES firearms(id) ON DELETE SET NULL;

-- Update owner_id from user_id where available
UPDATE classifieds SET owner_id = user_id WHERE user_id IS NOT NULL;

-- Add additional fields to trading_listings for consistency
ALTER TABLE trading_listings ADD COLUMN IF NOT EXISTS contact_information VARCHAR;

-- Create a unified view for listings that combines both tables
CREATE OR REPLACE VIEW unified_listings AS
SELECT 
  id,
  title,
  description,
  price,
  condition,
  primary_image_url AS image_url,
  owner_id,
  location,
  status,
  firearm_id,
  'trading' AS source,
  created_at,
  updated_at
FROM trading_listings
WHERE status = 'active'
UNION ALL
SELECT
  id,
  title,
  description,
  price,
  condition,
  primary_image_url AS image_url,
  owner_id,
  location,
  status,
  firearm_id,
  'classified' AS source,
  created_at,
  updated_at
FROM classifieds
WHERE status = 'active';

-- Create RLS policies for classifieds similar to trading_listings
ALTER TABLE classifieds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view active classifieds" ON classifieds;
DROP POLICY IF EXISTS "Users can manage their own classifieds" ON classifieds;

CREATE POLICY "Users can view active classifieds"
  ON classifieds FOR SELECT
  USING (status = 'active' OR owner_id = auth.uid());

CREATE POLICY "Users can manage their own classifieds"
  ON classifieds FOR ALL
  USING (owner_id = auth.uid());

-- Create helper functions for both listings
CREATE OR REPLACE FUNCTION cancel_listing(p_table_name text, p_listing_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sql text;
  v_result boolean;
BEGIN
  IF p_table_name NOT IN ('trading_listings', 'classifieds') THEN
    RAISE EXCEPTION 'Invalid table name: %', p_table_name;
  END IF;
  
  v_sql := format('
    UPDATE %I
    SET status = ''cancelled''
    WHERE id = %L AND owner_id = %L
    RETURNING true', 
    p_table_name, p_listing_id, auth.uid()
  );
  
  EXECUTE v_sql INTO v_result;
  RETURN coalesce(v_result, false);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION cancel_listing(text, UUID) TO authenticated;

-- Add a function to get unified listings
CREATE OR REPLACE FUNCTION get_unified_listings()
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  price NUMERIC,
  condition TEXT,
  image_url TEXT,
  owner_id UUID,
  location TEXT,
  status TEXT,
  firearm_id UUID,
  source TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.title,
    t.description,
    t.price,
    t.condition,
    t.primary_image_url AS image_url,
    t.owner_id,
    t.location,
    t.status,
    t.firearm_id,
    'trading' AS source,
    t.created_at,
    t.updated_at
  FROM trading_listings t
  WHERE t.status = 'active'
  
  UNION ALL
  
  SELECT
    c.id,
    c.title,
    c.description,
    c.price,
    c.condition,
    c.primary_image_url AS image_url,
    c.owner_id,
    c.location,
    c.status,
    c.firearm_id,
    'classified' AS source,
    c.created_at,
    c.updated_at
  FROM classifieds c
  WHERE c.status = 'active'
  
  ORDER BY created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_unified_listings() TO authenticated; 