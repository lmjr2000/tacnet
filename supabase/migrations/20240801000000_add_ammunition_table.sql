-- This migration adds the ammunition table for tracking ammunition inventory
-- with storage locations, expiration dates, and usage statistics

-- Create ammunition table
CREATE TABLE public.ammunition (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  caliber TEXT NOT NULL,
  brand TEXT,
  bullet_type TEXT,
  bullet_weight NUMERIC,
  quantity INTEGER NOT NULL DEFAULT 0,
  rounds_per_box INTEGER,
  purchase_date DATE,
  expiration_date DATE,
  storage_location TEXT,
  lot_number TEXT,
  price_per_round NUMERIC,
  notes TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create ammunition usage log for tracking usage statistics
CREATE TABLE public.ammunition_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ammunition_id UUID REFERENCES public.ammunition(id) ON DELETE CASCADE NOT NULL,
  firearm_id UUID REFERENCES public.firearms(id) ON DELETE SET NULL,
  date_used DATE NOT NULL DEFAULT CURRENT_DATE,
  quantity_used INTEGER NOT NULL,
  purpose TEXT,
  accuracy_rating INTEGER, -- 1-5 star rating
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Row Level Security
ALTER TABLE public.ammunition ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ammunition_usage ENABLE ROW LEVEL SECURITY;

-- RLS policies for ammunition
CREATE POLICY "Users can view their own ammunition" 
  ON public.ammunition FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own ammunition" 
  ON public.ammunition FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own ammunition" 
  ON public.ammunition FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own ammunition" 
  ON public.ammunition FOR DELETE 
  USING (auth.uid() = user_id);

-- RLS policies for ammunition usage
CREATE POLICY "Users can view their own ammunition usage" 
  ON public.ammunition_usage FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM public.ammunition 
    WHERE ammunition.id = ammunition_usage.ammunition_id 
    AND ammunition.user_id = auth.uid()
  ));

CREATE POLICY "Users can insert ammunition usage for their ammunition" 
  ON public.ammunition_usage FOR INSERT 
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.ammunition 
    WHERE ammunition.id = ammunition_usage.ammunition_id 
    AND ammunition.user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own ammunition usage" 
  ON public.ammunition_usage FOR UPDATE 
  USING (EXISTS (
    SELECT 1 FROM public.ammunition 
    WHERE ammunition.id = ammunition_usage.ammunition_id 
    AND ammunition.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own ammunition usage" 
  ON public.ammunition_usage FOR DELETE 
  USING (EXISTS (
    SELECT 1 FROM public.ammunition 
    WHERE ammunition.id = ammunition_usage.ammunition_id 
    AND ammunition.user_id = auth.uid()
  ));

-- Grant permissions
GRANT ALL ON public.ammunition TO authenticated;
GRANT ALL ON public.ammunition_usage TO authenticated;

-- Create update function to automatically decrement ammunition quantity when usage is added
CREATE OR REPLACE FUNCTION decrement_ammunition_quantity()
RETURNS TRIGGER AS $$
BEGIN
  -- Decrement the quantity in the ammunition table
  UPDATE public.ammunition
  SET 
    quantity = GREATEST(0, quantity - NEW.quantity_used),
    updated_at = NOW()
  WHERE id = NEW.ammunition_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to decrement ammunition quantity when usage is added
CREATE TRIGGER decrement_ammunition_after_usage
AFTER INSERT ON public.ammunition_usage
FOR EACH ROW
EXECUTE FUNCTION decrement_ammunition_quantity();

-- Create function to update ammunition quantity when usage is edited or deleted
CREATE OR REPLACE FUNCTION update_ammunition_quantity_on_usage_change()
RETURNS TRIGGER AS $$
DECLARE
  quantity_diff INTEGER;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Calculate the difference between old and new quantity
    quantity_diff := NEW.quantity_used - OLD.quantity_used;
    
    -- Update the ammunition quantity
    UPDATE public.ammunition
    SET 
      quantity = GREATEST(0, quantity - quantity_diff),
      updated_at = NOW()
    WHERE id = NEW.ammunition_id;
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Add the deleted quantity back to ammunition
    UPDATE public.ammunition
    SET 
      quantity = quantity + OLD.quantity_used,
      updated_at = NOW()
    WHERE id = OLD.ammunition_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updates and deletes
CREATE TRIGGER update_ammunition_on_usage_update
AFTER UPDATE ON public.ammunition_usage
FOR EACH ROW
EXECUTE FUNCTION update_ammunition_quantity_on_usage_change();

CREATE TRIGGER restore_ammunition_on_usage_delete
AFTER DELETE ON public.ammunition_usage
FOR EACH ROW
EXECUTE FUNCTION update_ammunition_quantity_on_usage_change(); 