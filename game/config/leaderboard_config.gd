extends RefCounted

# Global Top-10 backend.
# Fill these two values after creating the Supabase project.
# Use the public publishable key (or legacy anon key) in browser clients.
# Never place a secret/service_role key here.
const SUPABASE_URL := ""
const SUPABASE_ANON_KEY := ""

const TABLE_NAME := "leaderboard"
