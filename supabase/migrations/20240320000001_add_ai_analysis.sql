-- Add AI analysis columns to firearms table
ALTER TABLE firearms
ADD COLUMN IF NOT EXISTS ai_analysis JSONB,
ADD COLUMN IF NOT EXISTS ai_analysis_updated_at TIMESTAMP WITH TIME ZONE; 