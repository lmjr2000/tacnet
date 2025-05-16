-- Fix for classifieds table schema issues
-- This migration ensures the classifieds table has the correct structure
-- and creates it if it doesn't exist

-- First check if the classifieds table exists
DO $$
BEGIN
  -- Create classifieds table if it doesn't exist
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'classifieds') THEN
    CREATE TABLE public.classifieds (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      title TEXT NOT NULL,
      description TEXT,
      price NUMERIC,
      condition TEXT,
      primary_image_url TEXT,
      owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
      location TEXT,
      status TEXT DEFAULT 'active',
      firearm_id UUID REFERENCES public.firearms(id) ON DELETE SET NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
    );

    -- Add RLS policies
    ALTER TABLE public.classifieds ENABLE ROW LEVEL SECURITY;

    -- Allow authenticated users to see active classifieds
    CREATE POLICY "View active classifieds" ON public.classifieds
      FOR SELECT
      USING (status = 'active');

    -- Allow users to create their own classifieds
    CREATE POLICY "Create own classifieds" ON public.classifieds
      FOR INSERT
      WITH CHECK (auth.uid() = owner_id);

    -- Allow users to update their own classifieds
    CREATE POLICY "Update own classifieds" ON public.classifieds
      FOR UPDATE
      USING (auth.uid() = owner_id);

    -- Allow users to delete their own classifieds
    CREATE POLICY "Delete own classifieds" ON public.classifieds
      FOR DELETE
      USING (auth.uid() = owner_id);
      
    -- Grant access to authenticated users
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.classifieds TO authenticated;
  ELSE
    -- If the table exists, make sure it has all the required columns
    
    -- Ensure primary_image_url column exists (migration from image_url)
    IF NOT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'primary_image_url'
    ) THEN
      -- Add primary_image_url if it doesn't exist
      ALTER TABLE public.classifieds ADD COLUMN primary_image_url TEXT;
      
      -- If image_url exists, migrate data
      IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'image_url'
      ) THEN
        -- Copy data from image_url to primary_image_url
        UPDATE public.classifieds SET primary_image_url = image_url WHERE primary_image_url IS NULL AND image_url IS NOT NULL;
      END IF;
    END IF;
    
    -- Ensure owner_id column exists (migration from user_id)
    IF NOT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'owner_id'
    ) THEN
      -- Add owner_id if it doesn't exist
      ALTER TABLE public.classifieds ADD COLUMN owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
      
      -- If user_id exists, migrate data
      IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'user_id'
      ) THEN
        -- Copy data from user_id to owner_id
        UPDATE public.classifieds SET owner_id = user_id WHERE owner_id IS NULL AND user_id IS NOT NULL;
      END IF;
    END IF;
    
    -- Add any other missing columns with their defaults
    IF NOT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'firearm_id'
    ) THEN
      ALTER TABLE public.classifieds ADD COLUMN firearm_id UUID REFERENCES public.firearms(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'condition'
    ) THEN
      ALTER TABLE public.classifieds ADD COLUMN condition TEXT;
      -- Set a default condition for existing records
      UPDATE public.classifieds SET condition = 'New' WHERE condition IS NULL;
    END IF;
    
    IF NOT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'classifieds' AND column_name = 'status'
    ) THEN
      ALTER TABLE public.classifieds ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
  END IF;
END
$$;

-- Add some sample classifieds if the table is empty
DO $$
DECLARE
  total_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_count FROM public.classifieds;
  
  IF total_count = 0 THEN
    -- Insert sample data
    INSERT INTO public.classifieds 
      (title, description, price, condition, primary_image_url, owner_id, location, status, created_at)
    VALUES
      ('9mm Ammo for Sale', 'Selling 500 rounds of 9mm ammo. Brand new in box.', 150.00, 'New', 'https://example.com/ammo1.jpg', '00000000-0000-0000-0000-000000000000', 'Austin, TX', 'active', NOW() - INTERVAL '2 days'),
      ('AR-15 Parts Kit', 'Complete lower parts kit for AR-15 builds.', 89.99, 'New', 'https://example.com/parts.jpg', '00000000-0000-0000-0000-000000000000', 'Houston, TX', 'active', NOW() - INTERVAL '5 days'),
      ('Hunting Scope', 'Slightly used 3-9x40 hunting scope. Great condition.', 200.00, 'Used - Like New', 'https://example.com/scope.jpg', '00000000-0000-0000-0000-000000000000', 'Dallas, TX', 'active', NOW() - INTERVAL '1 day'),
      ('Gun Safe', 'Large gun safe, holds up to 12 firearms. Electronic lock.', 450.00, 'Used - Good', 'https://example.com/safe.jpg', '00000000-0000-0000-0000-000000000000', 'San Antonio, TX', 'active', NOW() - INTERVAL '7 days'),
      ('Cleaning Kit', 'Universal gun cleaning kit with brushes and solvents.', 35.00, 'New', 'https://example.com/cleaning.jpg', '00000000-0000-0000-0000-000000000000', 'El Paso, TX', 'active', NOW());
      
    RAISE NOTICE 'Added sample classifieds data.';
  END IF;
END$$; 