-- Create message reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(message_id, user_id, emoji)
);

-- Add RLS policies
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view reactions for messages they sent or received"
  ON message_reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM direct_messages
      WHERE id = message_reactions.message_id
      AND (sender_id = auth.uid() OR recipient_id = auth.uid())
    )
  );

CREATE POLICY "Users can add reactions to messages they can view"
  ON message_reactions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM direct_messages
      WHERE id = message_reactions.message_id
      AND (sender_id = auth.uid() OR recipient_id = auth.uid())
    )
  );

CREATE POLICY "Users can delete their own reactions"
  ON message_reactions FOR DELETE
  USING (user_id = auth.uid());

-- Create function to get message reactions
CREATE OR REPLACE FUNCTION get_message_reactions(message_ids UUID[])
RETURNS TABLE (
  message_id UUID,
  reactions JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mr.message_id,
    jsonb_object_agg(
      mr.emoji,
      jsonb_build_object(
        'emoji', mr.emoji,
        'count', COUNT(*),
        'users', jsonb_agg(p.username)
      )
    ) as reactions
  FROM message_reactions mr
  JOIN profiles p ON p.id = mr.user_id
  WHERE mr.message_id = ANY(message_ids)
  GROUP BY mr.message_id;
END;
$$;

-- Create function to toggle reaction
CREATE OR REPLACE FUNCTION toggle_message_reaction(
  p_message_id UUID,
  p_emoji TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Check if reaction exists
  SELECT EXISTS (
    SELECT 1 FROM message_reactions
    WHERE message_id = p_message_id
    AND user_id = auth.uid()
    AND emoji = p_emoji
  ) INTO v_exists;
  
  IF v_exists THEN
    -- Remove reaction
    DELETE FROM message_reactions
    WHERE message_id = p_message_id
    AND user_id = auth.uid()
    AND emoji = p_emoji;
    RETURN FALSE;
  ELSE
    -- Add reaction
    INSERT INTO message_reactions (message_id, user_id, emoji)
    VALUES (p_message_id, auth.uid(), p_emoji);
    RETURN TRUE;
  END IF;
END;
$$; 