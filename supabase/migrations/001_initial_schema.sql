-- Vanshavali Database Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Table: family_members
-- ============================================
CREATE TABLE IF NOT EXISTS public.family_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  
  -- Auth Link: If NULL, this is a placeholder/ghost profile created by a relative.
  -- If NOT NULL, this is a real registered user.
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Lineage Links (Self-Referencing)
  father_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
  mother_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
  spouse_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,

  -- Basic Details
  first_name_en TEXT NOT NULL,
  first_name_gu TEXT, -- Gujarati
  last_name_en TEXT NOT NULL,
  last_name_gu TEXT, -- Gujarati
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')),
  dob DATE,
  is_alive BOOLEAN DEFAULT TRUE,
  
  -- Search/Filter
  village_origin TEXT,
  current_city TEXT,

  -- Deep Data (Flexible)
  -- Structure: { "education": "...", "occupation": "...", "medical": "..." }
  deep_details JSONB DEFAULT '{}'::JSONB
);

-- ============================================
-- Indexes for better performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_family_members_auth_user_id ON public.family_members(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_father_id ON public.family_members(father_id);
CREATE INDEX IF NOT EXISTS idx_family_members_mother_id ON public.family_members(mother_id);
CREATE INDEX IF NOT EXISTS idx_family_members_spouse_id ON public.family_members(spouse_id);
CREATE INDEX IF NOT EXISTS idx_family_members_names ON public.family_members(first_name_en, last_name_en);
CREATE INDEX IF NOT EXISTS idx_family_members_village ON public.family_members(village_origin);

-- ============================================
-- Row Level Security (RLS)
-- ============================================
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

-- Policy 1: Everyone can read all family members (Public Tree)
CREATE POLICY "Anyone can view family members" 
  ON public.family_members 
  FOR SELECT 
  USING (true);

-- Policy 2: Authenticated users can insert new members
CREATE POLICY "Authenticated users can insert family members" 
  ON public.family_members 
  FOR INSERT 
  TO authenticated
  WITH CHECK (true);

-- Policy 3: Users can only update their own row OR unclaimed profiles
CREATE POLICY "Users can update their own profile" 
  ON public.family_members 
  FOR UPDATE 
  TO authenticated
  USING (
    auth_user_id = auth.uid() 
    OR auth_user_id IS NULL
  )
  WITH CHECK (
    auth_user_id = auth.uid() 
    OR auth_user_id IS NULL
  );

-- Policy 4: Users can delete only profiles they created (not their own claimed profile)
CREATE POLICY "Users can delete unclaimed profiles" 
  ON public.family_members 
  FOR DELETE 
  TO authenticated
  USING (auth_user_id IS NULL);

-- ============================================
-- RPC Function: Claim Profile
-- ============================================
-- This function allows a user to claim an unclaimed profile
CREATE OR REPLACE FUNCTION claim_profile(profile_id UUID)
RETURNS public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result public.family_members;
BEGIN
  -- Check if user already has a profile
  IF EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = auth.uid()) THEN
    RAISE EXCEPTION 'User already has a profile';
  END IF;
  
  -- Check if profile exists and is unclaimed
  IF NOT EXISTS (SELECT 1 FROM public.family_members WHERE id = profile_id AND auth_user_id IS NULL) THEN
    RAISE EXCEPTION 'Profile not found or already claimed';
  END IF;
  
  -- Claim the profile
  UPDATE public.family_members 
  SET auth_user_id = auth.uid()
  WHERE id = profile_id AND auth_user_id IS NULL
  RETURNING * INTO result;
  
  RETURN result;
END;
$$;

-- ============================================
-- RPC Function: Get Ego-Centric Network
-- ============================================
-- This function returns the family network centered on a specific member
CREATE OR REPLACE FUNCTION get_ego_network(center_member_id UUID)
RETURNS SETOF public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH center AS (
    SELECT * FROM public.family_members WHERE id = center_member_id
  ),
  related_ids AS (
    -- The center member
    SELECT id FROM center
    UNION
    -- Father
    SELECT father_id FROM center WHERE father_id IS NOT NULL
    UNION
    -- Mother
    SELECT mother_id FROM center WHERE mother_id IS NOT NULL
    UNION
    -- Spouse
    SELECT spouse_id FROM center WHERE spouse_id IS NOT NULL
    UNION
    -- Children (where center is father or mother)
    SELECT fm.id FROM public.family_members fm
    WHERE fm.father_id = center_member_id OR fm.mother_id = center_member_id
    UNION
    -- Siblings (share same father or mother)
    SELECT fm.id FROM public.family_members fm, center c
    WHERE (fm.father_id = c.father_id AND c.father_id IS NOT NULL)
       OR (fm.mother_id = c.mother_id AND c.mother_id IS NOT NULL)
  )
  SELECT fm.* FROM public.family_members fm
  WHERE fm.id IN (SELECT id FROM related_ids);
END;
$$;

-- ============================================
-- RPC Function: Search Family Members
-- ============================================
CREATE OR REPLACE FUNCTION search_family_members(search_query TEXT, result_limit INT DEFAULT 20)
RETURNS SETOF public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.family_members
  WHERE 
    first_name_en ILIKE '%' || search_query || '%'
    OR last_name_en ILIKE '%' || search_query || '%'
    OR first_name_gu ILIKE '%' || search_query || '%'
    OR last_name_gu ILIKE '%' || search_query || '%'
    OR village_origin ILIKE '%' || search_query || '%'
    OR current_city ILIKE '%' || search_query || '%'
  LIMIT result_limit;
END;
$$;

-- ============================================
-- Grant necessary permissions
-- ============================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.family_members TO anon, authenticated;
GRANT EXECUTE ON FUNCTION claim_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_ego_network(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION search_family_members(TEXT, INT) TO anon, authenticated;
