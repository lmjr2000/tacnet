-- Function to get user messages
CREATE OR REPLACE FUNCTION get_user_messages(user_id UUID)
RETURNS SETOF direct_messages
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM direct_messages
  WHERE sender_id = user_id OR recipient_id = user_id
  ORDER BY created_at DESC;
$$;

-- Function to get conversation messages
CREATE OR REPLACE FUNCTION get_conversation_messages(current_user_id UUID, other_user_id UUID)
RETURNS SETOF direct_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify that both users exist
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = current_user_id) THEN
    RAISE EXCEPTION 'Current user not found';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = other_user_id) THEN
    RAISE EXCEPTION 'Other user not found';
  END IF;

  RETURN QUERY
  SELECT dm.*
  FROM direct_messages dm
  WHERE (dm.sender_id = current_user_id AND dm.recipient_id = other_user_id) OR
        (dm.sender_id = other_user_id AND dm.recipient_id = current_user_id)
  ORDER BY dm.created_at ASC;

  -- If no messages found, return empty set instead of null
  IF NOT FOUND THEN
    RETURN;
  END IF;
END;
$$;

-- Function to send a message
CREATE OR REPLACE FUNCTION send_message(sender_id UUID, recipient_id UUID, message_text TEXT, item_id UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_message_id UUID;
BEGIN
  INSERT INTO direct_messages (sender_id, recipient_id, message, item_id, is_read)
  VALUES (sender_id, recipient_id, message_text, item_id, false)
  RETURNING id INTO new_message_id;
  
  RETURN new_message_id;
END;
$$;

-- Function to mark a message as read
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

-- Function to delete a message
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
