-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_conversation_messages(UUID, UUID);
DROP FUNCTION IF EXISTS send_message(UUID, UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS mark_message_as_read(UUID);
DROP FUNCTION IF EXISTS delete_message(UUID, UUID);

-- Recreate the functions
CREATE OR REPLACE FUNCTION get_conversation_messages(current_user_id UUID, other_user_id UUID)
RETURNS TABLE (
  id UUID,
  sender_id UUID,
  recipient_id UUID,
  message TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT dm.*
  FROM direct_messages dm
  WHERE (dm.sender_id = current_user_id AND dm.recipient_id = other_user_id) OR
        (dm.sender_id = other_user_id AND dm.recipient_id = current_user_id)
  ORDER BY dm.created_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION send_message(sender_id UUID, recipient_id UUID, message_text TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_message_id UUID;
BEGIN
  INSERT INTO direct_messages (sender_id, recipient_id, message, is_read)
  VALUES (sender_id, recipient_id, message_text, false)
  RETURNING id INTO new_message_id;
  
  RETURN new_message_id;
END;
$$;

CREATE OR REPLACE FUNCTION mark_message_as_read(message_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE direct_messages
  SET is_read = true
  WHERE id = message_id AND recipient_id = auth.uid();
  
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION delete_message(message_id UUID, user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM direct_messages
  WHERE id = message_id AND sender_id = user_id;
  
  RETURN FOUND;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_conversation_messages(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION send_message(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_message_as_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_message(UUID, UUID) TO authenticated; 