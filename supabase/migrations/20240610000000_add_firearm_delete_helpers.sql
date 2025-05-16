-- Add helper functions for safely deleting firearms with associated trading listings

-- Function to safely cancel all trading listings for a specific firearm
CREATE OR REPLACE FUNCTION cancel_firearm_listings(p_firearm_id UUID)
RETURNS SETOF trading_listings
SECURITY INVOKER
AS $$
BEGIN
  -- Update all active trading listings for this firearm to be cancelled
  RETURN QUERY
  UPDATE trading_listings 
  SET 
    status = 'cancelled',
    notes = COALESCE(notes, '') || E'\nAutomatically cancelled - firearm was deleted',
    updated_at = NOW()
  WHERE 
    firearm_id = p_firearm_id
    AND status = 'active'
  RETURNING *;
END;
$$ LANGUAGE plpgsql;

-- Function to unlink all trading listings from a specific firearm
CREATE OR REPLACE FUNCTION unlink_firearm_listings(p_firearm_id UUID)
RETURNS SETOF trading_listings
SECURITY INVOKER
AS $$
BEGIN
  -- Unlink the firearm from all its trading listings
  RETURN QUERY
  UPDATE trading_listings 
  SET 
    firearm_id = NULL,
    notes = COALESCE(notes, '') || E'\nAutomatically unlinked - firearm was deleted',
    updated_at = NOW()
  WHERE 
    firearm_id = p_firearm_id
  RETURNING *;
END;
$$ LANGUAGE plpgsql;

-- Function to safely delete a firearm by handling all its trading listings first
CREATE OR REPLACE FUNCTION safe_delete_firearm(p_firearm_id UUID, p_user_id UUID)
RETURNS SETOF firearms
SECURITY INVOKER
AS $$
DECLARE
  affected_listings INTEGER;
BEGIN
  -- First try to cancel all active listings
  SELECT COUNT(*) INTO affected_listings
  FROM cancel_firearm_listings(p_firearm_id);
  
  -- Then unlink the firearm from all listings
  PERFORM unlink_firearm_listings(p_firearm_id);
  
  -- Now delete the firearm
  RETURN QUERY
  DELETE FROM firearms
  WHERE 
    id = p_firearm_id 
    AND user_id = p_user_id
  RETURNING *;
END;
$$ LANGUAGE plpgsql;

-- Add proper Row Level Security for the functions
GRANT EXECUTE ON FUNCTION cancel_firearm_listings TO authenticated;
GRANT EXECUTE ON FUNCTION unlink_firearm_listings TO authenticated;
GRANT EXECUTE ON FUNCTION safe_delete_firearm TO authenticated; 